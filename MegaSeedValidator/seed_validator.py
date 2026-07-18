#!/usr/bin/env python3
"""Validateur externe de seeds pour KevinPiriou/RobloxGame.
Bibliothèque standard uniquement. Voir README.md pour les limites de parité RNG.
"""
from __future__ import annotations
import argparse,csv,hashlib,html,json,math,os,random as py_random,sqlite3,time,traceback,webbrowser
from collections import deque
from concurrent.futures import ProcessPoolExecutor,as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any,Optional
UINT32_MOD=4294967296; UINT32_MAX=4294967295
DIRECTIONS={'North':(0.,-1.),'South':(0.,1.),'East':(1.,0.),'West':(-1.,0.)}
class PortableRandom:
    def __init__(self,seed:int):
        self.state=int(math.floor(seed))%UINT32_MOD or 0x6D2B79F5
    def _u32(self):
        x=self.state; x^=(x<<13)&UINT32_MAX; x^=(x>>17)&UINT32_MAX; x^=(x<<5)&UINT32_MAX
        self.state=x&UINT32_MAX; return self.state
    def next_number(self,a=0.,b=1.): return a+(b-a)*(self._u32()/UINT32_MAX)
    def next_integer(self,a:int,b:int):
        span=b-a+1; limit=(UINT32_MOD//span)*span
        while True:
            v=self._u32()
            if v<limit:return a+v%span
class PythonRandom:
    def __init__(self,seed):self.r=py_random.Random(seed)
    def next_number(self,a=0.,b=1.):return self.r.uniform(a,b)
    def next_integer(self,a,b):return self.r.randint(a,b)
def make_rng(mode,seed):return PortableRandom(seed) if mode=='portable' else PythonRandom(seed)
def load_config(path:Path):
    raw=path.read_text(encoding='utf-8'); c=json.loads(raw); c['_config_hash']=hashlib.sha256(raw.encode()).hexdigest(); return c
def clamp(v,a,b):return max(a,min(b,v))
def dist(a,b):return math.hypot(a[0]-b[0],a[1]-b[1])
def rotate(x,z,y):
    y%=4
    return (x,z) if y==0 else ((-z,x) if y==1 else ((-x,-z) if y==2 else (z,-x)))
def rotated_size(w,d,y):return (w,d) if y%2==0 else (d,w)
def rect(cx,cz,w,d,**extra):
    r={'cx':cx,'cz':cz,'width':w,'depth':d,'min_x':cx-w/2,'max_x':cx+w/2,'min_z':cz-d/2,'max_z':cz+d/2};r.update(extra);return r
def rect_intersects(a,b,pad=0.):
    return a['max_x']+pad>=b['min_x'] and a['min_x']-pad<=b['max_x'] and a['max_z']+pad>=b['min_z'] and a['min_z']-pad<=b['max_z']
def point_rect_distance(p,r):
    return dist(p,(clamp(p[0],r['min_x'],r['max_x']),clamp(p[1],r['min_z'],r['max_z'])))
def elevation(p,scale,g):return clamp(p['elevation']*scale+g['elevation_offset'],g['minimum_elevation'],g['maximum_elevation'])
def ramp_len(e,g):
    r=g['ramp'];return clamp(e*r['length_per_elevation'],r['minimum_length'],r['maximum_length'])
def local_bounds(layout,scale,g):
    mnx=mnz=math.inf;mxx=mxz=-math.inf
    def ext(a,b,c,d):
        nonlocal mnx,mxx,mnz,mxz;mnx=min(mnx,a);mxx=max(mxx,b);mnz=min(mnz,c);mxz=max(mxz,d)
    for p in layout['platforms']:
        ox,oz=p['offset'];w,d=p['size'];hw=w/2;hd=d/2;ext(ox-hw,ox+hw,oz-hd,oz+hd);rl=ramp_len(elevation(p,scale,g),g)
        for s in p.get('ramps',[]):
            if s=='East':ext(ox+hw,ox+hw+rl,oz-hd,oz+hd)
            elif s=='West':ext(ox-hw-rl,ox-hw,oz-hd,oz+hd)
            elif s=='North':ext(ox-hw,ox+hw,oz-hd-rl,oz-hd)
            elif s=='South':ext(ox-hw,ox+hw,oz+hd,oz+hd+rl)
    return {'min_x':mnx,'max_x':mxx,'min_z':mnz,'max_z':mxz}
def world_bounds(anchor,l,y):
    pts=[]
    for x in (l['min_x'],l['max_x']):
        for z in (l['min_z'],l['max_z']):
            rx,rz=rotate(x,z,y);pts.append((anchor[0]+rx,anchor[1]+rz))
    return {'min_x':min(x for x,z in pts),'max_x':max(x for x,z in pts),'min_z':min(z for x,z in pts),'max_z':max(z for x,z in pts)}
def weighted_layout(rng,items,excluded):
    avail=[x for x in items if x['id'] not in excluded];total=sum(x['weight'] for x in avail)
    if total<=0:return None
    cur=rng.next_number(0,total)
    for x in avail:
        cur-=x['weight']
        if cur<=0:return x
    return avail[-1]
def cardinal(a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]
    if abs(dx)>=abs(dz):return (1.,0.) if dx>=0 else (-1.,0.)
    return (0.,1.) if dz>=0 else (0.,-1.)
def edge_pos(p,direction,clearance):
    ldx,ldz=rotate(direction[0],direction[1],(-p['yaw'])%4)
    extent=p['size'][0]/2 if abs(ldx)>abs(ldz) else p['size'][1]/2
    return p['ground'][0]+direction[0]*(extent+clearance),p['ground'][1]+direction[1]*(extent+clearance)
def make_platforms(selected,g):
    platforms=[];ramps=[];idx=0
    for li,s in enumerate(selected):
        s['platform_indices']=[]
        for p in s['definition']['platforms']:
            idx+=1;ox,oz=rotate(p['offset'][0],p['offset'][1],s['yaw']);cx=s['anchor'][0]+ox;cz=s['anchor'][1]+oz
            w,d=rotated_size(p['size'][0],p['size'][1],s['yaw']);e=elevation(p,s['elevation_scale'],g)
            rec=rect(cx,cz,w,d,kind='platform',platform_index=idx,layout_index=li,layout_id=s['definition']['id'],yaw=s['yaw'],size=p['size'],elevation=e,ground=[cx,cz],ramps=[])
            platforms.append(rec);s['platform_indices'].append(idx-1)
            for ri,side in enumerate(p.get('ramps',[]),1):
                ldx,ldz=DIRECTIONS[side];dx,dz=rotate(ldx,ldz,s['yaw']);local_x=side in ('East','West')
                he=p['size'][0]/2 if local_x else p['size'][1]/2;cross=p['size'][1] if local_x else p['size'][0];rl=ramp_len(e,g)
                rcx=cx+dx*(he+rl/2);rcz=cz+dz*(he+rl/2);rw,rd=(rl,cross) if abs(dx)>abs(dz) else (cross,rl)
                entry=(cx+dx*(he+rl),cz+dz*(he+rl));ed=(cx+dx*he,cz+dz*he)
                rr=rect(rcx,rcz,rw,rd,kind='ramp',platform_index=idx,ramp_index=ri,side=side,entry=list(entry),edge=list(ed),elevation=e,length=rl,slope_deg=math.degrees(math.atan2(e,max(.001,rl))))
                ramps.append(rr);rec['ramps'].append(len(ramps)-1)
    return platforms,ramps
def link_blocks(start,end,lid,g):
    lc=g['links'];dx,dz=end[0]-start[0],end[1]-start[1];length=math.hypot(dx,dz)
    if length<lc['minimum_length']:return []
    n=max(1,math.ceil(length/lc['maximum_length']));sl=length/n;ux,uz=dx/length,dz/length;out=[]
    for i in range(n):
        sx,sz=start[0]+ux*i*sl,start[1]+uz*i*sl;ex,ez=start[0]+ux*(i+1)*sl,start[1]+uz*(i+1)*sl;cx,cz=(sx+ex)/2,(sz+ez)/2
        w,d=(sl,lc['width']) if abs(ux)>abs(uz) else (lc['width'],sl)
        out.append(rect(cx,cz,w,d,kind='link',link_id=lid,index=i,start=[sx,sz],end=[ex,ez],elevation=lc['elevation']))
    return out
def make_links(selected,platforms,g):
    lc=g['links'];segments=[];connections=[]
    if not lc['enabled'] or len(selected)<2:return segments,connections
    linked={0};ci=0
    while True:
        best=None;bd=math.inf
        for fi in linked:
            if not selected[fi].get('platform_indices'):continue
            fp=platforms[selected[fi]['platform_indices'][0]]
            for ti in range(len(selected)):
                if ti in linked or not selected[ti].get('platform_indices'):continue
                tp=platforms[selected[ti]['platform_indices'][0]];dd=dist(fp['ground'],tp['ground'])
                if dd<bd:bd=dd;best=(fi,ti,fp,tp)
        if best is None:break
        ci+=1;fi,ti,fp,tp=best;made=[]
        if bd<=lc['maximum_connection_distance']:
            d1=cardinal(fp['ground'],tp['ground']);d2=cardinal(tp['ground'],fp['ground']);start=edge_pos(fp,d1,lc['clearance']);end=edge_pos(tp,d2,lc['clearance']);elbow=(end[0],start[1])
            made=link_blocks(start,elbow,f'{ci}a',g)+link_blocks(elbow,end,f'{ci}b',g);segments.extend(made)
        connections.append({'from_layout':fi,'to_layout':ti,'distance':bd,'success':bool(made),'segment_count':len(made),'from_platform':fp['platform_index'],'to_platform':tp['platform_index']})
        linked.add(ti) # comportement actuel, même si aucun bloc n'a été créé
    return segments,connections
def weighted_asset(rng,assets):
    total=sum(a['weight'] for a in assets);cur=rng.next_number(0,total)
    for a in assets:
        cur-=a['weight']
        if cur<=0:return a
    return assets[-1]
def circle_free(pos,radius,occupied,arrival,clear):return dist(pos,arrival)>=clear and all(dist(pos,o['position'])>=radius+o['radius'] for o in occupied)
def in_terrain(pos,terrain,clear):return any(r['min_x']-clear<=pos[0]<=r['max_x']+clear and r['min_z']-clear<=pos[1]<=r['max_z']+clear for r in terrain)
def make_decor(rng,platforms,links,bounds,arrival,g):
    c=g['decorations'];families=c['families'];occupied=[];out=[];total=0;terrain=platforms+links
    for name in c['family_order']:
        if total>=c['maximum_instances']:break
        f=families[name];fc=0;fmax=f.get('maximum_instances_per_map',10**9)
        def place(pos,on_platform):
            nonlocal total,fc
            if pos is None or total>=c['maximum_instances'] or fc>=fmax:return
            a=weighted_asset(rng,f['assets']);h=rng.next_number(a['minimum_height'],a['maximum_height']);yaw=rng.next_number(0,math.pi*2);blocking=f.get('collision_mode') in ('All','Bounds','TreeTrunk')
            out.append({'family':name,'asset':a['name'],'x':pos[0],'z':pos[1],'radius':f['footprint_radius'],'height':h,'yaw':yaw,'blocking':blocking,'on_platform':on_platform});occupied.append({'position':pos,'radius':f['footprint_radius']});total+=1;fc+=1
        for p in platforms:
            if total>=c['maximum_instances'] or fc>=fmax:break
            area=p['width']*p['depth']
            if area<f['minimum_platform_area'] or not f['minimum_elevation']<=p['elevation']<=f['maximum_elevation']:continue
            exp=area/1000*f['density_per_thousand_studs'];cnt=math.floor(exp)+(1 if rng.next_number()<exp-math.floor(exp) else 0);cnt=int(clamp(max(f['minimum_per_platform'],cnt),f['minimum_per_platform'],f['maximum_per_platform']))
            margin=min(c['platform_margin'],min(p['width'],p['depth'])*.35)
            for _ in range(cnt):
                pos=None
                for _a in range(c['placement_attempts_per_instance']):
                    x=rng.next_number(p['min_x']+margin,p['max_x']-margin);z=rng.next_number(p['min_z']+margin,p['max_z']-margin)
                    if circle_free((x,z),f['footprint_radius'],occupied,arrival,c['arrival_clear_radius']):pos=(x,z);break
                place(pos,True)
        gr=c['ground'];uw=bounds['max_x']-bounds['min_x']-2*gr['edge_inset'];ud=bounds['max_z']-bounds['min_z']-2*gr['edge_inset'];exp=max(0,uw)*max(0,ud)/1000*f['density_per_thousand_studs']*gr['density_multiplier'];gc=math.floor(exp)+(1 if rng.next_number()<exp-math.floor(exp) else 0);gc=min(gc,f.get('maximum_ground_instances',10**9))
        for _ in range(gc):
            if total>=c['maximum_instances'] or fc>=fmax:break
            pos=None
            for _a in range(c['placement_attempts_per_instance']):
                x=rng.next_number(bounds['min_x']+gr['edge_inset'],bounds['max_x']-gr['edge_inset']);z=rng.next_number(bounds['min_z']+gr['edge_inset'],bounds['max_z']-gr['edge_inset'])
                if not in_terrain((x,z),terrain,gr['terrain_clearance']) and circle_free((x,z),f['footprint_radius'],occupied,arrival,c['arrival_clear_radius']):pos=(x,z);break
            place(pos,False)
    return out
def generate_plan(seed,cfg,rng_mode):
    started=time.perf_counter();g=cfg['generator'];m=cfg['map_profile'];rng=make_rng(rng_mode,seed+413)
    bounds={'min_x':m['min_x']+g['playable_inset'],'max_x':m['max_x']-g['playable_inset'],'min_z':m['min_z']+g['playable_inset'],'max_z':m['max_z']-g['playable_inset']};arrival=(m['arrival_x'],m['arrival_z']);selected=[];occupied=[];ua=max(1,(bounds['max_x']-bounds['min_x'])*(bounds['max_z']-bounds['min_z']));target=ua*g['target_coverage_ratio'];covered=0.;planned=0;warnings=[]
    while len(selected)<g['maximum_layout_count'] and (len(selected)<g['minimum_layout_count'] or covered<target):
        attempted=set();placed=False
        for _ in range(len(g['layouts'])):
            layout=weighted_layout(rng,g['layouts'],attempted)
            if layout is None:break
            attempted.add(layout['id'])
            if planned+len(layout['platforms'])>g['maximum_generated_platforms']:continue
            scale=rng.next_number(g['elevation_scale_minimum'],g['elevation_scale_maximum']);yaw=rng.next_integer(0,3);lb=local_bounds(layout,scale,g);anchor=wb=None
            for _a in range(g['anchor_attempts']):
                cand=(rng.next_number(bounds['min_x'],bounds['max_x']),rng.next_number(bounds['min_z'],bounds['max_z']));cb=world_bounds(cand,lb,yaw)
                inside=cb['min_x']>=bounds['min_x'] and cb['max_x']<=bounds['max_x'] and cb['min_z']>=bounds['min_z'] and cb['max_z']<=bounds['max_z'];free=all(not rect_intersects(cb,o,g['platform_spacing']) for o in occupied);away=point_rect_distance(arrival,cb)>=g['arrival_clear_radius']
                if inside and free and away:anchor,wb=cand,cb;break
            if anchor is not None:
                selected.append({'definition':layout,'anchor':list(anchor),'yaw':yaw,'elevation_scale':scale,'bounds':wb});occupied.append(wb);covered+=sum(p['size'][0]*p['size'][1] for p in layout['platforms']);planned+=len(layout['platforms']);placed=True;break
        if not placed:warnings.append('coverage_capped_by_available_surface');break
    platforms,ramps=make_platforms(selected,g);links,connections=make_links(selected,platforms,g);decor=make_decor(rng,platforms,links,bounds,arrival,g)
    return {'seed':seed,'rng_mode':rng_mode,'bounds':bounds,'arrival':list(arrival),'selected_layouts':selected,'platforms':platforms,'ramps':ramps,'links':links,'link_connections':connections,'decorations':decor,'covered_area':covered,'usable_area':ua,'coverage_ratio':covered/ua,'generation_warnings':warnings,'generation_ms':(time.perf_counter()-started)*1000}
@dataclass(frozen=True)
class Grid:
    min_x:float;min_z:float;step:float;width:int;height:int
    def point(self,ix,iz):return self.min_x+(ix+.5)*self.step,self.min_z+(iz+.5)*self.step
    def cell(self,x,z):return int((x-self.min_x)//self.step),int((z-self.min_z)//self.step)
    def inside(self,ix,iz):return 0<=ix<self.width and 0<=iz<self.height
    def flat(self,ix,iz):return iz*self.width+ix
def mark_rect(blocked,grid,r,pad):
    a,b=grid.cell(r['min_x']-pad,r['min_z']-pad);c,d=grid.cell(r['max_x']+pad,r['max_z']+pad);a=max(0,a);b=max(0,b);c=min(grid.width-1,c);d=min(grid.height-1,d)
    for iz in range(b,d+1):
        base=iz*grid.width
        for ix in range(a,c+1):blocked[base+ix]=1
def mark_circle(blocked,grid,x,z,rad):
    a,b=grid.cell(x-rad,z-rad);c,d=grid.cell(x+rad,z+rad);rr=rad*rad
    for iz in range(max(0,b),min(grid.height-1,d)+1):
        for ix in range(max(0,a),min(grid.width-1,c)+1):
            px,pz=grid.point(ix,iz)
            if (px-x)**2+(pz-z)**2<=rr:blocked[grid.flat(ix,iz)]=1
def nearest_free(grid,blocked,p,radius=4):
    cx,cz=grid.cell(*p)
    if grid.inside(cx,cz) and not blocked[grid.flat(cx,cz)]:return cx,cz
    for r in range(1,radius+1):
        for iz in range(cz-r,cz+r+1):
            for ix in range(cx-r,cx+r+1):
                if grid.inside(ix,iz) and not blocked[grid.flat(ix,iz)]:return ix,iz
    return None
def flood(grid,blocked,start,parents=False):
    vis=bytearray(grid.width*grid.height);par={};q=deque([start]);vis[grid.flat(*start)]=1;count=0
    while q:
        ix,iz=q.popleft();count+=1;cur=grid.flat(ix,iz)
        for nx,nz in ((ix+1,iz),(ix-1,iz),(ix,iz+1),(ix,iz-1)):
            if not grid.inside(nx,nz):continue
            ni=grid.flat(nx,nz)
            if blocked[ni] or vis[ni]:continue
            vis[ni]=1
            if parents:par[ni]=cur
            q.append((nx,nz))
    return vis,par,count
def rebuild_path(grid,par,start,goal):
    si=grid.flat(*start);i=grid.flat(*goal)
    if i!=si and i not in par:return []
    ids=[i]
    while i!=si:i=par[i];ids.append(i)
    out=[]
    for flat in reversed(ids):iz,ix=divmod(flat,grid.width);out.append(list(grid.point(ix,iz)))
    return out
def analyze_plan(plan,cfg,detailed_path=False):
    started=time.perf_counter();g=cfg['generator'];m=cfg['map_profile'];errors=[];warnings=list(plan['generation_warnings'])
    if len(plan['selected_layouts'])<g['minimum_layout_count']:errors.append('layout_count_below_minimum')
    if not plan['platforms']:errors.append('no_platform')
    if len(plan['platforms'])>g['maximum_generated_platforms']:errors.append('platform_count_above_maximum')
    for i,l in enumerate(plan['selected_layouts']):
        b=l['bounds'];pb=plan['bounds']
        if not (b['min_x']>=pb['min_x'] and b['max_x']<=pb['max_x'] and b['min_z']>=pb['min_z'] and b['max_z']<=pb['max_z']):errors.append(f'layout_{i}_outside_bounds')
        if point_rect_distance(tuple(plan['arrival']),b)<g['arrival_clear_radius']:errors.append(f'layout_{i}_inside_arrival_clearance')
    for i in range(len(plan['selected_layouts'])):
        for j in range(i+1,len(plan['selected_layouts'])):
            if rect_intersects(plan['selected_layouts'][i]['bounds'],plan['selected_layouts'][j]['bounds'],g['platform_spacing']-1e-6):errors.append(f'layout_overlap_{i}_{j}')
    steep=[r for r in plan['ramps'] if r['slope_deg']>m['max_walkable_slope_deg']]
    if steep:errors.append(f'steep_ramps:{len(steep)}')
    failed=[c for c in plan['link_connections'] if not c['success']]
    if failed:warnings.append(f'link_connections_without_blocks:{len(failed)}')
    overlap=0
    for l in plan['links']:
        for p in plan['platforms']:
            ox=min(l['max_x'],p['max_x'])-max(l['min_x'],p['min_x']);oz=min(l['max_z'],p['max_z'])-max(l['min_z'],p['min_z'])
            if ox>g['links']['clearance'] and oz>g['links']['clearance']:overlap+=1;break
    if overlap:warnings.append(f'link_platform_intersections:{overlap}')
    arrival=tuple(plan['arrival'])
    if any(point_rect_distance(arrival,l)<=m['agent_radius'] for l in plan['links']):errors.append('arrival_blocked_by_link')
    b=plan['bounds'];step=m['grid_step'];grid=Grid(b['min_x'],b['min_z'],step,max(1,math.ceil((b['max_x']-b['min_x'])/step)),max(1,math.ceil((b['max_z']-b['min_z'])/step)));blocked=bytearray(grid.width*grid.height);pad=m['agent_radius']
    for p in plan['platforms']:mark_rect(blocked,grid,p,pad)
    for l in plan['links']:mark_rect(blocked,grid,l,pad)
    for d in plan['decorations']:
        if d['blocking'] and not d['on_platform']:mark_circle(blocked,grid,d['x'],d['z'],d['radius']+pad)
    start=nearest_free(grid,blocked,arrival,2);path=[];rr=0;reachable=set();base_ratio=0.;far=None;fd=-1
    if start is None:errors.append('arrival_has_no_free_navigation_cell');vis=bytearray(grid.width*grid.height);par={}
    else:
        vis,par,rc=flood(grid,blocked,start,detailed_path);free=len(blocked)-sum(blocked);base_ratio=rc/max(1,free)
        for r in plan['ramps']:
            cell=nearest_free(grid,blocked,tuple(r['entry']),3)
            if cell is not None and vis[grid.flat(*cell)] and r['slope_deg']<=m['max_walkable_slope_deg']:
                rr+=1;reachable.add(r['platform_index']);dd=dist(arrival,tuple(r['entry']))
                if dd>fd:fd=dd;far=cell
        if detailed_path and far is not None:path=rebuild_path(grid,par,start,far)
    pc=len(plan['platforms']);rp=len(reachable)
    if rp<pc:errors.append(f'unreachable_platforms:{pc-rp}')
    if base_ratio<m['min_base_reachable_ratio']:errors.append(f'base_reachable_ratio_too_low:{base_ratio:.3f}')
    mismatch=0
    for c in plan['link_connections']:
        if not c['success']:continue
        fp=plan['platforms'][c['from_platform']-1];tp=plan['platforms'][c['to_platform']-1]
        mismatch+=(abs(fp['elevation']-g['links']['elevation'])>1)+(abs(tp['elevation']-g['links']['elevation'])>1)
    if mismatch:warnings.append(f'raised_links_without_explicit_vertical_transition:{mismatch}')
    cov=plan['coverage_ratio'];covq=max(0.,1-abs(cov-g['target_coverage_ratio'])/max(.01,g['target_coverage_ratio']));conn=rp/max(1,pc);baseq=clamp((base_ratio-.75)/.25,0,1);linkq=(1-len(failed)/max(1,len(plan['link_connections'])))/(1+overlap*.25);unique=len({l['definition']['id'] for l in plan['selected_layouts']});div=unique/max(1,len(plan['selected_layouts']));elevs=[p['elevation'] for p in plan['platforms']];span=max(elevs)-min(elevs) if elevs else 0.;eq=clamp(span/90,.25,1);clearq=0 if 'arrival_blocked_by_link' in errors else 1
    score=conn*35+baseq*15+covq*15+linkq*10+div*10+eq*5+clearq*10-len(errors)*8-len(warnings)*1.25;score=clamp(score,0,100)
    return {'seed':plan['seed'],'status':'VALID' if not errors else 'INVALID','score':round(score,3),'layout_count':len(plan['selected_layouts']),'platform_count':pc,'ramp_count':len(plan['ramps']),'reachable_ramps':rr,'reachable_platforms':rp,'link_segments':len(plan['links']),'link_connections':len(plan['link_connections']),'failed_link_connections':len(failed),'coverage_ratio':round(cov,6),'base_reachable_ratio':round(base_ratio,6),'unique_layouts':unique,'elevation_span':round(span,3),'decoration_count':len(plan['decorations']),'blocking_ground_decorations':sum(1 for d in plan['decorations'] if d['blocking'] and not d['on_platform']),'errors':errors,'warnings':warnings,'path':path,'analysis_ms':round((time.perf_counter()-started)*1000,3),'generation_ms':round(plan['generation_ms'],3)}
def worker(payload):
    seed,cfg,rng=payload
    try:return analyze_plan(generate_plan(seed,cfg,rng),cfg,False)
    except Exception as e:return {'seed':seed,'status':'ERROR','score':0.,'layout_count':0,'platform_count':0,'ramp_count':0,'reachable_ramps':0,'reachable_platforms':0,'link_segments':0,'link_connections':0,'failed_link_connections':0,'coverage_ratio':0.,'base_reachable_ratio':0.,'unique_layouts':0,'elevation_span':0.,'decoration_count':0,'blocking_ground_decorations':0,'errors':[f'exception:{type(e).__name__}:{e}'],'warnings':[],'path':[],'analysis_ms':0.,'generation_ms':0.}
_WORKER_CFG=None
_WORKER_RNG='portable'
def init_worker(cfg,rng):
    global _WORKER_CFG,_WORKER_RNG
    _WORKER_CFG=cfg;_WORKER_RNG=rng
def worker_seed(seed):
    return worker((seed,_WORKER_CFG,_WORKER_RNG))
FIELDS=['seed','status','score','layout_count','platform_count','ramp_count','reachable_ramps','reachable_platforms','link_segments','link_connections','failed_link_connections','coverage_ratio','base_reachable_ratio','unique_layouts','elevation_span','decoration_count','blocking_ground_decorations','error_count','warning_count','generation_ms','analysis_ms','errors','warnings']
def flat_result(r):
    x=dict(r);x['error_count']=len(r['errors']);x['warning_count']=len(r['warnings']);x['errors']='|'.join(r['errors']);x['warnings']='|'.join(r['warnings']);x.pop('path',None);return {k:x.get(k,'') for k in FIELDS}
def init_db(path):
    c=sqlite3.connect(path);c.execute('CREATE TABLE IF NOT EXISTS seed_results (seed INTEGER PRIMARY KEY,status TEXT,score REAL,layout_count INTEGER,platform_count INTEGER,ramp_count INTEGER,reachable_ramps INTEGER,reachable_platforms INTEGER,link_segments INTEGER,link_connections INTEGER,failed_link_connections INTEGER,coverage_ratio REAL,base_reachable_ratio REAL,unique_layouts INTEGER,elevation_span REAL,decoration_count INTEGER,blocking_ground_decorations INTEGER,error_count INTEGER,warning_count INTEGER,generation_ms REAL,analysis_ms REAL,errors TEXT,warnings TEXT)');return c
def insert_db(c,r):
    row=flat_result(r);c.execute(f"INSERT OR REPLACE INTO seed_results ({','.join(FIELDS)}) VALUES ({','.join('?' for _ in FIELDS)})",[row[k] for k in FIELDS])
def svg_rect(r,b,w,h,cl):
    sx=w/(b['max_x']-b['min_x']);sz=h/(b['max_z']-b['min_z']);x=(r['min_x']-b['min_x'])*sx;y=h-(r['max_z']-b['min_z'])*sz;return f'<rect class="{cl}" x="{x:.2f}" y="{y:.2f}" width="{r["width"]*sx:.2f}" height="{r["depth"]*sz:.2f}"/>'
def render_svg(plan,res,out):
    w=h=1000;b=plan['bounds'];sx=w/(b['max_x']-b['min_x']);sz=h/(b['max_z']-b['min_z']);point=lambda x,z:((x-b['min_x'])*sx,h-(z-b['min_z'])*sz)
    p=[f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}"><style>.bg{{fill:#151922}}.platform{{fill:#4a9d59;stroke:#bde6a5;stroke-width:2}}.ramp{{fill:#d9aa4d;stroke:#ffe09a;opacity:.85}}.link{{fill:#4f83b8;stroke:#b8ddff;opacity:.75}}.decor{{fill:#315f38;opacity:.75}}.blocker{{fill:#ad4e46;opacity:.8}}.arrival{{fill:#fff;stroke:#00e5ff;stroke-width:4}}.path{{fill:none;stroke:#ff4fe1;stroke-width:4}}text{{fill:white;font-family:Arial}}</style><rect class="bg" width="1000" height="1000"/>''']
    p += [svg_rect(x,b,w,h,'platform') for x in plan['platforms']]+[svg_rect(x,b,w,h,'ramp') for x in plan['ramps']]+[svg_rect(x,b,w,h,'link') for x in plan['links']]
    for d in plan['decorations']:
        x,y=point(d['x'],d['z']);rr=max(2,d['radius']*(sx+sz)/2);p.append(f'<circle class="{"blocker" if d["blocking"] else "decor"}" cx="{x:.2f}" cy="{y:.2f}" r="{rr:.2f}"/>')
    ax,ay=point(*plan['arrival']);p.append(f'<circle class="arrival" cx="{ax:.2f}" cy="{ay:.2f}" r="10"/>')
    if res.get('path'):
        pts=' '.join(f'{point(q[0],q[1])[0]:.1f},{point(q[0],q[1])[1]:.1f}' for q in res['path']);p.append(f'<polyline class="path" points="{pts}"/>')
    title=html.escape(f'Seed {plan["seed"]} — {res["status"]} — score {res["score"]:.1f}');info=html.escape(f'Layouts {res["layout_count"]} | plateformes {res["platform_count"]} | couverture {res["coverage_ratio"]:.1%} | base {res["base_reachable_ratio"]:.1%}')
    p.append(f'<text x="24" y="38" font-size="28" font-weight="bold">{title}</text><text x="24" y="68" font-size="18">{info}</text></svg>');out.write_text('\n'.join(p),encoding='utf-8')
def html_report(out,results,meta):
    rows=[]
    for r in sorted(results,key=lambda x:(-x['score'],x['seed']))[:200]:
        preview=out.parent/'previews'/f'seed_{r["seed"]}.svg';link=f'<a href="previews/seed_{r["seed"]}.svg">SVG</a>' if preview.exists() else ''
        rows.append(f"<tr><td>{r['seed']}</td><td>{r['status']}</td><td>{r['score']:.2f}</td><td>{r['layout_count']}</td><td>{r['platform_count']}</td><td>{r['coverage_ratio']:.3f}</td><td>{r['base_reachable_ratio']:.3f}</td><td>{len(r['errors'])}</td><td>{len(r['warnings'])}</td><td>{link}</td></tr>")
    valid=sum(r['status']=='VALID' for r in results);invalid=sum(r['status']=='INVALID' for r in results);errs=sum(r['status']=='ERROR' for r in results)
    out.write_text(f'''<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Mega Seed Validator</title><style>body{{font-family:Arial;background:#11151d;color:#edf3fa;margin:32px}}.card{{background:#1a2130;padding:18px;border-radius:12px;margin-bottom:18px}}table{{border-collapse:collapse;width:100%;background:#171d28}}th,td{{border-bottom:1px solid #2c3748;padding:8px;text-align:right}}th:first-child,td:first-child{{text-align:left}}a{{color:#4edcff}}</style></head><body><h1>Mega Seed Validator</h1><div class="card"><p>Seeds : {len(results)} — valides : {valid} — invalides : {invalid} — erreurs : {errs}</p><p>Commit : {html.escape(meta['commit'])}</p><p>RNG : {html.escape(meta['rng_mode'])} — config : {html.escape(meta['config_hash'])}</p></div><table><thead><tr><th>Seed</th><th>Statut</th><th>Score</th><th>Layouts</th><th>Plateformes</th><th>Couverture</th><th>Base accessible</th><th>Erreurs</th><th>Alertes</th><th>Aperçu</th></tr></thead><tbody>{''.join(rows)}</tbody></table></body></html>''',encoding='utf-8')
def run_batch(cfg,start,count,workers,rng,out,top_count,render_count,progress=None):
    out.mkdir(parents=True,exist_ok=True);(out/'previews').mkdir(exist_ok=True);(out/'plans').mkdir(exist_ok=True);conn=init_db(out/'results.sqlite');results=[];workers=workers if workers>0 else max(1,(os.cpu_count() or 2)-1);started=time.perf_counter()
    with (out/'results.csv').open('w',newline='',encoding='utf-8-sig') as f:
        wr=csv.DictWriter(f,fieldnames=FIELDS);wr.writeheader()
        if workers==1:
            iterator=(worker((s,cfg,rng)) for s in range(start,start+count))
            for i,r in enumerate(iterator,1):results.append(r);wr.writerow(flat_result(r));insert_db(conn,r);progress and progress(i,count,r);conn.commit() if i%100==0 else None
        else:
            chunksize=max(1,count//max(1,workers*24))
            with ProcessPoolExecutor(max_workers=workers,initializer=init_worker,initargs=(cfg,rng)) as pool:
                for i,r in enumerate(pool.map(worker_seed,range(start,start+count),chunksize=chunksize),1):
                    results.append(r);wr.writerow(flat_result(r));insert_db(conn,r);progress and progress(i,count,r);conn.commit() if i%100==0 else None
    conn.commit();conn.close();ranking=sorted((r for r in results if r['status']=='VALID'),key=lambda r:(-r['score'],r['seed']));top=ranking[:top_count]
    (out/'top_seeds.txt').write_text('\n'.join(str(r['seed']) for r in top)+('\n' if top else ''),encoding='utf-8');(out/'top_results.json').write_text(json.dumps(top,indent=2,ensure_ascii=False),encoding='utf-8')
    for r in top[:render_count]:
        plan=generate_plan(r['seed'],cfg,rng);detail=analyze_plan(plan,cfg,True);(out/'plans'/f'seed_{r["seed"]}.json').write_text(json.dumps({'plan':plan,'analysis':detail},indent=2,ensure_ascii=False),encoding='utf-8');render_svg(plan,detail,out/'previews'/f'seed_{r["seed"]}.svg')
    meta={'repository':cfg['project']['repository'],'branch':cfg['project']['branch'],'commit':cfg['project']['commit'],'config_hash':cfg['_config_hash'],'rng_mode':rng,'start_seed':start,'count':count,'workers':workers,'elapsed_seconds':round(time.perf_counter()-started,3),'valid':sum(r['status']=='VALID' for r in results),'invalid':sum(r['status']=='INVALID' for r in results),'errors':sum(r['status']=='ERROR' for r in results)}
    (out/'run_metadata.json').write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding='utf-8');html_report(out/'report.html',results,meta);return meta
def single(cfg,seed,rng,out,open_it=True):
    out.mkdir(parents=True,exist_ok=True);plan=generate_plan(seed,cfg,rng);res=analyze_plan(plan,cfg,True);jp=out/f'seed_{seed}.json';sp=out/f'seed_{seed}.svg';jp.write_text(json.dumps({'plan':plan,'analysis':res},indent=2,ensure_ascii=False),encoding='utf-8');render_svg(plan,res,sp);print(json.dumps(res,indent=2,ensure_ascii=False));print(f'\nPlan : {jp}\nAperçu : {sp}');open_it and webbrowser.open(sp.resolve().as_uri());return res
def gui(config_path):
    import tkinter as tk
    from tkinter import ttk,filedialog,messagebox
    import threading
    cfg=load_config(config_path);w=tk.Tk();w.title('Mega Seed Validator');w.geometry('800x650');f=ttk.Frame(w,padding=18);f.pack(fill='both',expand=True);ttk.Label(f,text='Mega Seed Validator',font=('Segoe UI',20,'bold')).grid(row=0,column=0,columnspan=3,sticky='w');ttk.Label(f,text='Préfiltre externe rapide. La parité exacte avec Roblox nécessite le RNG portable fourni.',wraplength=730).grid(row=1,column=0,columnspan=3,sticky='w',pady=(4,16))
    vals={k:tk.StringVar(value=v) for k,v in {'start':'1','count':'1000','workers':'0','top':'100','render':'20','rng':'portable','output':str((Path.cwd()/'seed_results').resolve()),'one':'1'}.items()};fields=[('Seed de départ','start'),('Nombre de seeds','count'),('Workers (0 = auto)','workers'),('Top conservées','top'),('Aperçus SVG','render')]
    for row,(label,key) in enumerate(fields,2):ttk.Label(f,text=label).grid(row=row,column=0,sticky='w',pady=4);ttk.Entry(f,textvariable=vals[key],width=24).grid(row=row,column=1,sticky='w')
    ttk.Label(f,text='RNG').grid(row=7,column=0,sticky='w');ttk.Combobox(f,textvariable=vals['rng'],values=('portable','python'),state='readonly',width=21).grid(row=7,column=1,sticky='w');ttk.Label(f,text='Dossier de sortie').grid(row=8,column=0,sticky='w');ttk.Entry(f,textvariable=vals['output'],width=55).grid(row=8,column=1,sticky='we');ttk.Button(f,text='Choisir',command=lambda:vals['output'].set(filedialog.askdirectory(initialdir=vals['output'].get()) or vals['output'].get())).grid(row=8,column=2,padx=6)
    prog=tk.DoubleVar(value=0);ttk.Progressbar(f,variable=prog,maximum=100).grid(row=9,column=0,columnspan=3,sticky='we',pady=(18,4));log=tk.Text(f,height=12);log.grid(row=10,column=0,columnspan=3,sticky='nsew');f.columnconfigure(1,weight=1);f.rowconfigure(10,weight=1)
    def append(s):log.insert('end',s+'\n');log.see('end')
    def job():
        try:
            out=Path(vals['output'].get())
            def update(done,total,r):
                if done==1 or done%max(1,total//100)==0 or done==total:w.after(0,lambda:prog.set(done*100/total));w.after(0,lambda:append(f'{done}/{total} — seed {r["seed"]} — {r["status"]} — {r["score"]:.1f}'))
            meta=run_batch(cfg,int(vals['start'].get()),int(vals['count'].get()),int(vals['workers'].get()),vals['rng'].get(),out,int(vals['top'].get()),int(vals['render'].get()),update);w.after(0,lambda:append(json.dumps(meta,indent=2,ensure_ascii=False)));w.after(0,lambda:messagebox.showinfo('Terminé',f'Rapport :\n{out/"report.html"}'));w.after(0,lambda:webbrowser.open((out/'report.html').resolve().as_uri()))
        except Exception:
            err=traceback.format_exc();w.after(0,lambda:append(err));w.after(0,lambda:messagebox.showerror('Erreur',err))
    controls=ttk.Frame(f);controls.grid(row=11,column=0,columnspan=3,sticky='we',pady=12);ttk.Button(controls,text='Lancer le batch',command=lambda:threading.Thread(target=job,daemon=True).start()).pack(side='left');ttk.Label(controls,text='Seed unique :').pack(side='left',padx=(24,6));ttk.Entry(controls,textvariable=vals['one'],width=14).pack(side='left')
    def one():
        try:r=single(cfg,int(vals['one'].get()),vals['rng'].get(),Path(vals['output'].get())/'single',True);append(f'Seed {r["seed"]}: {r["status"]} — {r["score"]}')
        except Exception:messagebox.showerror('Erreur',traceback.format_exc())
    ttk.Button(controls,text='Vérifier et afficher',command=one).pack(side='left',padx=6);w.mainloop()
def parser():
    p=argparse.ArgumentParser(description='Lance et valide les seeds du générateur procédural MegaRoblox.');p.add_argument('--config',type=Path,default=Path(__file__).resolve().parent/'config'/'current_project.json');s=p.add_subparsers(dest='command',required=True);b=s.add_parser('batch');b.add_argument('--start',type=int,default=1);b.add_argument('--count',type=int,default=1000);b.add_argument('--workers',type=int,default=0);b.add_argument('--rng',choices=('portable','python'),default='portable');b.add_argument('--output',type=Path,default=Path('seed_results'));b.add_argument('--top',type=int,default=100);b.add_argument('--render-top',type=int,default=20);o=s.add_parser('seed');o.add_argument('seed',type=int);o.add_argument('--rng',choices=('portable','python'),default='portable');o.add_argument('--output',type=Path,default=Path('seed_results')/'single');o.add_argument('--no-open',action='store_true');s.add_parser('gui');return p
def main():
    a=parser().parse_args();cfg=load_config(a.config)
    if a.command=='gui':gui(a.config);return 0
    if a.command=='seed':single(cfg,a.seed,a.rng,a.output,not a.no_open);return 0
    def progress(done,total,r):
        if done==1 or done%max(1,total//20)==0 or done==total:print(f'[{done:>6}/{total}] seed={r["seed"]} {r["status"]} score={r["score"]:.1f}')
    meta=run_batch(cfg,a.start,a.count,a.workers,a.rng,a.output,a.top,a.render_top,progress);print(json.dumps(meta,indent=2,ensure_ascii=False));print('Rapport :',(a.output/'report.html').resolve());return 0
if __name__=='__main__':raise SystemExit(main())
