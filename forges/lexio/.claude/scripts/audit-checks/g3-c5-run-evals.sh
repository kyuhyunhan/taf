#!/bin/bash
# G3-C5 — run-evals.ts exists
set -uo pipefail
EVAL="$WORKDIR/server/evals/run-evals.ts"
[[ -f "$EVAL" ]] || exit 0
if grep -q 'rubric\|likert\|cosine' "$EVAL"; then
    if grep -q 'snapshot\|baseline' "$EVAL"; then
        exit 3
    fi
    exit 2
fi
exit 1
