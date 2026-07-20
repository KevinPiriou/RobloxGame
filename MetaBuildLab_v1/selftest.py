from pathlib import Path

from meta_lab.catalog import load_catalog
from meta_lab.engine import draft_build, analytical_evaluate, event_simulate

root=Path(__file__).resolve().parent
catalog=load_catalog(root/"catalogs"/"current_project.json")

first=draft_build(catalog,"medium",123,1)
second=draft_build(catalog,"medium",123,1)
assert first.signature()==second.signature()

analytical=analytical_evaluate(catalog,first,"medium")
assert analytical["dps"]>0
assert analytical["effective_health"]>0

scenario=dict(catalog["run_scenarios"][0])
scenario["duration_seconds"]=8
event=event_simulate(catalog,first,"medium",scenario,42,True)
assert event.survival_seconds>0

print(
    "Self-test OK",
    {
        "dps":round(analytical["dps"],2),
        "damage":round(event.damage,2),
        "kills":event.kills
    }
)
