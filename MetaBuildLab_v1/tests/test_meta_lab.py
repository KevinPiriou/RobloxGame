from __future__ import annotations

import copy
import hashlib
import json
import math
import tempfile
import unittest
from pathlib import Path

from meta_lab.analyzer import (
    minimum_coverage_candidates,
    run_analysis,
    sampling_coverage,
)
from meta_lab.catalog import (
    catalog_support_report,
    load_catalog,
    validate_catalog,
)
from meta_lab.engine import analytical_evaluate, draft_build, event_simulate
from meta_lab.evidence import inspect_source_snapshot
from meta_lab.model import Acquisition, Build
from meta_lab.roblox_adapter import import_roblox_snapshot


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "catalogs" / "current_project.json"
CATALOG = load_catalog(CATALOG_PATH)


def empty_build() -> Build:
    return Build(
        build_id="test_build",
        character_id="default_character",
        weapon_levels={"fireball": 1},
        acquisitions=[],
        profile_origin="medium",
        generation_seed=123,
    )


class CatalogContractTests(unittest.TestCase):
    def test_current_catalog_is_supported_and_current(self) -> None:
        validate_catalog(CATALOG)
        support = catalog_support_report(CATALOG)
        source = inspect_source_snapshot(CATALOG, CATALOG_PATH)
        self.assertEqual(support["model_status"], "theoretical_supported")
        self.assertEqual(support["unsupported"], [])
        self.assertTrue(source["ok"], source)

    def test_nested_unknown_effect_is_rejected(self) -> None:
        invalid = copy.deepcopy(CATALOG)
        invalid["perks"][0]["variants"]["Common"]["effects"][0][
            "type"
        ] = "silent_future_effect"
        with self.assertRaisesRegex(ValueError, "non supporte"):
            validate_catalog(invalid)

    def test_unimplemented_trigger_is_rejected(self) -> None:
        invalid = copy.deepcopy(CATALOG)
        invalid["perks"][0]["variants"]["Common"]["effects"][0][
            "trigger"
        ] = "EveryNSeconds"
        with self.assertRaisesRegex(ValueError, "trigger non supporte"):
            validate_catalog(invalid)

    def test_unimplemented_effect_is_rejected(self) -> None:
        invalid = copy.deepcopy(CATALOG)
        invalid["perks"][0]["variants"]["Common"]["effects"][0][
            "type"
        ] = "heal"
        with self.assertRaisesRegex(ValueError, "type non supporte"):
            validate_catalog(invalid)

    def test_unimplemented_weapon_behavior_is_rejected(self) -> None:
        invalid = copy.deepcopy(CATALOG)
        invalid["weapons"][0]["behaviors"].append(
            {"type": "future_silent_weapon_behavior"}
        )
        with self.assertRaisesRegex(ValueError, "non supporte"):
            validate_catalog(invalid)

    def test_stale_source_hash_is_detected(self) -> None:
        stale = copy.deepcopy(CATALOG)
        first_source = next(iter(stale["meta"]["source_snapshot"]["files"]))
        stale["meta"]["source_snapshot"]["files"][first_source] = "0" * 64
        with tempfile.TemporaryDirectory(dir=ROOT) as temp_dir:
            path = Path(temp_dir) / "stale_catalog.json"
            path.write_text(json.dumps(stale), encoding="utf-8")
            report = inspect_source_snapshot(stale, path)
        self.assertFalse(report["ok"])
        self.assertIn(first_source, report["changed"])

    def test_distribution_manifest_matches_files(self) -> None:
        manifest = json.loads(
            (ROOT / "MANIFEST.sha256.json").read_text(encoding="utf-8")
        )
        self.assertIn("meta_lab/evidence.py", manifest)
        for relative, expected in manifest.items():
            with self.subTest(file=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file(), relative)
                actual = hashlib.sha256(path.read_bytes()).hexdigest()
                self.assertEqual(actual, expected)


class ModelEvidenceTests(unittest.TestCase):
    def test_proof_analysis_refuses_incomplete_catalog_coverage(self) -> None:
        required = minimum_coverage_candidates(CATALOG)
        with tempfile.TemporaryDirectory(dir=ROOT) as temp_dir:
            with self.assertRaisesRegex(ValueError, "couvir le catalogue|couvrir le catalogue"):
                run_analysis(
                    CATALOG,
                    Path(temp_dir),
                    candidates=required - 1,
                    top_event=1,
                    repetitions=1,
                )

    def test_draft_and_event_are_deterministic(self) -> None:
        first = draft_build(CATALOG, "medium", 123, 1)
        second = draft_build(CATALOG, "medium", 123, 1)
        self.assertEqual(first.signature(), second.signature())

        scenario = dict(CATALOG["run_scenarios"][0])
        scenario["duration_seconds"] = 10
        event_a = event_simulate(CATALOG, first, "medium", scenario, 42)
        event_b = event_simulate(CATALOG, first, "medium", scenario, 42)
        self.assertEqual(event_a, event_b)

    def test_damage_upgrade_increases_expected_dps(self) -> None:
        base = empty_build()
        upgraded = empty_build()
        upgraded.acquisitions.append(
            Acquisition("perk", "damage_percent", "Common", 1)
        )
        base_score = analytical_evaluate(CATALOG, base, "medium")
        upgraded_score = analytical_evaluate(CATALOG, upgraded, "medium")
        self.assertGreater(upgraded_score["dps"], base_score["dps"])

    def test_jump_upgrade_increases_declared_mobility_proxy(self) -> None:
        base = empty_build()
        upgraded = empty_build()
        upgraded.acquisitions.append(
            Acquisition("perk", "jump_bonus", "Common", 1)
        )
        base_score = analytical_evaluate(CATALOG, base, "medium")
        upgraded_score = analytical_evaluate(CATALOG, upgraded, "medium")
        self.assertGreater(
            upgraded_score["mobility_proxy"], base_score["mobility_proxy"]
        )

    def test_supported_weapon_behaviors_execute_in_both_models(self) -> None:
        behaviors = {
            "projectile": {},
            "homing": {"accuracy_bonus": 0.1},
            "bounce": {"count": 1, "damage_multiplier": 0.8},
            "pierce": {"targets": 1, "damage_multiplier": 0.8},
            "explosion": {"targets": 2, "damage_multiplier": 0.4},
            "persistent_area": {"ticks": 2, "damage_multiplier": 0.3},
            "chain": {"targets": 2, "damage_multiplier": 0.6},
            "orbital": {"orbs": 1},
            "summon": {"attacks": 1},
            "contact": {"contacts": 1, "damage_multiplier": 0.5},
            "beam": {"targets": 2, "damage_multiplier": 0.8},
            "dot": {"status": "poison", "chance": 0.5},
            "return": {"damage_multiplier": 0.7},
            "fragmentation": {"count": 2, "damage_multiplier": 0.3},
            "distance_scaling": {"max_bonus": 0.5},
            "health_scaling": {"missing_health_bonus": 0.5},
            "execute": {"threshold": 0.15},
        }
        for kind, fields in behaviors.items():
            with self.subTest(behavior=kind):
                catalog = copy.deepcopy(CATALOG)
                behavior = {"type": kind, **fields}
                catalog["weapons"][0]["behaviors"] = [behavior]
                validate_catalog(catalog)
                build = empty_build()
                analytical = analytical_evaluate(catalog, build, "medium")
                self.assertTrue(math.isfinite(analytical["raw_power"]))
                scenario = dict(catalog["run_scenarios"][0])
                scenario["duration_seconds"] = 1
                event = event_simulate(
                    catalog, build, "medium", scenario, 42
                )
                self.assertTrue(math.isfinite(event.damage))


class FutureContentTests(unittest.TestCase):
    def make_future_catalog(self) -> dict:
        future = copy.deepcopy(CATALOG)
        character = copy.deepcopy(future["characters"][0])
        character["id"] = "future_mage"
        character["name"] = "Mage futur"
        character["base_stats"]["MaxHealth"] = 90
        future["characters"].append(character)

        weapon = copy.deepcopy(future["weapons"][0])
        weapon["id"] = "future_orb"
        weapon["name"] = "Orbe future"
        weapon["base"]["damage"] = 18
        weapon["behaviors"] = [
            {"type": "projectile"},
            {"type": "chain", "targets": 2, "damage_multiplier": 0.6},
        ]
        future["weapons"].append(weapon)

        relic = copy.deepcopy(future["items"][0])
        relic["id"] = "future_relic"
        relic["name"] = "Relique future"
        relic["category"] = "relic"
        relic["effects"] = [{
            "trigger": "OnAcquire",
            "type": "stat",
            "stat": "MaxHealthBonus",
            "operation": "add",
            "value": 25,
        }]
        future["relics"] = [relic]

        curse = copy.deepcopy(relic)
        curse["id"] = "future_curse"
        curse["name"] = "Malediction future"
        curse["category"] = "curse"
        curse["effects"] = [{
            "trigger": "OnAcquire",
            "type": "stat",
            "stat": "DamagePercent",
            "operation": "add",
            "value": -0.05,
        }]
        future["curses"] = [curse]
        return future

    def test_future_character_and_weapon_are_sampled(self) -> None:
        future = self.make_future_catalog()
        validate_catalog(future)
        required = minimum_coverage_candidates(future)
        builds = [
            draft_build(
                future,
                "medium",
                987,
                index,
                coverage_draft=True,
            )
            for index in range(1, required + 1)
        ]
        coverage = sampling_coverage(future, builds)
        self.assertTrue(coverage["complete"], coverage)
        self.assertGreater(
            coverage["groups"]["characters"]["minimum_presence"], 0
        )
        self.assertGreater(
            coverage["groups"]["weapons"]["minimum_presence"], 0
        )
        self.assertGreater(
            coverage["groups"]["relics"]["minimum_presence"], 0
        )
        self.assertGreater(
            coverage["groups"]["curses"]["minimum_presence"], 0
        )

    def test_future_relic_is_applied_in_event_confirmation(self) -> None:
        future = self.make_future_catalog()
        build = empty_build()
        build.acquisitions.append(
            Acquisition("relic", "future_relic", "Common", 1)
        )
        scenario = dict(future["run_scenarios"][0])
        scenario["duration_seconds"] = 0
        result = event_simulate(future, build, "medium", scenario, 42)
        self.assertEqual(result.max_health, 125)

    def test_roblox_adapter_consumes_build_meta_content(self) -> None:
        future = self.make_future_catalog()
        raw = {
            "ExportedAt": 123456,
            "CombatConfig": {},
            "Perks": {
                "Definitions": {
                    "1": {
                        "Id": "future_perk",
                        "Name": "Perk futur",
                        "Variants": {
                            rarity: {
                                "Stats": {"DamagePercent": 0.1}
                            }
                            for rarity in CATALOG["settings"]["rarities"]
                        },
                    }
                },
                "Rarities": {},
            },
            "RunItemConfig": {
                "Definitions": {
                    "FutureItem": {
                        "Id": "future_item",
                        "Name": "Objet futur",
                        "Rarity": "Common",
                        "StatsPerStack": {"MoveSpeedPercent": 0.05},
                    }
                }
            },
            "BuildMetaConfig": {
                "SchemaVersion": 1,
                "Characters": {
                    str(index): value
                    for index, value in enumerate(future["characters"], 1)
                },
                "Weapons": {
                    str(index): value
                    for index, value in enumerate(future["weapons"], 1)
                },
            },
        }
        imported = import_roblox_snapshot(CATALOG, raw)
        validate_catalog(imported)
        self.assertEqual(
            {entry["id"] for entry in imported["characters"]},
            {"default_character", "future_mage"},
        )
        self.assertEqual(
            {entry["id"] for entry in imported["weapons"]},
            {"fireball", "future_orb"},
        )
        self.assertEqual(
            {entry["id"] for entry in imported["perks"]},
            {"future_perk"},
        )
        self.assertEqual(
            {entry["id"] for entry in imported["items"]},
            {"future_item"},
        )

    def test_roblox_adapter_rejects_unknown_item_mechanic(self) -> None:
        future = self.make_future_catalog()
        raw = {
            "CombatConfig": {},
            "Perks": {
                "Definitions": {
                    "1": {
                        "Id": "future_perk",
                        "Name": "Perk futur",
                        "Variants": {
                            rarity: {"Stats": {"DamagePercent": 0.1}}
                            for rarity in CATALOG["settings"]["rarities"]
                        },
                    }
                }
            },
            "RunItemConfig": {
                "Definitions": {
                    "FutureItem": {
                        "Id": "future_item",
                        "Name": "Objet futur",
                        "Rarity": "Common",
                        "FutureDamageRule": 10,
                    }
                }
            },
            "BuildMetaConfig": {
                "SchemaVersion": 1,
                "Characters": {"1": future["characters"][0]},
                "Weapons": {"1": future["weapons"][0]},
            },
        }
        with self.assertRaisesRegex(ValueError, "non modelises"):
            import_roblox_snapshot(CATALOG, raw)


if __name__ == "__main__":
    unittest.main()
