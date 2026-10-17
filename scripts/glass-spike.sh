#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx14.0"
if [[ "$(uname -m)" == "x86_64" ]]; then
    TARGET="x86_64-apple-macosx14.0"
fi

mkdir -p "$ROOT/.build/dev"
swiftc -parse-as-library \
    -sdk "$SDK" -target "$TARGET" \
    "$ROOT/Tools/GlassSpike/GlassSpike.swift" \
    -o "$ROOT/.build/dev/glass-spike" \
    -framework AppKit -framework SwiftUI

"$ROOT/.build/dev/glass-spike"
