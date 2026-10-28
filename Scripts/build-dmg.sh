#!/usr/bin/env bash
#
# Builds Sottodesu and packages it as a drag-to-install disk image.
#
#   Scripts/build-dmg.sh [version]
#
# The version defaults to MARKETING_VERSION in project.yml. The result is
# build/Sottodesu-<version>.dmg (plus a .sha256 file next to it).
#
# Optional environment variables, for a build that macOS opens without a warning
# (needs a paid Apple Developer account):
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  a notarytool keychain profile name; notarizes and staples the DMG
#                   (create one with: xcrun notarytool store-credentials)
#
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Sottodesu"
BUILD_DIR="build"
DERIVED="$BUILD_DIR/DerivedData"
STAGE="$BUILD_DIR/dmg"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(sed -n 's/^ *MARKETING_VERSION: *"\([^"]*\)".*$/\1/p' project.yml | head -n1)"
fi
[[ -n "$VERSION" ]] || { echo "Could not work out the version. Pass it as an argument." >&2; exit 1; }
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Building $APP_NAME $VERSION (Release, Apple silicon + Intel)"
rm -rf "$BUILD_DIR"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="-" \
  build

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "The build did not produce $APP" >&2; exit 1; }

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  echo "==> Signing with: $SIGN_IDENTITY"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

echo "==> Creating $DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "docs/dmg/How to open Sottodesu.txt" "$STAGE/"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing (this can take a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

( cd "$BUILD_DIR" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )

echo
echo "Done: $DMG"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  echo "Note: this build is not signed with a Developer ID, so macOS will ask people to approve it"
  echo "once under System Settings > Privacy & Security > Open Anyway (see README)."
fi
