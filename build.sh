#!/bin/bash
set -e

APP_NAME="Orbit"
BUILD_DIR=".build/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
swift build

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Orbit/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

cat > "$APP_BUNDLE/Contents/PkgInfo" <<EOF
APPL????
EOF

echo "Signing app bundle..."
codesign -fs "Orbit Dev Signing" "$APP_BUNDLE" --deep

echo "Done! App bundle at: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "To grant Accessibility permission:"
echo "  1. Run: open $APP_BUNDLE"
echo "  2. macOS will prompt for Accessibility access"
echo "  3. Or manually add $APP_BUNDLE in System Settings → Privacy & Security → Accessibility"
