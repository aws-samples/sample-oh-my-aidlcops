# OMA Ontology

OMA (`oh-my-aidlcops`) separates **what the system talks about** from **how the
harness runs it**. This directory is the "what" — the shared vocabulary every
plugin, skill, and agent agrees on.

The goal is not a runtime type system. Schemas here are **documentation that
happens to be machine-checkable**. JSON Schema validation runs in CI so drift
between plugins surfaces as a failing test instead of a subtle behavioural
difference.

## Six core entities

```
                   +-----------+
                   |   Skill   |   triggered by a keyword or slash command
                   +-----+-----+
                         |
                         v
  +-----------+     +-----------+     +--------------+
  |   Agent   |---->| produces  |---->|  Deployment  |
  +-----------+     +-----------+     +------+-------+
        ^                                    |
        |                                    v
   constrained                          observed by
   by Budget                                 |
        |                                    v
  +-----------+                        +-----------+
  |  Budget   |                        | Incident  |
  +-----------+                        +-----------+
                                             ^
                                             |
                                        emitted from
                                             |
                                       +-----------+
                                       |    Risk   |   gates Construction->Ops
                                       +-----------+
```

Each box is a JSON Schema in `../schemas/ontology/`.

| Entity      | Schema file                         | Who produces it                | Who consumes it                       |
|-------------|-------------------------------------|--------------------------------|---------------------------------------|
| Agent       | `agent.schema.json`                 | plugin author                  | Claude Code, Kiro, oma-compile        |
| Skill       | `skill.schema.json`                 | plugin author                  | Claude Code skill loader              |
| Deployment  | `deployment.schema.json`            | `aidlc-construction`           | `agenticops.autopilot-deploy`         |
| Incident    | `incident.schema.json`              | `agenticops.incident-response` | human approver; auto-rollback path    |
| Budget      | `budget.schema.json`                | plugin author / finops team    | `agenticops.cost-governance`          |
| Risk        | `risk.schema.json`                  | `modernization.risk-discovery` | stage-gate-strict mode                |

## Relationships

- **Agent produces Deployment.** `aidlc-construction.construction-loop` emits a
  `Deployment` artifact at the Construction->Operations handoff. Every downstream
  AgenticOps skill reads this artifact rather than re-deriving target/artifact
  fields from prose.

- **Incident references Deployment.** When `agenticops.incident-response`
  creates an `Incident`, it fills `deployment_ref` with the impacted
  `Deployment.id`. This lets the remediation path reuse `Deployment.rollback_plan`
  without re-asking the user.

- **Budget constrains Agent.** `Budget.scope: "agent"` + `scope_ref: "<agent-id>"`
  gives `agenticops.cost-governance` a typed target. The `rule_expression` is
  evaluated by the simpleeval-backed `eval_condition()` in
  `plugins/agenticops/skills/cost-governance/SKILL.md` — **never** by Python's
  built-in `eval()`.

- **Risk gates stage transitions.** Under
  `steering/workflows/stage-gated-progression.md` (stage-gate-strict), any
  `Risk` with `accepted=false` and a non-empty `gate_ref` blocks the
  Construction->Operations transition.

## Why shared vocabulary matters here

Before this layer existed, two examples of accidental divergence:

1. `autopilot-deploy.skill` used "deployment target" meaning the EKS cluster
   name. `construction-loop.skill` used "deployment target" meaning
   `eks | ec2 | lambda`. The handoff worked only because a human re-interpreted.
2. `cost-governance.skill` had no shared notion of "scope". Each rule embedded
   a bespoke selector string, so merging two plugins' budgets in the same
   account required reading both skills in full.

Both are now resolved by `Deployment.target` (enum) and `Budget.scope` (enum).

## How to evolve the ontology

1. Add fields to an existing schema before inventing a new entity. Schema bumps
   are free; entity additions are architectural.
2. New enum values require a README row explaining when to use them.
3. Breaking changes (required-field additions, enum narrowing) require a DSL
   `version:` bump in `schemas/harness/dsl.schema.json`.
4. Never reference the ontology from inside plugin code except through the
   DSL surface or SKILL.md frontmatter. If a skill needs runtime-typed data,
   validate the JSON at the boundary using the schema.

## See also

- `./glossary.md` — one paragraph per term
- `../schemas/ontology/` — schema files
- `../schemas/harness/dsl.schema.json` — how the DSL references these entities
