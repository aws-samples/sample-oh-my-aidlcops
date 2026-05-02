---
id: ontology
title: Ontology
sidebar_position: 7
---

# Ontology — shared vocabulary

OMA separates **what the system talks about** from **how the harness runs it**.
This page covers the "what": six JSON Schemas every plugin and skill agrees on.

:::info Why this exists
Before this layer, `autopilot-deploy.skill` and `construction-loop.skill` both
used the phrase "deployment target" to mean *different* things — one meant the
EKS cluster name, the other meant `eks | ec2 | lambda`. Handoffs worked only
because a human re-interpreted. The ontology closes that gap.
:::

## Six core entities

| Entity       | Schema file                                      | Produced by                         | Consumed by                                |
|--------------|--------------------------------------------------|-------------------------------------|--------------------------------------------|
| `Agent`      | `schemas/ontology/agent.schema.json`             | plugin author                       | Claude Code, Kiro, oma-compile             |
| `Skill`      | `schemas/ontology/skill.schema.json`             | plugin author                       | Claude Code skill loader                   |
| `Deployment` | `schemas/ontology/deployment.schema.json`        | `aidlc`                | `agenticops.autopilot-deploy`              |
| `Incident`   | `schemas/ontology/incident.schema.json`          | `agenticops.incident-response`      | human approver; auto-rollback              |
| `Budget`     | `schemas/ontology/budget.schema.json`            | plugin author / finops              | `agenticops.cost-governance`               |
| `Risk`       | `schemas/ontology/risk.schema.json`              | `modernization.risk-discovery`      | stage-gate-strict mode                     |

## Relationships at a glance

```
                   +-----------+
                   |   Skill   |   triggered by keyword or slash command
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
                                       +-----------+
                                       |    Risk   |   gates Construction->Ops
                                       +-----------+
```

## Example: `Deployment`

```json
{
  "id": "vllm-llama3-70b",
  "target": "eks",
  "artifact": "public.ecr.aws/example/vllm:0.18.2",
  "approval_state": "proposed",
  "blast_radius": "single-cluster",
  "rollback_plan": "helm rollback vllm 1",
  "spec_ref": ".omao/plans/spec-2026-04-30-vllm.md",
  "adr_refs": ["ADR-014"]
}
```

`agenticops.autopilot-deploy` refuses to act on anything below `approval_state: approved`.
Once approved, the same document tells `incident-response` how to roll back —
no re-derivation from prose.

## Example: `Budget`

```json
{
  "id": "autopilot-deploy-monthly",
  "scope": "agent",
  "scope_ref": "autopilot-deploy",
  "limit_usd": 250.0,
  "period": "monthly",
  "rule_expression": "spend_usd > limit_usd * 0.8",
  "action_on_breach": "notify"
}
```

`rule_expression` is evaluated by the simpleeval-backed `eval_condition()`
defined in `plugins/agenticops/skills/cost-governance/SKILL.md`. Python
`eval()` is forbidden — the sandbox exists because `rule_expression` is
user-editable input.

## Evolving the ontology

1. Add fields to an existing schema before inventing a new entity.
2. New enum values need a README row explaining when to use them.
3. Breaking changes (required-field additions, enum narrowing) require a DSL
   `version:` bump in `schemas/harness/dsl.schema.json`.

Full glossary: [ontology/glossary.md](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/ontology/glossary.md).
