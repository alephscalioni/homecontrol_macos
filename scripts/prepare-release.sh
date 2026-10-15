#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ $# -lt 2 || $# -gt 3 ]]; then
    print -u2 'Uso: scripts/prepare-release.sh config/updates.local.json https://host/diretorio-dos-downloads/ [conta-de-assinatura]'
    exit 1
fi
UPDATE_CONFIG="${1:A}"
DOWNLOAD_BASE="$2"
SIGNING_ACCOUNT="${3:-br.com.homecontrol.updates}"
export HOMECONTROL_UPDATE_CONFIG="$UPDATE_CONFIG"
if [[ -n "${HOMECONTROL_PREBUILT_APP:-}" ]]; then
    APP_DIR="${HOMECONTROL_PREBUILT_APP:A}"
else
    ./scripts/build-app.sh release
    APP_DIR="$PWD/build/HomeControl.app"
fi
if [[ ! -f "$APP_DIR/Contents/Info.plist" ]]; then
    print -u2 'O aplicativo preparado não contém Contents/Info.plist.'
    exit 1
fi
codesign --verify --deep --strict "$APP_DIR"
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
PUBLIC_KEY="$("$TOOLS/generate_keys" --account "$SIGNING_ACCOUNT" -p)"
python3 - "$UPDATE_CONFIG" "$PUBLIC_KEY" "$DOWNLOAD_BASE" "$APP_DIR/Contents/Info.plist" <<'PY'
import json, plistlib, sys
from urllib.parse import urlsplit
config = json.load(open(sys.argv[1]))
if config['publicEDKey'] != sys.argv[2].strip():
    raise SystemExit('A chave pública configurada não corresponde à conta de assinatura.')
url = urlsplit(sys.argv[3])
if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment or not url.path.endswith('/'):
    raise SystemExit('O endereço de download precisa ser HTTPS e terminar com /.')
if not urlsplit(config['feedURL']).path.endswith('/appcast.xml'):
    raise SystemExit('Este script publica um feed chamado appcast.xml.')
with open(sys.argv[4], 'rb') as source:
    info = plistlib.load(source)
if info.get('SUFeedURL') != config['feedURL'] or info.get('SUPublicEDKey') != config['publicEDKey'] or info.get('SURequireSignedFeed') is not True:
    raise SystemExit('O aplicativo preparado não corresponde ao canal de atualizações configurado.')
PY
VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_DIR/Contents/Info.plist")"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw "$APP_DIR/Contents/Info.plist")"
OUT="$PWD/build/updates/$VERSION-$BUILD_NUMBER"
ARCHIVE="$OUT/HomeControl-$VERSION-$BUILD_NUMBER.zip"
mkdir -p "$OUT"
if [[ -e "$ARCHIVE" ]]; then
    print -u2 'Esta versão já foi preparada. Aumente CFBundleVersion para gerar outra.'
    exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE"
"$TOOLS/generate_appcast" --account "$SIGNING_ACCOUNT" --download-url-prefix "$DOWNLOAD_BASE" --maximum-deltas 0 "$OUT"
"$TOOLS/sign_update" --account "$SIGNING_ACCOUNT" --verify "$OUT/appcast.xml"
print "Pacote e feed assinado prontos em: $OUT"
print 'Nenhum arquivo foi publicado. Envie o ZIP e o appcast.xml para os endereços configurados.'
