#!/usr/bin/env python3
"""eval-skills.py — Static quality evaluator for OMA SKILL.md and plugin.json.

Attribution
-----------
Adapted from Atom-oh/oh-my-cloud-skills/scripts/eval-skills.py (MIT License).
OMA extends the check set for the SKILL.md frontmatter contract adopted from
awslabs/agent-plugins (Apache-2.0) and enforces OMA documentation style rules.

Copyright (c) Atom-oh contributors — original structure.
Copyright (c) 2026 oh-my-aidlcops contributors — extensions and OMA checks.
License: MIT (see NOTICE).

Usage:
    python3 scripts/eval-skills.py
    python3 scripts/eval-skills.py --strict
    python3 scripts/eval-skills.py --plugin agentic-platform
    python3 scripts/eval-skills.py --skill agentic-eks-bootstrap

Checks per SKILL.md
    - YAML frontmatter present with `name` and `description`.
    - `description` >= 20 characters.
    - Body has a "When to Use" section.
    - Body has "참고 자료" or "References" section.
    - Body length 50–500 lines (warn outside).
    - No H1 heading (`^# ` on its own line).
    - No first-person Korean pronouns (저는, 제가, 우리는, 우리가).
    - `allowed-tools` is a string (not a YAML list).
    - `model` is one of the approved Claude IDs or empty.

Checks per plugin.json
    - Description <= 500 chars.
    - Version follows SemVer.
    - Keywords is a non-empty array.

Exit codes:
    0  every skill/plugin passed (or only WARNs without --strict)
    1  at least one FAIL (or WARN with --strict)
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
APPROVED_MODELS = {
    "claude-opus-4-7",
    "claude-opus-4-6",
    "claude-sonnet-4-6",
    "claude-haiku-4-5",
    "",  # empty/absent is acceptable
}

FIRST_PERSON_KO = ("저는", "제가", "우리는", "우리가")
SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[a-zA-Z0-9.-]+)?$")
FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------
@dataclass
class Report:
    target: Path
    kind: str
    pass_count: int = 0
    warn_count: int = 0
    fail_count: int = 0
    messages: List[Tuple[str, str]] = field(default_factory=list)

    def ok(self, name: str) -> None:
        self.pass_count += 1
        self.messages.append(("PASS", name))

    def warn(self, name: str, detail: str = "") -> None:
        self.warn_count += 1
        self.messages.append(("WARN", f"{name}: {detail}" if detail else name))

    def fail(self, name: str, detail: str = "") -> None:
        self.fail_count += 1
        self.messages.append(("FAIL", f"{name}: {detail}" if detail else name))


# ---------------------------------------------------------------------------
# Frontmatter parsing (adapted from oh-my-cloud-skills)
# ---------------------------------------------------------------------------
def parse_frontmatter(text: str) -> Tuple[Dict[str, Any], str]:
    """Return (fm_dict, body). Supports scalars and inline arrays."""
    m = FRONTMATTER_RE.match(text)
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
# Skill checks
# ---------------------------------------------------------------------------
def eval_skill(skill_md: Path) -> Report:
    report = Report(target=skill_md, kind="skill")
    try:
        text = skill_md.read_text(encoding="utf-8")
    except OSError as exc:
        report.fail("read", str(exc))
        return report

    fm, body = parse_frontmatter(text)

    # name
    name = fm.get("name")
    if not name:
        report.fail("frontmatter.name", "missing")
    elif not re.match(r"^[a-z][a-z0-9-]*$", str(name)):
        report.fail("frontmatter.name", f"must be kebab-case: {name}")
    else:
        report.ok("frontmatter.name")

    # description
    description = fm.get("description", "")
    if not description:
        report.fail("frontmatter.description", "missing")
    elif len(str(description)) < 20:
        report.fail("frontmatter.description",
                    f"length {len(str(description))} < 20 chars")
    else:
        report.ok("frontmatter.description")

    # allowed-tools — string, not list
    allowed_tools = fm.get("allowed-tools")
    if allowed_tools is not None:
        if isinstance(allowed_tools, list):
            report.fail("frontmatter.allowed-tools",
                        "must be a comma-separated string, not a YAML list")
        elif not isinstance(allowed_tools, str):
            report.fail("frontmatter.allowed-tools",
                        f"unexpected type {type(allowed_tools).__name__}")
        else:
            report.ok("frontmatter.allowed-tools")

    # model — one of the approved IDs
    model = fm.get("model", "")
    if str(model) not in APPROVED_MODELS:
        report.fail("frontmatter.model",
                    f"'{model}' not in approved list {sorted(APPROVED_MODELS)}")
    else:
        report.ok("frontmatter.model")

    # Body sections
    when_to_use_patterns = [
        r"^\s*##\s+When to Use",
        r"^\s*##\s+언제 사용",
        r"^\s*##\s+사용 시점",
        r"^\s*##\s+언제 써",
    ]
    if any(re.search(p, body, re.MULTILINE | re.IGNORECASE) for p in when_to_use_patterns):
        report.ok("body.when-to-use")
    else:
        report.fail("body.when-to-use", "section missing (accepts 'When to Use' / '언제 사용' / '사용 시점')")

    if re.search(r"^\s*##\s+(참고 자료|References)\b", body, re.MULTILINE):
        report.ok("body.references")
    else:
        report.fail("body.references", "'## 참고 자료' or '## References' missing")

    # Body length
    body_lines = len([ln for ln in body.splitlines() if ln.strip()])
    if body_lines < 50:
        report.warn("body.length", f"{body_lines} lines (<50 — too terse)")
    elif body_lines > 500:
        report.warn("body.length", f"{body_lines} lines (>500 — consider splitting)")
    else:
        report.ok("body.length")

    # No H1 outside frontmatter (ignore content inside fenced code blocks)
    body_no_code = re.sub(r"^```[\s\S]*?^```", "", body, flags=re.MULTILINE)
    if re.search(r"^# \S", body_no_code, re.MULTILINE):
        report.fail("body.no-h1", "H1 heading detected — use H2/H3 (title lives in frontmatter)")
    else:
        report.ok("body.no-h1")

    # No first-person Korean pronouns
    offenders = [tok for tok in FIRST_PERSON_KO if tok in body]
    if offenders:
        report.fail("body.no-first-person-ko",
                    f"found Korean first-person pronouns: {', '.join(offenders)}")
    else:
        report.ok("body.no-first-person-ko")

    return report


# ---------------------------------------------------------------------------
# Plugin checks
# ---------------------------------------------------------------------------
def eval_plugin(plugin_json: Path) -> Report:
    report = Report(target=plugin_json, kind="plugin")
    try:
        data = json.loads(plugin_json.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        report.fail("read/parse", str(exc))
        return report

    description = data.get("description", "")
    if not description:
        report.fail("description", "missing")
    elif len(description) > 500:
        report.fail("description", f"length {len(description)} > 500 chars")
    else:
        report.ok("description")

    version = data.get("version", "")
    if not version:
        report.fail("version", "missing")
    elif not SEMVER_RE.match(version):
        report.fail("version", f"'{version}' not SemVer (x.y.z[-pre])")
    else:
        report.ok("version")

    keywords = data.get("keywords") or []
    if not isinstance(keywords, list) or not keywords:
        report.fail("keywords", "missing or empty")
    else:
        report.ok("keywords")

    return report


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------
def find_skills(repo_dir: Path, plugin_filter: Optional[str],
                skill_filter: Optional[str]) -> List[Path]:
    plugins_dir = repo_dir / "plugins"
    if not plugins_dir.is_dir():
        return []
    out: List[Path] = []
    for plugin in sorted(p for p in plugins_dir.iterdir() if p.is_dir()):
        if plugin_filter and plugin.name != plugin_filter:
            continue
        skills_dir = plugin / "skills"
        if not skills_dir.is_dir():
            continue
        for skill in sorted(s for s in skills_dir.iterdir() if s.is_dir()):
            if skill_filter and skill.name != skill_filter:
                continue
            md = skill / "SKILL.md"
            if md.exists():
                out.append(md)
    return out


def find_plugin_manifests(repo_dir: Path,
                          plugin_filter: Optional[str]) -> List[Path]:
    plugins_dir = repo_dir / "plugins"
    if not plugins_dir.is_dir():
        return []
    out: List[Path] = []
    for plugin in sorted(p for p in plugins_dir.iterdir() if p.is_dir()):
        if plugin_filter and plugin.name != plugin_filter:
            continue
        manifest = plugin / ".claude-plugin" / "plugin.json"
        if manifest.exists():
            out.append(manifest)
    return out


# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------
def print_report(report: Report, verbose: bool) -> None:
    header = f"{report.kind.upper():<7} {report.target}"
    status = "OK"
    if report.fail_count:
        status = "FAIL"
    elif report.warn_count:
        status = "WARN"
    print(f"[{status:<4}] {header} "
          f"(pass={report.pass_count} warn={report.warn_count} fail={report.fail_count})")
    for level, msg in report.messages:
        if level == "PASS" and not verbose:
            continue
        print(f"        {level:<4} {msg}")


def aggregate(reports: Iterable[Report]) -> Tuple[int, int, int]:
    p = w = f = 0
    for r in reports:
        p += r.pass_count
        w += r.warn_count
        f += r.fail_count
    return p, w, f


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="eval-skills.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--repo-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="OMA repository root (default: inferred from script location).",
    )
    parser.add_argument("--plugin", help="Limit to a single plugin name.")
    parser.add_argument("--skill", help="Limit to a single skill name.")
    parser.add_argument("--strict", action="store_true",
                        help="Treat WARNs as FAILs (exit 1 on any warning).")
    parser.add_argument("--verbose", action="store_true",
                        help="Print every PASS line in addition to WARN/FAIL.")
    args = parser.parse_args(argv)

    repo_dir: Path = args.repo_dir.resolve()

    reports: List[Report] = []
    for manifest in find_plugin_manifests(repo_dir, args.plugin):
        reports.append(eval_plugin(manifest))
    for skill_md in find_skills(repo_dir, args.plugin, args.skill):
        reports.append(eval_skill(skill_md))

    if not reports:
        print("no skills or plugin manifests found.")
        return 0

    for r in reports:
        print_report(r, verbose=args.verbose)

    p, w, f = aggregate(reports)
    print()
    print(f"Totals: pass={p}, warn={w}, fail={f}, items={len(reports)}")

    if f > 0:
        return 1
    if args.strict and w > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
