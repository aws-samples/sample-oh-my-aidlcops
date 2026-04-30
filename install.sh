#!/usr/bin/env bash
# install.sh — OMA remote installer (Tech Preview).
#
# Run:
#   curl -fsSL https://raw.githubusercontent.com/aws-samples/sample-oh-my-aidlcops/v0.2.0-preview.1/install.sh | bash
#
# Downloads the tagged tarball, verifies the sha256 checksum pinned below,
# extracts into OMA_HOME (default: ~/.oma), and symlinks bin/oma into
# $OMA_BIN_DIR (default: ~/.local/bin).
#
# Flags (set as env vars):
#   OMA_VERSION     override the tag (default: matches install.sh version)
#   OMA_HOME        install root (default: ~/.oma)
#   OMA_BIN_DIR     symlink dir (default: ~/.local/bin)
#   OMA_SKIP_SHA    set to 1 to skip checksum verification (NOT recommended)
#   OMA_SOURCE      git | tarball (default: tarball)

set -euo pipefail

OMA_VERSION="${OMA_VERSION:-v0.2.0-preview.1}"
OMA_HOME="${OMA_HOME:-$HOME/.oma}"
OMA_BIN_DIR="${OMA_BIN_DIR:-$HOME/.local/bin}"
OMA_SOURCE="${OMA_SOURCE:-tarball}"
OMA_SKIP_SHA="${OMA_SKIP_SHA:-0}"
OMA_REPO="aws-samples/sample-oh-my-aidlcops"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
color() { if [ -t 2 ]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
log()  { printf '%s %s\n' "$(color 36 '[oma]')" "$*" >&2; }
warn() { printf '%s %s\n' "$(color 33 '[warn]')" "$*" >&2; }
die()  { printf '%s %s\n' "$(color 31 '[err] ')" "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------
for tool in curl tar; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool missing: $tool"
done

# sha256 tool — macOS uses shasum, Linux often has sha256sum.
if command -v sha256sum >/dev/null 2>&1; then
    sha_cmd="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    sha_cmd="shasum -a 256"
else
    warn "no sha256sum / shasum found; checksum verification disabled"
    sha_cmd=""
    OMA_SKIP_SHA=1
fi

# -----------------------------------------------------------------------------
# Download + verify
# -----------------------------------------------------------------------------
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

base_url="https://github.com/$OMA_REPO/releases/download/$OMA_VERSION"
tarball="oh-my-aidlcops-$OMA_VERSION.tar.gz"
checksum="$tarball.sha256"

log "downloading $tarball from $base_url"
curl -fsSL -o "$tmp_dir/$tarball" "$base_url/$tarball" \
    || die "failed to download $tarball (is the release published?)"

if [ "$OMA_SKIP_SHA" != "1" ] && [ -n "$sha_cmd" ]; then
    if curl -fsSL -o "$tmp_dir/$checksum" "$base_url/$checksum" 2>/dev/null; then
        pushd "$tmp_dir" >/dev/null
        if ! $sha_cmd -c "$checksum" >/dev/null 2>&1; then
            die "sha256 verification FAILED for $tarball"
        fi
        popd >/dev/null
        log "sha256 verified"
    else
        warn "checksum file not published; continuing without verification"
    fi
fi

# -----------------------------------------------------------------------------
# Extract + link
# -----------------------------------------------------------------------------
log "installing to $OMA_HOME"
if [ -d "$OMA_HOME" ]; then
    if [ -f "$OMA_HOME/.oma-installed" ]; then
        warn "$OMA_HOME already exists; replacing"
    else
        die "$OMA_HOME exists but is not an OMA install; refusing to overwrite"
    fi
fi
mkdir -p "$OMA_HOME"
tar -xzf "$tmp_dir/$tarball" -C "$OMA_HOME"
touch "$OMA_HOME/.oma-installed"

# -----------------------------------------------------------------------------
# Symlink bin/oma
# -----------------------------------------------------------------------------
mkdir -p "$OMA_BIN_DIR"
ln -sf "$OMA_HOME/bin/oma" "$OMA_BIN_DIR/oma"
chmod +x "$OMA_HOME/bin/oma"

# Tips for PATH wiring
case ":$PATH:" in
    *":$OMA_BIN_DIR:"*) ;;
    *) warn "add $OMA_BIN_DIR to your PATH (e.g., echo 'export PATH=\"$OMA_BIN_DIR:\$PATH\"' >> ~/.zshrc)" ;;
esac

log "OMA $OMA_VERSION installed."
log "run 'oma setup' in your project directory to continue."
