#!/bin/bash
set -e

APP_NAME="JazzHands"
BUILD_DIR=".build/debug"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
SIGNING_IDENTITY="JazzHands Dev Signing"

echo "Building $APP_NAME..."
swift build

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Creating app bundle at $APP_BUNDLE..."
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp "Orbit/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
    cat > "$APP_BUNDLE/Contents/PkgInfo" <<EOF
APPL????
EOF
else
    echo "Updating existing app bundle..."
fi

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Signing app bundle..."
codesign -fs "$SIGNING_IDENTITY" --options runtime --entitlements "Orbit/Resources/Orbit.entitlements" "$APP_BUNDLE" --deep

echo "Done! App bundle at: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
