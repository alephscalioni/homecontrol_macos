#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
BUILD_MODE="${1:-release}"
CONFIGURATION=Release
[[ "$BUILD_MODE" == debug ]] && CONFIGURATION=Debug
TEAM_ID="${HOMECONTROL_TEAM_ID:-}"
if [[ -n "${HOMECONTROL_SIGNING_IDENTITY:-}" && -z "$TEAM_ID" ]]; then
    TEAM_ID="$(python3 - "$HOMECONTROL_SIGNING_IDENTITY" <<'PY'
import re, subprocess, sys
identities = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
for line in identities.splitlines():
    if sys.argv[1] in line:
        match = re.search(r'\(([A-Z0-9]{10})\)"', line)
        if match:
            print(match.group(1))
            break
PY
)"
fi
APP_GROUP=""
[[ -n "$TEAM_ID" ]] && APP_GROUP="$TEAM_ID.br.com.homecontrol.shared"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw Info.plist)"
APP_BUILD="$(plutil -extract CFBundleVersion raw Info.plist)"
xcodebuild -project HomeControl.xcodeproj -scheme HomeControl -configuration "$CONFIGURATION" \
    -derivedDataPath "$PWD/build/DerivedData" -clonedSourcePackagesDirPath "$PWD/.build/xcode-packages" \
    "HOME_CONTROL_APP_GROUP=$APP_GROUP" "MARKETING_VERSION=$APP_VERSION" "CURRENT_PROJECT_VERSION=$APP_BUILD" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
NATIVE_APP="$PWD/build/DerivedData/Build/Products/$CONFIGURATION/HomeControl.app"
APP_DIR="$PWD/build/HomeControl.app"
rm -rf "$APP_DIR"
ditto "$NATIVE_APP" "$APP_DIR"
UPDATE_CONFIG="${HOMECONTROL_UPDATE_CONFIG:-$PWD/config/updates.json}"
if [[ -f "$UPDATE_CONFIG" ]]; then
    python3 scripts/configure-updates.py "$APP_DIR/Contents/Info.plist" "$UPDATE_CONFIG"
elif [[ -n "${HOMECONTROL_UPDATE_CONFIG:-}" ]]; then
    print -u2 "Configuração de atualizações não encontrada: $UPDATE_CONFIG"
    exit 1
else
    python3 scripts/configure-updates.py "$APP_DIR/Contents/Info.plist"
fi
SPARKLE_ROOT="$PWD/.build/xcode-packages/artifacts/sparkle/Sparkle"
[[ -d "$SPARKLE_ROOT" ]] || SPARKLE_ROOT="$PWD/.build/artifacts/sparkle/Sparkle"
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
    xcrun dsymutil "$APP_DIR/Contents/PlugIns/HomeControlControls.appex/Contents/MacOS/HomeControlControls" -o "$PWD/build/HomeControlControls.appex.dSYM"
    xcrun strip -S "$APP_DIR/Contents/PlugIns/HomeControlControls.appex/Contents/MacOS/HomeControlControls"
fi
if [[ -f assets/HomeControl.icns ]]; then
    cp assets/HomeControl.icns "$APP_DIR/Contents/Resources/HomeControl.icns"
fi
if [[ -n "${HOMECONTROL_SIGNING_IDENTITY:-}" ]]; then
    [[ -n "$TEAM_ID" ]] || { print -u2 'Informe HOMECONTROL_TEAM_ID para habilitar o Central de Controle.'; exit 1; }
    mkdir -p "$PWD/build/code-signing"
    python3 - "$PWD/build/code-signing" "$APP_GROUP" <<'PY'
from pathlib import Path
import plistlib, sys
directory = Path(sys.argv[1])
shared = {'com.apple.security.application-groups': [sys.argv[2]]}
(directory / 'app.entitlements').write_bytes(plistlib.dumps(shared))
(directory / 'controls.entitlements').write_bytes(plistlib.dumps({**shared, 'com.apple.security.app-sandbox': True}))
PY
    FRAMEWORK="$APP_DIR/Contents/Frameworks/Sparkle.framework"
    for NESTED in "$FRAMEWORK"/Versions/Current/XPCServices/*.xpc(N) "$FRAMEWORK/Versions/Current/Updater.app" "$FRAMEWORK/Versions/Current/Autoupdate"; do
        codesign --force --timestamp --options runtime --sign "$HOMECONTROL_SIGNING_IDENTITY" "$NESTED"
    done
    codesign --force --timestamp --options runtime --sign "$HOMECONTROL_SIGNING_IDENTITY" "$FRAMEWORK"
    codesign --force --timestamp --options runtime --entitlements "$PWD/build/code-signing/controls.entitlements" --sign "$HOMECONTROL_SIGNING_IDENTITY" "$APP_DIR/Contents/PlugIns/HomeControlControls.appex"
    codesign --force --timestamp --options runtime --entitlements "$PWD/build/code-signing/app.entitlements" --sign "$HOMECONTROL_SIGNING_IDENTITY" "$APP_DIR"
else
    # Preserve Sparkle's vendor-signed helpers; local ad-hoc signing applies to the host only.
    mkdir -p "$PWD/build/code-signing"
    python3 - "$PWD/build/code-signing/controls-adhoc.entitlements" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as output:
    plistlib.dump({'com.apple.security.app-sandbox': True}, output)
PY
    codesign --force --entitlements "$PWD/build/code-signing/controls-adhoc.entitlements" --sign - "$APP_DIR/Contents/PlugIns/HomeControlControls.appex"
    codesign --force --sign - "$APP_DIR"
fi
codesign --verify --deep --strict "$APP_DIR"
print "App pronto: $APP_DIR"
