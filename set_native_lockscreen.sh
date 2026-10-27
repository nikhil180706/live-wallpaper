#!/bin/bash
set -e

VIDEO="$1"
if [ -z "$VIDEO" ]; then
    VIDEO="/Users/nikhilraghuvanshi/Desktop/live wallpaper/Lauma Chop Chop Var! 😳 4k Anime Girl Dance Wallpaper Live Wallpaper_2160p60 (1).mp4"
fi

if [ ! -f "$VIDEO" ]; then
    echo "❌ Error: Video file not found at: $VIDEO"
    exit 1
fi

echo "================================================="
echo " 🎬 Injecting Live Video into macOS Native Lock Screen"
echo " Video: $(basename "$VIDEO")"
echo "================================================="

AERIAL_DIR="${HOME}/Library/Application Support/com.apple.wallpaper/aerials"
VIDEOS_DIR="${AERIAL_DIR}/videos"
THUMBS_DIR="${AERIAL_DIR}/thumbnails"
TARGET_ASSET="4207734D-74FE-4F92-B5E1-6EC8DEE24A15"

mkdir -p "${VIDEOS_DIR}" "${THUMBS_DIR}"

# 1. Backup original Apple aerial if not already backed up
if [ ! -f "${VIDEOS_DIR}/${TARGET_ASSET}.mov.orig" ]; then
    if [ -f "${VIDEOS_DIR}/${TARGET_ASSET}.mov" ]; then
        cp "${VIDEOS_DIR}/${TARGET_ASSET}.mov" "${VIDEOS_DIR}/${TARGET_ASSET}.mov.orig"
    fi
fi

# 2. Inject user video
echo "✔ Copying video to macOS system aerial slot..."
cp -f "$VIDEO" "${VIDEOS_DIR}/${TARGET_ASSET}.mov"

# 3. Generate matching thumbnail
echo "✔ Generating video thumbnail..."
sips -z 180 320 "${HOME}/Pictures/LiveWallpaper/LockScreen_Wallpaper.png" --out "${THUMBS_DIR}/${TARGET_ASSET}.png" 2>/dev/null || true

# 4. Flush macOS wallpaper caches
echo "✔ Flushing macOS wallpaper and screen saver daemons..."
killall WallpaperAgent 2>/dev/null || true
killall idleassetsd 2>/dev/null || true
killall ScreenSaverEngine 2>/dev/null || true

echo ""
echo "================================================="
echo " 🎉 Live Lock Screen Video Successfully Injected!"
echo "================================================="
echo ""
echo "To see it playing live right now on your Lock Screen:"
echo "1. In the System Settings window that just opened, click 'Golden Gate Sunset' under Cityscapes."
echo "2. Press 'Control + Command + Q' on your keyboard to lock your screen."
echo "3. Watch your video loop LIVE in full 60 FPS motion!"
