#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"
if [[ "$(uname -m)" == "x86_64" ]]; then
    TARGET="x86_64-apple-macosx14.0"
fi

BUILD_DIR="$ROOT/.build/release"
BIN="$BUILD_DIR/Nook"
APP="$ROOT/dist/Nook.app"

mkdir -p "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling Nook…"
swiftc -parse-as-library -O -whole-module-optimization \
    -sdk "$SDK" -target "$TARGET" \
    "$ROOT"/Sources/NookKit/*.swift \
    "$ROOT"/Sources/Nook/*.swift \
    -o "$BIN" \
    -framework AppKit \
    -framework SwiftUI \
    -framework Carbon \
    -framework NaturalLanguage \
    -framework Security

cp "$BIN" "$APP/Contents/MacOS/Nook"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [[ -f "$ROOT/Resources/Nook.icns" ]]; then
    cp "$ROOT/Resources/Nook.icns" "$APP/Contents/Resources/Nook.icns"
fi

chmod +x "$APP/Contents/MacOS/Nook"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || {
    echo "Ad-hoc code signing failed" >&2
    exit 1
}

echo "Built $APP"
