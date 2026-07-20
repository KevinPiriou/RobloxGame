from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path
from typing import Any


SOURCE_FILES = (
    "src/shared/CombatConfig.luau",
    "src/shared/Perks.luau",
    "src/shared/RunItemConfig.luau",
    "src/shared/BuildMetaConfig.luau",
    "src/server/PerkService.luau",
    "src/server/RunItemService.luau",
    "src/server/RunScoreService.luau",
    "src/server/JumpBonusService.luau",
    "src/server/WeaponService.luau",
    "src/server/MonsterService.luau",
    "src/server/ChestService.luau",
)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_project_root(catalog_path: Path) -> Path:
    resolved = catalog_path.resolve()
    for parent in (resolved.parent, *resolved.parents):
        if (parent / "src" / "shared" / "CombatConfig.luau").is_file():
            return parent
    raise ValueError(
        "Racine Roblox introuvable depuis le catalogue. "
        "Le dossier doit rester dans le depot du projet."
    )


def current_commit(project_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout.strip() or None


def capture_source_snapshot(project_root: Path) -> dict[str, Any]:
    files: dict[str, str] = {}
    missing: list[str] = []
    for relative in SOURCE_FILES:
        path = project_root / relative
        if not path.is_file():
            missing.append(relative)
            continue
        files[relative] = file_sha256(path)
    if missing:
        raise ValueError(
            "Sources MetaBuild manquantes : " + ", ".join(missing)
        )
    return {
        "format": "sha256-v1",
        "commit": current_commit(project_root),
        "files": files,
    }


def inspect_source_snapshot(
    catalog: dict[str, Any], catalog_path: Path
) -> dict[str, Any]:
    project_root = find_project_root(catalog_path)
    expected = catalog.get("meta", {}).get("source_snapshot")
    if not isinstance(expected, dict):
        return {
            "ok": False,
            "status": "missing_snapshot",
            "project_root": str(project_root),
            "changed": [],
            "missing": list(SOURCE_FILES),
        }

    expected_files = expected.get("files", {})
    if not isinstance(expected_files, dict):
        expected_files = {}

    changed: list[str] = []
    missing: list[str] = []
    untracked_by_snapshot: list[str] = []
    current_hashes: dict[str, str] = {}

    for relative in SOURCE_FILES:
        path = project_root / relative
        if not path.is_file():
            missing.append(relative)
            continue
        current_hash = file_sha256(path)
        current_hashes[relative] = current_hash
        expected_hash = expected_files.get(relative)
        if expected_hash is None:
            untracked_by_snapshot.append(relative)
        elif expected_hash != current_hash:
            changed.append(relative)

    unknown_files = sorted(set(expected_files) - set(SOURCE_FILES))
    ok = not changed and not missing and not untracked_by_snapshot
    return {
        "ok": ok,
        "status": "current" if ok else "stale",
        "project_root": str(project_root),
        "snapshot_commit": expected.get("commit"),
        "current_commit": current_commit(project_root),
        "changed": changed,
        "missing": missing,
        "untracked_by_snapshot": untracked_by_snapshot,
        "unknown_snapshot_files": unknown_files,
        "current_hashes": current_hashes,
    }


def require_current_sources(
    catalog: dict[str, Any], catalog_path: Path
) -> dict[str, Any]:
    report = inspect_source_snapshot(catalog, catalog_path)
    if report["ok"]:
        return report
    details = report.get("changed", []) + report.get("missing", [])
    details += report.get("untracked_by_snapshot", [])
    suffix = ": " + ", ".join(details) if details else ""
    raise ValueError(
        "Catalogue MetaBuild perime ou sans preuve de provenance" + suffix + ". "
        "Reexporter les donnees Roblox puis relancer import-roblox."
    )
