# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
once GA is reached. During Tech Preview, patch releases may contain
breaking changes to non-stable surfaces as documented in
[`docs/docs/support-policy.md`](./docs/docs/support-policy.md).

## [Unreleased]

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

[Unreleased]: https://github.com/aws-samples/sample-oh-my-aidlcops/compare/v0.3.0-preview.1...HEAD
[0.3.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.3.0-preview.1
[0.2.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.2.0-preview.1
[0.1.0]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.1.0
