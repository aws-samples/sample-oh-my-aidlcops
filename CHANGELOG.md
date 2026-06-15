# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
once GA is reached. During Tech Preview, patch releases may contain
breaking changes to non-stable surfaces as documented in
[`docs/docs/support-policy.md`](./docs/docs/support-policy.md).

## [Unreleased]

### Added
- **Reliability dual-axis docs.** Two methodology-grounded pages —
  `docs/docs/ontology-engineering.md` (correctness axis: typed world
  model, Inner/Middle/Outer triple feedback loop, AgenticOps as the
  living-ontology Outer Loop) and `docs/docs/harness-engineering.md`
  (safety axis: seven harness patterns mapped to OMA surfaces with
  honest partial/roadmap status, independent verification) — plus a
  "Reliability dual-axis" sidebar category.
- **Diagram authoring standard.**
  `steering/workflows/diagram-authoring-standard.md` mandates the diagram
  tool by intent — D2 (flow/sequence/state), mingrammer Diagrams
  (infrastructure/cloud), Excalidraw (concept sketches) — retires Mermaid
  for new diagrams, and requires quoted labels on any grandfathered
  Mermaid. Surfaced as a top-level rule in `steering/oma-hub.md`; D2,
  Diagrams, and Excalidraw registered in REFERENCES.
- **REFERENCES.** Registered the engineering-playbook AIDLC methodology
  landing page and the Ontology/Harness Engineering sub-pages as the
  canonical conceptual sources.
- **`observability.trace_mcp` profile contract.** Optional
  `schemas/profile/profile.schema.json` block (additive, null by default)
  that registers a user-supplied trace-reading MCP server for the
  agenticops feedback-loop skills. OMA ships no trace MCP and runs no
  Langfuse — it defines the `mcp__<server_name>__*` socket; the user
  supplies the server. Registered the Langfuse Public API in REFERENCES.
- `templates/permissions/{common,sandbox,staging,prod}.yaml` — abstract
  deny-rule templates scoped by `profile.yaml` `aws.environment`. Each
  template declares `deny.{bash,edit,write,mcp}` patterns plus
  `auto_approve` defaults. See `templates/permissions/README.md` for the
  schema and the abstract → harness mapping table.
- `scripts/lib/permissions.sh` — shared resolver. Reads
  `templates/permissions/<env>.yaml`, follows `extends` against
  `common.yaml`, and emits a normalized JSON document plus Claude /
  Kiro emitters (`perms_to_claude_deny`, `perms_to_kiro_autoapprove`).
- `install_permissions()` in `scripts/install/{claude,kiro}.sh`:
  Claude — append-uniq merge of `permissions.deny` into
  `~/.claude/settings.json`; existing user-authored entries preserved.
  Kiro — patch `~/.kiro/settings/cli.json` autoApprove and rewrite each
  OMA-owned `~/.kiro/agents/*.agent.json` from the source repo (never
  mutates the tracked repo files), tagging the result with
  `_meta.oma_permissions_env` so the deny set is auditable from Kiro.
  Hand-edited agent.json copies are detected and refused.
- New install flags `--skip-permissions` / `OMA_SKIP_PERMISSIONS=1` and
  override `OMA_PERMISSIONS_ENV=<env>` for CI smoke runs.
- `scripts/oma/setup.sh` exports `OMA_PROJECT_DIR` so the install
  scripts read the project's `.omao/profile.yaml`, not their own cwd.
- `tests/installer/test_permissions_lib.bats` and
  `tests/installer/test_install_permissions.bats` — 26 bats cases
  covering the resolver (extends-merge, env validation, sandbox/staging/
  prod superset, emitter shape) and the end-to-end install path
  (idempotency, user-entry preservation, `--skip-permissions`,
  `OMA_PERMISSIONS_ENV` override, hand-edited agent refusal, source
  repo cleanliness).
- New `permissions-applied` probe in `scripts/oma/doctor.sh` (13th
  probe). Reports pass when `~/.claude/settings.json` deny set is a
  superset of the resolved env template AND every Kiro
  `~/.kiro/agents/*.agent.json` carries a matching
  `_meta.oma_permissions_env`. Skips cleanly when no profile or no
  harness install is detected; warns and points at `oma setup` when
  drift is detected. `bin/oma` help reflects the new count.
- `tests/installer/test_doctor_permissions.bats` — 9 cases pinning
  the probe through skip / pass / warn paths for both harnesses,
  including profile env-mismatch and missing/unsupported
  aws.environment.
- **Project-level permission overlay**:
  `<project>/.omao/permissions.yaml` is now read on top of the
  `common + <env>.yaml` chain. Overlay supports
  `deny.add.{bash,edit,write,mcp}`, `deny.remove.{...}`, and
  `auto_approve.{...}` overrides. `scripts/lib/permissions.sh` gains
  `perms_apply_overlay` and `perms_resolve_with_overlays`; both install
  scripts and the doctor probe call the new resolver so the overlay is
  reflected in `~/.claude/settings.json`, Kiro autoApprove, and the
  doctor superset check.
- `oma permissions [show|path]` subcommand
  (`scripts/oma/permissions.sh`). `show` prints the resolved chain with
  per-entry provenance (`common.yaml` / `<env>.yaml` / `overlay`) plus
  overlay add/remove counts; `--json` emits machine-readable output.
  `path` prints `<project>/.omao/permissions.yaml` and creates the
  parent directory so `$EDITOR $(oma permissions path)` works
  immediately. Registered in `bin/oma`.
- `tests/installer/test_permissions_overlay.bats` — 9 cases covering
  the overlay add/remove/auto_approve semantics, the
  `oma permissions show|path|--json` interface, install reflection,
  and the doctor warn-on-overlay-but-no-reinstall path. The lib suite
  also gains 6 unit cases for `perms_resolve_with_overlays`.
- `hooks/{session-start,user-prompt-submit}.sh` emit a new
  `[MAGIC KEYWORD: OMA_PERMISSIONS_DRIFT]` line when
  `.omao/permissions.yaml` has been edited more recently than
  `~/.claude/settings.json` or `~/.kiro/settings/cli.json`. The
  per-prompt hook is the load-bearing one: a yaml edit is reflected
  on the very next prompt, not just the next session. Detection is a
  pure mtime check shared via `perms_overlay_drift` in
  `scripts/lib/permissions.sh`. Kill switch:
  `OMA_DISABLE_PERMISSIONS_DRIFT=1`. 9 new bats cases across
  `tests/hooks/test_session_start.bats` and
  `tests/hooks/test_user_prompt_submit_drift.bats` cover newer-overlay,
  newer-settings, kill switch, missing-harness-config, and "trigger
  keyword still wins" paths.
- `hooks/user-prompt-submit.sh` no longer exits early on an empty
  triggers list — the budget warning and the new drift block need
  to run regardless. Triggers loop is now properly conditional on
  non-empty `TRIGGERS`.
- `oma setup` now seeds `<project>/.omao/permissions.yaml` from
  `templates/permissions/overlay.yaml.tmpl` on first run. The seed is
  fully commented out so it's a no-op overlay; users uncomment the
  rules they need. Existing overlay files are preserved verbatim on
  re-run. Two new bats cases in `tests/profile/test_setup_non_interactive.bats`
  pin the no-op equivalence and the preservation behaviour.

### Changed
- **Observability is opt-in (default `none`).** `oma setup` no longer
  defaults to `langfuse-managed`; the ontology + harness core needs no
  observability backend. OTel (`opentelemetry-only`) and Langfuse
  (`langfuse-self-hosted` / `langfuse-managed`) are explicit opt-in
  choices. Updated the setup prompt, profile template/docs (en/ko),
  easy-button CI example, the `/oma:self-improving` workflow descriptions,
  and marked `ai-infra`'s `langfuse-observability` skill as an optional
  backend. No schema change (the mode enum already included `none`).
- **Repositioning.** README (en/ko), docs intro, philosophy, and the
  marketplace description now lead with the AIDLC methodology's
  reliability dual-axis — Ontology Engineering (correctness) and
  Harness Engineering (safety) as installable plugins — with AIDLC
  Workflows as the process spine and AgenticOps reframed as the
  living-ontology Outer Loop, rather than the prior
  "Operations-automation marketplace" framing. No code or schema
  changes.
- **Easy-button + enterprise-ops-toolset framing.** READMEs, intro, and
  philosophy now present OMA as a one-install easy button for the two
  reliability axes, with a stated roadmap toward AWS Hosted MCP + DevOps
  agent + Security agent integrations forming an open toolset for
  enterprise operations automation.
- **Harness policy enforcement migrated from OPA/Rego to pure Claude Code
  `PreToolUse` hooks.** The old path (`spec.policies[].rego_ref` pointing
  at `.rego` files + `scripts/oma/validate.sh` shelling out to an `opa`
  binary, fail-open when `opa` was absent) is gone. Each plugin's
  `policies[].enforce` block now compiles into
  `plugins/<name>/hooks/harness-rules.json` plus a managed `PreToolUse`
  entry in `hooks/hooks.json` that runs the bundled `hooks/enforce.py`
  (copied from `tools/oma_harness/enforce.py`), blocking matching tool
  calls before they run — fail-closed per rule, no external policy
  engine, no `opa` dependency.
- `oma doctor --enterprise` probe #6 renamed `policies-rego` →
  `policies-enforce`; it now verifies every `policies[].enforce.deny_if`
  regex compiles instead of resolving `.rego` files.
- `oma validate` is JSON-Schema-only; it no longer evaluates policy.
  `tools/oma_compile/compile.py` swaps `_verify_rego_refs()` for
  `_verify_policy_regexes()` and emits the harness hook artifacts.
- Removed `policies/examples/*.rego` and `tests/harness/test_opa_stub.py`.

### Fixed
- **Self-improving loop honesty.** The landing page and docs implied OMA
  turns Langfuse traces into improvement PRs out of the box. OMA ships the
  skills and the MCP contract, not the Langfuse runtime — docs (landing,
  intro, philosophy, profile, tier-0; ko + en) now state the loop closes
  only when an external Langfuse + trace MCP is configured. The three
  agenticops skills no longer shell out to `curl` with Langfuse secrets or
  call an undefined `fetch_langfuse_traces()`; they consume
  `mcp__<server_name>__*` and degrade gracefully when unconfigured.
- **Broken philosophy/ontology Mermaid diagrams.** Unquoted labels (the
  `(6R)` edge label aborted the entire flowchart parse) now quoted per the
  diagram-authoring standard; the English philosophy diagram, which had
  drifted from the Korean source, is re-synced.
- **Doc consistency.** `ontology.md` (en/ko) now documents all 8 entities
  (adds Spec/ADR); stale `v0.2.0-preview.1` strings in easy-button,
  getting-started, and support-policy refreshed to `v0.4.0-preview.1`;
  the "5 plugins" GA criterion corrected to 4; duplicate aidlc Phase 1 /
  Phase 2 plugin rows merged. Missing en i18n pages added so the
  Docusaurus build resolves with 0 link warnings.
- `hooks/{session-start,user-prompt-submit}.sh` now emit
  `{hookSpecificOutput: {hookEventName, additionalContext}}` instead
  of the bare `{additionalContext}` form. Claude Code 2.x ignores
  the legacy shape silently — the user sees no effect from any hook
  output (drift alerts, trigger keywords, budget warnings, ontology
  status block, active-mode reminder, project memory). Confirmed
  against Anthropic's 2.1.x hook reference. Affected emit sites:
  session-start jq + python3 + python fallbacks; user-prompt-submit
  trigger, budget, and permission-drift branches. Existing bats
  assertions migrated to the new jq path
  `.hookSpecificOutput.additionalContext`.
- `hooks/{session-start,user-prompt-submit}.sh` now resolve every
  `.omao/...` path against `$CLAUDE_PROJECT_DIR` (with `OMA_PROJECT_DIR`
  and `$PWD` as fallbacks) instead of the bare cwd. Claude Code spawns
  hooks from whichever directory `claude` was invoked in, so the
  previous relative-path lookups silently skipped when the cwd
  diverged from the project root. Affected paths: trigger detection
  (`.omao/triggers.json`), active-mode reminder
  (`.omao/state/active-mode`), project-memory loading
  (`.omao/project-memory.json`), ontology status block
  (`.omao/ontology/`), and the budget warning
  (`.omao/ontology/budgets/`).
- `scripts/install/{claude,kiro}.sh` `install_permissions`: when the
  PyYAML fallback path runs `python3 -c "import sys, yaml; ..."` against
  `.omao/profile.yaml` and PyYAML is missing on the inherited python3,
  the invocation used to dump a traceback to stderr and an empty stdout,
  silently collapsing `env=""` and skipping the entire permissions step.
  CI test 20 (`claude.sh stamps the OMA permissions sentinel`) failed
  downstream when this happened. The fallback now probes `import yaml`
  first and `die`s with a clear remediation message
  (`pip install pyyaml`, or set `OMA_PERMISSIONS_ENV` /
  `OMA_SKIP_PERMISSIONS=1`). The bats sentinel assertions also capture
  the install status + output so any future regression surfaces here
  instead of as a confusing `[ -f sentinel ]` failure two lines later.
  `.github/workflows/oma-foundation.yml` adds a `python3 -c "import
  yaml"` smoke check before the bats step so the missing dependency is
  named at the top of the failure log.
- `perms_overlay_drift` now compares `.omao/permissions.yaml` against
  OMA-owned sentinel files (`<harness_home>/.oma-permissions-applied-at`)
  instead of the harness config (`settings.json` / `cli.json`). Both
  Claude Code and Kiro touch their own settings files for unrelated
  reasons (session telemetry, model cache); using their mtime caused
  the drift hook to silently false-negative as soon as the harness
  bumped its config timestamp. install_permissions in both install
  scripts now stamps a sentinel after a successful merge, and a harness
  with no sentinel is treated as "never installed" — no false-positive
  alerts on Kiro-less workstations either. Bats coverage updated to
  exercise the sentinel mtime semantics.
- `hooks/{session-start,user-prompt-submit}.sh` now resolve every
  `.omao/...` path against `$CLAUDE_PROJECT_DIR` (with `OMA_PROJECT_DIR`
  and `$PWD` as fallbacks) instead of the bare cwd. Claude Code spawns
  hooks from whichever directory `claude` was invoked in, so the
  previous relative-path lookups silently skipped when the cwd
  diverged from the project root. Drift detection, trigger matching,
  active-mode reminder, project-memory loading, ontology status block,
  and the budget warning are all on the new resolution.
- `scripts/lib/permissions.sh` `merge_one`: child template's explicit
  `auto_approve.{read_only,file_writes,bash_commands}: false` now
  overrides a parent's `true`. The previous `(child.k // parent.k)`
  collapsed `false` into the parent value because jq's `//` operator
  treats `false` as a null alternative. New `pick_scalar` helper uses
  `has(k)` so child intent is honored regardless of the literal value.
  Regression caught by `tests/installer/test_permissions_lib.bats`.
- `scripts/install/claude.sh` `detect_claude_version`: trailing
  `| awk '{print $1}' || true` keeps the silent-fallback intent under
  `set -euo pipefail`. Wrapper `claude` binaries (toolbox / asdf /
  similar) that exit non-zero on stale state no longer abort the
  installer. The bug pre-dates this change set but only surfaced
  through the new `tests/installer/test_doctor_permissions.bats`.

## [0.4.0-preview.1] — 2026-05-02

### Breaking
- **Plugin rename: `agentic-platform` → `ai-infra`.** The directory,
  DSL filename, Kiro agent profile filename, marketplace entry, and
  every doc/test reference move. Install IDs change accordingly:
  `/plugin install ai-infra@oh-my-aidlcops`. The broader
  `ai-infra` name signals that this plugin covers the AWS AI
  runtime surface (EKS today; Bedrock / SageMaker runtime skills
  planned). Slash commands (`/oma:platform-bootstrap`) are unchanged.
- **Plugin merge: `aidlc-inception` + `aidlc-construction` → `aidlc`.**
  A single plugin now groups the AIDLC Phase 1 and Phase 2 skills under
  `plugins/aidlc/skills/inception/` and `plugins/aidlc/skills/construction/`.
  Install IDs change to `/plugin install aidlc@oh-my-aidlcops`; the
  two prior ids are retired. `.omao/triggers.json` keeps the
  `inception`, `construction`, and `aidlc-loop` keywords pointing at
  the existing slash commands -- only the `plugin:` attribution flips
  to `aidlc`. Kiro installer now descends into the two skill groups
  and links them as `~/.kiro/skills/aidlc/{inception,construction}/<skill>/`.

### Added
- Landing page (`docs/src/components/HomeLanding`) restructured to a
  pain -> mechanism -> install narrative with a "Problem vs OMA"
  contrast block, a numbered "three mechanisms" strip, a Tier-0
  workflow card grid, a 3-step terminal install section, and an
  inline FAQ accordion. Styles added under the existing `--oma-*`
  token palette; no token files change.
- `docs/docs/intro.md` rewritten to open with project goal, problem,
  approach, and approach mechanism before diving into catalog. Four
  plugins reflected in the catalog; nine Tier-0 commands in the
  workflow table.
- `docs/docs/philosophy-aidlc-meets-agenticops.md` reintegrates
  `modernization` as a brownfield entry path, expands the AgenticOps
  skill table to six (adds `audit-trail`), and replaces the
  unresolved Self-Improving Loop ADR placeholders with canonical
  in-repo pointers.

### Changed
- `scripts/install/kiro.sh` now walks nested skill groups. Skills
  carrying `SKILL.md` at depth 1 keep the flat layout; grouping
  directories (no `SKILL.md` present) descend one more level so the
  merged `aidlc` plugin's inception/construction skills link
  correctly.

### Fixed
- Every doc, test, steering file, install script, eval scenario,
  skill cross-ref, and marketplace entry now uses the new plugin
  ids (`ai-infra`, `aidlc`). Old ids only survive in historical
  CHANGELOG entries for the 0.1.0 / 0.2.0-preview.1 / 0.3.0-preview.1
  releases.

## [0.3.0-preview.1] — 2026-05-01

### Added — v0.5 Plugin migration + enterprise tooling
- `plugins/{agenticops,aidlc-inception,aidlc-construction,modernization}/*.oma.yaml`
  bring every first-party plugin under the harness DSL. Triggers merge
  into `.omao/triggers.json` via `oma compile --all`.
- `oma doctor --enterprise` (`scripts/oma/doctor-enterprise.sh`) runs
  eight probes: ontology-2020-12, slsa-digest, risk-classification,
  audit-jsonl, dsl-version, policies-rego, plugin-dsl, mcp-pinned.
- `oma compile --strict-enterprise` enforces:
  DSL v2 only, `Deployment.approval_chain` non-empty on approved
  deployments, object-form `Deployment.artifact` with `sha256:…` digest,
  and `owasp_llm_top10_id` or `nist_ai_rmf_subcategory` on every `Risk`.
- Per-entity error format (one line per offender with a fix hint)
  under `--strict-enterprise` so CI logs stay parseable.
- `tests/harness/test_plugin_migration.py`, `test_strict_enterprise.py`.
- `docs/docs/enterprise-readiness.md`, `docs/docs/rollback.md`.

### Added — v0.4 SLSA / OTEL / OPA / audit + compliance docs
- `tools/oma_audit/` — validated JSON-L append helper (`append_audit_event`)
  and CLI (`python -m tools.oma_audit.append`). Replaces the
  `echo >> aidlc-docs/audit.md` pattern; dual-write is supported.
- `scripts/oma/migrate-audit.sh` — best-effort converter from legacy
  Markdown append log to `.omao/audit.jsonl`.
- `schemas/ontology/deployment.schema.json` `artifact` now accepts
  either the legacy string or an SLSA v1.1 object
  (`uri/digest/provenance_uri/signing/builder`).
- `schemas/harness/dsl.schema.json` v2 fills in `spec.telemetry`
  (traces/metrics/logs) and `spec.policies[]` (`id/rego_ref/severity/phase`).
- `tools/oma_compile/compile.py` gains `_verify_rego_refs()` — policies
  must point at an existing `.rego` file.
- `scripts/oma/validate.sh` + `oma validate` subcommand: schema + OPA
  shell-out with graceful fallback when `opa` is absent.
- `docs/docs/compliance/{nist-ai-rmf,owasp-llm-top10,slsa-provenance}.md`.
- `policies/examples/deployment-approval.rego` reference policy.

### Added — v0.3b Harness DSL v2
- `schemas/harness/dsl.schema.json`: `version` enum extended to `[1, 2]`;
  v1 files continue to validate unchanged. v2 adds optional
  `metadata.labels/annotations`, `workflows.<name>.steps[]` DAG,
  `telemetry` (body in v0.4), `policies` (body in v0.4).
- `tools/oma_compile/compile.py` adds `_validate_workflows()` — checks
  agent_ref resolves, depends_on stays in-workflow, no cycles, no
  duplicate step ids.
- `allOf[0].if/then` in the DSL schema makes the v2-only keys a
  **hard error** under `version: 1`.
- `tests/harness/test_workflows.py`, `test_compile_roundtrip.py` gains
  `MINI_DSL_V2` proving v1 and v2 compile to byte-equivalent outputs.
- `docs/docs/harness-dsl-v2.md` migration guide.

### Added — v0.3a Enterprise ontology foundation
- `schemas/ontology/spec.schema.json` and `schemas/ontology/adr.schema.json`
  close the Phase 1 traceability gap (`entityRef` enum previously listed
  Spec/ADR without schema files).
- `schemas/common/approval-chain.schema.json` — reusable `$defs.approvalChain`
  shared by Deployment and Incident approval gating.
- `schemas/audit/event.schema.json` — JSON-L audit event record replacing the
  free-form `aidlc-docs/audit.md` surface (migration of skill writers lands
  in v0.4).
- Enterprise optional fields on the existing six schemas:
  - Agent: `mcp_uri`, `model_tier`
  - Skill: `sla_tier`
  - Deployment: `approval_chain`, `risk_exceptions[]`
  - Incident: `approval_chain`, `trace_id`, `span_id`
  - Budget: `cost_center_owner`, `approval_gate`, `exception_expires_at`
  - Risk: `owasp_llm_top10_id`, `nist_ai_rmf_subcategory`,
    `compliance_refs[]`, `deployment_refs[]`
- `pyproject.toml` pins runtime/dev dependencies (`jsonschema>=4.18,<5`,
  `pyyaml>=6.0,<7`, `pytest>=7.4,<9`). `tests/conftest.py` silences the
  jsonschema `RefResolver` DeprecationWarning so CI runs with `-W error`
  stay green until the move to `referencing.Registry` in v0.6+.
- Trigger schema on harness DSL now captures `{id, keywords[],
  context_required[], command, description}`. `tools/oma_compile` emits
  this richer shape directly into `.omao/triggers.json`, aligning with the
  format `hooks/user-prompt-submit.sh` already expected.

### Added — v0.3a existing features
- `oma init` subcommand — scaffolds `.omao/` without the full wizard.
  Users no longer need to remember the install path.
- `oma where` subcommand — prints the OMA install root plus key
  subdirectories (pretty + `--json` modes).

### Changed
- `install/claude.sh` now detects Claude Code major version. On 2.0+ it
  appends a marketplace install hint to the summary explaining that
  symlinks alone do not populate `/plugin list`.
- `oma setup` Next-steps now branches on the detected Claude Code
  version. For 2.0+ it prints the exact `claude <<'MARKET' ... MARKET`
  here-doc that registers the marketplace and installs all five
  plugins.
- All awslabs MCP servers in `agentic-platform.oma.yaml` now carry
  `AWS_REGION: us-east-1` in their env. Previously only two did, which
  caused `aws-knowledge` and `cloudwatch` to fail startup on boto3
  region-resolution errors.
- docs (EN + KO getting-started / claude-code-setup / kiro-setup) use
  `oma init` instead of the raw `bash ~/.oma/scripts/init-omao.sh` path
  so users don't need to know the install location.

### Fixed
- Raw `<oma-repo>` placeholders in docs replaced with concrete commands
  (`oma init`, `oma where`) or the actual `~/.oma` path.

### Added — Follow-up wave (post-merge tooling)
- `refactor(audit)`: migrate `component-design` SKILL.md writer from
  `echo >> aidlc-docs/audit.md` to `python -m tools.oma_audit.append` so
  the JSONL audit log actually gets populated at runtime (PR #6).
- `feat(harness)`: populate the v2 `workflows`, `telemetry`, and
  `policies` blocks on `agentic-platform.oma.yaml` and ship
  `scripts/oma/run-workflow.sh` — a topo-sort stub that prints a DAG
  execution plan (PR #8).
- `feat(oma-validate)`: route validation on entity shape for all eight
  ontology types (Deployment, Incident, Budget, Risk, Agent, Skill,
  Spec, ADR) with Draft-07 and Draft 2020-12 dispatch (PR #7).
- `test(strict-enterprise)`: lift the five user-visible error strings
  emitted by `enforce_strict_enterprise()` into module-level constants
  and snapshot them so accidental wording drift fails CI (PR #5).
- `test(installer)` + `ci(pages)`: enterprise smoke bats covering
  `oma doctor --enterprise` / `oma compile --strict-enterprise` /
  `oma validate`, plus a bump of `actions/upload-pages-artifact` from
  v3 to v4 (PR #9).
- `docs`: expand `CONTRIBUTING.md` with the working-agreement rules
  and ship a public Docusaurus contributing page under Governance
  (PR #10).

### Added — Release pipeline automation
- `/releases` page on GitHub Pages — Docusaurus plugin fetches the
  GitHub Releases API at build time and bakes the response into a
  static page (`docs/plugins/releases-loader/`, `docs/src/pages/releases.tsx`).
- `docs-build.yml` triggers on `release.published / edited / deleted`
  events in addition to `push` to main, so a tag push refreshes Pages
  automatically (PR #3).
- `docs/docs/releases-pipeline.md` documents the tag → release.yml →
  docs-build.yml → deploy-pages chain with a Mermaid diagram and
  rollback procedure.

### Security
- Dependabot alert GHSA-w5hq-g745-h8pq (uuid < 14 buffer bounds check)
  closed by pinning `uuid: ^14.0.0` via npm `overrides` in
  `docs/package.json` (PR #4). Exploit path was not reachable in the
  static-site build pipeline; the pin clears the alert regardless.

## [0.2.0-preview.1] — 2026-04-30

### Added — Ontology + harness foundation
- 6 ontology JSON schemas under `schemas/ontology/` (Agent, Skill, Deployment,
  Incident, Budget, Risk) with cross-entity `$ref` resolution.
- `ontology/README.md` and `ontology/glossary.md` describing the shared
  vocabulary.
- Harness DSL schema `schemas/harness/dsl.schema.json` (v1) with pinned-version
  enforcement and declared-MCP resolution.
- `tools/oma_compile/` compiler that emits `.mcp.json` and
  `kiro-agents/*.agent.json` from a single `<plugin>.oma.yaml` source.
- First DSL migration: `plugins/ai-infra/agentic-platform.oma.yaml`;
  committed native files regenerated and byte-for-byte tested.

### Added — Easy button
- `bin/oma` dispatcher with `setup`, `doctor`, `compile`, `status`,
  `upgrade`, `uninstall`, `help`, `version` subcommands.
- `scripts/oma/setup.sh` wizard (7 questions, non-interactive mode,
  `--dry-run`, `--migrate`, `--skip-install`, `--skip-doctor`).
- `scripts/oma/doctor.sh` with 12 probes and machine-readable JSON report
  (`schemas/doctor/report.schema.json`).
- Profile schema `schemas/profile/profile.schema.json` (v1) + template +
  `scripts/lib/profile.sh` helpers.
- Seed ontology templates under `templates/ontology/` rendered on setup.
- Hook upgrade: `session-start.sh` injects `.omao/ontology/` snapshot;
  `user-prompt-submit.sh` inserts `[MAGIC KEYWORD: OMA_BUDGET_WARN]` when a
  budget exceeds its warn threshold.
- Ontology + Harness Mandate steering (`steering/workflows/ontology-harness-mandate.md`)
  as top-level absolute rules.
- `ontology:` field added to `schemas/skill-frontmatter.schema.json` and to
  7 existing skills (6 agenticops + risk-discovery).

### Added — Docs site
- New pages: Easy Button, Profile, Doctor, Support Policy, Telemetry.
- Sidebar Foundation + Governance categories.
- Navbar Star button.
- Mandatory "Star the repo" final install step on every setup page.

### Added — Release engineering
- `scripts/dev/make-tarball.sh` produces reproducible tarballs excluding
  ephemeral state.
- `install.sh` remote installer with sha256 verification (`curl | bash`
  one-liner).
- `.github/workflows/release.yml` builds + publishes the tarball and
  checksum on every `v*` tag.

### Changed — Repo layout
- `scripts/install-*.sh` → `scripts/install/{claude,kiro,aidlc-extensions}.sh`.
  Old paths retained as shims for backwards compatibility.
- `scripts/{validate,validate_strict,eval-skills,sync-from-playbook}.py`
  → `scripts/dev/`.
- New directories: `scripts/oma/`, `scripts/lib/`, `bin/`, `templates/`,
  `schemas/profile/`, `schemas/doctor/`, `tests/{installer,profile,hooks,doctor}/`.

### Tests
- 22 Python tests (ontology, DSL, compile round-trip, agentic-platform
  specific).
- Bats suites: installer dispatch (9), profile (8 incl. setup E2E),
  doctor (2), hooks (5).
- CI `.github/workflows/oma-foundation.yml` runs Python + bats gates on
  every PR.

### Documentation
- README (EN + KO) updated with 3-line install flow and Tech Preview
  banner.

## [0.1.0] — 2026-04-29

### Added
- Initial marketplace with 5 plugins (agentic-platform, agenticops,
  aidlc-inception, aidlc-construction, modernization).
- AIDLC 3-phase lifecycle plugins + AgenticOps skills.
- AWS Hosted MCP server pins (11 servers).
- Docusaurus documentation site.
- Hardened hooks (safe JSON emission), least-privilege IAM in
  langfuse-observability, simpleeval-based cost-governance expressions.
- MIT-0 license, AWS-samples destination.

[Unreleased]: https://github.com/aws-samples/sample-oh-my-aidlcops/compare/v0.4.0-preview.1...HEAD
[0.4.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.4.0-preview.1
[0.3.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.3.0-preview.1
[0.2.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.2.0-preview.1
[0.1.0]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.1.0
