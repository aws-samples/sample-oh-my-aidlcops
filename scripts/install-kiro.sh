#!/usr/bin/env bash
# Shim — the real installer is scripts/install/kiro.sh.
exec bash "$(dirname "$0")/install/kiro.sh" "$@"
