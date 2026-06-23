#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
"$ROOT/build.sh"

ZIP="clipboardpass-${VERSION}.zip"
rm -f "$ZIP"
# ditto preserves the code signature and bundles clipboardpass.app at the zip root.
ditto -c -k --sequesterRsrc --keepParent clipboardpass.app "$ZIP"

echo "==> Created $ZIP"
shasum -a 256 "$ZIP"