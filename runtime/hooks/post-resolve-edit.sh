#!/bin/bash
# PostToolUse hook — runs after Write/Edit. Fires lint-workflow.sh
# only when the edited file is part of the resolve system (resolve/*,
# scripts/*, skills/*/SKILL.md). Keeps lint cost off Swift edits.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

case "$FILE_PATH" in
    */forges/lexio/.claude/resolve/*|*/forges/lexio/.claude/scripts/*|*/forges/lexio/.claude/skills/*)
        ;;
    *)
        exit 0
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="$SCRIPT_DIR/../scripts/lint-workflow.sh"
if [[ ! -x "$LINT" ]]; then
    exit 0
fi

# Run lint silently on success; emit summary on failure.
OUTPUT=$("$LINT" 2>&1)
if [[ $? -eq 0 ]]; then
    exit 0
fi

echo "── resolve lint failures ──" >&2
echo "$OUTPUT" | grep "✗" | head -10 >&2
exit 0   # never block on lint findings; just surface.
