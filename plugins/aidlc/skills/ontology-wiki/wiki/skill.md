# Skill

> Actor capability bound to a harness. Source:
> `schemas/ontology/skill.schema.json`.

## What it is

A `Skill` is a capability that a harness loads, routed to by keyword triggers.
Unlike an `Agent`, a Skill is required to declare a `harness` — the safety axis
is part of its identity.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z][a-z0-9-]*$` | kebab-case |
| `harness` | ✅ | `claude · kiro · both` | which harness(es) load this skill |
| `triggers` | | array | keyword triggers routed via `.omao/triggers.json` |
| `steering` | | string | optional Kiro steering fragment path |
| `ontology` | | object | `produces` / `consumes` entity refs |
| `description` | | string | |
| `sla_tier` | | `critical · standard · best-effort` | `critical` = must not regress |

## References (from graph.json)

- inverse: `Deployment → Skill` via `produced_by` — **produced_by** (⚠️ AMBIGUOUS, 0.5)
- inverse: `Risk → Skill` via `gate_ref` — **blocks_gate** (⚠️ AMBIGUOUS, 0.5)

## Why it is shaped this way

- **`harness` is required** — a skill cannot exist without declaring where it is
  enforced, which keeps the safety axis attached to every capability.
- **`sla_tier`** lets the self-improving loop know which skills must not regress
  when it proposes changes.

## Gotchas for an authoring agent

- Two AMBIGUOUS edges point at Skill (`produced_by`, `gate_ref`). If you author
  a `Deployment` or `Risk` referencing a skill, spell out the target so the
  reference does not degrade to a guess.
