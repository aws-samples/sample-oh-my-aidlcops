---
title: Getting Started
description: OMA 5-minute Quickstart. From marketplace installation through first /oma:autopilot execution to checkpoint approval—the entire flow in the shortest path.
sidebar_position: 2
---

This document is a 5-minute Quickstart for users new to `oh-my-aidlcops` (OMA). We describe the Claude Code environment, though Kiro follows the same flow (invoking skills directly via `.kiro/skills/` symlinks rather than slash commands). See [Kiro Setup](./kiro-setup.md) for Kiro-specific steps.

## Prerequisites

| Item | Version | Notes |
|---|---|---|
| Claude Code CLI | latest stable | `claude --version` |
| jq | 1.6+ | Installation scripts use it for JSON merging |
| bash | 4+ | macOS default 3.2 is outdated; run `brew install bash` |
| AWS credentials | — | `ai-infra` workflows require EKS, CloudWatch, and S3 access |
| (Optional) Kubernetes CLI | kubectl v1.32+ | Needed for `platform-bootstrap` |

## Optional: Install the `oma` CLI (for AgenticOps)

OMA ships **three installation scripts** that serve different layers.
Understand them first:

| Script | Effects | Required on Claude Code 2.0+? |
|---|---|---|
| **`install.sh`** (remote one-liner) | Unpacks CLI into `~/.oma/`, symlinks `~/.local/bin/oma`. **Does not touch `~/.claude/`** | Optional — only if you want the `oma` CLI |
| **`oma setup`** | Writes `.omao/profile.yaml` + seed ontology; internally also runs `install/claude.sh` to merge MCP/hooks into `settings.json` | Optional — needed only for AgenticOps |
| **`scripts/install/claude.sh`** | Creates `~/.claude/plugins/` symlinks + merges MCP/hooks into `settings.json` (Claude Code 1.x path) | ❌ **Alone, it does NOT appear in `/plugin list`** |
| **`/plugin marketplace add` + `install`** | Native Claude Code registration (`~/.claude/installed_plugins.json`) | ✅ **Mandatory** |

So on Claude Code 2.0+ the **native marketplace flow (Step 1 below) is
required**, and `oma setup` is only needed **when you plan to use AgenticOps**.

```bash
# Install the OMA CLI (only if you plan to use AgenticOps)
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.4.0-preview.1/install.sh | bash
cd my-project
oma setup      # writes .omao/profile.yaml + seed ontology
oma doctor     # environment probes
```

> Press ENTER at every prompt to accept defaults.
> In CI, set `OMA_NON_INTERACTIVE=1` with env flags for unattended install.
> Step 1 below is independent — it works even if `oma setup` was skipped.

### AWS credentials must be configured separately

The AWS account id and region that `oma setup` asks for are **metadata
only** — a record of which account this project targets. Actual AWS API
access is governed **separately** by one of:

```bash
aws configure                  # static access keys
aws configure sso              # SSO / IAM Identity Center
export AWS_PROFILE=my-profile  # reuse an existing profile
```

At the end of setup, `oma` runs `aws sts get-caller-identity` to confirm
the current shell's credentials resolve to the same account id recorded in
`profile.yaml` and warns on mismatch. The `AWS credentials` probe in
`oma doctor` performs the same check on demand.

## Step 1: Register the Marketplace (30 seconds)

On Claude Code **2.0+** the native marketplace is the **only supported**
installation path. Launch Claude Code:

```bash
claude
```

Inside the Claude Code session:

```text
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install ai-infra@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
```

:::info Installing all four at once
`/plugin install` itself takes a single plugin id per invocation
(space-separated arguments are **not** supported). Pasting the six lines
above lets Claude Code run them sequentially. If you prefer to script
installation from a shell one-liner, use a here-doc:

```bash
claude <<'EOF'
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install ai-infra@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
EOF
```
:::

`/plugin list` should show all four as `enabled`:

```text
ai-infra       v0.4.0-preview.1  enabled
agenticops     v0.4.0-preview.1  enabled
aidlc          v0.4.0-preview.1  enabled
modernization  v0.4.0-preview.1  enabled
```

:::caution `bash scripts/install/claude.sh` alone does NOT work
The OMA installer script only creates symlinks under `~/.claude/plugins/`.
That was enough for Claude Code 1.x, but **Claude Code 2.0+** treats
`~/.claude/installed_plugins.json` as ground truth. Running the script
on its own leaves `/plugin list` empty. Use the native marketplace flow
above instead.

The installer script remains useful for legacy Claude Code 1.x
environments and for syncing MCP servers / hooks into `settings.json` in
non-interactive setups.
:::

## Step 2: Initialize Your Project (10 seconds)

OMA stores per-project state under `.omao/`. **If you ran `oma setup`, this
step is already done** — setup also initializes `.omao/`.

To create `.omao/` without the full setup wizard:

```bash
cd <your-project>
oma init           # scaffolds .omao/ only (no wizard)
```

> You do not need to remember the OMA install path — `oma init` resolves
> it automatically. Run `oma where` to print the install root if you ever
> need it.

The structure created is as follows:

```
.omao/
├── plans/                # AIDLC artifacts (spec, design, ADR, user stories)
├── state/                # Session checkpoints and active Tier-0 mode
├── notepad.md            # Working notes
├── triggers.json         # Keyword trigger catalog (read by SessionStart hook)
└── project-memory.json   # Per-project persistent context
```

`.omao/` is harness-agnostic, so Claude Code and Kiro share the same files.

## Step 3: First Tier-0 Execution (2 minutes)

Start with the lightest workflow, `/oma:aidlc-loop`, for a single feature AIDLC one-pass.

```bash
> /oma:aidlc-loop "Add anomaly pattern detection rules to user authentication logs"
```

The agent proceeds in this order:

1. **Inception** — Generate `spec.md` and `user-stories.md` in `.omao/plans/`.
2. **Checkpoint 1** — An approval prompt appears for requirements review. Respond with `approve` or `revise`.
3. **Construction** — After approval, sequentially generate `design.md`, `adr-<topic>.md`, test strategy, and implementation diff.
4. **Checkpoint 2** — Design and implementation review checkpoint. Approval and revision are possible here too.
5. **Operations Setup** — The `agenticops` plugin registers Langfuse trace hooks for continuous post-deployment monitoring.

## Step 4: Understanding Checkpoint Structure (1 minute)

OMA checkpoints follow the 5-stage template from [aws-samples/sample-apex-skills](https://github.com/aws-samples/sample-apex-skills).

```mermaid
flowchart LR
    G["1. Gather Context"] --> P["2. Pre-flight"]
    P --> PL["3. Plan"]
    PL --> E["4. Execute"]
    E --> V["5. Validate"]
    V -.on failure.-> PL
```

Each stage stores results in `.omao/state/checkpoint-<n>.json`. You can pause and resume; rollback is performed by restoring `.omao/state/` snapshots.

## Step 5: Switch to Autonomous Mode (1 minute)

For full-loop automation instead of single-pass, use `/oma:autopilot`.

```bash
> /oma:autopilot "Complete the new API endpoint /v1/events/anomaly from planning through operations"
```

`autopilot` runs Inception, Construction, and Operations continuously, requiring user approval only at checkpoints. During the operations phase, `continuous-eval`, `incident-response`, and `cost-governance` skills activate in the background.

To stop anytime, invoke:

```bash
> /oma:cancel
```

## Verify Results

After completing the Quickstart, the following artifacts are generated:

- `.omao/plans/spec.md` — Requirements specification
- `.omao/plans/design.md` — Component design
- `.omao/plans/adr-*.md` — Architecture decision records
- Source code changes (committed to feature branch)
- `.omao/state/session-<id>/` — Session logs and checkpoint results

## Troubleshooting Summary

| Symptom | Root Cause | Fix |
|---|---|---|
| `/plugin marketplace add` fails | Claude Code version unsupported | Run `claude --version` and upgrade |
| `jq: command not found` | jq not installed | `brew install jq` / `apt install jq` |
| `/oma:*` commands not exposed | `~/.claude/commands/oma/` symlink failed | Rerun `bash scripts/install/claude.sh` |
| MCP server connection fails | `uvx` missing or network issue | Run `pipx install uv` and retry |
| Checkpoint stuck waiting | Hook registration missing | See [Claude Code Setup](./claude-code-setup.md) hooks section |

For more detailed troubleshooting, see [Claude Code Setup](./claude-code-setup.md).

## Next Steps

- [Easy Button](./easy-button.md) — Single `oma setup` execution for install, profile, and seed ontology
- [Profile](./profile.md) and [Doctor](./doctor.md) — Project settings and environment health checks
- [Ontology](./ontology.md) and [Harness DSL](./harness-dsl.md) — Runtime domain contracts and DSL
- [Philosophy](./philosophy-aidlc-meets-agenticops.md) — Understand OMA's design premise
- [Tier-0 Workflows](./tier-0-workflows.md) — Deep dive into all 9 Tier-0 commands
- [Keyword Triggers](./keyword-triggers.md) — Auto-invoke commands based on keywords
- [Support Policy](./support-policy.md) and [Telemetry](./telemetry.md) — Tech Preview support scope

## Reference Materials

### Official Documentation
- [Claude Code Plugins](https://docs.anthropic.com/claude/docs/claude-code-plugins) — Claude Code plugin official guide
- [awslabs/aidlc-workflows](https://github.com/awslabs/aidlc-workflows) — AIDLC core workflow repository

### OMA Internal Documentation
- [Introduction](./intro.md) — OMA overview and plugin catalog
- [Claude Code Setup](./claude-code-setup.md) — Manual installation and hook configuration
- [Tier-0 Workflows](./tier-0-workflows.md) — Command reference details
