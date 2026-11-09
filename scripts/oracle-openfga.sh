#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="${MOON_HOME:-$HOME/.moon}/bin:$PATH"
exec python3 scripts/oracle_openfga.py "$@"
