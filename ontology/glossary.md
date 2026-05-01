# OMA Glossary

Terms here match the schemas in `../schemas/ontology/`. One paragraph per term.
If you add a term to a schema, add it here too.

## AIDLC

The AI-Driven Development Lifecycle. Three phases: **Inception** (requirements,
ADRs, user stories), **Construction** (component design, codegen, TDD for
agentic systems), **Operations** (continuous eval, incident response, cost
governance). OMA treats AIDLC as the primary unit of work and maps Tier-0
workflows onto phase boundaries.

## AgenticOps

The operations-phase operating model where agents diagnose, propose fixes, and
request approval, but humans approve. Automation never skips an approval
checkpoint. Implemented by the `agenticops` plugin.

## Agent

An OMA-invocable unit of execution. Three runtimes: `claude-code` for Claude
Code subagents, `kiro` for Kiro `.agent.json` profiles, `cli` for tmux-hosted
CLI workers (claude/codex/gemini). Agents declare what ontology entities they
`produce` and `consume` so the harness can wire inputs without prose contracts.

## Skill

A procedure loaded into a harness — SKILL.md for Claude Code, a steering
fragment for Kiro, or both. Skills are addressable by keyword trigger or slash
command. A skill is what the user invokes; an Agent is what the skill delegates
to.

## Deployment

The artifact that crosses the Construction->Operations boundary. Immutable
`target` (eks/ec2/lambda/...), `artifact` (image ref or zip URI), and
`approval_state` machine: draft -> proposed -> approved -> deployed
(or rejected, or rolled_back). `agenticops.autopilot-deploy` refuses to act on
anything below `approved`.

## Incident

An operational event handled by `agenticops.incident-response`. Always carries
a `severity` (sev-1..sev-5), an `alarm_source`, and a `proposed_fix` written by
an agent. The `approval_state` machine mirrors Deployment's so the same UI can
render both. `deployment_ref` ties an incident back to the artifact that broke.

## Budget

A cost-governance constraint. Scope is one of `account | agent | skill |
deployment | tag`. The `rule_expression` is evaluated by the simpleeval-backed
`eval_condition()` function (see `plugins/agenticops/skills/cost-governance/SKILL.md`).
Python `eval()` is forbidden here — the simpleeval sandbox exists because
`rule_expression` is user-editable input.

## Risk

A modernization risk surfaced by `modernization.risk-discovery`. Carries
`category` (6R + cross-cutting concerns), `likelihood`, `impact`, `mitigation`,
and optional `gate_ref`. Under stage-gate-strict, an unaccepted risk with a
non-empty `gate_ref` blocks the Construction->Operations transition.

## Harness

Everything outside the ontology that makes a plugin run: hooks, MCP server
wiring, agent profiles, keyword triggers, session state directories. Harnesses
are harness-agnostic only at the `.omao/` layer — both Claude Code and Kiro
read/write the same `.omao/`.

## DSL

The YAML surface defined by `schemas/harness/dsl.schema.json`. One
`<plugin>.oma.yaml` per plugin. `oma-compile` reads it and emits the native
files that Claude Code and Kiro already understand. The DSL never runs at
runtime — it is a build-time translator.

## Tier-0 / Tier-1 / Tier-2

Workflow depth classification. Tier-0 are top-level user-facing workflows
(`/oma:autopilot`, `/oma:agenticops`). Tier-1 are plugin-local workflows
invoked by Tier-0. Tier-2 are specialist procedures Tier-1 delegates to. The
`Agent.tier` field records which layer an agent belongs to so the harness can
reject Tier-2 agents from being called directly by the user.

## 6R (modernization)

Rehost, Replatform, Refactor, Repurchase, Retain, Retire. The six modernization
categories used by `Risk.category` and by the `modernization` plugin's decision
trees. Cross-cutting concerns (compliance, performance, security,
data-migration) extend this vocabulary without reshaping the 6R core.

## Approval state

Shared lifecycle used by Deployment and Incident. Always goes through
`proposed` before any remediation runs. Agents write `proposed`; humans write
`approved` or `rejected`. The harness is the only writer of the terminal
states (`deployed`, `rolled_back`, `mitigated`, `closed`).

## Blast radius

How far damage spreads if a Deployment misbehaves. Enum values map to AWS
constructs: `single-namespace` (one k8s namespace), `single-cluster` (one EKS
cluster), `single-account` (one AWS account), `cross-account`, `cross-region`.
AgenticOps escalates approval requirements as the blast radius grows.

## Spec

An Inception-phase artefact (schema `spec.schema.json`, Draft 2020-12)
capturing requirements and owner. Every requirement carries an id, text, and
MoSCoW priority (`must`/`should`/`may`). Spec supersedes older specs via
`supersedes[]` and links forward to ADRs via `linked_adrs[]`. Deployments
reference the spec they satisfy through `Deployment.spec_ref`.

## ADR

Architecture Decision Record (schema `adr.schema.json`, Draft 2020-12).
Numbered (`adr-0001-...`), with `context` / `decision` / `consequences`
sections. An ADR moves from `proposed` -> `accepted` (or `rejected`) and may
later be `deprecated` or `superseded_by` a later ADR. Deployments reference
the ADRs they follow via `Deployment.adr_refs[]`.

## ApprovalChain

A reusable `$defs` block in `schemas/common/approval-chain.schema.json`.
Each link is `{approver, approved_at, reason, role?}`. Appears on
`Deployment.approval_chain` and `Incident.approval_chain`. Client-provided
timestamps are not cryptographic non-repudiation; see
`docs/docs/compliance/slsa-provenance.md` (v0.4) for how cosign bundles
layer on top.

## AuditEvent

One line of `.omao/audit.jsonl`, described by
`schemas/audit/event.schema.json`. Captures `{timestamp, actor, action,
target, phase}` plus optional `compliance`, `trace_id`, and `span_id`
fields. Skills move from `echo >> aidlc-docs/audit.md` to
`tools.oma_audit.append` over v0.4 (dual-write) and v0.5 (Markdown path
removed).

## OWASP LLM Top 10

The OWASP project "Top 10 for Large Language Model Applications". OMA
captures the categorisation on `Risk.owasp_llm_top10_id` (enum
`LLM01`..`LLM10`). The mapping from each category to the OMA field that
mitigates it lives in `docs/docs/compliance/owasp-llm-top10.md` (v0.4).

## NIST AI RMF subcategory

An identifier from NIST AI 100-1 of the shape
`{GOVERN|MAP|MEASURE|MANAGE}.<number>.<number>` (e.g. `MEASURE.2.6`).
Appears on `Risk.nist_ai_rmf_subcategory` and on
`AuditEvent.compliance.nist_ai_rmf`. Mapping docs land in v0.4.

## Quality gate

A blocking check at a phase boundary. Tracked via
`steering/workflows/stage-gated-progression.md`. An open gate prevents the AIDLC
loop from advancing. `Risk.gate_ref` names the gate a risk blocks, so the stage
machine can explain *why* progression is refused.
