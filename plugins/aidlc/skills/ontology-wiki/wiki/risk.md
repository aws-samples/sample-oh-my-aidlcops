# Risk

> Operations fact; OWASP/NIST-classified; gates Deployments. Source:
> `schemas/ontology/risk.schema.json`.

## What it is

A `Risk` records a categorized threat with a likelihood and impact, an optional
mitigation, and optional compliance classifications (OWASP LLM Top 10, NIST AI
RMF). It gates stage transitions via `gate_ref` and can be waived per-deployment.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z0-9][a-z0-9-]*$` | |
| `category` | ✅ | `rehost · replatform · refactor · repurchase · retain · retire · compliance · performance · security · data-migration` | 6R bucket or cross-cutting concern |
| `likelihood` | ✅ | `very-low · low · medium · high · very-high` | |
| `impact` | ✅ | `minor · moderate · major · severe · catastrophic` | |
| `mitigation` | | string | **required before `accepted: true`** |
| `gate_ref` | | string | ⚠️ quality gate this risk blocks (AMBIGUOUS target) |
| `accepted` | | boolean | |
| `owner` | | string | accountable human/team |
| `evidence` | | array | |
| `owasp_llm_top10_id` | | `LLM01 · LLM02 · LLM03 · LLM04 · LLM05 · LLM06 · LLM07 · LLM08 · LLM09 · LLM10` | OWASP Top 10 for LLM Applications |
| `nist_ai_rmf_subcategory` | | `^(GOVERN\|MAP\|MEASURE\|MANAGE)\.[0-9]+\.[0-9]+$` | e.g. `GOVERN.1.1`, `MEASURE.2.6` |
| `compliance_refs` | | array | framework controls this risk maps to |
| `deployment_refs` | | array of `^[a-z][a-z0-9-]*$` | `Deployment.id` values this applies to |

## References (from graph.json)

- `Risk → Deployment` via `deployment_refs` — **applies_to** (EXTRACTED, 0.9)
- `Risk → Skill` via `gate_ref` — **blocks_gate** (⚠️ AMBIGUOUS, 0.5)
- inverse: `Deployment.risk_exceptions` waives a risk's gate for one deployment

## Why it is shaped this way

- **`deployment_refs` (here) and `Deployment.risk_exceptions` (there) are an
  asymmetric pair**: a risk *applies to* deployments, but a deployment can
  *explicitly waive* the gate. Both directions must be checked or an unmitigated
  risk ships silently.
- **OWASP/NIST fields are optional but load-bearing** — strict-enterprise
  requires at least one of `owasp_llm_top10_id` / `nist_ai_rmf_subcategory` on
  every risk, so classify at authoring time.

## Gotchas for an authoring agent

- Before authoring a new Risk, query existing risks for the same
  `owasp_llm_top10_id` / `nist_ai_rmf_subcategory` — reuse the established
  classification instead of inventing a parallel one.
- `mitigation` is required before you may set `accepted: true`.
