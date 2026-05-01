"""DSL schema tests: positive shape + representative rejections."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft7Validator, RefResolver

REPO_ROOT = Path(__file__).resolve().parents[2]
DSL_SCHEMA = REPO_ROOT / "schemas" / "harness" / "dsl.schema.json"
ONTOLOGY_DIR = REPO_ROOT / "schemas" / "ontology"


def _validator() -> Draft7Validator:
    schema = json.loads(DSL_SCHEMA.read_text(encoding="utf-8"))
    store = {}
    for other in ONTOLOGY_DIR.glob("*.schema.json"):
        content = json.loads(other.read_text(encoding="utf-8"))
        store[content["$id"]] = content
        store["../ontology/" + other.name] = content
    resolver = RefResolver.from_schema(schema, store=store)
    return Draft7Validator(schema, resolver=resolver)


MINIMAL_OK = {
    "version": 1,
    "plugin": "agentic-platform",
    "agents": [
        {
            "id": "platform-architect",
            "runtime": "claude-code",
            "mcp": ["eks"],
            "ontology": {"produces": ["Deployment"], "consumes": ["Spec"]},
        }
    ],
    "mcp": {
        "eks": {
            "command": "uvx",
            "args": ["awslabs.eks-mcp-server==0.1.28"],
        }
    },
    "hooks": {"session-start": {"runs": "hooks/session-start.sh"}},
    "triggers": [
        {
            "id": "platform-bootstrap",
            "keywords": ["platform-bootstrap"],
            "command": "/oma:platform-bootstrap",
        }
    ],
}

BAD_VERSION = {**MINIMAL_OK, "version": 99}
BAD_RUNTIME = {
    "version": 1,
    "plugin": "x",
    "agents": [{"id": "a", "runtime": "vscode"}],
}
BAD_PLUGIN_NAME = {"version": 1, "plugin": "Agentic_Platform"}

# v2 fixtures — workflow DAG, metadata, reserved telemetry/policies slots.
V2_OK = {
    "version": 2,
    "plugin": "agentic-platform",
    "metadata": {"labels": {"aidlc-phase": "construction"}},
    "agents": [
        {"id": "platform-architect", "runtime": "kiro", "mcp": ["eks"]},
        {"id": "vllm-deployer", "runtime": "kiro", "mcp": ["eks"]},
    ],
    "mcp": {
        "eks": {"command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"]}
    },
    "workflows": {
        "platform-bootstrap": {
            "steps": [
                {"id": "preflight", "agent_ref": "platform-architect"},
                {
                    "id": "provision",
                    "agent_ref": "vllm-deployer",
                    "depends_on": ["preflight"],
                    "on_failure": "rollback",
                },
            ]
        }
    },
    "telemetry": {},
    "policies": [],
}


def test_minimal_valid():
    errs = list(_validator().iter_errors(MINIMAL_OK))
    assert errs == [], [e.message for e in errs]


def test_v2_shape_valid():
    errs = list(_validator().iter_errors(V2_OK))
    assert errs == [], [e.message for e in errs]


@pytest.mark.parametrize("payload", [BAD_VERSION, BAD_RUNTIME, BAD_PLUGIN_NAME])
def test_invalid_shapes_rejected(payload):
    errs = list(_validator().iter_errors(payload))
    assert errs, "expected violations"


def test_v1_rejects_workflows_key():
    """Workflows section is reserved for v2; the v1 schema has additionalProperties: false."""
    payload = {**MINIMAL_OK, "workflows": {"p": {"steps": [{"id": "s"}]}}}
    errs = list(_validator().iter_errors(payload))
    assert errs, "v1 must reject the v2-only workflows key"
