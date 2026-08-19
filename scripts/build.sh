#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path --sdk macosx)"
swift build -c release --product MacControl --sdk "$SDK"
swift build -c release --product smc-helper --sdk "$SDK"

BIN="$ROOT/.build/release"
DIST="$ROOT/dist/MacControl.app"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources"

cp "$BIN/MacControl" "$DIST/Contents/MacOS/MacControl"
cp "$BIN/smc-helper" "$DIST/Contents/MacOS/smc-helper"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
echo -n "APPL????" > "$DIST/Contents/PkgInfo"

codesign --force --deep --sign - "$DIST" >/dev/null 2>&1 || true
echo "Built $DIST"
