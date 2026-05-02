#!/usr/bin/env python3
"""sync-from-playbook.py — Mirror engineering-playbook docs into skill references.

Walks the companion `engineering-playbook` repository and regenerates a concise
index of relevant documents inside each OMA plugin under
`plugins/<plugin>/references/playbook-index.md`. Hand-authored reference files
(anything other than `playbook-index.md`) are never touched.

Usage:
    python3 scripts/sync-from-playbook.py
    python3 scripts/sync-from-playbook.py --dry-run
    python3 scripts/sync-from-playbook.py --playbook-dir ~/src/engineering-playbook
    python3 scripts/sync-from-playbook.py --plugin ai-infra

Default playbook locations probed in order:
    $ENGINEERING_PLAYBOOK_DIR
    $HOME/workspace/engineering-playbook
    ../engineering-playbook  (relative to the OMA repo root)

Coverage:
    docs/agentic-ai-platform/**/*.md → relevant to ai-infra, agenticops
    docs/aidlc/**/*.md                → relevant to aidlc, aidlc

Each indexed entry shows:
    - Title (frontmatter title, or first H1, or filename)
    - Tags (frontmatter tags)
    - First ~200 characters of the body as a synopsis
    - H2 table of contents (up to 8 headings)
    - GitHub URL built as
      https://github.com/<owner>/<repo>/blob/<branch>/<path>
      (falls back to a relative link when git metadata is unavailable)

Exit codes:
    0  index up to date (or would be after dry-run)
    1  playbook directory not found or no docs discovered
    2  runtime error while reading / writing files
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess  # nosec B404 - only used to invoke hardcoded `git` with no untrusted input
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple


# ---------------------------------------------------------------------------
# Plugin → playbook doc subtrees
# ---------------------------------------------------------------------------
PLUGIN_COVERAGE: Dict[str, List[str]] = {
    "ai-infra": ["docs/agentic-ai-platform"],
    "agenticops": ["docs/agentic-ai-platform/operations-mlops"],
    "aidlc": ["docs/aidlc"],
    "aidlc": ["docs/aidlc"],
}

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", re.DOTALL)
H1_RE = re.compile(r"^# +(.+)$", re.MULTILINE)
H2_RE = re.compile(r"^## +(.+)$", re.MULTILINE)
SYNOPSIS_CHARS = 200
TOC_MAX = 8


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------
@dataclass
class PlaybookDoc:
    rel_path: str           # path relative to the playbook repo root
    title: str
    description: str
    tags: List[str]
    synopsis: str
    toc: List[str]
    github_url: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def parse_frontmatter(text: str) -> Tuple[Dict[str, object], str]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    raw = m.group(1)
    body = text[m.end():]
    data: Dict[str, object] = {}
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
                data[key] = value.strip('"').strip("'")
    if current_key and in_list:
        data[current_key] = current_list
    return data, body


def git_metadata(repo: Path) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Return (owner, repo_name, branch) or (None, None, None) when unavailable."""
    if not (repo / ".git").exists():
        return None, None, None
    try:
        url = subprocess.check_output(  # nosec B603,B607 - hardcoded `git` binary, no shell, no user-controlled argv
            ["git", "-C", str(repo), "config", "--get", "remote.origin.url"],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None, None, None
    try:
        branch = subprocess.check_output(  # nosec B603,B607 - hardcoded `git` binary, no shell, no user-controlled argv
            ["git", "-C", str(repo), "rev-parse", "--abbrev-ref", "HEAD"],
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        branch = "main"
    m = re.search(r"github\.com[:/]+([^/]+)/([^/.]+)(?:\.git)?$", url)
    if not m:
        return None, None, branch
    return m.group(1), m.group(2), branch or "main"


def build_github_url(owner: Optional[str], repo: Optional[str],
                     branch: Optional[str], rel_path: str) -> str:
    if owner and repo and branch:
        return f"https://github.com/{owner}/{repo}/blob/{branch}/{rel_path}"
    return f"./{rel_path}"


def clean_body_for_synopsis(body: str) -> str:
    text = re.sub(r"^\s*import .+?;?$", "", body, flags=re.MULTILINE)
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"^#.*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def first_paragraph(body: str, limit: int = SYNOPSIS_CHARS) -> str:
    cleaned = clean_body_for_synopsis(body)
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[:limit].rstrip() + "…"


def extract_doc(rel_path: str, abs_path: Path,
                owner: Optional[str], repo: Optional[str],
                branch: Optional[str]) -> PlaybookDoc:
    text = abs_path.read_text(encoding="utf-8", errors="replace")
    fm, body = parse_frontmatter(text)
    title = str(fm.get("title") or "").strip()
    if not title:
        h1 = H1_RE.search(body)
        title = h1.group(1).strip() if h1 else abs_path.stem
    description = str(fm.get("description") or "").strip()
    tags_raw = fm.get("tags") or []
    if isinstance(tags_raw, str):
        tags = [t.strip() for t in tags_raw.split(",") if t.strip()]
    elif isinstance(tags_raw, list):
        tags = [str(t) for t in tags_raw]
    else:
        tags = []
    synopsis = description or first_paragraph(body)
    toc = [m.group(1).strip() for m in H2_RE.finditer(body)][:TOC_MAX]
    return PlaybookDoc(
        rel_path=rel_path,
        title=title,
        description=description,
        tags=tags,
        synopsis=synopsis,
        toc=toc,
        github_url=build_github_url(owner, repo, branch, rel_path),
    )


def discover_playbook_dir(explicit: Optional[Path], oma_repo: Path) -> Optional[Path]:
    candidates: List[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    env = os.environ.get("ENGINEERING_PLAYBOOK_DIR")
    if env:
        candidates.append(Path(env))
    candidates.append(Path.home() / "workspace" / "engineering-playbook")
    candidates.append(oma_repo.parent / "engineering-playbook")
    for c in candidates:
        if c.is_dir() and (c / "docs").is_dir():
            return c.resolve()
    return None


def collect_docs(playbook_dir: Path, subtrees: List[str],
                 owner: Optional[str], repo: Optional[str],
                 branch: Optional[str]) -> List[PlaybookDoc]:
    seen: Dict[str, PlaybookDoc] = {}
    for sub in subtrees:
        base = playbook_dir / sub
        if not base.is_dir():
            continue
        for md in sorted(base.rglob("*.md")):
            rel = md.relative_to(playbook_dir).as_posix()
            if rel in seen:
                continue
            try:
                seen[rel] = extract_doc(rel, md, owner, repo, branch)
            except Exception as exc:  # pragma: no cover - defensive
                print(f"warning: skipping {rel}: {exc}", file=sys.stderr)
    return list(seen.values())


def render_index(plugin: str, docs: List[PlaybookDoc], playbook_dir: Path) -> str:
    lines: List[str] = []
    lines.append("<!-- AUTO-GENERATED by scripts/sync-from-playbook.py. DO NOT EDIT BY HAND. -->")
    lines.append("<!-- Hand-authored reference docs live alongside this file and are preserved. -->")
    lines.append("")
    lines.append(f"# {plugin} — engineering-playbook index")
    lines.append("")
    lines.append(f"Source: `{playbook_dir}`")
    lines.append(f"Documents: {len(docs)}")
    lines.append("")
    if not docs:
        lines.append("_No matching documents found. The plugin has no playbook coverage yet._")
        return "\n".join(lines) + "\n"
    for doc in docs:
        lines.append(f"## [{doc.title}]({doc.github_url})")
        lines.append("")
        lines.append(f"Path: `{doc.rel_path}`")
        if doc.tags:
            lines.append(f"Tags: {', '.join(f'`{t}`' for t in doc.tags)}")
        lines.append("")
        if doc.synopsis:
            lines.append(doc.synopsis)
            lines.append("")
        if doc.toc:
            lines.append("Sections:")
            for item in doc.toc:
                lines.append(f"- {item}")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def write_index(index_path: Path, content: str, dry_run: bool) -> bool:
    if index_path.exists():
        existing = index_path.read_text(encoding="utf-8")
        if existing == content:
            return False
    if dry_run:
        return True
    index_path.parent.mkdir(parents=True, exist_ok=True)
    index_path.write_text(content, encoding="utf-8")
    return True


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="sync-from-playbook.py",
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
        "--playbook-dir",
        type=Path,
        default=None,
        help="Path to the engineering-playbook clone.",
    )
    parser.add_argument(
        "--plugin",
        help="Sync a single plugin instead of all configured plugins.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report planned changes without writing files.",
    )
    args = parser.parse_args(argv)

    oma_repo: Path = args.repo_dir.resolve()
    playbook_dir = discover_playbook_dir(args.playbook_dir, oma_repo)
    if playbook_dir is None:
        print("error: engineering-playbook directory not found. Pass --playbook-dir.",
              file=sys.stderr)
        return 1

    owner, repo, branch = git_metadata(playbook_dir)

    plugins_target = (
        [args.plugin] if args.plugin
        else [p for p in PLUGIN_COVERAGE if (oma_repo / "plugins" / p).is_dir()]
    )
    if not plugins_target:
        print("no OMA plugins found to sync.", file=sys.stderr)
        return 1

    changed: List[str] = []
    for plugin in plugins_target:
        subtrees = PLUGIN_COVERAGE.get(plugin)
        if not subtrees:
            print(f"skip {plugin}: no coverage map entry")
            continue
        docs = collect_docs(playbook_dir, subtrees, owner, repo, branch)
        index_path = oma_repo / "plugins" / plugin / "references" / "playbook-index.md"
        content = render_index(plugin, docs, playbook_dir)
        try:
            if write_index(index_path, content, args.dry_run):
                action = "would write" if args.dry_run else "updated"
                print(f"{action}: {index_path} ({len(docs)} docs)")
                changed.append(plugin)
            else:
                print(f"up-to-date: {index_path}")
        except OSError as exc:
            print(f"error writing {index_path}: {exc}", file=sys.stderr)
            return 2

    if args.dry_run and changed:
        print(f"\ndry-run: {len(changed)} plugin(s) need updates")
    return 0


if __name__ == "__main__":
    sys.exit(main())
