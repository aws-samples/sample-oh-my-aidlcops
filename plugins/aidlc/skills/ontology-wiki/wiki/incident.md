# Incident

> Operations fact feeding the Outer Loop. Source:
> `schemas/ontology/incident.schema.json`.

## What it is

An `Incident` records something that went wrong in Operations: its severity, what
raised it, the fix the agent proposes, and a human-in-the-loop approval state.
It is one of the three entities (`Incident`, `Budget`, `Risk`) that feed the
self-improving Outer Loop.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z0-9][a-z0-9-]*$` | |
| `severity` | ✅ | `sev-1 · sev-2 · sev-3 · sev-4 · sev-5` | sev-1 = customer-facing outage; sev-5 = informational |
| `alarm_source` | ✅ | string | CloudWatch alarm, Prometheus rule, Langfuse signal, … |
| `approval_state` | ✅ | `draft · proposed · approved · rejected · mitigated · closed` | |
| `deployment_ref` | | string | the affected `Deployment.id`, if known |
| `blast_radius` | | `single-namespace · single-cluster · single-account · cross-account · cross-region` | |
| `proposed_fix` | | string | must be human-reviewed before applying |
| `runbook_ref` | | string | runbook the agent consulted |
| `evidence` | | array | log excerpts, metric snapshots, trace ids |
| `approval_chain` | | array | approvals for runbook overrides |
| `trace_id` | | `^[a-f0-9]{32}$` | OpenTelemetry trace id linking to distributed traces |
| `span_id` | | `^[a-f0-9]{16}$` | OpenTelemetry span id |

## References (from graph.json)

- `Incident → Deployment` via `deployment_ref` — **affects** (INFERRED, 0.8);
  reuses the deployment's `rollback_plan` and `blast_radius`

## Why it is shaped this way

- **`deployment_ref` links back to the Deployment** so recovery reuses the
  already-authored `rollback_plan` instead of re-deriving it mid-outage.
- **`trace_id` / `span_id` are patterned** (OTel hex) so an incident ties
  precisely to distributed traces — a load-bearing link for the self-improving
  loop's trace analysis.

## Gotchas for an authoring agent

- `proposed_fix` never auto-applies — `approval_state` gates it.
- Fill `deployment_ref` when known; without it, `incident-response` cannot reuse
  the deployment's rollback plan.
