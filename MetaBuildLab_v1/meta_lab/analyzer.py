
from __future__ import annotations
import csv
import json
import random
import sqlite3
import statistics
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Callable

from .engine import draft_build, analytical_evaluate, event_simulate
from .model import Build


def minimum_coverage_candidates(catalog: dict[str, Any]) -> int:
    character_count = max(1, len(catalog["characters"]))
    weapon_count = max(1, len(catalog["weapons"]))
    max_weapons = min(
        4,
        int(catalog["settings"].get("max_simultaneous_weapons", 4)),
    )
    profile_weapon_cap = max(
        1,
        max(
            min(
                weapon_count,
                int(profile.get("weapon_slots", max_weapons)),
                max_weapons,
            )
            for profile in catalog["skill_profiles"].values()
        ),
    )
    requirements = [
        character_count,
        character_count * profile_weapon_cap * weapon_count,
        len(catalog["perks"]) * len(catalog["settings"]["rarities"]),
        len(catalog["items"]),
        len(catalog.get("relics", [])),
        len(catalog.get("curses", [])),
    ]
    return max(1, *requirements)


def sampling_coverage(catalog: dict[str, Any], builds: list[Build]) -> dict[str, Any]:
    observed: dict[str, Counter[str]] = {
        "characters": Counter(),
        "weapons": Counter(),
        "perks": Counter(),
        "perk_variants": Counter(),
        "items": Counter(),
        "relics": Counter(),
        "curses": Counter(),
    }
    for build in builds:
        observed["characters"][build.character_id] += 1
        for weapon_id in build.weapon_levels:
            observed["weapons"][weapon_id] += 1
        for acquisition in build.acquisitions:
            if acquisition.category == "perk":
                observed["perks"][acquisition.content_id] += 1
                observed["perk_variants"][
                    f"{acquisition.content_id}:{acquisition.rarity}"
                ] += 1
            elif acquisition.category in ("item", "relic", "curse"):
                observed[acquisition.category + "s"][acquisition.content_id] += 1

    rarity_ids = list(catalog["settings"]["rarities"])
    expected = {
        "characters": [entry["id"] for entry in catalog["characters"]],
        "weapons": [entry["id"] for entry in catalog["weapons"]],
        "perks": [entry["id"] for entry in catalog["perks"]],
        "perk_variants": [
            f"{entry['id']}:{rarity}"
            for entry in catalog["perks"]
            for rarity in rarity_ids
        ],
        "items": [entry["id"] for entry in catalog["items"]],
        "relics": [entry["id"] for entry in catalog.get("relics", [])],
        "curses": [entry["id"] for entry in catalog.get("curses", [])],
    }

    groups: dict[str, Any] = {}
    totals_expected = 0
    totals_seen = 0
    for group, identifiers in expected.items():
        missing = sorted(identifier for identifier in identifiers if observed[group][identifier] <= 0)
        seen = len(identifiers) - len(missing)
        totals_expected += len(identifiers)
        totals_seen += seen
        groups[group] = {
            "expected": len(identifiers),
            "observed": seen,
            "coverage_rate": (
                seen / len(identifiers) if identifiers else 1.0
            ),
            "minimum_presence": min(
                (observed[group][identifier] for identifier in identifiers),
                default=0,
            ),
            "missing": missing,
        }
    return {
        "complete": totals_seen == totals_expected,
        "coverage_rate": totals_seen / max(1, totals_expected),
        "groups": groups,
    }

def percentile_rank(values: list[float], value: float) -> float:
    if not values:
        return 0.5
    return sum(1 for v in values if v <= value) / len(values)

def mean_or_zero(values):
    return statistics.fmean(values) if values else 0.0

def stdev_or_zero(values):
    return statistics.pstdev(values) if len(values)>1 else 0.0

def aggregate_event_results(results):
    if not results:
        return {}
    fields = [
        "survival_seconds","damage","kills","elite_kills","level","xp","coins",
        "chests","health_remaining","max_health","damage_taken","healing",
        "projectile_events"
    ]
    agg = {f:mean_or_zero([float(getattr(r,f)) for r in results]) for f in fields}
    agg.update({
        f"{f}_std":stdev_or_zero([float(getattr(r,f)) for r in results])
        for f in fields
    })
    agg["survival_rate"] = mean_or_zero([1.0 if r.survived else 0.0 for r in results])
    agg["budget_saturation_rate"] = mean_or_zero([
        1.0 if r.event_budget_saturated else 0.0 for r in results
    ])
    return agg

def normalize_scores(builds: list[Build], profiles: list[str]) -> None:
    metrics = defaultdict(list)
    for build in builds:
        for profile in profiles:
            data = build.event_results.get(profile)
            if not data:
                continue
            for key in ("damage","kills","level","survival_rate","health_remaining"):
                metrics[(profile,key)].append(float(data.get(key,0)))
    for build in builds:
        profile_scores = []
        for profile in profiles:
            data = build.event_results.get(profile)
            if not data:
                continue
            offense = (
                .55*percentile_rank(metrics[(profile,"damage")],data["damage"]) +
                .45*percentile_rank(metrics[(profile,"kills")],data["kills"])
            )
            survival = (
                .7*data["survival_rate"] +
                .3*percentile_rank(
                    metrics[(profile,"health_remaining")],
                    data["health_remaining"]
                )
            )
            progression = percentile_rank(metrics[(profile,"level")],data["level"])
            consistency = 1-min(
                1,
                float(data.get("damage_std",0))/max(1,float(data["damage"]))
            )
            saturation_penalty = float(data.get("budget_saturation_rate",0))*.10
            score = (
                offense*.40 + survival*.35 + progression*.15 +
                consistency*.10 - saturation_penalty
            )*100
            profile_scores.append(score)
        if profile_scores:
            robustness = min(profile_scores)/max(1,max(profile_scores))
            build.meta_score = max(
                0,
                min(100,statistics.fmean(profile_scores)*(.85+.15*robustness))
            )
        else:
            build.meta_score = 0

def analytical_mean_power(
    catalog: dict[str, Any],
    build: Build,
    profiles: list[str],
    cache: dict[str, float] | None = None,
) -> float:
    cache_key = build.signature()
    if cache is not None and cache_key in cache:
        return cache[cache_key]
    values = [
        analytical_evaluate(catalog,build,profile)["raw_power"]
        for profile in profiles
    ]
    result = mean_or_zero(values)
    if cache is not None:
        cache[cache_key] = result
    return result

def ablate_build(build: Build, removed_components: set[str]) -> Build:
    acquisitions = [
        acquisition
        for acquisition in build.acquisitions
        if f"{acquisition.category}:{acquisition.content_id}" not in removed_components
    ]
    weapon_levels = {
        weapon_id:level
        for weapon_id,level in build.weapon_levels.items()
        if f"weapon:{weapon_id}" not in removed_components
    }
    return Build(
        build_id=build.build_id+"_ablated",
        character_id=build.character_id,
        weapon_levels=weapon_levels,
        acquisitions=acquisitions,
        profile_origin=build.profile_origin,
        generation_seed=build.generation_seed,
    )

def component_impact(
    catalog: dict[str, Any],
    builds: list[Build],
    profiles: list[str],
    power_cache: dict[str, float] | None = None,
) -> list[dict[str, Any]]:
    all_components = sorted(
        component
        for component in set().union(*(build.component_ids() for build in builds))
        if component.startswith(("perk:","item:","relic:","curse:"))
    )
    rows = []
    for component in all_components:
        carriers = [build for build in builds if component in build.component_ids()]
        if len(carriers)<2:
            continue
        deltas=[]
        full_values=[]
        ablated_values=[]
        for build in carriers[:40]:
            full=analytical_mean_power(catalog,build,profiles,power_cache)
            ablated=analytical_mean_power(
                catalog,
                ablate_build(build,{component}),
                profiles,
                power_cache,
            )
            full_values.append(full)
            ablated_values.append(ablated)
            deltas.append((full-ablated)/max(1,abs(ablated))*100)
        rows.append({
            "component":component,
            "presence":len(carriers),
            "presence_rate":len(carriers)/max(1,len(builds)),
            "mean_with":mean_or_zero(full_values),
            "mean_without":mean_or_zero(ablated_values),
            "impact":mean_or_zero(deltas),
            "method":"analytical_ablation_percent"
        })
    return sorted(rows,key=lambda row:row["impact"],reverse=True)

def pair_synergies(
    catalog: dict[str, Any],
    builds: list[Build],
    profiles: list[str],
    min_presence: int = 3,
    power_cache: dict[str, float] | None = None,
) -> list[dict[str, Any]]:
    components = sorted(
        component
        for component in set().union(*(build.component_ids() for build in builds))
        if component.startswith(("perk:","item:","relic:","curse:"))
    )
    rows = []
    for index,a in enumerate(components):
        for b in components[index+1:]:
            carriers=[
                build for build in builds
                if a in build.component_ids() and b in build.component_ids()
            ]
            if len(carriers)<min_presence:
                continue
            interactions=[]
            observed=[]
            expected=[]
            for build in carriers[:24]:
                full=analytical_mean_power(catalog,build,profiles,power_cache)
                no_a=analytical_mean_power(
                    catalog,ablate_build(build,{a}),profiles,power_cache
                )
                no_b=analytical_mean_power(
                    catalog,ablate_build(build,{b}),profiles,power_cache
                )
                no_both=analytical_mean_power(
                    catalog,ablate_build(build,{a,b}),profiles,power_cache
                )
                interaction=full-no_a-no_b+no_both
                interactions.append(interaction/max(1,abs(no_both))*100)
                observed.append(full)
                expected.append(no_a+no_b-no_both)
            rows.append({
                "a":a,
                "b":b,
                "presence":len(carriers),
                "observed":mean_or_zero(observed),
                "expected_additive":mean_or_zero(expected),
                "synergy":mean_or_zero(interactions),
                "method":"pair_ablation_interaction_percent"
            })
    return sorted(rows,key=lambda row:row["synergy"],reverse=True)

def build_comments(build: Build, component_rows, synergy_rows, median_score: float) -> list[str]:
    comments = []
    if build.meta_score >= 90:
        comments.append("Alerte : combinaison dominante dans l'échantillon analysé.")
    elif build.meta_score >= 75:
        comments.append("Build supérieur et robuste dans les scénarios testés.")
    elif build.meta_score <= 25:
        comments.append("Build faible ou trop situationnel dans le modèle actuel.")

    components = build.component_ids()
    relevant_impacts = [r for r in component_rows if r["component"] in components]
    positive = sorted(relevant_impacts,key=lambda r:r["impact"],reverse=True)[:3]
    negative = sorted(relevant_impacts,key=lambda r:r["impact"])[:2]
    if positive and positive[0]["impact"]>2:
        comments.append(
            "Piliers estimés : " +
            ", ".join(
                f"{r['component']} (+{r['impact']:.1f})"
                for r in positive if r["impact"]>0
            )
        )
    if negative and negative[0]["impact"]<-2:
        comments.append(
            "Faiblesses estimées : " +
            ", ".join(
                f"{r['component']} ({r['impact']:.1f})"
                for r in negative if r["impact"]<0
            )
        )

    relevant_synergies = [
        r for r in synergy_rows
        if r["a"] in components and r["b"] in components and r["synergy"]>2
    ]
    if relevant_synergies:
        top = relevant_synergies[0]
        comments.append(
            f"Synergie observée : {top['a']} + {top['b']} "
            f"({top['synergy']:+.1f})."
        )

    profile_scores = {
        p:data.get("survival_rate",0)
        for p,data in build.event_results.items()
    }
    if profile_scores and max(profile_scores.values())-min(profile_scores.values())>.35:
        comments.append("Forte sensibilité au niveau d'adresse du joueur.")

    saturation = max(
        (data.get("budget_saturation_rate",0) for data in build.event_results.values()),
        default=0
    )
    if saturation>0:
        comments.append(
            "Le plafond d'événements projectile est atteint : "
            "puissance extrême à confirmer dans Roblox."
        )
    if build.meta_score > median_score+15:
        comments.append(
            "Écart important à la médiane : candidat prioritaire "
            "pour un test d'équilibrage."
        )
    return comments or ["Aucun signal extrême détecté dans les scénarios actuels."]

def save_sqlite(path: Path, builds: list[Build], impacts, synergies) -> None:
    conn = sqlite3.connect(path)
    conn.executescript("""
    DROP TABLE IF EXISTS builds;
    DROP TABLE IF EXISTS component_impacts;
    DROP TABLE IF EXISTS pair_synergies;
    CREATE TABLE builds(
      build_id TEXT PRIMARY KEY, signature TEXT, profile_origin TEXT,
      meta_score REAL, analytical_json TEXT, event_json TEXT, comments_json TEXT
    );
    CREATE TABLE component_impacts(
      component TEXT, presence INTEGER, presence_rate REAL, mean_with REAL,
      mean_without REAL, impact REAL
    );
    CREATE TABLE pair_synergies(
      a TEXT, b TEXT, presence INTEGER, observed REAL,
      expected_additive REAL, synergy REAL
    );
    """)
    for build in builds:
        conn.execute(
            "INSERT INTO builds VALUES(?,?,?,?,?,?,?)",
            (
                build.build_id,build.signature(),build.profile_origin,
                build.meta_score,
                json.dumps(build.analytical,ensure_ascii=False),
                json.dumps(build.event_results,ensure_ascii=False),
                json.dumps(build.comments,ensure_ascii=False)
            )
        )
    for row in impacts:
        conn.execute(
            "INSERT INTO component_impacts VALUES(?,?,?,?,?,?)",
            (
                row["component"],row["presence"],row["presence_rate"],
                row["mean_with"],row["mean_without"],row["impact"]
            )
        )
    for row in synergies:
        conn.execute(
            "INSERT INTO pair_synergies VALUES(?,?,?,?,?,?)",
            (
                row["a"],row["b"],row["presence"],row["observed"],
                row["expected_additive"],row["synergy"]
            )
        )
    conn.commit()
    conn.close()

def run_analysis(
    catalog: dict[str, Any],
    output: Path,
    candidates: int = 600,
    top_event: int = 40,
    repetitions: int = 8,
    seed: int = 1337,
    profiles: list[str] | None = None,
    progress: Callable[[str],None] | None = None,
    evidence: dict[str, Any] | None = None,
    require_complete_coverage: bool = True,
) -> dict[str, Any]:
    required_candidates = minimum_coverage_candidates(catalog)
    if require_complete_coverage and candidates < required_candidates:
        raise ValueError(
            "Analyse insuffisante pour couvrir le catalogue : "
            f"{candidates} candidats demandes, {required_candidates} requis. "
            "Augmenter --candidates ou utiliser --allow-partial-coverage "
            "uniquement pour un diagnostic rapide non probant."
        )
    output.mkdir(parents=True,exist_ok=True)
    profiles = profiles or list(catalog["skill_profiles"])
    started = time.perf_counter()

    def log(message: str) -> None:
        if progress:
            progress(message)

    builds_by_signature: dict[str,Build] = {}
    drafted_builds: list[Build] = []
    for index in range(candidates):
        profile = profiles[index%len(profiles)]
        build = draft_build(
            catalog, profile, seed, index + 1, coverage_draft=True
        )
        drafted_builds.append(build)
        build.analytical = {
            profile_id:analytical_evaluate(catalog,build,profile_id)
            for profile_id in profiles
        }
        signature = build.signature()
        previous = builds_by_signature.get(signature)
        if previous is None:
            builds_by_signature[signature]=build
        else:
            old = mean_or_zero([
                values["raw_power"] for values in previous.analytical.values()
            ])
            new = mean_or_zero([
                values["raw_power"] for values in build.analytical.values()
            ])
            if new>old:
                builds_by_signature[signature]=build
        if (index+1)%max(1,candidates//10)==0:
            log(f"Draft analytique : {index+1}/{candidates}")

    builds = list(builds_by_signature.values())
    builds.sort(
        key=lambda build:mean_or_zero([
            values["raw_power"] for values in build.analytical.values()
        ]),
        reverse=True
    )

    selected = builds[:min(top_event,len(builds))]
    if len(builds)>top_event:
        rng=random.Random(seed+99)
        pool=builds[top_event:]
        selected.extend(
            rng.sample(
                pool,
                k=min(max(10,top_event//3),len(pool))
            )
        )
    log(f"Confirmation événementielle de {len(selected)} builds.")

    scenarios=catalog["run_scenarios"]
    for build_index,build in enumerate(selected,1):
        for profile in profiles:
            results=[]
            for repetition in range(repetitions):
                chooser=random.Random(
                    seed+build_index*1009+repetition*37+sum(map(ord,profile))
                )
                cursor=chooser.random()*sum(
                    float(scenario.get("weight",1))
                    for scenario in scenarios
                )
                scenario=scenarios[-1]
                for candidate_scenario in scenarios:
                    cursor-=float(candidate_scenario.get("weight",1))
                    if cursor<=0:
                        scenario=candidate_scenario
                        break
                result=event_simulate(
                    catalog,build,profile,scenario,
                    seed+build_index*100000+repetition*101+sum(map(ord,profile)),
                    keep_timeline=(
                        build_index==1 and repetition==0 and
                        profile==profiles[-1]
                    )
                )
                results.append(result)
            build.event_results[profile]=aggregate_event_results(results)
            timeline=next((result.timeline for result in results if result.timeline),[])
            if timeline:
                build.event_results[profile]["timeline"]=timeline
        if build_index%max(1,len(selected)//10)==0:
            log(f"Simulation événementielle : {build_index}/{len(selected)}")

    normalize_scores(selected,profiles)
    selected.sort(key=lambda build:build.meta_score,reverse=True)
    # Une tranche repartie sur tout le classement limite le biais des seuls
    # meilleurs builds sans rendre l'ablation quadratique hors de controle.
    if len(builds) <= 240:
        evidence_builds = builds
    else:
        evidence_builds = [
            builds[round(index * (len(builds) - 1) / 239)]
            for index in range(240)
        ]
    power_cache: dict[str, float] = {}
    impacts=component_impact(
        catalog,evidence_builds,profiles,power_cache
    )
    synergies=pair_synergies(
        catalog,evidence_builds,profiles,
        min_presence=max(2,min(6,len(evidence_builds)//30)),
        power_cache=power_cache,
    )
    median_score=statistics.median(
        [build.meta_score for build in selected]
    ) if selected else 0
    for build in selected:
        build.comments=build_comments(
            build,impacts,synergies,median_score
        )

    coverage = sampling_coverage(catalog, drafted_builds)
    coverage["minimum_candidates"] = required_candidates
    if require_complete_coverage and not coverage["complete"]:
        missing = [
            f"{group}: {', '.join(values['missing'])}"
            for group, values in coverage["groups"].items()
            if values["missing"]
        ]
        raise RuntimeError(
            "Defaut interne de couverture du catalogue : " + "; ".join(missing)
        )
    result_payload = {
        "meta":{
            "candidates_requested":candidates,
            "unique_candidates":len(builds),
            "event_builds":len(selected),
            "repetitions":repetitions,
            "profiles":profiles,
            "seed":seed,
            "elapsed_seconds":round(time.perf_counter()-started,3),
            "evidence": evidence or {},
            "sampling_coverage": coverage,
            "interpretation": "theoretical_not_calibrated_against_live_runs",
        },
        "builds":[{
            "build_id":build.build_id,
            "signature":build.signature(),
            "profile_origin":build.profile_origin,
            "meta_score":round(build.meta_score,3),
            "analytical":build.analytical,
            "event_results":build.event_results,
            "comments":build.comments
        } for build in selected],
        "component_impacts":impacts,
        "pair_synergies":synergies
    }
    (output/"meta_results.json").write_text(
        json.dumps(result_payload,ensure_ascii=False,indent=2),
        encoding="utf-8"
    )

    with (output/"builds.csv").open(
        "w",newline="",encoding="utf-8-sig"
    ) as handle:
        writer=csv.writer(handle)
        writer.writerow([
            "rank","build_id","meta_score","profile_origin",
            "signature","comments"
        ])
        for rank,build in enumerate(selected,1):
            writer.writerow([
                rank,build.build_id,round(build.meta_score,3),
                build.profile_origin,build.signature(),
                " | ".join(build.comments)
            ])

    with (output/"component_impacts.csv").open(
        "w",newline="",encoding="utf-8-sig"
    ) as handle:
        fields=[
            "component","presence","presence_rate",
            "mean_with","mean_without","impact"
        ]
        writer=csv.DictWriter(handle,fieldnames=fields)
        writer.writeheader()
        for row in impacts:
            writer.writerow({key:row[key] for key in fields})

    with (output/"pair_synergies.csv").open(
        "w",newline="",encoding="utf-8-sig"
    ) as handle:
        fields=[
            "a","b","presence","observed",
            "expected_additive","synergy"
        ]
        writer=csv.DictWriter(handle,fieldnames=fields)
        writer.writeheader()
        for row in synergies:
            writer.writerow({key:row[key] for key in fields})

    save_sqlite(output/"meta_results.sqlite",selected,impacts,synergies)

    from .report import write_report
    write_report(
        output/"meta_report.html",
        catalog,selected,impacts,synergies,
        {
            "candidates":candidates,
            "unique":len(builds),
            "event_builds":len(selected),
            "repetitions":repetitions,
            "profiles":profiles,
            "seed":seed,
            "elapsed":round(time.perf_counter()-started,3),
            "evidence": evidence or {},
            "sampling_coverage": coverage,
        }
    )

    return {
        "output":str(output),
        "report":str(output/"meta_report.html"),
        "unique_candidates":len(builds),
        "event_builds":len(selected),
        "top_score":selected[0].meta_score if selected else 0,
        "coverage_complete":coverage["complete"],
        "coverage_rate":coverage["coverage_rate"],
        "elapsed_seconds":round(time.perf_counter()-started,3)
    }
