---
title: Claude Code Setup
description: Two installation paths for OMA in Claude Code environments (native marketplace and manual), settings.json MCP merge mechanics, hook registration details, and common troubleshooting.
sidebar_position: 4
---

This document explains two paths to install and configure `oh-my-aidlcops` (OMA) in the Claude Code CLI environment. The native marketplace path is recommended; manual installation is used when the native path is unavailable due to offline environments, enterprise policies, or other constraints.

## Prerequisites

| Tool | Version | Installation |
|---|---|---|
| Claude Code CLI | latest stable | [Official Installation Guide](https://docs.anthropic.com/claude/docs/claude-code) |
| bash | 4+ | `brew install bash` (macOS default 3.2 is outdated) |
| jq | 1.6+ | `brew install jq` or `apt install jq` |
| uv / uvx | latest | `pipx install uv` (required for MCP server execution) |
| git | 2.30+ | System defaults are acceptable for most environments |

## Method 1 · Native Marketplace Installation (only supported path)

On Claude Code **2.0+** the native marketplace is the only mechanism that
exposes plugins in `/plugin list`. Launch Claude Code:

```bash
claude
```

Inside the Claude Code session, paste (or enter) the six lines below:

```text
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install agentic-platform@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc-inception@oh-my-aidlcops
/plugin install aidlc-construction@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
```

To script the whole sequence from a shell one-liner use a here-doc:

```bash
claude <<'EOF'
/plugin marketplace add https://github.com/aws-samples/sample-oh-my-aidlcops
/plugin install agentic-platform@oh-my-aidlcops
/plugin install agenticops@oh-my-aidlcops
/plugin install aidlc-inception@oh-my-aidlcops
/plugin install aidlc-construction@oh-my-aidlcops
/plugin install modernization@oh-my-aidlcops
/plugin list
EOF
```

Expected `/plugin list` output:

```bash
> /plugin list
# agentic-platform     0.2.0-preview.1   enabled
# agenticops           0.2.0-preview.1   enabled
# aidlc-inception      0.2.0-preview.1   enabled
# aidlc-construction   0.2.0-preview.1   enabled
# modernization        0.2.0-preview.1   enabled
```

This path updates `~/.claude/installed_plugins.json` and merges each
plugin's `.mcp.json` and commands automatically.

## Method 2 · Manual Script (legacy / auxiliary)

:::caution Claude Code 2.0+ will not load plugins from this path alone
`scripts/install/claude.sh` creates symlinks under `~/.claude/plugins/` and
merges MCP servers + hooks into `~/.claude/settings.json`. That was enough
for Claude Code 1.x, but **Claude Code 2.0+** treats
`~/.claude/installed_plugins.json` as ground truth. Running the script by
itself leaves `/plugin list` empty. Use it only in the scenarios below.
:::

`scripts/install/claude.sh` remains useful in three scenarios:

1. **Legacy Claude Code 1.x** — the symlink approach was the only install path there.
2. **MCP / hooks only** — merge OMA MCP servers + hooks into `settings.json` without registering the marketplace.
3. **Offline CI** — air-gapped environments where `/plugin marketplace add` cannot reach GitHub.

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
cd oh-my-aidlcops
bash scripts/install/claude.sh
```

The script performs four steps (see [install/claude.sh source](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/scripts/install/claude.sh) for detailed behavior).

1. **Plugin symlink** — Symlinks each plugin directory to `~/.claude/plugins/<plugin>/`.
2. **Command symlink** — Symlinks `steering/commands/oma/` to `~/.claude/commands/oma/`, exposing `/oma:*` slash commands.
3. **MCP server merge** — Non-destructively merges the `mcpServers` object from each plugin's `.mcp.json` into the top-level `mcpServers` key in `~/.claude/settings.json`.
4. **Hook registration** — Registers `hooks/user-prompt-submit.sh` and `hooks/session-start.sh` in `~/.claude/settings.json`'s `hooks` section.

The script is **idempotent**. Re-running preserves existing symlinks and creates only missing items.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OMA_OWNER` | `aws-samples` | Marketplace GitHub owner |
| `CLAUDE_HOME` | `$HOME/.claude` | Claude Code installation directory |

## settings.json Merge Details

OMA's installation script **does not overwrite existing `settings.json`**. It uses `jq` to partially merge only two sections.

### `mcpServers` Merge Rules

Existing keys are preserved; only new keys are added.

```json
{
  "mcpServers": {
    "my-custom-server": { "command": "..." },
    "eks-mcp-server": { "command": "uvx", "args": ["awslabs.eks-mcp-server"] },
    "cloudwatch-mcp-server": { "command": "uvx", "args": ["awslabs.cloudwatch-mcp-server"] }
  }
}
```

In the example above, `my-custom-server` (existing key) is preserved, and the 11 hosted MCP servers that OMA adds are inserted as new keys. On key collision, **the existing value takes precedence**.

The list of MCP servers targeted for merge is defined in section 3 of [NOTICE](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE).

### `hooks` Registration Rules

`UserPromptSubmit` and `SessionStart` hooks are added with the following structure.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "/path/to/oh-my-aidlcops/hooks/user-prompt-submit.sh" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "/path/to/oh-my-aidlcops/hooks/session-start.sh" }
        ]
      }
    ]
  }
}
```

Existing hooks are preserved. The installation script checks whether the same `command` path is already registered and avoids creating duplicates.

Hooks serve these roles:

- **SessionStart** — Loads `.omao/triggers.json`, detects active Tier-0 mode, and injects OMA state into session context.
- **UserPromptSubmit** — Detects keyword triggers in user input and suggests matching `/oma:<workflow>` commands. See [Keyword Triggers](./keyword-triggers.md) for details.

## Project Initialization

Installation proceeds at the user home directory level, but actual work happens in `.omao/` at the project root.

```bash
cd <your-project>
bash <oma-repo>/scripts/init-omao.sh
```

This script creates `.omao/plans/`, `.omao/state/`, `.omao/notepad.md`, `.omao/triggers.json`, and `.omao/project-memory.json`.

`.omao/` is **harness-agnostic**, so state remains consistent even if you alternate between Claude Code and Kiro in the same project.

## AIDLC Extensions (opt-in)

The `aidlc-inception` and `aidlc-construction` plugins follow the opt-in extension structure of awslabs/aidlc-workflows. To activate extensions, run:

```bash
bash scripts/install/aidlc-extensions.sh
```

The script clones `awslabs/aidlc-workflows` to `~/.aidlc` and symlinks OMA's `*.opt-in.md` files into that repository's extension directory. OMA does not copy or modify core workflow files; it contributes extensions only (see section 2 of [NOTICE](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/NOTICE) for details).

## Installation Verification

All three commands below must work normally for installation to be complete.

```bash
# 1. Verify plugin active status
> /plugin list

# 2. Verify slash command autocomplete
> /oma:
# autopilot, aidlc-loop, inception, construction, agenticops, self-improving,
# platform-bootstrap, review, cancel must all be shown.

# 3. Verify MCP server connections
> /mcp
# 11 AWS hosted MCP servers must be listed.
```

## Troubleshooting

### `/plugin marketplace add` fails

This occurs when Claude Code version is outdated.

```bash
claude --version
# Upgrade to latest stable: https://docs.anthropic.com/claude/docs/claude-code
```

### `jq: command not found`

The installation script uses jq for JSON merge.

```bash
# macOS
brew install jq
# Debian/Ubuntu
sudo apt-get install -y jq
```

### `/oma:*` commands not displayed

The `~/.claude/commands/oma/` symlink may not have been created.

```bash
ls -la ~/.claude/commands/oma/
# If it is a stale symlink, remove and reinstall
rm ~/.claude/commands/oma
bash <oma-repo>/scripts/install/claude.sh
```

### MCP server connection fails (`uvx not found`)

AWS hosted MCP servers run via `uvx` stdio.

```bash
pipx install uv
# or
curl -LsSf https://astral.sh/uv/install.sh | sh

# After installation
uvx --version
```

### Hook does not execute

Verify that hooks are registered in `~/.claude/settings.json`.

```bash
jq '.hooks' ~/.claude/settings.json
# Both UserPromptSubmit and SessionStart events must be present.
```

Also verify that hook files have execute permissions.

```bash
chmod +x <oma-repo>/hooks/user-prompt-submit.sh
chmod +x <oma-repo>/hooks/session-start.sh
```

### Checkpoint stuck waiting

This may be a permission issue with `.omao/state/` directory.

```bash
ls -la .omao/state/
# If write permission is missing
chmod -R u+w .omao/
```

### Uninstalling plugins

For native marketplace installation:

```bash
> /plugin uninstall agentic-platform agenticops aidlc-inception aidlc-construction
> /plugin marketplace remove oh-my-aidlcops
```

For manual installation, remove symlinks and manually delete relevant entries from `settings.json`.

```bash
rm ~/.claude/plugins/agentic-platform ~/.claude/plugins/agenticops \
   ~/.claude/plugins/aidlc-inception ~/.claude/plugins/aidlc-construction
rm ~/.claude/commands/oma
# Manually clean OMA entries from mcpServers and hooks in ~/.claude/settings.json
```

## Reference Materials

### Official Documentation
- [Claude Code CLI](https://docs.anthropic.com/claude/docs/claude-code) — Official Claude Code guide
- [Claude Code Plugins](https://docs.anthropic.com/claude/docs/claude-code-plugins) — Plugin structure standards
- [awslabs/mcp](https://github.com/awslabs/mcp) — Catalog of MCP servers to merge
- [jq Manual](https://jqlang.github.io/jq/manual/) — Reference for direct settings.json editing

### OMA Internal Documentation
- [Getting Started](./getting-started.md) — 5-minute Quickstart
- [Kiro Setup](./kiro-setup.md) — Kiro environment installation
- [Keyword Triggers](./keyword-triggers.md) — Hook-based automatic command invocation
- [Tier-0 Workflows](./tier-0-workflows.md) — Detailed command reference after installation
