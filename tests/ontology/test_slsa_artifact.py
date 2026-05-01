"""Deployment.artifact now accepts both legacy string and SLSA-shaped object."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from jsonschema import Draft7Validator, RefResolver

SCHEMA_DIR = Path(__file__).resolve().parents[2] / "schemas" / "ontology"


def _validator() -> Draft7Validator:
    schema = json.loads((SCHEMA_DIR / "deployment.schema.json").read_text(encoding="utf-8"))
    store = {}
    for other in SCHEMA_DIR.glob("*.schema.json"):
        content = json.loads(other.read_text(encoding="utf-8"))
        store[content["$id"]] = content
        store[other.name] = content
    return Draft7Validator(schema, resolver=RefResolver.from_schema(schema, store=store))


LEGACY_OK = {
    "id": "vllm-llama3-70b",
    "target": "eks",
    "artifact": "public.ecr.aws/example/vllm:0.18.2",
    "approval_state": "proposed",
}

SLSA_OK = {
    "id": "vllm-llama3-70b",
    "target": "eks",
    "artifact": {
        "uri": "public.ecr.aws/example/vllm",
        "digest": "sha256:" + "a" * 64,
        "provenance_uri": "https://example.com/attestations/vllm.intoto.jsonl",
        "signing": {
            "cosign_bundle_uri": "https://example.com/attestations/vllm.sig",
            "issuer": "https://token.actions.githubusercontent.com"
        },
        "builder": "github-actions"
    },
    "approval_state": "approved"
}


@pytest.mark.parametrize("payload", [LEGACY_OK, SLSA_OK], ids=["legacy-string", "slsa-object"])
def test_positive(payload):
    errs = list(_validator().iter_errors(payload))
    assert errs == [], [e.message for e in errs]


@pytest.mark.parametrize(
    "artifact",
    [
        {"uri": "x", "digest": "sha256:too-short"},
        {"uri": "", "digest": "sha256:" + "a" * 64},
        {"uri": "x"},  # missing digest
        {"digest": "sha256:" + "a" * 64},  # missing uri
        {"uri": "x", "digest": "md5:" + "a" * 32},  # wrong algo
    ],
    ids=["bad-digest-len", "empty-uri", "no-digest", "no-uri", "wrong-algo"],
)
def test_negative(artifact):
    payload = {**LEGACY_OK, "artifact": artifact}
    errs = list(_validator().iter_errors(payload))
    assert errs, "expected schema violation"
