#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> Building (release)…"
swift build -c release

APP="$ROOT/clipboardpass.app"
BIN="$ROOT/.build/release/clipboardpass"

echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/clipboardpass"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "==> Code signing (ad-hoc, hardened runtime)…"
codesign --force --options runtime --sign - "$APP"

echo "==> Done: $APP"
echo "    Run with:  open \"$APP\""
