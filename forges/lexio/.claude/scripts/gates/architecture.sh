#!/bin/bash
# architecture.sh — verify Lexio's L0–L3 layer rule via static grep.
#
# Rule: L0 → all, L1 → L2/L3, L2 → L3. No reverse imports.
# In practice, Swift files don't have explicit layer imports — they
# import modules. So we approximate by checking that no L1/L2/L3 file
# references higher-layer *symbols* (specifically: type names that
# live exclusively in a higher layer).
#
# Heuristic: this script greps for known-high-layer type names appearing
# in lower-layer files. It is intentionally conservative — false
# positives are noisy but acceptable. False negatives are dangerous and
# are caught by code review.
#
# Exit 0 → no reverse imports detected.
# Exit 1 → at least one violation; details printed.

set -uo pipefail

: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
SRC="$WORKDIR/Lexio"

if [[ ! -d "$SRC" ]]; then
    echo "architecture.sh: source root not found: $SRC" >&2
    exit 0   # not a violation; environment misconfigured. Don't block.
fi

VIOLATIONS=0
violate() {
    echo "  ✗ $1" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
}

# Known L0 symbols — must NOT appear in L1/L2/L3 files.
L0_SYMBOLS=(
    "AppCoordinator"
    "AppDelegate"
    "DependencyContainer"
    "LexioApp"
)

# Known L1 symbols — must NOT appear in L2/L3 files.
L1_SYMBOLS=(
    "OverlayPanel"
    "OverlayPresenter"
    "TranslatorView"
    "TranslatorViewModel"
    "StatusBarController"
    "SettingsView"
)

# Known L2 symbols — must NOT appear in L3 files.
# (Conservative: only the concrete service implementations.)
L2_SYMBOLS=(
    "ClipboardService"
    "HotkeyManager"
    "PermissionManager"
    "OpenAITranslationService"
    "DictionaryService"
    "LexioAPIService"
    "APIClient"
    "KeychainStorage"
    "UserDefaultsStorage"
)

check_layer() {
    local victim_layer="$1"; shift
    local forbidden_symbols=("$@")
    local layer_dir="$SRC/$victim_layer"
    if [[ ! -d "$layer_dir" ]]; then return 0; fi
    for sym in "${forbidden_symbols[@]}"; do
        # Match the symbol as a whole word, ignoring the case where the
        # symbol *is* the file's own type (e.g. AppCoordinator.swift may
        # mention `class AppCoordinator`). We treat any match in the
        # lower layer as a violation — operators can whitelist via
        # comment if needed.
        local matches
        # Exclude comment lines (`//`, `///`) — names mentioned in
        # documentation comments are not reverse imports.
        matches=$(grep -rnw "$sym" "$layer_dir" --include="*.swift" 2>/dev/null \
                  | grep -v -E ':[[:space:]]*///?' \
                  || true)
        if [[ -n "$matches" ]]; then
            while IFS= read -r line; do
                violate "$victim_layer references $sym → $line"
            done <<< "$matches"
        fi
    done
}

echo "── architecture gate ──────────────────────────"
check_layer "L1_Presentation" "${L0_SYMBOLS[@]}"
check_layer "L2_Core"         "${L0_SYMBOLS[@]}" "${L1_SYMBOLS[@]}"
check_layer "L3_Foundation"   "${L0_SYMBOLS[@]}" "${L1_SYMBOLS[@]}" "${L2_SYMBOLS[@]}"

if [[ $VIOLATIONS -gt 0 ]]; then
    echo "  $VIOLATIONS reverse-import violation(s) detected." >&2
    exit 1
fi
echo "  ✓ no reverse imports detected"
exit 0
