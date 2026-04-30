#!/usr/bin/env bash
# scripts/lib/log.sh — shared logger. Source this file, never execute it.
#
# Exports: log, warn, die, step, ok, skip
# All writers obey NO_COLOR and can be silenced via OMA_QUIET=1.

# Guard against double-sourcing.
if [ "${__OMA_LOG_LOADED:-0}" = 1 ]; then return 0; fi
__OMA_LOG_LOADED=1

__oma_color() {
    # $1 = ansi code, $2 = text
    if [ "${NO_COLOR:-}" ] || [ ! -t 2 ]; then
        printf '%s' "$2"
        return
    fi
    printf '\033[%sm%s\033[0m' "$1" "$2"
}

log()  { [ "${OMA_QUIET:-0}" = 1 ] && return 0; printf '%s %s\n' "$(__oma_color 36 '[oma]')" "$*" >&2; }
step() { [ "${OMA_QUIET:-0}" = 1 ] && return 0; printf '%s %s\n' "$(__oma_color 34 '[oma]')" "$*" >&2; }
ok()   { [ "${OMA_QUIET:-0}" = 1 ] && return 0; printf '%s %s\n' "$(__oma_color 32 '[ok] ')" "$*" >&2; }
skip() { [ "${OMA_QUIET:-0}" = 1 ] && return 0; printf '%s %s\n' "$(__oma_color 90 '[--] ')" "$*" >&2; }
warn() { printf '%s %s\n' "$(__oma_color 33 '[warn]')" "$*" >&2; }
die()  { printf '%s %s\n' "$(__oma_color 31 '[err] ')" "$*" >&2; exit 1; }
