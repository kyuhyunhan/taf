#!/bin/bash
# pre-edit-agent-required.sh — PreToolUse hook for Write|Edit.
#
# When the current maintain-loop phase has `agent_required: true` AND the
# tool input targets a production-code path (Lexio/ or server/src/), this
# hook blocks the direct Edit/Write call. The model must dispatch the
# change via Task (subagent_type=...) so it goes through the canonical
# named agent.
#
# Default OFF — opt in by setting `FORGE_ENFORCE_AGENT_REQUIRED=1` in
# the session env (or via settings.json#env for forge-scoped default-on,
# mirroring the blocking-phase-gate rollout in memory 20260514T0540).
#
# Rationale (G1-C5 of the forge rubric):
#   workflows/maintain-loop.yaml declares `agent_required` on
#   implement-server / implement-client / write-tests-client. Without
#   this hook, the metadata is advisory. The hook closes the loop.
#
# Failure mode protection:
#   - If phase-state.json absent → exit 0 (no current phase).
#   - If workflow YAML unparseable → exit 0 (fail open, never lock out).
#   - If file_path not extractable → exit 0.
#
# Block decision emits a Claude Code-formatted JSON refusal.

set -uo pipefail

# Default OFF — opt in via env.
[[ "${FORGE_ENFORCE_AGENT_REQUIRED:-0}" != "1" ]] && exit 0

# Resolves R-3 hold (runtime-hooks-script-dir-pattern-audit): the previous
# `$SCRIPT_DIR/..` derivation pointed FORGE_ROOT at taf/runtime/ rather
# than the forge root, silently disabling the enforcement.
: "${FORGE_ROOT:?FORGE_ROOT must be set (see settings.local.json.example)}"
PHASE_STATE="$FORGE_ROOT/.claude/.phase-state.json"
WORKFLOW="$FORGE_ROOT/.claude/resolve/workflows/maintain-loop.yaml"

[[ -f "$PHASE_STATE" ]] || exit 0
[[ -f "$WORKFLOW" ]] || exit 0

INPUT=$(cat)

# Extract phase id from state file
PHASE_ID=$(python3 -c "
import json, sys
try:
    print(json.load(open('$PHASE_STATE')).get('phase_id', ''))
except Exception:
    pass
" 2>/dev/null)

[[ -z "$PHASE_ID" ]] && exit 0

# Look up agent_required for that phase
AR=$(python3 - "$WORKFLOW" "$PHASE_ID" <<'PY'
import sys, yaml
try:
    spec = yaml.safe_load(open(sys.argv[1]))
    for p in (spec.get('phases') or []):
        if p.get('id') == sys.argv[2]:
            print('yes' if p.get('agent_required') else 'no')
            sys.exit(0)
except Exception:
    pass
print('no')
PY
)

[[ "$AR" != "yes" ]] && exit 0

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

# Only enforce on production paths
case "$FILE_PATH" in
    */Lexio/*|*/server/src/*)
        cat <<EOF
{
  "decision": "block",
  "reason": "AGENT_REQUIRED: maintain-loop phase '$PHASE_ID' requires production-code changes ($FILE_PATH) to be dispatched via Task (subagent_type=<named agent>). Compose the prompt with .claude/scripts/dispatch-agent.sh <agent_id> for the canonical prefix, or unset FORGE_ENFORCE_AGENT_REQUIRED to bypass for this session."
}
EOF
        exit 2
        ;;
    *)
        exit 0
        ;;
esac
