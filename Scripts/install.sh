#!/usr/bin/env bash
#
# Installs the latest Sottodesu without any Gatekeeper warning.
# Files downloaded with curl are not quarantined, so macOS opens the app straight away.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/lexeremin/Sottodesu/main/Scripts/install.sh)"
#
set -euo pipefail

REPO="lexeremin/Sottodesu"
WORK="$(mktemp -d)"
MOUNT="$WORK/volume"

cleanup() {
  hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "==> Finding the latest Sottodesu release"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -n1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[[ -n "$URL" ]] || { echo "No release found at https://github.com/$REPO/releases" >&2; exit 1; }

echo "==> Downloading $(basename "$URL")"
curl -fL --progress-bar "$URL" -o "$WORK/Sottodesu.dmg"

echo "==> Installing to /Applications"
mkdir -p "$MOUNT"
hdiutil attach "$WORK/Sottodesu.dmg" -nobrowse -readonly -quiet -mountpoint "$MOUNT"
rm -rf /Applications/Sottodesu.app
cp -R "$MOUNT/Sottodesu.app" /Applications/
xattr -dr com.apple.quarantine /Applications/Sottodesu.app 2>/dev/null || true

echo "==> Done. Opening Sottodesu"
open /Applications/Sottodesu.app
