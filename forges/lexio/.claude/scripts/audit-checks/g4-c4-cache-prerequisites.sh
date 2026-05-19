#!/bin/bash
# G4-C4 — prompt-caching prerequisites: stable, sized, in-use preamble.
#
# Rationale for the rewrite (vs. the original "check settings.json for
# cache_control markers"):
#   Claude Code is the host; its SDK config — including any cache_control
#   placement — is internal to the host, not surfaced via the per-forge
#   settings.json that we control. The rubric as originally written was
#   unmeasurable from our side. Rather than guess, this check measures
#   what the forge *can* observably control:
#
#     1. The agent-prompt-prefix.sh output is byte-deterministic across
#        invocations. Caching requires the cached content to be stable;
#        any nondeterminism breaks the cache key.
#     2. The dispatch wrapper has been invoked in this forge's telemetry.
#        Caching only matters if the stable content is actually re-sent
#        often enough to amortise the cost.
#     3. CLAUDE.md is slim (cross-ref G4-C6) so the auto-loaded session
#        context fits within whatever cache window the host applies.
#     4. (Bonus, score 3) An explicit caching-strategy note exists in
#        memory/cross-cutting/ so future operators know what's cached
#        where, even when the host SDK changes underneath us.
#
# What we still cannot measure: the actual cache-hit rate at the
# Anthropic API. That belongs to the host. If Claude Code eventually
# exposes a `cache_stats.jsonl` we can pivot this check to consume it.

set -uo pipefail

# FORGE_ROOT in this script is conventionally the .claude/ dir (one level
# below the forge root proper). Derive from script location when not set.
FORGE_ROOT="${FORGE_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PREFIX="$FORGE_ROOT/scripts/agent-prompt-prefix.sh"
LOG="$FORGE_ROOT/.session-token-log.jsonl"
WORKSPACE_CLAUDE_MD="$FORGE_ROOT/../CLAUDE.md"

# (1) deterministic
out1=$("$PREFIX" 2>/dev/null)
out2=$("$PREFIX" 2>/dev/null)
if [ "$out1" != "$out2" ]; then
    echo "[g4-c4] prefix output is NON-DETERMINISTIC — caching impossible" >&2
    exit 0
fi

# Useful diagnostics: prefix size + Anthropic cache eligibility heuristic.
prefix_bytes=$(printf '%s' "$out1" | wc -c | tr -d ' ')
prefix_tokens=$((prefix_bytes / 4))

# (2) dispatch wrapper has been used in this session
dispatches=0
if [ -f "$LOG" ]; then
    dispatches=$(wc -l < "$LOG" | tr -d ' ')
fi

# (3) CLAUDE.md slim (re-uses the G4-C6 threshold of 3.0k tokens; soft check)
claude_md_bytes=$(wc -c < "$WORKSPACE_CLAUDE_MD" 2>/dev/null | tr -d ' ' || echo 0)
claude_md_tokens=$((claude_md_bytes / 4))

# (4) explicit strategy doc — look for a memory note tagged with caching
: "${PRIVATE_ROOT:?PRIVATE_ROOT must be set (see settings.local.json.example)}"
strategy_note=$(grep -rln 'cache.*strategy\|prompt cache\|cache_control' \
    "$PRIVATE_ROOT/memory/cross-cutting/" 2>/dev/null | head -1)

# emit diagnostics
echo "[g4-c4] prefix: deterministic=yes, bytes=$prefix_bytes (~${prefix_tokens} tok)" >&2
echo "[g4-c4] dispatches recorded: $dispatches" >&2
echo "[g4-c4] CLAUDE.md: ~${claude_md_tokens} tok (G4-C6 threshold = 3000)" >&2
echo "[g4-c4] strategy note: ${strategy_note:-(none)}" >&2

# scoring
score=1   # deterministic floor

if [ "$dispatches" -ge 1 ] && [ "$claude_md_tokens" -lt 3000 ]; then
    score=2
fi

if [ "$score" -eq 2 ] && [ -n "$strategy_note" ]; then
    score=3
fi

exit "$score"
