#!/bin/bash
# pre-holds-edit.sh — PreToolUse hook for Write/Edit on .claude/holds.yaml.
#
# Enforces the pending-only invariant (decision: 2026-05-16):
#   `status: resolved` is NOT an allowed value in holds.yaml. A resolved
#   hold is a closure memory note under memory/cross-cutting/ plus a
#   deletion from this file — never an entry that lingers.
#
# Hook contract:
#   - Fires only when the tool_input.file_path ends in .claude/holds.yaml.
#   - For Write: inspects `content`. For Edit: inspects `new_string`.
#   - If the proposed content contains a non-comment line matching
#     `^\s*status:\s*resolved\b`, the hook blocks with a guidance reason.
#   - Otherwise exits 0 (allows the edit).
#
# This is a guardrail, not a substitute for the audit check —
# `audit-checks/holds-resolution-integrity.sh` catches the same drift
# that bypasses this hook (e.g. external editor, git checkout).

set -uo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tin = data.get('tool_input', {})
    print(tin.get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

case "$FILE_PATH" in
    */.claude/holds.yaml) ;;
    *) exit 0 ;;
esac

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tin = data.get('tool_input', {})
    # Write uses 'content'; Edit uses 'new_string'.
    print(tin.get('content') or tin.get('new_string') or '')
except Exception:
    pass
" 2>/dev/null)

# Match `status: resolved` on a non-comment line.
if echo "$CONTENT" | grep -qE '^[[:space:]]*status:[[:space:]]*resolved\b'; then
    cat <<'EOF'
{
  "decision": "block",
  "reason": "holds.yaml edit rejected: `status: resolved` is not an allowed value in the pending-only model. To resolve a hold: (1) write a closure note under memory/cross-cutting/ with filename `<ts>-hold-<hold-id>-closed.md`, get user sign-off; (2) DELETE the hold entry from holds.yaml. See header of holds.yaml for the contract, and 20260516T1500..T1507 for closure-note examples."
}
EOF
    exit 2
fi

exit 0
