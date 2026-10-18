#!/bin/sh
# setup_sdk.sh - clone and build the ps4-payload-dev SDK from git.
#
# Do NOT use the release ZIP. The SDK's CRT gates startup on a per-firmware
# table (crt/patch.c); a firmware missing from that table makes the payload
# exit before main() with no log line, which looks identical to a loader
# failure. Release builds lag the offsets. Full story: docs/BUILDING.md and
# docs/LEARNINGS.md lesson 2.
#
# Usage:
#   ./scripts/setup_sdk.sh              # latest default branch
#   PS4_SDK_REF=<commit> ./scripts/setup_sdk.sh
#   PS4_SDK_DEST=~/ps4-payload-sdk ./scripts/setup_sdk.sh <ref>
#
# Requires: git, make, clang-18+ / lld-18+ / llvm-18+ (llvm-config on PATH).
set -e

REF="${1:-${PS4_SDK_REF:-master}}"
DEST="${PS4_SDK_DEST:-$HOME/ps4-payload-sdk}"
SRC="${PS4_SDK_SRC:-$HOME/ps4-payload-sdk-src}"

command -v git >/dev/null 2>&1 || { echo "FAIL: git not found"; exit 1; }
command -v make >/dev/null 2>&1 || { echo "FAIL: make not found"; exit 1; }
if command -v llvm-config >/dev/null 2>&1 || command -v llvm-config-18 >/dev/null 2>&1; then
  :
else
  echo "FAIL: llvm-config not found. Install clang/lld/llvm 18 or newer."
  exit 1
fi

if [ -d "$SRC/.git" ]; then
  echo "=== fetching SDK ==="
  git -C "$SRC" fetch -q origin
else
  echo "=== cloning SDK ==="
  git clone -q https://github.com/ps4-payload-dev/sdk.git "$SRC"
fi
git -C "$SRC" checkout -q "$REF"
echo "SDK at $(git -C "$SRC" rev-parse --short HEAD) ($(git -C "$SRC" log -1 --format=%s))"

# Firmware gate. Print what this checkout supports so you can confirm your
# console's firmware is listed before you build. Missing firmware = silent
# death before main().
echo "=== firmware cases in crt/patch.c ==="
if [ -f "$SRC/crt/patch.c" ]; then
  grep -o 'case 0x[0-9a-fA-F]*:' "$SRC/crt/patch.c" | sort -u | sed 's/^/  /'
else
  echo "  WARN: crt/patch.c not found; cannot verify firmware support"
fi

echo "=== building SDK -> $DEST ==="
make -C "$SRC" DESTDIR="$DEST" clean >/dev/null 2>&1 || true
make -C "$SRC" DESTDIR="$DEST" install >/dev/null

for f in bin/orbis-clang target/lib/crt1.o toolchain/orbis.mk; do
  [ -e "$DEST/$f" ] || { echo "FAIL: $DEST/$f missing after install"; exit 1; }
done

echo
echo "SDK installed at $DEST"
echo "Build the payload with:"
echo "  PS4_PAYLOAD_SDK=$DEST make"
