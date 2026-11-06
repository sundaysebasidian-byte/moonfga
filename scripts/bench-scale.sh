#!/usr/bin/env bash
# Manual, offline release benchmark; intentionally not called by CI.
# Output must be a new directory. Optional --targets native js wasm-gc,
# --sizes 10000 100000 1000000, --timeout 180 (seconds per operation process).
# Filter expensive cases with --shapes group20 --operations objects_many.
set -euo pipefail
export MOON_HOME="${MOON_HOME:-/tmp/moon-new}"
export PATH="$MOON_HOME/bin:$PATH"
cd "$(dirname "$0")/.."
exec python3 scripts/bench_scale.py "$@"
