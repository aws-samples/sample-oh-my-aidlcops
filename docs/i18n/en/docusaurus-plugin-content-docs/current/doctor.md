---
id: doctor
title: Doctor (oma doctor)
sidebar_position: 10
---

# Doctor — `oma doctor`

Runs 12 environment probes to verify that installation and runtime environment are ready to support AIDLC / AgenticOps work.

## Usage

```bash
oma doctor            # Human-readable table format
oma doctor --json     # JSON schema report for CI
oma doctor --project /path/to/project   # Check target directory instead of current
```

## Exit codes

| Code | Meaning |
|---|---|
| 0 | All probes pass (skips allowed) |
| 1 | At least 1 warning, no failures |
| 2 | At least 1 failure |

## Probe list

| id | Label | Default severity | Description |
|---|---|---|---|
| `bash-version` | Bash >= 4 | fail | Reject macOS default bash 3.2 |
| `jq-installed` | jq installed | fail | Dependency for all JSON merge paths |
| `git-installed` | git installed | fail | clone install & upgrade |
| `python3-installed` | python3 installed | warn | Required for DSL compile / profile validate |
| `uvx-installed` | uvx installed (for MCP) | warn | MCP server launcher |
| `claude-cli` | Claude CLI | skip | Skip if missing — Kiro-only configuration allowed |
| `kiro-cli` | Kiro CLI | skip | Same as above |
| `claude-settings` | Claude settings.json has OMA hooks | warn | Trigger inactive if hooks not registered |
| `mcp-pin-integrity` | MCP server versions pinned | fail | Entire `.mcp.json` must use `==X.Y.Z` |
| `aws-credentials` | AWS credentials | warn | `aws sts get-caller-identity` success |
| `profile-valid` | `.omao/profile.yaml` valid | warn/fail | Fails on schema violations |
| `ontology-valid` | `.omao/ontology/` valid | fail | Seed ontology JSON Schema validation |

## JSON report schema

`--json` output follows [`schemas/doctor/report.schema.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/doctor/report.schema.json).

```jsonc
{
  "version": "1",
  "oma_version": "0.2.0-preview.1",
  "generated_at": "2026-04-30T02:05:11Z",
  "summary": { "pass": 11, "warn": 1, "fail": 0, "skipped": 0 },
  "probes": [
    { "id": "bash-version", "status": "pass", "message": "bash 5.2" },
    { "id": "aws-credentials", "status": "warn", "message": "aws sts get-caller-identity failed", "remediation": "Run `aws configure sso`." },
    ...
  ]
}
```

## Usage in CI

```yaml
- name: oma doctor
  run: oma doctor --json > doctor.json
- name: Fail on critical doctor issues
  run: |
    jq -e '.summary.fail == 0' doctor.json
```

By default, `warn` does not fail CI. For strict mode, also assert `.summary.warn == 0`.
