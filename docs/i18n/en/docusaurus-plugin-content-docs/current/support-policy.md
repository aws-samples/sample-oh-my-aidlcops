---
id: support-policy
title: Support Policy (Tech Preview)
sidebar_position: 50
---

# Support Policy — Tech Preview

OMA `v0.2.0-preview.1` is a **Tech Preview** release. It does not provide production SLA. Support scope is confirmed by the criteria below.

## Stability contract

| Surface | Status | Policy |
|---|---|---|
| `.omao/profile.yaml` v1 schema | **stable** | No breaking changes before GA |
| `schemas/ontology/*.schema.json` v1 | **stable** | No breaking changes before GA |
| `schemas/harness/dsl.schema.json` v1 | **beta** | Fields may be added; no field removal |
| `bin/oma` subcommand names / exit codes | **beta** | Name changes must go through deprecation cycle |
| `oma doctor` JSON report schema v1 | **beta** | Fields may be added; no removal |
| Plugin internal skill body / prompts | **evolving** | May change between minor releases |
| `templates/` defaults | **evolving** | Frequent updates |

## Support scope

- Provided: documentation-based installation, `oma setup` / `oma doctor` bug fixes, schema violation reports.
- Not provided: production deployment support, 24x7 on-call, paid SLA, security CVE responsibility.

## Issue reporting

- Bugs: https://github.com/aws-samples/sample-oh-my-aidlcops/issues

## Telemetry

OMA **does not collect telemetry.** See [Telemetry](./telemetry.md) for details.

## Upgrade

- `oma upgrade` (for clone installs) or re-run latest `install.sh`.
- Major/minor release notes: [`CHANGELOG.md`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/CHANGELOG.md).

## Removal

```bash
oma uninstall     # Unlink symlinks + clean settings.json (WIP)
rm -rf ~/.oma
rm ~/.local/bin/oma
```

## GA criteria

GA (`v1.0.0`) enters when all four items below are met:

1. E2E scenarios on both harnesses (Claude Code, Kiro) reproducible: 3 or more.
2. All 5 plugins complete DSL migration.
3. Zero critical bug reports from downstream users / 90 days.
4. Release artifact supply-chain validation (sha256 + SBOM + signed commit) automated.
