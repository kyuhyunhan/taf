#!/bin/bash
# G3-C2 — Server prompt SECURITY & SAFETY RULES
set -uo pipefail
PROMPT="$WORKDIR/server/src/services/openai/prompts/analyze.ts"
[[ -f "$PROMPT" ]] || exit 0
grep -q 'SECURITY & SAFETY RULES' "$PROMPT" || exit 0
ANTI_LEAK=$(grep -c 'NEVER reveal' "$PROMPT" || true)
DELIMITER=$(grep -c 'INPUT_START' "$PROMPT" || true)
IDONTKNOW=$(grep -c 'Cannot determine\|I don.t know\|empty\|unintelligible' "$PROMPT" || true)
if [[ "$ANTI_LEAK" -gt 0 && "$DELIMITER" -gt 0 && "$IDONTKNOW" -gt 0 ]]; then
    # Check for adversarial test fixture
    if [[ -d "$WORKDIR/server/evals/adversarial" ]] || find "$WORKDIR/server/tests" -name '*adversarial*' -o -name '*jailbreak*' 2>/dev/null | grep -q .; then
        exit 3
    fi
    exit 2
fi
exit 1
