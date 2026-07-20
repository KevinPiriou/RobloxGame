
from __future__ import annotations
import html
from pathlib import Path

def esc(value):
    return html.escape(str(value))

def bar_chart(rows, value_key, label_key, title, width=980, height=420, limit=15):
    rows=rows[:limit]
    if not rows:
        return f"<h3>{esc(title)}</h3><p>Aucune donnée.</p>"
    max_value=max(abs(float(row[value_key])) for row in rows) or 1
    left=260
    top=42
    row_height=max(20,(height-top-20)/len(rows))
    parts=[
        f'<svg viewBox="0 0 {width} {height}" role="img">',
        f'<text x="16" y="26" class="chart-title">{esc(title)}</text>'
    ]
    for index,row in enumerate(rows):
        y=top+index*row_height
        value=float(row[value_key])
        bar_width=(width-left-80)*abs(value)/max_value
        x=left if value>=0 else left-bar_width
        css_class="positive" if value>=0 else "negative"
        parts.append(
            f'<text x="8" y="{y+14:.1f}" class="axis">'
            f'{esc(str(row[label_key])[:38])}</text>'
        )
        parts.append(
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_width:.1f}" '
            f'height="{row_height*.65:.1f}" class="{css_class}"/>'
        )
        value_x=left+bar_width+8 if value>=0 else x-50
        parts.append(
            f'<text x="{value_x:.1f}" y="{y+14:.1f}" class="value">'
            f'{value:+.1f}</text>'
        )
    parts.append("</svg>")
    return "".join(parts)

def line_chart(timeline,title,width=980,height=360):
    if not timeline:
        return ""
    keys=[("dps","DPS"),("alive","Ennemis vivants"),("health","PV")]
    max_values={
        key:max(float(point.get(key,0)) for point in timeline) or 1
        for key,_ in keys
    }
    colors={"dps":"#49d7ff","alive":"#ffb347","health":"#7dff9c"}
    parts=[
        f'<svg viewBox="0 0 {width} {height}">',
        f'<text x="16" y="26" class="chart-title">{esc(title)}</text>'
    ]
    plot_top=45
    plot_height=height-75
    plot_width=width-80
    duration=max(float(point["time"]) for point in timeline) or 1
    for key,label in keys:
        points=[]
        for point in timeline:
            x=50+float(point["time"])/duration*plot_width
            y=plot_top+plot_height-(
                float(point.get(key,0))/max_values[key]
            )*plot_height
            points.append(f"{x:.1f},{y:.1f}")
        parts.append(
            f'<polyline points="{" ".join(points)}" fill="none" '
            f'stroke="{colors[key]}" stroke-width="3"/>'
        )
    parts.append(
        f'<text x="55" y="{height-8}" class="axis">0 min</text>'
    )
    parts.append(
        f'<text x="{width-110}" y="{height-8}" class="axis">'
        f'{duration/60:.1f} min</text>'
    )
    for index,(key,label) in enumerate(keys):
        parts.append(
            f'<text x="{180+index*210}" y="{height-8}" '
            f'fill="{colors[key]}">{label}</text>'
        )
    parts.append("</svg>")
    return "".join(parts)

def write_report(path:Path,catalog,builds,impacts,synergies,meta):
    coverage=meta.get("sampling_coverage",{})
    coverage_rate=float(coverage.get("coverage_rate",0))*100
    source_snapshot=meta.get("evidence",{}).get("source_snapshot",{})
    source_ok=bool(source_snapshot.get("ok"))
    missing_groups=[]
    for group,data in coverage.get("groups",{}).items():
        if data.get("missing"):
            missing_groups.append(
                f"{group}: {', '.join(data['missing'][:8])}"
            )
    top_rows=[
        {"label":f"#{index+1} {build.build_id}","value":build.meta_score}
        for index,build in enumerate(builds)
    ]
    impact_rows=[
        {"label":row["component"],"value":row["impact"]}
        for row in impacts
    ]
    synergy_rows=[
        {"label":f'{row["a"]} + {row["b"]}',"value":row["synergy"]}
        for row in synergies
    ]

    timeline=""
    if builds:
        for profile,data in builds[0].event_results.items():
            if data.get("timeline"):
                timeline=line_chart(
                    data["timeline"],
                    f"Run témoin du meilleur build — {profile}"
                )
                break

    build_table=[]
    for rank,build in enumerate(builds,1):
        profile_cells=[]
        for profile,data in build.event_results.items():
            profile_cells.append(
                f"<strong>{esc(profile)}</strong>: "
                f"survie {data.get('survival_rate',0)*100:.0f}% · "
                f"dégâts {data.get('damage',0):.0f} · "
                f"kills {data.get('kills',0):.0f} · "
                f"niv. {data.get('level',0):.1f}"
            )
        build_table.append(
            f"<tr>"
            f"<td>{rank}</td>"
            f"<td><strong>{esc(build.build_id)}</strong><br>"
            f"<code>{esc(build.signature())}</code></td>"
            f"<td class='score'>{build.meta_score:.1f}</td>"
            f"<td>{'<br>'.join(profile_cells)}</td>"
            f"<td>{esc(' '.join(build.comments))}</td>"
            f"</tr>"
        )

    synergy_table="".join(
        f"<tr><td>{esc(row['a'])}</td><td>{esc(row['b'])}</td>"
        f"<td>{row['presence']}</td><td>{row['synergy']:+.2f}</td></tr>"
        for row in synergies[:100]
    )

    path.write_text(
        f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<title>Meta Build Lab</title>
<style>
:root{{--bg:#10141d;--panel:#192130;--line:#2d3a50;--text:#edf5ff;--muted:#a7b4c8}}
body{{font-family:Segoe UI,Arial,sans-serif;background:var(--bg);color:var(--text);margin:0;padding:28px}}
h1,h2{{margin:.25em 0}}
.panel{{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:18px;margin:18px 0}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}}
table{{border-collapse:collapse;width:100%;font-size:13px}}
th,td{{border-bottom:1px solid var(--line);padding:9px;vertical-align:top;text-align:left}}
th{{position:sticky;top:0;background:#202a3b}}
code{{white-space:normal;color:#c7d7ef}}
.score{{font-size:20px;font-weight:700}}
svg{{background:#121925;border-radius:10px;width:100%;height:auto}}
.chart-title{{fill:white;font-size:18px;font-weight:700}}
.axis{{fill:#a7b4c8;font-size:12px}}
.value{{fill:#edf5ff;font-size:12px}}
.positive{{fill:#45c879}}
.negative{{fill:#e15b64}}
.badge{{display:inline-block;background:#26344b;padding:5px 9px;border-radius:999px;margin:3px}}
.evidence-good{{border-color:#45c879}}
.evidence-warn{{border-color:#e2a84b}}
</style>
</head>
<body>
<h1>Meta Build Lab</h1>
<p>Analyse combinatoire analytique et confirmation événementielle sans rendu 3D.</p>

<div class="panel">
<span class="badge">Candidats : {meta['candidates']}</span>
<span class="badge">Uniques : {meta['unique']}</span>
<span class="badge">Confirmés : {meta['event_builds']}</span>
<span class="badge">Répétitions : {meta['repetitions']}</span>
<span class="badge">Profils : {esc(", ".join(meta['profiles']))}</span>
<span class="badge">Durée calcul : {meta['elapsed']} s</span>
<span class="badge">Couverture catalogue : {coverage_rate:.1f}%</span>
<span class="badge">Sources prouvées : {'oui' if source_ok else 'non'}</span>
</div>

<div class="panel {'evidence-good' if source_ok and coverage.get('complete') else 'evidence-warn'}">
<h2>Preuves de validité de l'outil</h2>
<p><strong>Modèle :</strong> théorique, déterministe et non calibré contre des runs live.</p>
<p><strong>Provenance :</strong> {'les hashes des sources Roblox correspondent au catalogue.' if source_ok else 'les sources ne sont pas prouvées ; ce rapport ne doit pas guider un équilibrage.'}</p>
<p><strong>Couverture :</strong> {coverage_rate:.1f}% des personnages, armes, perks, variantes et objets ont été injectés au moins une fois dans les candidats.</p>
<p>{esc(' | '.join(missing_groups)) if missing_groups else "Aucun contenu catalogue absent de l'échantillon analytique."}</p>
</div>

<div class="grid">
<div class="panel">
{bar_chart(top_rows,"value","label","Scores des builds")}
</div>
<div class="panel">
{bar_chart(impact_rows,"value","label","Impact marginal des composants")}
</div>
</div>

<div class="panel">
{bar_chart(synergy_rows,"value","label","Synergies de paires observées")}
</div>

<div class="panel">
{timeline}
</div>

<div class="panel">
<h2>Classement détaillé</h2>
<div style="overflow:auto;max-height:760px">
<table>
<thead>
<tr><th>#</th><th>Build</th><th>Score</th><th>Résultats</th><th>Commentaire</th></tr>
</thead>
<tbody>
{"".join(build_table)}
</tbody>
</table>
</div>
</div>

<div class="panel">
<h2>Paires combinatoires</h2>
<table>
<thead>
<tr><th>A</th><th>B</th><th>Présence</th><th>Synergie</th></tr>
</thead>
<tbody>{synergy_table}</tbody>
</table>
</div>

<div class="panel">
<h2>Limites d'interprétation</h2>
<p>
Les scores sont relatifs au catalogue, aux profils, aux scénarios et aux
hypothèses de collecte configurés. Ils donnent des indices de méta, pas une
preuve d'équilibrage définitive. Les meilleures et pires combinaisons doivent
ensuite être validées dans Roblox avec les mêmes contenus.
</p>
</div>
</body>
</html>""",
        encoding="utf-8"
    )
