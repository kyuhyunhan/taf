#!/bin/bash
# G3-C4 — evals/golden/ with >=50 pairs
set -uo pipefail
DIR="$WORKDIR/server/evals/golden"
[[ -d "$DIR" ]] || exit 0
COUNT=$(find "$DIR" \( -name '*.jsonl' -o -name '*.json' \) -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
COUNT=${COUNT:-0}
echo "# golden_pairs=$COUNT" >&2
if [[ "$COUNT" -lt 25 ]]; then exit 1; fi
if [[ "$COUNT" -lt 50 ]]; then exit 1; fi
if [[ "$COUNT" -lt 150 ]]; then exit 2; fi
exit 3
