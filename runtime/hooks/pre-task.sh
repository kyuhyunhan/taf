#!/bin/bash
# pre-task.sh — PreToolUse hook for the Task tool.
#
# Reads the subagent_type from the tool input and validates it against
# .claude/resolve/agents.yaml. If the agent is not declared, the hook
# BLOCKS the Task call.
#
# Blocking mechanism: exit 1 + decision JSON to deny. Claude Code reads
# the JSON to surface a clear message to the model.
#
# Allowlist source of truth: $FORGE_ROOT/.claude/resolve/agents.yaml#allowed (top-level keys).

INPUT=$(cat)

SUBAGENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tin = data.get('tool_input', {})
    print(tin.get('subagent_type', ''))
except Exception:
    pass
" 2>/dev/null)

# If we can't extract a subagent_type, let it through — fail open on
# parse errors so a malformed hook doesn't break the session.
if [[ -z "$SUBAGENT" ]]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_YAML="${FORGE_ROOT:-$SCRIPT_DIR/../..}/.claude/resolve/agents.yaml"

# Check membership via python (single source of truth: YAML parse).
ALLOWED=$(python3 - "$AGENTS_YAML" "$SUBAGENT" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    cfg = yaml.safe_load(f)
agents = cfg.get('allowed', {}) or {}
print('yes' if sys.argv[2] in agents else 'no')
PY
)

if [[ "$ALLOWED" != "yes" ]]; then
    # Block — emit decision JSON per Claude Code hook spec.
    cat <<EOF
{
  "decision": "block",
  "reason": "Agent '$SUBAGENT' is not in Lexio's agents.yaml allowlist. Update resolve/agents.yaml to add it, or pick a registered agent. Run scripts/resolve.sh --agents to see the allowed set."
}
EOF
    exit 2
fi

# ── blocking phase-gate (hold #3b, env-opt-in) ─────
# When FORGE_BLOCKING_PHASE_GATE=1, refuse any Task call if the most recent
# phase-advance.sh invocation recorded outcome=failed. This stops the
# model from invoking another sub-agent before fixing the failing gates.
#
# Default OFF (advisory unchanged) — set FORGE_BLOCKING_PHASE_GATE=1 in
# the session env to opt in. Rollout plan: validate across 2–3 real
# sessions, then promote to default-on (separate decision, separate
# commit).
if [[ "${FORGE_BLOCKING_PHASE_GATE:-0}" == "1" ]]; then
    PHASE_STATE_FILE="$SCRIPT_DIR/../.phase-state.json"
    if [[ -f "$PHASE_STATE_FILE" ]]; then
        OUTCOME=$(python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f:
        print(json.load(f).get('outcome', ''))
except Exception:
    print('')
" "$PHASE_STATE_FILE" 2>/dev/null)
        if [[ "$OUTCOME" == "failed" ]]; then
            PHASE_ID=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    print(json.load(f).get('phase_id', '?'))
" "$PHASE_STATE_FILE" 2>/dev/null)
            FAILED_GATES=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    print(', '.join(json.load(f).get('failed_required_gates', []) or ['(unknown)']))
" "$PHASE_STATE_FILE" 2>/dev/null)
            cat <<EOF
{
  "decision": "block",
  "reason": "BLOCKING PHASE GATE: prior phase '$PHASE_ID' failed required gate(s): $FAILED_GATES. Fix the failures, then re-run phase-advance.sh '$PHASE_ID'. To bypass for this session, unset FORGE_BLOCKING_PHASE_GATE."
}
EOF
            exit 2
        fi
    fi
fi

exit 0
