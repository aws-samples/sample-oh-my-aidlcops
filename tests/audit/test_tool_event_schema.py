"""Tool-event audit schema tests (Draft 2020-12).

The tool-event schema is self-contained (no $ref), so validation needs no
registry — this mirrors the runtime contract where the PostToolUse hook emits
conforming lines with only jq/python3.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator, FormatChecker

REPO_ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads(
    (REPO_ROOT / "schemas" / "audit" / "tool-event.schema.json").read_text(
        encoding="utf-8"
    )
)


def _validator() -> Draft202012Validator:
    return Draft202012Validator(SCHEMA, format_checker=FormatChecker())


MUTATING_BASH_OK = {
    "ts": "2026-07-19T12:00:00Z",
    "tool": "Bash",
    "classification": "mutating",
    "matched_rule": "kubectl-mutating",
    "command_excerpt": "kubectl apply -f manifest.yaml",
    "session_id": "sess-123",
    "cwd": "/home/user/project",
    "feedback_emitted": True,
}

BENIGN_READ_OK = {
    "ts": "2026-07-19T12:01:00Z",
    "tool": "Read",
    "classification": "benign",
    "file_path": "/home/user/project/README.md",
    "feedback_emitted": False,
}

MUTATING_WRITE_OK = {
    "ts": "2026-07-19T12:02:00Z",
    "tool": "Write",
    "classification": "mutating",
    "matched_rule": "file-write",
    "file_path": "/home/user/project/main.py",
    "feedback_emitted": True,
}


@pytest.mark.parametrize(
    "payload",
    [MUTATING_BASH_OK, BENIGN_READ_OK, MUTATING_WRITE_OK],
    ids=["mutating-bash", "benign-read", "mutating-write"],
)
def test_positive(payload):
    errs = list(_validator().iter_errors(payload))
    assert errs == [], [e.message for e in errs]


@pytest.mark.parametrize(
    "payload, expected",
    [
        # Missing required ts
        ({"tool": "Bash", "classification": "benign"}, "ts"),
        # Missing required classification
        ({"ts": "2026-07-19T12:00:00Z", "tool": "Bash"}, "classification"),
        # Bad timestamp
        ({"ts": "yesterday", "tool": "Bash", "classification": "benign"}, "pattern"),
        # Unknown classification
        ({"ts": "2026-07-19T12:00:00Z", "tool": "Bash",
          "classification": "destructive"}, "destructive"),
        # Unknown top-level property (additionalProperties: false)
        ({"ts": "2026-07-19T12:00:00Z", "tool": "Bash",
          "classification": "benign", "rogue": "x"}, "rogue"),
    ],
    ids=["missing-ts", "missing-class", "bad-ts", "unknown-class", "extra-prop"],
)
def test_negative(payload, expected):
    errs = list(_validator().iter_errors(payload))
    assert errs, f"expected schema violations for {expected}"
