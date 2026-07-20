
from __future__ import annotations
import heapq
import math
import random
import statistics
from collections import Counter
from typing import Any

from .catalog import by_id
from .model import Acquisition, Build, RuntimeBuild, Enemy, EventResult, DEFAULT_STATS

def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))

def apply_stack_value(base: float, stacks: int, rule: str = "additive",
                      cap: float | None = None, decay: float = .75) -> float:
    stacks = max(0, int(stacks))
    if stacks <= 0:
        return 0.0
    if rule == "additive":
        value = base * stacks
    elif rule == "multiplicative":
        value = (1 + base) ** stacks - 1
    elif rule == "diminishing":
        value = sum(base * (decay ** i) for i in range(stacks))
    elif rule == "capped":
        value = base * stacks
    elif rule == "threshold":
        value = base if stacks > 0 else 0
    elif rule == "exponential":
        value = base * (2 ** (stacks - 1))
    elif rule == "cooldown_reduction":
        value = 1 - (1 / ((1 + base) ** stacks))
    elif rule == "charges":
        value = base * stacks
    else:
        raise ValueError(f"Règle de stack inconnue : {rule}")
    return min(value, cap) if cap is not None else value

def effect_value(effect: dict[str, Any], stacks: int) -> float:
    if "value_per_stack" in effect:
        return apply_stack_value(
            float(effect["value_per_stack"]), stacks,
            effect.get("stack_rule", "additive"),
            effect.get("cap"), float(effect.get("decay", .75))
        )
    return float(effect.get("value", 0))

def apply_stat_effect(runtime: RuntimeBuild, effect: dict[str, Any], stacks: int = 1) -> None:
    stat = effect.get("stat")
    if not stat:
        return
    value = effect_value(effect, stacks)
    operation = effect.get("operation", "add")
    current = float(runtime.stats.get(stat, 0))
    if operation == "add":
        runtime.stats[stat] = current + value
    elif operation == "multiply":
        runtime.stats[stat] = current * (1 + value)
    elif operation == "set":
        runtime.stats[stat] = value
    elif operation == "max":
        runtime.stats[stat] = max(current, value)
    elif operation == "min":
        runtime.stats[stat] = min(current, value)
    else:
        raise ValueError(f"Opération statistique inconnue : {operation}")
    if stat == "Shield" and value > 0:
        runtime.shield += value

def register_effect(runtime: RuntimeBuild, effect: dict[str, Any], stacks: int, source: str) -> None:
    trigger = effect.get("trigger", "OnAcquire")
    if trigger in ("OnAcquire", "OnRunStart") and effect.get("type") == "stat":
        apply_stat_effect(runtime, effect, stacks)
    else:
        runtime.trigger_effects[trigger].append((effect, stacks, source))

def add_component(runtime: RuntimeBuild, definition: dict[str, Any], stacks: int = 1,
                  variant: dict[str, Any] | None = None) -> None:
    category = definition.get("category", "content")
    cid = definition["id"]
    component = f"{category}:{cid}"
    runtime.components.add(component)
    runtime.stacks[component] += stacks
    for tag in definition.get("tags", []):
        runtime.tags[tag] += stacks
    source_effects = (variant or definition).get("effects", [])
    for effect in source_effects:
        register_effect(runtime, effect, stacks, component)

def synergy_matches(runtime: RuntimeBuild, synergy: dict[str, Any]) -> bool:
    conditions = synergy.get("conditions", {})
    for tag in conditions.get("all_tags", []):
        if runtime.tags.get(tag, 0) <= 0:
            return False
    any_tags = conditions.get("any_tags", [])
    if any_tags and not any(runtime.tags.get(tag, 0) > 0 for tag in any_tags):
        return False
    for component in conditions.get("all_components", []):
        if component not in runtime.components:
            return False
    for stat, minimum in conditions.get("min_stats", {}).items():
        if runtime.stats.get(stat, 0) < minimum:
            return False
    return True

def apply_synergies(runtime: RuntimeBuild, catalog: dict[str, Any]) -> None:
    for synergy in catalog.get("synergies", []):
        if synergy["id"] in runtime.active_synergies:
            continue
        if synergy_matches(runtime, synergy):
            runtime.active_synergies.append(synergy["id"])
            runtime.components.add(f"synergy:{synergy['id']}")
            for effect in synergy.get("effects", []):
                register_effect(runtime, effect, 1, f"synergy:{synergy['id']}")

def create_runtime(catalog: dict[str, Any], build: Build, acquisitions_count: int | None = None) -> RuntimeBuild:
    runtime = RuntimeBuild()
    character_map = by_id(catalog["characters"])
    weapon_map = by_id(catalog["weapons"])
    perk_map = by_id(catalog["perks"])
    item_map = by_id(catalog["items"])
    relic_map = by_id(catalog.get("relics", []))
    curse_map = by_id(catalog.get("curses", []))

    character = character_map[build.character_id]
    runtime.stats.update(DEFAULT_STATS)
    runtime.stats.update(character.get("base_stats", {}))
    add_component(runtime, character)

    for weapon_id, level in build.weapon_levels.items():
        weapon = weapon_map[weapon_id]
        add_component(runtime, weapon)
        for level_def in weapon.get("levels", []):
            if int(level_def.get("level", 0)) <= level:
                for effect in level_def.get("effects", []):
                    if effect.get("type") == "stat":
                        apply_stat_effect(runtime, effect)
                    else:
                        register_effect(runtime, effect, 1, f"weapon:{weapon_id}")

    acquisitions = build.acquisitions if acquisitions_count is None else build.acquisitions[:acquisitions_count]
    for acquisition in acquisitions:
        if acquisition.category == "perk":
            definition = perk_map[acquisition.content_id]
            variant = definition["variants"][acquisition.rarity]
            add_component(runtime, definition, acquisition.stack, variant)
        elif acquisition.category == "item":
            add_component(runtime, item_map[acquisition.content_id], acquisition.stack)
        elif acquisition.category == "relic":
            add_component(runtime, relic_map[acquisition.content_id], acquisition.stack)
        elif acquisition.category == "curse":
            add_component(runtime, curse_map[acquisition.content_id], acquisition.stack)
        apply_synergies(runtime, catalog)

    apply_synergies(runtime, catalog)
    runtime.stats["CritChance"] = clamp(runtime.stats.get("CritChance", 0), 0, 1)
    runtime.stats["ArmorPercent"] = clamp(runtime.stats.get("ArmorPercent", 0), 0, .8)
    return runtime

def marginal_utility(catalog: dict[str, Any], runtime: RuntimeBuild,
                     definition: dict[str, Any], variant: dict[str, Any] | None = None) -> float:
    weights = catalog.get("utility_weights", {})
    score = 0.0
    effects = (variant or definition).get("effects", [])
    for effect in effects:
        etype = effect.get("type")
        if etype == "stat":
            value = effect_value(effect, 1)
            stat = effect.get("stat", "")
            weight = float(weights.get(stat, 0))
            if stat == "CritMultiplierBonus" and runtime.stats.get("CritChance", 0) < .10:
                weight *= .45
            if stat == "EffectDurationPercent" and runtime.tags.get("poison", 0) <= 0:
                weight *= .55
            if stat == "EliteFlatDamage":
                weight *= .65
            score += value * weight
        elif etype == "apply_status":
            score += 3.5
        elif etype == "counter_reward":
            score += 2.0
    tags = set(definition.get("tags", []))
    if "poison" in tags and runtime.stats.get("EffectDurationPercent", 0) > 0:
        score += 2
    if "crit" in tags and runtime.stats.get("CritMultiplierBonus", 0) > 0:
        score += 2
    if "damage" in tags and runtime.stats.get("AttackSpeedPercent", 0) > 0:
        score += 1
    return score

def weighted_choice(rng: random.Random, entries: list[tuple[Any, float]]) -> Any:
    total = sum(max(0.0, w) for _, w in entries)
    if total <= 0:
        return rng.choice([x for x, _ in entries])
    cursor = rng.random() * total
    for value, weight in entries:
        cursor -= max(0.0, weight)
        if cursor <= 0:
            return value
    return entries[-1][0]

def pick_perk_rarity(catalog: dict[str, Any], runtime: RuntimeBuild, rng: random.Random) -> str:
    luck = max(0.0, runtime.stats.get("Luck", 0))
    entries = []
    for rarity, data in catalog["settings"]["rarities"].items():
        weight = float(data["weight"])
        if rarity == "Rare":
            weight += luck * 80
        elif rarity == "Epic":
            weight += luck * 45
        elif rarity == "Legendary":
            weight += luck * 20
        entries.append((rarity, weight))
    return weighted_choice(rng, entries)

def choose_with_quality(rng: random.Random, scored: list[tuple[Any, float]], quality: float) -> Any:
    if not scored:
        raise ValueError("Aucun choix.")
    scored = sorted(scored, key=lambda x: x[1], reverse=True)
    if rng.random() < clamp(quality, 0, 1):
        rank_roll = rng.random()
        if rank_roll < quality or len(scored) == 1:
            return scored[0][0]
        if rank_roll < .92 or len(scored) == 2:
            return scored[min(1, len(scored)-1)][0]
        return scored[min(2, len(scored)-1)][0]
    return rng.choice(scored)[0]

def draft_build(
    catalog: dict[str, Any],
    profile_id: str,
    seed: int,
    build_index: int,
    coverage_draft: bool = False,
) -> Build:
    rng = random.Random((seed * 1000003) + build_index * 9176 + sum(map(ord, profile_id)))
    profile = catalog["skill_profiles"][profile_id]
    characters = list(catalog["characters"])
    if coverage_draft:
        character = characters[(build_index - 1) % len(characters)]
    else:
        character = rng.choice(characters)
    max_weapons = min(4, int(catalog["settings"].get("max_simultaneous_weapons", 4)))
    weapon_candidates = list(catalog["weapons"])
    weapon_cap = min(
        max_weapons,
        max(1, min(len(weapon_candidates), int(profile.get("weapon_slots", max_weapons)))),
    )
    weapon_count = (
        1 + ((build_index - 1) // max(1, len(characters))) % weapon_cap
        if coverage_draft
        else weapon_cap
    )
    scored_weapons = []
    for weapon in weapon_candidates:
        base = weapon["base"]
        heuristic = base["damage"] * base.get("projectiles", 1) / max(.08, base["cooldown"])
        scored_weapons.append((weapon, heuristic * rng.uniform(.85, 1.15)))
    ranked_weapons = [
        entry[0]
        for entry in sorted(scored_weapons, key=lambda x: x[1], reverse=True)
    ]
    if coverage_draft:
        forced_index = (
            (build_index - 1) // max(1, len(characters) * weapon_cap)
        ) % len(weapon_candidates)
        forced_weapon = weapon_candidates[forced_index]
        ranked_weapons = [
            forced_weapon,
            *(weapon for weapon in ranked_weapons if weapon is not forced_weapon),
        ]
    chosen_weapons = ranked_weapons[:weapon_count]
    weapon_levels = {w["id"]: int(profile.get("starting_weapon_level", 1)) for w in chosen_weapons}

    build = Build(
        build_id=f"B{build_index:05d}_{profile_id}",
        character_id=character["id"],
        weapon_levels=weapon_levels,
        acquisitions=[],
        profile_origin=profile_id,
        generation_seed=seed,
    )
    runtime = create_runtime(catalog, build)
    perk_count = int(profile.get("target_perk_picks", 20))
    quality = float(profile.get("choice_quality", .75))
    perk_defs = list(catalog["perks"])

    rarity_ids = list(catalog["settings"]["rarities"])
    for pick_index in range(perk_count):
        if coverage_draft and pick_index == 0:
            definition = perk_defs[(build_index - 1) % len(perk_defs)]
            rarity = rarity_ids[
                ((build_index - 1) // len(perk_defs)) % len(rarity_ids)
            ]
        else:
            options = rng.sample(perk_defs, k=min(int(catalog["settings"].get("perk_choices_per_level", 3)), len(perk_defs)))
            scored = []
            for definition in options:
                rarity = pick_perk_rarity(catalog, runtime, rng)
                variant = definition["variants"][rarity]
                payload = (definition, rarity)
                utility = marginal_utility(catalog, runtime, definition, variant) * rng.uniform(.92, 1.08)
                scored.append((payload, utility))
            definition, rarity = choose_with_quality(rng, scored, quality)
        acq = Acquisition("perk", definition["id"], rarity, 1)
        build.acquisitions.append(acq)
        add_component(runtime, definition, 1, definition["variants"][rarity])
        apply_synergies(runtime, catalog)

    item_count = int(profile.get("target_item_picks", 6))
    item_defs = list(catalog["items"])
    for item_index in range(item_count):
        if coverage_draft and item_index == 0:
            item = item_defs[(build_index - 1) % len(item_defs)]
        else:
            candidates = []
            for item in item_defs:
                rarity_weight = float(catalog["settings"]["chest_rarity_weights"].get(item.get("rarity","Common"), .1))
                utility = max(.05, marginal_utility(catalog, runtime, item))
                candidates.append((item, rarity_weight * (1 + utility * quality * .08)))
            item = weighted_choice(rng, candidates)
        acq = Acquisition("item", item["id"], item.get("rarity",""), 1)
        build.acquisitions.append(acq)
        add_component(runtime, item, 1)
        apply_synergies(runtime, catalog)

    # Ces familles ne sont pas encore présentes dans le jeu, mais elles font
    # partie du contrat du laboratoire. Dès qu'elles sont alimentées, elles
    # doivent donc entrer dans les builds et dans la preuve de couverture.
    for category in ("relic", "curse"):
        definitions = list(catalog.get(category + "s", []))
        if not definitions:
            continue
        target_count = max(
            1,
            int(profile.get(f"target_{category}_picks", 1)),
        )
        for pick_index in range(target_count):
            if coverage_draft and pick_index == 0:
                definition = definitions[(build_index - 1) % len(definitions)]
            else:
                definition = rng.choice(definitions)
            acquisition = Acquisition(
                category,
                definition["id"],
                definition.get("rarity", ""),
                1,
            )
            build.acquisitions.append(acquisition)
            add_component(runtime, definition, 1)
            apply_synergies(runtime, catalog)
    return build

def weapon_expected_dps(catalog: dict[str, Any], runtime: RuntimeBuild,
                        weapon: dict[str, Any], profile: dict[str, Any],
                        enemy_density: float = 1.0, elite: bool = False) -> tuple[float, float]:
    base = weapon["base"]
    damage = (float(base["damage"]) + runtime.stats.get("FlatDamage", 0)
              + (runtime.stats.get("EliteFlatDamage", 0) if elite else 0))
    damage *= 1 + runtime.stats.get("DamagePercent", 0)
    crit_chance = clamp(runtime.stats.get("CritChance", 0), 0, 1) if base.get("crit_enabled", True) else 0
    crit_mult = 1.5 + runtime.stats.get("CritMultiplierBonus", 0)
    damage *= 1 + crit_chance * (crit_mult - 1)
    cooldown = max(.08, float(base["cooldown"]) / max(.1, 1 + runtime.stats.get("AttackSpeedPercent", 0)))
    projectiles = max(1, min(24, int(base.get("projectiles",1) + runtime.stats.get("ProjectileCount",0))))
    accuracy = float(profile["accuracy"])
    hit_bonus = 0.0
    extra_hits = 0.0
    aoe_multiplier = 1.0
    dot_dps = 0.0
    damage_scale = 1.0
    for behavior in weapon.get("behaviors", []):
        kind = behavior["type"]
        if kind == "homing":
            hit_bonus += float(behavior.get("accuracy_bonus", .1))
        elif kind == "bounce":
            count = int(behavior.get("count", 0))
            if behavior.get("count_stat"):
                count += int(runtime.stats.get(behavior["count_stat"], 0))
            extra_hits += min(count, max(0, int(enemy_density * 8))) * .82
        elif kind == "pierce":
            extra_hits += float(behavior.get("targets", 1)) * .88
        elif kind == "chain":
            extra_hits += float(behavior.get("targets", 1)) * float(behavior.get("damage_multiplier", .7))
        elif kind == "return":
            extra_hits += float(behavior.get("damage_multiplier", .8))
        elif kind == "explosion":
            aoe_multiplier += float(behavior.get("targets", 2)) * float(behavior.get("damage_multiplier", .45))
        elif kind == "fragmentation":
            extra_hits += float(behavior.get("count", 2)) * float(behavior.get("damage_multiplier", .35))
        elif kind == "persistent_area":
            dot_dps += float(behavior.get("tick_damage", 2)) * int(behavior.get("ticks", 3)) / cooldown
        elif kind == "beam":
            extra_hits += float(behavior.get("targets",2))
        elif kind == "orbital":
            extra_hits += float(behavior.get("orbs",1))*.6
        elif kind == "summon":
            extra_hits += float(behavior.get("attacks",1))*.7
        elif kind == "contact":
            extra_hits += float(behavior.get("contacts",1))*.5
        elif kind == "dot":
            status = catalog["statuses"].get(behavior.get("status"), {})
            interval = max(.05, float(status.get("tick_interval", 1)))
            duration = float(status.get("base_duration", 0)) * (
                1 + runtime.stats.get("EffectDurationPercent", 0)
            )
            ticks = max(0, int(duration / interval))
            dot_dps += (
                float(status.get("tick_damage", 0))
                * ticks
                * float(behavior.get("chance", 1))
                * projectiles
                / cooldown
            )
        elif kind == "distance_scaling":
            damage_scale *= 1 + float(behavior.get("max_bonus", .5)) * .5
        elif kind == "health_scaling":
            damage_scale *= (
                1 + float(behavior.get("missing_health_bonus", .5)) * .35
            )
        elif kind == "execute":
            threshold = clamp(float(behavior.get("threshold", .15)), 0, .9)
            damage_scale *= 1 / max(.1, 1 - threshold)
    damage *= damage_scale
    speed_factor = clamp((float(base.get("speed", 50)) * (1 + runtime.stats.get("ProjectileSpeedPercent", 0))) / 58, .72, 1.18)
    hit_chance = clamp((accuracy + hit_bonus) * speed_factor, .05, .995)
    hits_per_projectile = (1 + extra_hits) * aoe_multiplier
    raw = damage * projectiles * hits_per_projectile * hit_chance / cooldown + dot_dps
    return raw, hit_chance

def analytical_evaluate(catalog: dict[str, Any], build: Build, profile_id: str) -> dict[str, float]:
    profile = catalog["skill_profiles"][profile_id]
    runtime = create_runtime(catalog, build)
    weapon_map = by_id(catalog["weapons"])
    dps_normal = 0.0
    dps_elite = 0.0
    hit_chances = []
    for wid in build.weapon_levels:
        dps, hit = weapon_expected_dps(catalog, runtime, weapon_map[wid], profile, enemy_density=1.5, elite=False)
        elite_dps, _ = weapon_expected_dps(catalog, runtime, weapon_map[wid], profile, enemy_density=.8, elite=True)
        dps_normal += dps
        dps_elite += elite_dps
        hit_chances.append(hit)
    max_health = runtime.stats.get("MaxHealth",100) + runtime.stats.get("MaxHealthBonus",0)
    armor = clamp(runtime.stats.get("ArmorPercent",0),0,.8)
    effective_health = (max_health + runtime.shield) / max(.2, 1-armor)
    sustain = runtime.stats.get("HealthRegen",0) + dps_normal * runtime.stats.get("LifeStealPercent",0)
    proxy = catalog.get("model_assumptions", {}).get("proxy_coefficients", {})
    collect_factor = clamp(
        1 + runtime.stats.get("CollectRadius", 0) * float(proxy.get("collect_radius_per_stud", .01)),
        1,
        float(proxy.get("collect_radius_cap", 1.4)),
    )
    mobility = 1 + (
        runtime.stats.get("MoveSpeedPercent", 0) * float(proxy.get("move_speed_value", .35))
        + runtime.stats.get("JumpPercent", 0) * float(proxy.get("jump_value", .12))
    )
    step_score = 1 + runtime.stats.get("StepScorePercent", 0)
    explicit_synergy = (
        runtime.stats.get("MetaCritSynergy", 0)
        + runtime.stats.get("MetaCoverageSynergy", 0)
    )
    progression = (1 + runtime.stats.get("XpGainPercent",0)) * profile["pickup_efficiency"] * collect_factor
    economy = (1 + runtime.stats.get("GoldGainPercent",0)) * profile["pickup_efficiency"] * collect_factor
    coverage = 1 + .10 * runtime.stats.get("BounceCount",0) + .08 * runtime.stats.get("ProjectileCount",0)
    raw_power = (
        dps_normal * .45 + dps_elite * .15 + effective_health * .16
        + sustain * 8 + progression * 22 + economy * 8 + coverage * 12
        + mobility * float(proxy.get("mobility_power_weight", 8))
        + step_score * float(proxy.get("step_score_power_weight", 3))
        + explicit_synergy * float(proxy.get("explicit_synergy_power_weight", 5))
    )
    ramp = float(catalog["settings"].get("analytical_ramp_factor", .66))
    return {
        "dps": dps_normal,
        "elite_dps": dps_elite,
        "effective_health": effective_health,
        "sustain": sustain,
        "progression": progression,
        "economy": economy,
        "mobility_proxy": mobility,
        "collection_proxy": collect_factor,
        "step_score_proxy": step_score,
        "hit_chance": statistics.fmean(hit_chances) if hit_chances else 0,
        "raw_power": raw_power * ramp,
        "active_synergies": float(len(runtime.active_synergies)),
    }

def wave_number(scenario: dict[str, Any], t: float) -> int:
    return int(t // float(scenario["wave_duration"])) + 1

def current_max_alive(scenario: dict[str, Any], t: float, enemy_multiplier: float) -> int:
    wave = wave_number(scenario, t)
    value = int(scenario["wave_base_max_alive"] + (wave - 1) * scenario["wave_max_alive_increase"])
    if t < scenario.get("calm_duration",0):
        value = min(value, int(scenario.get("calm_max_alive", value)))
    value = math.ceil(value * max(1.0, enemy_multiplier))
    return min(int(scenario["monster_max_alive"]), value)

def spawn_interval(scenario: dict[str, Any], t: float) -> float:
    wave = wave_number(scenario, t)
    value = float(scenario["spawn_interval"]) - (wave - 1) * float(scenario["spawn_interval_decrease_per_wave"])
    return max(float(scenario["spawn_interval_min"]), value)

def spawn_batch(scenario: dict[str, Any], t: float) -> int:
    wave = wave_number(scenario, t)
    if t < scenario.get("calm_duration",0):
        return max(1, int(scenario["spawn_batch_base"]))
    extra = (wave - 1) // int(scenario["spawn_batch_increase_every"])
    return min(int(scenario["spawn_batch_max"]), int(scenario["spawn_batch_base"]) + extra)

def trigger_effects(runtime: RuntimeBuild, trigger: str, context: dict[str, Any],
                    rng: random.Random, catalog: dict[str, Any]) -> None:
    for effect, stacks, source in list(runtime.trigger_effects.get(trigger, [])):
        etype = effect.get("type")
        if etype == "stat":
            apply_stat_effect(runtime, effect, stacks)
        elif etype == "counter_reward":
            counter = effect.get("counter","kills")
            runtime.counters[counter] += 1
            base_threshold = max(1, int(effect.get("threshold",1)))
            multiplier = clamp(float(effect.get("threshold_stack_multiplier",1)), .1, 1)
            threshold = max(1, math.ceil(base_threshold * (multiplier ** max(0, stacks-1))))
            while runtime.counters[counter] >= threshold:
                runtime.counters[counter] -= threshold
                reward = effect.get("reward",{})
                if reward.get("type") == "stat":
                    apply_stat_effect(runtime, reward, 1)
        elif etype not in ("apply_status", "proc_multiplier"):
            raise ValueError(f"Effet non traite au runtime : {etype} ({source})")


def event_simulate(catalog: dict[str, Any], build: Build, profile_id: str,
                   scenario: dict[str, Any], seed: int, keep_timeline: bool = False) -> EventResult:
    rng = random.Random(seed)
    profile = catalog["skill_profiles"][profile_id]
    settings = catalog["settings"]
    weapon_map = by_id(catalog["weapons"])
    perk_map = by_id(catalog["perks"])
    item_map = by_id(catalog["items"])

    initial_acquisitions = [
        acquisition
        for acquisition in build.acquisitions
        if acquisition.category in ("relic", "curse")
    ]
    empty_build = Build(
        build_id=build.build_id,
        character_id=build.character_id,
        weapon_levels=build.weapon_levels,
        acquisitions=initial_acquisitions,
        profile_origin=build.profile_origin,
        generation_seed=build.generation_seed,
    )
    runtime = create_runtime(catalog, empty_build)
    trigger_effects(runtime, "OnRunStart", {}, rng, catalog)

    perk_sequence = [a for a in build.acquisitions if a.category == "perk"]
    item_sequence = [a for a in build.acquisitions if a.category == "item"]
    next_perk = 0
    next_item = 0

    duration = float(scenario.get("duration_seconds", settings["run_duration_seconds"]))
    dt = float(settings.get("event_step_seconds", .25))
    event_budget = int(settings.get("projectile_event_budget", 250000))
    enemies: list[Enemy] = []
    next_enemy_id = 1
    next_spawn = 0.0
    elite_schedule = {round(float(e["time"]),3): int(e["count"]) for e in scenario.get("elite_events",[])}
    next_attack = {wid:0.0 for wid in build.weapon_levels}

    max_health = runtime.stats.get("MaxHealth",100) + runtime.stats.get("MaxHealthBonus",0)
    health = max_health
    runtime.shield = runtime.stats.get("Shield",0)
    xp = 0.0
    total_xp = 0.0
    level = 1
    coins = 0.0
    chests = 0
    damage_total = 0.0
    damage_taken = 0.0
    healing = 0.0
    kills = 0
    elite_kills = 0
    projectile_events = 0
    saturated = False
    timeline = []
    dot_events: list[tuple[float,int,Enemy,int,float,float,str]] = []
    dot_serial = 0
    next_sample = 0.0
    next_chest_check = 10.0
    last_wave = 0
    t = 0.0

    def required_xp(lvl: int) -> float:
        return float(settings["xp_base"] + (max(1,lvl)-1)*settings["xp_increase_per_level"])

    def apply_acquisition(acq: Acquisition) -> None:
        nonlocal max_health, health
        before_max = runtime.stats.get("MaxHealth",100) + runtime.stats.get("MaxHealthBonus",0)
        if acq.category == "perk":
            definition = perk_map[acq.content_id]
            add_component(runtime, definition, 1, definition["variants"][acq.rarity])
        elif acq.category == "item":
            add_component(runtime, item_map[acq.content_id], 1)
        apply_synergies(runtime, catalog)
        after_max = runtime.stats.get("MaxHealth",100) + runtime.stats.get("MaxHealthBonus",0)
        if after_max > before_max:
            health += after_max - before_max
        max_health = after_max

    def choose_target(elite_priority: bool = False) -> Enemy | None:
        if elite_priority:
            for enemy in enemies:
                if enemy.alive and enemy.elite:
                    return enemy
        for enemy in enemies:
            if enemy.alive:
                return enemy
        return None

    def damage_enemy(enemy: Enemy, amount: float, source: str) -> None:
        nonlocal damage_total, kills, elite_kills, xp, total_xp, coins, health, healing
        if not enemy.alive or amount <= 0:
            return
        dealt = min(enemy.hp, amount)
        enemy.hp -= amount
        damage_total += dealt
        life = dealt * max(0.0, runtime.stats.get("LifeStealPercent",0))
        if life > 0 and health > 0:
            actual = min(life, max_health-health)
            health += actual
            healing += actual
        if enemy.hp <= 0 and enemy.alive:
            enemy.alive = False
            kills += 1
            if enemy.elite:
                elite_kills += 1
            gained_xp = enemy.xp * (1 + runtime.stats.get("XpGainPercent",0))
            pickup_efficiency = clamp(
                profile["pickup_efficiency"]
                * (
                    1
                    + runtime.stats.get("CollectRadius", 0)
                    * float(
                        catalog.get("model_assumptions", {})
                        .get("proxy_coefficients", {})
                        .get("collect_radius_per_stud", .01)
                    )
                ),
                0,
                1,
            )
            if rng.random() <= pickup_efficiency:
                xp += gained_xp
                total_xp += gained_xp
            coin_chance = clamp(settings["coin_drop_chance"] * pickup_efficiency,0,1)
            if rng.random() <= coin_chance:
                coins += 1 * (1 + runtime.stats.get("GoldGainPercent",0))
            trigger_effects(runtime, "OnKill", {"enemy":enemy}, rng, catalog)
            if enemy.elite:
                trigger_effects(runtime, "OnEliteKill", {"enemy":enemy}, rng, catalog)

    def apply_statuses(enemy: Enemy, weapon: dict[str, Any]) -> None:
        nonlocal dot_serial
        status_requests: list[tuple[str,float]] = []
        for effect, stacks, _source in runtime.trigger_effects.get("OnHit",[]):
            if effect.get("type") != "apply_status":
                continue
            chance = float(effect.get("chance",0)) + float(effect.get("chance_per_stack",0))*stacks
            proc_mult = 1.0
            for proc_effect, _, _ in runtime.trigger_effects.get("OnHit",[]):
                if proc_effect.get("type") == "proc_multiplier" and proc_effect.get("proc") == effect.get("status"):
                    proc_mult *= float(proc_effect.get("value",1))
            if rng.random() <= clamp(chance*proc_mult,0,1):
                status_requests.append((effect["status"],1.0))
        for behavior in weapon.get("behaviors",[]):
            if behavior["type"] == "dot" and rng.random() <= float(behavior.get("chance",1)):
                status_requests.append((behavior["status"],float(behavior.get("damage_multiplier",1))))
        for status_id, multiplier in status_requests:
            status = catalog["statuses"].get(status_id)
            if not status or not enemy.alive:
                continue
            interval = max(.05,float(status["tick_interval"]))
            duration = float(status["base_duration"]) * (1 + runtime.stats.get("EffectDurationPercent",0))
            ticks = max(1, int(duration / interval))
            dot_serial += 1
            heapq.heappush(
                dot_events,
                (t+interval,dot_serial,enemy,ticks,interval,float(status["tick_damage"])*multiplier,status_id)
            )

    def on_hit(enemy: Enemy, base_damage: float, weapon: dict[str, Any], multiplier: float = 1.0) -> None:
        damage = base_damage * multiplier
        crit = False
        if weapon["base"].get("crit_enabled", True) and rng.random() <= clamp(runtime.stats.get("CritChance",0),0,1):
            damage *= 1.5 + runtime.stats.get("CritMultiplierBonus",0)
            crit = True
        missing_fraction = 1 - enemy.hp / max(1,enemy.max_hp)
        for behavior in weapon.get("behaviors",[]):
            kind = behavior["type"]
            if kind == "distance_scaling":
                damage *= 1 + float(behavior.get("max_bonus",.5)) * rng.random()
            elif kind == "health_scaling":
                damage *= 1 + float(behavior.get("missing_health_bonus",.5)) * missing_fraction
            elif kind == "execute" and enemy.hp/enemy.max_hp <= float(behavior.get("threshold",.15)):
                damage = max(damage, enemy.hp)
        damage_enemy(enemy, damage, weapon["id"])
        if crit:
            trigger_effects(runtime, "OnCrit", {"enemy":enemy,"damage":damage}, rng, catalog)
        trigger_effects(runtime, "OnHit", {"enemy":enemy,"damage":damage}, rng, catalog)
        apply_statuses(enemy, weapon)

    while t < duration and health > 0:
        # Résout les ticks de statut à leur vraie échéance temporelle.
        while dot_events and dot_events[0][0] <= t + 1e-9:
            tick_time, serial, enemy, ticks_left, interval, tick_damage, status_id = heapq.heappop(dot_events)
            if enemy.alive:
                damage_enemy(enemy,tick_damage,status_id)
                ticks_left -= 1
                if ticks_left > 0 and enemy.alive:
                    heapq.heappush(
                        dot_events,
                        (tick_time+interval,serial,enemy,ticks_left,interval,tick_damage,status_id)
                    )

        wave = wave_number(scenario,t)
        if wave != last_wave:
            if last_wave:
                trigger_effects(runtime,"OnWaveEnd",{"wave":last_wave},rng,catalog)
            last_wave = wave
            trigger_effects(runtime,"OnWaveStart",{"wave":wave},rng,catalog)

        alive_count = sum(1 for e in enemies if e.alive)
        max_alive = current_max_alive(scenario,t,1+runtime.stats.get("EnemyCountPercent",0))
        if t + 1e-9 >= next_spawn and alive_count < max_alive:
            count = min(spawn_batch(scenario,t), max_alive-alive_count)
            template = catalog["enemies"]["normal"]
            for _ in range(count):
                enemies.append(Enemy(
                    next_enemy_id,float(template["health"]),float(template["health"]),
                    float(template["damage"]),float(template["attack_cooldown"]),
                    False,float(template["xp"])
                ))
                next_enemy_id += 1
            next_spawn = t + spawn_interval(scenario,t)

        for event_time, count in list(elite_schedule.items()):
            if t <= event_time < t + dt:
                template = catalog["enemies"]["elite"]
                for _ in range(count):
                    enemies.append(Enemy(
                        next_enemy_id,float(template["health"]),float(template["health"]),
                        float(template["damage"]),float(template["attack_cooldown"]),
                        True,float(template["xp"])
                    ))
                    next_enemy_id += 1
                del elite_schedule[event_time]

        for wid in build.weapon_levels:
            weapon = weapon_map[wid]
            cooldown = max(
                .08,
                float(weapon["base"]["cooldown"]) /
                max(.1,1+runtime.stats.get("AttackSpeedPercent",0))
            )
            while t + 1e-9 >= next_attack[wid] and health > 0:
                trigger_effects(runtime,"OnAttack",{"weapon":wid},rng,catalog)
                base_damage = float(weapon["base"]["damage"]) + runtime.stats.get("FlatDamage",0)
                base_damage *= 1 + runtime.stats.get("DamagePercent",0)
                projectile_count = max(
                    1,
                    min(24,int(
                        weapon["base"].get("projectiles",1) +
                        runtime.stats.get("ProjectileCount",0)
                    ))
                )
                summon_mult = 1
                for behavior in weapon.get("behaviors",[]):
                    if behavior["type"] == "summon":
                        summon_mult += int(behavior.get("attacks",1))
                    if behavior["type"] == "orbital":
                        projectile_count += int(behavior.get("orbs",1))
                projectile_count *= summon_mult

                for _ in range(projectile_count):
                    projectile_events += 1
                    if projectile_events > event_budget:
                        saturated = True
                        break
                    trigger_effects(
                        runtime,
                        "OnProjectileCreated",
                        {"weapon": wid},
                        rng,
                        catalog,
                    )
                    target = choose_target()
                    if target is None:
                        break
                    accuracy = profile["accuracy"]
                    bonus = sum(
                        float(b.get("accuracy_bonus",0))
                        for b in weapon.get("behaviors",[])
                        if b["type"]=="homing"
                    )
                    speed_factor = clamp(
                        (
                            float(weapon["base"].get("speed",58)) *
                            (1+runtime.stats.get("ProjectileSpeedPercent",0))
                        ) / 58,
                        .72,1.18
                    )
                    hit_chance = clamp((accuracy+bonus)*speed_factor,.05,.995)
                    if rng.random() > hit_chance:
                        continue
                    on_hit(target,base_damage,weapon)

                    hit_specs: list[tuple[int,float,str | None]] = []
                    for behavior in weapon.get("behaviors",[]):
                        kind = behavior["type"]
                        if kind == "bounce":
                            count = int(behavior.get("count",0))
                            if behavior.get("count_stat"):
                                count += int(runtime.stats.get(behavior["count_stat"],0))
                            hit_specs.append((count,float(behavior.get("damage_multiplier",1)),"OnBounce"))
                        elif kind == "pierce":
                            hit_specs.append((int(behavior.get("targets",1)),float(behavior.get("damage_multiplier",.9)),None))
                        elif kind == "chain":
                            hit_specs.append((int(behavior.get("targets",1)),float(behavior.get("damage_multiplier",.7)),None))
                        elif kind == "return":
                            hit_specs.append((1,float(behavior.get("damage_multiplier",.8)),None))
                        elif kind == "fragmentation":
                            hit_specs.append((int(behavior.get("count",2)),float(behavior.get("damage_multiplier",.35)),"OnProjectileCreated"))
                        elif kind == "explosion":
                            hit_specs.append((int(behavior.get("targets",2)),float(behavior.get("damage_multiplier",.45)),None))
                        elif kind == "beam":
                            hit_specs.append((int(behavior.get("targets",2)),float(behavior.get("damage_multiplier",1)),None))
                        elif kind == "persistent_area":
                            hit_specs.append((int(behavior.get("ticks",3)),float(behavior.get("damage_multiplier",.3)),None))
                        elif kind == "contact":
                            hit_specs.append((int(behavior.get("contacts",1)),float(behavior.get("damage_multiplier",.5)),None))
                    for count,mult,trig in hit_specs:
                        for _extra in range(max(0,count)):
                            extra_target = choose_target()
                            if extra_target is None:
                                break
                            on_hit(extra_target,base_damage,weapon,mult)
                            if trig is not None:
                                trigger_effects(runtime,trig,{"weapon":wid},rng,catalog)
                    if saturated:
                        break

                next_attack[wid] += cooldown
                if saturated:
                    alive_targets = [e for e in enemies if e.alive]
                    if alive_targets:
                        approx_dps,_ = weapon_expected_dps(
                            catalog,runtime,weapon,profile,1.5,False
                        )
                        damage_enemy(alive_targets[0],approx_dps*cooldown,weapon["id"])
                    break

        req = required_xp(level)
        while xp >= req:
            xp -= req
            level += 1
            trigger_effects(runtime,"OnLevelUp",{"level":level},rng,catalog)
            if next_perk < len(perk_sequence):
                apply_acquisition(perk_sequence[next_perk])
                next_perk += 1
            req = required_xp(level)

        if t >= next_chest_check and next_item < len(item_sequence):
            cost = settings["base_chest_cost"] + chests*settings["chest_cost_increase"]
            if coins >= cost and rng.random() <= profile["chest_interest"]:
                coins -= cost
                chests += 1
                apply_acquisition(item_sequence[next_item])
                next_item += 1
                trigger_effects(runtime,"OnChestOpened",{"chests":chests},rng,catalog)
            next_chest_check += 10

        alive = [e for e in enemies if e.alive]
        if alive:
            average_damage = sum(e.damage for e in alive)/len(alive)
            exposure = float(profile["pressure_exposure"])
            proxy = catalog.get("model_assumptions", {}).get("proxy_coefficients", {})
            movement_relief = 1 / max(
                .65,
                1
                + runtime.stats.get("MoveSpeedPercent", 0)
                * float(proxy.get("move_speed_value", .35))
                + runtime.stats.get("JumpPercent", 0)
                * float(proxy.get("jump_value", .12)),
            )
            incoming_dps = len(alive)*exposure*average_damage/1.1
            incoming_dps *= movement_relief*(1-profile["evasion"]*.35)
            incoming = incoming_dps*dt*(1+rng.uniform(-.12,.12))
            incoming *= 1-clamp(runtime.stats.get("ArmorPercent",0),0,.8)
            if runtime.shield > 0:
                absorbed = min(runtime.shield,incoming)
                runtime.shield -= absorbed
                incoming -= absorbed
            if incoming > 0:
                health -= incoming
                damage_taken += incoming
                trigger_effects(runtime,"OnDamageTaken",{"damage":incoming},rng,catalog)

        regen = max(0,runtime.stats.get("HealthRegen",0))*dt
        if regen > 0 and health > 0:
            actual = min(regen,max_health-health)
            health += actual
            healing += actual
            if actual > 0:
                trigger_effects(runtime,"OnHeal",{"heal":actual},rng,catalog)

        if health/max(1,max_health) <= .25:
            trigger_effects(runtime,"OnLowHealth",{"ratio":health/max_health},rng,catalog)

        if keep_timeline and t >= next_sample:
            timeline.append({
                "time":round(t,2),
                "health":round(max(0,health),2),
                "alive":float(sum(1 for e in enemies if e.alive)),
                "damage":round(damage_total,2),
                "kills":float(kills),
                "level":float(level),
                "dps":round(damage_total/max(1,t),2)
            })
            next_sample += 15

        if int(t/dt) % 80 == 0 and len(enemies)>500:
            enemies = [e for e in enemies if e.alive]
        t += dt

    survived = health > 0 and t >= duration
    return EventResult(
        survived=survived,
        survival_seconds=min(t,duration),
        damage=damage_total,
        kills=kills,
        elite_kills=elite_kills,
        level=level,
        xp=total_xp,
        coins=coins,
        chests=chests,
        health_remaining=max(0,health),
        max_health=max_health,
        damage_taken=damage_taken,
        healing=healing,
        projectile_events=projectile_events,
        event_budget_saturated=saturated,
        timeline=timeline
    )
