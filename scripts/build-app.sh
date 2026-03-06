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
if [ -d "${BUILD_DIR}/Brim_Brim.bundle" ]; then
    cp -R "${BUILD_DIR}/Brim_Brim.bundle" "${RESOURCES}/"
fi

echo "Built: ${APP_BUNDLE}"
echo ""
echo "To run:  open build/Brim.app"
echo "To install: cp -R build/Brim.app /Applications/"
