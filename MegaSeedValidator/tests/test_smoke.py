import importlib.util
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sv',ROOT/'seed_validator.py')
import sys
sv=importlib.util.module_from_spec(spec);sys.modules['sv']=sv;spec.loader.exec_module(sv)
cfg=sv.load_config(ROOT/'config'/'current_project.json')
a=sv.generate_plan(12345,cfg,'portable');b=sv.generate_plan(12345,cfg,'portable')
assert a['selected_layouts']==b['selected_layouts']
r=sv.analyze_plan(a,cfg)
assert r['status'] in {'VALID','INVALID'}
assert 0<=r['score']<=100
print('smoke ok',r['status'],r['score'])
