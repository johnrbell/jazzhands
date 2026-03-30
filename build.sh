#!/bin/bash
set -e

APP_NAME="JazzHands"
BUILD_DIR=".build/debug"
INSTALL_DIR="$HOME/Applications"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "Warning: No Apple Development identity found, falling back to ad-hoc signing."
    echo "  TCC permissions (Accessibility, Screen Recording) may not persist across rebuilds."
    SIGNING_IDENTITY="-"
fi
echo "Signing with: $SIGNING_IDENTITY"

# Kill running instance if any
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Stopping running $APP_NAME..."
    pkill -x "$APP_NAME" || true
    sleep 0.5
fi

echo "Building $APP_NAME..."
swift build

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Creating app bundle at $APP_BUNDLE..."
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"
    cp "JazzHands/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
    cat > "$APP_BUNDLE/Contents/PkgInfo" <<EOF
APPL????
EOF
else
    echo "Updating existing app bundle..."
fi

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "JazzHands/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "JazzHands/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "JazzHands/Resources/MenuBarIcon.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png"
cp "JazzHands/Resources/MenuBarIcon@2x.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon@2x.png"
cp "JazzHands/Resources/MenuBarAppIcon.png" "$APP_BUNDLE/Contents/Resources/MenuBarAppIcon.png"
cp "JazzHands/Resources/MenuBarAppIcon@2x.png" "$APP_BUNDLE/Contents/Resources/MenuBarAppIcon@2x.png"

echo "Signing app bundle..."
codesign -fs "$SIGNING_IDENTITY" --options runtime --entitlements "JazzHands/Resources/JazzHands.entitlements" "$APP_BUNDLE" --deep

echo "Done! App bundle at: $APP_BUNDLE"
echo ""
echo "Launching $APP_NAME..."
open "$APP_BUNDLE"
