#!/bin/bash
set -e

APP_NAME="LiveWallpaper"
TARGET_APP="${APP_NAME}.app"
SAVER_NAME="${APP_NAME}.saver"

echo "================================================="
echo " Packaging Live Wallpaper Studio for Sharing"
echo " Target: ${TARGET_APP} + ${SAVER_NAME}"
echo "================================================="

DMG_STAGING="dmg_staging"
rm -rf "${DMG_STAGING}" "LiveWallpaper.dmg" "LiveWallpaper.zip"
mkdir -p "${DMG_STAGING}"

cp -R "${TARGET_APP}" "${DMG_STAGING}/"
if [ -d "${SAVER_NAME}" ]; then
    cp -R "${SAVER_NAME}" "${DMG_STAGING}/"
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
zip -r -q "LiveWallpaper.zip" "${TARGET_APP}" "${SAVER_NAME}"

rm -rf "${DMG_STAGING}"

echo "🎉 Done! Ready to share with your friend."
