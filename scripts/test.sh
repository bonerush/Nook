#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"
if [[ "$(uname -m)" == "x86_64" ]]; then
    TARGET="x86_64-apple-macosx14.0"
fi

mkdir -p "$ROOT/.build/dev"
echo "Running prompt-engine checks…"
swiftc -O \
    -sdk "$SDK" -target "$TARGET" \
    "$ROOT"/Sources/NookKit/*.swift \
    "$ROOT"/Tests/NookKitTests/*.swift \
    -o "$ROOT/.build/dev/nook-tests" \
    -framework AppKit \
    -framework NaturalLanguage \
    -framework Security

"$ROOT/.build/dev/nook-tests"
