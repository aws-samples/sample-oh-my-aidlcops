# References

Every external spec, upstream repo, framework, or authoritative
document OMA depends on or cites. Single source of truth — other files
(README, NOTICE, docs/docs/compliance/\*, CHANGELOG) should link here
rather than re-listing URLs.

**Contribution rule:** before adding a new external reference anywhere
in the repo, add the entry to this file first. If the entry already
exists, link to its anchor (e.g. `[SLSA v1.1](./REFERENCES.md#slsa-v11)`)
instead of re-pasting the raw URL.

**Maintenance rule:** when `.lycheeignore` flags a URL here as dead,
update both this file and the ignore list together. Removing the
ignore entry without updating the reference is how dead links come
back.

## Contents

- [Upstream code we reuse](#upstream-code-we-reuse) — Apache-2.0 /
  MIT / MIT-0 projects whose artefacts OMA consumes directly.
- [Authoritative standards](#authoritative-standards) — specs that
  define the schema shape of OMA ontology fields.
- [Frameworks and methodologies](#frameworks-and-methodologies) —
  governance and lifecycle references that shape OMA's decision trees.
- [Harness engineering](#harness-engineering) — CI, release, and
  supply-chain building blocks that keep the automation honest.
- [AIDLC and AgenticOps references](#aidlc-and-agenticops-references)
  — upstream material for the AIDLC lifecycle and AgenticOps pattern.
- [Tools used at runtime](#tools-used-at-runtime) — binaries and
  libraries the Easy Button expects on `$PATH`.
- [Our own artefacts](#our-own-artefacts) — canonical URLs for this
  repo's releases, pages, and docs.

---

## Upstream code we reuse

| Name | URL | License | Role in OMA |
|---|---|---|---|
| <a id="awslabs-agent-plugins"></a>awslabs/agent-plugins | https://github.com/awslabs/agent-plugins | Apache-2.0 | `plugin`, `skill-frontmatter`, `mcp`, `marketplace` JSON schemas adopted verbatim |
| <a id="awslabs-aidlc-workflows"></a>awslabs/aidlc-workflows | https://github.com/awslabs/aidlc-workflows | MIT-0 | AIDLC core workflow consumed as-is; OMA contributes only `*.opt-in.md` extensions |
| <a id="awslabs-mcp"></a>awslabs/mcp | https://github.com/awslabs/mcp | Apache-2.0 | 11 hosted MCP servers referenced via `uvx` stdio (`eks`, `cloudwatch`, `prometheus`, `bedrock-agentcore`, `bedrock-kb-retrieval`, `sagemaker-ai`, `aws-iac`, `aws-pricing`, `aws-documentation`, `aws-knowledge`, `well-architected-security`) |
| <a id="aws-samples-sample-apex-skills"></a>aws-samples/sample-apex-skills | https://github.com/aws-samples/sample-apex-skills | MIT-0 | Workflow 5-checkpoint template pattern |
| <a id="aws-samples-modernization-kiro"></a>aws-samples/sample-ai-driven-modernization-with-kiro | https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro | MIT-0 | Risk-discovery, audit-trail, quality-gates, and 6R strategy methodology |
| <a id="atom-oh"></a>Atom-oh/oh-my-cloud-skills | https://github.com/Atom-oh/oh-my-cloud-skills | MIT | Eval script patterns and Kiro conversion reference |
| <a id="oh-my-claudecode"></a>oh-my-claudecode (OMC) | https://github.com/Yeachan-Heo/oh-my-claudecode | — | Tier-0 orchestration pattern and `.omc/`→`.omao/` state convention |

Full attribution lives in [NOTICE](./NOTICE); the table above is the
quick-access list for humans.

## Authoritative standards

| Standard | URL | Where it lands in OMA |
|---|---|---|
| <a id="mcp-v10"></a>Model Context Protocol v1.0 | https://modelcontextprotocol.io | `Agent.mcp_uri` on `schemas/ontology/agent.schema.json` |
| <a id="slsa-v11"></a>SLSA v1.1 Provenance | https://slsa.dev/spec/v1.1/ | `Deployment.artifact.{digest,provenance_uri,signing}` |
| <a id="nist-ai-rmf"></a>NIST AI Risk Management Framework (AI 100-1) | https://www.nist.gov/itl/ai-risk-management-framework | `Risk.nist_ai_rmf_subcategory`; `AuditEvent.compliance.nist_ai_rmf` |
| <a id="owasp-llm-top-10"></a>OWASP Top 10 for Large Language Model Applications | https://owasp.org/www-project-top-10-for-large-language-model-applications/ | `Risk.owasp_llm_top10_id` (LLM01..LLM10) |
| <a id="json-schema-2020-12"></a>JSON Schema Draft 2020-12 | https://json-schema.org/draft/2020-12/schema | `schemas/ontology/{spec,adr}.schema.json`, `schemas/common/approval-chain.schema.json`, `schemas/audit/event.schema.json` |
| <a id="opentelemetry-semconv"></a>OpenTelemetry Semantic Conventions | https://opentelemetry.io/docs/specs/semconv/ | `Incident.trace_id`, `Incident.span_id`, DSL v2 `spec.telemetry.traces/metrics/logs` |
| <a id="oci-image-spec"></a>OCI Image Spec v1.1 | https://github.com/opencontainers/image-spec/blob/main/spec.md | `Deployment.artifact.digest` sha256 pattern |
| <a id="opa-rego"></a>OPA / Rego | https://www.openpolicyagent.org/docs/latest/ | `spec.policies[].rego_ref`; `scripts/oma/validate.sh` shell-out |
| <a id="cosign"></a>Sigstore cosign | https://docs.sigstore.dev/quickstart/quickstart-cosign/ | `Deployment.artifact.signing.cosign_bundle_uri` |
| <a id="rfc-3339"></a>RFC 3339 (ISO 8601 profile) | https://datatracker.ietf.org/doc/html/rfc3339 | All `*_at` timestamp fields across ontology |
| <a id="keep-a-changelog"></a>Keep a Changelog 1.1 | https://keepachangelog.com/en/1.1.0/ | `CHANGELOG.md` section shape |
| <a id="semver"></a>Semantic Versioning 2.0 | https://semver.org/spec/v2.0.0.html | Git tag naming post-GA |
| <a id="nygard-adr"></a>Michael Nygard, "Documenting Architecture Decisions" (2011) | https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions | `schemas/ontology/adr.schema.json` field set (`context` / `decision` / `consequences`) and 5-state status machine trace directly to this post |
| <a id="adr-github-io"></a>adr.github.io (community ADR hub) | https://adr.github.io/ | Template catalogue and tool ecosystem; OMA follows the MADR slug convention from this hub |
| <a id="madr"></a>MADR — Markdown Any Decision Records | https://adr.github.io/madr/ | `adr-NNNN-<slug>` id format and file-naming convention for `.omao/plans/adr/*.md` |
| <a id="ieee-830"></a>IEEE Std 830-1998 (Software Requirements Specifications) | https://standards.ieee.org/ieee/830/1222/ | `schemas/ontology/spec.schema.json` `requirements[]` shape (id / text / MoSCoW priority) follows the IEEE 830 shall/should/may layering; superseded by ISO/IEC/IEEE 29148 but widely cited |
| <a id="ieee-29148"></a>ISO/IEC/IEEE 29148-2018 (successor to IEEE 830) | https://www.iso.org/standard/72089.html | Modern restatement of the requirements template referenced by Spec entity |

## Frameworks and methodologies

| Framework | URL | Influence on OMA |
|---|---|---|
| <a id="finops-framework"></a>FinOps Framework | https://www.finops.org/framework/ | `Budget.cost_center_owner`, `Budget.approval_gate`, `Budget.scope` enum |
| <a id="6r"></a>AWS 6R modernization strategy | https://aws.amazon.com/cloud-migration/ | `Risk.category` enum, `modernization` plugin decision trees |
| <a id="well-architected"></a>AWS Well-Architected Framework | https://docs.aws.amazon.com/wellarchitected/latest/framework/ | `well-architected-security` MCP server + security posture reviews |
| <a id="slsa-framework"></a>SLSA Framework | https://slsa.dev/ | Supply-chain integrity for `Deployment.artifact` |
| <a id="nist-800-53"></a>NIST SP 800-53 Rev. 5 | https://csrc.nist.gov/pubs/sp/800/53/r5/upd1/final | `Risk.compliance_refs[].framework=nist-800-53` |
| <a id="iso-42001"></a>ISO/IEC 42001 | https://www.iso.org/standard/81230.html | `Risk.compliance_refs[].framework=iso-42001` |
| <a id="soc-2"></a>AICPA SOC 2 | https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2 | `Risk.compliance_refs[].framework=soc-2` |
| <a id="mitre-atlas"></a>MITRE ATLAS | https://atlas.mitre.org/ | `Risk.compliance_refs[].framework=mitre-atlas` (attack taxonomy) |
| <a id="claude-code"></a>Claude Code (Anthropic) | https://docs.anthropic.com/en/docs/claude-code/overview | Primary agent harness that loads OMA plugins; trigger + hook contracts follow Claude Code docs |

## Harness engineering

| Reference | URL | Where it lands in OMA |
|---|---|---|
| <a id="gh-actions-workflow-syntax"></a>GitHub Actions workflow syntax | https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions | Every `.github/workflows/*.yml` structure |
| <a id="gh-actions-reusable"></a>GitHub Actions reusable workflows | https://docs.github.com/en/actions/using-workflows/reusing-workflows | Future refactor target to dedupe `foundation` and `release` test jobs |
| <a id="gh-actions-release-cycle"></a>GitHub Actions release-event triggers | https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#release | `docs-build.yml` rebuild on `release: {published,edited,deleted}` |
| <a id="gh-actions-deprecation-node20"></a>GitHub Actions Node 20 deprecation notice (2026-09-16) | https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/ | Drove the `actions/checkout@v4 → v5` bump (PR #18) |
| <a id="conventional-commits"></a>Conventional Commits 1.0 | https://www.conventionalcommits.org/en/v1.0.0/ | `CONTRIBUTING.md` commit-message style (`feat:` / `fix:` / `chore:` / `docs:`) |
| <a id="sigstore"></a>Sigstore project overview | https://www.sigstore.dev/ | Background for `Deployment.artifact.signing` (cosign bundle URI) |
| <a id="oci-distribution"></a>OCI Distribution Spec | https://github.com/opencontainers/distribution-spec | Registry behaviour for artifact pulls referenced by `Deployment.artifact.uri` |
| <a id="slsa-generator"></a>SLSA Generator (GitHub Action) | https://github.com/slsa-framework/slsa-github-generator | Reference implementation for generating `artifact.provenance_uri` in CI |

## AIDLC and AgenticOps references

| Reference | URL | Why it is here |
|---|---|---|
| <a id="awslabs-agent-plugins-readme"></a>awslabs/agent-plugins README (governance model) | https://github.com/awslabs/agent-plugins/blob/main/README.md | Canonical definition of the plugin / skill / marketplace contract OMA adopts |
| <a id="awslabs-aidlc-workflows-readme"></a>awslabs/aidlc-workflows README | https://github.com/awslabs/aidlc-workflows/blob/main/README.md | AIDLC 3-phase loop definition OMA extends via `*.opt-in.md` files |
| <a id="aws-well-arch-genai-lens"></a>AWS Well-Architected Generative AI Lens | https://docs.aws.amazon.com/wellarchitected/latest/generative-ai-lens/generative-ai-lens.html | Design review checklist OMA's `ai-infra` plugin aligns with |
| <a id="aws-agentic-ai-blog"></a>AWS blog — Build an agentic AI assistant on AWS (reference architecture) | https://aws.amazon.com/blogs/machine-learning/ | General entry point; individual posts rotate — follow the blog index rather than pin a single URL |
| <a id="aws-modernization"></a>AWS Cloud Migration landing (was aws.amazon.com/modernization/) | https://aws.amazon.com/cloud-migration/ | Updated canonical URL after the modernization alias was retired; used by `plugins/modernization` |

## Tools used at runtime

| Tool | URL | Purpose |
|---|---|---|
| <a id="uvx"></a>uv / uvx | https://docs.astral.sh/uv/ | Runs every awslabs MCP server stdio-style without ambient pip installs |
| <a id="jq"></a>jq | https://jqlang.github.io/jq/ | Hook scripts, `.omao/triggers.json` parsing, `oma doctor --json` |
| <a id="bats"></a>bats-core | https://bats-core.readthedocs.io/ | Shell test harness (`tests/installer`, `tests/profile`, `tests/hooks`, `tests/doctor`) |
| <a id="jsonschema"></a>python-jsonschema | https://python-jsonschema.readthedocs.io/ | Schema validation in `tools/oma_compile/`, `tools/oma_audit/`, `scripts/dev/validate.py` |
| <a id="pyyaml"></a>PyYAML | https://pyyaml.org/wiki/PyYAMLDocumentation | DSL parsing |
| <a id="simpleeval"></a>simpleeval | https://pypi.org/project/simpleeval/ | Sandboxed `Budget.rule_expression` evaluator |
| <a id="docusaurus"></a>Docusaurus | https://docusaurus.io/ | `docs/` site generator |
| <a id="lychee"></a>lycheeverse/lychee-action | https://github.com/lycheeverse/lychee-action | Link-check CI (see `.github/workflows/link-check.yml` and `.lycheeignore`) |
| <a id="opa-tool"></a>OPA binary | https://www.openpolicyagent.org/docs/latest/#running-opa | `scripts/oma/validate.sh` policy evaluation shell-out |
| <a id="mermaid"></a>Mermaid | https://mermaid.js.org/ | Flow diagrams in docs (`theme-mermaid` plugin) |
| <a id="hypothesis"></a>Hypothesis (property-based testing) | https://hypothesis.readthedocs.io/ | Referenced by `plugins/aidlc` agentic TDD rules; property-based invariant generator |
| <a id="kiro"></a>Kiro | https://kiro.dev/ | Secondary agent harness alongside Claude Code; `scripts/install/kiro.sh` target |
| <a id="gh-cli"></a>GitHub CLI (`gh`) | https://cli.github.com/ | Release create, PR open, workflow dispatch across release pipeline |

## Our own artefacts

| Artefact | URL |
|---|---|
| Source repository | https://github.com/aws-samples/sample-oh-my-aidlcops |
| Docusaurus site | https://aws-samples.github.io/sample-oh-my-aidlcops/ |
| Release list (Pages) | https://aws-samples.github.io/sample-oh-my-aidlcops/releases |
| GitHub Releases | https://github.com/aws-samples/sample-oh-my-aidlcops/releases |
| Issue tracker | https://github.com/aws-samples/sample-oh-my-aidlcops/issues |
| Install one-liner (current tag) | https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.3.0-preview.1/install.sh |

Programmatic references also exist inline in each skill / plugin; this
file intentionally only captures the **external** surface.

## Verification

`scripts/dev/check-references.py` walks this file once per week
(via `.github/workflows/references-check.yml`) and issues `HEAD` /
`GET` against every `https://` URL. Failures fail the workflow; the
next PR either fixes the URL or moves the entry to `.lycheeignore`
with a dated reason.

_Last reviewed: 2026-05-01_

## Changelog

Any change to this file belongs in `CHANGELOG.md` under `Changed` or
`Added` as appropriate. When adding a standard or tool, list it here
first; pull requests that introduce a URL without a REFERENCES.md
entry should be asked to move the URL here and link back.
