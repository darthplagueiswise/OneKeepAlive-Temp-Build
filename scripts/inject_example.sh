#!/bin/bash
set -euo pipefail
IPA_APP="${1:-Payload/App.app}"
DYLIB="${2:-OneKeepAlive.dylib}"
LC="@executable_path/Frameworks/OneKeepAlive.dylib"
mkdir -p "$IPA_APP/Frameworks"
cp "$DYLIB" "$IPA_APP/Frameworks/OneKeepAlive.dylib"
BIN="$IPA_APP/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$IPA_APP/Info.plist")"
if command -v insert_dylib >/dev/null 2>&1; then
  insert_dylib --weak --strip-codesig --inplace "$LC" "$BIN" || true
else
  vtool -add-load "$LC" -output "${BIN}.patched" "$BIN"
  mv "${BIN}.patched" "$BIN"
fi
echo "Done. Reassine o IPA."
