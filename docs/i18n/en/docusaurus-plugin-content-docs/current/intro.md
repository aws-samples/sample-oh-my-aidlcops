---
title: oh-my-aidlcops
description: A plugin marketplace that automates the entire AIDLC lifecycle with agent-driven operations. A drop-in extension set for platform engineers and Claude Code and Kiro users.
sidebar_position: 1
slug: /intro
---

`oh-my-aidlcops` (OMA) is a **plugin marketplace** that connects all phases of the AIDLC (AI-Driven Development Lifecycle) — Inception → Construction → Operations — through agent-driven operations automation. OMA is a sister project of [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) (OMC), extending the general-purpose Claude Code orchestration philosophy to the AIDLC domain. The core premise is simple — **AIDLC becomes complete only when its operations phase is automated by agents.**

## One-Paragraph Summary

AWS's official [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) systematizes the planning, design, and implementation phases. OMA combines this with an **AgenticOps** layer (self-improving feedback loop, autonomous deployment, continuous evaluation, incident response, and cost governance), enabling the lifecycle to close without manual phase-by-phase execution. Users approve only at checkpoints; agents handle diagnosis, proposal, and execution.

## Plugin Catalog

| Plugin | Role | Example Skills |
|---|---|---|
| `ai-infra` | Build and operate Agentic AI Platform on EKS | `agentic-eks-bootstrap`, `vllm-serving-setup`, `inference-gateway-routing`, `langfuse-observability`, `gpu-resource-management`, `ai-gateway-guardrails` |
| `agenticops` | Agent-driven operations automation | `self-improving-loop`, `autopilot-deploy`, `incident-response`, `continuous-eval`, `cost-governance` |
| `aidlc` | AIDLC Phase 1 extensions (opt-in) | `workspace-detection`, `requirements-analysis`, `user-stories`, `workflow-planning` |
| `aidlc` | AIDLC Phase 2 extensions (opt-in) | `component-design`, `code-generation`, `test-strategy` |

Detailed plugin definitions are in the repository root at [`.claude-plugin/marketplace.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/.claude-plugin/marketplace.json).

## Tier-0 Workflows

Tier-0 workflows are high-leverage operations that start an entire flow with a single invocation and require user approval only at checkpoints.

| Command | Purpose |
|---|---|
| `/oma:autopilot` | Autonomous AIDLC full-loop execution (Inception → Construction → Operations) |
| `/oma:aidlc-loop` | Single feature AIDLC one-pass |
| `/oma:inception` | Phase 1 only |
| `/oma:construction` | Phase 2 only |
| `/oma:agenticops` | Operations mode (continuous-eval + incident-response + cost-governance running in parallel) |
| `/oma:self-improving` | Langfuse traces → skill/prompt improvement PR feedback loop |
| `/oma:platform-bootstrap` | Agentic AI Platform 5-checkpoint bootstrap on EKS |
| `/oma:review` | AIDLC artifact review (ADR, spec, design, PR) |
| `/oma:cancel` | Terminate active Tier-0 mode |

See [Tier-0 Workflows](./tier-0-workflows.md) for detailed invocation of each command.

## AIDLC × AgenticOps Fusion Diagram

```mermaid
flowchart LR
    U[User Request] --> T[Tier-0 Trigger]
    T -->|keyword matching| C["/oma:&lt;workflow&gt;"]
    C --> D[Plugin Dispatch]
    D --> P1[ai-infra]
    D --> P2[agenticops]
    D --> P3[aidlc]
    D --> P4[aidlc]
    P1 --> S[Skill Execution]
    P2 --> S
    P3 --> S
    P4 --> S
    S --> M[AWS Hosted MCP]
    M --> EKS[eks-mcp-server]
    M --> CW[cloudwatch-mcp-server]
    M --> PR[prometheus-mcp-server]
    M --> IAC[aws-iac-mcp-server]
    S --> CK{Checkpoint<br/>User Approval}
    CK -->|approve| OP[Operations Autonomous Execution]
    OP -->|trace feedback| SI[self-improving-loop]
    SI -.improvement PR.-> P4
    SI -.skill tuning.-> P2
```

The diagram above shows how the AIDLC 3-phase structure closes via an agent-driven feedback loop. Observability data from the Operations phase (Langfuse traces, Prometheus metrics, CloudWatch logs) flows back through `self-improving-loop` to automatically improve Construction-phase skills and prompts.

## Supported Harnesses (Dual Harness)

OMA operates identically across two agent harnesses.

- **Claude Code** — Install via native `/plugin marketplace add` or `bash scripts/install/claude.sh` (or `oma setup`). Integrates into `.claude/plugins/`, `.claude/commands/oma/`, and `.claude/settings.json`.
- **Kiro** — Install via `bash scripts/install/kiro.sh` (or select `harness=kiro` in `oma setup`). Symlinks `SKILL.md` to `.kiro/skills/` and steering to `.kiro/steering/`.
- **Shared state** — The `.omao/` directory at project root is harness-agnostic; both harnesses read and write the same files.
- **Recommended path** — Single `oma setup` command handles profile + seed ontology + plugin installation all at once. See [Easy Button](./easy-button.md) for details.

Installation and configuration for each harness are covered in [Claude Code Setup](./claude-code-setup.md) and [Kiro Setup](./kiro-setup.md).

## Target Users

- **Platform engineers** building and operating Agentic AI platforms on AWS EKS
- **LLM and agent operations teams** seeking to cover planning through operations with AIDLC
- **Claude Code or Kiro users** who prefer validated drop-in marketplace plugins over building custom skills

## Reused Assets

OMA follows the principle of reuse over reinvention. Full attribution is documented in [NOTICE](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE).

| Source | License | How Used |
|---|---|---|
| [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) | Apache-2.0 | Plugin, Skill, MCP, and Marketplace JSON schemas adopted |
| [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) | MIT-0 | Used as AIDLC core; contributions are `*.opt-in.md` extensions only |
| [awslabs/mcp](https://github.com/awslabs/mcp) | Apache-2.0 | 11 hosted MCP servers referenced |
| [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills) | MIT-0 | 5-checkpoint workflow template |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | — | Tier-0 orchestration philosophy and `.omc/` state management inherited |

## Next Steps

1. [Getting Started](./getting-started.md) — 5-minute Quickstart to experience your first Tier-0 execution.
2. [Philosophy](./philosophy-aidlc-meets-agenticops.md) — Understand the AIDLC × AgenticOps design premise.
3. [Claude Code Setup](./claude-code-setup.md) or [Kiro Setup](./kiro-setup.md) — Proceed with actual installation.

## Reference Materials

### Official Documentation
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — AIDLC core workflow official repository
- [awslabs/agent-plugins](https://github.com/awslabs/agent-plugins) — Plugin, skill, and marketplace standards
- [awslabs/mcp](https://github.com/awslabs/mcp) — AWS Hosted MCP servers collection

### Related Projects
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — General-purpose Claude Code orchestration (OMA's parent project)
- [oh-my-aidlcops Repository](https://github.com/aws-samples/sample-oh-my-aidlcops) — Source code and issue tracker

### OMA Internal Documentation
- [Getting Started](./getting-started.md) — 5-minute Quickstart
- [Tier-0 Workflows](./tier-0-workflows.md) — Complete command reference
