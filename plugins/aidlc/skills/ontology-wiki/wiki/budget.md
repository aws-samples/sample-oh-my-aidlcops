# Budget

> Cost-governance fact feeding the Outer Loop. Source:
> `schemas/ontology/budget.schema.json`.

## What it is

A `Budget` sets a hard USD limit over a period, with a `rule_expression` that
`agenticops.cost-governance` evaluates against runtime metrics and an
`action_on_breach` that says what to do when it trips.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z][a-z0-9-]*$` | |
| `scope` | ✅ | `account · agent · skill · deployment · tag` | what the budget applies to |
| `limit_usd` | ✅ | number | hard limit for the period |
| `period` | ✅ | `hourly · daily · weekly · monthly · quarterly` | |
| `rule_expression` | ✅ | string | **simpleeval** expression, e.g. `spend_usd > limit_usd * 0.8` |
| `action_on_breach` | ✅ | `notify · throttle · suspend-agent · require-approval · auto-rollback` | |
| `scope_ref` | | string | ⚠️ weakest-typed edge — account id / Agent.id / Skill.id / Deployment.id / `k=v` tag |
| `notify_targets` | | array | Slack/Email/SNS for the `notify` action |
| `cost_center_owner` | | string | FinOps chargeback owner |
| `approval_gate` | | `none · finops-director · cfo` | used when `action_on_breach = require-approval` |
| `exception_expires_at` | | date-time | auto-expiry for temporary overage waivers |

## References (from graph.json)

- `Budget → Agent` via `scope_ref` — **scoped_to** (⚠️ AMBIGUOUS, 0.4 — lowest
  confidence edge in the graph; four possible target types, no pattern)

## Why it is shaped this way

- **`rule_expression` is simpleeval, never Python `eval()`** — it is
  user-editable input, so it runs in the sandboxed `eval_condition()` in
  `cost-governance/SKILL.md`. This is a safety requirement, not a preference.
- **`action_on_breach` is an enum of escalations** so cost-governance has a
  fixed, auditable set of responses.

## Gotchas for an authoring agent

- `scope_ref` is the graph's most likely drift point. Always pair it with an
  explicit `scope` so the reference type is unambiguous, and prefer an id that
  matches the `scope` you set.
- Never put raw `eval()`-style expressions in `rule_expression`; stay within
  simpleeval's grammar.
