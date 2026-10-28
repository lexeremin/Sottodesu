#!/usr/bin/env bash
#
# Takes the screenshots shown in the README, using the app's built-in demo mode
# (made-up data — your real Downloads folder and history are never touched).
#
#   Scripts/take-screenshots.sh
#
# The first time, macOS asks whether your terminal may record the screen. Allow it under
# System Settings > Privacy & Security > Screen & System Audio Recording, then run the script again.
# Leave the mouse and keyboard alone while it runs, and keep other windows off the screen.
#
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="docs/screenshots"
BUILD="build/screenshots"
BIN="$BUILD/DerivedData/Build/Products/Release/Sottodesu.app/Contents/MacOS/Sottodesu"

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }

echo "==> Building"
xcodegen generate
xcodebuild -project Sottodesu.xcodeproj -scheme Sottodesu -configuration Release \
  -destination 'platform=macOS' -derivedDataPath "$BUILD/DerivedData" CODE_SIGN_IDENTITY="-" -quiet build
swiftc -O Scripts/window-id.swift -o "$BUILD/window-id"
mkdir -p "$OUT"

# capture <file name> <tab> <language> <locale> <light|dark>
capture() {
  local name="$1" tab="$2" lang="$3" locale="$4" appearance="$5"
  local style=(-NSRequiresAquaSystemAppearance YES)
  if [[ "$appearance" == "dark" ]]; then style=(-AppleInterfaceStyle Dark); fi

  "$BIN" --demo --tab "$tab" -AppleLanguages "($lang)" -AppleLocale "$locale" "${style[@]}" >/dev/null 2>&1 &
  local pid=$!

  local wid=""
  for _ in $(seq 1 40); do
    wid="$("$BUILD/window-id" "$pid" 2>/dev/null || true)"
    if [[ -n "$wid" ]]; then break; fi
    sleep 0.25
  done
  if [[ -z "$wid" ]]; then
    kill "$pid" 2>/dev/null || true
    echo "No window appeared for $name" >&2
    return 1
  fi

  sleep 1.5   # let the lists and charts finish drawing
  screencapture -o -l "$wid" "$OUT/$name.png"
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  echo "   $name.png"
}

echo "==> Taking screenshots"
for tab in sort report largest; do
  for appearance in light dark; do
    capture "$tab-$appearance" "$tab" en en_US "$appearance"
  done
done
capture "sort-ru" sort ru ru_RU light
capture "sort-zh-Hans" sort zh-Hans zh_CN light
capture "sort-ko" sort ko ko_KR light
capture "sort-ja" sort ja ja_JP light
capture "sort-fr" sort fr fr_FR light

echo
echo "Done. Look through $OUT/ — if the images are blank or show only the desktop,"
echo "give your terminal Screen Recording permission and run this again."
