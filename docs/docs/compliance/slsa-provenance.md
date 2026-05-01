---
sidebar_position: 30
title: SLSA provenance
---

# SLSA v1.1 provenance on Deployment.artifact

:::tip External references
Every upstream spec and framework OMA cites — including SLSA v1.1
itself — is catalogued on the [References](/docs/references) page.
:::

`Deployment.artifact` accepts two shapes in v0.4+:

```yaml
# Legacy — still valid, no provenance metadata.
artifact: public.ecr.aws/example/vllm:0.18.2

# Enterprise — SLSA v1.1 provenance attached.
artifact:
  uri: public.ecr.aws/example/vllm
  digest: sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  provenance_uri: https://example.com/attestations/vllm.intoto.jsonl
  signing:
    cosign_bundle_uri: https://example.com/attestations/vllm.sig
    issuer: https://token.actions.githubusercontent.com
  builder: github-actions
```

> **Authoritative reference**: SLSA v1.1 specification,
> https://slsa.dev/spec/v1.1/

## Field meaning

| Field                       | Source                                                            | Consumer                          |
|-----------------------------|-------------------------------------------------------------------|-----------------------------------|
| `uri`                       | Canonical image/object URI (no tag, tag lives in consumer config) | `autopilot-deploy`, cosign verify |
| `digest`                    | SHA-256 hash emitted by the builder                               | image-pull policy, cosign verify  |
| `provenance_uri`            | SLSA v1.1 JSON document URI                                       | auditors, SBOM correlation        |
| `signing.cosign_bundle_uri` | cosign bundle or transparent log link                             | `oma validate` (v0.4+)            |
| `signing.issuer`            | OIDC issuer of the signing identity                               | policy-as-code allow-list         |
| `builder`                   | Free-form builder tag (github-actions, buildkite, …)              | attestation aggregator            |

## Why OMA keeps the legacy string form

During v0.3→v0.4 rollout, plugins that have not yet generated signed
provenance continue to emit plain string artifacts. The schema accepts
both so migrations are incremental. Under
`oma compile --strict-enterprise` (v0.5) the string form is rejected;
operators migrate at their own pace.

## Validation entry points

- **Compile-time**: `tools/oma_compile/compile.py` accepts both shapes,
  no separate flag.
- **Strict enterprise**: rejects string artefacts and object artefacts
  with missing `digest`.
- **Runtime (v0.4+)**: `oma validate <deployment.yaml>` checks the
  shape and, when OPA is installed, evaluates any Rego policies that
  reference `input.artifact.digest` / `input.artifact.signing.issuer`.
- **CI**: projects can call `cosign verify --certificate-identity …` on
  `artifact.uri@digest` using the `signing.issuer` field from the
  Deployment record.

## Non-repudiation layering

`Deployment.approval_chain[].approved_at` timestamps are
client-provided. True non-repudiation comes from:

1. `artifact.signing.cosign_bundle_uri` — cryptographic signature of the
   artefact itself.
2. `audit.jsonl` events written by `tools.oma_audit.append` — tied back
   to `Deployment.id` via `target.entity_id`.
3. External SIEM (out of scope here) that ingests
   `telemetry.logs.endpoint` + `audit.jsonl`.

Future work: bundle cosign signing into `tools.oma_audit.append` so
audit events themselves become signed artefacts.
