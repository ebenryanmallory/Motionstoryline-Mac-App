#!/bin/bash

# Motion Storyline Notarization Script
# This script notarizes the DMG for distribution outside the Mac App Store

set -e  # Exit on any error

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Motion Storyline"
DMG_PATH="$PROJECT_DIR/dist/$APP_NAME.dmg"

# Notarization configuration
# These should be set in your environment or Xcode settings
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"  # App-specific password from Apple ID
TEAM_ID="${TEAM_ID:-}"

echo "🍎 Starting Apple Notarization Process"
echo "   DMG: $DMG_PATH"
echo ""

# Check prerequisites
if [ ! -f "$DMG_PATH" ]; then
    echo "❌ DMG not found at $DMG_PATH"
    echo "   Please run create_dmg.sh first"
    exit 1
fi

if [ -z "$APPLE_ID" ]; then
    echo "❌ APPLE_ID environment variable not set"
    echo "   Please set your Apple ID email address"
    exit 1
fi

if [ -z "$APP_PASSWORD" ]; then
    echo "❌ APP_PASSWORD environment variable not set"
    echo "   Please create an app-specific password at appleid.apple.com"
    echo "   and set it in the APP_PASSWORD environment variable"
    exit 1
fi

if [ -z "$TEAM_ID" ]; then
    echo "❌ TEAM_ID environment variable not set"
    echo "   Please set your Apple Developer Team ID"
    exit 1
fi

# Create keychain profile for notarization (optional but recommended)
echo "🔐 Setting up notarization credentials..."
xcrun notarytool store-credentials "Motion-Storyline-Profile" \
    --apple-id "$APPLE_ID" \
    --password "$APP_PASSWORD" \
    --team-id "$TEAM_ID" \
    --validate

# Submit for notarization
echo "📤 Submitting DMG for notarization..."
SUBMISSION_ID=$(xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "Motion-Storyline-Profile" \
    --output-format json | jq -r '.id')

if [ -z "$SUBMISSION_ID" ] || [ "$SUBMISSION_ID" = "null" ]; then
    echo "❌ Failed to submit for notarization"
    exit 1
fi

echo "✅ Submitted successfully!"
echo "   Submission ID: $SUBMISSION_ID"
echo ""

# Wait for notarization to complete
echo "⏳ Waiting for notarization to complete..."
echo "   This typically takes 1-10 minutes..."

while true; do
    STATUS=$(xcrun notarytool info "$SUBMISSION_ID" \
        --keychain-profile "Motion-Storyline-Profile" \
        --output-format json | jq -r '.status')
    
    case "$STATUS" in
        "Accepted")
            echo "✅ Notarization successful!"
            break
            ;;
        "Invalid")
            echo "❌ Notarization failed!"
            echo "   Getting failure details..."
            xcrun notarytool log "$SUBMISSION_ID" \
                --keychain-profile "Motion-Storyline-Profile"
            exit 1
            ;;
        "In Progress")
            echo "   Still processing... (Status: $STATUS)"
            sleep 30
            ;;
        *)
            echo "   Unknown status: $STATUS"
            sleep 30
            ;;
    esac
done

# Staple the notarization to the DMG
echo "📎 Stapling notarization to DMG..."
xcrun stapler staple "$DMG_PATH"

# Verify the stapling
echo "🔍 Verifying stapled notarization..."
xcrun stapler validate "$DMG_PATH"

# Verify Gatekeeper acceptance
echo "🛡️  Verifying Gatekeeper acceptance..."
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo ""
echo "🎉 Notarization Complete!"
echo "   DMG is now ready for distribution"
echo "   Users can download and install without security warnings"
echo ""
echo "Final DMG: $DMG_PATH" 