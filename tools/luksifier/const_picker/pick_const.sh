#!/bin/bash

PYTHON="python3"
# Get the directory of this script, even when called via relative path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

execute() {
    python3 -m venv /tmp/venv
    source /tmp/venv/bin/activate

    pip install --upgrade pip -q >/dev/null 2>&1
    pip install --no-cache-dir -r "${SCRIPT_DIR}/requirements.txt" -q >/dev/null 2>&1

    ${PYTHON} "${SCRIPT_DIR}/const_picker.py" "$@"

    deactivate
}

execute "$@"

