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

## What this commit does NOT do

- Does not modify `scripts/install/claude.sh` or `scripts/install/kiro.sh`.
- Does not modify any plugin's `*.oma.yaml`.
- Does not modify `bin/oma` or any subcommand.
- Does not write to `~/.claude/settings.json` or `~/.kiro/`.

A separate follow-up commit adds `install_permissions()` to both install
scripts and wires it into `oma setup`. Splitting the work this way lets
reviewers see and edit the abstract templates before any harness-specific
emit logic is committed.
