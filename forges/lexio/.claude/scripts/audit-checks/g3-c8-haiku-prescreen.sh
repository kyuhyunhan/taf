#!/bin/bash
# G3-C8 — Haiku-based jailbreak pre-screen
set -uo pipefail
HANDLER="$WORKDIR/server/src/handlers/analyze.ts"
[[ -f "$HANDLER" ]] || exit 0
if grep -q 'haiku\|prescreen\|pre-screen\|jailbreak' "$HANDLER"; then
    if grep -q 'reject\|block\|refuse' "$HANDLER"; then
        exit 2
    fi
    exit 1
fi
exit 0
