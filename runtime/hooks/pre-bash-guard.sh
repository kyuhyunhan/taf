#!/bin/bash
# PreToolUse hook — runs before any Bash tool call.
# Blocks commands matching known-dangerous patterns.

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | sed 's/"command":"//;s/"$//')

DANGEROUS_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "git push.*--force.*main"
    "git push.*--force.*master"
    "git reset --hard"
    "git clean -fd"
    "> /dev/sd"
    "mkfs"
    "dd if="
)

for PATTERN in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$PATTERN"; then
        echo "BLOCKED: Potentially dangerous command detected"
        echo "Pattern matched: $PATTERN"
        echo "Command: $COMMAND"
        exit 1
    fi
done

exit 0
