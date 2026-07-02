# Ontology Knowledge Graph — Report

> **Generated artifact.** This report mirrors Graphify's `GRAPH_REPORT.md`
> output shape (god nodes, surprising edges, suggested questions). It is a
> build-time snapshot of `graph.json`. Regenerate via the corpus build step
> (see `adr-0001-graphify-knowledge-wiki`); do not hand-edit — edit the
> schemas, then rebuild.

## Corpus

| Source | Role |
|---|---|
| `schemas/ontology/*.schema.json` | the 8 typed entities (nodes + reference edges) |
| `.omao/plans/adr/*` · `.omao/plans/spec/*` | decision + intent narratives |
| `docs/docs/*.md` | conceptual definitions and worked examples |
| `.omao/ontology/*` (user machine) | the **live** Budget / Incident / Deployment instances |

At `oma setup` the live-instance rows are what make this a *living* ontology
map rather than a static schema dump.

## Nodes — 8 entities

| Entity | Phase | God node | Role in the correctness chain |
|---|---|:---:|---|
| `Spec` | inception | ⭐ | Source of WHAT/WHEN — requirements intent |
| `ADR` | inception · construction | ⭐ | Architecture decisions; constrains `Deployment` |
| `Deployment` | construction · operations | ⭐ | The validated Construction→Operations handoff |
| `Agent` | all | | Actor with a declared produce/consume contract |
| `Skill` | all | | Actor capability bound to a harness |
| `Incident` | operations | | Operations fact feeding the Outer Loop |
| `Budget` | operations | | Cost-governance fact feeding the Outer Loop |
| `Risk` | operations | | OWASP/NIST-classified; gates Deployments |

**God nodes** (highest-degree — everything routes through them): `Spec`, `ADR`,
`Deployment`. These three close the Inception→Construction→Operations
traceability spine, so an agent grounding a new entity should almost always
read the god-node pages first.

## Edges — 13 references, by provenance

Each edge is tagged with how it was derived, so an agent knows what is a hard
schema guarantee versus a prose-level guess.

### EXTRACTED (6) — mechanical from a schema pattern, confidence ≥ 0.9

| From | → | To | Relation | Field |
|---|---|---|---|---|
| `ADR` | → | `ADR` | supersedes | `supersedes` |
| `ADR` | → | `ADR` | superseded_by | `superseded_by` |
| `ADR` | → | `Spec` | related_to | `related_specs` |
| `Spec` | → | `ADR` | motivated_by | `linked_adrs` |
| `Spec` | → | `Spec` | supersedes | `supersedes` |
| `Risk` | → | `Deployment` | applies_to | `deployment_refs` |

### INFERRED (4) — free-string field whose description names the target

| From | → | To | Relation | Field |
|---|---|---|---|---|
| `Deployment` | → | `Spec` | satisfies | `spec_ref` |
| `Deployment` | → | `ADR` | constrained_by | `adr_refs` |
| `Deployment` | → | `Agent` | produced_by | `produced_by` |
| `Incident` | → | `Deployment` | affects | `deployment_ref` |

### AMBIGUOUS (3) — target entity named in prose only; verify before relying

| From | → | To | Relation | Field | Why ambiguous |
|---|---|---|---|---|---|
| `Deployment` | → | `Skill` | produced_by | `produced_by` | may name an Agent *or* a Skill |
| `Risk` | → | `Skill` | blocks_gate | `gate_ref` | quality-gate id, not bound to one entity type |
| `Budget` | → | `Agent` | scoped_to | `scope_ref` | may be an account id, Agent.id, Skill.id, or Deployment.id |

## Surprising connections

- **`Risk → Deployment` is bidirectional but asymmetric.** `Risk.deployment_refs`
  is EXTRACTED (patterned), while the inverse `Deployment.risk_exceptions` is a
  waiver list — a risk *applies to* a deployment, but a deployment can
  *explicitly waive* a risk's gate. An agent proposing a `Deployment` must check
  both directions or it can silently ship an unmitigated risk.
- **`produced_by` spans two entity types.** The same field points at either an
  `Agent` or a `Skill`, which is why it appears once as INFERRED and once as
  AMBIGUOUS. Grounding code that assumes "producer = Agent" will miss
  skill-produced deployments.
- **`Budget.scope_ref` is the weakest-typed edge in the graph** (confidence 0.4):
  four possible target types with no pattern. It is the first place drift will
  reappear if the wiki is not consulted before authoring a Budget.

## Suggested grounding questions

Before authoring an entity, an agent should query the wiki for:

- "What enum values does `Deployment.target` allow?" → `eks · ec2 · lambda · ecs · bedrock-agentcore · sagemaker` (never invent a cluster-name string — the original drift)
- "Which entities feed the Outer Loop?" → `Incident`, `Budget`, `Risk`
- "What must exist before `Deployment.approval_state = approved`?" → a non-empty `rollback_plan`, and (strict-enterprise) a non-empty `approval_chain`
- "Has this Risk been classified before?" → check `owasp_llm_top10_id` / `nist_ai_rmf_subcategory` on existing `Risk` instances

## Per-entity pages

See `wiki/<entity>.md` for the field-level definition, enums, references, and
the *why* behind each entity:
[adr](./wiki/adr.md) · [spec](./wiki/spec.md) · [deployment](./wiki/deployment.md) ·
[agent](./wiki/agent.md) · [skill](./wiki/skill.md) · [incident](./wiki/incident.md) ·
[budget](./wiki/budget.md) · [risk](./wiki/risk.md)
