#!/bin/bash

# Script to change the iPhone app icon
# Usage: ./change_app_icon.sh <icon_name>
# Example: ./change_app_icon.sh duck

if [ -z "$1" ]; then
    echo "Available icons:"
    ls -1 images/*.png | sed 's|images/||' | sed 's|\.png||'
    echo ""
    echo "Usage: ./change_app_icon.sh <icon_name>"
    echo "Example: ./change_app_icon.sh duck"
    exit 1
fi

ICON_NAME="$1"
ICON_PATH="images/${ICON_NAME}.png"
TARGET_PATH="BabyKickTracker/Assets.xcassets/AppIcon.appiconset/appicon.png"

if [ ! -f "$ICON_PATH" ]; then
    echo "❌ Error: $ICON_PATH not found"
    exit 1
fi

# Check if image is 1024x1024 (required for app icons)
DIMENSIONS=$(file "$ICON_PATH" | grep -oE '[0-9]+ x [0-9]+')
WIDTH=$(echo $DIMENSIONS | cut -d' ' -f1)
HEIGHT=$(echo $DIMENSIONS | cut -d' ' -f3)

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "⚠️  Warning: Image is ${WIDTH}x${HEIGHT}, but app icons should be 1024x1024"
    echo "   The icon may not display correctly. Continue? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi

# Backup current icon if it exists
if [ -f "$TARGET_PATH" ]; then
    cp "$TARGET_PATH" "${TARGET_PATH}.backup"
    echo "✅ Backed up current icon to ${TARGET_PATH}.backup"
fi

# Copy new icon
cp "$ICON_PATH" "$TARGET_PATH"
echo "✅ Changed app icon to: $ICON_NAME"
echo ""
echo "📱 Next steps:"
echo "   1. Clean build folder in Xcode (Cmd+Shift+K)"
echo "   2. Build and run (Cmd+R)"
echo "   3. Check the app icon on your iPhone"
echo ""
echo "💡 To restore original: cp ${TARGET_PATH}.backup $TARGET_PATH"


