---
sidebar_position: 40
title: Enterprise readiness
---

# Enterprise readiness

:::tip Aggregate status
Run `oma enterprise-status` to summarise `doctor --enterprise` probes
plus the phased-adoption stage counters in one shot. Pass `--json` for
machine-readable output; the same payload is archived to
`.omao/status.json` so dashboards can ingest it without re-running the
probe chain.
:::

Enterprise readiness in OMA is defined by an **opt-in gate**, not a
default. Teams that do not need it pay nothing; teams that do enable it
enforce the full 8-probe contract before any `Deployment.approval_state`
can move to `approved`.

## Two commands

```bash
# Diagnostic only — no state changes, safe to run repeatedly.
oma doctor --enterprise

# Enforcement — blocks the compile when any gate fails.
oma compile --strict-enterprise
```

Run `doctor --enterprise` first. It always exits 0/1 — never changes
files. Use it during phased adoption to see what is still missing.

## The 8 probes

| # | Probe                 | What it checks                                                                                       | Where to fix                                                |
|---|-----------------------|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------|
| 1 | ontology-2020-12      | `schemas/ontology/{spec,adr}.schema.json` parse under Draft 2020-12.                                 | Update the schema — never hand-edit fixtures.               |
| 2 | slsa-digest           | Every on-disk Deployment with object-form `artifact` has `digest` matching `^sha256:[a-f0-9]{64}$`.  | Rebuild with a signing builder; fill `artifact.digest`.     |
| 3 | risk-classification   | Every Risk has at least one of `owasp_llm_top10_id` or `nist_ai_rmf_subcategory`.                    | Consult `docs/compliance/owasp-llm-top10.md` + NIST mapping. |
| 4 | audit-jsonl           | Every line of `.omao/audit.jsonl` validates against `schemas/audit/event.schema.json`.               | Replace `echo >> audit.md` with `tools.oma_audit.append`.   |
| 5 | dsl-version           | Every `*.oma.yaml` uses `version: 2`.                                                                | Bump the DSL header; all other keys stay unchanged.         |
| 6 | policies-rego         | Every `policies[].rego_ref` resolves to an existing `.rego` file.                                    | Commit the `.rego` or drop the entry from DSL.              |
| 7 | plugin-dsl            | Every plugin directory has a `*.oma.yaml` (warning only — raw `plugin.json` still permitted).        | Run the v0.5 migration for the offending plugin.            |
| 8 | mcp-pinned            | Every MCP `args[]` contains a `==X.Y.Z` pin.                                                         | Pin floating versions (`@latest` / `@canary`).              |

Probe 7 emits a **warning**; the other seven are **blocking** under
`--strict-enterprise`.

## `--strict-enterprise` additional enforcement

Beyond the 8 probes above, the compile-time gate also enforces:

- **Deployment.approval_state = approved** requires a non-empty
  `approval_chain`. Each chain link must carry `approver`,
  `approved_at` (ISO 8601), and `reason`.
- **Deployment.artifact** must use the object form. The legacy string
  form is emitted with a per-entity error line pointing at the offending
  deployment id.
- **DSL v1 files are rejected.** Bump every DSL to `version: 2` before
  turning the flag on.

## Phased adoption

| Stage | Action                                                                                       | Verification                    |
|-------|----------------------------------------------------------------------------------------------|---------------------------------|
| 1     | Run `oma doctor --enterprise` weekly; track the number of warnings and failures.             | `[doctor:enterprise] N probes OK` |
| 2     | Backfill `Risk.owasp_llm_top10_id` / `nist_ai_rmf_subcategory` on every open risk.            | Probe 3 clears.                 |
| 3     | Migrate `Deployment.artifact` to the object form; populate `digest` and `provenance_uri`.    | Probe 2 clears.                 |
| 4     | Replace every `echo >> audit.md` with `python -m tools.oma_audit.append …`.                   | Probe 4 clears.                 |
| 5     | Enable `oma compile --strict-enterprise` in CI.                                              | Non-zero exit on regression.    |
| 6     | Archive the legacy `aidlc-docs/audit.md` file once Probe 4 has been green for two weeks.      | Markdown log removed.           |

## Per-entity error format

`--strict-enterprise` emits one line per offending entity. Example:

```
strict-enterprise gate failed:
  deployment 'vllm-llama3-70b': approval_state=approved but approval_chain is empty. Fix: append one approval link with approver/approved_at/reason.
  deployment 'vllm-llama3-70b': legacy string artifact is rejected under strict-enterprise. Fix: replace with the object form (uri/digest).
  risk 'legacy-oracle': strict-enterprise requires at least one of owasp_llm_top10_id (LLM01..LLM10) or nist_ai_rmf_subcategory (e.g. MEASURE.2.6). Fix: add the classification that best matches this risk.
```

The error lines are stable enough to parse from CI logs.

## Known limitations

- Client-provided `approved_at` timestamps are not cryptographically
  bound to the approver identity. Layer cosign bundles via
  `Deployment.artifact.signing.cosign_bundle_uri` for stronger
  non-repudiation; see [SLSA provenance](./compliance/slsa-provenance.md).
- The mapping docs cover ~14 NIST AI RMF subcategories out of 72. Teams
  with stricter audit scopes extend their own matrix and attach extra
  `Risk.compliance_refs[]` rows.
- `oma validate` shells out to a pre-installed `opa` binary. When `opa`
  is absent the policy phase is skipped with a warning; schema
  validation still runs.
