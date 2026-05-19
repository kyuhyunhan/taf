#!/bin/bash
# Gate: release-installed
# Pass when /Applications/Lexio.app exists, its CFBundleShortVersionString
# matches MARKETING_VERSION in the workdir project.pbxproj, and the Lexio
# process is running.
#
# When to expect this gate to PASS without a fresh release:
#   - Server-only or docs-only changes — MARKETING_VERSION untouched,
#     so installed version still matches and the previously-installed
#     binary remains correct.
#
# When this gate legitimately FAILS:
#   - Client code changed + MARKETING_VERSION bumped + release-client
#     phase was skipped → installed binary is stale (this is the L-3
#     failure mode the gate exists to catch).
#   - Lexio process not running at verify time — a possible
#     false-positive if the user has Lexio quit on purpose. Bypass via
#     `LEXIO_SKIP_RELEASE_GATE=1` when known OK.

set -euo pipefail

if [ "${LEXIO_SKIP_RELEASE_GATE:-0}" = "1" ]; then
    echo "release-installed: SKIPPED (LEXIO_SKIP_RELEASE_GATE=1)"
    exit 0
fi

: "${WORKDIR:?WORKDIR must be set (see settings.local.json.example)}"
APP="/Applications/Lexio.app"
PBXPROJ="$WORKDIR/Lexio.xcodeproj/project.pbxproj"

if [ ! -d "$APP" ]; then
    echo "release-installed: $APP not found" >&2
    exit 1
fi

INSTALLED="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)"
if [ -z "$INSTALLED" ]; then
    echo "release-installed: cannot read installed CFBundleShortVersionString" >&2
    exit 1
fi

DECLARED="$(grep -m1 'MARKETING_VERSION =' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/')"
if [ -z "$DECLARED" ]; then
    echo "release-installed: cannot read MARKETING_VERSION from $PBXPROJ" >&2
    exit 1
fi

if [ "$INSTALLED" != "$DECLARED" ]; then
    echo "release-installed: version mismatch — installed=$INSTALLED declared=$DECLARED" >&2
    exit 1
fi

if ! pgrep -x Lexio >/dev/null; then
    echo "release-installed: Lexio is not running" >&2
    exit 1
fi

echo "release-installed: OK (version $INSTALLED, PID $(pgrep -x Lexio))"
