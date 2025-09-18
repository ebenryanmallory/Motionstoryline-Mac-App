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
DERIVED_DATA_PATH="$BUILD_DIR/DerivedData"
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
mkdir -p "$DERIVED_DATA_PATH"

# Build and archive the app
echo "🔨 Building and archiving the app..."
cd "$PROJECT_DIR"

xcodebuild archive \
    -project "Motion Storyline.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -destination "generic/platform=macOS" \
    -quiet

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive failed - archive not found at $ARCHIVE_PATH"
    exit 1
fi

#############################################
## Export the app (Developer ID preferred; optional fallback)
#############################################
echo "📦 Exporting the app (Developer ID preferred)..."
mkdir -p "$EXPORT_PATH"

# Detect Team ID from archive if not provided
# Try to detect Team ID from archive; fall back to env; then project file
DETECTED_TEAM_ID=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:TeamID' "$ARCHIVE_PATH/Info.plist" 2>/dev/null || true)
TEAM_ID_FOR_EXPORT="${DETECTED_TEAM_ID:-${DEVELOPMENT_TEAM}}"
if [ -z "$TEAM_ID_FOR_EXPORT" ]; then
    PBXPROJ="$PROJECT_DIR/Motion Storyline.xcodeproj/project.pbxproj"
    if [ -f "$PBXPROJ" ]; then
        TEAM_ID_FOR_EXPORT=$(grep -o 'DEVELOPMENT_TEAM = [^;]*' "$PBXPROJ" | head -1 | sed 's/DEVELOPMENT_TEAM = //' | tr -d ';"' || true)
    fi
fi
if [ -z "$TEAM_ID_FOR_EXPORT" ]; then
    # Try to infer Team ID from installed Developer ID Application certificate
    CERT_LINE=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 || true)
    if [ -n "$CERT_LINE" ]; then
        TEAM_ID_FOR_EXPORT=$(echo "$CERT_LINE" | sed -n 's/.*(\(.*\)).*/\1/p')
    fi
fi
if [ -z "$TEAM_ID_FOR_EXPORT" ]; then
    if [ -n "$ALLOW_UNSIGNED_FALLBACK" ]; then
        echo "⚠️  Team ID not found. Proceeding with unsigned/dev-signed fallback (ALLOW_UNSIGNED_FALLBACK is set)."
    else
        echo "❌ Unable to determine Team ID from archive and DEVELOPMENT_TEAM not set."
        echo "   Set DEVELOPMENT_TEAM or set ALLOW_UNSIGNED_FALLBACK=1 to continue without Developer ID."
        exit 1
    fi
fi

# Create export options plist (Developer ID)
EXPORT_OPTIONS_PLIST="$BUILD_DIR/ExportOptions.plist"
cat > "$EXPORT_OPTIONS_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID_FOR_EXPORT}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

EXPORTED_WITH_DEVID=0
if [ -n "$TEAM_ID_FOR_EXPORT" ]; then
    if xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -quiet; then
        APP_PATH="$EXPORT_PATH/$APP_NAME.app"
        EXPORTED_WITH_DEVID=1
    else
        if [ -n "$ALLOW_UNSIGNED_FALLBACK" ]; then
            echo "⚠️  Developer ID export failed. Falling back to archived app (unsigned or development-signed)."
            APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
        else
            echo "❌ Developer ID export failed and ALLOW_UNSIGNED_FALLBACK is not set."
            exit 1
        fi
    fi
else
    # No Team ID; go straight to fallback if allowed
    if [ -n "$ALLOW_UNSIGNED_FALLBACK" ]; then
        APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME.app"
    else
        echo "❌ Missing Team ID and ALLOW_UNSIGNED_FALLBACK not set. Cannot proceed."
        exit 1
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Unable to locate app bundle for DMG creation at: $APP_PATH"
    echo "   Ensure the archive succeeded and contains Products/Applications/$APP_NAME.app"
    exit 1
fi

#############################################
## Verify signing
#############################################
echo "🔍 Verifying app code signature..."
if ! codesign -v --deep --strict "$APP_PATH" 2>/dev/null; then
    if [ "$EXPORTED_WITH_DEVID" = "1" ]; then
        echo "❌ Code signature verification failed for Developer ID export."
        exit 1
    else
        echo "⚠️  Code signature verification failed (expected for unsigned/dev-signed fallback). Continuing."
    fi
fi

SIGN_INFO=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)
echo "$SIGN_INFO" | sed -n 's/^.*Authority=\(.*\)$/Authority: \1/p' | head -3
TEAM_ID_LINE=$(echo "$SIGN_INFO" | grep -E '^TeamIdentifier=' || true)
echo "${TEAM_ID_LINE:-TeamIdentifier=Unknown}"

if [ "$EXPORTED_WITH_DEVID" = "1" ]; then
    if ! echo "$SIGN_INFO" | grep -q "Authority=Developer ID Application"; then
        echo "❌ App is not signed with a Developer ID Application certificate."
        exit 1
    fi
else
    echo "ℹ️  Proceeding without Developer ID signature. Users must bypass Gatekeeper once."
fi

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

# Include First Run Guide to help users bypass Gatekeeper safely
if [ -f "$PROJECT_DIR/Docs/First-Run-Guide.txt" ]; then
    cp "$PROJECT_DIR/Docs/First-Run-Guide.txt" "$DMG_DIR/First Run Guide.txt"
fi

# Create the DMG
echo "💿 Creating DMG..."
rm -f "$DMG_PATH"

# Create temporary DMG
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -srcfolder "$DMG_DIR" -volname "$DMG_TITLE" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size "$DMG_SIZE" "$TEMP_DMG"

# Mount the temporary DMG
MOUNT_DIR="/Volumes/$DMG_TITLE"
# If a previous mount exists (from an interrupted run), try to detach it
if mount | grep -q "$MOUNT_DIR"; then
    echo "🔌 Detaching previous mount at $MOUNT_DIR"
    hdiutil detach "$MOUNT_DIR" || true
    sleep 1
fi
hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG"

# Wait for mount
sleep 2

# Configure DMG appearance
if [ -f "$DMG_BACKGROUND" ]; then
    echo "🎨 Setting DMG background..."
    mkdir -p "$MOUNT_DIR/.background"
    cp "$DMG_BACKGROUND" "$MOUNT_DIR/.background/background.png"
fi

# Apply DMG settings using AppleScript (best-effort; ignore errors in headless environments)
if ! osascript << EOF
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
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try
        
        -- Position icons
        try
            set position of item "$APP_NAME.app" of container window to {170, 200}
            set position of item "Applications" of container window to {470, 200}
            try
                set position of item "First Run Guide.txt" of container window to {320, 360}
            end try
        end try
        
        -- Hide background folder
        set the bounds of container window to {100, 100, 740, 480}
        update without registering applications
        delay 2
    end tell
end tell
EOF
then
    echo "⚠️  Unable to customize DMG appearance via Finder AppleScript. Continuing without cosmetics."
fi

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
