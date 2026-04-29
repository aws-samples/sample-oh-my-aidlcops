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

### Claude Code (native marketplace)

```bash
claude
> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
> /plugin install agentic-platform agenticops aidlc-inception aidlc-construction modernization
```

### Claude Code (manual)

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install-claude.sh
```

### Kiro

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash sample-oh-my-aidlcops/scripts/install-kiro.sh
```

### Initialize `.omao/` in your project

```bash
cd <your-project>
bash <path-to-oma>/scripts/init-omao.sh
```

### AIDLC extensions (opt-in)

```bash
bash scripts/install-aidlc.sh
# Clones awslabs/aidlc-workflows into ~/.aidlc and symlinks OMA's opt-in extensions.
```

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

OMA is in Phase 1 MVP. See [CONTRIBUTING.md](./CONTRIBUTING.md) for the bug
report and pull request process, and [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)
for the Amazon Open Source Code of Conduct. Issues and PRs are especially
welcome for skill quality, MCP coverage gaps, and Kiro compatibility testing.

For security issues, do **not** open a public GitHub issue — follow the AWS
[vulnerability reporting process](https://aws.amazon.com/security/vulnerability-reporting/)
instead.
