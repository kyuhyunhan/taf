#!/bin/bash
# SessionStart hook — emits Lexio session context driven by the resolve
# manifest. No hardcoded command lists; everything comes from YAML.
#
# Output protocol: JSON per Claude Code SessionStart spec.
#   - hookSpecificOutput.additionalContext → full forge banner (model only)
#   - systemMessage                        → one-line summary (user-visible)

set -uo pipefail

# Resolves R-3 hold (runtime-hooks-script-dir-pattern-audit): use the
# env-injected FORGE_ROOT instead of deriving it from $SCRIPT_DIR/..,
# which used to resolve to taf/runtime/ rather than the forge root.
: "${FORGE_ROOT:?FORGE_ROOT must be set (see settings.local.json.example)}"
: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
: "${PRIVATE_ROOT:?PRIVATE_ROOT must be set (see settings.local.json.example)}"
: "${TAS_ROOT:?TAS_ROOT must be set (see settings.local.json.example)}"
RESOLVE_DIR="$FORGE_ROOT/.claude/resolve"

BANNER=$(
set -uo pipefail

echo "Lexio forge session started"
echo "─────────────────────────────────"

BRANCH=$(git -C "$WORKDIR" branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
    echo "Workdir branch: $BRANCH"
fi

CHANGES=$(git -C "$WORKDIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$CHANGES" -gt 0 ]; then
    echo "Uncommitted changes: $CHANGES file(s)"
fi

echo "─────────────────────────────────"
echo "Resolve manifest: .claude/resolve/manifest.yaml"
echo "Memory:           \$PRIVATE_ROOT/memory/ (atomic notes — append-only)"
echo ""

# Emit available workflows + agents straight from YAML so this list
# never lies. Uses python directly (no source of read-yaml.sh needed
# in a session-init context — keeps the hook self-contained).

python3 - "$RESOLVE_DIR" <<'PY' 2>/dev/null || true
import os, sys, yaml
resolve_dir = sys.argv[1]
try:
    with open(os.path.join(resolve_dir, 'manifest.yaml')) as f:
        m = yaml.safe_load(f)
    with open(os.path.join(resolve_dir, 'agents.yaml')) as f:
        a = yaml.safe_load(f)
except Exception as e:
    print(f"(resolve manifest unreadable: {e})")
    sys.exit(0)

print("Workflows (invoke via the matching skill):")
for wid, wf in (m.get('workflows') or {}).items():
    skill = wf.get('skill', '?')
    desc = (wf.get('description') or '').split('\n')[0]
    print(f"  /{skill:<26}  {desc}")

print("")
print("Allowed agents (Task subagent_type):")
for aid, ag in (a.get('agents') or {}).items():
    when = (ag.get('when') or '').split('\n')[0]
    print(f"  {aid:<26}  {when[:80]}")

print("")
print("Hard rules — see manifest.yaml#hard_rules. Gate scripts under .claude/scripts/gates/.")
print("")
print("Phase boundaries: after each maintain-loop phase, before starting the next,")
print("invoke `.claude/scripts/phase-advance.sh <phase-id>` to run that phase's")
print("post_gates. Exits 0 on pass, 1 on required-gate failure, 2 on unknown id.")
print("Skipping this is what caused the 2026-05-12 retrospective's L-2 finding.")
PY

# ── Recent memory surfacing ──────────────────────────────────
# Brings forward-looking decision context into the session start banner so
# atomic notes don't sit dead (audit 2026-05-14: 57% unreferenced).
# Lists the 10 most recently-modified notes across all layers with their
# titles. Python-driven for portable mtime sort + frontmatter parsing.
echo "─────────────────────────────────"
echo "Recent memory (top 10 by mtime):"
# Memory now lives in the private overlay (taf phase-1b-1+).
python3 - "$PRIVATE_ROOT/memory" <<'PY'
import os, sys, re
root = sys.argv[1]
notes = []
for dirpath, dirnames, filenames in os.walk(root):
    if '_legacy' in dirpath:
        continue
    for fn in filenames:
        if not fn.endswith('.md'): continue
        if fn in ('README.md', 'TAXONOMY.md'): continue
        full = os.path.join(dirpath, fn)
        try:
            mtime = os.path.getmtime(full)
        except OSError:
            continue
        notes.append((mtime, full))
notes.sort(reverse=True)
for _, path in notes[:10]:
    layer = os.path.basename(os.path.dirname(path))
    title = '?'
    nid = '?'
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r'^title:\s*(.+)', line)
                if m: title = m.group(1).strip()[:68]
                m = re.match(r'^id:\s*(.+)', line)
                if m: nid = m.group(1).strip()
                if title != '?' and nid != '?': break
    except OSError:
        pass
    print(f"  [{layer:<13}] {nid:<14} — {title}")
print(f"  (full corpus: {len(notes)} notes under $PRIVATE_ROOT/memory/)")
PY

# ── Audit-axis goal score banner ──────────────────────────────
# Surfaces the current 4-axis score so every session begins with a
# concrete measure of forge maturity. Full report via `/forge-audit`.
# Goals declared in resolve/audit.yaml (2026-05-15 onward).
GOAL_SCRIPT="$TAS_ROOT/scripts/audit.sh"
if [ -x "$GOAL_SCRIPT" ]; then
    SCORE_LINE=$("$GOAL_SCRIPT" --json --auto-only 2>/dev/null \
        | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    overall = d.get('overall_mean', 0.0)
    passed = d.get('overall_passed', False)
    parts = []
    for aid, ax in d.get('axes', {}).items():
        short = aid.split('-')[1] if '-' in aid else aid
        parts.append(f'a{short}={ax[\"mean_score\"]:.1f}')
    color = 'GREEN' if passed else 'RED'
    print(f'  Forge goals: {color} (overall {overall:.2f}/3.00) — {\" \".join(parts)}')
except Exception:
    print('  Forge goals: (unable to score)')
" 2>/dev/null)
    echo "─────────────────────────────────"
    echo "$SCORE_LINE"
    echo "  Full report: /forge-audit  |  Rubric of one: /forge-audit --rubric <ID>"
fi

# ── Token-economy telemetry surface (G4-C7) ────────────────────
# Reads .session-token-log.jsonl and emits a 7-day running average of
# dispatch-agent.sh prompt-prefix sizes. A regression alarm (avg up
# >30% week-over-week) is the level-3 EXCEEDED ambition; not wired yet.
TOKEN_LOG="$FORGE_ROOT/.claude/.session-token-log.jsonl"
if [ -f "$TOKEN_LOG" ]; then
    python3 - "$TOKEN_LOG" <<'PY'
import json, sys, time, os
log_path = sys.argv[1]
now = time.time()
week_ago = now - 7 * 86400
prev_week_start = now - 14 * 86400
recent = []
prev = []
try:
    for line in open(log_path):
        try:
            obj = json.loads(line)
            ts_str = obj.get('timestamp', '')
            # parse ISO8601 UTC: YYYY-MM-DDTHH:MM:SSZ
            ts = time.mktime(time.strptime(ts_str.rstrip('Z'), '%Y-%m-%dT%H:%M:%S'))
            tokens = obj.get('total_approx_tokens', 0)
            if ts >= week_ago:
                recent.append(tokens)
            elif ts >= prev_week_start:
                prev.append(tokens)
        except Exception:
            continue
except OSError:
    pass
if not recent and not prev:
    sys.exit(0)
avg = sum(recent) / len(recent) if recent else 0
prev_avg = sum(prev) / len(prev) if prev else 0
delta = ((avg - prev_avg) / prev_avg * 100) if prev_avg else 0
marker = ""
if prev_avg and delta > 30:
    marker = "  ⚠ regression (avg ↑ 30%+ wk/wk)"
print(f"─────────────────────────────────")
print(f"  Token telemetry: 7-day avg {avg:.0f} tokens/dispatch over {len(recent)} dispatches{marker}")
PY
fi

echo "─────────────────────────────────"
)

# ── Derive a one-line summary for systemMessage (user-visible) ──
# Parse the captured banner instead of recomputing — single source of truth.
SUMMARY_BRANCH=$(printf '%s\n' "$BANNER" | awk -F': ' '/^Workdir branch:/ {print $2; exit}')
SUMMARY_GOAL=$(printf '%s\n' "$BANNER" | grep -oE 'Forge goals: (GREEN|RED|YELLOW) \(overall [0-9.]+/3\.00\)' | head -1 \
    | sed -E 's/Forge goals: ([A-Z]+) \(overall ([0-9.]+)\/3\.00\)/\2\/3.00 \1/')
SUMMARY_NOTES=$(printf '%s\n' "$BANNER" | grep -oE 'full corpus: [0-9]+ notes' | head -1 | awk '{print $3}')
SUMMARY="lexio forge · branch=${SUMMARY_BRANCH:-?} · goals ${SUMMARY_GOAL:-?} · ${SUMMARY_NOTES:-?} notes"

# ── Emit JSON output per Claude Code SessionStart hook spec ──
# additionalContext: model-only forge banner.
# systemMessage:     one-line summary shown to user in transcript.
export BANNER SUMMARY
python3 - <<'PY'
import json, os, sys
sys.stdout.write(json.dumps({
    "systemMessage": os.environ.get("SUMMARY", ""),
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": os.environ.get("BANNER", ""),
    },
}))
PY
