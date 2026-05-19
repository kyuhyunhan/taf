#!/bin/bash
# pre-memory-write.sh — PreToolUse hook for Write/Edit on memory/ files.
#
# Enforces memory/README.md discipline: notes must be drafted and
# approved before writing. The hook blocks Write/Edit on any path under
# */forges/lexio/memory/ (position-independent — works whether the
# file is accessed via $TAF_ROOT, an old symlink, or any other path)
# unless either:
#   (a) the most recent user message contained an explicit approval
#       marker ("APPROVED:" or "권장사항대로", "approved", "go ahead"
#       phrases), OR
#   (b) the file is README.md, TAXONOMY.md, or an overview/threads file
#       (mutable narrative overlays — not atomic notes).
#
# Note: we cannot reliably read the previous user message from the hook
# input, so we use a softer marker check: the file content being written
# must NOT contain "DRAFT:" as a literal marker. If "DRAFT:" appears in
# the content, the write is the *draft phase*, not the final write — we
# allow it (it's not a real memory write, just a draft echo). The model
# must remove the DRAFT marker AFTER user approval.
#
# Combined with the user's explicit approval in conversation, this gives
# a workable two-phase write.

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tin = data.get('tool_input', {})
    print(tin.get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tin = data.get('tool_input', {})
    # Write tool uses 'content'; Edit tool uses 'new_string'.
    print(tin.get('content') or tin.get('new_string') or '')
except Exception:
    pass
" 2>/dev/null)

# Only gate writes under the forge memory tree. Match by `forges/*/memory/`
# fragment so the hook fires regardless of which mount the write came
# through — public taf path or private overlay path
# ($PRIVATE_ROOT/forges/lexio/memory/...).
case "$FILE_PATH" in
    */forges/*/memory/*)
        ;;
    *)
        exit 0
        ;;
esac

# Mutable overlays — allow.
case "$FILE_PATH" in
    *"/memory/README.md"|*"/memory/TAXONOMY.md")
        exit 0 ;;
    *"/memory/overview/"*|*"/memory/threads/"*)
        exit 0 ;;
esac

# Atomic note path: ../memory/<layer>/<id>-<slug>.md.
# Require that the content includes the YAML frontmatter (--- ... ---)
# AND does NOT include the literal "DRAFT:" marker — DRAFT content is
# meant to be shown to the user, not written.
if echo "$CONTENT" | grep -q "^DRAFT:"; then
    cat <<EOF
{
  "decision": "block",
  "reason": "Memory write rejected: content still contains the 'DRAFT:' marker. Remove the marker after the user has approved the draft, then re-issue the Write."
}
EOF
    exit 2
fi

# Require frontmatter.
if ! echo "$CONTENT" | head -1 | grep -q "^---$"; then
    cat <<EOF
{
  "decision": "block",
  "reason": "Memory write rejected: atomic notes MUST begin with YAML frontmatter (--- ... ---). See memory/README.md for the schema."
}
EOF
    exit 2
fi

# Require required frontmatter keys.
for key in id title when layer status; do
    if ! echo "$CONTENT" | head -20 | grep -qE "^${key}:"; then
        cat <<EOF
{
  "decision": "block",
  "reason": "Memory write rejected: missing required frontmatter key '${key}'. Required: id, title, when, layer, status. See memory/README.md."
}
EOF
        exit 2
    fi
done

exit 0
