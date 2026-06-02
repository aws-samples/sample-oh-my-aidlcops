---
name: diagram-authoring-standard
description: Mandatory diagram tooling standard for every OMA artifact. Picks the right tool per diagram intent (flow/sequence, infrastructure architecture, concept sketch) and bans parse-fragile inline syntax that silently fails to render.
inclusion: manual
---

# Diagram Authoring Standard (ABSOLUTE)

This standard is **load-bearing**. A diagram that fails to render is worse
than no diagram — it signals neglect and hides the very relationship it was
meant to show. The OMA philosophy page shipped a broken Mermaid flowchart
(unquoted `(6R)` in an edge label aborted the whole parse), so this rule
exists to make tool choice deterministic and rendering failures impossible
to merge.

## Pick the tool by intent — not by habit

| Diagram intent | REQUIRED tool | Why this tool | Source extension |
|---|---|---|---|
| **Flow / sequence / state** — control flow, request sequences, feedback loops, decision trees, lifecycle transitions | **[D2](https://d2lang.com/)** | Declarative, deterministic layout; stable text source diffs cleanly; renders to SVG at build time | `*.d2` |
| **Infrastructure / cloud architecture** — AWS topology, EKS/VPC layout, service-to-service runtime wiring, deployment targets | **[mingrammer Diagrams](https://diagrams.mingrammer.com/)** | First-class AWS/K8s node icons; architecture reads as architecture, not as boxes | `*.diagram.py` |
| **Concept / explanatory sketch** — mental models, 2-axis framings, "napkin" relationships, teaching aids | **[Excalidraw](https://excalidraw.com/)** | Hand-drawn feel communicates "this is a model, not a spec"; low-friction to revise | `*.excalidraw` (+ exported `*.svg`) |

> One intent, one tool. Do not draw an AWS architecture in D2, and do not
> draw a control-flow loop in Diagrams. If a diagram spans two intents,
> split it into two diagrams.

## Hard rules

1. **No tool substitution.** The mapping above is mandatory. "Mermaid is
   easier" is not an exception — Mermaid is being retired from new OMA
   diagrams precisely because its inline parser fails silently on common
   labels (parentheses, unquoted special characters), which is how the
   philosophy diagram broke.
2. **Commit the source, render the image.** The `.d2` / `.diagram.py` /
   `.excalidraw` source is the editable artifact and MUST be committed
   alongside the exported `.svg`/`.png`. Docs embed the rendered image,
   never the raw source as a code fence (build-time rendering for D2 and
   Diagrams is not wired into Docusaurus yet).
3. **Quote every label.** Until a diagram is migrated, any *remaining*
   Mermaid block MUST wrap every node and edge label in double quotes —
   `A["Inception · spec/stories"]`, `O -- "traces/metrics" --> SI` — and
   MUST NOT use raw `(`, `)`, `|...|` edge-label pipes with special
   characters, or bare `·`/`/` outside quotes. This is the minimum bar
   that keeps a diagram parseable.
4. **Verify before commit.** Build the docs (`cd docs && npm run build`)
   or render the source locally and confirm the diagram appears. A diagram
   that is not visually confirmed is treated as not done.
5. **English-only labels in committed diagrams** follows the repo-wide
   artifact rule. Conversation about a diagram may be in any language; the
   committed `.d2`/`.py`/`.svg` labels are English.

## Migration posture

Existing Mermaid diagrams are grandfathered **only** while they render.
The moment one is touched for content, migrate it to the intent-matched
tool above. New diagrams added after this standard lands MUST use the
required tool from day one — no new Mermaid.

## Tooling availability

These renderers are not yet part of the `oma doctor` probe set or the docs
build pipeline. Until they are:

- **D2**: install via `brew install d2` or the official script; render with
  `d2 diagram.d2 diagram.svg`.
- **Diagrams**: `pip install diagrams` (requires Graphviz `dot`, already
  present on most dev machines); render by running the `.diagram.py`.
- **Excalidraw**: author in the web app or the VS Code extension; export
  SVG with embedded scene so the source round-trips.

Wiring these into CI (a render-and-diff gate analogous to
`oma compile --check`) is tracked as follow-up harness work.

## References

- [D2](https://d2lang.com/) — declarative diagram language
- [mingrammer Diagrams](https://diagrams.mingrammer.com/) — diagrams as code, AWS/K8s icon sets
- [Excalidraw](https://excalidraw.com/) — virtual whiteboard for concept sketches
- [`workflows/ontology-harness-mandate.md`](./ontology-harness-mandate.md) — the absolute-rules companion this standard sits beside
