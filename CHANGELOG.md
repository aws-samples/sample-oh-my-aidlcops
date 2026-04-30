# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
once GA is reached. During Tech Preview, patch releases may contain
breaking changes to non-stable surfaces as documented in
[`docs/docs/support-policy.md`](./docs/docs/support-policy.md).

## [Unreleased]

### Added
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
- First DSL migration: `plugins/agentic-platform/agentic-platform.oma.yaml`;
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

[Unreleased]: https://github.com/aws-samples/sample-oh-my-aidlcops/compare/v0.2.0-preview.1...HEAD
[0.2.0-preview.1]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.2.0-preview.1
[0.1.0]: https://github.com/aws-samples/sample-oh-my-aidlcops/releases/tag/v0.1.0
