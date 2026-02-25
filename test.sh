#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/tests"

VENV=.venv

if [ ! -d "$VENV" ]; then
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q -e ".[test]"
fi

case "${1:-test}" in
    install)
        python3 -m venv "$VENV"
        "$VENV/bin/pip" install -q -e ".[test]"
        ;;
    test)
        "$VENV/bin/pytest" . -v --timeout=300 -n auto
        ;;
    fast)
        "$VENV/bin/pytest" . -v -m "not ai"
        ;;
    lint)
        "$VENV/bin/pytest" test_skill_structure.py test_cross_cutting.py -v
        ;;
    *)
        echo "Usage: $0 {install|test|fast|lint}"
        exit 1
        ;;
esac
