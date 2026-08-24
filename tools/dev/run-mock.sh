#!/usr/bin/env bash
# Launch the mocked development shell headlessly and screenshot it.
#   tools/dev/run-mock.sh [seconds]
exec "$(dirname "${BASH_SOURCE[0]}")/run-headless.sh" dev-shell.qml "${1:-6}" --mock
