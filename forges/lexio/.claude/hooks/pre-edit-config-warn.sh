#!/bin/bash
# pre-edit-config-warn.sh — PreToolUse hook for Write/Edit on serverless-IaC
# config files. Enforces hard rule 4 (r-source-not-config): confirm with
# the user before editing samconfig.toml / template.yaml / serverless.yml.
#
# Closes the declaration-vs-enforcement gap identified in the 2026-05-15
# audit: manifest.yaml#hard_rules.r-source-not-config previously claimed
# `enforced_by: pre-bash-guard.sh (warns on samconfig/template edits)`,
# but pre-bash-guard.sh had no such patterns AND those files are usually
# touched via Edit/Write tools (not Bash) anyway.
#
# Flow:
#   1. Model attempts Edit/Write on a matching config file.
#   2. This hook blocks with a reason that surfaces hard rule 4.
#   3. Model asks the user whether the change belongs in config or source.
#   4. On user confirmation, the model exports
#      `LEXIO_CONFIG_EDIT_APPROVED=1` via Bash and retries the edit.
#   5. This hook sees the env var set → exits 0 → edit proceeds.
#
# The env var is per-session (Bash subprocess persistence). A new session
# starts with no approval. This matches the spirit of hard rule 4: the
# *confirmation* is the load-bearing step, not the edit itself.

set -uo pipefail

# Approved for this session → proceed.
if [[ "${LEXIO_CONFIG_EDIT_APPROVED:-0}" == "1" ]]; then
    exit 0
fi

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except Exception:
    pass
" 2>/dev/null)

case "$(basename "$FILE_PATH")" in
    samconfig.toml|template.yaml|serverless.yml|serverless.yaml)
        cat <<EOF
{
  "decision": "block",
  "reason": "CONFIG_EDIT_REQUIRES_CONFIRMATION: '$FILE_PATH' is an IaC/build config file. Hard rule r-source-not-config (manifest.yaml#hard_rules) requires confirming with the user that the change belongs in config rather than source. Ask the user first; if confirmed, run \`export LEXIO_CONFIG_EDIT_APPROVED=1\` via Bash, then retry the edit. The approval persists for this session only."
}
EOF
        exit 2
        ;;
    *)
        exit 0
        ;;
esac
