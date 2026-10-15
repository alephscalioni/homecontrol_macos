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
./scripts/build-app.sh release
TOOLS="$PWD/.build/artifacts/sparkle/Sparkle/bin"
PUBLIC_KEY="$("$TOOLS/generate_keys" --account "$SIGNING_ACCOUNT" -p)"
python3 - "$UPDATE_CONFIG" "$PUBLIC_KEY" "$DOWNLOAD_BASE" <<'PY'
import json, sys
from urllib.parse import urlsplit
config = json.load(open(sys.argv[1]))
if config['publicEDKey'] != sys.argv[2].strip():
    raise SystemExit('A chave pública configurada não corresponde à conta de assinatura.')
url = urlsplit(sys.argv[3])
if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment or not url.path.endswith('/'):
    raise SystemExit('O endereço de download precisa ser HTTPS e terminar com /.')
if not urlsplit(config['feedURL']).path.endswith('/appcast.xml'):
    raise SystemExit('Este script publica um feed chamado appcast.xml.')
PY
VERSION="$(plutil -extract CFBundleShortVersionString raw build/HomeControl.app/Contents/Info.plist)"
BUILD_NUMBER="$(plutil -extract CFBundleVersion raw build/HomeControl.app/Contents/Info.plist)"
OUT="$PWD/build/updates"
ARCHIVE="$OUT/HomeControl-$VERSION-$BUILD_NUMBER.zip"
mkdir -p "$OUT"
if [[ -e "$ARCHIVE" ]]; then
    print -u2 'Esta versão já foi preparada. Aumente CFBundleVersion para gerar outra.'
    exit 1
fi
ditto -c -k --sequesterRsrc --keepParent build/HomeControl.app "$ARCHIVE"
"$TOOLS/generate_appcast" --account "$SIGNING_ACCOUNT" --download-url-prefix "$DOWNLOAD_BASE" --maximum-deltas 0 "$OUT"
"$TOOLS/sign_update" --account "$SIGNING_ACCOUNT" --verify "$OUT/appcast.xml"
print "Pacote e feed assinado prontos em: $OUT"
print 'Nenhum arquivo foi publicado. Envie o ZIP e o appcast.xml para os endereços configurados.'
