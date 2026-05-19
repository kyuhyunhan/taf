#!/bin/bash
# server-tests.sh — server/ unit tests pass (jest).
#
# Mirrors resolve/gates.yaml#gates.server-tests:
#   command: npm test
#   cwd: ${WORKDIR}/server
#   pass_exit_code: 0
#   optional: true

set -uo pipefail

GATE_ID="server-tests"
: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
CWD="$WORKDIR/server"
CMD="npm test --silent"
TIMEOUT=240

echo "── gate: $GATE_ID ─────────────────────────────"
echo "  cmd: $CMD"
echo "  cwd: $CWD"

cd "$CWD" || { echo "  ✗ cwd not accessible"; exit 1; }

OUTPUT=$(timeout "$TIMEOUT" bash -c "$CMD" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    PASSED=$(echo "$OUTPUT" | grep -Eo '[0-9]+ passed' | head -1 || true)
    echo "  ✓ $GATE_ID passed${PASSED:+ ($PASSED)}"
    exit 0
fi

echo "  ✗ $GATE_ID FAILED (exit $EXIT_CODE)" >&2
echo "$OUTPUT" | tail -40 >&2
exit "$EXIT_CODE"
