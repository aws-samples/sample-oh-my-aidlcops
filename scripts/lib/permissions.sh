#!/usr/bin/env bash
# scripts/lib/permissions.sh — Permission-template loader shared by the Claude
# and Kiro install scripts.
#
# Reads templates/permissions/<env>.yaml, resolves `extends` against
# common.yaml, optionally applies a project-level overlay
# (`<project>/.omao/permissions.yaml`), and emits a single normalized JSON
# document on stdout that both install scripts can ingest without re-parsing
# YAML.
#
# Resolution chain (lowest → highest priority):
#   1. templates/permissions/common.yaml      (OMA repo, baseline floor)
#   2. templates/permissions/<env>.yaml       (OMA repo, environment defaults)
#   3. <project>/.omao/permissions.yaml       (user overlay, optional)
#
# The overlay can both add and remove rules, and override auto_approve flags.
# See perms_apply_overlay below for the schema.
#
# Output schema (always present, may be empty arrays):
#
# {
#   "auto_approve": {
#     "read_only":     <bool>,
#     "file_writes":   <bool>,
#     "bash_commands": <bool>
#   },
#   "deny": {
#     "bash":  ["<glob>", ...],
#     "edit":  ["<glob>", ...],
#     "write": ["<glob>", ...],
#     "mcp":   ["<glob>", ...]
#   },
#   "_meta": {
#     "env":       "<sandbox|staging|prod>",
#     "templates": ["common.yaml", "<env>.yaml"]
#   }
# }
#
# Depends on scripts/lib/log.sh. Uses yq (preferred) or python3 (fallback).

if [ "${__OMA_PERMS_LOADED:-0}" = 1 ]; then return 0; fi
__OMA_PERMS_LOADED=1

__oma_perms_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$__oma_perms_lib_dir/log.sh"

__oma_perms_repo_root() {
    (cd "$__oma_perms_lib_dir/../.." && pwd)
}

# perms_template_dir
# Prints the absolute path to templates/permissions/.
perms_template_dir() {
    printf '%s/templates/permissions' "$(__oma_perms_repo_root)"
}

# perms_yaml_to_json <yaml-file>
# yq preferred for speed; python3 fallback.
perms_yaml_to_json() {
    file="$1"
    [ -f "$file" ] || die "permission template not found: $file"
    if command -v yq >/dev/null 2>&1; then
        yq -o=json '.' "$file"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, json, yaml; json.dump(yaml.safe_load(open(sys.argv[1], encoding='utf-8')), sys.stdout)" "$file"
    else
        die "need yq or python3 to parse YAML (install: brew install yq)"
    fi
}

# perms_resolve <env>
# Resolve <env>.yaml plus its `extends` chain into a single normalized JSON
# document and print it on stdout. <env> ∈ sandbox|staging|prod.
#
# Resolution rules:
#   - Each template named in `extends` is resolved before the current file.
#   - `auto_approve.*` scalars: child overrides parent.
#   - `deny.{bash,edit,write,mcp}` arrays: child UNION parent (uniq, sorted).
#   - Unknown keys are ignored (forward-compat with future schema additions).
perms_resolve() {
    env="$1"
    case "$env" in
        sandbox|staging|prod) ;;
        *) die "perms_resolve: invalid env '$env' (sandbox|staging|prod)" ;;
    esac

    tmpl_dir="$(perms_template_dir)"
    main_yaml="$tmpl_dir/${env}.yaml"
    [ -f "$main_yaml" ] || die "permission template missing: $main_yaml"

    # Read main + extends (one level deep is sufficient for the current
    # schema; deeper trees would just need recursion). Build a list of
    # (name, json) pairs in resolution order: bases first, then main.
    main_json="$(perms_yaml_to_json "$main_yaml")"
    extends_list=$(printf '%s' "$main_json" | jq -r '.extends // [] | .[]?')

    # Collect base JSON docs in order.
    bases_json="[]"
    while IFS= read -r base; do
        [ -n "$base" ] || continue
        base_path="$tmpl_dir/$base"
        [ -f "$base_path" ] || die "extends references missing template: $base"
        base_json="$(perms_yaml_to_json "$base_path")"
        bases_json="$(printf '%s' "$bases_json" | jq --argjson b "$base_json" '. + [$b]')"
    done <<EOF
$extends_list
EOF

    # Merge: scalar override (last wins), arrays union+uniq+sort.
    #
    # auto_approve flags are tri-valued from jq's perspective: `true`, `false`,
    # or "key absent". The naive `(child.k // parent.k)` collapses both `false`
    # and missing into the parent value because jq's `//` treats `false` as a
    # null alternative. That blocks any child template from overriding `true`
    # back to `false` once a parent set it. Use explicit `has(k)` so a
    # `false` literal in the child is honored.
    final_json="$(jq -n \
        --argjson bases "$bases_json" \
        --argjson main "$main_json" \
        --arg env "$env" \
        --arg main_name "${env}.yaml" \
        '
        def union_uniq($a; $b): ($a + $b) | unique | sort;

        def pick_scalar(parent; child; key):
          if (child // {}) | has(key) then child[key] else parent[key] end;

        def merge_one(parent; child):
          {
            auto_approve: {
              read_only:     pick_scalar(parent.auto_approve // {}; child.auto_approve // {}; "read_only"),
              file_writes:   pick_scalar(parent.auto_approve // {}; child.auto_approve // {}; "file_writes"),
              bash_commands: pick_scalar(parent.auto_approve // {}; child.auto_approve // {}; "bash_commands")
            },
            deny: {
              bash:  union_uniq(parent.deny.bash  // []; child.deny.bash  // []),
              edit:  union_uniq(parent.deny.edit  // []; child.deny.edit  // []),
              write: union_uniq(parent.deny.write // []; child.deny.write // []),
              mcp:   union_uniq(parent.deny.mcp   // []; child.deny.mcp   // [])
            }
          };

        # Start with an empty default, fold bases left-to-right, then apply main.
        ($bases | reduce .[] as $b ({
            auto_approve: { read_only: false, file_writes: false, bash_commands: false },
            deny: { bash: [], edit: [], write: [], mcp: [] }
          }; merge_one(.; $b))) as $base_merged
        | merge_one($base_merged; $main)
        | . + { _meta: { env: $env } }
        ')"

    # Attach the resolved template chain (extends list + main file name).
    extends_array_json="$(printf '%s' "$main_json" | jq '.extends // []')"
    printf '%s' "$final_json" | jq \
        --argjson exts "$extends_array_json" \
        --arg main_name "${env}.yaml" \
        '._meta.templates = ($exts + [$main_name])'
}

# perms_apply_overlay <resolved-json> <overlay-yaml>
# Apply a project overlay (`<project>/.omao/permissions.yaml`) on top of an
# already-resolved template chain. Returns the merged JSON on stdout.
#
# Overlay schema (every key optional):
#
#   version: 1
#   deny:
#     add:                          # extra deny patterns to layer in
#       bash:  ["<pattern>", ...]
#       edit:  ["<glob>", ...]
#       write: ["<glob>", ...]
#       mcp:   ["<pattern>", ...]
#     remove:                       # patterns to subtract from the resolved set
#       bash:  ["<pattern>", ...]
#       edit:  ["<glob>", ...]
#       write: ["<glob>", ...]
#       mcp:   ["<pattern>", ...]
#   auto_approve:                   # any/all flags optional; explicit value wins
#     read_only:     <bool>
#     file_writes:   <bool>
#     bash_commands: <bool>
#
# Removals are exact-match against the post-merge deny array (after
# common+env have unioned). To remove a pattern that was introduced in
# common.yaml, copy the exact string into deny.remove.<bucket>.
perms_apply_overlay() {
    resolved="$1"
    overlay_yaml="$2"
    if [ ! -f "$overlay_yaml" ]; then
        printf '%s' "$resolved"
        return 0
    fi
    overlay_json="$(perms_yaml_to_json "$overlay_yaml")"

    jq -n \
        --argjson r "$resolved" \
        --argjson o "$overlay_json" \
        --arg     overlay_path "$overlay_yaml" \
        '
        def union_uniq($a; $b): ($a + $b) | unique | sort;
        def subtract($a; $b): $a | map(select(. as $x | $b | index($x) | not));
        def pick_scalar(parent; child; key):
          if (child // {}) | has(key) then child[key] else parent[key] end;

        ($o.deny.add    // {}) as $add
        | ($o.deny.remove // {}) as $rm
        | ($o.auto_approve // {}) as $aa
        | $r
        | .deny.bash  = subtract(union_uniq(.deny.bash  // []; $add.bash  // []); $rm.bash  // [])
        | .deny.edit  = subtract(union_uniq(.deny.edit  // []; $add.edit  // []); $rm.edit  // [])
        | .deny.write = subtract(union_uniq(.deny.write // []; $add.write // []); $rm.write // [])
        | .deny.mcp   = subtract(union_uniq(.deny.mcp   // []; $add.mcp   // []); $rm.mcp   // [])
        | .auto_approve.read_only     = pick_scalar(.auto_approve // {}; $aa; "read_only")
        | .auto_approve.file_writes   = pick_scalar(.auto_approve // {}; $aa; "file_writes")
        | .auto_approve.bash_commands = pick_scalar(.auto_approve // {}; $aa; "bash_commands")
        | ._meta.overlay_path = $overlay_path
        | ._meta.overlay_applied = (
            ((($add.bash  // []) | length) > 0) or
            ((($add.edit  // []) | length) > 0) or
            ((($add.write // []) | length) > 0) or
            ((($add.mcp   // []) | length) > 0) or
            ((($rm.bash   // []) | length) > 0) or
            ((($rm.edit   // []) | length) > 0) or
            ((($rm.write  // []) | length) > 0) or
            ((($rm.mcp    // []) | length) > 0) or
            (($aa | keys | length) > 0)
          )
        '
}

# perms_resolve_with_overlays <env> [<project_dir>]
# Resolve templates/<env>.yaml and (if present) layer the project overlay
# from <project_dir>/.omao/permissions.yaml on top. <project_dir> defaults
# to $PWD.
perms_resolve_with_overlays() {
    env="$1"
    project_dir="${2:-$PWD}"
    base_resolved="$(perms_resolve "$env")"
    overlay="$project_dir/.omao/permissions.yaml"
    perms_apply_overlay "$base_resolved" "$overlay"
}

# perms_resolve_for_profile <profile.yaml>
# Convenience: read aws.environment from a profile.yaml and call perms_resolve.
perms_resolve_for_profile() {
    profile="$1"
    [ -f "$profile" ] || die "profile not found: $profile"
    env=""
    if command -v yq >/dev/null 2>&1; then
        env="$(yq -r '.aws.environment // ""' "$profile")"
    elif command -v python3 >/dev/null 2>&1; then
        env="$(python3 -c "import sys, yaml; d=yaml.safe_load(open(sys.argv[1])); print(d.get('aws',{}).get('environment',''))" "$profile")"
    else
        die "need yq or python3 to read profile.yaml"
    fi
    if [ -z "$env" ]; then
        warn "profile $profile has no aws.environment; defaulting to sandbox"
        env="sandbox"
    fi
    perms_resolve "$env"
}

# perms_to_claude_deny <resolved-json>
# Translate the abstract deny set into Claude Code permission strings.
# Stdin: resolved JSON. Stdout: JSON array of strings ready to merge into
# settings.json `permissions.deny`.
perms_to_claude_deny() {
    jq '
        ((.deny.bash  // []) | map("Bash("  + . + ")"))
        + ((.deny.edit  // []) | map("Edit("  + . + ")"))
        + ((.deny.write // []) | map("Write(" + . + ")"))
        + (.deny.mcp   // [])
        | unique
    '
}

# perms_to_kiro_autoapprove <resolved-json>
# Stdin: resolved JSON. Stdout: JSON object suitable for Kiro cli.json /
# agent.json `autoApprove` field.
perms_to_kiro_autoapprove() {
    jq -r '
        {
          readOnly:      .auto_approve.read_only,
          fileWrites:    .auto_approve.file_writes,
          bashCommands:  .auto_approve.bash_commands
        }
    '
}

# perms_overlay_drift <project_dir> [<user_home>]
# Compare .omao/permissions.yaml mtime against OMA-owned sentinels created
# by install_permissions:
#
#   <user_home>/.claude/.oma-permissions-applied-at   (claude install)
#   <user_home>/.kiro/.oma-permissions-applied-at     (kiro install)
#
# Print a comma-separated list of sentinels that pre-date the overlay
# (overlay newer → drift) on stdout. Empty stdout means "no drift".
#
# Why a sentinel instead of comparing against settings.json: Claude Code
# and Kiro both touch their own settings files for unrelated reasons
# (session telemetry, model cache, last-used timestamps). A sentinel
# OMA owns is the only mtime that genuinely tracks "when did
# install_permissions last apply the overlay". A harness with no
# sentinel is treated as "never installed" — no false-positive drift
# alerts on a Kiro-less workstation.
#
# Pure mtime check — no YAML parsing, no side effects.
perms_overlay_drift() {
    project_dir="${1:-$PWD}"
    user_home="${2:-$HOME}"
    overlay="$project_dir/.omao/permissions.yaml"
    [ -f "$overlay" ] || return 0
    overlay_mtime=$(stat -f %m "$overlay" 2>/dev/null || stat -c %Y "$overlay" 2>/dev/null || echo 0)
    drifted=""
    for sentinel in \
        "$user_home/.claude/.oma-permissions-applied-at" \
        "$user_home/.kiro/.oma-permissions-applied-at"; do
        [ -f "$sentinel" ] || continue   # never installed for this harness
        sentinel_mtime=$(stat -f %m "$sentinel" 2>/dev/null || stat -c %Y "$sentinel" 2>/dev/null || echo 0)
        if [ "$overlay_mtime" -gt "$sentinel_mtime" ]; then
            label="${sentinel/#$user_home/~}"
            drifted+="${drifted:+, }$label"
        fi
    done
    printf '%s' "$drifted"
}

# perms_print_summary <resolved-json>
# Human-readable one-screen summary, stderr-friendly. Used by install scripts.
perms_print_summary() {
    json="$1"
    printf '%s' "$json" | jq -r '
        "  env       : " + ._meta.env,
        "  templates : " + (._meta.templates | join(" + ")),
        "  deny.bash : " + ((.deny.bash  // []) | length | tostring) + " patterns",
        "  deny.edit : " + ((.deny.edit  // []) | length | tostring) + " globs",
        "  deny.write: " + ((.deny.write // []) | length | tostring) + " globs",
        "  deny.mcp  : " + ((.deny.mcp   // []) | length | tostring) + " patterns",
        "  autoApprove.readOnly     : " + (.auto_approve.read_only     | tostring),
        "  autoApprove.fileWrites   : " + (.auto_approve.file_writes   | tostring),
        "  autoApprove.bashCommands : " + (.auto_approve.bash_commands | tostring)
    '
}
