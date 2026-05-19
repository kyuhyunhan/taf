#!/bin/bash
# unit.sh — LexioTests gate (Swift Testing + XCTest).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE_DIR="$(cd "$SCRIPT_DIR/../../resolve" && pwd)"
source "$SCRIPT_DIR/../lib/read-yaml.sh"

GATES_YAML="$RESOLVE_DIR/gates.yaml"
GATE_ID="unit"

CMD=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.command")
CWD=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.cwd")
PASS_PATTERN=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.pass_pattern")
TIMEOUT=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.timeout_seconds")

echo "── gate: $GATE_ID ─────────────────────────────"
echo "  cmd: $CMD"
echo "  cwd: $CWD"

cd "$CWD" || { echo "  ✗ cwd not accessible"; exit 1; }

OUTPUT=$(timeout "${TIMEOUT:-240}" bash -c "$CMD" 2>&1) || true

if echo "$OUTPUT" | grep -qE "$PASS_PATTERN"; then
    PASSED=$(echo "$OUTPUT" | grep -c " passed " || true)
    echo "  ✓ $GATE_ID passed ($PASSED test cases)"
    exit 0
fi

echo "  ✗ $GATE_ID FAILED" >&2
echo "$OUTPUT" | grep -E "(error:|FAILED|failed)" | head -20 >&2
exit 1
