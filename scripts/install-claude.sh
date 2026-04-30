#!/usr/bin/env bash
# Shim preserved for backwards-compatibility. The real installer now lives at
# scripts/install/claude.sh. This file exists so existing docs, curl URLs, and
# muscle-memory invocations keep working for at least one minor release.
exec bash "$(dirname "$0")/install/claude.sh" "$@"
