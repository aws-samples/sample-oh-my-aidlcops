#!/usr/bin/env bash
# scripts/oma/run-workflow.sh — OMA workflow DAG runner (stub: prints plan, does not execute).
#
# Usage:
#   oma run-workflow <plugin> <workflow-name>
#
# Resolves the plugin's *.oma.yaml, extracts the named workflow, topo-sorts
# the DAG (Kahn's algorithm), and prints the execution order with agent_ref/skill_ref
# per step. Validates that agent_ref points at a declared agent. Exits 0 on clean DAG,
# 1 on missing workflow / cycle / unknown agent_ref.
#
# Future work: layer actual invocation (spawn agent, execute skill, pass context).

set -euo pipefail

OMA_REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck disable=SC1091
. "$OMA_REPO_ROOT/scripts/lib/log.sh"

usage() {
    cat <<EOF
Usage: oma run-workflow <plugin> <workflow-name>

Validates and prints the DAG execution plan for a named workflow.

Example:
    oma run-workflow agentic-platform platform-bootstrap

Environment:
    OMA_REPO_ROOT   Override repo root (default: auto-detect).
    OMA_DRY_RUN     Print plan but exit before invoking agents (default: already dry).
EOF
}

if [ $# -lt 2 ]; then
    usage
    exit 64  # EX_USAGE
fi

plugin_name="$1"
workflow_name="$2"

dsl_path="$OMA_REPO_ROOT/plugins/$plugin_name/$plugin_name.oma.yaml"
if [ ! -f "$dsl_path" ]; then
    die "plugin '$plugin_name' not found (expected $dsl_path)"
    exit 1
fi

# Require python3 + pyyaml.
if ! command -v python3 >/dev/null 2>&1; then
    die "python3 not found; install it to run workflow DAG resolution"
    exit 1
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    die "python3 package 'pyyaml' not found; install via: pip3 install pyyaml"
    exit 1
fi

# Inline Python script: load YAML, extract workflow, topo-sort, print execution order.
python3 - "$dsl_path" "$workflow_name" <<'EOPYTHON'
import sys
import yaml
from collections import defaultdict, deque

dsl_path = sys.argv[1]
workflow_name = sys.argv[2]

with open(dsl_path, 'r', encoding='utf-8') as fh:
    dsl = yaml.safe_load(fh)

if not isinstance(dsl, dict):
    print(f"error: {dsl_path} top-level must be a mapping", file=sys.stderr)
    sys.exit(1)

workflows = dsl.get('workflows') or {}
if workflow_name not in workflows:
    if not workflows:
        print(f"error: plugin {dsl.get('plugin', '?')} declares no workflows", file=sys.stderr)
    else:
        available = ', '.join(workflows.keys())
        print(f"error: workflow '{workflow_name}' not found (available: {available})", file=sys.stderr)
    sys.exit(1)

workflow = workflows[workflow_name]
steps = workflow.get('steps') or []
if not steps:
    print(f"error: workflow '{workflow_name}' has no steps", file=sys.stderr)
    sys.exit(1)

# Build step map and validate agent_ref resolution.
agent_ids = {a['id'] for a in (dsl.get('agents') or [])}
step_map = {}
for step in steps:
    sid = step['id']
    step_map[sid] = step
    agent_ref = step.get('agent_ref')
    if agent_ref and agent_ref not in agent_ids:
        print(f"error: step '{sid}' references undeclared agent_ref '{agent_ref}'", file=sys.stderr)
        sys.exit(1)

# Build dependency graph.
edges = defaultdict(list)
indeg = {sid: 0 for sid in step_map.keys()}
for step in steps:
    sid = step['id']
    for dep in step.get('depends_on') or []:
        if dep not in step_map:
            print(f"error: step '{sid}' depends_on '{dep}' which is not declared", file=sys.stderr)
            sys.exit(1)
        edges[dep].append(sid)
        indeg[sid] += 1

# Kahn's algorithm for topo sort.
queue = deque([sid for sid, deg in indeg.items() if deg == 0])
order = []
while queue:
    sid = queue.popleft()
    order.append(sid)
    for succ in edges[sid]:
        indeg[succ] -= 1
        if indeg[succ] == 0:
            queue.append(succ)

if len(order) != len(step_map):
    print(f"error: workflow '{workflow_name}' has a dependency cycle", file=sys.stderr)
    sys.exit(1)

# Print execution order.
print(f"execution order: {' -> '.join(order)}")
print()
for sid in order:
    step = step_map[sid]
    agent_ref = step.get('agent_ref', '(none)')
    skill_ref = step.get('skill_ref', '(none)')
    on_failure = step.get('on_failure', 'fail')
    print(f"  {sid}:")
    print(f"    agent_ref: {agent_ref}")
    print(f"    skill_ref: {skill_ref}")
    print(f"    on_failure: {on_failure}")
EOPYTHON

exit_code=$?
if [ $exit_code -ne 0 ]; then
    exit $exit_code
fi

ok "workflow '$workflow_name' DAG is valid"
step "stub: printing plan only; no invocation wired yet"
