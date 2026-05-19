#!/bin/bash
# server-typecheck.sh — server/ TypeScript compiles without errors.
#
# Mirrors the contract declared in resolve/gates.yaml#gates.server-typecheck:
#   command: npx tsc --noEmit
#   cwd: ${WORKDIR}/server
#   pass_exit_code: 0
#   optional: true
#
# Exit 0 on pass, non-zero on type errors. Optional gates report failure but
# do not block phase advancement (phase-advance.sh handles that distinction).

set -uo pipefail

GATE_ID="server-typecheck"
: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
CWD="$WORKDIR/server"
CMD="npx tsc --noEmit"
TIMEOUT=120

echo "── gate: $GATE_ID ─────────────────────────────"
echo "  cmd: $CMD"
echo "  cwd: $CWD"

cd "$CWD" || { echo "  ✗ cwd not accessible"; exit 1; }

OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "  ✓ $GATE_ID passed"
    exit 0
fi

echo "  ✗ $GATE_ID FAILED (exit $EXIT_CODE)" >&2
echo "$OUTPUT" | tail -30 >&2
exit "$EXIT_CODE"
