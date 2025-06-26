#!/bin/bash

# Motion Storyline Complete Release Build Script
# This script orchestrates the complete release process:
# 1. Clean and build the app
# 2. Create DMG installer
# 3. Optionally notarize for distribution

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Motion Storyline"

# Command line options
NOTARIZE=false
CLEAN_BUILD=true
OPEN_FINDER=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --notarize)
            NOTARIZE=true
            shift
            ;;
        --no-clean)
            CLEAN_BUILD=false
            shift
            ;;
        --no-open)
            OPEN_FINDER=false
            shift
            ;;
        -h|--help)
            echo "Motion Storyline Release Build Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --notarize     Submit DMG for Apple notarization"
            echo "  --no-clean     Skip cleaning derived data"
            echo "  --no-open      Don't open Finder when complete"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Environment variables for notarization:"
            echo "  APPLE_ID       Your Apple ID email"
            echo "  APP_PASSWORD   App-specific password from Apple ID"
            echo "  TEAM_ID        Your Apple Developer Team ID"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Motion Storyline Release Build Process"
echo "========================================"
echo ""

# Check for required tools
echo "🔧 Checking required tools..."
command -v xcodebuild >/dev/null 2>&1 || {
    echo "❌ xcodebuild not found. Please install Xcode."
    exit 1
}

command -v hdiutil >/dev/null 2>&1 || {
    echo "❌ hdiutil not found. This should be available on all macOS systems."
    exit 1
}

if [ "$NOTARIZE" = true ]; then
    command -v xcrun >/dev/null 2>&1 || {
        echo "❌ xcrun not found. Please install Xcode command line tools."
        exit 1
    }
    
    command -v jq >/dev/null 2>&1 || {
        echo "❌ jq not found. Install with: brew install jq"
        exit 1
    }
fi

echo "✅ All required tools found"
echo ""

# Clean derived data if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "🧹 Cleaning derived data..."
    rm -rf "$PROJECT_DIR/DerivedData"
    rm -rf "$PROJECT_DIR/.build"
    rm -rf "$PROJECT_DIR/dist"
fi

# Get version information
cd "$PROJECT_DIR"
VERSION=$(defaults read "$PROJECT_DIR/Motion Storyline/Motion Storyline/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_NUMBER=$(defaults read "$PROJECT_DIR/Motion Storyline/Motion Storyline/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

echo "📋 Build Information:"
echo "   Version: $VERSION"
echo "   Build: $BUILD_NUMBER"
echo "   Notarization: $([ "$NOTARIZE" = true ] && echo "Enabled" || echo "Disabled")"
echo ""

# Step 1: Create DMG
echo "Step 1: Creating DMG Installer"
echo "------------------------------"
"$SCRIPT_DIR/create_dmg.sh"

DMG_PATH="$PROJECT_DIR/dist/$APP_NAME.dmg"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG creation failed"
    exit 1
fi

echo ""

# Step 2: Notarize (if requested)
if [ "$NOTARIZE" = true ]; then
    echo "Step 2: Apple Notarization"
    echo "-------------------------"
    "$SCRIPT_DIR/notarize.sh"
    echo ""
fi

# Final verification
echo "🔍 Final Verification"
echo "--------------------"
echo "Verifying DMG integrity..."
hdiutil verify "$DMG_PATH"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
DMG_MD5=$(md5 -q "$DMG_PATH")

echo ""
echo "🎉 Release Build Complete!"
echo "=========================="
echo ""
echo "📦 Package Information:"
echo "   File: $APP_NAME.dmg"
echo "   Path: $DMG_PATH"
echo "   Size: $DMG_SIZE"
echo "   MD5:  $DMG_MD5"
echo "   Version: $VERSION ($BUILD_NUMBER)"
echo ""

if [ "$NOTARIZE" = true ]; then
    echo "✅ Ready for public distribution (notarized)"
else
    echo "⚠️  Ready for testing (not notarized)"
    echo "   Run with --notarize for public distribution"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Test the DMG by mounting and installing"
echo "2. Upload to your distribution server/CDN"
echo "3. Update download links on your website"
echo "4. Create release notes and announcements"

# Open Finder to the build directory
if [ "$OPEN_FINDER" = true ]; then
    echo ""
    echo "📂 Opening build directory in Finder..."
    open "$PROJECT_DIR/dist"
fi

echo ""
echo "🏁 Build process complete!" 