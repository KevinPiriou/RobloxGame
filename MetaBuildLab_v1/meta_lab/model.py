
from __future__ import annotations
from dataclasses import dataclass, field
from collections import Counter, defaultdict
from typing import Any

DEFAULT_STATS = {
    "MaxHealth":100.0,"MoveSpeed":15.0,"JumpPower":55.0,
    "JumpPercent":0.0,
    "DamagePercent":0.0,"FlatDamage":0.0,"EliteFlatDamage":0.0,
    "AttackSpeedPercent":0.0,"ProjectileCount":0.0,"ProjectileSpeedPercent":0.0,
    "EffectDurationPercent":0.0,"BounceCount":0.0,"CritChance":0.0,
    "CritMultiplierBonus":0.0,"LifeStealPercent":0.0,"HealthRegen":0.0,
    "MaxHealthBonus":0.0,"Shield":0.0,"XpGainPercent":0.0,"GoldGainPercent":0.0,
    "Luck":0.0,"ArmorPercent":0.0,"EnemyCountPercent":0.0,"CollectRadius":0.0,
    "StepScorePercent":0.0,"MetaCritSynergy":0.0,"MetaCoverageSynergy":0.0,
}

@dataclass
class Acquisition:
    category: str
    content_id: str
    rarity: str = ""
    stack: int = 1

    def token(self) -> str:
        suffix = f"[{self.rarity}]" if self.rarity else ""
        return f"{self.category}:{self.content_id}{suffix}"

@dataclass
class Build:
    build_id: str
    character_id: str
    weapon_levels: dict[str, int]
    acquisitions: list[Acquisition]
    profile_origin: str
    generation_seed: int
    analytical: dict[str, Any] = field(default_factory=dict)
    event_results: dict[str, dict[str, Any]] = field(default_factory=dict)
    meta_score: float = 0.0
    comments: list[str] = field(default_factory=list)

    def signature(self) -> str:
        counts = Counter(a.token() for a in self.acquisitions)
        parts = [f"character:{self.character_id}"]
        parts.extend(f"weapon:{wid}@{lvl}" for wid, lvl in sorted(self.weapon_levels.items()))
        parts.extend(f"{token}x{count}" for token, count in sorted(counts.items()))
        return "|".join(parts)

    def component_ids(self) -> set[str]:
        result = {f"character:{self.character_id}"}
        result.update(f"weapon:{wid}" for wid in self.weapon_levels)
        result.update(f"{a.category}:{a.content_id}" for a in self.acquisitions)
        return result

@dataclass
class RuntimeBuild:
    stats: dict[str, float] = field(default_factory=lambda: dict(DEFAULT_STATS))
    stacks: Counter = field(default_factory=Counter)
    components: set[str] = field(default_factory=set)
    tags: Counter = field(default_factory=Counter)
    trigger_effects: dict[str, list[tuple[dict[str, Any], int, str]]] = field(
        default_factory=lambda: defaultdict(list)
    )
    counters: Counter = field(default_factory=Counter)
    active_synergies: list[str] = field(default_factory=list)
    shield: float = 0.0

@dataclass
class Enemy:
    enemy_id: int
    hp: float
    max_hp: float
    damage: float
    attack_cooldown: float
    elite: bool
    xp: float
    alive: bool = True

@dataclass
class EventResult:
    survived: bool
    survival_seconds: float
    damage: float
    kills: int
    elite_kills: int
    level: int
    xp: float
    coins: float
    chests: int
    health_remaining: float
    max_health: float
    damage_taken: float
    healing: float
    projectile_events: int
    event_budget_saturated: bool
    timeline: list[dict[str, float]]
