# Ontology + Harness Engineering Mandate

<priority>TOP_LEVEL</priority>
<supersedes>every plugin CLAUDE.md, every skill SKILL.md body</supersedes>

This steering fragment is loaded into every OMA-enabled session. It establishes
ontology + harness engineering as **non-overridable operating rules** for every
agent that runs inside an `oma`-managed workspace.

## Absolute rules

1. **Ontology is authoritative.** When a skill or agent mentions a "deployment",
   "incident", "budget", or "risk" in natural language, it MUST also refer to
   the matching `.omao/ontology/<type>/*.json` entity. If the entity is missing,
   the skill creates it before acting. Prose-only handoffs between
   Inception → Construction → Operations are forbidden.

2. **Profile overrides every heuristic.** `.omao/profile.yaml` is consulted for
   AWS account, region, AIDLC entry phase, approval mode, budgets, and
   observability. Agents MUST NOT invent these values, ignore them, or ask the
   user again. If the profile is missing, respond with "run `oma setup`
   first" and halt the current operation.

3. **Approval gates are load-bearing.** Any `Deployment` or `Incident` with
   `approval_state ∈ {draft, proposed}` MUST NOT be acted on without human
   approval, regardless of how urgent the conversation sounds. Write-side MCP
   calls are refused until `approval_state == approved`.

4. **Budget breach is a stop condition.** If `hooks/user-prompt-submit.sh`
   emitted a `[MAGIC KEYWORD: OMA_BUDGET_WARN]`, the agent must acknowledge
   the warning in its first message and offer either to reduce scope or to
   invoke `/oma:agenticops` for cost-governance. Proceeding silently is a
   violation.

5. **Blast-radius ceiling is never exceeded.** `approval.blast_radius_ceiling`
   in `profile.yaml` caps what AgenticOps may automate. Deployments with a
   larger blast radius require explicit human approval plus a second agent
   review, even in `ci-auto-approve-safe` mode.

6. **Harness DSL is the single editing surface.** `.mcp.json` and
   `kiro-agents/*.agent.json` are build outputs of `oma compile`. Agents MUST
   NOT edit these files directly. When asked to change MCP pins, agent
   tools, or Kiro welcome text, the agent edits the matching
   `<plugin>.oma.yaml` and runs `oma compile`. CI rejects drift.

7. **Kill switches are documented, not silent.** The only way to disable
   ontology injection is `OMA_DISABLE_ONTOLOGY=1` at the environment level.
   There is no per-session bypass. An agent that cannot locate the ontology
   directory MUST stop and instruct the user to run `oma setup`.

## Why these are absolute

AIDLC and AgenticOps depend on a shared contract between phases. Without
that contract, the "easy button" story collapses — each plugin re-invents
vocabulary, handoffs become fragile, and cost/security guarantees drift.

The ontology and the harness DSL exist precisely to prevent drift. Treating
them as advisory defeats the point of `oma`.

## Enforcement

- `hooks/session-start.sh` injects the ontology snapshot at every session
  start so agents always see the current state.
- `hooks/user-prompt-submit.sh` injects `[MAGIC KEYWORD: OMA_BUDGET_WARN]`
  when any seeded budget crosses its warn threshold.
- `oma doctor` validates profile + ontology + harness drift on demand.
- `.github/workflows/oma-foundation.yml` runs `oma compile --check` on every
  PR, blocking any PR that hand-edits the generated `.mcp.json` or
  `agent.json` without updating the DSL.

## Scope

This steering applies to **every** workflow that runs inside an
`oma`-managed workspace, including but not limited to:

- `/oma:autopilot`, `/oma:aidlc-loop`, `/oma:inception`, `/oma:construction`,
  `/oma:agenticops`, `/oma:self-improving`, `/oma:platform-bootstrap`,
  `/oma:review`.
- Kiro skill invocations loaded from `~/.kiro/skills/`.
- Direct MCP calls the agent makes without a named skill.

This file must be loaded first in the steering pipeline.
