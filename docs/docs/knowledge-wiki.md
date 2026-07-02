---
id: knowledge-wiki
title: Knowledge Wiki
sidebar_position: 6
---

# Knowledge Wiki — the retrieval layer that grounds the ontology

:::info Status — design accepted ([adr-0001](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/ontology/adr.schema.json)), build not yet shipped
The design below is **accepted** and recorded as an ADR entity
(`adr-0001-graphify-knowledge-wiki`): the wiki is built at `oma setup`, backed
by [Graphify](https://graphify.net/) (MIT) as the runtime query substrate via
its MCP surface. The corpus structure (`graph.json`) is committed under
`plugins/aidlc/skills/ontology-wiki/`; the Graphify-produced build has **not**
yet run in CI, and the ~71.5× token-reduction figure below is Graphify's own
benchmark, **not yet reproduced on OMA's corpus**. The
[Ontology](./ontology.md) (8 JSON Schemas) and [Harness](./harness-dsl.md)
(PreToolUse enforcement) layers **are** shipped. Treat the build steps as
roadmap and the numbers as unverified until a release note says otherwise.
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

## The approach: a semantic retrieval layer queried *before* generation

A knowledge wiki is a corpus of natural-language reference pages — entity
definitions, the narrative behind each `ADR`, worked examples, naming
conventions — indexed for **semantic search**. An agent queries it *before*
producing a typed artifact, so it generates grounded in what already exists
instead of re-deriving (and drifting from) it.

The three layers are complementary, not competing — each acts at a different
moment:

| Layer | What it holds | Form | When it acts | Status |
|---|---|---|---|---|
| **Knowledge wiki** | definitions, decision narratives, precedent, conventions | Graphify graph + markdown, queried at runtime | *before* generation (retrieval / grounding) | 🛠️ design accepted, build pending |
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

## How the wiki is built and queried

`adr-0001-graphify-knowledge-wiki` adopts [Graphify](https://graphify.net/)
(MIT — a Tree-sitter + LLM knowledge-graph builder) as the engine. The wiki is
built on the user's machine at `oma setup`, then queried at runtime:

```
oma setup
  1. assemble corpus  ──  schemas/ontology + ADR/Spec + docs/ + the user's
                          live .omao/ontology instances (Budget/Incident/Deployment)
  2. graphify build   ──  extract entities + relationships one-way (corpus → graph.json)
  3. runtime queries  ──  agents query Graphify (via its MCP server) before
                          authoring an entity, instead of re-reading raw schemas
```

The committed `graph.json`
(`plugins/aidlc/skills/ontology-wiki/graph.json`) is the structural backing —
8 entity nodes and their reference edges, each tagged `EXTRACTED` /
`INFERRED` / `AMBIGUOUS` with a confidence score so an agent knows what was
derived mechanically versus guessed from prose.

### The three open questions, resolved

The earlier proposal left three questions for an ADR. `adr-0001` answers each:

| Question | Resolution in `adr-0001` |
|---|---|
| **Source of truth** — must derive one-way from schemas/ADR, never the reverse | Graphify extraction is strictly one-way (corpus → graph; never written back), so the schemas stay authoritative by construction. |
| **Staleness** — a lagging index is worse than none | Re-index incrementally (`graphify --update` / `--watch`, or a git post-commit hook) on any ontology/docs change. |
| **Retrieval surface** — MCP vs skill vs build-time index | Graphify's `--mcp` stdio server, registered through OMA's existing `.mcp.json`. The intrusive `graphify claude install` (which ships its own PreToolUse hook) is **not** used, so OMA's harness stays the sole owner of PreToolUse and instead *wraps* the agent's wiki queries. |

### Honest limits

- **Runtime dependency.** This trades the marketplace's zero-runtime-dependency
  ideal for `pip install graphifyy` + a model API for the semantic pass + a
  running MCP process. The plugin ships the *wiring* (an `.mcp.json` entry,
  steering, the setup step), not a pre-built corpus.
- **Graceful degradation is mandatory.** When Graphify is absent or its MCP
  server is down, agents fall back to reading the raw schemas/docs directly.
  The wiki is an accelerator, never a hard precondition for correctness.
- **Numbers are unverified.** Graphify's ~71.5× token-reduction benchmark holds
  in a *build-once-query-many over a large corpus* regime — which the docs-wide
  + live-instance corpus fits — but it has not been measured on OMA's corpus and
  must not be claimed as fact until it is.

## References

- [Ontology Engineering](./ontology-engineering.md) — the correctness axis this layer serves
- [Ontology](./ontology.md) — the 8-entity schema reference and evolution rules
- [Harness Engineering](./harness-engineering.md) — the safety axis, for contrast on *when* each layer acts
- [Graphify](https://graphify.net/) — the MIT knowledge-graph builder adopted as the wiki engine ([safishamsi/graphify](https://github.com/safishamsi/graphify))
- [engineering-playbook — Ontology Engineering](https://devfloor9.github.io/engineering-playbook/docs/aidlc/methodology/ontology-engineering) — the living-ontology source ([REFERENCES](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/REFERENCES.md#ep-ontology-engineering))
