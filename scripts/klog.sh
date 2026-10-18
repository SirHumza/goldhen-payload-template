#!/bin/sh
# klog.sh - capture the PS4 kernel log (TCP :3232) to a file.
#
# klog is a live firehose: start this BEFORE you deploy and watch it while the
# payload loads. A payload's printf() lands here. See docs/DEBUGGING.md.
#
# Usage:
#   ./scripts/klog.sh                      # default host, port 3232, klog.txt
#   ./scripts/klog.sh 192.168.1.50
#   PS4_HOST=192.168.1.50 ./scripts/klog.sh
set -e
HOST="${1:-${PS4_HOST:-192.168.1.136}}"
PORT="${2:-${PS4_KLOG_PORT:-3232}}"
OUT="${3:-klog.txt}"

command -v nc >/dev/null 2>&1 || { echo "FAIL: nc (netcat) not found"; exit 1; }

echo "capturing $HOST:$PORT -> $OUT   (Ctrl-C to stop)"
nc "$HOST" "$PORT" | tee "$OUT"
