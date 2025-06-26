#!/bin/bash

# Motion Storyline Development Build Script
# This script completes the build process when code signing certificates are not available
# It extracts the app from an existing archive and creates a DMG for development/testing

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Motion Storyline"

# Command line options
OPEN_FINDER=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-open)
            OPEN_FINDER=false
            shift
            ;;
        -h|--help)
            echo "Motion Storyline Development Build Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "This script extracts the app from an existing archive and creates"
            echo "a DMG for development/testing when code signing certificates are not available."
            echo ""
            echo "Options:"
            echo "  --no-open      Don't open Finder when complete"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Prerequisites:"
            echo "  - An existing .xcarchive must be present in the dist/ folder"
            echo "  - Run this after a failed build_release.sh due to missing certificates"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Paths
BUILD_DIR="$PROJECT_DIR/dist"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ARCHIVE_APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
DMG_DIR="$BUILD_DIR/dmg"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"

# DMG configuration
DMG_TITLE="Motion Storyline Installer"
DMG_BACKGROUND="$SCRIPT_DIR/assets/dmg-background.png"
DMG_ICON="$SCRIPT_DIR/assets/dmg-icon.icns"

echo "🚀 Motion Storyline Development Build Process"
echo "============================================="
echo ""
echo "This script extracts the app from an existing archive and creates"
echo "a DMG for development/testing purposes."
echo ""

# Check if archive exists
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found at: $ARCHIVE_PATH"
    echo ""
    echo "Please run the following first to create an archive:"
    echo "  cd '$PROJECT_DIR'"
    echo "  xcodebuild archive -project 'Motion Storyline.xcodeproj' -scheme 'Motion Storyline' -configuration 'Release' -archivePath '$ARCHIVE_PATH' -destination 'generic/platform=macOS'"
    echo ""
    echo "Or run: ./Scripts/build_release.sh (which will fail at export but create the archive)"
    exit 1
fi

# Check if app exists in archive
if [ ! -d "$ARCHIVE_APP_PATH" ]; then
    echo "❌ App not found in archive at: $ARCHIVE_APP_PATH"
    exit 1
fi

echo "✅ Found archive with app at: $ARCHIVE_APP_PATH"
echo ""

# Get version information
VERSION=$(defaults read "$ARCHIVE_APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_NUMBER=$(defaults read "$ARCHIVE_APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

echo "📋 Build Information:"
echo "   Version: $VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Archive: $(basename "$ARCHIVE_PATH")"
echo ""

# Step 1: Extract app from archive
echo "Step 1: Extracting app from archive"
echo "-----------------------------------"
echo "📦 Copying app from archive to export folder..."

# Create export directory
mkdir -p "$EXPORT_PATH"

# Remove existing app if present
if [ -d "$APP_PATH" ]; then
    rm -rf "$APP_PATH"
fi

# Copy app from archive
cp -R "$ARCHIVE_APP_PATH" "$EXPORT_PATH/"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Failed to copy app from archive"
    exit 1
fi

echo "✅ App extracted to: $APP_PATH"
echo ""

# Step 2: Prepare DMG contents
echo "Step 2: Preparing DMG contents"
echo "------------------------------"
echo "📂 Setting up DMG directory structure..."

# Clean and create DMG directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
cp -R "$APP_PATH" "$DMG_DIR/"

# Create Applications symlink
ln -sf /Applications "$DMG_DIR/Applications"

# Copy additional files if they exist
if [ -f "$PROJECT_DIR/README.md" ]; then
    cp "$PROJECT_DIR/README.md" "$DMG_DIR/Read Me.txt"
    echo "✅ Added README to DMG"
fi

if [ -f "$PROJECT_DIR/LICENSE" ]; then
    cp "$PROJECT_DIR/LICENSE" "$DMG_DIR/"
    echo "✅ Added LICENSE to DMG"
fi

echo "✅ DMG contents prepared"
echo ""

# Step 3: Create DMG
echo "Step 3: Creating DMG installer"
echo "------------------------------"
echo "💿 Building DMG file..."

# Remove existing DMG
rm -f "$DMG_PATH"

# Create temporary DMG
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$DMG_TITLE" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 200m "$TEMP_DMG"

# Mount the temporary DMG
MOUNT_DIR="/Volumes/$DMG_TITLE"
echo "📀 Mounting DMG for customization..."
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG"

# Wait for mount
sleep 2

# Configure DMG appearance
if [ -f "$DMG_BACKGROUND" ]; then
    echo "🎨 Setting custom DMG background..."
    mkdir -p "$MOUNT_DIR/.background"
    cp "$DMG_BACKGROUND" "$MOUNT_DIR/.background/background.png"
    BACKGROUND_SCRIPT="set background picture of theViewOptions to file \".background:background.png\""
else
    echo "⚠️  No custom background found, using default"
    BACKGROUND_SCRIPT=""
fi

# Apply DMG settings using AppleScript
echo "🎯 Configuring DMG layout..."
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
        $BACKGROUND_SCRIPT
        
        -- Position icons
        set position of item "$APP_NAME.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        
        -- Update and close
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Set custom icon if available
if [ -f "$DMG_ICON" ]; then
    echo "🎯 Setting custom DMG icon..."
    cp "$DMG_ICON" "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_DIR" 2>/dev/null || true
fi

# Unmount the temporary DMG
echo "💾 Finalizing DMG..."
hdiutil detach "$MOUNT_DIR"

# Convert to final compressed DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$TEMP_DMG"

# Set DMG permissions
chmod 644 "$DMG_PATH"

echo "✅ DMG created successfully"
echo ""

# Step 4: Verification
echo "Step 4: Verification"
echo "-------------------"
echo "🔍 Verifying DMG integrity..."
hdiutil verify "$DMG_PATH"

# Get file information
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
DMG_MD5=$(md5 -q "$DMG_PATH")

echo ""
echo "🎉 Development Build Complete!"
echo "=============================="
echo ""
echo "📦 Package Information:"
echo "   File: $APP_NAME.dmg"
echo "   Path: $DMG_PATH"
echo "   Size: $DMG_SIZE"
echo "   MD5:  $DMG_MD5"
echo "   Version: $VERSION ($BUILD_NUMBER)"
echo ""
echo "⚠️  Development Build Notes:"
echo "   • This build is NOT code signed"
echo "   • Suitable for development and testing only"
echo "   • For distribution, obtain Apple Developer certificates"
echo "   • Users may see security warnings when installing"
echo ""
echo "📋 Next Steps:"
echo "1. Test the DMG by mounting and installing"
echo "2. Verify the app runs correctly"
echo "3. For distribution: obtain certificates and use build_release.sh --notarize"
echo ""

# Open Finder to the build directory
if [ "$OPEN_FINDER" = true ]; then
    echo "📂 Opening build directory in Finder..."
    open "$BUILD_DIR"
fi

echo "🏁 Development build process complete!" 