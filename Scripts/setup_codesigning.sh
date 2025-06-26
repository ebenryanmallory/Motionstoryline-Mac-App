#!/bin/bash

# Motion Storyline Code Signing Setup Script
# This script helps configure code signing for distribution

set -e  # Exit on any error

echo "🔐 Motion Storyline Code Signing Setup"
echo "======================================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode not found. Please install Xcode from the Mac App Store."
    exit 1
fi

# Check if developer tools are installed
if ! command -v xcrun &> /dev/null; then
    echo "❌ Xcode command line tools not found."
    echo "   Install with: xcode-select --install"
    exit 1
fi

echo "✅ Xcode and command line tools found"
echo ""

# List available certificates
echo "📋 Available Code Signing Certificates:"
echo "---------------------------------------"
security find-identity -v -p codesigning | grep -E "(Developer ID Application|Mac Developer)" || {
    echo "❌ No code signing certificates found!"
    echo ""
    echo "📝 To set up code signing:"
    echo "1. Join the Apple Developer Program ($99/year)"
    echo "2. Create certificates in Apple Developer portal"
    echo "3. Download and install certificates in Keychain"
    echo ""
    echo "🔗 Useful links:"
    echo "   Apple Developer: https://developer.apple.com"
    echo "   Certificate Guide: https://developer.apple.com/help/account/create-certificates"
    exit 1
}

echo ""
echo "📋 Available Provisioning Profiles:"
echo "-----------------------------------"
ls -la ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null | grep -v "^total" | grep -v "^\." || {
    echo "ℹ️  No provisioning profiles found (this is normal for macOS apps)"
}

echo ""
echo "🎯 Recommended Setup for Distribution:"
echo "-------------------------------------"
echo "1. **Developer ID Application Certificate**"
echo "   - Required for distribution outside Mac App Store"
echo "   - Allows users to run your app without warnings"
echo ""
echo "2. **Developer ID Installer Certificate** (Optional)"
echo "   - For creating signed PKG installers"
echo "   - Not needed if using DMG distribution"
echo ""

# Check current Xcode project settings
PROJECT_DIR="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
PBXPROJ="$PROJECT_DIR/Motion Storyline.xcodeproj/project.pbxproj"

if [ -f "$PBXPROJ" ]; then
    echo "🔍 Current Project Code Signing Settings:"
    echo "----------------------------------------"
    
    CODE_SIGN_STYLE=$(grep -o 'CODE_SIGN_STYLE = [^;]*' "$PBXPROJ" | head -1 | sed 's/CODE_SIGN_STYLE = //' | tr -d ';')
    DEVELOPMENT_TEAM=$(grep -o 'DEVELOPMENT_TEAM = [^;]*' "$PBXPROJ" | head -1 | sed 's/DEVELOPMENT_TEAM = //' | tr -d ';' || echo "Not set")
    BUNDLE_ID=$(grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' "$PBXPROJ" | head -1 | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //' | tr -d '";')
    
    echo "   Code Sign Style: ${CODE_SIGN_STYLE:-Not set}"
    echo "   Development Team: ${DEVELOPMENT_TEAM:-Not set}"
    echo "   Bundle Identifier: ${BUNDLE_ID:-Not set}"
    echo ""
    
    if [ "$CODE_SIGN_STYLE" = "Automatic" ]; then
        echo "✅ Automatic code signing is enabled"
        if [ "$DEVELOPMENT_TEAM" != "Not set" ] && [ -n "$DEVELOPMENT_TEAM" ]; then
            echo "✅ Development team is configured"
        else
            echo "⚠️  Development team not set"
            echo "   Configure this in Xcode: Project Settings > Signing & Capabilities"
        fi
    else
        echo "⚠️  Manual code signing detected"
        echo "   Consider switching to Automatic for easier management"
    fi
fi

echo ""
echo "🛠️  Configuration Steps:"
echo "------------------------"
echo "1. Open Motion Storyline.xcodeproj in Xcode"
echo "2. Select the project in the navigator"
echo "3. Go to 'Signing & Capabilities' tab"
echo "4. Set your Development Team"
echo "5. Ensure 'Automatically manage signing' is checked"
echo "6. Verify the Bundle Identifier is unique"
echo ""

echo "🎯 For Distribution (DMG):"
echo "-------------------------"
echo "1. Build with Release configuration"
echo "2. Archive the app (Product > Archive)"
echo "3. Export with 'Developer ID' distribution method"
echo "4. Use our create_dmg.sh script to package"
echo "5. Notarize with our notarize.sh script"
echo ""

echo "⚠️  Important Notes:"
echo "-------------------"
echo "• Developer ID certificates expire annually"
echo "• Notarization requires app-specific passwords"
echo "• Keep your certificates backed up and secure"
echo "• Test signed builds on different machines"
echo ""

echo "🔗 Helpful Resources:"
echo "--------------------"
echo "• Apple Code Signing Guide: https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/"
echo "• Notarization Guide: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution"
echo "• Xcode Help: https://help.apple.com/xcode/mac/current/#/dev1bf96f17e"

echo ""
echo "✨ Setup complete! Configure signing in Xcode, then use build_release.sh to create your DMG." 