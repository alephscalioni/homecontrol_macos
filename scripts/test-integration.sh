#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
FIXTURE_PORT="${HA_TEST_PORT:-18765}"
python3 scripts/mock-ha.py "$FIXTURE_PORT" &
FIXTURE_PID=$!
trap 'kill "$FIXTURE_PID" 2>/dev/null || true' EXIT
for attempt in {1..30}; do
    if curl --silent --fail "http://127.0.0.1:$FIXTURE_PORT" >/dev/null; then
        HA_TEST_SERVER="http://127.0.0.1:$FIXTURE_PORT" swift test
        exit $?
    fi
    sleep 0.1
done
print -u2 'O servidor de testes não iniciou.'
exit 1
