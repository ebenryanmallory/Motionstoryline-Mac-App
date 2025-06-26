# Motion Storyline Build & Distribution Scripts

This directory contains scripts for building, packaging, and distributing Motion Storyline as a professional macOS application.

## Quick Start

1. **Setup Code Signing**:
   ```bash
   ./setup_codesigning.sh
   ```

2. **Create a DMG (Development)**:
   ```bash
   ./build_release.sh
   ```

3. **Create a Notarized DMG (Production)**:
   ```bash
   export APPLE_ID="your@email.com"
   export APP_PASSWORD="your-app-specific-password"
   export TEAM_ID="YOUR_TEAM_ID"
   ./build_release.sh --notarize
   ```

## Scripts Overview

### 🚀 `build_release.sh` - Main Build Script
The complete release pipeline that orchestrates the entire process.

**Usage:**
```bash
./build_release.sh [options]

Options:
  --notarize     Submit DMG for Apple notarization
  --no-clean     Skip cleaning derived data
  --no-open      Don't open Finder when complete
  -h, --help     Show help message
```

**What it does:**
1. Cleans previous builds
2. Builds and archives the app
3. Creates a professional DMG installer
4. Optionally notarizes for distribution
5. Provides verification and next steps

### 🔨 `create_dmg.sh` - DMG Creation
Creates a professional DMG installer with custom branding.

**Features:**
- Custom background image and icon
- Proper window layout and sizing
- Applications folder symlink
- Automatic icon positioning
- Compressed final output

### 🍎 `notarize.sh` - Apple Notarization
Handles the complete notarization process for distribution outside the Mac App Store.

**Prerequisites:**
- Apple Developer Program membership
- App-specific password from Apple ID
- Valid Developer ID certificate

### 🔐 `setup_codesigning.sh` - Code Signing Setup
Helps configure code signing for your development environment.

**Checks:**
- Available certificates
- Xcode project settings
- Development team configuration
- Provides guidance for proper setup

## Configuration

### `dmg_config.conf`
Customize DMG creation settings without modifying scripts:

```bash
# App Information
APP_NAME="Motion Storyline"
DMG_TITLE="Motion Storyline Installer"

# Layout
WINDOW_WIDTH=640
WINDOW_HEIGHT=380
APP_ICON_X=170
APP_ICON_Y=200
```

### Environment Variables for Notarization

Set these in your shell profile or CI/CD environment:

```bash
export APPLE_ID="your@email.com"
export APP_PASSWORD="your-app-specific-password"  # From appleid.apple.com
export TEAM_ID="YOUR_TEAM_ID"  # 10-character Team ID
```

## Custom Assets

### Required Files (Optional)
Place these in the `assets/` directory for custom DMG branding:

- **`dmg-background.png`** (640x380 px) - DMG background image
- **`dmg-icon.icns`** - Custom volume icon

See `assets/README.md` for detailed specifications.

## Prerequisites

### Development Environment
- macOS 14.0 or later
- Xcode 15.0 or later
- Xcode Command Line Tools
- Apple Developer Program membership (for distribution)

### Required Tools
```bash
# Check if tools are available
xcodebuild -version
xcrun --version
hdiutil help

# For notarization
brew install jq  # JSON processing
```

## Code Signing Setup

### 1. Apple Developer Program
- Enroll at [developer.apple.com](https://developer.apple.com)
- Create a **Developer ID Application** certificate
- Download and install in Keychain Access

### 2. Xcode Configuration
1. Open `Motion Storyline.xcodeproj`
2. Select project → Signing & Capabilities
3. Set your Development Team
4. Enable "Automatically manage signing"
5. Verify Bundle Identifier is unique

### 3. Verification
```bash
# Check available certificates
security find-identity -v -p codesigning

# Verify project settings
./setup_codesigning.sh
```

## Distribution Workflow

### For Testing (Internal)
```bash
./build_release.sh
# Creates unsigned DMG for internal testing
```

### For Public Distribution
```bash
# Set notarization credentials
export APPLE_ID="your@email.com"
export APP_PASSWORD="your-app-specific-password"
export TEAM_ID="YOUR_TEAM_ID"

# Create notarized DMG
./build_release.sh --notarize
```

### Post-Distribution
1. Test the DMG on a clean Mac
2. Upload to your CDN/hosting
3. Update website download links
4. Create release notes

## Troubleshooting

### Common Issues

**"No code signing certificates found"**
- Run `./setup_codesigning.sh` for guidance
- Check Apple Developer portal for certificates
- Ensure certificates are installed in Keychain

**"Notarization failed"**
- Verify Apple ID credentials
- Check app-specific password
- Ensure Team ID is correct
- Review notarization logs for specific errors

**"DMG creation failed"**
- Check available disk space
- Verify app was built successfully
- Review build logs for errors

### Debug Mode
```bash
# Enable verbose logging in dmg_config.conf
ENABLE_VERBOSE_LOGGING=true
PRESERVE_TEMP_FILES=true
```

### Getting Help
1. Check script output for specific error messages
2. Review Apple's documentation for code signing and notarization
3. Verify all prerequisites are met
4. Test with a minimal example first

## File Structure

```
Scripts/
├── README.md                 # This file
├── build_release.sh         # Main build orchestrator
├── create_dmg.sh           # DMG creation
├── notarize.sh             # Apple notarization
├── setup_codesigning.sh    # Code signing setup
├── dmg_config.conf         # Configuration settings
└── assets/
    ├── README.md           # Asset specifications
    ├── dmg-background.png  # Custom background (optional)
    └── dmg-icon.icns      # Custom icon (optional)
```

## Security Notes

⚠️ **Never commit sensitive information:**
- App-specific passwords
- Private keys (.p12 files)
- Certificate signing requests
- Notarization profiles

The `.gitignore` is configured to exclude these files automatically.

## Next Steps

1. **Initial Setup**: Run `./setup_codesigning.sh`
2. **Create Assets**: Design custom DMG background and icon
3. **Test Build**: Run `./build_release.sh` for local testing
4. **Production Build**: Set up notarization and run with `--notarize`
5. **Automation**: Integrate with CI/CD for automated releases

---

🎉 **Ready to distribute Motion Storyline professionally!** 