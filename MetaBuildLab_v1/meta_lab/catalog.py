from __future__ import annotations

import json
import math
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

from .model import DEFAULT_STATS


SUPPORTED_SCHEMA_VERSION = 2

REQUIRED_TOP_LEVEL = {
    "schema_version", "meta", "settings", "skill_profiles", "characters",
    "weapons", "perks", "items", "statuses", "gems", "synergies",
    "enemies", "run_scenarios",
}

SUPPORTED_TRIGGERS = {
    "OnRunStart", "OnAcquire", "OnAttack",
    "OnProjectileCreated", "OnHit", "OnCrit", "OnBounce", "OnKill",
    "OnEliteKill", "OnDamageTaken", "OnHeal", "OnLowHealth",
    "OnChestOpened", "OnLevelUp", "OnWaveStart", "OnWaveEnd",
}

SUPPORTED_BEHAVIORS = {
    "projectile", "homing", "bounce", "pierce", "explosion",
    "persistent_area", "chain", "orbital", "summon", "contact", "beam",
    "dot", "return", "fragmentation", "distance_scaling",
    "health_scaling", "execute",
}

BEHAVIOR_MODEL_SUPPORT = {
    behavior: "analytical_and_event_proxy"
    for behavior in SUPPORTED_BEHAVIORS
}

SUPPORTED_EFFECT_TYPES = {
    "stat", "counter_reward", "apply_status", "proc_multiplier",
}

SUPPORTED_OPERATIONS = {"add", "multiply", "set", "max", "min"}
SUPPORTED_STACK_RULES = {
    "additive", "multiplicative", "diminishing", "capped", "threshold",
    "exponential", "cooldown_reduction", "charges",
}

# Direct : formule explicite dans le moteur. Proxy : coefficient theorique
# visible dans le rapport, a calibrer ensuite avec la telemetrie Roblox.
STAT_MODEL_SUPPORT = {
    **{key: "direct" for key in DEFAULT_STATS},
    "JumpPercent": "proxy",
    "MoveSpeedPercent": "proxy",
    "CollectRadius": "proxy",
    "StepScorePercent": "proxy",
    "Luck": "proxy",
    "MetaCritSynergy": "proxy",
    "MetaCoverageSynergy": "proxy",
}


def load_catalog(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    validate_catalog(data)
    return data


def _is_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def _require_number(
    value: Any, path: str, issues: list[str], minimum: float | None = None
) -> None:
    if not _is_number(value):
        issues.append(f"{path} doit etre un nombre fini")
        return
    if minimum is not None and float(value) < minimum:
        issues.append(f"{path} doit etre >= {minimum}")


def _iter_entry_effects(
    data: dict[str, Any]
) -> Iterable[tuple[str, dict[str, Any]]]:
    for group in ("characters", "items", "relics", "curses"):
        for index, entry in enumerate(data.get(group, [])):
            if not isinstance(entry, dict):
                continue
            for effect_index, effect in enumerate(entry.get("effects", [])):
                yield f"{group}[{index}].effects[{effect_index}]", effect
    for index, perk in enumerate(data.get("perks", [])):
        if not isinstance(perk, dict):
            continue
        for rarity, variant in perk.get("variants", {}).items():
            if not isinstance(variant, dict):
                continue
            for effect_index, effect in enumerate(variant.get("effects", [])):
                yield (
                    f"perks[{index}].variants.{rarity}.effects[{effect_index}]",
                    effect,
                )
    for index, weapon in enumerate(data.get("weapons", [])):
        if not isinstance(weapon, dict):
            continue
        for level_index, level in enumerate(weapon.get("levels", [])):
            if not isinstance(level, dict):
                continue
            for effect_index, effect in enumerate(level.get("effects", [])):
                yield (
                    f"weapons[{index}].levels[{level_index}].effects[{effect_index}]",
                    effect,
                )
    for index, synergy in enumerate(data.get("synergies", [])):
        if not isinstance(synergy, dict):
            continue
        for effect_index, effect in enumerate(synergy.get("effects", [])):
            yield f"synergies[{index}].effects[{effect_index}]", effect


def _validate_effect(
    effect: Any,
    path: str,
    data: dict[str, Any],
    issues: list[str],
    validate_trigger: bool = True,
) -> None:
    if not isinstance(effect, dict):
        issues.append(f"{path} doit etre un objet")
        return
    effect_type = effect.get("type")
    if effect_type not in SUPPORTED_EFFECT_TYPES:
        issues.append(f"{path}.type non supporte : {effect_type}")
        return

    if validate_trigger:
        trigger = effect.get("trigger", "OnAcquire")
        if trigger not in SUPPORTED_TRIGGERS:
            issues.append(f"{path}.trigger non supporte : {trigger}")

    stack_rule = effect.get("stack_rule", "additive")
    if stack_rule not in SUPPORTED_STACK_RULES:
        issues.append(f"{path}.stack_rule non supporte : {stack_rule}")

    if effect_type == "stat":
        stat = effect.get("stat")
        if stat not in STAT_MODEL_SUPPORT:
            issues.append(f"{path}.stat non modelise : {stat}")
        operation = effect.get("operation", "add")
        if operation not in SUPPORTED_OPERATIONS:
            issues.append(f"{path}.operation non supportee : {operation}")
        if "value" not in effect and "value_per_stack" not in effect:
            issues.append(f"{path} doit definir value ou value_per_stack")
    elif effect_type == "apply_status":
        status = effect.get("status")
        if status not in data.get("statuses", {}):
            issues.append(f"{path}.status inconnu : {status}")
    elif effect_type == "proc_multiplier":
        if not str(effect.get("proc", "")).strip():
            issues.append(f"{path}.proc est requis")
    elif effect_type == "counter_reward":
        reward = effect.get("reward")
        _validate_effect(reward, f"{path}.reward", data, issues, False)

    for key in (
        "value", "value_per_stack", "cap", "decay", "chance",
        "chance_per_stack", "damage", "threshold",
        "threshold_stack_multiplier",
    ):
        if key in effect:
            _require_number(effect[key], f"{path}.{key}", issues)


def catalog_issues(data: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    missing = sorted(REQUIRED_TOP_LEVEL - set(data))
    if missing:
        return ["Cles catalogue manquantes : " + ", ".join(missing)]

    if data.get("schema_version") != SUPPORTED_SCHEMA_VERSION:
        issues.append(
            "schema_version non supportee : "
            f"{data.get('schema_version')} (attendu {SUPPORTED_SCHEMA_VERSION})"
        )
    if not data["characters"]:
        issues.append("Le catalogue doit contenir au moins un personnage")
    if not data["weapons"]:
        issues.append("Le catalogue doit contenir au moins une arme")
    if not data["perks"]:
        issues.append("Le catalogue doit contenir au moins un perk")
    if not data["items"]:
        issues.append("Le catalogue doit contenir au moins un objet")
    if not data["skill_profiles"]:
        issues.append("Le catalogue doit contenir au moins un profil joueur")
    if not data["run_scenarios"]:
        issues.append("Le catalogue doit contenir au moins un scenario")

    seen: set[str] = set()
    for group in (
        "characters", "weapons", "perks", "items", "relics", "curses",
        "gems", "synergies", "run_scenarios",
    ):
        for index, entry in enumerate(data.get(group, [])):
            if not isinstance(entry, dict):
                issues.append(f"{group}[{index}] doit etre un objet")
                continue
            entry_id = str(entry.get("id", "")).strip()
            if not entry_id:
                issues.append(f"{group}[{index}] est sans id")
                continue
            key = f"{group}:{entry_id}"
            if key in seen:
                issues.append(f"Id duplique : {key}")
            seen.add(key)

    settings = data.get("settings", {})
    max_weapons = settings.get("max_simultaneous_weapons", 4)
    if not isinstance(max_weapons, int) or isinstance(max_weapons, bool):
        issues.append("settings.max_simultaneous_weapons doit etre un entier")
    elif not 1 <= max_weapons <= 4:
        issues.append("La V1 accepte entre une et quatre armes simultanees")

    rarities = settings.get("rarities", {})
    if not isinstance(rarities, dict) or not rarities:
        issues.append("settings.rarities doit contenir les raretes")
        rarities = {}
    for rarity, definition in rarities.items():
        _require_number(
            definition.get("weight") if isinstance(definition, dict) else None,
            f"settings.rarities.{rarity}.weight",
            issues,
            0,
        )

    supported_stats = set(STAT_MODEL_SUPPORT)
    for index, character in enumerate(data.get("characters", [])):
        if not isinstance(character, dict):
            continue
        base_stats = character.get("base_stats", {})
        if not isinstance(base_stats, dict):
            issues.append(f"characters[{index}].base_stats doit etre un objet")
            continue
        for stat, value in base_stats.items():
            if stat not in supported_stats:
                issues.append(
                    f"characters[{index}].base_stats.{stat} non modelise"
                )
            _require_number(
                value, f"characters[{index}].base_stats.{stat}", issues
            )

    for index, perk in enumerate(data.get("perks", [])):
        if not isinstance(perk, dict):
            continue
        variants = perk.get("variants", {})
        if not isinstance(variants, dict):
            issues.append(f"perks[{index}].variants doit etre un objet")
            continue
        if set(variants) != set(rarities):
            issues.append(
                f"perks[{index}].variants doit couvrir exactement les raretes"
            )

    for index, weapon in enumerate(data.get("weapons", [])):
        if not isinstance(weapon, dict):
            continue
        base = weapon.get("base", {})
        if not isinstance(base, dict):
            issues.append(f"weapons[{index}].base doit etre un objet")
            base = {}
        for field in ("damage", "cooldown", "projectiles"):
            _require_number(
                base.get(field), f"weapons[{index}].base.{field}", issues, 0
            )
        levels = weapon.get("levels", [])
        level_numbers = [
            level.get("level") if isinstance(level, dict) else None
            for level in levels
        ]
        valid_level_numbers = all(
            isinstance(level, int) and not isinstance(level, bool)
            for level in level_numbers
        )
        if levels and not valid_level_numbers:
            issues.append(
                f"weapons[{index}].levels doit contenir des niveaux entiers"
            )
        elif levels and level_numbers != sorted(set(level_numbers)):
            issues.append(
                f"weapons[{index}].levels doit etre unique et croissant"
            )
        for behavior_index, behavior in enumerate(weapon.get("behaviors", [])):
            path = f"weapons[{index}].behaviors[{behavior_index}]"
            if not isinstance(behavior, dict):
                issues.append(f"{path} doit etre un objet")
                continue
            kind = behavior.get("type")
            if kind not in SUPPORTED_BEHAVIORS:
                issues.append(f"{path} non supporte : {kind}")
            count_stat = behavior.get("count_stat")
            if count_stat and count_stat not in supported_stats:
                issues.append(
                    f"{path}.count_stat "
                    f"non modelise : {count_stat}"
                )
            if kind == "dot" and behavior.get("status") not in data.get("statuses", {}):
                issues.append(
                    f"{path}.status inconnu : {behavior.get('status')}"
                )
            for field in (
                "accuracy_bonus", "count", "targets", "damage_multiplier",
                "tick_damage", "ticks", "orbs", "attacks", "contacts",
                "chance", "max_bonus", "missing_health_bonus", "threshold",
            ):
                if field in behavior:
                    _require_number(
                        behavior[field], f"{path}.{field}", issues, 0
                    )

    for path, effect in _iter_entry_effects(data):
        _validate_effect(effect, path, data, issues)

    for status_id, status in data.get("statuses", {}).items():
        if not isinstance(status, dict):
            issues.append(f"statuses.{status_id} doit etre un objet")
            continue
        for field in ("tick_damage", "tick_interval", "base_duration"):
            _require_number(
                status.get(field), f"statuses.{status_id}.{field}", issues, 0
            )

    required_profile_fields = {
        "accuracy", "evasion", "pickup_efficiency", "choice_quality",
        "chest_interest", "target_perk_picks", "target_item_picks",
        "pressure_exposure",
    }
    for profile_id, profile in data.get("skill_profiles", {}).items():
        if not isinstance(profile, dict):
            issues.append(f"skill_profiles.{profile_id} doit etre un objet")
            continue
        for field in required_profile_fields:
            if field not in profile:
                issues.append(f"skill_profiles.{profile_id}.{field} est requis")
            else:
                _require_number(
                    profile[field], f"skill_profiles.{profile_id}.{field}", issues, 0
                )

    required_scenario_fields = {
        "duration_seconds", "wave_duration", "calm_duration",
        "calm_max_alive", "wave_base_max_alive", "wave_max_alive_increase",
        "spawn_batch_base", "spawn_batch_increase_every", "spawn_batch_max",
        "spawn_interval", "spawn_interval_min",
        "spawn_interval_decrease_per_wave", "monster_max_alive",
    }
    for index, scenario in enumerate(data.get("run_scenarios", [])):
        if not isinstance(scenario, dict):
            issues.append(f"run_scenarios[{index}] doit etre un objet")
            continue
        for field in required_scenario_fields:
            if field not in scenario:
                issues.append(f"run_scenarios[{index}].{field} est requis")
            else:
                _require_number(
                    scenario[field], f"run_scenarios[{index}].{field}", issues, 0
                )

    utility_weights = data.get("utility_weights", {})
    used_choice_stats = {
        effect.get("stat")
        for path, effect in _iter_entry_effects(data)
        if effect.get("type") == "stat" and path.startswith(("perks", "items"))
    }
    for stat in sorted(used_choice_stats - set(utility_weights)):
        issues.append(f"utility_weights.{stat} manque pour un choix de build")

    return issues


def validate_catalog(data: dict[str, Any]) -> None:
    issues = catalog_issues(data)
    if issues:
        preview = "\n- ".join(issues[:20])
        suffix = f"\n... {len(issues) - 20} autre(s) erreur(s)" if len(issues) > 20 else ""
        raise ValueError("Catalogue invalide :\n- " + preview + suffix)


def catalog_support_report(data: dict[str, Any]) -> dict[str, Any]:
    effect_types: Counter[str] = Counter()
    stats: Counter[str] = Counter()
    for _path, effect in _iter_entry_effects(data):
        effect_types[str(effect.get("type"))] += 1
        if effect.get("type") == "stat":
            stats[str(effect.get("stat"))] += 1
        reward = effect.get("reward")
        if isinstance(reward, dict):
            effect_types[str(reward.get("type"))] += 1
            if reward.get("type") == "stat":
                stats[str(reward.get("stat"))] += 1
    for character in data.get("characters", []):
        for stat in character.get("base_stats", {}):
            stats[stat] += 1

    direct = sorted(stat for stat in stats if STAT_MODEL_SUPPORT.get(stat) == "direct")
    proxy = sorted(stat for stat in stats if STAT_MODEL_SUPPORT.get(stat) == "proxy")
    return {
        "schema_version": data.get("schema_version"),
        "content": {
            group: len(data.get(group, []))
            for group in (
                "characters", "weapons", "perks", "items", "relics",
                "curses", "gems", "synergies", "run_scenarios",
            )
        },
        "effect_types": dict(sorted(effect_types.items())),
        "weapon_behaviors": {
            behavior: BEHAVIOR_MODEL_SUPPORT[behavior]
            for behavior in sorted({
                entry.get("type")
                for weapon in data.get("weapons", [])
                for entry in weapon.get("behaviors", [])
                if isinstance(entry, dict)
                and entry.get("type") in BEHAVIOR_MODEL_SUPPORT
            })
        },
        "stats_direct": direct,
        "stats_proxy": proxy,
        "unsupported": catalog_issues(data),
        "model_status": "theoretical_supported" if not catalog_issues(data) else "blocked",
    }


def by_id(entries: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {entry["id"]: entry for entry in entries}
