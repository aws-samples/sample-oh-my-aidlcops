---
id: easy-button
title: Easy Button — 3-command install
sidebar_position: 1.5
---

# Easy Button — 3-command install

:::caution Tech Preview
`oma setup` / `oma doctor` are **Tech Preview** (`v0.2.0-preview.1`).
Only `profile.yaml` v1 is considered stable; other surfaces may change before GA.
See [Support Policy](./support-policy.md) for details.
:::

OMA aims to be the "AIDLC × AgenticOps easy button." Installation through first workflow execution completes in **three lines**.

```bash
# 1. Remote install — download release tarball, install to ~/.oma, symlink ~/.local/bin/oma
curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.2.0-preview.1/install.sh | bash

# 2. Project setup — create profile, seed ontology, install plugins
cd my-project
oma setup

# 3. Environment check — 12 probes for profile/hooks/MCP/ontology/AWS credentials
oma doctor
```

## What `oma setup` does

1. **Preflight** — Verify availability of `jq`, `git`, `python3`, `uvx`, Claude CLI, Kiro CLI.
2. **Profile wizard** — Seven questions (Harness / AWS account / Region / Environment / AIDLC entry phase / Approval mode / Monthly budget / Observability). All defaults can be skipped by pressing ENTER.
3. **Write `.omao/profile.yaml` + immediate validation** — Fails on schema violations. Installation does not complete with an invalid profile.
4. **Seed ontology render** — Substitute profile values into `templates/ontology/`, generate `.omao/ontology/{budgets,deployments,risks}/*.json`, **each passing JSON Schema validation**.
5. **Harness install** — Call `scripts/install/claude.sh` or `kiro.sh`. If both selected, use `both`.
6. **DSL compile** — If `plugins/*/*.oma.yaml` exists, run `python3 -m tools.oma_compile --all`, regenerate `.mcp.json` / `kiro-agents/*.agent.json`.
7. **Doctor summary** — Run 12 probes, pretty-print output. Aggregate zero failures / N warnings.

### Non-interactive execution (CI)

```bash
OMA_NON_INTERACTIVE=1 \
  OMA_HARNESS=claude-code \
  OMA_AWS_ACCOUNT=123456789012 \
  OMA_AWS_REGION=ap-northeast-2 \
  OMA_AWS_ENV=sandbox \
  OMA_AIDLC_PHASE=inception \
  OMA_APPROVAL_MODE=interactive \
  OMA_BUDGET_USD=200 \
  OMA_OBSERVABILITY=langfuse-managed \
  oma setup --non-interactive --skip-doctor
```

## Ontology + Harness are top-level rules

In projects installed via `oma`, ontology (Agent / Skill / Deployment / Incident / Budget / Risk) and harness DSL operate as **top-level rules overriding all plugins**. Specific rules are defined in [Ontology + Harness Mandate](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/steering/workflows/ontology-harness-mandate.md).

Enforcement points:

| Timing | Component | Action |
|---|---|---|
| Session start | `hooks/session-start.sh` | Scan `.omao/ontology/` → inject Budget / Incident / Deployment state |
| User prompt | `hooks/user-prompt-submit.sh` | If Budget exceeds 80%, insert `[MAGIC KEYWORD: OMA_BUDGET_WARN]` |
| On-demand | `oma doctor` | Check Profile / Ontology / Harness drift |
| PR time | `.github/workflows/oma-foundation.yml` | Block DSL↔native drift with `oma compile --check` |

## Next steps

- [Profile Reference](./profile.md)
- [Doctor Reference](./doctor.md)
- [Ontology Overview](./ontology.md)
- [Harness DSL](./harness-dsl.md)
- [Tier-0 Workflows](./tier-0-workflows.md)
