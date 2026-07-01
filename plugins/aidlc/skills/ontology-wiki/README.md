# ontology-wiki — build & setup wiring (design)

The pre-generation grounding layer from `adr-0001-graphify-knowledge-wiki`.
This README specifies how the corpus is built and wired at `oma setup`. The
runtime query contract lives in [`SKILL.md`](./SKILL.md); the architecture and
honest limits live in [`docs/docs/knowledge-wiki.md`](../../../../docs/docs/knowledge-wiki.md).

## What ships in the plugin

| File | Role | Shipped by `/plugin install`? |
|---|---|:---:|
| `graph.json` | structural backing — 8 nodes, reference edges, provenance tags | ✅ |
| `GRAPH_REPORT.md` | god nodes, surprising edges, suggested grounding questions | ✅ |
| `wiki/<entity>.md` | per-entity definition, enums, references, rationale, gotchas | ✅ |
| `SKILL.md` | 3-tier retrieval + graceful-degradation contract | ✅ |

These are committed under `skills/` so the marketplace path delivers a working
2nd-tier wiki with **zero runtime dependency**. Graphify is only needed to
(re)generate them or to serve 1st-tier live queries.

## `oma setup` wiring (design — implementation tracked in #54)

Insert between step 4 (render seed ontology) and step 5 (install plugins):

```
4.5  Knowledge Wiki (opt-in)
     ask OMA_WIKI_GRAPHIFY "Enable Graphify-backed live wiki queries? \
          (requires: pip install graphifyy) (none/runtime)" "none"

     if OMA_WIKI_GRAPHIFY = runtime AND graphifyy present:
        a. assemble corpus  = schemas/ontology + .omao/plans/{adr,spec}
                              + docs/docs + the user's live .omao/ontology/*
        b. graphify <corpus> --no-viz        # build graph.json + wiki/
        c. register the graphify --mcp server into the user's harness
           settings (Claude .mcp.json / Kiro cli.json) directly —
           NOT via `graphify claude install` (that ships its own PreToolUse
           hook and would collide with OMA's harness).
        d. optionally: graphify hook install # git post-commit re-index
     else:
        skip — the committed corpus (2nd tier) is already in place; the
        SKILL.md degrades to reading it, and finally to raw schemas (3rd tier).
```

### Why opt-in, not default

- Graphify is a pip package + a running MCP process + a model API call for the
  semantic pass. Defaulting it would break the marketplace's zero-runtime-
  dependency promise and add a single-maintainer dependency on the hot path.
- The committed corpus already satisfies "install a plugin → get the third
  accuracy layer" without any of that. Graphify only *upgrades* it to live,
  relationship-aware queries when the user asks.

## Regeneration (staleness guard)

The committed corpus must not lag the schemas. Regenerate when
`schemas/ontology/**`, `.omao/plans/**`, or `docs/docs/**` change:

```
graphify <corpus> --update       # incremental re-extract + merge
# or wire a git post-commit hook:
graphify hook install
```

A CI check analogous to `oma compile --check` should fail when `graph.json`
drifts from the current schemas. Until that check exists, treat the committed
corpus as a point-in-time snapshot and prefer 3rd-tier (raw schema) reads when
freshness is in doubt.

## Harness interaction

Graphify's `--mcp` server is a normal MCP server: OMA's harness PreToolUse hook
(matcher `.*`) **wraps** the agent's `mcp__graphify__*` calls, so wiki access is
itself subject to harness policy. The intrusive `graphify claude install` is
never used, so there is exactly one PreToolUse owner: OMA's harness.
