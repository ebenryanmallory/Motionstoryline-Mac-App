#!/bin/bash

# Motion Storyline DMG Creation Script
# This script builds the app, signs it, and creates a distributable DMG

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Motion Storyline"
BUNDLE_ID="motionstoryline.Motion-Storyline"
SCHEME="Motion Storyline"
CONFIGURATION="Release"

# Paths
BUILD_DIR="$PROJECT_DIR/dist"
ARCHIVE_PATH="$BUILD_DIR/Motion Storyline.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

# DMG configuration
DMG_TITLE="Motion Storyline Installer"
DMG_SIZE="200m"
DMG_BACKGROUND="$SCRIPT_DIR/assets/dmg-background.png"
DMG_ICON="$SCRIPT_DIR/assets/dmg-icon.icns"

# Version information
VERSION=$(defaults read "$PROJECT_DIR/Motion Storyline/Motion Storyline/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_NUMBER=$(defaults read "$PROJECT_DIR/Motion Storyline/Motion Storyline/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

echo "🚀 Building Motion Storyline DMG Installer"
echo "   Version: $VERSION ($BUILD_NUMBER)"
echo "   Configuration: $CONFIGURATION"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DMG_DIR"

# Build and archive the app
echo "🔨 Building and archiving the app..."
cd "$PROJECT_DIR"

xcodebuild archive \
    -project "Motion Storyline.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    -quiet

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive failed - archive not found at $ARCHIVE_PATH"
    exit 1
fi

# Export the app
echo "📦 Exporting the app..."
mkdir -p "$EXPORT_PATH"

# Create export options plist
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>\${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Export failed - app not found at $APP_PATH"
    exit 1
fi

# Verify the app bundle
echo "🔍 Verifying app bundle..."
codesign -v -v "$APP_PATH" || {
    echo "⚠️  Code signature verification failed, but continuing..."
}

# Prepare DMG contents
echo "📂 Preparing DMG contents..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -sf /Applications "$DMG_DIR/Applications"

# Copy additional files if they exist
if [ -f "$PROJECT_DIR/README.md" ]; then
    cp "$PROJECT_DIR/README.md" "$DMG_DIR/Read Me.txt"
fi

if [ -f "$PROJECT_DIR/LICENSE" ]; then
    cp "$PROJECT_DIR/LICENSE" "$DMG_DIR/"
fi

# Create the DMG
echo "💿 Creating DMG..."
rm -f "$DMG_PATH"

# Create temporary DMG
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$DMG_TITLE" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size "$DMG_SIZE" "$TEMP_DMG"

# Mount the temporary DMG
MOUNT_DIR="/Volumes/$DMG_TITLE"
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG"

# Wait for mount
sleep 2

# Configure DMG appearance
if [ -f "$DMG_BACKGROUND" ]; then
    echo "🎨 Setting DMG background..."
    mkdir -p "$MOUNT_DIR/.background"
    cp "$DMG_BACKGROUND" "$MOUNT_DIR/.background/background.png"
fi

# Apply DMG settings using AppleScript
osascript << EOF
tell application "Finder"
    tell disk "$DMG_TITLE"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 740, 480}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set background picture of theViewOptions to file ".background:background.png"
        
        -- Position icons
        set position of item "$APP_NAME.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        
        -- Hide background folder
        set the bounds of container window to {100, 100, 740, 480}
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Set custom icon if available
if [ -f "$DMG_ICON" ]; then
    echo "🎯 Setting DMG icon..."
    cp "$DMG_ICON" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR"
fi

# Unmount the temporary DMG
echo "💾 Finalizing DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to final compressed DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$TEMP_DMG"

# Set DMG permissions
chmod 644 "$DMG_PATH"

# Verify the final DMG
echo "✅ Verifying DMG..."
hdiutil verify "$DMG_PATH"

# Get file size
DMG_SIZE_MB=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "🎉 DMG Creation Complete!"
echo "   DMG Path: $DMG_PATH"
echo "   Size: $DMG_SIZE_MB"
echo "   Version: $VERSION ($BUILD_NUMBER)"
echo ""
echo "Next steps:"
echo "1. Test the DMG by mounting and installing"
echo "2. Notarize for distribution (see notarize.sh)"
echo "3. Upload to your distribution server" 