# examples/

Committed **example** ontology entities that the wiki corpus references.

`.omao/plans/adr/` (where `oma setup` writes real ADR instances) is
git-ignored — each user project gets its own. These copies live here, outside
`.omao/`, so the shipped corpus can point at a concrete, schema-valid instance
that survives in the repo.

| File | What it demonstrates |
|---|---|
| `adr-0001-graphify-knowledge-wiki.json` | The accepted decision behind this skill — the Knowledge Wiki is built at `oma setup` with Graphify as the runtime query substrate. Validates against `schemas/ontology/adr.schema.json`. |

These are illustrative, not live state. The authoritative runtime instances are
authored into the user's `.omao/plans/adr/` at setup time.
