#!/bin/bash
# G3-C3 — User input wrapped in [INPUT_START]/[INPUT_END]
set -uo pipefail
PROMPT="$WORKDIR/server/src/services/openai/prompts/analyze.ts"
[[ -f "$PROMPT" ]] || exit 0
grep -q 'INPUT_START' "$PROMPT" || exit 0
grep -q 'INPUT_END' "$PROMPT" || exit 0
# Check for delimiter stripping defense
if grep -q 'replace.*INPUT_START\|sanitize\|strip.*delimiter' "$PROMPT"; then
    exit 3
fi
exit 2
