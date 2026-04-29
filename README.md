# oh-my-aidlcops

**AIDLC × AgenticOps** — a plugin marketplace that automates the full AI-Driven
Development Lifecycle with agent-based operations on AWS.

[한국어 README](./README.ko.md) · [Documentation](./docs/) · [Plugins](./plugins/) · [Steering](./steering/)

---

## What is OMA?

`oh-my-aidlcops` (OMA) is the sibling project of
[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) (OMC). Where OMC
orchestrates generic Claude Code workflows, OMA specializes in the **AIDLC
loop**: Inception → Construction → Operations.

The thesis: AIDLC is complete only when operations are agent-automated. OMA
fuses the AWS-official [AIDLC workflows](https://github.com/awslabs/aidlc-workflows)
with an **AgenticOps** layer (self-improving feedback loops, autonomous deploys,
continuous evaluation, incident response, cost governance) so the lifecycle
closes itself without human execution at every step.

## Who is this for?

- Platform engineers building agentic AI on AWS EKS.
- Teams running LLM/agent workloads who want AIDLC to cover *operations*, not
  just design and construction.
- Claude Code or Kiro users who want a drop-in marketplace rather than hand-rolling
  skills.

## Plugins

| Plugin | What it does | Example skills |
|---|---|---|
| **`agentic-platform`** | Build & run the Agentic AI Platform on EKS | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| **`agenticops`** | Operate it with agents | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance` |
| **`aidlc-inception`** | AIDLC Phase 1 extensions | `workspace-detection`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| **`aidlc-construction`** | AIDLC Phase 2 extensions | `component-design`, `code-generation`, `test-strategy` |

## Tier-0 workflows

OMA inherits the Tier-0 pattern from OMC — high-leverage workflows you invoke
once and let run, with human approval only at checkpoints.

| Command | Purpose |
|---|---|
| `/oma:autopilot` | Full AIDLC loop autopilot |
| `/oma:aidlc-loop` | Single-feature AIDLC one-pass |
| `/oma:agenticops` | Operations mode (continuous eval + incident response + cost governance) |
| `/oma:self-improving` | Feedback loop — Langfuse traces to skill/prompt improvement PR |
| `/oma:platform-bootstrap` | 5-checkpoint Agentic AI Platform build on EKS |

Full command list in [CLAUDE.md](./CLAUDE.md).

## Install

### Claude Code (native marketplace)

```bash
claude
> /plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
> /plugin install agentic-platform agenticops aidlc-inception aidlc-construction
```

### Claude Code (manual)

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash oh-my-aidlcops/scripts/install-claude.sh
```

### Kiro

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
bash oh-my-aidlcops/scripts/install-kiro.sh
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
    └─▶ aidlc-construction  (Phase 2)
    │
    ▼
Skills execute, calling AWS Hosted MCP
    │
    ├─▶ eks, cloudwatch, prometheus, aws-iac, ...
    │
    ▼
Checkpoint — human approves
    │
    ▼
Operations phase continues autonomously
    │
    └─▶ self-improving-loop feeds corrections back to Construction
```

## Reused assets

OMA stands on top of existing AWS and community work rather than reinventing.

| Source | License | How OMA uses it |
|---|---|---|
| [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) | Apache-2.0 | Adopts `plugin`, `skill-frontmatter`, `mcp`, `marketplace` JSON schemas. |
| [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | MIT-0 | Consumed as AIDLC core; OMA contributes only `*.opt-in.md` extensions. |
| [awslabs/mcp](https://github.com/awslabs/mcp) | Apache-2.0 | 11 hosted MCP servers referenced via `uvx` stdio. |
| [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) | MIT-0 | Workflow 5-checkpoint template pattern. |
| [Atom-oh/oh-my-cloud-skills](https://github.com/Atom-oh/oh-my-cloud-skills) | MIT | Eval script patterns, Kiro conversion reference. |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | — | Tier-0 orchestration and `.omc/` state inheritance. |

Full attribution in [NOTICE](./NOTICE).

## License

Apache-2.0. See [LICENSE](./LICENSE).

## Contributing

OMA is in Phase 1 MVP. Issues and PRs welcome — especially for skill quality,
MCP coverage gaps, and Kiro compatibility testing.
