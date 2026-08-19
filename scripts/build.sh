#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path --sdk macosx)"
swift build -c release --product MacControl --sdk "$SDK"
swift build -c release --product smc-helper --sdk "$SDK"
swift build -c release --product MacControlWidgets --sdk "$SDK"

BIN="$ROOT/.build/release"
DIST="$ROOT/dist/MacControl.app"
PLUGIN="$DIST/Contents/PlugIns/MacControlWidgets.appex"
rm -rf "$DIST"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Resources" "$PLUGIN/Contents/MacOS"

cp "$BIN/MacControl" "$DIST/Contents/MacOS/MacControl"
cp "$BIN/smc-helper" "$DIST/Contents/MacOS/smc-helper"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$DIST/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$DIST/Contents/PkgInfo"

cp "$BIN/MacControlWidgets" "$PLUGIN/Contents/MacOS/MacControlWidgets"
cp "$ROOT/Resources/Widgets/Info.plist" "$PLUGIN/Contents/Info.plist"

codesign --force --sign - "$DIST" >/dev/null 2>&1 || true
codesign --force --sign - \
  --entitlements "$ROOT/Resources/Widgets/MacControlWidgets.entitlements" \
  "$PLUGIN" >/dev/null 2>&1 || true
echo "Built $DIST"
