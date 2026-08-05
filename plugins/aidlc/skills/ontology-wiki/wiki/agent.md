# Agent

> Actor with a declared produce/consume contract. Source:
> `schemas/ontology/agent.schema.json`.

## What it is

An `Agent` is an actor that runs in a harness (Claude Code, Kiro, or CLI) and
declares, via its `ontology` block, which entities it produces and consumes.
That contract is what lets the compiler and the harness reason about handoffs.

## Fields

| Field | Required | Type / enum | Notes |
|---|:---:|---|---|
| `id` | ✅ | `^[a-z][a-z0-9-]*$` | kebab-case, unique within a plugin |
| `runtime` | ✅ | `claude-code · kiro · cli` | where the agent runs |
| `model` | | string | free-form so future model names stay valid |
| `tier` | | integer 0–2 | Tier-0 = top-level workflows |
| `mcp` | | array | MCP server ids local to the plugin DSL |
| `mcp_uri` | | `^mcp://` | optional canonical MCP URI |
| `model_tier` | | `opus · sonnet · haiku · gpt-4o · custom` | cost-aware routing hint |
| `ontology` | | object | `produces` / `consumes` entity refs |
| `description` | | string | |

## References (from graph.json)

- inverse: `Deployment → Agent` via `produced_by` — **produced_by** (INFERRED, 0.7)
- the `ontology.produces` / `ontology.consumes` block names entity types (e.g.
  `ai-infra` declares `produces: [Deployment]`, `consumes: [Spec, ADR]`)

## Why it is shaped this way

- **`model` is free-form but `model_tier` is an enum** — the tier hint is what
  autopilot/agenticops route on, while `model` stays open so new Claude/Bedrock/
  OSS names never require a schema bump.
- **The `ontology` block is the contract** that makes an Agent a graph citizen
  rather than an opaque runner.

## Gotchas for an authoring agent

- `produced_by` on a `Deployment` may point here *or* at a `Skill` — the two
  actor types share that field. Declare `ontology.produces` so the direction is
  unambiguous.
