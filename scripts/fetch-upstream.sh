#!/usr/bin/env bash
# Download pinned upstream conformance data (Apache-2.0) into .upstream/ (git-ignored).
#   openfga/openfga  : assets/tests/*.yaml  (Check / ListObjects / ListUsers matrix)
#   openfga/language : tests/data           (DSL <-> JSON transformer and validation cases)
set -euo pipefail

OPENFGA_COMMIT="44054f542f64e9b9589dd26a595081b3d2cfd942"   # tag v1.22.1
LANGUAGE_COMMIT="ed62a11e759a0faa1354404ead761f956469e149"  # main @ 2026-10

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.upstream"
mkdir -p "$DEST/openfga" "$DEST/language"

fetch() { curl -fsSL --retry 3 -o "$2" "$1"; }

for f in consolidated_1_1_tests.yaml abac_tests.yaml; do
  fetch "https://raw.githubusercontent.com/openfga/openfga/$OPENFGA_COMMIT/assets/tests/$f" \
        "$DEST/openfga/$f"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fetch "https://codeload.github.com/openfga/language/tar.gz/$LANGUAGE_COMMIT" "$tmp/language.tgz"
tar -xzf "$tmp/language.tgz" -C "$tmp"
rm -rf "$DEST/language/data"
cp -R "$tmp/language-$LANGUAGE_COMMIT/tests/data" "$DEST/language/data"

{
  echo "openfga/openfga $OPENFGA_COMMIT"
  echo "openfga/language $LANGUAGE_COMMIT"
} > "$DEST/VERSIONS"
echo "upstream data ready in $DEST"
