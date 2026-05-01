"""Spec and ADR schema validation tests.

Spec and ADR are Draft 2020-12 entities (new in v0.3a), so this test module
uses Draft202012Validator explicitly. The legacy 6 entities remain on
Draft-07 and are covered by test_schemas.py.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

SCHEMA_DIR = Path(__file__).resolve().parents[2] / "schemas" / "ontology"
COMMON_DIR = Path(__file__).resolve().parents[2] / "schemas" / "common"


def _load(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _validator(schema_name: str) -> Draft202012Validator:
    return Draft202012Validator(_load(SCHEMA_DIR / schema_name))


SPEC_OK = {
    "id": "spec-gpu-capacity-plan",
    "owner": "platform-team",
    "status": "approved",
    "title": "GPU Capacity Plan for vLLM",
    "description": "Captures the GPU node pool sizing and Spot ratio targets.",
    "requirements": [
        {"id": "REQ-GPU-001", "text": "Reserve 20% on-demand capacity.", "priority": "must"},
        {"id": "REQ-GPU-002", "text": "Support bursting to Spot.", "priority": "should"},
    ],
    "linked_adrs": ["adr-0001-vllm-choice"],
    "created_at": "2026-04-12T09:00:00Z",
    "approved_at": "2026-04-18T14:00:00Z",
}
SPEC_BAD = {
    "id": "bad id",
    "owner": "",
    "status": "queued",
    "requirements": [{"id": "req-001", "text": "", "priority": "nice-to-have"}],
}

ADR_OK = {
    "id": "adr-0001-vllm-choice",
    "status": "accepted",
    "title": "Choose vLLM for model serving",
    "context": "We need PagedAttention v2 and Multi-LoRA support on EKS.",
    "decision": "Adopt vLLM v0.18.2 as the primary serving engine.",
    "consequences": "Locks us to CUDA 12.x; mitigated by Karpenter pool pinning.",
    "decided_at": "2026-04-15T10:00:00Z",
    "decided_by": "platform-architect",
    "related_specs": ["spec-gpu-capacity-plan"],
}
ADR_BAD = {
    "id": "adr-1-vllm",
    "status": "open",
    "title": "",
    "context": "",
    "decision": "",
}


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        ("spec.schema.json", SPEC_OK),
        ("adr.schema.json", ADR_OK),
    ],
)
def test_positive(schema_name, payload):
    errs = list(_validator(schema_name).iter_errors(payload))
    assert errs == [], [e.message for e in errs]


@pytest.mark.parametrize(
    "schema_name, payload",
    [
        ("spec.schema.json", SPEC_BAD),
        ("adr.schema.json", ADR_BAD),
    ],
)
def test_negative(schema_name, payload):
    errs = list(_validator(schema_name).iter_errors(payload))
    assert errs, "expected schema violations but payload validated"


def test_approval_chain_defs_resolve():
    """The approval-chain $defs must load as valid Draft 2020-12."""
    content = _load(COMMON_DIR / "approval-chain.schema.json")
    assert "$defs" in content
    assert "approvalChain" in content["$defs"]
    assert "approvalLink" in content["$defs"]
    # Verify the embedded $defs validate themselves as schemas.
    Draft202012Validator.check_schema(content["$defs"]["approvalLink"])
    Draft202012Validator.check_schema(content["$defs"]["approvalChain"])
