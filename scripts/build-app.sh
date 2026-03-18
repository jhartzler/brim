#!/bin/bash
set -euo pipefail

# Build Brim.app bundle from Swift Package Manager output
APP_NAME="Brim"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"
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

echo "Built: ${APP_BUNDLE}"
echo ""
echo "To run:  ${APP_BUNDLE}/Contents/MacOS/${APP_NAME} &"
echo "To install: cp -R ${APP_BUNDLE} /Applications/"
