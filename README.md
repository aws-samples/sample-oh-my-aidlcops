# sample-oh-my-aidlcops

**AIDLC × AgenticOps** — a plugin marketplace that automates the full AI-Driven
Development Lifecycle with agent-based operations on AWS.

[한국어 README](./README.ko.md) · [Documentation](./docs/) · [Plugins](./plugins/) · [Steering](./steering/)

---

## What is OMA?

`oh-my-aidlcops` (OMA) is the sibling project of
[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) (OMC).
Where OMC orchestrates generic Claude Code workflows, OMA specializes in the
**AIDLC loop**: Inception → Construction → Operations.

The thesis: AIDLC is complete only when operations are agent-automated. OMA
fuses the AWS-official [AIDLC workflows](https://github.com/awslabs/aidlc-workflows)
with an **AgenticOps** layer (self-improving feedback loops, autonomous deploys,
continuous evaluation, incident response, cost governance) so the lifecycle
closes itself without human execution at every step.

## Who is this for?

- Platform engineers building agentic AI on AWS EKS.
- Teams running LLM/agent workloads who want AIDLC to cover *operations*, not
  just design and construction.
- Teams modernizing legacy workloads onto AWS using a repeatable 6R workflow.
- Claude Code or Kiro users who want a drop-in marketplace rather than
  hand-rolling skills.

## Plugins

| Plugin | What it does | Example skills |
|---|---|---|
| **`agentic-platform`** | Build & run the Agentic AI Platform on EKS | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| **`agenticops`** | Operate it with agents | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance`, `audit-trail` |
| **`aidlc-inception`** | AIDLC Phase 1 extensions | `structured-intake`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| **`aidlc-construction`** | AIDLC Phase 2 extensions | `component-design`, `code-generation`, `test-strategy`, `risk-discovery`, `quality-gates` |
| **`modernization`** | Legacy workload modernization to AWS (6R strategy) | `workload-assessment`, `modernization-strategy`, `to-be-architecture`, `containerization`, `cutover-planning` |

## Tier-0 workflows

OMA inherits the Tier-0 pattern from OMC — high-leverage workflows you invoke
once and let run, with human approval only at checkpoints.

| Command | Purpose |
|---|---|
| `/oma:autopilot` | Full AIDLC loop autopilot (Inception → Construction → Operations) |
| `/oma:aidlc-loop` | Single-feature AIDLC one-pass |
| `/oma:agenticops` | Operations mode (continuous-eval + incident-response + cost-governance) |
| `/oma:self-improving` | Feedback loop — Langfuse traces to skill/prompt improvement PR |
| `/oma:platform-bootstrap` | 5-checkpoint Agentic AI Platform build on EKS |
| `/oma:modernize` | Legacy workload modernization (6R decision → cutover) |
| `/oma:review` | AIDLC artifact review (ADR, spec, design, PR) |
| `/oma:cancel` | Terminate active Tier-0 mode |

## Install

### ⚡ One-liner (Tech Preview — recommended)

`install.sh` downloads the pinned release tarball, extracts to `~/.oma`, and
symlinks `~/.local/bin/oma`. `oma setup` then writes a project profile,
seeds the ontology, installs the plugins, and runs `oma doctor` to confirm
the environment.

```bash
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.2.0-preview.1/install.sh | bash
cd my-project
oma setup
oma doctor
```

See the [Easy Button docs](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/easy-button)
for what `oma setup` writes, how the 12 doctor probes work, and how the
ontology + harness DSL get enforced at runtime.

> **Tech Preview notice** — `v0.2.0-preview.1` stabilizes `profile.yaml` v1
> and the 6 ontology schemas. Everything else (CLI UX, DSL fields, doctor
> report shape) may evolve before GA. See [Support Policy](https://aws-samples.github.io/sample-oh-my-aidlcops/docs/support-policy).

### Claude Code (native marketplace — Claude Code 2.0+)

```bash
claude
```

Inside the Claude Code session:

```text
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install agentic-platform@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc-inception@oh-my-aidlcops
/plugin install aidlc-construction@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
```

> `/plugin install` accepts a single plugin id per invocation. Pasting the
> six lines above lets Claude Code run them sequentially. For a shell
> one-liner, use `claude <<'EOF' ... EOF` to feed the commands via stdin.

### Claude Code (manual script — legacy / MCP-only)

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install/claude.sh
```

> The manual script creates `~/.claude/plugins/` symlinks and merges MCP
> servers + hooks into `settings.json`. **On Claude Code 2.0+ this alone
> does NOT register plugins with `/plugin list`.** Use it only for
> legacy 1.x environments, offline CI, or when you want to wire MCP
> servers without activating the marketplace.

### Kiro

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install/kiro.sh
```

### Initialize `.omao/` in your project

```bash
cd <your-project>
bash <path-to-oma>/scripts/init-omao.sh
```

### AIDLC extensions (opt-in)

```bash
bash scripts/install/aidlc-extensions.sh
# Clones awslabs/aidlc-workflows into ~/.aidlc and symlinks OMA's opt-in extensions.
```

### Liked it? Give the repo a Star

If OMA was useful, a ⭐ on the [GitHub repository](https://github.com/aws-samples/sample-oh-my-aidlcops)
helps us prioritize maintenance and keeps release notifications flowing
to you. It is entirely optional — nothing in the CLI changes based on
your star status.

## Architecture

```
User request
    │
    ▼
Tier-0 trigger  ─── matches keyword? ──▶ /oma:<workflow>
    │
    ▼
Plugin dispatch
    │
    ├─▶ agentic-platform    (build)
    ├─▶ agenticops          (operate)
    ├─▶ aidlc-inception     (Phase 1)
    ├─▶ aidlc-construction  (Phase 2)
    └─▶ modernization       (legacy → AWS)
    │
    ▼
Skills execute, calling AWS Hosted MCP
    │
    ├─▶ eks, cloudwatch, prometheus, aws-iac, cost-explorer, ...
    │
    ▼
Checkpoint — human approves
    │
    ▼
Operations phase continues autonomously
    │
    └─▶ self-improving-loop feeds corrections back to Construction
```

## Foundation: ontology + harness DSL

OMA plugins rest on two shared layers:

1. **Ontology** (`ontology/`, `schemas/ontology/`) — six JSON Schemas that
   define the vocabulary every plugin and skill agrees on: `Agent`, `Skill`,
   `Deployment`, `Incident`, `Budget`, `Risk`. A handoff between Construction
   and Operations is no longer a prose description; it is a validated
   `Deployment` document. See [ontology/README.md](./ontology/README.md) and
   [ontology/glossary.md](./ontology/glossary.md).
2. **Harness DSL** (`schemas/harness/dsl.schema.json`, `tools/oma_compile/`) —
   one `<plugin>.oma.yaml` per plugin is the single source of agents, MCP
   servers, hooks, and triggers. `python -m tools.oma_compile` translates it
   to the native `.mcp.json` and `kiro-agents/*.agent.json` files that Claude
   Code and Kiro already consume, so marketplace installs stay unchanged.

```
<plugin>.oma.yaml  ──(oma-compile)──▶  .mcp.json
                                   ▶  kiro-agents/<agent>.agent.json
                                   ▶  .omao/triggers.json  (merged across plugins)
```

CI (`.github/workflows/oma-foundation.yml`) validates every schema fixture and
runs `oma-compile --check` to reject drift between DSL sources and committed
native files.

## Security posture

This repository ships with conservative defaults. A few things are worth
calling out before you use it in production:

- **MCP servers are pinned** to exact PyPI versions in every `.mcp.json` and
  `kiro-agents/*.agent.json`. `@latest` is not used anywhere — a compromised
  upstream release cannot silently land alongside AWS credentials.
- **EKS MCP is read-only by default.** The bundled Kiro agent profile does
  *not* pass `--allow-write` or `--allow-sensitive-data-access` to
  `awslabs.eks-mcp-server`. Add them explicitly when you need to provision
  or mutate EKS resources, and audit that change.
- **IAM is least-privilege.** The `langfuse-observability` skill uses a
  customer-managed policy scoped to the Langfuse bucket ARN; AWS managed
  `AmazonS3FullAccess` (`s3:*` account-wide) is explicitly rejected with a
  "Bad Example" block in the skill.
- **`budget.yaml` expressions are sandboxed.** The `cost-governance` skill
  evaluates `rule["when"]` via [`simpleeval`](https://pypi.org/project/simpleeval/)
  (AST walker, zero builtins, zero callables). A documented Bad Example shows
  why Python `eval()` on a user-editable file is an RCE vector.
- **Session state stays local.** `.omao/state/`, `.omao/plans/`, `.omao/logs/`,
  `.omao/notepad.md`, and `.omao/project-memory.json` are gitignored —
  `audit-trail` captures prompts verbatim (PII, approver identity, SOC2
  retention content) and must never leave the machine.
- **Hooks require a real JSON encoder.** `hooks/session-start.sh` uses `jq`
  (with `python3` / `python` as ordered fallbacks) and exits non-zero rather
  than emitting shell-interpolated JSON, preventing state-file injection into
  the session context.

## Reused assets

OMA stands on top of existing AWS and community work rather than reinventing.

| Source | License | How OMA uses it |
|---|---|---|
| [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) | Apache-2.0 | Adopts `plugin`, `skill-frontmatter`, `mcp`, `marketplace` JSON schemas. |
| [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | MIT-0 | Consumed as AIDLC core; OMA contributes only `*.opt-in.md` extensions. |
| [awslabs/mcp](https://github.com/awslabs/mcp) | Apache-2.0 | 11 hosted MCP servers referenced via `uvx` stdio. |
| [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) | MIT-0 | Workflow 5-checkpoint template pattern. |
| [aws-samples/sample-ai-driven-modernization-with-kiro](https://github.com/aws-samples/sample-ai-driven-modernization-with-kiro) | MIT-0 | Risk-discovery, audit-trail, quality-gates, 6R strategy methodology. |
| [Atom-oh/oh-my-cloud-skills](https://github.com/Atom-oh/oh-my-cloud-skills) | MIT | Eval script patterns, Kiro conversion reference. |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | — | Tier-0 orchestration and `.omc/` state inheritance. |

Full attribution in [NOTICE](./NOTICE).

## License

MIT No Attribution (MIT-0). See [LICENSE](./LICENSE).

## Contributing

OMA is in Tech Preview (`v0.2.0-preview.1`). See [CONTRIBUTING.md](./CONTRIBUTING.md) for the bug
report and pull request process, and [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
for the Amazon Open Source Code of Conduct. Issues and PRs are especially
welcome for skill quality, MCP coverage gaps, and Kiro compatibility testing.

For security issues, do **not** open a public GitHub issue — follow the AWS
[vulnerability reporting process](https://aws.amazon.com/security/vulnerability-reporting/)
instead.
