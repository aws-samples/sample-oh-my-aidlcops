# OMA Permission Templates

Environment-scoped deny templates that constrain the tools and resources OMA
plugins are allowed to call. Templates here are **reference data only** —
nothing in this directory is yet wired into `oma setup` or `oma compile`. A
follow-up commit adds an `install_permissions()` function to
`scripts/install/{claude,kiro}.sh` that consumes these files.

## Files

| File | Scope | Loaded when |
|---|---|---|
| `common.yaml` | Baseline rules every install inherits. Audit ledger and ontology JSON paths can only be mutated through OMA tools. | Always |
| `sandbox.yaml` | Personal accounts, dev clusters. Relaxes auto-approve for file writes; common deny still applies. | `profile.yaml` `aws.environment: sandbox` |
| `staging.yaml` | Shared dev clusters, pre-prod accounts. Blocks cross-region Bedrock inference profiles, cluster-wide kubectl, IAM mutation. | `profile.yaml` `aws.environment: staging` |
| `prod.yaml` | Production accounts. Read-only manifests, GitOps-only kubectl, no IAM/secret/KMS mutation, no EKS write MCP. | `profile.yaml` `aws.environment: prod` |

## Schema

Each template is a YAML document with this shape:

```yaml
version: 1
extends: ["common.yaml"]            # optional, list of template names
applies_when:                       # optional, profile match criteria
  aws.environment: <sandbox|staging|prod>
description: |
  Free-form prose explaining the intent of this template.

deny:
  bash:  []   # fnmatch globs against full command lines
  edit:  []   # POSIX globs against file paths
  write: []   # POSIX globs (Edit + Write merged in Kiro)
  mcp:   []   # fnmatch globs against MCP tool names

auto_approve:
  read_only: true
  file_writes: false
  bash_commands: false
```

`extends` is processed by deep-merging each base into the current template:
list keys are unioned (uniqueness preserved), scalar keys are overwritten.

## Mapping to harness-native config

The install script translates abstract keys to each harness format. Two
formats today, one source of truth here.

| Abstract key | Claude `.claude/settings.json` | Kiro `~/.kiro/settings/cli.json` + `~/.kiro/agents/*.agent.json` |
|---|---|---|
| `deny.bash[i]` | `permissions.deny += "Bash(<pattern>)"` | `cli.json autoApprove.bashCommands=false` + agent.json `tools` strips Bash |
| `deny.edit[i]` | `permissions.deny += "Edit(<glob>)"` | `cli.json autoApprove.fileWrites=false` + agent.json `tools` strips Edit |
| `deny.write[i]` | `permissions.deny += "Write(<glob>)"` | (same as edit — Kiro merges Edit and Write) |
| `deny.mcp[i]` | `permissions.deny += "<mcp_tool_pattern>"` | agent.json `mcpServers[*].disabled=true` or `tools` removes the entry |
| `auto_approve.read_only` | informational hint | `cli.json autoApprove.readOnly` and agent.json `autoApprove.readOnly` |
| `auto_approve.file_writes` | informational hint | `cli.json autoApprove.fileWrites` and agent.json `autoApprove.fileWrites` |
| `auto_approve.bash_commands` | informational hint | `cli.json autoApprove.bashCommands` and agent.json `autoApprove.bashCommands` |

Glob semantics:

- `deny.bash` and `deny.mcp` use fnmatch — `*` does not cross spaces in bash
  patterns, and matching is case-sensitive.
- `deny.edit` and `deny.write` use POSIX globs — use `**` for recursive
  match across directories.

## Pick the right template

Picked automatically from `.omao/profile.yaml`'s `aws.environment` value:

```yaml
aws:
  environment: prod    # → templates/permissions/prod.yaml + common.yaml
```

A user who needs to override (e.g., a dev who wants prod-strength locally)
can copy a template into `.omao/permissions.yaml` and the install script
will prefer the local copy. That override path lands with the install
script commit.

## How the templates are applied

`scripts/lib/permissions.sh` is the shared resolver:

```bash
. scripts/lib/permissions.sh
perms_resolve prod | perms_to_claude_deny      # -> JSON array of "Bash(...)" lines
perms_resolve prod | perms_to_kiro_autoapprove # -> {readOnly,fileWrites,bashCommands}
```

`install_permissions()` in `scripts/install/{claude,kiro}.sh` invokes the
resolver based on `.omao/profile.yaml` `aws.environment` (or the
`OMA_PERMISSIONS_ENV` override) and merges the result into:

- **Claude** — `~/.claude/settings.json` `permissions.deny[]` via
  append-uniq. Existing user-authored entries are preserved verbatim.
- **Kiro** — `~/.kiro/settings/cli.json` `autoApprove` and each
  OMA-installed `~/.kiro/agents/*.agent.json`. The agent files are
  rewritten from the source repo on every run (so upstream agent
  updates flow through), but never mutated in the tracked repo. Each
  patched copy carries `_meta.oma_permissions_env` and
  `_meta.oma_permissions_deny` so the deny set is auditable from Kiro
  even though Kiro itself does not enforce a permissions list.

Skip the step entirely with `--skip-permissions` or
`OMA_SKIP_PERMISSIONS=1`. Hand-edited agent.json copies (no
`_meta.oma_permissions_env`) are refused — delete the file to re-apply.
