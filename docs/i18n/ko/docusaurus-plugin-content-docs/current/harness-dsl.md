---
id: harness-dsl
title: Harness DSL
sidebar_position: 8
---

# Harness DSL — one source of truth per plugin

Every OMA plugin describes its runtime surface in a single YAML file:

```
plugins/<name>/<name>.oma.yaml
```

`python -m tools.oma_compile` translates that file into the native files
Claude Code and Kiro already understand:

```
<plugin>.oma.yaml  ──(oma-compile)──▶  .mcp.json
                                   ▶  kiro-agents/<agent>.agent.json
                                   ▶  .omao/triggers.json   (merged across plugins)
```

Plugins keep shipping the compiled output, so `/plugin install` from the
marketplace works even on machines that have never seen the compiler.

## Example

```yaml
# plugins/ai-infra/ai-infra.oma.yaml
version: 1
plugin: ai-infra

agents:
  - id: autopilot-deploy
    runtime: claude-code
    mcp: [eks, cloudwatch, prometheus]
    tier: 0
    ontology:
      produces: [Deployment]
      consumes: [Spec, ADR]

mcp:
  eks:
    command: uvx
    args: ["awslabs.eks-mcp-server==0.1.28"]
    env: { FASTMCP_LOG_LEVEL: ERROR }
  cloudwatch:
    command: uvx
    args: ["awslabs.cloudwatch-mcp-server==0.0.25"]

hooks:
  session-start:
    runs: hooks/session-start.sh

triggers:
  - keyword: platform-bootstrap
    route: /oma:platform-bootstrap
```

## Guarantees enforced at compile time

- **Pinned MCP versions.** `args` must contain `==X.Y.Z`. Floating versions
  (`@latest`, unpinned, caret ranges) are rejected so a compromised upstream
  release cannot silently land alongside AWS credentials.
- **Declared MCP references.** `agents[*].mcp` can only name ids that exist in
  the top-level `mcp:` map. Unknown references fail the build.
- **Real hook scripts.** `hooks.<event>.runs` must point at an existing file
  under the plugin. No phantom hook declarations.
- **Stable output.** Emitted JSON is sorted deterministically; CI fails the
  build if committed `.mcp.json` or `.agent.json` drift from the DSL source
  (`oma-compile --check`).

## Commands

```bash
# Compile one plugin
python -m tools.oma_compile plugins/ai-infra/ai-infra.oma.yaml

# Compile every plugin that has a *.oma.yaml
python -m tools.oma_compile --all

# Fail if committed native files drift from DSL
python -m tools.oma_compile --check
```

## Where the ontology plugs in

`agents[*].ontology.produces` and `consumes` use the entity enum from
`schemas/ontology/agent.schema.json`. The compiler doesn't invent new
vocabulary — the Ontology page ([Ontology](./ontology.md)) is the source of
truth.

## Schema reference

Full JSON Schema: [`schemas/harness/dsl.schema.json`](https://github.com/aws-samples/sample-oh-my-aidlcops/blob/main/schemas/harness/dsl.schema.json).
