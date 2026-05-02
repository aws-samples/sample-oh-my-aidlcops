---
sidebar_position: 30
title: Harness DSL v2
---

# Harness DSL v2

OMA's harness DSL bumped from `version: 1` to `version: 2` in release
v0.3b. The bump is **purely additive** — existing v1 files compile
unchanged and emit the same `.mcp.json` / `kiro-agents/*.agent.json`
output they did before.

## What is new

v2 adds four optional top-level sections on top of v1:

| Section | Status in v0.3b | Purpose |
|---------|-----------------|---------|
| `metadata` | Accepted, ignored by the compiler | Kubernetes-style `labels` / `annotations` |
| `workflows` | Validated as a DAG; no runtime executor | Named sequences of agent/skill steps |
| `telemetry` | Free-form object (body validated in v0.4) | OpenTelemetry Collector wiring |
| `policies` | Free-form array (body validated in v0.4) | OPA/Rego policy-as-code references |

None of these sections change the files emitted by `oma-compile`. A
plugin can adopt v2 solely to annotate its intent, without touching its
runtime surface.

## Migrating a v1 file

1. Change the top-level `version: 1` to `version: 2`.
2. Keep every other key exactly as it was.
3. Optionally add any of the four new sections.

Example — adding a workflow DAG:

```yaml
version: 2
plugin: ai-infra

metadata:
  labels:
    aidlc-phase: construction

agents:
  - id: platform-architect
    runtime: kiro
    mcp: [eks]
  - id: vllm-deployer
    runtime: kiro
    mcp: [eks]

mcp:
  eks:
    command: uvx
    args: ["awslabs.eks-mcp-server==0.1.28"]

workflows:
  platform-bootstrap:
    description: 5-checkpoint platform bootstrap
    steps:
      - id: preflight
        agent_ref: platform-architect
      - id: provision
        agent_ref: vllm-deployer
        depends_on: [preflight]
        on_failure: rollback
```

## Workflow DAG validation

The compiler rejects the file before emission if any of these hold:

- a `depends_on` entry does not name a step in the same workflow;
- the `depends_on` graph contains a cycle;
- an `agent_ref` does not match an `agents[].id` in the same file;
- two steps share the same `id` inside one workflow.

`skill_ref` is **not** validated against the plugin file — skills are
resolved at runtime by the harness.

## Backward compatibility guarantees

- v1 files continue to validate under the same `dsl.schema.json`.
- v1 files are **explicitly prohibited** from using the v2-only sections
  (enforced via a schema `allOf[0].if/then`).
- Under `oma compile --strict-enterprise` (v0.5) only v2 files are
  accepted; the baseline `oma compile` continues to accept both.

## What comes next

- **v0.4** fills in the body schemas for `telemetry` and `policies` and
  wires `scripts/oma/validate.sh` to shell out to `opa eval` when a
  plugin declares policies.
- **v0.5** regenerates `ai-infra.oma.yaml`'s native outputs as a
  byte-diff baseline and migrates the remaining four plugins to v2.
