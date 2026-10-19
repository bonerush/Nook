#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Nook.app/Contents/MacOS/Nook"

if [[ ! -x "$APP" ]]; then
    echo "Build first: ./scripts/build.sh" >&2
    exit 1
fi

pkill -f 'dist/Nook.app/Contents/MacOS/Nook' 2>/dev/null || true
sleep 0.4

measure() {
    local label="$1"
    shift
    "$APP" "$@" >/tmp/nook-benchmark.log 2>&1 &
    sleep 4
    local pid
    pid="$(pgrep -f 'dist/Nook.app/Contents/MacOS/Nook' | head -1)"
    if [[ -z "$pid" ]]; then
        echo "$label: failed to launch" >&2
        return 1
    fi
    local rss
    rss="$(ps -o rss= -p "$pid" | awk '{printf "%.0f", $1/1024}')"
    local cpu
    cpu="$(top -l 6 -s 1 -pid "$pid" -stats pid,cpu | awk -v p="$pid" '$1==p {sum+=$2; n++} END {if (n>0) printf "%.1f", sum/n; else print "0.0"}')"
    printf "%-10s  CPU %5s%%   RSS %5s MB\n" "$label" "$cpu" "$rss"
    kill "$pid" 2>/dev/null || true
    sleep 0.4
}

echo "Nook benchmark (preview data, no user script)"
echo "--------------------------------------------"
measure editor --preview-sample
measure playback --preview-sample --preview-start --no-backdrop
echo ""
echo "Numbers are RSS. macOS compresses part of it.
Numbers vary by display size and window count."
