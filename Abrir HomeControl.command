#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ ! -d build/HomeControl.app ]]; then
    ./scripts/build-app.sh
fi
open build/HomeControl.app
