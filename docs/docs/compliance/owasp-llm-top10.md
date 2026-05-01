---
sidebar_position: 20
title: OWASP LLM Top 10 mapping
---

# OWASP Top 10 for Large Language Model Applications — OMA mapping

:::tip External references
Every upstream spec and framework OMA cites — including OWASP LLM
Top 10 itself — is catalogued on the [References](/docs/references)
page.
:::

`Risk.owasp_llm_top10_id` takes values `LLM01`..`LLM10`. Every Risk that
relates to LLM application security should carry exactly one of these
codes; risks spanning multiple categories fan out via
`Risk.compliance_refs[]`.

> **Authoritative reference**: OWASP Foundation,
> [OWASP Top 10 for LLM Applications 2025](https://owasp.org/www-project-top-10-for-large-language-model-applications/).

## Category map

| Code  | OWASP title                            | Primary OMA field / skill                                                 | Typical mitigation                                     |
|-------|----------------------------------------|---------------------------------------------------------------------------|--------------------------------------------------------|
| LLM01 | Prompt Injection                       | `agentic-platform.ai-gateway-guardrails` skill; OPA policy `data.oma.deny` | Pre-prompt sanitisation + egress allow-list.           |
| LLM02 | Sensitive Information Disclosure       | `Budget.notify_targets` redaction; Presidio scan upstream of Langfuse.    | PII scrubbing in trace exports.                        |
| LLM03 | Supply Chain                           | `Deployment.artifact.provenance_uri` (SLSA v1.1); MCP server pinning.     | Signed provenance + pinned `==X.Y.Z` dependencies.     |
| LLM04 | Data and Model Poisoning               | `Risk.category=data-migration` with `Risk.evidence[]` lineage.             | Training-set diffs captured as ADRs.                   |
| LLM05 | Improper Output Handling               | `Deployment.blast_radius`; output schema validation on tool calls.         | Typed tool signatures + post-response validator.       |
| LLM06 | Excessive Agency                       | `Agent.tier` gating; `policies[]` blocking writes under strict mode.      | Tier-2 agents never callable directly from user input. |
| LLM07 | System Prompt Leakage                  | `ai-gateway-guardrails.prompt_exfiltration_rules`; audit action `policy-deny`. | Deny-list canaries in system prompts.                 |
| LLM08 | Vector and Embedding Weaknesses        | `bedrock-kb-retrieval-mcp` configuration review.                          | Embedding provider pinning + retrieval-time ACLs.      |
| LLM09 | Misinformation                         | `telemetry.traces` + Langfuse `MEASURE.2.11` fairness evaluations.        | Human-in-the-loop on high-severity model outputs.      |
| LLM10 | Unbounded Consumption                  | `Budget.action_on_breach=throttle | suspend-agent`.                       | Rate-limiters + cost-aware agent routing.              |

## Wiring into skills

- `plugins/agentic-platform/skills/ai-gateway-guardrails/SKILL.md` uses
  LLM01/LLM02/LLM06/LLM07 as its primary taxonomy.
- `plugins/agenticops/skills/cost-governance/SKILL.md` addresses LLM10
  via `Budget.action_on_breach` and enforces `approval_gate` on
  exceptions.
- `plugins/agenticops/skills/incident-response/SKILL.md` emits an
  `Incident` whose `approval_chain` backs each `policy-deny` audit
  event.

## Risk authoring checklist

Every new Risk tagged against an LLM category should carry:

1. `owasp_llm_top10_id` — exactly one enum value.
2. `nist_ai_rmf_subcategory` — the closest NIST subcategory (often
   `MEASURE.2.6` for LLM01/05 and `MANAGE.4.1` for LLM10).
3. `mitigation` — one or two sentences describing the planned fix.
4. `gate_ref` — the quality gate that stays open until the mitigation
   lands (stage-gate-strict consumers).
5. `compliance_refs[]` entries for any sector-specific controls (SOC 2,
   ISO 42001, NIST 800-53) the organisation tracks.

`oma compile --strict-enterprise` (v0.5) blocks the commit when items 1
or 2 are missing.
