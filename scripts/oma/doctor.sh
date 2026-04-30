#!/usr/bin/env bash
# scripts/oma/doctor.sh — OMA environment doctor.
#
# Runs 12 probes and emits a human-readable report (default) or
# a machine-readable JSON report (`--json`). Exit codes:
#   0 — all pass (skips allowed)
#   1 — at least one warning (no failures)
#   2 — at least one failure
#
# Probes:
#   bash-version, jq-installed, git-installed, python3-installed, uvx-installed,
#   claude-cli, kiro-cli, claude-settings, mcp-pin-integrity, aws-credentials,
#   profile-valid, ontology-valid

set -euo pipefail

REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"

FORMAT=pretty
PROJECT_DIR="$(pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --json)     FORMAT=json; shift ;;
        --project)  PROJECT_DIR="$2"; shift 2 ;;
        -h|--help)  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          die "unknown flag: $1" ;;
    esac
done

# -----------------------------------------------------------------------------
# Probe plumbing
# -----------------------------------------------------------------------------
PROBE_IDS=()
PROBE_LABELS=()
PROBE_STATUSES=()
PROBE_MESSAGES=()
PROBE_REMEDIATIONS=()

record() {
    PROBE_IDS+=("$1")
    PROBE_LABELS+=("$2")
    PROBE_STATUSES+=("$3")
    PROBE_MESSAGES+=("$4")
    PROBE_REMEDIATIONS+=("${5:-}")
}

# -----------------------------------------------------------------------------
# Individual probes
# -----------------------------------------------------------------------------
probe_bash_version() {
    v="$(bash --version | head -1 | sed -E 's/.*version ([0-9]+\.[0-9]+).*/\1/')"
    major="${v%%.*}"
    if [ "$major" -ge 4 ] 2>/dev/null; then
        record bash-version "Bash >= 4" pass "bash $v"
    else
        record bash-version "Bash >= 4" fail "bash $v (need 4+)" \
            "Install bash 4+: brew install bash (macOS) or apt install bash"
    fi
}

probe_cmd() {
    id="$1"; label="$2"; cmd="$3"; remedy="$4"; severity="${5:-fail}"
    if command -v "$cmd" >/dev/null 2>&1; then
        record "$id" "$label" pass "found: $(command -v "$cmd")"
    else
        record "$id" "$label" "$severity" "not in PATH" "$remedy"
    fi
}

probe_claude_settings() {
    path="$HOME/.claude/settings.json"
    if [ ! -f "$path" ]; then
        record claude-settings "Claude settings.json has OMA hooks" skip "no ~/.claude/settings.json yet" \
            "Run \`oma setup\` or \`bash scripts/install/claude.sh\`."
        return
    fi
    if command -v jq >/dev/null 2>&1 && \
       jq -e '.hooks // {} | to_entries[] | .value[] | .hooks[]? | select(.command | test("oh-my-aidlcops"))' "$path" >/dev/null 2>&1; then
        record claude-settings "Claude settings.json has OMA hooks" pass "hooks wired"
    else
        record claude-settings "Claude settings.json has OMA hooks" warn "OMA hooks not registered" \
            "Run \`oma setup\` or \`bash scripts/install/claude.sh\`."
    fi
}

probe_mcp_pins() {
    if ! command -v jq >/dev/null 2>&1; then
        record mcp-pin-integrity "MCP server versions pinned" skip "jq missing"
        return
    fi
    bad=0
    while IFS= read -r mcp; do
        [ -n "$mcp" ] || continue
        args=$(jq -c '.mcpServers[] | .args' "$mcp" 2>/dev/null || echo "[]")
        echo "$args" | grep -qE '==[0-9]+\.[0-9]+\.[0-9]+' || bad=$((bad + 1))
    done < <(find "$REPO_ROOT/plugins" -name '.mcp.json' -type f)
    if [ "$bad" -eq 0 ]; then
        record mcp-pin-integrity "MCP server versions pinned" pass "all .mcp.json entries pinned"
    else
        record mcp-pin-integrity "MCP server versions pinned" fail "$bad .mcp.json file(s) have unpinned args" \
            "Pin every MCP server to an explicit '==X.Y.Z'."
    fi
}

probe_aws_credentials() {
    if ! command -v aws >/dev/null 2>&1; then
        record aws-credentials "AWS credentials" skip "aws CLI not installed" \
            "Optional — install AWS CLI v2 and run \`aws configure\`."
        return
    fi
    if aws sts get-caller-identity >/dev/null 2>&1; then
        record aws-credentials "AWS credentials" pass "sts:GetCallerIdentity succeeded"
    else
        record aws-credentials "AWS credentials" warn "aws sts get-caller-identity failed" \
            "Run \`aws configure sso\` or \`aws configure\` with valid keys."
    fi
}

probe_profile_valid() {
    path="$PROJECT_DIR/.omao/profile.yaml"
    if [ ! -f "$path" ]; then
        record profile-valid ".omao/profile.yaml valid" warn "no profile yet" \
            "Run \`oma setup\` in this project directory."
        return
    fi
    # shellcheck disable=SC1091
    . "$REPO_ROOT/scripts/lib/profile.sh"
    if profile_validate "$path" 2>/dev/null; then
        record profile-valid ".omao/profile.yaml valid" pass "schema OK"
    else
        record profile-valid ".omao/profile.yaml valid" fail "schema violations" \
            "Run \`oma doctor\` output; then edit .omao/profile.yaml and re-run setup."
    fi
}

probe_ontology_valid() {
    dir="$PROJECT_DIR/.omao/ontology"
    if [ ! -d "$dir" ]; then
        record ontology-valid ".omao/ontology/ valid" skip "no ontology seed yet"
        return
    fi
    # shellcheck disable=SC1091
    . "$REPO_ROOT/scripts/oma/_seed.sh"
    if seed_validate_ontology "$PROJECT_DIR" 2>/dev/null; then
        record ontology-valid ".omao/ontology/ valid" pass "all seed instances valid"
    else
        record ontology-valid ".omao/ontology/ valid" fail "schema violations in seed ontology" \
            "Run \`python3 -m tools.oma_compile --help\` and inspect the seed files."
    fi
}

# -----------------------------------------------------------------------------
# Run all probes
# -----------------------------------------------------------------------------
probe_bash_version
probe_cmd jq-installed           "jq installed"      jq       "brew install jq (macOS) or apt install jq"
probe_cmd git-installed          "git installed"     git      "Install git via OS package manager"
probe_cmd python3-installed      "python3 installed" python3  "Install python3 (3.10+)"  warn
probe_cmd uvx-installed          "uvx installed (for MCP)" uvx "pipx install uv" warn
probe_cmd claude-cli             "Claude CLI"        claude   "https://docs.anthropic.com/claude/docs/claude-code" skip
probe_cmd kiro-cli               "Kiro CLI"          kiro     "https://kiro.dev" skip
probe_claude_settings
probe_mcp_pins
probe_aws_credentials
probe_profile_valid
probe_ontology_valid

# -----------------------------------------------------------------------------
# Emit report
# -----------------------------------------------------------------------------
PASS=0; WARN=0; FAIL=0; SKIP=0
for s in "${PROBE_STATUSES[@]}"; do
    case "$s" in
        pass) PASS=$((PASS+1)) ;;
        warn) WARN=$((WARN+1)) ;;
        fail) FAIL=$((FAIL+1)) ;;
        skip) SKIP=$((SKIP+1)) ;;
    esac
done

if [ "$FORMAT" = json ]; then
    jq -nc \
        --arg oma_version "${OMA_VERSION:-unknown}" \
        --arg generated_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson pass "$PASS" --argjson warn "$WARN" --argjson fail "$FAIL" --argjson skip "$SKIP" \
        --argjson probes "$(python3 - "${PROBE_IDS[@]}" <<PY 2>/dev/null
import json, sys
ids=sys.argv[1:]
labels="""$(IFS=$'\n'; printf '%s\n' "${PROBE_LABELS[@]}")"""
statuses="""$(IFS=$'\n'; printf '%s\n' "${PROBE_STATUSES[@]}")"""
messages="""$(IFS=$'\n'; printf '%s\n' "${PROBE_MESSAGES[@]}")"""
remediations="""$(IFS=$'\n'; printf '%s\n' "${PROBE_REMEDIATIONS[@]}")"""
labels=labels.strip().split('\n') if labels.strip() else []
statuses=statuses.strip().split('\n') if statuses.strip() else []
messages=messages.strip().split('\n') if messages.strip() else []
remediations=remediations.strip().split('\n') if remediations.strip() else []
out=[]
for i,pid in enumerate(ids):
    entry={"id":pid,"label":labels[i] if i<len(labels) else "","status":statuses[i] if i<len(statuses) else "skip","message":messages[i] if i<len(messages) else ""}
    if i<len(remediations) and remediations[i]:
        entry["remediation"]=remediations[i]
    out.append(entry)
json.dump(out, sys.stdout)
PY
        )" \
        '{version:"1", oma_version:$oma_version, generated_at:$generated_at, summary:{pass:$pass, warn:$warn, fail:$fail, skipped:$skip}, probes:$probes}'
else
    printf '\nOMA Doctor\n'
    printf '=========================\n'
    for i in "${!PROBE_IDS[@]}"; do
        id="${PROBE_IDS[$i]}"
        label="${PROBE_LABELS[$i]}"
        st="${PROBE_STATUSES[$i]}"
        msg="${PROBE_MESSAGES[$i]}"
        remedy="${PROBE_REMEDIATIONS[$i]}"
        case "$st" in
            pass) sym="$(printf '\033[32m✓\033[0m' 2>/dev/null || echo '[ok]')"   ;;
            warn) sym="$(printf '\033[33m!\033[0m' 2>/dev/null || echo '[!! ]')"  ;;
            fail) sym="$(printf '\033[31m✗\033[0m' 2>/dev/null || echo '[FAIL]')" ;;
            skip) sym="$(printf '\033[90m·\033[0m' 2>/dev/null || echo '[--]')"   ;;
        esac
        printf '  %s  %-40s  %s\n' "$sym" "$label" "$msg"
        [ -n "$remedy" ] && [ "$st" != pass ] && [ "$st" != skip ] && printf '         -> %s\n' "$remedy"
    done
    printf '\nSummary: %d pass, %d warn, %d fail, %d skip\n' "$PASS" "$WARN" "$FAIL" "$SKIP"
fi

if [ "$FAIL" -gt 0 ]; then exit 2; fi
if [ "$WARN" -gt 0 ]; then exit 1; fi
exit 0
