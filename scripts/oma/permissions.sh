#!/usr/bin/env bash
# scripts/oma/permissions.sh — inspect the resolved permission chain.
#
# Subcommands:
#   show     Print the resolved deny set + auto_approve, with provenance:
#            which template/overlay each entry came from.
#   path     Print the absolute path of <project>/.omao/permissions.yaml,
#            create the parent directory if needed (so the user can
#            `$EDITOR (oma permissions path)` immediately).
#
# Reads .omao/profile.yaml from $PWD (or --project <dir>) for aws.environment.
# Honors OMA_PERMISSIONS_ENV as an override.

set -euo pipefail

REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/permissions.sh"

PROJECT_DIR="$PWD"
SUBCMD="show"
FORMAT=pretty

usage() {
    cat <<'EOF'
oma permissions — inspect resolved permission chain

Usage:
    oma permissions [show|path] [--project DIR] [--json]

Subcommands:
    show    Print the resolved deny set + auto_approve flags, with the
            originating layer (template, env overlay, or project overlay)
            for each entry.
    path    Print the path of <project>/.omao/permissions.yaml so the
            user can edit it (`$EDITOR $(oma permissions path)`).

Options:
    --project DIR   Project root that holds .omao/profile.yaml.
                    Default: current working directory.
    --json          Emit machine-readable JSON (show only).

Environment:
    OMA_PERMISSIONS_ENV   Override env (sandbox/staging/prod).
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        show|path) SUBCMD="$1"; shift ;;
        --project) PROJECT_DIR="$2"; shift 2 ;;
        --json)    FORMAT=json; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown arg: $1 (try --help)" ;;
    esac
done

# ---------------- path ----------------
if [ "$SUBCMD" = "path" ]; then
    target="$PROJECT_DIR/.omao/permissions.yaml"
    mkdir -p "$(dirname "$target")"
    printf '%s\n' "$target"
    exit 0
fi

# ---------------- show ----------------
profile="$PROJECT_DIR/.omao/profile.yaml"
env="${OMA_PERMISSIONS_ENV:-}"
if [ -z "$env" ]; then
    if [ ! -f "$profile" ]; then
        die "no .omao/profile.yaml at $PROJECT_DIR (run \`oma setup\` first or pass --project)"
    fi
    if command -v yq >/dev/null 2>&1; then
        env="$(yq -r '.aws.environment // ""' "$profile")"
    else
        env="$(python3 -c "import sys, yaml; print(yaml.safe_load(open(sys.argv[1])).get('aws',{}).get('environment',''))" "$profile" 2>/dev/null || true)"
    fi
fi
case "$env" in
    sandbox|staging|prod) ;;
    *) die "unsupported aws.environment: '$env' (sandbox|staging|prod)" ;;
esac

# Build provenance: resolve each layer in isolation so we know which entries
# come from where. Order: common.yaml, <env>.yaml-additions, overlay-add,
# overlay-remove (subtraction).
common_json="$(perms_yaml_to_json "$REPO_ROOT/templates/permissions/common.yaml")"
env_json="$(perms_yaml_to_json    "$REPO_ROOT/templates/permissions/${env}.yaml")"
overlay_path="$PROJECT_DIR/.omao/permissions.yaml"
overlay_json='{}'
overlay_present=0
if [ -f "$overlay_path" ]; then
    overlay_json="$(perms_yaml_to_json "$overlay_path")"
    overlay_present=1
fi

resolved_json="$(perms_resolve_with_overlays "$env" "$PROJECT_DIR")"

# Produce a per-entry provenance map: bucket -> [{pattern, source}, ...]
# source ∈ "common.yaml" | "<env>.yaml" | "overlay" .
prov_json="$(jq -n \
    --argjson c "$common_json" \
    --argjson e "$env_json" \
    --argjson o "$overlay_json" \
    --argjson r "$resolved_json" \
    --arg     env "$env" \
    '
    def annotate(bucket):
      ($r.deny[bucket] // []) | map(
        . as $p
        | {pattern: $p,
           source:
             (if (($c.deny // {})[bucket] // []) | index($p)
              then "common.yaml"
              elif (($e.deny // {})[bucket] // []) | index($p)
              then ($env + ".yaml")
              elif (($o.deny.add // {})[bucket] // []) | index($p)
              then "overlay"
              else "?" end)}
      );
    {
      bash:  annotate("bash"),
      edit:  annotate("edit"),
      write: annotate("write"),
      mcp:   annotate("mcp"),
      removed: ($o.deny.remove // {}),
      auto_approve: $r.auto_approve,
      env: $env,
      overlay_path: ($r._meta.overlay_path // null),
      overlay_applied: ($r._meta.overlay_applied // false),
      templates_chain: ($r._meta.templates // [])
    }
    ')"

if [ "$FORMAT" = "json" ]; then
    printf '%s\n' "$prov_json" | jq .
    exit 0
fi

# Pretty output
overlay_status="overlay : (none — create with: oma permissions path)"
if [ "$overlay_present" -eq 1 ]; then
    if [ "$(printf '%s' "$resolved_json" | jq -r '._meta.overlay_applied')" = "true" ]; then
        overlay_status="overlay : $overlay_path (applied)"
    else
        overlay_status="overlay : $overlay_path (present, no rules)"
    fi
fi

printf '\nResolved permission chain — %s\n' "$env"
printf '=========================\n'
printf '  env       : %s\n'   "$env"
printf '  templates : %s\n'   "$(printf '%s' "$prov_json" | jq -r '.templates_chain | join(" + ")')"
printf '  %s\n'                "$overlay_status"
printf '  autoApprove.readOnly     : %s\n' "$(printf '%s' "$prov_json" | jq -r '.auto_approve.read_only')"
printf '  autoApprove.fileWrites   : %s\n' "$(printf '%s' "$prov_json" | jq -r '.auto_approve.file_writes')"
printf '  autoApprove.bashCommands : %s\n' "$(printf '%s' "$prov_json" | jq -r '.auto_approve.bash_commands')"

for bucket in bash edit write mcp; do
    count="$(printf '%s' "$prov_json" | jq ".${bucket} | length")"
    printf '\n  deny.%-5s (%d):\n' "$bucket" "$count"
    printf '%s\n' "$prov_json" | jq -r ".${bucket}[] | \"    [\\(.source | (. + \"             \")[0:13])] \\(.pattern)\""
done

removed_total="$(printf '%s' "$prov_json" | jq '[.removed[]?] | add // [] | length')"
if [ "$removed_total" -gt 0 ]; then
    printf '\n  overlay removals (%d):\n' "$removed_total"
    for bucket in bash edit write mcp; do
        count="$(printf '%s' "$prov_json" | jq ".removed.${bucket} // [] | length")"
        if [ "$count" -gt 0 ]; then
            printf '    %s:\n' "$bucket"
            printf '%s\n' "$prov_json" | jq -r ".removed.${bucket}[] | \"      - \" + ."
        fi
    done
fi
printf '\n'
