#!/usr/bin/env bash
# Builds the browser playground into web/dist.
#
#   scripts/build-web.sh
#
# Compiles the `playground` package for the JS backend and copies it, together
# with the static page in web/, to web/dist. Requires the MoonBit toolchain.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
export PATH="$HOME/.moon/bin:$PATH"

moon build --target js --release playground

built="_build/js/release/build/playground/playground.js"
dist="web/dist"
rm -rf "$dist"
mkdir -p "$dist"

cp "$built" "$dist/moonfga.js"
# The playground must stay free of file-system packages; a browser has no node:fs.
if grep -q 'from "node:' "$dist/moonfga.js"; then
  echo "error: playground.js imports a node: module" >&2
  exit 1
fi

for file in index.html style.css app.js examples.js explain.js; do
  cp "web/$file" "$dist/$file"
done
touch "$dist/.nojekyll"
echo "built $dist"
