#!/bin/bash
# 打包 Helm.app + Helm.dmg(思路承 Odysseus build-macos-app.sh,壳换成真 WKWebView 窗口)。
#
#   ./build-app.sh
#
# 产物:
#   dist/Helm.app — 双击:拉起本仓 .venv 的后端(若没在跑)+ 原生窗口加载 UI
#   dist/Helm.dmg — 拖进 Applications 的镜像
#
# 启动器式打包:不内嵌 Python,仓路径在打包时烘焙进 Info.plist(HelmRoot);
# 挪仓后重打包,或用 HELM_ROOT 环境变量覆盖。
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/.." && pwd)"
DIST="$DIR/dist"
APP="$DIST/Helm.app"

echo "→ swift build -c release"
swift build -c release --package-path "$DIR"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$DIR/.build/release/HelmShell" "$APP/Contents/MacOS/Helm"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Helm</string>
    <key>CFBundleDisplayName</key>     <string>Helm</string>
    <key>CFBundleIdentifier</key>      <string>com.helm.shell</string>
    <key>CFBundleVersion</key>         <string>0.1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleExecutable</key>      <string>Helm</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>HelmRoot</key>                <string>$REPO</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP" 2>/dev/null && echo "→ ad-hoc 签名 ok" || echo "→ 未签名(本机自用可跑)"

echo "→ hdiutil → Helm.dmg"
rm -f "$DIST/Helm.dmg"
TMP="$(mktemp -d)"
mkdir "$TMP/Helm"
cp -R "$APP" "$TMP/Helm/"
ln -s /Applications "$TMP/Helm/Applications"
hdiutil create -volname "Helm" -srcfolder "$TMP/Helm" -ov -format UDZO "$DIST/Helm.dmg" >/dev/null
rm -rf "$TMP"

echo "✓ $APP"
echo "✓ $DIST/Helm.dmg"
