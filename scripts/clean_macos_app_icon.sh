#!/bin/bash
# Clean up macOS app icon configuration
# Removes the generated .icns file and CFBundleIconFile plist key,
# leaving only CFBundleIconName for asset catalog-based icons

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-DaystingIRC.app>"
    exit 1
fi

APP_PATH="$1"
PLIST_PATH="$APP_PATH/Contents/Info.plist"
ICNS_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App bundle not found at $APP_PATH"
    exit 1
fi

echo "Cleaning up icon configuration in $APP_PATH..."

# Remove the .icns file
if [ -f "$ICNS_PATH" ]; then
    rm -f "$ICNS_PATH"
    echo "✓ Removed AppIcon.icns"
else
    echo "  AppIcon.icns not found (already clean)"
fi

# Remove CFBundleIconFile from plist, keeping only CFBundleIconName
if /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$PLIST_PATH" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$PLIST_PATH"
    echo "✓ Removed CFBundleIconFile from Info.plist"
else
    echo "  CFBundleIconFile not in Info.plist (already clean)"
fi

echo "✓ Done! The app now uses only the asset catalog icon (CFBundleIconName)."
echo ""
echo "Tip: You may need to restart Finder and the Dock for the change to take effect:"
echo "  killall Finder Dock"
