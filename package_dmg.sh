#!/bin/bash
set -e

APP_NAME="LiveWallpaper"
APP_SRC="LiveWallpaper.app"
if [ ! -d "$APP_SRC" ]; then
    APP_SRC="/Applications/LiveWallpaper.app"
fi

SAVER_SRC="LiveWallpaper.saver"
if [ ! -d "$SAVER_SRC" ]; then
    SAVER_SRC="${HOME}/Library/Screen Savers/LiveWallpaper.saver"
fi

echo "================================================="
echo " Packaging Live Wallpaper Studio for Sharing"
echo " Source: ${APP_SRC} + ${SAVER_SRC}"
echo "================================================="

DMG_STAGING="dmg_staging"
rm -rf "${DMG_STAGING}" "LiveWallpaper.dmg" "LiveWallpaper.zip"
mkdir -p "${DMG_STAGING}"

cp -R "${APP_SRC}" "${DMG_STAGING}/LiveWallpaper.app"
if [ -d "${SAVER_SRC}" ]; then
    cp -R "${SAVER_SRC}" "${DMG_STAGING}/LiveWallpaper.saver"
fi

ln -s /Applications "${DMG_STAGING}/Applications"

echo "Creating LiveWallpaper.dmg..."
hdiutil create \
    -volname "Live Wallpaper Installer" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "LiveWallpaper.dmg"

echo "Creating LiveWallpaper.zip..."
zip -r -q "LiveWallpaper.zip" "${DMG_STAGING}/LiveWallpaper.app" "${DMG_STAGING}/LiveWallpaper.saver"

rm -rf "${DMG_STAGING}"

echo "🎉 Done! Ready to share with your friend."
