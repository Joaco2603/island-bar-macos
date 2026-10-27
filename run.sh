#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build
BIN="$(swift build --show-bin-path)/IslandBar"
rm -rf IslandBar.app
mkdir -p IslandBar.app/Contents/MacOS
cp "$BIN" IslandBar.app/Contents/MacOS/IslandBar
cp Support/Info.plist IslandBar.app/Contents/Info.plist
open IslandBar.app
