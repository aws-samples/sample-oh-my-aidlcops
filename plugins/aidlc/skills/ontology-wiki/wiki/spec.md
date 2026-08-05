# Spec

> **God node.** The source of WHAT/WHEN — requirements intent produced in
> Inception. Read before authoring a `Spec` or any `Deployment` that satisfies
> one. Source: `schemas/ontology/spec.schema.json`.

## What it is

A `Spec` captures requirements intent: an owner, a lifecycle status, and an
ordered list of atomic, traceable requirements. It opens the
Inception→Construction traceability chain that a `Deployment` later closes via
`spec_ref`.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^spec-[a-z0-9-]+$` | matches filename under `.omao/plans/spec/` |
| `owner` | ✅ | string | team handle or individual accountable for the lifecycle |
| `status` | ✅ | `draft · reviewing · approved · superseded` | |
| `title` | | string | |
| `description` | | string | |
| `requirements` | | array | ordered atomic requirements, each traceable to downstream ADRs |
| `supersedes` | | array of `^spec-[a-z0-9-]+$` | prior spec ids this replaces |
| `linked_adrs` | | array of `^adr-[0-9]{4}-[a-z0-9-]+$` | ADRs that motivated or flow from this spec |
| `created_at` / `approved_at` | | date-time | |

## References (from graph.json)

- `Spec → ADR` via `linked_adrs` — **motivated_by** (EXTRACTED, 1.0)
- `Spec → Spec` via `supersedes` — decision lineage (EXTRACTED, 1.0)
- inverse: `ADR → Spec` (related_to), `Deployment → Spec` (satisfies)

## Why it is shaped this way

- **`requirements` are atomic and ordered** so each one is individually
  traceable to an ADR and then a Deployment — traceability is per-requirement,
  not per-document.
- **`status` and `supersedes`** keep superseded intent in the graph rather than
  deleting it, mirroring the ADR lineage pattern.

## Gotchas for an authoring agent

- A `Spec` and an `ADR` are complementary, not interchangeable: the Spec holds
  *what/when* (requirements), the ADR holds *why* (decisions). Do not encode a
  decision rationale in a Spec description.
