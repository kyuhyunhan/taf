#!/bin/bash
# git-clean-status.sh — Lexio workdir has no uncommitted changes.
#
# Reads the command from gates.yaml (single source of truth) and uses
# its declared exit-code semantics. Mirrors the build.sh / unit.sh
# templates so behaviour is consistent across gates.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOLVE_DIR="$(cd "$SCRIPT_DIR/../../resolve" && pwd)"
source "$SCRIPT_DIR/../lib/read-yaml.sh"

GATES_YAML="$RESOLVE_DIR/gates.yaml"
GATE_ID="git-clean-status"

CMD=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.command")
CWD=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.cwd")
TIMEOUT=$(read_yaml "$GATES_YAML" "gates.${GATE_ID}.timeout_seconds")

echo "── gate: $GATE_ID ─────────────────────────────"
echo "  cwd: $CWD"

cd "$CWD" || { echo "  ✗ cwd not accessible"; exit 1; }

if timeout "${TIMEOUT:-10}" bash -c "$CMD"; then
    echo "  ✓ $GATE_ID passed"
    exit 0
fi

echo "  ✗ $GATE_ID FAILED — uncommitted changes present:" >&2
git status --short >&2
exit 1
