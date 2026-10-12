#!/bin/bash
# Build Thread and wrap the binary in a minimal app bundle at build/Thread.app.
# Needs only the Xcode Command Line Tools.
set -euo pipefail

cd "$(dirname "$0")/.."
swift build -c release

app="build/Thread.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Thread" "$app/Contents/MacOS/Thread"
cp Resources/Info.plist "$app/Contents/Info.plist"

# Ad-hoc signature: enough to run on this Mac, not to distribute.
codesign --force --sign - "$app"
echo "Built $app"
