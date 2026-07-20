import importlib.util
import copy
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("seed_validator", ROOT / "seed_validator.py")
VALIDATOR = importlib.util.module_from_spec(SPEC)
sys.modules["seed_validator"] = VALIDATOR
assert SPEC.loader is not None
SPEC.loader.exec_module(VALIDATOR)


class MegaSeedValidatorSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.config = VALIDATOR.load_config(ROOT / "config" / "current_project.json")

    def test_portable_generation_is_deterministic(self):
        first = VALIDATOR.generate_plan(12345, self.config, "portable")
        second = VALIDATOR.generate_plan(12345, self.config, "portable")
        self.assertEqual(first["selected_layouts"], second["selected_layouts"])
        result = VALIDATOR.analyze_plan(first, self.config)
        self.assertIn(result["status"], {"VALID", "INVALID"})
        self.assertGreaterEqual(result["score"], 0)
        self.assertLessEqual(result["score"], 100)

    def test_project_snapshot_is_current(self):
        status = VALIDATOR.source_snapshot(self.config)
        self.assertTrue(status["ok"], status)
        self.assertEqual(len(status["checks"]), 5)

    def test_production_guard_is_declared(self):
        parity = VALIDATOR.parity_metadata(self.config, "portable")
        guard = parity["production_guard"]
        self.assertTrue(guard["enabled"])
        self.assertTrue(guard["uses_roblox_random"])
        self.assertGreaterEqual(guard["maximum_attempts"], 2)

    def test_stale_snapshot_is_rejected(self):
        stale = copy.deepcopy(self.config)
        stale["project"]["procedural_service_blob"] = "0" * 40
        with self.assertRaises(RuntimeError):
            VALIDATOR.require_current_snapshot(stale)

    def test_output_directory_rejects_a_concurrent_batch(self):
        with tempfile.TemporaryDirectory(prefix="mega_seed_validator_lock_") as directory:
            lock = Path(directory) / ".batch.lock"
            with VALIDATOR.exclusive_batch_lock(lock):
                with self.assertRaises(RuntimeError):
                    with VALIDATOR.exclusive_batch_lock(lock):
                        self.fail("Le second verrou ne doit jamais être acquis.")

    def test_second_batch_replaces_previous_campaign(self):
        with tempfile.TemporaryDirectory(prefix="mega_seed_validator_") as directory:
            output = Path(directory)
            VALIDATOR.run_batch(self.config, 1, 5, 1, "portable", output, 3, 3)
            metadata = VALIDATOR.run_batch(self.config, 10, 2, 1, "portable", output, 2, 1)

            connection = sqlite3.connect(output / "results.sqlite")
            try:
                seeds = [row[0] for row in connection.execute("SELECT seed FROM seed_results ORDER BY seed")]
            finally:
                connection.close()

            self.assertEqual(seeds, [10, 11])
            self.assertLessEqual(len(list((output / "previews").glob("seed_*.svg"))), 1)
            self.assertLessEqual(len(list((output / "plans").glob("seed_*.json"))), 1)
            self.assertTrue(metadata["source_snapshot"]["ok"])
            self.assertFalse(metadata["parity"]["exact_with_production"])
            self.assertEqual(metadata["parity"]["seed_identity"], "synthetic")

            persisted = json.loads((output / "run_metadata.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["start_seed"], 10)
            self.assertEqual(persisted["count"], 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
