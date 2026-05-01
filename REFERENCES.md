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
| <a id="nist-ai-rmf"></a>NIST AI Risk Management Framework (AI 100-1) | https://nvlpubs.nist.gov/nistpubs/ai/NIST.AI.100-1.pdf | `Risk.nist_ai_rmf_subcategory`; `AuditEvent.compliance.nist_ai_rmf` |
| <a id="owasp-llm-top-10"></a>OWASP Top 10 for Large Language Model Applications | https://owasp.org/www-project-top-10-for-large-language-model-applications/ | `Risk.owasp_llm_top10_id` (LLM01..LLM10) |
| <a id="json-schema-2020-12"></a>JSON Schema Draft 2020-12 | https://json-schema.org/draft/2020-12/schema | `schemas/ontology/{spec,adr}.schema.json`, `schemas/common/approval-chain.schema.json`, `schemas/audit/event.schema.json` |
| <a id="opentelemetry-semconv"></a>OpenTelemetry Semantic Conventions | https://opentelemetry.io/docs/specs/semconv/ | `Incident.trace_id`, `Incident.span_id`, DSL v2 `spec.telemetry.traces/metrics/logs` |
| <a id="oci-image-spec"></a>OCI Image Spec v1.1 | https://github.com/opencontainers/image-spec/blob/main/spec.md | `Deployment.artifact.digest` sha256 pattern |
| <a id="opa-rego"></a>OPA / Rego | https://www.openpolicyagent.org/docs/latest/ | `spec.policies[].rego_ref`; `scripts/oma/validate.sh` shell-out |
| <a id="cosign"></a>Sigstore cosign | https://docs.sigstore.dev/signing/quickstart/ | `Deployment.artifact.signing.cosign_bundle_uri` |
| <a id="rfc-3339"></a>RFC 3339 (ISO 8601 profile) | https://datatracker.ietf.org/doc/html/rfc3339 | All `*_at` timestamp fields across ontology |
| <a id="keep-a-changelog"></a>Keep a Changelog 1.1 | https://keepachangelog.com/en/1.1.0/ | `CHANGELOG.md` section shape |
| <a id="semver"></a>Semantic Versioning 2.0 | https://semver.org/spec/v2.0.0.html | Git tag naming post-GA |

## Frameworks and methodologies

| Framework | URL | Influence on OMA |
|---|---|---|
| <a id="finops-framework"></a>FinOps Framework | https://www.finops.org/framework/ | `Budget.cost_center_owner`, `Budget.approval_gate`, `Budget.scope` enum |
| <a id="6r"></a>AWS 6R modernization strategy | https://docs.aws.amazon.com/whitepapers/latest/migration-strategy/migration-strategy.html | `Risk.category` enum, `modernization` plugin decision trees |
| <a id="well-architected"></a>AWS Well-Architected Framework | https://docs.aws.amazon.com/wellarchitected/latest/framework/ | `well-architected-security` MCP server + security posture reviews |
| <a id="slsa-framework"></a>SLSA Framework | https://slsa.dev/ | Supply-chain integrity for `Deployment.artifact` |
| <a id="nist-800-53"></a>NIST SP 800-53 Rev. 5 | https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-53r5.pdf | `Risk.compliance_refs[].framework=nist-800-53` |
| <a id="iso-42001"></a>ISO/IEC 42001 | https://www.iso.org/standard/81230.html | `Risk.compliance_refs[].framework=iso-42001` |
| <a id="soc-2"></a>AICPA SOC 2 | https://www.aicpa-cima.com/topic/audit-assurance/audit-and-assurance-greater-than-soc-2 | `Risk.compliance_refs[].framework=soc-2` |
| <a id="mitre-atlas"></a>MITRE ATLAS | https://atlas.mitre.org/ | `Risk.compliance_refs[].framework=mitre-atlas` (attack taxonomy) |

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

## Changelog

Any change to this file belongs in `CHANGELOG.md` under `Changed` or
`Added` as appropriate. When adding a standard or tool, list it here
first; pull requests that introduce a URL without a REFERENCES.md
entry should be asked to move the URL here and link back.
