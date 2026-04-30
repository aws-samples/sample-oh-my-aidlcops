#!/usr/bin/env bash
# Shim — the real installer is scripts/install/aidlc-extensions.sh.
exec bash "$(dirname "$0")/install/aidlc-extensions.sh" "$@"
