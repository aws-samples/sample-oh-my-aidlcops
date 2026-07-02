# ADR

> **God node.** Architecture Decision Record — the *why* behind the domain
> model. Read before authoring an `ADR` or any `Deployment` that cites one.
> Source: `schemas/ontology/adr.schema.json`.

## What it is

An `ADR` records a decision: the forces in play (`context`), the choice made
(`decision`), and its fallout (`consequences`). It follows Michael Nygard's 2011
template with a 5-state status machine; the id format follows MADR. In OMA an
ADR is an **ontology entity the agent produces** — not a human-reviewed approval
gate. `adr-0001-graphify-knowledge-wiki` is the first instance, recording the
decision to build this very wiki.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^adr-[0-9]{4}-[a-z0-9-]+$` | zero-padded; matches filename under `.omao/plans/adr/` |
| `status` | ✅ | `proposed · accepted · rejected · deprecated · superseded` | 5-state machine |
| `title` | ✅ | string ≤ 200 | |
| `context` | ✅ | string ≤ 5000 | forces in play at decision time |
| `decision` | ✅ | string ≤ 5000 | stated in the active voice |
| `consequences` | | string ≤ 5000 | positive, negative, and neutral |
| `supersedes` / `superseded_by` | | `^adr-[0-9]{4}-[a-z0-9-]+$` | decision-lineage links |
| `decided_at` | | date-time | |
| `decided_by` | | string | |
| `related_specs` | | array of `^spec-[a-z0-9-]+$` | back-link to motivating Specs |

## References (from graph.json)

- `ADR → ADR` via `supersedes` / `superseded_by` — decision lineage (EXTRACTED, 1.0)
- `ADR → Spec` via `related_specs` — **related_to** (EXTRACTED, 1.0)
- inverse: `Spec → ADR` (motivated_by), `Deployment → ADR` (constrained_by)

## Why it is shaped this way

- **`context` / `decision` / `consequences` are separate fields**, not one blob,
  so the *why* (context) is retrievable independently of the *what* (decision) —
  this is the "decision narrative that structured links cannot hold" the wiki is
  meant to preserve.
- **The status machine is explicit** so a `superseded` decision stays in the
  graph (with a `superseded_by` link) instead of being deleted — precedent is
  never lost.

## Gotchas for an authoring agent

- Every field caps at 5000 chars; a long rationale must be summarized, not dumped.
- Before proposing a new ADR, query for an existing one on the same subject —
  supersede it explicitly rather than creating a silent duplicate.
