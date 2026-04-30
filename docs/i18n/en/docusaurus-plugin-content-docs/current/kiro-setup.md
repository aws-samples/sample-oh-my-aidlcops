---
title: Kiro Setup
description: Installation path for OMA in the Kiro agent harness. Covers install/kiro.sh symlink structure, kiro.meta.yaml sidecar, and state sharing with Claude Code.
sidebar_position: 5
---

This document explains how to install and configure `oh-my-aidlcops` (OMA) in the Kiro harness. OMA supports both Claude Code and Kiro with identical skill and state foundations; both harnesses share the `.omao/` directory at the project root.

## Kiro Harness

Kiro is a **skills-first agent harness** distinct from Claude Code. Key differences:

| Aspect | Claude Code | Kiro |
|---|---|---|
| Plugin unit | `plugin/` directory | Flat skill-level deployment |
| Skill location | `~/.claude/plugins/<plugin>/skills/<skill>/` | `~/.kiro/skills/<plugin>/<skill>/` |
| Command system | `/slash-command` | Direct skill invocation |
| Steering | Auto-injected by Claude Code | `.kiro/steering/` directory-based |
| Trigger hints | `settings.json` hooks | `kiro.meta.yaml` sidecar |

OMA absorbs these differences in `install/kiro.sh`, sharing the identical `plugins/<plugin>/skills/<skill>/SKILL.md` source across both harnesses.

## Prerequisites

| Tool | Version | Installation |
|---|---|---|
| Kiro runtime | latest stable | [Kiro Official Guide](https://kiro.dev) |
| bash | 4+ | `brew install bash` (macOS) |
| jq | 1.6+ | `brew install jq` / `apt install jq` |
| git | 2.30+ | System defaults acceptable |
| uv / uvx | latest | `pipx install uv` (required for MCP servers) |

## Installation

Kiro does not provide a native marketplace path, so manual installation is the only option.

```bash
git clone https://github.com/aws-samples/sample-oh-my-aidlcops
cd oh-my-aidlcops
bash scripts/install/kiro.sh
```

Expected output after script execution:

```
[install-kiro] OMA repo : /.../oh-my-aidlcops
[install-kiro] KIRO_HOME: /home/user/.kiro
[install-kiro] OMA_OWNER: aws-samples
[install-kiro] skill linked: agentic-platform/vllm-serving-setup
[install-kiro] skill linked: agenticops/self-improving-loop
...
[install-kiro] steering linked: /home/user/.kiro/steering

Installation complete.
    skills linked         : 23
    kiro.meta.yaml found  : 7
```

## Symlink Structure

After installation, the Kiro home directory has the following structure:

```
~/.kiro/
├── skills/
│   ├── agentic-platform/
│   │   ├── agentic-eks-bootstrap       -> <repo>/plugins/agentic-platform/skills/agentic-eks-bootstrap
│   │   ├── vllm-serving-setup          -> <repo>/plugins/agentic-platform/skills/vllm-serving-setup
│   │   ├── inference-gateway-routing   -> ...
│   │   └── ...
│   ├── agenticops/
│   │   ├── self-improving-loop         -> ...
│   │   ├── autopilot-deploy            -> ...
│   │   ├── incident-response           -> ...
│   │   ├── continuous-eval             -> ...
│   │   └── cost-governance             -> ...
│   ├── aidlc-inception/
│   └── aidlc-construction/
├── steering                             -> <repo>/steering
├── guides/                              # NEW: stage-by-stage safety guides (per-plugin directory)
│   └── agentic-platform/                -> <repo>/plugins/agentic-platform/guides
├── agents/                              # NEW: Kiro agent profiles
│   └── agentic-platform.agent.json      -> <repo>/plugins/agentic-platform/kiro-agents/agentic-platform.agent.json
└── settings/                            # NEW: CLI settings
    └── cli.json                         # Default template (user-editable)
```

Each symlink points to the original directory in the OMA repository. Thus, updating the repository with `git pull` immediately makes latest skills available to Kiro.

### Idempotency

`install/kiro.sh` is idempotent. Re-running preserves existing symlinks if their targets are correct and creates only corrupted links. If an actual file occupies a symlink location, **the script warns and does not overwrite**.

```
[install-kiro][warn] refusing to replace non-symlink: /home/user/.kiro/skills/my-skill
```

## kiro.meta.yaml Sidecar

Some Claude Code SKILL.md frontmatter fields are not directly interpreted by Kiro. Some skills provide Kiro-specific metadata as a `kiro.meta.yaml` sidecar file; the install script detects and logs this.

```
[install-kiro] skill linked: agentic-platform/vllm-serving-setup
[install-kiro]   kiro.meta.yaml sidecar detected for agentic-platform/vllm-serving-setup
```

Example sidecar structure:

```yaml
# kiro.meta.yaml
kiro:
  trigger_keywords:
    - "vllm"
    - "model serving"
    - "PagedAttention"
  context_files:
    - SKILL.md
    - reference/vllm-config.yaml
  mcp_required:
    - eks-mcp-server
    - aws-pricing-mcp-server
  phase: operations
  approval_required: true
```

Kiro reads this metadata to perform:

- **trigger_keywords** — Prioritize skill suggestion on natural language match
- **context_files** — Load additional files alongside skill execution
- **mcp_required** — Verify required MCP server connections before execution
- **phase** — Classify as Inception / Construction / Operations stage
- **approval_required** — Whether checkpoint approval is required

Skills without sidecars operate normally using only SKILL.md frontmatter.

## Full Kiro Layout Support

OMA supports the complete directory layout used in AWS Kiro modernization samples. The install script automatically configures these 5 directories:

### 1. skills/ — Executable Skills

Symlinks all plugin `skills/` subdirectories to `~/.kiro/skills/<plugin>/<skill>/` form. Each skill comprises `SKILL.md` and optional `kiro.meta.yaml` sidecar.

### 2. steering/ — Global Orientation

Symlinks the `steering/` directory to `~/.kiro/steering/`.

```
steering/
├── oma-hub.md              # OMA global orientation
├── commands/
│   └── oma/                # /oma:* slash command definitions (Claude Code-specific)
└── workflows/              # 5-checkpoint workflow templates
```

Kiro does not interpret `commands/oma/` as slash commands but uses file content as skill orchestration reference material. The 5-checkpoint templates in `workflows/` operate identically across both harnesses.

### 3. guides/ — Stage-by-Stage Safety Guides

Symlinks plugin `guides/` directories to `~/.kiro/guides/<plugin>/` form. Guides are stage-gated, safety-critical content loaded per workflow stage.

```
~/.kiro/guides/
└── agentic-platform/       -> <repo>/plugins/agentic-platform/guides
    ├── aws-practices/      # AWS Well-Architected-based guides
    ├── common/             # Common safety baselines
    └── stages/             # Stage-by-stage checkpoint guides
        ├── stage-1-analysis.md
        ├── stage-2-requirements.md
        └── ...
```

Kiro automatically loads the guide for the current workflow stage into context. For example, during the `stage-2-requirements` phase, `stages/stage-2-requirements.md` is injected as context.

### 4. agents/ — Kiro Agent Profiles

Symlinks plugin `kiro-agents/*.json` files to `~/.kiro/agents/` directory. Each agent profile defines:

- **MCP Server Configuration** — List of required MCP servers and environment variables
- **Auto-approval Rules** — Read-only / file write / bash command approval policies
- **Resource Loading** — Steering files and skill paths to load on agent startup

Example: `agentic-platform.agent.json`

```json
{
  "name": "agentic-platform",
  "description": "Agentic AI Platform architect for EKS + vLLM + Inference Gateway + Langfuse on AWS.",
  "mcpServers": {
    "awslabs.eks-mcp-server": { "command": "uvx", "args": ["awslabs.eks-mcp-server==0.1.28"] },
    "awslabs.aws-documentation-mcp-server": { ... }
  },
  "autoApprove": {
    "readOnly": true
  }
}
```

In Kiro runtime, activate the profile in the form `@agentic-platform`.

### 5. settings/ — CLI Default Configuration

Copies `scripts/kiro-cli.template.json` template to `~/.kiro/settings/cli.json` (only if no existing file). This file defines default Kiro CLI behavior.

```json
{
  "defaultModel": "claude-sonnet-4-6",
  "autoApprove": {
    "readOnly": true,
    "fileWrites": false,
    "bashCommands": false
  },
  "steering": {
    "alwaysLoad": ["oma-hub.md"]
  }
}
```

After installation, users can directly edit this file to adjust default model, auto-approval policy, and steering files to always load.

## Project Initialization

Initialize `.omao/` in your project directory, the same as Claude Code. **If you ran `oma setup`, this is already done** — no manual call needed.

To initialize manually without the full setup wizard:

```bash
cd <your-project>
# If installed via install.sh (default)
bash ~/.oma/scripts/init-omao.sh

# If installed via git clone
bash <cloned-repo>/scripts/init-omao.sh
```

Since `.omao/` is harness-agnostic, state stays synchronized even if you use Claude Code and Kiro in parallel on the same project. For example, you can start an AIDLC loop in Kiro and continue it in Claude Code for checkpoint approvals.

## AIDLC Extensions (opt-in)

Kiro also supports awslabs/aidlc-workflows extensions.

```bash
bash scripts/install/aidlc-extensions.sh
```

The script clones `awslabs/aidlc-workflows` to `~/.aidlc` and symlinks OMA's `*.opt-in.md` extensions. Kiro does not auto-load `~/.aidlc` as skill context, so you must either reference it explicitly during skill invocation or copy it to your project's `.omao/plans/` directory.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OMA_OWNER` | `aws-samples` | GitHub owner |
| `KIRO_HOME` | `$HOME/.kiro` | Kiro installation directory |

You can reassign `KIRO_HOME` in CI environments or on multi-user machines to create isolated installations.

```bash
KIRO_HOME=/opt/kiro-ci bash scripts/install/kiro.sh
```

## Installation Verification

```bash
# 1. Check skill directory
ls ~/.kiro/skills/
# agentic-platform/  agenticops/  aidlc-inception/  aidlc-construction/

# 2. Skill count per plugin
for p in agentic-platform agenticops aidlc-inception aidlc-construction; do
    echo "$p: $(ls ~/.kiro/skills/$p/ 2>/dev/null | wc -l) skills"
done

# 3. Verify steering symlink
ls -la ~/.kiro/steering
# Should be a symbolic link to <repo>/steering
```

Invoke a skill in Kiro runtime to verify normal operation.

```
> agenticops/self-improving-loop analyze traces and write improvement PR
```

## Troubleshooting

### Skills not showing in Kiro

Check whether symlinks were created under `~/.kiro/skills/`.

```bash
find ~/.kiro/skills/ -maxdepth 2 -type l | head
```

If symlinks are broken, reinstall.

```bash
rm -rf ~/.kiro/skills/agentic-platform ~/.kiro/skills/agenticops \
       ~/.kiro/skills/aidlc-inception ~/.kiro/skills/aidlc-construction
bash ~/.oma/scripts/install/kiro.sh
```

### `refusing to replace non-symlink` warning

This occurs when actual files exist in the Kiro skill directory. Back up and remove the conflicting file, then reinstall.

```bash
mv ~/.kiro/skills/<conflicting-skill> ~/.kiro/skills/<conflicting-skill>.bak
bash ~/.oma/scripts/install/kiro.sh
```

### kiro.meta.yaml not taking effect

Sidecar field support varies by Kiro version. Check the following:

```bash
# Verify sidecar file existence
find ~/.kiro/skills/ -name 'kiro.meta.yaml' | head

# Check sidecar load in Kiro runtime logs (see Kiro documentation)
```

Unsupported fields are ignored and do not affect basic skill operation.

### State mismatch between Claude Code and Kiro

Both harnesses share the same `.omao/`, so they should stay synchronized by design. If mismatch occurs, suspect file system sync issues (NFS, network drives).

```bash
# Verify the file system is local
df -T .omao/
# If it is a network drive, migration to local disk is recommended
```

### MCP server connection fails

Kiro runtime may not find the `uvx` path. Add the uv installation path (`~/.local/bin` or `~/.cargo/bin`) to `PATH` in Kiro settings.

## Kiro-Specific Considerations

### Trigger Keyword-Based Invocation

Kiro auto-matches natural language input to skills based on `trigger_keywords` in `kiro.meta.yaml`. This is similar to Claude Code's [Keyword Triggers](./keyword-triggers.md) hook-based structure but handled by Kiro's internal engine.

### Checkpoint Approval UX

Kiro displays checkpoints as inline prompts in the conversation. Approve/reject/revise by entering `approve` / `reject` / `revise <comment>`. Input format is identical to Claude Code, so learning cost is minimal.

### Log Collection

Kiro stores execution logs in `~/.kiro/logs/`. OMA does not separately collect these logs, but attaching that directory with bug reports enables reproducibility.

## Removal

```bash
# Remove skill symlinks
rm -rf ~/.kiro/skills/agentic-platform ~/.kiro/skills/agenticops \
       ~/.kiro/skills/aidlc-inception ~/.kiro/skills/aidlc-construction

# Remove steering symlink
rm ~/.kiro/steering

# (Optional) Remove project state
rm -rf <your-project>/.omao/
```

## Reference Materials

### Official Documentation
- [Kiro Official Guide](https://kiro.dev) — Kiro runtime installation and configuration
- [awslabs/mcp](https://github.com/awslabs/mcp) — List of MCP servers for Kiro

### OMA Internal Documentation
- [Introduction](./intro.md) — OMA overview
- [Getting Started](./getting-started.md) — 5-minute Quickstart (Claude Code-based; flow is identical)
- [Claude Code Setup](./claude-code-setup.md) — Sister harness installation
- [Tier-0 Workflows](./tier-0-workflows.md) — Workflows to invoke after installation
