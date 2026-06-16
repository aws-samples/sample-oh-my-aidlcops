---
id: knowledge-wiki
title: Knowledge Wiki
sidebar_position: 6
---

# Knowledge Wiki — the retrieval layer that grounds the ontology

:::info Status — design proposal, not yet shipped
OMA does **not** ship a knowledge-wiki component today. This page describes a
proposed layer and the reasoning behind it, so the design is reviewable before
any code lands. The [Ontology](./ontology.md) (8 JSON Schemas) and
[Harness](./harness-dsl.md) (PreToolUse enforcement) layers described elsewhere
**are** implemented. Treat everything below as roadmap unless a later release
note says otherwise.
:::

## The gap: the ontology validates *after* generation

The [Ontology Engineering](./ontology-engineering.md) axis guarantees
correctness with a **post-hoc** mechanism:

```
agent writes entity YAML  ──▶  oma validate  ──▶  schema violation → rejected
```

This catches a malformed `Deployment` or an undeclared `Risk` classification.
What it cannot do is tell an agent, *before* it writes anything, what the domain
already knows:

- Is `Deployment.target` already an enum (`eks | ec2 | lambda`), or am I free to
  invent a cluster-name string?
- Has a `Risk` like this one been classified under OWASP or NIST before, and how?
- Why was the `Payment` aggregate split into `CustomerReference` +
  `CustomerProfile` — was that an `ADR`, and what triggered it?

The ontology's origin story on the [Ontology](./ontology.md) page is exactly
this failure: `autopilot-deploy` and `construction-loop` both said "deployment
target" and meant different things. Validation only caught the clash *after* the
conflicting documents existed. The handoff still cost a human re-read.

## The proposal: a semantic retrieval layer queried *before* generation

A knowledge wiki is a corpus of natural-language reference pages — entity
definitions, the narrative behind each `ADR`, worked examples, naming
conventions — indexed for **semantic search**. An agent queries it *before*
producing a typed artifact, so it generates grounded in what already exists
instead of re-deriving (and drifting from) it.

The three layers are complementary, not competing — each acts at a different
moment:

| Layer | What it holds | Form | When it acts | Status |
|---|---|---|---|---|
| **Knowledge wiki** | definitions, decision narratives, precedent, conventions | unstructured, semantically searchable | *before* generation (retrieval / grounding) | 🔭 proposed |
| **Ontology** (8 schemas) | the typed world model — entities, fields, invariants | structured, machine-validated | *after* generation (validation) | ✅ shipped |
| **Harness** (PreToolUse) | execution deny rules | compiled regex rules | *before* a tool runs (enforcement) | ✅ shipped |

The ontology answers **"is this true?"** The wiki answers **"what is already
known?"** A type system rejects a wrong answer; it does not supply the right
one. The wiki supplies the context that makes the first answer correct.

## How the wiki makes the ontology *more accurate*

Three concrete paths, each tied to a failure the ontology page already names:

1. **Pre-generation grounding (prevents drift instead of catching it).**
   The agent retrieves existing definitions, enums, and synonyms before writing.
   A duplicate or renamed concept is avoided at the source, rather than surfaced
   as a validation clash after two skills have already diverged. This attacks the
   "deployment target" failure at generation time, not handoff time.

2. **Decision narratives that structured links cannot hold.**
   The 8 schemas connect by `id` reference (`Deployment.adr_refs: ["ADR-014"]`) —
   structural, but silent on *why*. The wiki preserves the prose behind a
   decision (the `Payment` → `CustomerReference` + `CustomerProfile` redesign and
   the P99 signal that triggered it) so the
   [Outer Loop](./ontology-engineering.md#agenticops-as-the-outer-loop) can reuse
   past reasoning instead of re-litigating it.

3. **A second input to schema evolution.**
   Today the Outer Loop's `self-improving-loop` consumes operational signal
   (traces, metrics, incidents). A wiki adds *accumulated domain knowledge* as a
   second input, so a proposed schema change is grounded in both what operations
   observed and what the domain has already established.

## How this connects to evolving the ontology

[Ontology](./ontology.md#evolving-the-ontology) already defines the evolution
rules: add fields before inventing entities; new enum values need a documented
rationale; breaking changes bump the DSL `version:`. Those rules say *what is
allowed*. A wiki would feed *what is informed* into each step of the
[triple feedback loop](./ontology-engineering.md#the-triple-feedback-loop--a-living-ontology):

| Loop | Cadence | Without a wiki | With a wiki (proposed) |
|---|---|---|---|
| **Inner** | minutes | add a constraint from a single test failure | check whether the constraint already exists or contradicts a documented convention before adding it |
| **Middle** | days | bump a schema from a repeated PR pattern | retrieve prior decisions on the same entity so the schema change is consistent with established intent |
| **Outer** | weeks | redesign the domain model from operational signal alone | combine operational signal with the recorded narrative of *why the model is shaped as it is* |

In each case the wiki does not change *what the ontology enforces* — the schemas
remain the single source of truth, validated by `oma validate`. It changes how
*accurately* the next ontology edit is proposed, by making prior knowledge
retrievable at the moment of authorship.

## Open design questions

These must be resolved in an [ADR](./ontology.md) before implementation:

- **Source of truth.** The wiki must derive from the schemas + `ADR`/`Spec`
  documents, never the reverse, or it becomes a competing definition of the
  domain and reintroduces the drift it is meant to prevent.
- **Staleness.** A retrieval layer that lags the schemas is worse than none.
  Ingestion would need to re-run on every ontology change (an Inner-Loop hook).
- **Retrieval surface.** Whether agents query the wiki via an MCP tool, a skill,
  or a build-time index is an interface decision with different harness
  implications for each.

## References

- [Ontology Engineering](./ontology-engineering.md) — the correctness axis this layer serves
- [Ontology](./ontology.md) — the 8-entity schema reference and evolution rules
- [Harness Engineering](./harness-engineering.md) — the safety axis, for contrast on *when* each layer acts
- [engineering-playbook — Ontology Engineering](https://devfloor9.github.io/engineering-playbook/docs/aidlc/methodology/ontology-engineering) — the living-ontology source ([REFERENCES](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/REFERENCES.md#ep-ontology-engineering))
