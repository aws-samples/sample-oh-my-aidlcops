---
sidebar_position: 10
title: NIST AI RMF mapping
---

# NIST AI Risk Management Framework (AI 100-1) mapping

OMA uses the NIST AI RMF as its primary AI-specific governance taxonomy.
Every `Risk` entity can carry an optional
`nist_ai_rmf_subcategory` of the form
`{GOVERN|MAP|MEASURE|MANAGE}.<n>.<n>` (e.g. `GOVERN.1.1`).
Audit events may reference the same subcategory under
`compliance.nist_ai_rmf`.

> **Authoritative reference**: NIST AI 100-1, *Artificial Intelligence
> Risk Management Framework (AI RMF 1.0)*,
> https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf

## Why this mapping exists

- **Traceability.** A `Deployment.approval_state=approved` decision is
  easier to defend during an audit when the blocking `Risk`s it cleared
  list the NIST subcategory they addressed.
- **Skill routing.** `agenticops.incident-response` and
  `modernization.risk-discovery` pivot on the RMF function
  (GOVERN/MAP/MEASURE/MANAGE) to decide which playbook runs.
- **Aggregation.** FinOps and security dashboards group spend and
  incidents by RMF function to report up to compliance leadership.

## Function → OMA surface

| RMF function | What OMA enforces                                               | Primary field / gate                                       |
|--------------|-----------------------------------------------------------------|------------------------------------------------------------|
| **GOVERN**   | Policy and role accountability for every approval.              | `Deployment.approval_chain`, `Risk.compliance_refs[]`      |
| **MAP**      | Context capture during AIDLC Inception.                         | `Spec` (id, owner, requirements), `ADR.context`            |
| **MEASURE**  | Evaluation and monitoring of deployed models.                   | `telemetry.traces/metrics/logs`, `.omao/audit.jsonl`       |
| **MANAGE**   | Mitigation, rollback, and lifecycle of identified risks.        | `Risk.mitigation`, `Deployment.rollback_plan`, `Incident`  |

## Representative subcategory map

The table is intentionally not exhaustive — it lists the subcategories we
have wired concretely. Additional entries land as plugins grow.

| Subcategory | Intent (abbrev.)                                       | OMA field / action                                                  |
|-------------|--------------------------------------------------------|---------------------------------------------------------------------|
| GOVERN.1.1  | AI risk management policies are established.          | `Risk.nist_ai_rmf_subcategory`; `Deployment.approval_chain` non-empty under `--strict-enterprise`. |
| GOVERN.1.3  | Oversight roles documented.                           | `Deployment.approval_chain[].role`; `Incident.approval_chain[].role`. |
| GOVERN.4.2  | Third-party risks addressed.                          | `Risk.compliance_refs[]` with `framework=slsa`; SLSA provenance on `Deployment.artifact`. |
| MAP.1.1     | Context of AI system use is documented.               | `Spec.description` + `Spec.requirements[]`.                         |
| MAP.1.6     | System objectives are tied to stakeholders.           | `Spec.owner`; `Spec.linked_adrs[]`.                                 |
| MAP.5.2     | Likelihood and impact assessed.                       | `Risk.likelihood` × `Risk.impact` matrix.                           |
| MEASURE.2.6 | Content safety evaluated.                             | OWASP LLM01 guardrails + `Risk.owasp_llm_top10_id=LLM01`.           |
| MEASURE.2.11| Fairness/bias evaluated.                              | `Risk.owasp_llm_top10_id=LLM09` (misinformation) + eval pipelines.  |
| MEASURE.2.13| Monitored performance.                                | `telemetry.metrics.endpoint`; Langfuse trace exports.               |
| MANAGE.1.3  | Responses to risks prioritised and tracked.           | `Risk.mitigation`; `Risk.gate_ref` blocks stage transition until closed. |
| MANAGE.2.4  | Plans for continuing monitoring.                      | `agenticops.continuous-eval` skill; `telemetry.traces` endpoint.    |
| MANAGE.4.1  | Incident response plan invoked.                       | `Incident` with non-empty `proposed_fix` + `approval_chain`.        |

## Using it day-to-day

1. When `modernization.risk-discovery` emits a `Risk`, set both
   `nist_ai_rmf_subcategory` **and** at least one `compliance_refs[]`
   entry so downstream skills can aggregate.
2. When `agenticops.incident-response` proposes a remediation, it writes
   an `AuditEvent` with `compliance.nist_ai_rmf` pointing to the
   relevant MANAGE subcategory.
3. Under `oma compile --strict-enterprise` (v0.5), every `Risk` without
   either `owasp_llm_top10_id` or `nist_ai_rmf_subcategory` is rejected
   with a per-entity error line.

## Known gaps

- This mapping covers ~14 of the 72 subcategories. The remainder are
  acknowledged but not yet wired. PRs welcome.
- Non-repudiation on `approval_chain[].approved_at` is client-provided;
  cryptographic signing is tracked separately via
  [SLSA provenance](./slsa-provenance.md).
