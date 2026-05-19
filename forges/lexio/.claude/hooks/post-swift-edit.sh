#!/bin/bash
# PostToolUse hook — runs after Write/Edit on a .swift file.
#
# Two responsibilities:
#   1. Run SwiftLint on the edited file (when installed).
#   2. Make violations visible to the model — current loose hook
#      silenced them with `|| true`. We now print a one-line summary
#      to stderr when lint reports something, so the model sees the
#      warning in the next tool result.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

if [[ "$FILE_PATH" != *.swift ]]; then
    exit 0
fi

if ! command -v swiftlint &>/dev/null; then
    # No SwiftLint installed — silent no-op (not a violation).
    exit 0
fi

OUTPUT=$(swiftlint lint --path "$FILE_PATH" --quiet 2>/dev/null || true)

if [[ -z "$OUTPUT" ]]; then
    exit 0
fi

# Surface violations on stderr so they appear in the next tool result.
# Truncate to first 10 lines to avoid context pollution.
echo "── SwiftLint findings for $(basename "$FILE_PATH") ──" >&2
echo "$OUTPUT" | head -10 >&2
COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')
if [[ "$COUNT" -gt 10 ]]; then
    echo "  … and $((COUNT - 10)) more line(s). Run swiftlint lint --path $FILE_PATH to see all." >&2
fi

# Always exit 0 — lint findings should not block the user's work.
exit 0
