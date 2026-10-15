#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BUILD_MODE="${1:-release}"
swift build -c "$BUILD_MODE"
BIN_DIR="$(swift build -c "$BUILD_MODE" --show-bin-path)"
APP_DIR="$PWD/build/HomeControl.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/HomeControl" "$APP_DIR/Contents/MacOS/HomeControl"
cp -R "$BIN_DIR/HomeControl_HomeControl.bundle" "$APP_DIR/Contents/Resources/"
cp Info.plist "$APP_DIR/Contents/Info.plist"
UPDATE_CONFIG="${HOMECONTROL_UPDATE_CONFIG:-$PWD/config/updates.json}"
if [[ -f "$UPDATE_CONFIG" ]]; then
    python3 scripts/configure-updates.py "$APP_DIR/Contents/Info.plist" "$UPDATE_CONFIG"
elif [[ -n "${HOMECONTROL_UPDATE_CONFIG:-}" ]]; then
    print -u2 "Configuração de atualizações não encontrada: $UPDATE_CONFIG"
    exit 1
else
    python3 scripts/configure-updates.py "$APP_DIR/Contents/Info.plist"
fi
SPARKLE_ROOT="$PWD/.build/artifacts/sparkle/Sparkle"
SPARKLE_FRAMEWORK="$SPARKLE_ROOT/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "$APP_DIR/Contents/Frameworks"
rm -rf "$APP_DIR/Contents/Frameworks/Sparkle.framework"
ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE_ROOT/LICENSE" "$APP_DIR/Contents/Resources/Sparkle-LICENSE.txt"
# SwiftPM may add local absolute artifact search paths; packaged apps use only relative paths.
python3 - "$APP_DIR/Contents/MacOS/HomeControl" <<'PY'
import subprocess, sys
binary = sys.argv[1]
lines = subprocess.check_output(['otool', '-l', binary], text=True).splitlines()
for index, line in enumerate(lines):
    if line.strip() == 'cmd LC_RPATH':
        path = lines[index + 2].strip().split('path ', 1)[1].rsplit(' (offset', 1)[0]
        if path.startswith('/'):
            subprocess.run(['install_name_tool', '-delete_rpath', path, binary], check=True)
PY
if [[ "$BUILD_MODE" == release ]]; then
    # Keep crash-symbolication data outside the distributed app.
    xcrun dsymutil "$APP_DIR/Contents/MacOS/HomeControl" -o "$PWD/build/HomeControl.app.dSYM"
    # Remove debug symbol entries that retain local source and object-file paths.
    xcrun strip -S "$APP_DIR/Contents/MacOS/HomeControl"
fi
if [[ -f assets/HomeControl.icns ]]; then
    cp assets/HomeControl.icns "$APP_DIR/Contents/Resources/HomeControl.icns"
fi
if [[ -n "${HOMECONTROL_SIGNING_IDENTITY:-}" ]]; then
    FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
    for NESTED in "$FRAMEWORK"/Versions/Current/XPCServices/*.xpc(N) "$FRAMEWORK/Versions/Current/Updater.app" "$FRAMEWORK/Versions/Current/Autoupdate"; do
        codesign --force --timestamp --options runtime --sign "$HOMECONTROL_SIGNING_IDENTITY" "$NESTED"
    done
    codesign --force --timestamp --options runtime --sign "$HOMECONTROL_SIGNING_IDENTITY" "$FRAMEWORK"
    codesign --force --timestamp --options runtime --sign "$HOMECONTROL_SIGNING_IDENTITY" "$APP_DIR"
else
    # Preserve Sparkle's vendor-signed helpers; local ad-hoc signing applies to the host only.
    codesign --force --sign - "$APP_DIR"
fi
codesign --verify --deep --strict "$APP_DIR"
print "App pronto: $APP_DIR"
