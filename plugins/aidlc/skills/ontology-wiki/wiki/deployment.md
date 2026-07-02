# Deployment

> **God node.** The validated Construction→Operations handoff document. Read
> this before authoring any deployment, and before an `Incident` that references
> one. Source: `schemas/ontology/deployment.schema.json`.

## What it is

A `Deployment` is the single artifact that carries a change from Construction
into Operations. It is *the* answer to the canonical drift story: "deployment
target" once meant a cluster name in one skill and the enum `eks|ec2|lambda` in
another. `Deployment.target` is now a closed enum, so that ambiguity cannot recur.

`agenticops.autopilot-deploy` refuses to act on anything below
`approval_state: approved`. Once approved, the same document tells
`incident-response` how to roll back — no re-derivation from prose.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z][a-z0-9-]*$` | kebab-case identifier |
| `target` | ✅ | `eks · ec2 · lambda · ecs · bedrock-agentcore · sagemaker` | **closed enum — never invent a string** |
| `artifact` | ✅ | object (uri + digest) or legacy string | strict-enterprise requires the object form with `sha256:` digest |
| `approval_state` | ✅ | `draft · proposed · approved · rejected · deployed · rolled_back` | AgenticOps only progresses on `approved` |
| `manifests` | | array | IaC / Helm / k8s manifest paths |
| `rollback_plan` | | string | **required before `approval_state = approved`** |
| `blast_radius` | | `single-namespace · single-cluster · single-account · cross-account · cross-region` | consumed by `incident-response` |
| `produced_by` | | string | Agent **or** Skill id — see ambiguity note |
| `spec_ref` | | string | the `Spec` this satisfies (`.omao/plans/...`) |
| `adr_refs` | | array | `ADR` ids that constrain this deployment |
| `approval_chain` | | array | ordered approvals gating `approved` (see `schemas/common/approval-chain.schema.json`) |
| `risk_exceptions` | | array | `Risk.id` values whose `gate_ref` was explicitly waived |

## References (from graph.json)

- `Deployment → Spec` via `spec_ref` — **satisfies** (INFERRED, 0.8)
- `Deployment → ADR` via `adr_refs` — **constrained_by** (INFERRED, 0.8)
- `Deployment → Agent` via `produced_by` — **produced_by** (INFERRED, 0.7)
- `Deployment → Skill` via `produced_by` — **produced_by** (⚠️ AMBIGUOUS, 0.5)
- inverse: `Incident → Deployment` (affects), `Risk → Deployment` (applies_to)

## Why it is shaped this way

- **`target` is an enum, not free text** — this is the direct fix for the
  origin-story drift. Adding a new runtime means adding an enum value with a
  documented rationale (ontology evolution rule 2), not inventing a string.
- **`approval_state` is a human-in-the-loop gate**, not a status label. The
  harness and `autopilot-deploy` both key off `approved`; nothing auto-progresses.
- **`rollback_plan` is required before approval** so that `incident-response`
  never has to re-derive recovery steps from prose during an outage.

## Gotchas for an authoring agent

- Check **both** `Risk.deployment_refs` (risks that apply) **and**
  `risk_exceptions` (risks this deployment waives) — they are asymmetric and a
  silent gap ships an unmitigated risk.
- `produced_by` may name a `Skill`, not an `Agent`. Do not assume Agent.
- Under strict-enterprise, `artifact` must be the object form with a
  `sha256:<64 hex>` digest, and an `approved` deployment must carry a non-empty
  `approval_chain`.
