# oh-my-aidlcops (OMA) — AIDLC × AgenticOps Marketplace

You are running with **oh-my-aidlcops (OMA)**, a plugin marketplace that brings
agent-driven operations automation to the AIDLC (AI-Driven Development Lifecycle).

OMA is the sibling project of [oh-my-claudecode (OMC)](https://github.com/Atom-oh/oh-my-claudecode),
extending the same orchestration philosophy to the full AIDLC loop:
**Inception → Construction → Operations**.

The core thesis: AIDLC becomes complete when it meets AgenticOps. Humans approve,
agents execute.

<operating_principles>
- AIDLC 3-phase lifecycle (Inception / Construction / Operations) is the primary unit of work.
- Operations phase is agent-automated by default — humans approve, not execute.
- Delegate specialized work to the appropriate OMA plugin.
- engineering-playbook docs are the canonical knowledge source; skills carry summaries and links, not copies.
- AWS Hosted MCP (awslabs/mcp) is the default runtime data layer — no custom MCP servers until a clear gap is observed.
</operating_principles>

<plugin_catalog>
agentic-platform    — Build the Agentic AI Platform on EKS (vLLM, Inference Gateway, Langfuse, Kagent)
agenticops          — Operate it with agents (self-improving loop, autonomous deploy, continuous eval, incident response, cost governance)
aidlc-inception     — AIDLC Phase 1 opt-in extensions (requirements, stories, workflow planning)
aidlc-construction  — AIDLC Phase 2 opt-in extensions (component design, codegen, TDD for agentic systems)
</plugin_catalog>

<tier_0_workflows>
/oma:autopilot           — AIDLC full-loop autopilot (Inception→Construction→Operations, checkpoint approvals only)
/oma:aidlc-loop          — Single feature AIDLC one-pass
/oma:inception           — Phase 1 only
/oma:construction        — Phase 2 only
/oma:agenticops          — Operations mode (continuous-eval + incident-response + cost-governance active)
/oma:self-improving      — Feedback loop runner (Langfuse traces → skill/prompt improvement PR)
/oma:platform-bootstrap  — Agentic AI Platform 5-checkpoint bootstrap on EKS
/oma:review              — AIDLC artifact review (ADR, spec, design, PR)
/oma:cancel              — Terminate active Tier-0 mode
</tier_0_workflows>

<keyword_triggers>
"autopilot" (in AIDLC context)          → /oma:autopilot
"agenticops", "ops-mode"                → /oma:agenticops
"self-improving", "feedback-loop"       → /oma:self-improving
"aidlc" (single feature)                → /oma:aidlc-loop
"eks-agentic", "platform-bootstrap"     → /oma:platform-bootstrap
"inception"                             → /oma:inception
"construction"                          → /oma:construction
</keyword_triggers>

<execution_protocols>
- AIDLC phase gates are non-negotiable — do not skip Inception artifacts before Construction, do not skip Construction gates before Operations.
- Operations phase keeps humans in the loop only at approve/reject checkpoints; agents handle diagnosis, proposal drafting, and execution attempts.
- Before recommending a command, verify the plugin is installed (check `.claude/plugins/` or `.kiro/skills/`).
- When engineering-playbook docs are referenced, prefer linking over copying. Skills carry distilled references, not full document bodies.
</execution_protocols>

<state_and_context>
.omao/plans/         — AIDLC artifacts (spec, design, ADR, user stories)
.omao/state/         — Session checkpoints, in-flight Tier-0 mode
.omao/notepad.md     — Working memo
.omao/triggers.json  — Keyword trigger catalog (sourced by SessionStart hook)
.omao/project-memory.json — Project-level durable facts
</state_and_context>

<dual_harness>
- **Claude Code**: Use native `/plugin marketplace add` or `scripts/install-claude.sh`.
- **Kiro**: Use `scripts/install-kiro.sh` — symlinks SKILL.md into `.kiro/skills/` and steering into `.kiro/steering/`.
- **Shared state**: `.omao/` is harness-agnostic. Both harnesses read/write the same directory.
</dual_harness>

<reused_assets>
OMA deliberately avoids reinventing existing standards:
- Plugin / skill / marketplace / mcp JSON schemas — adopted from **awslabs/agent-plugins** (Apache-2.0).
- AIDLC core workflow — consumed from **awslabs/aidlc-workflows** (MIT-0). OMA contributes only `*.opt-in.md` extensions.
- MCP runtime servers — 11 services from **awslabs/mcp** (Apache-2.0), referenced via `uvx` stdio only.
- Workflow 5-checkpoint template — adapted from **aws-samples/sample-apex-skills** (MIT-0).
- Eval and Kiro-conversion patterns — referenced from **Atom-oh/oh-my-cloud-skills** (MIT).
- Orchestration philosophy (Tier-0, keyword triggers, `.omc/` state) — inherited from **oh-my-claudecode**.
See NOTICE for full attribution.
</reused_assets>

## Setup

```bash
# Claude Code (native marketplace)
claude
> /plugin marketplace add https://github.com/devfloor9/oh-my-aidlcops
> /plugin install agentic-platform agenticops aidlc-inception aidlc-construction

# Manual install (Claude Code)
bash scripts/install-claude.sh

# Kiro
bash scripts/install-kiro.sh

# Initialize .omao/ in a user project
cd <your-project>
bash <oma-repo>/scripts/init-omao.sh
```
