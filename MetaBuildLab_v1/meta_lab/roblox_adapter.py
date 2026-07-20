from __future__ import annotations

import copy
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .catalog import SUPPORTED_SCHEMA_VERSION, validate_catalog
from .evidence import capture_source_snapshot, find_project_root


PERK_DEFINITION_FIELDS = {"Id", "Name", "Description", "Icon", "Variants"}
PERK_VARIANT_FIELDS = {"Description", "Stats"}
ITEM_DEFINITION_FIELDS = {
    "Id", "Name", "Description", "Icon", "Accent", "Rarity",
    "PoisonChancePerStack", "PoisonTickDamage", "PoisonTickInterval",
    "PoisonBaseDuration", "PoisonFlashColor", "StatsPerStack",
    "StatsPerChestOpened", "MoveSpeedPercentPerStack",
    "AttackSpeedPercentPerStack", "ProjectileSpeedPercentPerStack",
    "StepScorePercentPerStack", "KillsPerMaxHealth",
    "KillThresholdStackMultiplier", "MaxHealthPerThreshold",
}


def _reject_unknown_fields(
    value: dict[str, Any], supported: set[str], path: str
) -> None:
    unknown = sorted(set(value) - supported)
    if unknown:
        raise ValueError(
            f"Champs Roblox non modelises dans {path} : "
            + ", ".join(unknown)
        )


def _numeric_array(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if not isinstance(value, dict):
        return []
    pairs=[]
    for key,child in value.items():
        try:
            pairs.append((int(key),child))
        except (TypeError,ValueError):
            continue
    return [child for _,child in sorted(pairs)]


def _stats_effects(stats: dict[str,Any] | None, trigger: str = "OnAcquire", per_stack: bool = False) -> list[dict[str,Any]]:
    effects=[]
    for stat,value in (stats or {}).items():
        effect={
            "trigger":trigger,
            "type":"stat",
            "stat":stat,
            "operation":"add",
        }
        effect["value_per_stack" if per_stack else "value"] = value
        effects.append(effect)
    return effects


def import_roblox_snapshot(base_catalog: dict[str,Any], raw_snapshot: dict[str,Any]) -> dict[str,Any]:
    result=copy.deepcopy(base_catalog)
    combat=raw_snapshot.get("CombatConfig",{})
    perks_raw=raw_snapshot.get("Perks",{})
    items_raw=raw_snapshot.get("RunItemConfig",{})
    build_meta=raw_snapshot.get("BuildMetaConfig")

    if not isinstance(build_meta, dict):
        raise ValueError(
            "BuildMetaConfig manque dans l'export Roblox. "
            "Utiliser la version V2 de BuildCatalogExporter."
        )
    if int(build_meta.get("SchemaVersion", 0)) != 1:
        raise ValueError("Version BuildMetaConfig non supportee")

    characters=_numeric_array(build_meta.get("Characters",{}))
    weapons=_numeric_array(build_meta.get("Weapons",{}))
    if not characters or not weapons:
        raise ValueError(
            "BuildMetaConfig doit exposer au moins un personnage et une arme"
        )
    result["characters"]=characters
    result["weapons"]=weapons

    # Compatibilite : les valeurs Fireball restent resynchronisees depuis
    # CombatConfig, qui demeure la source gameplay autoritaire.
    fireball=next(
        (weapon for weapon in result.get("weapons",[]) if weapon.get("id")=="fireball"),
        None,
    )
    if fireball is not None:
        base=fireball["base"]
        mapping={
            "FireballDamage":"damage",
            "FireballCooldown":"cooldown",
            "FireballRange":"range",
            "FireballSpeed":"speed",
            "FireballLifetime":"lifetime",
            "FireballHitRadius":"hit_radius",
        }
        for source,target in mapping.items():
            if source in combat:
                base[target]=combat[source]
    settings=result["settings"]
    settings["xp_base"]=combat.get("LevelBaseXp",settings.get("xp_base",6))
    settings["xp_increase_per_level"]=combat.get("LevelXpIncrease",settings.get("xp_increase_per_level",6))
    settings["xp_per_kill"]=combat.get("XpPerGem",settings.get("xp_per_kill",1))
    settings["coin_drop_chance"]=combat.get("CoinDropChance",settings.get("coin_drop_chance",.25))

    for scenario in result.get("run_scenarios",[]):
        scenario["wave_duration"]=combat.get("WaveDuration",scenario["wave_duration"])
        scenario["calm_duration"]=combat.get("DifficultyCalmDuration",scenario["calm_duration"])
        scenario["calm_max_alive"]=combat.get("DifficultyCalmMaxAlive",scenario["calm_max_alive"])
        scenario["wave_base_max_alive"]=combat.get("WaveBaseMaxAlive",scenario["wave_base_max_alive"])
        scenario["wave_max_alive_increase"]=combat.get("WaveMaxAliveIncrease",scenario["wave_max_alive_increase"])
        scenario["spawn_batch_base"]=combat.get("WaveSpawnBatchBase",scenario["spawn_batch_base"])
        scenario["spawn_batch_increase_every"]=combat.get("WaveSpawnBatchIncreaseEvery",scenario["spawn_batch_increase_every"])
        scenario["spawn_batch_max"]=combat.get("WaveSpawnBatchMax",scenario["spawn_batch_max"])
        scenario["spawn_interval"]=combat.get("MonsterSpawnInterval",scenario["spawn_interval"])
        scenario["spawn_interval_min"]=combat.get("MonsterSpawnIntervalMin",scenario["spawn_interval_min"])
        scenario["spawn_interval_decrease_per_wave"]=combat.get("MonsterSpawnIntervalDecreasePerWave",scenario["spawn_interval_decrease_per_wave"])
        scenario["monster_max_alive"]=combat.get("MonsterMaxAlive",scenario["monster_max_alive"])

    normal=result["enemies"]["normal"]
    normal["health"]=combat.get("MonsterHealth",normal["health"])
    normal["damage"]=combat.get("MonsterAttackDamage",normal["damage"])
    normal["attack_cooldown"]=combat.get("MonsterAttackCooldown",normal["attack_cooldown"])
    normal["speed"]=combat.get("MonsterWalkSpeed",normal["speed"])
    elite=result["enemies"]["elite"]
    elite["health"]=normal["health"]*combat.get("EliteMonsterHealthMultiplier",2)
    elite["damage"]=normal["damage"]*combat.get("EliteMonsterDamageMultiplier",2)

    # Raretés et perks.
    rarities=perks_raw.get("Rarities",{})
    for rarity,data in rarities.items():
        if rarity in settings["rarities"] and isinstance(data,dict):
            settings["rarities"][rarity]["weight"]=data.get("Weight",settings["rarities"][rarity]["weight"])
    imported_perks=[]
    for definition_index, definition in enumerate(
        _numeric_array(perks_raw.get("Definitions",{})), 1
    ):
        _reject_unknown_fields(
            definition,
            PERK_DEFINITION_FIELDS,
            f"Perks.Definitions[{definition_index}]",
        )
        variants={}
        for rarity,variant in (definition.get("Variants",{}) or {}).items():
            _reject_unknown_fields(
                variant,
                PERK_VARIANT_FIELDS,
                f"Perks.Definitions[{definition_index}].Variants.{rarity}",
            )
            variants[rarity]={
                "effects":_stats_effects(variant.get("Stats",{}),"OnAcquire",False)
            }
        imported_perks.append({
            "id":definition.get("Id",""),
            "name":definition.get("Name",definition.get("Id","")),
            "category":"perk",
            "tags":["perk"],
            "variants":variants,
        })
    if not imported_perks:
        raise ValueError("L'export Roblox ne contient aucun perk")
    result["perks"]=imported_perks

    # Objets de run.
    imported_items=[]
    for item_id,definition in (items_raw.get("Definitions",{}) or {}).items():
        _reject_unknown_fields(
            definition,
            ITEM_DEFINITION_FIELDS,
            f"RunItemConfig.Definitions.{item_id}",
        )
        effects=[]
        effects.extend(_stats_effects(definition.get("StatsPerStack",{}),"OnAcquire",True))
        legacy_stats={}
        for source,stat in (
            ("MoveSpeedPercentPerStack","MoveSpeedPercent"),
            ("AttackSpeedPercentPerStack","AttackSpeedPercent"),
            ("ProjectileSpeedPercentPerStack","ProjectileSpeedPercent"),
            ("StepScorePercentPerStack","StepScorePercent"),
        ):
            if source in definition:
                legacy_stats[stat]=definition[source]
        effects.extend(_stats_effects(legacy_stats,"OnAcquire",True))
        effects.extend(_stats_effects(definition.get("StatsPerChestOpened",{}),"OnChestOpened",True))
        if "PoisonChancePerStack" in definition:
            effects.append({
                "trigger":"OnHit",
                "type":"apply_status",
                "status":"poison",
                "chance_per_stack":definition.get("PoisonChancePerStack",0),
            })
            status=result.setdefault("statuses",{}).setdefault("poison",{})
            status.update({
                "id":"poison",
                "name":"Poison",
                "tick_damage":definition.get("PoisonTickDamage",4),
                "tick_interval":definition.get("PoisonTickInterval",1),
                "base_duration":definition.get("PoisonBaseDuration",4),
                "stacking":"independent",
            })
        if "KillsPerMaxHealth" in definition:
            effects.append({
                "trigger":"OnKill",
                "type":"counter_reward",
                "counter":"kills",
                "threshold":definition.get("KillsPerMaxHealth",50),
                "threshold_stack_multiplier":definition.get("KillThresholdStackMultiplier",1),
                "reward":{
                    "type":"stat",
                    "stat":"MaxHealthBonus",
                    "operation":"add",
                    "value":definition.get("MaxHealthPerThreshold",1),
                },
            })
        tags=["item"]
        if "PoisonChancePerStack" in definition: tags.extend(["poison","on_hit"])
        if any(effect.get("stat") in ("CritChance","CritMultiplierBonus") for effect in effects): tags.append("crit")
        if any(effect.get("stat") in ("DamagePercent","FlatDamage") for effect in effects): tags.append("damage")
        imported_items.append({
            "id":definition.get("Id",item_id),
            "name":definition.get("Name",item_id),
            "category":"item",
            "rarity":definition.get("Rarity","Common"),
            "tags":sorted(set(tags)),
            "effects":effects,
        })
    if not imported_items:
        raise ValueError("L'export Roblox ne contient aucun objet de run")
    result["items"]=imported_items

    result["schema_version"]=SUPPORTED_SCHEMA_VERSION
    result.setdefault("meta",{})["roblox_exported_at"]=raw_snapshot.get("ExportedAt")
    result["meta"]["adapter"]="roblox_snapshot_v2"
    return result


def import_file(base_catalog_path: Path, export_path: Path, output_path: Path) -> None:
    base=json.loads(base_catalog_path.read_text(encoding="utf-8"))
    raw=json.loads(export_path.read_text(encoding="utf-8"))
    merged=import_roblox_snapshot(base,raw)
    project_root=find_project_root(base_catalog_path)
    merged.setdefault("meta",{})["source_snapshot"]=capture_source_snapshot(project_root)
    merged["meta"]["snapshot_date"]=datetime.now(timezone.utc).date().isoformat()
    merged["meta"]["commit"]=merged["meta"]["source_snapshot"].get("commit")
    validate_catalog(merged)
    output_path.parent.mkdir(parents=True,exist_ok=True)
    output_path.write_text(json.dumps(merged,ensure_ascii=False,indent=2),encoding="utf-8")
