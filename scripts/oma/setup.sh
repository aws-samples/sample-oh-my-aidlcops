#!/usr/bin/env bash
# scripts/oma/setup.sh — OMA easy-button setup.
#
# Interactive by default; scriptable via OMA_NON_INTERACTIVE=1 + env flags.
# All prompts have sane defaults so ENTER-ENTER-ENTER works.
#
# Steps:
#   1. detect environment (jq, python3, git, uvx, claude CLI, kiro CLI)
#   2. collect profile (7 Qs or env-driven)
#   3. init .omao/, write .omao/profile.yaml, validate
#   4. render seed ontology (budgets, deployments, risks)
#   5. install harness plugins (claude and/or kiro)
#   6. run `oma compile --all` (no-op if no *.oma.yaml yet)
#   7. run `oma doctor` and summarize
#
# Flags:
#   --non-interactive      never prompt; env variables or defaults only
#   --migrate              detect existing .omao/ without profile.yaml
#   --dry-run              print planned actions, make no changes
#   --skip-install         skip harness install (step 5)
#   --skip-doctor          skip final doctor run

set -euo pipefail

REPO_ROOT="${OMA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/profile.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/oma/_seed.sh"

PROJECT_DIR="$(pwd)"
NON_INTERACTIVE=0
MIGRATE=0
DRY_RUN=0
SKIP_INSTALL=0
SKIP_DOCTOR=0

while [ $# -gt 0 ]; do
    case "$1" in
        --non-interactive) NON_INTERACTIVE=1; shift ;;
        --migrate)         MIGRATE=1; shift ;;
        --dry-run)         DRY_RUN=1; shift ;;
        --skip-install)    SKIP_INSTALL=1; shift ;;
        --skip-doctor)     SKIP_DOCTOR=1; shift ;;
        -h|--help)         sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)                 die "unknown flag: $1 (try --help)" ;;
    esac
done

if [ "${OMA_NON_INTERACTIVE:-0}" = 1 ]; then NON_INTERACTIVE=1; fi
if [ ! -t 0 ]; then NON_INTERACTIVE=1; fi

step "OMA setup — AIDLC × AgenticOps easy button"
log  "repo root : $REPO_ROOT"
log  "project   : $PROJECT_DIR"
log  "mode      : $( [ $NON_INTERACTIVE = 1 ] && echo non-interactive || echo interactive )"

# -----------------------------------------------------------------------------
# Step 1 — preflight
# -----------------------------------------------------------------------------
for tool in jq git; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool missing: $tool"
done
if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found — profile validation and compile will be unavailable"
else
    # Check whether profile validation dependencies (pyyaml + jsonschema) are
    # available. If not, try a one-shot auto-install before the wizard runs.
    # Never attempt to modify the system interpreter — always use --user.
    if ! python3 -c 'import yaml, jsonschema' >/dev/null 2>&1; then
        if [ "${OMA_SKIP_DEPS_INSTALL:-0}" != "1" ] && command -v pip3 >/dev/null 2>&1; then
            step "installing validator deps (pyyaml, jsonschema) with pip3 --user"
            if pip3 install --user --quiet pyyaml jsonschema 2>/dev/null; then
                ok "installed pyyaml + jsonschema into user site-packages"
            else
                warn "could not auto-install pyyaml/jsonschema; profile schema validation will be skipped"
                warn "install manually with: pip3 install --user pyyaml jsonschema"
            fi
        else
            warn "pip3 missing or OMA_SKIP_DEPS_INSTALL=1 — profile schema validation will be skipped"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Step 2 — profile wizard
# -----------------------------------------------------------------------------
ask() {
    # ask VAR "prompt" "default"
    local __var="$1" __prompt="$2" __default="$3"
    local __existing
    __existing="$(eval "printf %s \${$__var:-}")"
    if [ -n "$__existing" ]; then
        printf -v "$__var" '%s' "$__existing"
        return
    fi
    if [ "$NON_INTERACTIVE" = 1 ]; then
        printf -v "$__var" '%s' "$__default"
        return
    fi
    local __answer
    if [ -n "$__default" ]; then
        read -r -p "? $__prompt [$__default]: " __answer
    else
        read -r -p "? $__prompt: " __answer
    fi
    [ -n "$__answer" ] || __answer="$__default"
    printf -v "$__var" '%s' "$__answer"
}

ask OMA_HARNESS        "Harness (claude-code/kiro/both)"           "${OMA_HARNESS:-claude-code}"

if [ "$NON_INTERACTIVE" = 0 ]; then
    cat >&2 <<'EOT'

# NOTE ─────────────────────────────────────────────────────────────────────
# The AWS values below are METADATA only — they describe which account this
# project targets. oma setup does NOT run `aws configure` or log you in.
# Actual AWS API access is controlled separately by:
#   • `aws configure` / `aws configure sso` (writes ~/.aws/credentials|config)
#   • AWS_PROFILE / AWS_ACCESS_KEY_ID / SSO token in the shell environment
# After setup, oma runs `aws sts get-caller-identity` to verify your shell
# can reach the account you entered and warns on mismatch.
# ──────────────────────────────────────────────────────────────────────────

EOT
fi

ask OMA_AWS_ACCOUNT    "AWS account id (12 digits, recorded in profile.yaml)" "${OMA_AWS_ACCOUNT:-123456789012}"
ask OMA_AWS_REGION     "AWS region"                                "${OMA_AWS_REGION:-ap-northeast-2}"
ask OMA_AWS_ENV        "Environment (sandbox/staging/prod)"        "${OMA_AWS_ENV:-sandbox}"
ask OMA_AIDLC_PHASE    "AIDLC entry phase (inception/construction/operations)" "${OMA_AIDLC_PHASE:-inception}"
ask OMA_APPROVAL_MODE  "Approval mode (interactive/ci-auto-approve-safe/strict)" "${OMA_APPROVAL_MODE:-interactive}"
ask OMA_BUDGET_USD     "Default monthly budget (USD)"              "${OMA_BUDGET_USD:-200}"
ask OMA_OBSERVABILITY  "Observability (langfuse-managed/langfuse-self-hosted/opentelemetry-only/none)" "${OMA_OBSERVABILITY:-langfuse-managed}"

# Derive harness primary/secondary.
case "$OMA_HARNESS" in
    claude-code) HARNESS_PRIMARY="claude-code"; HARNESS_SECONDARY="null" ;;
    kiro)        HARNESS_PRIMARY="kiro";        HARNESS_SECONDARY="null" ;;
    both)        HARNESS_PRIMARY="claude-code"; HARNESS_SECONDARY="kiro" ;;
    *)           die "invalid harness: $OMA_HARNESS (claude-code|kiro|both)" ;;
esac

CREATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# -----------------------------------------------------------------------------
# Step 3 — write profile.yaml
# -----------------------------------------------------------------------------
OMAO_DIR="$PROJECT_DIR/.omao"
mkdir -p "$OMAO_DIR"

if [ "$DRY_RUN" = 1 ]; then
    ok "dry-run: would write $OMAO_DIR/profile.yaml"
else
    tmpl="$REPO_ROOT/templates/profile/profile.yaml.tmpl"
    seed_render "$tmpl" "$OMAO_DIR/profile.yaml" \
        "CREATED_AT=$CREATED_AT" \
        "HARNESS_PRIMARY=$HARNESS_PRIMARY" \
        "HARNESS_SECONDARY=$HARNESS_SECONDARY" \
        "AWS_ACCOUNT_ID=$OMA_AWS_ACCOUNT" \
        "AWS_REGION=$OMA_AWS_REGION" \
        "AWS_PROFILE_NAME=default" \
        "AWS_ENVIRONMENT=$OMA_AWS_ENV" \
        "AIDLC_ENTRY_PHASE=$OMA_AIDLC_PHASE" \
        "AIDLC_STRICT_GATES=false" \
        "APPROVAL_MODE=$OMA_APPROVAL_MODE" \
        "APPROVAL_BLAST_RADIUS=single-account" \
        "BUDGET_MONTHLY_USD=$OMA_BUDGET_USD" \
        "BUDGET_WARN_PCT=80" \
        "BUDGET_BLOCK_PCT=100" \
        "OBSERVABILITY_MODE=$OMA_OBSERVABILITY" \
        "OBSERVABILITY_ENDPOINT=null" \
        "STAR_CONFIRMED=false"
    if command -v python3 >/dev/null 2>&1; then
        if profile_validate "$OMAO_DIR/profile.yaml"; then
            ok "profile schema: OK"
        else
            case $? in
                1) die "profile validation failed; aborting (edit $OMAO_DIR/profile.yaml or re-run oma setup)" ;;
                2) warn "profile validator dependencies missing — skipping schema check"
                   profile_install_validator_hint ;;
                *) die "profile validation returned unexpected status" ;;
            esac
        fi
    fi
    ok "wrote $OMAO_DIR/profile.yaml"
fi

# -----------------------------------------------------------------------------
# Step 4 — seed ontology
# -----------------------------------------------------------------------------
if [ "$DRY_RUN" = 0 ]; then
    seed_render "$REPO_ROOT/templates/ontology/budgets/default.json.tmpl" \
        "$OMAO_DIR/ontology/budgets/default.json" \
        "AWS_ACCOUNT_ID=$OMA_AWS_ACCOUNT" \
        "BUDGET_MONTHLY_USD=$OMA_BUDGET_USD" \
        "BUDGET_WARN_PCT=80"
    seed_render "$REPO_ROOT/templates/ontology/deployments/example.json.tmpl" \
        "$OMAO_DIR/ontology/deployments/example.json"
    seed_render "$REPO_ROOT/templates/ontology/risks/bootstrap.json.tmpl" \
        "$OMAO_DIR/ontology/risks/bootstrap.json"
    mkdir -p "$OMAO_DIR/ontology/incidents"
    : > "$OMAO_DIR/ontology/incidents/.gitkeep"
    if command -v python3 >/dev/null 2>&1; then
        seed_validate_ontology "$PROJECT_DIR" || die "seed ontology failed schema validation"
    fi
    ok "seeded $OMAO_DIR/ontology/"
else
    ok "dry-run: would seed ontology"
fi

# Copy base triggers.json if absent.
if [ ! -f "$OMAO_DIR/triggers.json" ] && [ -f "$REPO_ROOT/.omao/triggers.json" ]; then
    cp "$REPO_ROOT/.omao/triggers.json" "$OMAO_DIR/triggers.json"
    ok "copied triggers.json"
fi

# Bootstrap notepad + project-memory (reuse init-omao.sh for consistency).
if [ "$DRY_RUN" = 0 ]; then
    PROJECT_DIR="$PROJECT_DIR" bash "$REPO_ROOT/scripts/init-omao.sh" --force --dir "$PROJECT_DIR" >/dev/null 2>&1 || true
fi

# -----------------------------------------------------------------------------
# Step 5 — harness install
# -----------------------------------------------------------------------------
if [ "$SKIP_INSTALL" = 1 ]; then
    skip "skipping harness install"
elif [ "$DRY_RUN" = 1 ]; then
    ok "dry-run: would install $HARNESS_PRIMARY${HARNESS_SECONDARY:+ + $HARNESS_SECONDARY}"
else
    case "$HARNESS_PRIMARY" in
        claude-code) bash "$REPO_ROOT/scripts/install/claude.sh" || warn "claude install returned non-zero" ;;
        kiro)        bash "$REPO_ROOT/scripts/install/kiro.sh"   || warn "kiro install returned non-zero" ;;
    esac
    if [ "$HARNESS_SECONDARY" = "kiro" ]; then
        bash "$REPO_ROOT/scripts/install/kiro.sh" || warn "kiro install returned non-zero"
    fi
fi

# -----------------------------------------------------------------------------
# Step 6 — compile DSL (no-op if no *.oma.yaml or pyyaml missing)
# -----------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && [ "$DRY_RUN" = 0 ]; then
    dsl_found=0
    for f in "$REPO_ROOT"/plugins/*/*.oma.yaml; do
        [ -e "$f" ] && { dsl_found=1; break; }
    done
    if [ "$dsl_found" = 1 ]; then
        if python3 -c 'import yaml, jsonschema' >/dev/null 2>&1; then
            if (cd "$REPO_ROOT" && python3 -m tools.oma_compile --all) >/dev/null 2>&1; then
                ok "compiled DSL"
            else
                warn "oma compile returned non-zero; committed .mcp.json files retained"
            fi
        else
            skip "python yaml/jsonschema missing; using committed .mcp.json as-is"
        fi
    else
        skip "no *.oma.yaml found; compile skipped"
    fi
fi

# -----------------------------------------------------------------------------
# Step 7 — AWS credential sanity check (metadata vs. real access)
# -----------------------------------------------------------------------------
# profile.yaml records the INTENDED account id; real API access comes from
# ~/.aws/credentials, ~/.aws/config, or the AWS_* environment variables.
# Confirm the current shell's credentials resolve to the same account id
# the user entered. Never fails hard — only informs.
if [ "$DRY_RUN" = 0 ]; then
    if command -v aws >/dev/null 2>&1; then
        actual_account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
        if [ -z "$actual_account" ]; then
            warn "AWS credentials not configured in this shell"
            warn "  agenticops skills require active AWS access. Run one of:"
            warn "    aws configure                         # static keys"
            warn "    aws configure sso                     # SSO / IAM Identity Center"
            warn "    export AWS_PROFILE=<your-profile>     # reuse an existing profile"
        elif [ "$actual_account" != "$OMA_AWS_ACCOUNT" ]; then
            warn "AWS credentials resolve to account $actual_account but profile.yaml records $OMA_AWS_ACCOUNT"
            warn "  Either edit .omao/profile.yaml (.aws.account_id) or switch profile:"
            warn "    export AWS_PROFILE=<profile-for-${OMA_AWS_ACCOUNT}>"
        else
            ok "AWS credentials verified: account $actual_account matches profile"
        fi
    else
        skip "aws CLI not installed; skipping credential sanity check"
    fi
fi

# -----------------------------------------------------------------------------
# Step 8 — doctor summary
# -----------------------------------------------------------------------------
if [ "$SKIP_DOCTOR" = 1 ]; then
    skip "skipping doctor"
elif [ "$DRY_RUN" = 1 ]; then
    ok "dry-run: would run oma doctor"
else
    bash "$REPO_ROOT/scripts/oma/doctor.sh" || true
fi

# -----------------------------------------------------------------------------
# Next steps
# -----------------------------------------------------------------------------
cat <<EOF

Next steps:
    1. Verify setup:
       oma doctor
    2. Start your first AIDLC loop:
       claude
       > /oma:autopilot "your goal here"
    3. (Optional) Give the repo a star if OMA was useful:
       https://github.com/aws-samples/sample-oh-my-aidlcops
EOF
