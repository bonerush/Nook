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

KIT_FILES=()
while IFS= read -r file; do
    KIT_FILES+=("$file")
done < <(find "$ROOT/Sources/NookKit" -name '*.swift' -print | sort)

TEST_FILES=()
while IFS= read -r file; do
    TEST_FILES+=("$file")
done < <(find "$ROOT/Tests/NookKitTests" -name '*.swift' -print | sort)

echo "Running prompt-engine checks…"
swiftc -O \
    -sdk "$SDK" -target "$TARGET" \
    "${KIT_FILES[@]}" "${TEST_FILES[@]}" \
    -o "$ROOT/.build/dev/nook-tests" \
    -framework AppKit \
    -framework NaturalLanguage \
    -framework Security

"$ROOT/.build/dev/nook-tests"
