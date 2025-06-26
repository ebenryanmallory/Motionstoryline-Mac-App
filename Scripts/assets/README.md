# DMG Assets Directory

This directory contains assets for customizing the Motion Storyline DMG installer.

## Required Files

### dmg-background.png
- **Size**: 640x380 pixels recommended
- **Format**: PNG with transparency support
- **Purpose**: Background image for the DMG installer window
- **Design Tips**: 
  - Use your app's branding colors
  - Include subtle visual cues for where to drag the app
  - Keep it clean and professional

### dmg-icon.icns
- **Format**: Apple Icon (.icns) format
- **Purpose**: Custom icon for the DMG volume
- **Source**: Can be created from your app icon or a custom installer icon
- **Tool**: Use `iconutil` or `sips` to convert from PNG to ICNS

## Creating Assets

### Background Image
1. Create a 640x380 PNG in your favorite design tool
2. Include your app logo/branding
3. Optionally add visual hints like arrows pointing to Applications folder
4. Save as `dmg-background.png` in this directory

### DMG Icon
Convert your app icon or create a custom installer icon:

```bash
# Convert PNG to ICNS (requires PNG at multiple sizes)
iconutil -c icns AppIcon.iconset -o dmg-icon.icns

# Or use sips for simple conversion
sips -s format icns AppIcon.png --out dmg-icon.icns
```

## Fallback Behavior

If these files are not present, the DMG creation script will:
- Use a plain white background
- Use the default macOS disk icon
- Still create a functional installer, just without custom branding

## Example Layout

Your DMG window will show:
- Motion Storyline.app (positioned at 170, 200)
- Applications folder symlink (positioned at 470, 200)
- Custom background image (if provided)
- Custom volume icon (if provided) 