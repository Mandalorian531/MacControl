#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/MacControl.app"
STAGE="$ROOT/dist/dmg-root"
DMG="$ROOT/dist/MacControl.dmg"

if [[ ! -d "$APP/Contents/MacOS" ]]; then
  "$ROOT/scripts/build.sh"
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/MacControl.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "MacControl" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGE"
echo "Built $DMG"
