---
id: profile
title: Profile (.omao/profile.yaml)
sidebar_position: 9
---

# Profile — `.omao/profile.yaml`

One per project, created by `oma setup`. All hooks, skills, and validation tools treat this file as **single source of truth**.

## Format (v1)

```yaml
version: 1
created_at: "2026-04-30T02:00:00Z"

harness:
  primary: claude-code        # claude-code | kiro
  secondary: null             # or "kiro" / "claude-code"

aws:
  account_id: "123456789012"
  region: ap-northeast-2
  profile_name: default
  environment: sandbox        # sandbox | staging | prod

aidlc:
  entry_phase: inception      # inception | construction | operations
  strict_gates: false

approval:
  mode: interactive           # interactive | ci-auto-approve-safe | strict
  blast_radius_ceiling: single-account

budgets:
  default_monthly_usd: 200
  warn_at_pct: 80
  block_at_pct: 100

observability:
  mode: langfuse-managed      # langfuse-managed | langfuse-self-hosted | opentelemetry-only | none
  endpoint: null

star_confirmed: false
```

## Validation

- Schema: [`schemas/profile/profile.schema.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/profile/profile.schema.json)
- `oma setup` **always** calls `profile_validate` immediately after write — installation does not complete with an invalid profile.
- `oma doctor`'s `profile-valid` probe re-validates per session.

## Field effects

- `harness.primary/secondary` — Determines which install scripts to run.
- `aws.*` — Seed budget's `scope_ref`, MCP server's region context.
- `aidlc.entry_phase` — Phase where first `/oma:autopilot` enters.
- `approval.mode` — `ci-auto-approve-safe` auto-approves within single-namespace blast radius. Otherwise human-in-the-loop.
- `approval.blast_radius_ceiling` — If exceeded, enforce human approval + secondary review.
- `budgets.*` — Seed `.omao/ontology/budgets/default.json`, and simultaneously set budget warning threshold for `user-prompt-submit.sh`.
- `observability.*` — If Langfuse self-hosted, `langfuse-observability` skill reuses `endpoint` field.

## Manual editing

- Editable without re-running `oma setup`. However, re-validate with `oma doctor` after editing.
- Empty values (`null`) may use safe defaults or error depending on field. See schema's `required` / `default` clauses.

## Rationale for defaults

- Monthly budget $200 — Observed median cost for single developer using Claude Code + Claude Sonnet full-day. Scale up for teams.
- `blast_radius_ceiling: single-account` — By default, cross-account or cross-region deployments route through human approval to control blast radius.
- `approval.mode: interactive` — Safest for initial adoption. Recommend promotion to `ci-auto-approve-safe` only in CI.
