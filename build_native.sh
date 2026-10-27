#!/bin/bash
set -e

echo "================================================="
echo " 🎬 Building Live Wallpaper Studio (Flagship)"
echo " macOS 27 Golden Gate Edition + Live Lock Screen"
echo "================================================="

APP_NAME="LiveWallpaper"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SAVER_NAME="LiveWallpaper.saver"

# 1. Clean and recreate bundle directories
rm -rf "${APP_BUNDLE}" "${SAVER_NAME}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 2. Copy generated AppIcon.icns if available
ICON_SRC="/Users/nikhilraghuvanshi/.gemini/antigravity/brain/e95a290f-dfe2-4812-98ec-119d44130b6d/AppIcon.icns"
if [ -f "${ICON_SRC}" ]; then
    cp "${ICON_SRC}" "${RESOURCES_DIR}/AppIcon.icns"
    cp "/Users/nikhilraghuvanshi/.gemini/antigravity/brain/e95a290f-dfe2-4812-98ec-119d44130b6d/AppIcon.png" "./AppIcon.png" 2>/dev/null || true
    echo "✔ Embedded macOS 27 App Icon into bundle"
fi

# 3. Generate Info.plist for App
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LiveWallpaper</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.livewallpaper.studio</string>
    <key>CFBundleName</key>
    <string>Live Wallpaper Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 4. Compile native LiveWallpaper.saver bundle (for moving live video on Lock Screen)
echo "Compiling Live Screen Saver bundle for Lock Screen..."
mkdir -p /tmp/clang-cache
mkdir -p "${SAVER_NAME}/Contents/MacOS"

cat << 'EOF' > "${SAVER_NAME}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LiveWallpaper</string>
    <key>CFBundleIdentifier</key>
    <string>com.livewallpaper.screensaver</string>
    <key>CFBundleName</key>
    <string>Live Wallpaper</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>LiveWallpaperSaverView</string>
</dict>
</plist>
EOF

swiftc -emit-library \
    -module-cache-path /tmp/clang-cache \
    -framework ScreenSaver \
    -framework Cocoa \
    -framework AVFoundation \
    native/saver.swift \
    -o "${SAVER_NAME}/Contents/MacOS/LiveWallpaper"

# Install into ~/Library/Screen Savers/ automatically!
mkdir -p "${HOME}/Library/Screen Savers"
rm -rf "${HOME}/Library/Screen Savers/${SAVER_NAME}"
cp -R "${SAVER_NAME}" "${HOME}/Library/Screen Savers/"
cp -R "${SAVER_NAME}" "${RESOURCES_DIR}/"
xattr -cr "${HOME}/Library/Screen Savers/${SAVER_NAME}" 2>/dev/null || true
echo "✔ Installed LiveWallpaper.saver into ~/Library/Screen Savers/"

# 5. Compile native SwiftUI Golden Gate Studio
echo "Compiling native SwiftUI Golden Gate studio..."
swiftc -O \
    -module-cache-path /tmp/clang-cache \
    -framework SwiftUI \
    -framework Cocoa \
    -framework AVFoundation \
    -framework UniformTypeIdentifiers \
    native/main.swift \
    -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

echo ""
echo "================================================="
echo " 🎉 Build Successful! Live Wallpaper Studio 2.0"
echo " Location: ${PWD}/${APP_BUNDLE}"
echo " Screen Saver: ${HOME}/Library/Screen Savers/${SAVER_NAME}"
echo "================================================="
echo ""
echo "Launch it right now with:"
echo "  open ${APP_BUNDLE}"
