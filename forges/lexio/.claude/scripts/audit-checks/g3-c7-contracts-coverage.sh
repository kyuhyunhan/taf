#!/bin/bash
# G3-C7 — .claude/resolve/contracts/<feature-id>.yaml per shipped feature.
#
# Rubric (mirrors .claude/resolve/audit.yaml#G3-C7):
#   0: no contracts directory (or empty)
#   1: directory exists but <8 contracts (heuristic: less than half of
#      the established feature catalog at time of writing — 16 contracts)
#   2: >=8 contracts AND not every contract ID referenced in a test file
#   3: +every contract ID appears in >=1 test file
#
# "Feature coverage" denominator: lexio has no separate feature
# registry — the contracts directory IS the feature catalog by
# construction. So we use contract count as the proxy for feature
# coverage (heuristic threshold = half of the established catalog).
# Level 2 vs 3 is the test-linkage discriminator, which IS objectively
# measurable.
#
# Test file scope: anything under $WORKDIR/LexioTests, LexioUITests,
# server/tests, server/evals. Match contract IDs case-sensitively as
# `C-\d+` anywhere in the file (allows freeform comments like
# `* Contract: C-001 (telemetry)` as well as the suggested
# `// contract: C-001`).
#
# Exit code = rubric level.
set -uo pipefail

FORGE_ROOT="${FORGE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
CONTRACTS_DIR="$FORGE_ROOT/.claude/resolve/contracts"

# Level 0 — directory absent or empty
if [ ! -d "$CONTRACTS_DIR" ]; then
    echo "# G3-C7: contracts dir absent ($CONTRACTS_DIR)" >&2
    exit 0
fi

CONTRACT_FILES=$(find "$CONTRACTS_DIR" -maxdepth 1 -name 'C-*.yaml' 2>/dev/null)
CONTRACT_COUNT=$(echo "$CONTRACT_FILES" | grep -c . || true)

if [ "$CONTRACT_COUNT" -eq 0 ]; then
    echo "# G3-C7: contracts dir empty" >&2
    exit 0
fi

# Level 1 — exists but thin
if [ "$CONTRACT_COUNT" -lt 8 ]; then
    echo "# G3-C7: $CONTRACT_COUNT contracts (<8 = below feature-catalog threshold)" >&2
    exit 1
fi

# Extract contract IDs (basename without .yaml; strip slug portion)
# Filename: C-NNN-slug.yaml → ID: C-NNN
CONTRACT_IDS=$(echo "$CONTRACT_FILES" | xargs -n1 basename 2>/dev/null \
    | sed -E 's/^(C-[0-9]+).*/\1/' | sort -u)

# Test scope
TEST_PATHS=()
[ -d "$WORKDIR/LexioTests" ] && TEST_PATHS+=("$WORKDIR/LexioTests")
[ -d "$WORKDIR/LexioUITests" ] && TEST_PATHS+=("$WORKDIR/LexioUITests")
[ -d "$WORKDIR/server/tests" ] && TEST_PATHS+=("$WORKDIR/server/tests")
[ -d "$WORKDIR/server/evals" ] && TEST_PATHS+=("$WORKDIR/server/evals")

if [ "${#TEST_PATHS[@]}" -eq 0 ]; then
    echo "# G3-C7: $CONTRACT_COUNT contracts, but no test directories found in $WORKDIR" >&2
    exit 2
fi

# Count referenced IDs
REFERENCED=0
UNREFERENCED=()
for id in $CONTRACT_IDS; do
    if grep -qrE "\\b${id}\\b" "${TEST_PATHS[@]}" 2>/dev/null; then
        REFERENCED=$((REFERENCED + 1))
    else
        UNREFERENCED+=("$id")
    fi
done

TOTAL_IDS=$(echo "$CONTRACT_IDS" | grep -c .)
echo "# G3-C7: $CONTRACT_COUNT contracts, $REFERENCED/$TOTAL_IDS referenced in tests" >&2
if [ "${#UNREFERENCED[@]}" -gt 0 ] && [ "${#UNREFERENCED[@]}" -le 10 ]; then
    echo "# unreferenced: ${UNREFERENCED[*]}" >&2
fi

# Level 3 — all referenced
if [ "$REFERENCED" -eq "$TOTAL_IDS" ]; then
    exit 3
fi

# Level 2 — exists at threshold, partial referenced
exit 2
