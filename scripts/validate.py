#!/usr/bin/env python3
"""validate.py — JSON Schema validation for OMA plugin / skill / MCP manifests.

Walks the oh-my-aidlcops repository and validates every manifest against its
published schema. Exits 0 when all checks pass, 1 on the first failure.

Usage:
    python3 scripts/validate.py
    python3 scripts/validate.py --fix-hint
    python3 scripts/validate.py --repo-dir /path/to/oh-my-aidlcops

Targets:
    plugins/<name>/.claude-plugin/plugin.json    → schemas/plugin.schema.json
    plugins/<name>/skills/<skill>/SKILL.md       → schemas/skill-frontmatter.schema.json
    plugins/<name>/.mcp.json                      → schemas/mcp.schema.json
    .claude-plugin/marketplace.json               → schemas/marketplace.schema.json

Dependencies:
    - Python 3.9+
    - jsonschema (optional; falls back to manual required-key checks when
      unavailable so the script still provides value in minimal environments)

Exit codes:
    0  all manifests valid
    1  one or more validation failures
    2  configuration or runtime error (e.g. missing schema file)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import jsonschema  # type: ignore
    _HAS_JSONSCHEMA = True
except ImportError:  # pragma: no cover - fallback path
    _HAS_JSONSCHEMA = False


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------
@dataclass
class Result:
    path: Path
    kind: str
    ok: bool
    errors: List[str] = field(default_factory=list)
    hints: List[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# YAML frontmatter parsing (minimal, dependency-free)
# ---------------------------------------------------------------------------
_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)


def parse_frontmatter(text: str) -> Tuple[Dict[str, Any], str]:
    """Return (frontmatter_dict, body). Handles simple scalars and lists."""
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    raw = m.group(1)
    body = text[m.end():]

    data: Dict[str, Any] = {}
    current_key: Optional[str] = None
    current_list: List[str] = []
    in_list = False

    for raw_line in raw.splitlines():
        line = raw_line.rstrip()
        if not line.strip():
            continue
        list_item = re.match(r"^\s*-\s+(.*)$", line)
        if list_item and in_list:
            current_list.append(list_item.group(1).strip().strip('"').strip("'"))
            continue
        kv = re.match(r"^([A-Za-z_][A-Za-z0-9_\-]*):\s*(.*)$", line)
        if kv:
            if current_key and in_list:
                data[current_key] = current_list
                current_list = []
            key = kv.group(1)
            value = kv.group(2).strip()
            if not value:
                current_key = key
                in_list = True
                current_list = []
            else:
                current_key = key
                in_list = False
                # Coerce booleans
                if value.lower() == "true":
                    data[key] = True
                elif value.lower() == "false":
                    data[key] = False
                else:
                    data[key] = value.strip('"').strip("'")
    if current_key and in_list:
        data[current_key] = current_list
    return data, body


# ---------------------------------------------------------------------------
# Validation core
# ---------------------------------------------------------------------------
def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def load_schema(schema_path: Path) -> Dict[str, Any]:
    if not schema_path.exists():
        raise FileNotFoundError(f"schema missing: {schema_path}")
    return load_json(schema_path)


def validate_against(instance: Any, schema: Dict[str, Any]) -> List[str]:
    """Return a list of error strings. Empty list == valid."""
    if _HAS_JSONSCHEMA:
        try:
            jsonschema.validate(instance=instance, schema=schema)
            return []
        except jsonschema.ValidationError as exc:  # type: ignore[attr-defined]
            path = ".".join(str(p) for p in exc.absolute_path) or "<root>"
            return [f"{path}: {exc.message}"]
        except jsonschema.SchemaError as exc:  # type: ignore[attr-defined]
            return [f"schema error: {exc.message}"]
    # Fallback: check required keys + minimal pattern enforcement.
    return _manual_validate(instance, schema, root=True)


def _manual_validate(instance: Any, schema: Dict[str, Any], root: bool) -> List[str]:
    errors: List[str] = []
    if not isinstance(schema, dict):
        return errors
    expected_type = schema.get("type")
    if expected_type == "object" and not isinstance(instance, dict):
        errors.append(f"expected object, got {type(instance).__name__}")
        return errors
    if expected_type == "array" and not isinstance(instance, list):
        errors.append(f"expected array, got {type(instance).__name__}")
        return errors
    if isinstance(instance, dict):
        for key in schema.get("required", []) or []:
            if key not in instance:
                errors.append(f"missing required key: {key}")
        props = schema.get("properties", {}) or {}
        for key, sub in props.items():
            if key in instance and isinstance(sub, dict):
                errors.extend(_manual_validate(instance[key], sub, root=False))
    return errors


# ---------------------------------------------------------------------------
# Hint generation
# ---------------------------------------------------------------------------
_HINTS = {
    "plugin.json": (
        "Add a name (kebab-case), description (<=500 chars), and SemVer version. "
        "See schemas/plugin.schema.json for the full contract."
    ),
    "SKILL.md": (
        "SKILL.md requires YAML frontmatter with `name` (kebab-case) and "
        "`description` (>=20 chars). See schemas/skill-frontmatter.schema.json."
    ),
    ".mcp.json": (
        "Top-level key must be `mcpServers` (object). stdio servers require "
        "`command`; http servers require `url`."
    ),
    "marketplace.json": (
        "Required: name, owner.name, metadata.{description,version}, plugins[] "
        "with at least name + source. See schemas/marketplace.schema.json."
    ),
}


def hint_for(path: Path) -> str:
    name = path.name
    if name in _HINTS:
        return _HINTS[name]
    if name == "SKILL.md":
        return _HINTS["SKILL.md"]
    return "No hint available."


# ---------------------------------------------------------------------------
# Manifest discovery
# ---------------------------------------------------------------------------
def discover(repo_dir: Path) -> Dict[str, List[Path]]:
    plugins_dir = repo_dir / "plugins"
    results: Dict[str, List[Path]] = {
        "marketplace": [],
        "plugin": [],
        "skill": [],
        "mcp": [],
    }
    mp = repo_dir / ".claude-plugin" / "marketplace.json"
    if mp.exists():
        results["marketplace"].append(mp)
    if plugins_dir.is_dir():
        for plugin in sorted(p for p in plugins_dir.iterdir() if p.is_dir()):
            manifest = plugin / ".claude-plugin" / "plugin.json"
            if manifest.exists():
                results["plugin"].append(manifest)
            mcp = plugin / ".mcp.json"
            if mcp.exists():
                results["mcp"].append(mcp)
            skills_dir = plugin / "skills"
            if skills_dir.is_dir():
                for skill in sorted(s for s in skills_dir.iterdir() if s.is_dir()):
                    sm = skill / "SKILL.md"
                    if sm.exists():
                        results["skill"].append(sm)
    return results


# ---------------------------------------------------------------------------
# Validation phases
# ---------------------------------------------------------------------------
def validate_file(path: Path, schema: Dict[str, Any], kind: str,
                  fix_hint: bool) -> Result:
    result = Result(path=path, kind=kind, ok=True)
    try:
        if kind == "skill":
            text = path.read_text(encoding="utf-8")
            frontmatter, _ = parse_frontmatter(text)
            if not frontmatter:
                result.ok = False
                result.errors.append("missing YAML frontmatter")
            else:
                errs = validate_against(frontmatter, schema)
                if errs:
                    result.ok = False
                    result.errors.extend(errs)
        else:
            instance = load_json(path)
            errs = validate_against(instance, schema)
            if errs:
                result.ok = False
                result.errors.extend(errs)
    except json.JSONDecodeError as exc:
        result.ok = False
        result.errors.append(f"invalid JSON: {exc}")
    except Exception as exc:  # pragma: no cover - defensive
        result.ok = False
        result.errors.append(f"{type(exc).__name__}: {exc}")
    if not result.ok and fix_hint:
        result.hints.append(hint_for(path))
    return result


def pretty_report(results: List[Result]) -> Tuple[int, int]:
    passed = 0
    failed = 0
    for r in results:
        status = "PASS" if r.ok else "FAIL"
        print(f"[{status}] {r.kind:<11} {r.path}")
        if not r.ok:
            failed += 1
            for err in r.errors:
                print(f"       - {err}")
            for hint in r.hints:
                print(f"       hint: {hint}")
        else:
            passed += 1
    print()
    print(f"Summary: {passed} passed, {failed} failed, {len(results)} total")
    return passed, failed


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="validate.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="OMA repository root (default: inferred from script location).",
    )
    parser.add_argument(
        "--fix-hint",
        action="store_true",
        help="Print corrective hints alongside each failure.",
    )
    args = parser.parse_args(argv)

    repo_dir: Path = args.repo_dir.resolve()
    schemas_dir = repo_dir / "schemas"
    if not schemas_dir.is_dir():
        print(f"error: schemas directory not found at {schemas_dir}", file=sys.stderr)
        return 2

    try:
        schema_map = {
            "marketplace": load_schema(schemas_dir / "marketplace.schema.json"),
            "plugin": load_schema(schemas_dir / "plugin.schema.json"),
            "skill": load_schema(schemas_dir / "skill-frontmatter.schema.json"),
            "mcp": load_schema(schemas_dir / "mcp.schema.json"),
        }
    except FileNotFoundError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if not _HAS_JSONSCHEMA:
        print("warning: jsonschema package not installed — falling back to "
              "required-key validation only.", file=sys.stderr)

    inventory = discover(repo_dir)
    results: List[Result] = []
    for kind, paths in inventory.items():
        for path in paths:
            results.append(
                validate_file(path, schema_map[kind], kind, args.fix_hint)
            )

    if not results:
        print("no manifests found to validate.")
        return 0

    _, failed = pretty_report(results)
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
