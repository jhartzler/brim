#!/bin/bash
set -euo pipefail

# Build Brim.app bundle from Swift Package Manager output
APP_NAME="Brim"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"
DMG_NAME="Brim.dmg"
DMG_PATH="build/${DMG_NAME}"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME}..."
swift build -c release 2>&1

echo "Assembling ${APP_NAME}.app..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "Sources/Brim/Info.plist" "${CONTENTS}/Info.plist"

# Copy app icon (.icns) into top-level Resources so macOS can find it
cp "Sources/Brim/Resources/AppIcon.icns" "${RESOURCES}/AppIcon.icns"

# Copy resources (asset catalog gets compiled during swift build)
# Copy resource bundles (name changed after library split: Brim_Brim -> Brim_BrimLib)
for bundle in "${BUILD_DIR}"/Brim_*.bundle; do
    [ -d "$bundle" ] && cp -R "$bundle" "${RESOURCES}/"
done

# Strip extended attributes (resource forks break codesign)
xattr -cr "${APP_BUNDLE}"

# Ad-hoc code sign (required to run on other Macs)
echo "Code signing..."
codesign --force --deep -s - "${APP_BUNDLE}"

# Verify the app bundle
echo "Verifying app bundle..."
codesign --verify --verbose=2 "${APP_BUNDLE}" 2>&1 || true

echo "Built: ${APP_BUNDLE}"

# Create DMG using create-dmg for proper window sizing and layout
echo "Creating DMG..."
rm -f "${DMG_PATH}"

STAGING_DIR=$(mktemp -d)
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

create-dmg \
    --volname "${APP_NAME} Installer" \
    --window-pos 200 120 \
    --window-size 500 300 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 130 120 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 360 120 \
    "${DMG_PATH}" \
    "${STAGING_DIR}" \
    2>&1

rm -rf "${STAGING_DIR}"

echo ""
echo "✅ Build complete!"
echo ""
echo "  App: ${APP_BUNDLE}"
echo "  DMG: ${DMG_PATH}"
echo ""
echo "To run:       ${APP_BUNDLE}/Contents/MacOS/${APP_NAME} &"
echo "To install:   cp -R ${APP_BUNDLE} /Applications/"
echo "To share:     Send the DMG file — open it and drag Brim to Applications"