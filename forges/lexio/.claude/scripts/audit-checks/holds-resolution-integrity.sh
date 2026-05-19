#!/bin/bash
# holds-resolution-integrity.sh — invariant check for the pending-only
# holds.yaml model.
#
# Invariant (as of 2026-05-16):
#   .claude/holds.yaml MUST NOT contain `status: resolved` entries.
#   A resolved hold = (closure memory note under memory/cross-cutting/
#   matching `*-hold-<id>-closed.md`) + (deletion from holds.yaml).
#
# This script is the recurrence guard for that invariant. Run it from:
#   - CI / pre-commit (future)
#   - forge-harden `resolve` phase post-check
#   - ad-hoc audit
#
# Exits non-zero (and emits a one-line reason on stderr) if the
# invariant is violated. Silent + exit 0 when clean.

set -uo pipefail

FORGE_ROOT="${FORGE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
HOLDS_FILE="$FORGE_ROOT/.claude/holds.yaml"

if [ ! -f "$HOLDS_FILE" ]; then
    echo "holds-resolution-integrity: $HOLDS_FILE not found" >&2
    exit 2
fi

# Look for `status: resolved` anywhere in the file (commented lines are
# excluded — we strip leading whitespace then ignore lines starting #).
violations=$(grep -nE '^\s*status:\s*resolved\b' "$HOLDS_FILE" || true)

if [ -n "$violations" ]; then
    cat >&2 <<EOF
holds-resolution-integrity: VIOLATION — \`status: resolved\` entries found in $HOLDS_FILE.
The pending-only model requires resolved holds to be (a) recorded as a
closure memory note under memory/cross-cutting/ with filename
\`<ts>-hold-<id>-closed.md\` and (b) DELETED from holds.yaml.

Offending lines:
$violations

Remediation: for each offender, write the closure note (see
20260516T1500..T1507 for examples), then delete the entry from
holds.yaml. Re-run this check.
EOF
    exit 1
fi

exit 0
