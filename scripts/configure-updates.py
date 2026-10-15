#!/usr/bin/env python3
"""Embed public updater configuration. Never accepts a signing private key."""
import base64
import json
import plistlib
import sys
from pathlib import Path
from urllib.parse import urlsplit


def configure(plist_path, config_path=None):
    with Path(plist_path).open('rb') as stream:
        info = plistlib.load(stream)
    keys = ['SUFeedURL', 'SUPublicEDKey', 'SUAutomaticallyUpdate', 'SUVerifyUpdateBeforeExtraction',
            'SURequireSignedFeed', 'SUSignedFeedFailureExpirationInterval', 'SUEnableSystemProfiling']
    for key in keys:
        info.pop(key, None)
    if config_path:
        config = json.loads(Path(config_path).read_text())
        if set(config) != {'feedURL', 'publicEDKey'}:
            raise ValueError('Use somente feedURL e publicEDKey; nenhuma chave privada pertence à configuração.')
        feed, public_key = config['feedURL'], config['publicEDKey']
        url = urlsplit(feed)
        if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
            raise ValueError('O feed deve usar HTTPS, sem credenciais, parâmetros ou fragmento.')
        if len(base64.b64decode(public_key, validate=True)) != 32:
            raise ValueError('A chave pública Ed25519 deve ter 32 bytes em base64.')
        info.update(SUFeedURL=feed, SUPublicEDKey=public_key, SUAutomaticallyUpdate=True,
                    SUVerifyUpdateBeforeExtraction=True, SURequireSignedFeed=True,
                    SUSignedFeedFailureExpirationInterval=0, SUEnableSystemProfiling=False)
        # SUEnableAutomaticChecks stays absent: Sparkle asks for consent once.
    with Path(plist_path).open('wb') as stream:
        plistlib.dump(info, stream, sort_keys=False)


if __name__ == '__main__':
    try:
        configure(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    except (ValueError, TypeError, OSError, KeyError) as error:
        raise SystemExit(f'Configuração de atualização inválida: {error}')
