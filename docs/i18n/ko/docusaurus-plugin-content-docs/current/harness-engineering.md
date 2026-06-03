---
id: harness-engineering
title: Harness Engineering
sidebar_position: 5
---

# Harness Engineering — the safety axis

> "The agent isn't the hard part — the harness is."

[Ontology Engineering](./ontology-engineering.md) *defines* the constraints that
make agent output correct (the WHAT/WHEN). Harness Engineering — the second
reliability axis of the [AIDLC methodology](https://devfloor9.github.io/engineering-playbook/docs/aidlc/methodology) —
is what *verifies and enforces* those constraints architecturally (the HOW). It is
the difference between "the agent knows the rule" and "the agent cannot break the
rule."

The companion page [Harness DSL](./harness-dsl.md) is the *mechanics* — the
`<plugin>.oma.yaml` format and the compiler. This page is the *why*: how OMA's
compile-time and runtime surfaces realize the methodology's safety guarantees.

## The problem: failure is architectural, not model-shaped

The methodology's canonical case: a fintech agent ran **847 API retries** in one
loop — ~$2,200 in cost, 14 half-finished emails sent to customers, a 3-hour
outage. The diagnosis was not the model or the prompt. It was the *absence of
architecture*: no retry budget, no timeout, no output gate, no circuit breaker, no
cost limit.

This reframes safety. **Guardrails** filter bad inputs/outputs at runtime (PII
masking, injection detection). A **harness** is whole-architecture design, active
from design time — "the architecture that constrains an agent to behave safely."
OMA needs both, and treats the harness as the larger container.

## The seven patterns, mapped to OMA

The methodology catalogs seven harness patterns. Here is where each lands in OMA
today — and, honestly, where it does not yet.

| Pattern | Purpose | OMA implementation | Status |
|---|---|---|---|
| **Retry Budget** | cap retries (e.g. 847 → 3) | `Budget.rule_expression` + `cost-governance` breach actions | ✅ |
| **Cost Limit** | per-request/period spend caps | `Budget` entity (`limit_usd`, `period`, `action_on_breach`); sandboxed `simpleeval` evaluator | ✅ |
| **Output Gate** | block incomplete/harmful output | `aidlc` → `construction/quality-gates` skill | ✅ |
| **PII Masking** | protect sensitive data in/out/logs | `ai-infra` → `ai-gateway-guardrails` skill | ✅ |
| **Prompt Injection Defense** | instruction hierarchy, delimiter isolation | `ai-gateway-guardrails` skill | ✅ |
| **Timeout** | prevent infinite loops | Harness DSL `timeout` field | ⚠️ partial (declared in DSL; runtime enforcement evolving) |
| **Circuit Breaker** | halt after repeated failures | — | 🔭 roadmap |

The DSL v2 `policies` block (OPA/Rego) and `telemetry` block (OpenTelemetry
Collector) are the extension points where the partial/roadmap patterns will land
without breaking `version: 1` plugins.

## Harness across the three AIDLC stages

The methodology applies the harness at every stage, not just runtime:

| Stage | Harness type | Verifies | OMA surface |
|---|---|---|---|
| **Inception** | spec verification | requirement completeness, conflicts, NFRs | `Spec`/`ADR` schema + `oma validate` |
| **Construction** | build / test | code correctness, security, architecture | `quality-gates`, `oma compile --strict-enterprise` |
| **Operations** | runtime | agent behavior limits, cost, SLOs | `cost-governance`, `ai-gateway-guardrails`, `continuous-eval` |

## Compile-time enforcement

OMA's strongest harness guarantees are enforced before anything runs, by
`oma compile`:

- **Pinned MCP versions** — `args` must contain `==X.Y.Z`; floating versions
  (`@latest`, caret ranges) are rejected so a compromised upstream release cannot
  land alongside AWS credentials.
- **Declared references only** — an agent's `mcp:` list can name only ids defined
  in the top-level `mcp:` map.
- **Real hook scripts** — `hooks.<event>.runs` must point at a file that exists.
- **Deterministic, drift-checked output** — `oma compile --check` fails CI if
  committed `.mcp.json` / `.agent.json` diverge from the DSL source.

`oma compile --strict-enterprise` raises the bar further: DSL v2 only,
`approval_chain` required on approved `Deployment`s, object-form artifacts with a
`sha256` digest, and every `Risk` classified under OWASP LLM Top 10 or NIST AI RMF.
`oma doctor --enterprise` runs 8 read-only probes to tell you whether a repo would
pass that gate before you turn it on.

## Independent verification — no self-grading

The methodology's sharpest rule: **"tests written by the same agent that wrote the
code cannot catch that agent's errors."** The fix is *independent verification* —
a different agent and model verify what another generated, with human approval on
core changes. Quality Gates are described as a "loss function" that catches errors
early before they propagate downstream.

OMA reflects this in its review lane: distinct reviewer roles (security, quality,
code) run as separate agents, and `continuous-eval` re-checks deployed behavior
against regression datasets rather than trusting the generating agent's own tests.

## How the two axes close the loop

Ontology defines constraints → harness verifies/enforces them → verification
results feed back into [ontology evolution](./ontology-engineering.md#the-triple-feedback-loop--a-living-ontology).
Correctness and safety are not independent checklists; they are two halves of one
loop. AgenticOps is what keeps that loop turning autonomously.

## References

- [engineering-playbook — Harness Engineering](https://devfloor9.github.io/engineering-playbook/docs/aidlc/methodology/harness-engineering) — conceptual source ([REFERENCES](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/REFERENCES.md#ep-harness-engineering))
- [Harness DSL](./harness-dsl.md) · [Harness DSL v2](./harness-dsl-v2.md) — the format and the compiler
- [Enterprise readiness](./enterprise-readiness.md) — `--strict-enterprise` gate + 8-probe doctor
- [Ontology Engineering](./ontology-engineering.md) — the correctness axis
