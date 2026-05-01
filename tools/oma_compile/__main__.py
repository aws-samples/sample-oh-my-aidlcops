"""CLI entry for oma-compile.

Usage:
  python -m tools.oma_compile plugins/<name>/<name>.oma.yaml [more.yaml ...]
  python -m tools.oma_compile --check
  python -m tools.oma_compile --all

--all  : discover plugins/*/<plugin>.oma.yaml
--check: compile in-memory and fail if committed native files drift.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .compile import (
    REPO_ROOT,
    CompileError,
    check_drift,
    compile_workspace,
    enforce_strict_enterprise,
)


def _discover() -> list[Path]:
    return sorted((REPO_ROOT / "plugins").glob("*/*.oma.yaml"))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="oma-compile", description=__doc__)
    parser.add_argument("files", nargs="*", type=Path, help="*.oma.yaml paths")
    parser.add_argument("--all", action="store_true", help="discover every plugin")
    parser.add_argument("--check", action="store_true", help="fail on drift")
    parser.add_argument(
        "--strict-enterprise",
        action="store_true",
        help="enforce enterprise-readiness gates (DSL v2 only, SLSA digest, "
             "Risk OWASP/NIST classification, approval_chain on approved deployments)",
    )
    args = parser.parse_args(argv)

    if args.all or args.check or args.strict_enterprise:
        files = _discover()
    else:
        files = [f.resolve() for f in args.files]

    if not files:
        print("no *.oma.yaml files found", file=sys.stderr)
        return 0

    try:
        if args.check:
            drift = check_drift(files)
            if drift:
                print("drift detected:", file=sys.stderr)
                for line in drift:
                    print(f"  {line}", file=sys.stderr)
                return 1
            print(f"clean ({len(files)} plugin(s))")
            return 0
        results = compile_workspace(files, write=True)
        if args.strict_enterprise:
            strict_errors = enforce_strict_enterprise(files)
            if strict_errors:
                print("strict-enterprise gate failed:", file=sys.stderr)
                for line in strict_errors:
                    print(f"  {line}", file=sys.stderr)
                return 1
    except CompileError as err:
        print(f"oma-compile error: {err}", file=sys.stderr)
        return 2

    for result in results:
        print(f"compiled {result.plugin}: {result.mcp_json_path.relative_to(REPO_ROOT)}")
        for path in result.agent_json_paths:
            print(f"  + {path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
