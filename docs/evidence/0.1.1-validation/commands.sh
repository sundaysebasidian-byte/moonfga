#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.moon/bin:$PATH"
moon check --deny-warn --target all
moon test --target all
moon fmt --check
moon info
git diff --exit-code -- '*.mbti'
./scripts/conformance.sh
scripts/build-web.sh
node web/smoke.mjs
node scripts/test-explain.mjs
moon run examples/library
moon run cmd/main -- validate examples/basic/model.fga
moon run cmd/main -- transform examples/basic/model.fga --to json
moon run cmd/main -- transform examples/basic/model.fga --to dsl
moon run cmd/main -- check --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer --user user:bob --explain
moon run cmd/main -- list-objects --model examples/basic/model.fga --store examples/basic/tuples.fga --type document --relation viewer --user user:bob
moon run cmd/main -- list-users --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer --filters user
moon run cmd/main -- expand --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer
moon run cmd/main -- check --model examples/abac/model.fga --store examples/abac/tuples.fga --object document:plan --relation viewer --user user:dana --context '{"office":"hq","allowed":["remote"]}'
moon run cmd/main -- test examples/basic/store.fga.yaml
moon run cmd/main -- test examples/abac/store.fga.yaml
moon run cmd/language
python3 scripts/oracle_openfga.py --seed 314159 --output docs/evidence/0.1.1-validation/oracle-314159
python3 scripts/oracle_openfga.py --seed 271828 --output docs/evidence/0.1.1-validation/oracle-271828
python3 scripts/oracle_directed.py "$PWD" "$PWD/docs/evidence/0.1.1-validation/directed"
moon run --target native cmd/conformance
moon run --target js cmd/conformance # existing Node argv prefix issue; see normalized run
node docs/evidence/0.1.1-validation/matrix-js-launcher.cjs
moon run --target wasm cmd/conformance
