#!/bin/bash
# G3-C1 — Structural unit test coverage
set -uo pipefail
LEXIO_TESTS=$(find "$WORKDIR/LexioTests" -name '*Tests*.swift' 2>/dev/null | wc -l | tr -d ' ')
SERVER_TESTS=$(find "$WORKDIR/server/tests" -name '*.test.ts' 2>/dev/null | wc -l | tr -d ' ')
PROD_SWIFT=$(find "$WORKDIR/Lexio" -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
PROD_SERVER=$(find "$WORKDIR/server/src" -name '*.ts' 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((LEXIO_TESTS + SERVER_TESTS))
PROD=$((PROD_SWIFT + PROD_SERVER))
[[ "$PROD" -eq 0 ]] && exit 0
RATIO=$(awk -v t="$TOTAL" -v p="$PROD" 'BEGIN{print t/p}')
echo "# tests=$TOTAL prod=$PROD ratio=$RATIO" >&2
awk -v r="$RATIO" 'BEGIN{
    if (r < 0.20) exit 0;
    if (r < 0.50) exit 1;
    if (r < 0.75) exit 2;
    exit 3;
}'
