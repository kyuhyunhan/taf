#!/bin/bash
# auto-commit-repos.sh — Independent auto-commit of lexio + taf repos.
#
# Usage:
#   .claude/scripts/auto-commit-repos.sh <phase-id-label>
#
# Examples:
#   auto-commit-repos.sh implement-client     # called from phase-advance.sh
#   auto-commit-repos.sh session-end          # called from SessionEnd hook
#
# Behavior:
#   - lexio repo: commits the entire working tree if dirty.
#   - taf  repo: commits only the forges/lexio/ subtree if dirty.
#   - Two repos are independent — a failure in one never blocks the other.
#   - Clean tree → no-op (no empty commit).
#   - Failing-test states ARE committed by design (TDD history).
#   - Honours $LEXIO_AUTOCOMMIT_DISABLE=1 to opt out (return success without
#     committing). Useful for harden/retrospective workflows that prefer
#     manual squashing.
#
# Exit codes:
#   0 — all committed (or nothing to commit, or opt-out via env)
#   1 — at least one commit failed; the other may still have succeeded

set -uo pipefail

PHASE_ID_LABEL="${1:-unspecified}"

if [ "${LEXIO_AUTOCOMMIT_DISABLE:-}" = "1" ]; then
    echo "║ auto-commit DISABLED (LEXIO_AUTOCOMMIT_DISABLE=1) — skipped"
    exit 0
fi

auto_commit_repo() {
    local repo_label="$1"
    local repo_path="$2"
    local scope_pathspec="$3"   # "" = whole tree; otherwise a pathspec

    if [ ! -d "$repo_path/.git" ]; then
        echo "║ [$repo_label] not a git repo at $repo_path — skipped"
        return 0
    fi

    local status_args=("status" "--porcelain")
    local add_args=("add" "-A")
    if [ -n "$scope_pathspec" ]; then
        status_args+=("--" "$scope_pathspec")
        add_args+=("--" "$scope_pathspec")
    fi

    local porcelain
    porcelain=$(git -C "$repo_path" "${status_args[@]}")
    if [ -z "$porcelain" ]; then
        echo "║ [$repo_label] clean — no auto-commit"
        return 0
    fi

    git -C "$repo_path" "${add_args[@]}" >/dev/null 2>&1 || {
        echo "║ [$repo_label] git add failed — auto-commit skipped"
        return 1
    }

    local files_count files_list stat_line
    files_count=$(echo "$porcelain" | wc -l | tr -d ' ')
    files_list=$(echo "$porcelain" | awk '{print $NF}' | head -5 | paste -sd ' ' -)
    if [ "$files_count" -gt 5 ]; then
        files_list="$files_list … (+$((files_count - 5)) more)"
    fi
    stat_line=$(git -C "$repo_path" diff --cached --shortstat 2>/dev/null | sed 's/^ //')
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Map maintain-loop phase to its canonical agent (workflows/maintain-loop.yaml).
    # Phases without an associated agent (memory-update / plan / deploy-server /
    # release-client / commit / verify / session-end) produce no trailer.
    local agent_trailer=""
    case "$PHASE_ID_LABEL" in
        implement-server)   agent_trailer="Authored-By-Agent: aws-serverless-developer" ;;
        implement-client)   agent_trailer="Authored-By-Agent: swift-developer" ;;
        write-tests-client) agent_trailer="Authored-By-Agent: swift-test-writer" ;;
        review)             agent_trailer="Authored-By-Agent: code-reviewer" ;;
    esac

    local msg
    msg="chore(auto/${PHASE_ID_LABEL}): boundary @ ${ts}

Files (${files_count}): ${files_list}
${stat_line}

Auto-committed by auto-commit-repos.sh. Failing tests included by design (TDD history)."

    # Append agent trailer when the phase maps to one. Trailer goes on its own
    # paragraph so `git interpret-trailers --parse` picks it up.
    if [ -n "$agent_trailer" ]; then
        msg="${msg}

${agent_trailer}"
    fi

    if git -C "$repo_path" commit -q -m "$msg" 2>/tmp/auto-commit-$repo_label.err; then
        local sha
        sha=$(git -C "$repo_path" rev-parse --short HEAD)
        echo "║ [$repo_label] auto-committed $sha (${files_count} files)"
    else
        echo "║ [$repo_label] auto-commit FAILED"
        echo "║   tail:"
        tail -3 "/tmp/auto-commit-$repo_label.err" | sed 's/^/║     /'
        return 1
    fi
    return 0
}

: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
: "${TAF_ROOT:?TAF_ROOT must be set (see settings.local.json.example)}"

echo "╠═══ auto-commit (${PHASE_ID_LABEL}) ══════════════════════════════"
RC=0
auto_commit_repo "lexio" "$WORKDIR" "" || RC=1
auto_commit_repo "taf"   "$TAF_ROOT" "forges/lexio" || RC=1
exit "$RC"
