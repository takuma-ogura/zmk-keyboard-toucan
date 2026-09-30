#!/usr/bin/env bash
# Flash Toucan firmware built by GitHub Actions from the latest origin/main.
#
#   scripts/flash.sh left            # normal firmware to the left half
#   scripts/flash.sh right           # normal firmware to the right half
#   scripts/flash.sh reset           # settings_reset (clears split + host pairing)
#
# Double-tap the half's reset button after starting; the script waits for XIAO-BOOT.
set -euo pipefail

REPO="takuma-ogura/zmk-keyboard-toucan"
BRANCH="main"
VOLUME="/Volumes/XIAO-BOOT"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
  left)  PATTERN="toucan_left*.uf2" ;;
  right) PATTERN="toucan_right*.uf2" ;;
  reset) PATTERN="settings_reset*.uf2" ;;
  *) echo "usage: $0 left|right|reset" >&2; exit 2 ;;
esac

git -C "$ROOT" fetch -q origin "$BRANCH"
SHA="$(git -C "$ROOT" rev-parse "origin/$BRANCH")"

# Refuse to flash if local keymap changes have not been pushed yet.
if [ "$(git -C "$ROOT" rev-parse HEAD)" != "$SHA" ] || [ -n "$(git -C "$ROOT" status --porcelain -- config boards build.yaml)" ]; then
  echo "local repo differs from origin/$BRANCH ($SHA). commit/push/pull first." >&2
  exit 1
fi

RUN_ID="$(gh run list -R "$REPO" --commit "$SHA" --status success -L 1 --json databaseId -q '.[0].databaseId')"
if [ -z "$RUN_ID" ]; then
  echo "no successful build for ${SHA:0:7}. run: gh workflow run -R $REPO --ref $BRANCH" >&2
  exit 1
fi

CACHE="$HOME/.cache/toucan-firmware/${SHA:0:7}"
if [ ! -d "$CACHE" ]; then
  gh run download "$RUN_ID" -R "$REPO" -D "$CACHE.tmp"
  mv "$CACHE.tmp" "$CACHE"
fi
UF2="$(find "$CACHE" -name "$PATTERN" | head -1)"
[ -n "$UF2" ] || { echo "no $PATTERN in $CACHE" >&2; exit 1; }

echo "firmware: ${SHA:0:7} ($(basename "$UF2"))"
echo "double-tap reset on the $1 half..."
for _ in $(seq 1 120); do
  [ -d "$VOLUME" ] && break
  sleep 1
done
[ -d "$VOLUME" ] || { echo "timed out waiting for $VOLUME" >&2; exit 1; }

cp "$UF2" "$VOLUME/"
echo "flashed ${SHA:0:7} to $1."
