#!/bin/bash
# G1-C7 — production-code commits go through Task delegation, not direct
# Edit/Write. Measured by attribution trailers in the last 10 commits that
# touch Lexio/ or server/src/.
#
# Signal hierarchy:
#   strong  — `Authored-By-Agent:` (specific taa journeyman named)
#   weak    — `Co-Authored-By: Claude` (LLM-assisted, agent unknown)
#   none    — neither trailer
#
# Score:
#   0  any-signal <25%
#   1  any-signal 25–50%, OR strong <50%
#   2  any-signal ≥75% AND strong ≥50%
#   3  strong ≥90%
#
# `$WORKDIR` is exported by audit.sh before sub-script invocation.

set -uo pipefail

: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"

if [ ! -d "$WORKDIR/.git" ]; then
    echo "[g1-c7] WORKDIR=$WORKDIR is not a git repo" >&2
    exit 2
fi

# Last 10 commits touching production code. Portable (no mapfile / bash 4).
shas=$(git -C "$WORKDIR" log --pretty=format:'%H' -10 -- 'Lexio/*' 'server/src/*' 2>/dev/null)
total=$(echo "$shas" | grep -c .)

if [ "$total" -eq 0 ]; then
    echo "[g1-c7] no production-code commits found" >&2
    exit 2
fi

strong=0
weak=0
for sha in $shas; do
    body=$(git -C "$WORKDIR" show -s --format='%B' "$sha" 2>/dev/null)
    if echo "$body" | grep -q '^Authored-By-Agent:'; then
        strong=$((strong + 1))
    elif echo "$body" | grep -q '^Co-Authored-By: Claude'; then
        weak=$((weak + 1))
    fi
done

any=$((strong + weak))
strong_pct=$((100 * strong / total))
any_pct=$((100 * any / total))

echo "[g1-c7] last $total prod-code commits: strong=$strong (${strong_pct}%), weak=$weak, any=$any (${any_pct}%)" >&2

# Score from the table above.
if [ "$strong_pct" -ge 90 ]; then exit 3; fi
if [ "$any_pct" -ge 75 ] && [ "$strong_pct" -ge 50 ]; then exit 2; fi
if [ "$any_pct" -ge 25 ]; then exit 1; fi
exit 0
