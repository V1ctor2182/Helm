#!/usr/bin/env bash
# Build "Helm Notch.app" from the SPM executable — a real, launchable bundle
# (double-clickable, and the base for code-signing later; see ticket #8 cluster).
set -euo pipefail
cd "$(dirname "$0")"

APP="Helm Notch.app"
EXE="HelmNotchApp"

echo "› swift build -c release"
swift build -c release --product "$EXE"

echo "› assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$EXE" "$APP/Contents/MacOS/HelmNotch"

# Bundle the vendored mediaremote-adapter (now-playing on macOS 15.4+).
cp -R Resources/mediaremote-adapter "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Helm Notch</string>
  <key>CFBundleDisplayName</key><string>Helm Notch</string>
  <key>CFBundleIdentifier</key><string>dev.helm.notch</string>
  <key>CFBundleExecutable</key><string>HelmNotch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <!-- accessory app: no Dock icon, lives in the notch + menu bar -->
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

echo "✓ built $(pwd)/$APP"
echo "  run: open \"$APP\"   (quit from the menu-bar item)"
