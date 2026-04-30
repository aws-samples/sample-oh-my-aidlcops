---
id: telemetry
title: Telemetry
sidebar_position: 51
---

# Telemetry

**OMA does not collect telemetry.** No data is collected whatsoever.

- `oma setup`, `oma doctor`, `oma compile`, `oma upgrade`, `oma uninstall` all run **locally only**.
- `.omao/` directory (profile, ontology seed, session state, audit logs, project memory) is **not committed** (blocked by `.gitignore`). No external transmission path exists.
- MCP server calls follow the policy of that MCP server provider (e.g., awslabs). OMA does not relay, sample, or aggregate.
- `hooks/session-start.sh`, `hooks/user-prompt-submit.sh` insert warning strings into prompt context only; they do not generate network requests.

## Verification

```bash
# 1. Directly check where network dependencies exist
grep -RIn 'curl\|wget\|http' scripts/ bin/ hooks/ | grep -v '^\s*#'

# 2. install.sh only downloads GitHub tarball (zero network requests after installation)
head -30 install.sh
```

## Exception — explicit external calls

The only paths OMA sends requests to external hosts:

1. `install.sh` — tarball and sha256 downloads (`raw.githubusercontent.com`,
   `github.com`). Never called after installation.
2. `scripts/install/aidlc-extensions.sh` — clone `awslabs/aidlc-workflows` repository.
3. `oma doctor` → `aws sts get-caller-identity` — **user's** AWS account STS call. Only if AWS CLI installed. Results stored locally only.

No other paths exist, and if added, they must be explicitly stated in `CHANGELOG.md`'s "Telemetry" section.
