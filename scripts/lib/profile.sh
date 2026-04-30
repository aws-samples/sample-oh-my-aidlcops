#!/usr/bin/env bash
# scripts/lib/profile.sh — .omao/profile.yaml read/write/validate helpers.
# Depends on scripts/lib/log.sh. Uses yq (preferred) or python3 (fallback).

if [ "${__OMA_PROFILE_LOADED:-0}" = 1 ]; then return 0; fi
__OMA_PROFILE_LOADED=1

# Shared logger
__oma_profile_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$__oma_profile_lib_dir/log.sh"

__oma_profile_repo_root() {
    # scripts/lib/ -> scripts/ -> repo root
    (cd "$__oma_profile_lib_dir/../.." && pwd)
}

profile_path() {
    # $1 = project dir (default: $PWD)
    printf '%s/.omao/profile.yaml' "${1:-$PWD}"
}

# profile_yaml_to_json <yaml-file>
# Emits JSON on stdout. yq preferred for speed; python3 fallback.
profile_yaml_to_json() {
    file="$1"
    [ -f "$file" ] || die "profile not found: $file"
    if command -v yq >/dev/null 2>&1; then
        yq -o=json '.' "$file"
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, json, yaml; json.dump(yaml.safe_load(open(sys.argv[1], encoding='utf-8')), sys.stdout)" "$file"
    else
        die "need yq or python3 to parse YAML (install: brew install yq)"
    fi
}

# profile_json_to_yaml <json-string>
# Stdin: JSON. Stdout: YAML.
profile_json_to_yaml() {
    if command -v yq >/dev/null 2>&1; then
        yq -P '.'
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, json, yaml; yaml.safe_dump(json.load(sys.stdin), sys.stdout, sort_keys=False, default_flow_style=False)"
    else
        die "need yq or python3 to emit YAML"
    fi
}

# profile_validate <yaml-file>
# Exits 0 if valid, non-zero with message if not.
profile_validate() {
    file="$1"
    schema="$(__oma_profile_repo_root)/schemas/profile/profile.schema.json"
    [ -f "$file" ]   || die "profile not found: $file"
    [ -f "$schema" ] || die "schema missing: $schema"

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$file" "$schema" <<'PY' || return 1
import json
import sys

try:
    import yaml
except ImportError:
    print("[profile] python3 yaml module missing; install pyyaml", file=sys.stderr)
    sys.exit(2)
try:
    from jsonschema import Draft7Validator
except ImportError:
    print("[profile] python3 jsonschema missing; install jsonschema", file=sys.stderr)
    sys.exit(2)

doc = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
schema = json.load(open(sys.argv[2], encoding="utf-8"))
errors = sorted(Draft7Validator(schema).iter_errors(doc), key=lambda e: list(e.absolute_path))
if errors:
    for e in errors:
        path = ".".join(str(p) for p in e.absolute_path) or "(root)"
        print(f"[profile][invalid] {path}: {e.message}", file=sys.stderr)
    sys.exit(1)
PY
    else
        die "profile_validate requires python3 with pyyaml + jsonschema"
    fi
}

# profile_read <yaml-file> <jq-expr>
# Evaluates <jq-expr> against the YAML (as JSON) and prints the result.
profile_read() {
    file="$1"; expr="${2:-.}"
    profile_yaml_to_json "$file" | jq -r "$expr"
}

# profile_write <yaml-file> <key>=<value> [...]
# Simple key=value patcher. `key` is a jq path (e.g., .aws.region).
# Usage: profile_write .omao/profile.yaml .aws.region=us-east-1
profile_write() {
    file="$1"; shift
    [ -f "$file" ] || die "profile not found: $file"
    tmp="$(mktemp)"
    json="$(profile_yaml_to_json "$file")"
    for pair in "$@"; do
        key="${pair%%=*}"
        val="${pair#*=}"
        json="$(printf '%s' "$json" | jq --arg v "$val" "$key = \$v")"
    done
    printf '%s' "$json" | profile_json_to_yaml > "$tmp"
    mv "$tmp" "$file"
}
