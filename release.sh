#!/bin/bash
set -e

APP_NAME="JazzHands"
VERSION=$(grep -A1 "CFBundleShortVersionString" JazzHands/Resources/Info.plist | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
BUILD_DIR=".build/release"
RELEASE_DIR="release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

# --- Signing Identity ---
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$SIGNING_IDENTITY" ]; then
    echo "ERROR: No 'Developer ID Application' certificate found in keychain."
    echo ""
    echo "To distribute outside the App Store, you need a Developer ID Application certificate."
    echo "  1. Go to https://developer.apple.com/account/resources/certificates/list"
    echo "  2. Create a 'Developer ID Application' certificate"
    echo "  3. Download and install it in your keychain"
    echo ""
    echo "If you just want a local release build (no notarization), run with --local:"
    echo "  bash release.sh --local"
    if [ "$1" != "--local" ]; then
        exit 1
    fi
    echo ""
    echo "Falling back to Apple Development identity for local build..."
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo "ERROR: No signing identity found at all. Cannot proceed."
        exit 1
    fi
fi
echo "Signing with: $SIGNING_IDENTITY"
echo "Version: $VERSION"
echo ""

# --- Build ---
echo "Building $APP_NAME (release)..."
swift build -c release

# --- Create App Bundle ---
rm -rf "$RELEASE_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "JazzHands/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "JazzHands/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cat > "$APP_BUNDLE/Contents/PkgInfo" <<EOF
APPL????
EOF

# --- Sign ---
echo "Signing app bundle..."
codesign -fs "$SIGNING_IDENTITY" --options runtime --entitlements "JazzHands/Resources/JazzHands.entitlements" "$APP_BUNDLE" --deep

# --- Notarize (only with Developer ID) ---
if echo "$SIGNING_IDENTITY" | grep -q "Developer ID"; then
    echo ""
    echo "Creating ZIP for notarization..."
    ZIP_PATH="$RELEASE_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    echo "Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "notarytool-profile" --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"

    rm -f "$ZIP_PATH"
    echo "Notarization complete."
else
    echo ""
    echo "Skipping notarization (no Developer ID certificate)."
fi

# --- Create DMG ---
echo ""
echo "Creating DMG..."
DMG_TEMP="$RELEASE_DIR/dmg-temp"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_TEMP"

# Sign the DMG too
codesign -fs "$SIGNING_IDENTITY" "$DMG_PATH"

# Notarize DMG if Developer ID
if echo "$SIGNING_IDENTITY" | grep -q "Developer ID"; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "notarytool-profile" --wait
    xcrun stapler staple "$DMG_PATH"
fi

echo ""
echo "============================================"
echo "  Release complete!"
echo "  App:  $APP_BUNDLE"
echo "  DMG:  $DMG_PATH"
echo "============================================"
echo ""
echo "To set up notarization credentials (one-time):"
echo "  xcrun notarytool store-credentials \"notarytool-profile\" \\"
echo "    --apple-id YOUR_APPLE_ID \\"
echo "    --team-id YOUR_TEAM_ID \\"
echo "    --password YOUR_APP_SPECIFIC_PASSWORD"
