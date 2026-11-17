# Numeric Local timezone — r10 rework round 1

Baseline `92e1949a4134b110d0dcbeb62a41a8710bb6080d`, branch `eco-r3`.
The requested r10 independent review was read before editing. All source edits
are in this worktree, including its `docs/proposal.md`; the main checkout was
not edited. No version bump, push, tag or publish.

Toolchain: moon 0.1.20261104 (940aa18), `MOON_HOME=/tmp/moon-new`;
Go go1.27.1 darwin/arm64, Node v24.18.0. Oracle: pinned OpenFGA v1.22.1
`44054f542f64e9b9589dd26a595081b3d2cfd942` and cel-go v0.31.0 from
`scripts/cel-oracle/go.mod`. Archive, binary and corpus hashes are retained in
[summary.json](numeric-local-timezone-rework1/summary.json).

| Finding | Change and verification |
| --- | --- |
| F1 | Replace the any-colon fallback with two nonempty signed decimal components separated by one colon. Other unprefixed colon strings retain E2000. Strip exactly one leading `:` for named-zone lookup, then use UTC if the stripped name is empty/unknown. Prefix notation behaves identically with the numeric flag on/off. The pinned server confirms 11 prefix cases; the old implementation fails at `:Asia/Kolkata`. Before-fix focused tests: 230/232, two failures; after fix: 232/232. |
| F2 | Choose the documentation-only compatibility boundary: unprefixed colon-free `+5`, `-8`, `+05`, `+0530` still raise E2000, although Go uses UTC. Correct runtime controls, Unreleased wording and comparison/proposal notes. Add offline assertions for all four strings with the numeric flag off/on. Do not claim general Go process-TZ equivalence. |
| F3 | Add separate Engine Check, ListObjects and ListUsers tests using a persisted conditioned tuple. Each exercises an omitted flag, explicit false and explicit true. Mutating only the Engine default false→true yields 286/289, exactly these three tests fail, exit 2. The original file is restored byte-for-byte; all final backends pass. |
| F4 | Correct the worktree proposal and rework3 closeout list; make the old S4 row explicitly historical/opt-in. Audit the whole repository with broad Local/offset and stale-phrase searches. Historical numeric evidence is marked superseded and linked to this note. The four remaining stale-pattern hits are one precise decimal-colon policy line and three unrelated evidence-retention lines; none claims a retained default numeric-offset deviation. |

At `2026-03-08T10:00:00Z`, the server confirms:

- `:Asia/Kolkata` → 15; `:America/Los_Angeles` → 3; `:Etc/GMT-5` → 15.
- `:UTC`, `::UTC`, `:+05:30`, `:`, `::Asia/Kolkata`, `:05:30`,
  `:Invalid/Zone`, `:::UTC` → 10 (UTC).

[Exact host observations](numeric-local-timezone-rework1/host-observations.json)
include the original four named zones and three numeric offsets as well.
A leading colon selects process-TZ notation, so `:+05:30` stays UTC even when
numeric Local offsets are explicitly enabled. Direct CEL getter arguments are
unchanged and do not use this host resolver.

## Commands and numeric results

From the worktree root:

```sh
export MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH
# New regressions before fixing the resolver:
moon test --target native -p cel -p engine
# 232 total / 230 passed / 2 failed
python3 scripts/r9_host_boundaries.py --output conformance-results/offset-rework1/host-before
# All 18 pinned server predicates succeed; local comparison fails at :Asia/Kolkata.
# After fixing the resolver:
moon test --target native -p cel -p engine
# 232 / 232 / 0
# Temporarily replace exactly this Engine::new declaration, then run:
# condition_allow_numeric_local_timezone~ : Bool = false -> ... = true
moon test --target native
# 289 total / 286 passed / 3 failed, exit 2; restore original bytes immediately.

export GOFLAGS=-mod=mod GOPROXY=off
python3 scripts/oracle_timestamp.py --output conformance-results/offset-rework1/timestamp
python3 scripts/oracle_host.py --output conformance-results/offset-rework1/original-host
python3 scripts/r9_host_boundaries.py --output conformance-results/offset-rework1/host
moon fmt
moon fmt --check
moon check --target native --deny-warn
moon check --target js --deny-warn
moon check --target wasm-gc --deny-warn
moon test --target native
moon test --target js
moon test --target wasm-gc
moon info
git diff --exit-code -- '*.mbti'
git diff --check
python3 -m py_compile scripts/r9_host_boundaries.py scripts/oracle_timestamp.py scripts/oracle_host.py
rg -n -i 'local.{0,70}(offset|偏移|extension|扩展)|numeric.{0,50}local|fixed-offset|three offset' --glob '!*.mbt' --glob '!*.mbti' --glob '!*.json' --glob '!*.txt' --glob '!*.go' --glob '!*.sum' --glob '!*.log' .
rg -n -i 'three offset differences|retained.{0,60}(Local|numeric offset)|fixed-offset[[:space:]]*$|Local 数值偏移扩展|three deliberate differences|colon-containing Local|numeric Local settings fall back' .
```

All final validation/oracle commands exit **0**. Tests: **289/289 on native,
JS and wasm-gc** (867 executions). The three target checks also use `--deny-warn`.
Timestamp oracle: **520 direct comparisons** (280 exact values, 240 evaluation
error categories), **2291 HTTP models / 6873 slots**, **0 mismatches**.
Original host: **20/20**. Extended r9: **18/18 pinned server Check comparisons**,
**54 default + 54 opt-in local API assertions**, **18 invalid-relation errors**,
**0 mismatches**. The r9 list outcomes are local assertions; only Check is sent
to those host servers. Full HTTP Check/ListObjects/ListUsers comparison remains
in the timestamp differential.

[Final commands/output](numeric-local-timezone-rework1/commands.json),
[mutation output](numeric-local-timezone-rework1/mutated-default-tests.txt),
[restoration hash](numeric-local-timezone-rework1/mutation.json),
[before-fix tests](numeric-local-timezone-rework1/before-tests.txt) and
[doc audit](numeric-local-timezone-rework1/doc-audit.txt) retain the proof.
Recorded outputs normalize the worktree prefix to `$REPO` and trim trailing
whitespace; raw server results, full corpora, outputs and binaries remain in
`conformance-results/offset-rework1/`. Interfaces are unchanged; after the local
commit, `moon info && git diff --exit-code -- '*.mbti'` is checked again.

## Limits and closeout

Unprefixed colon-free numeric/malformed/non-numeric Local settings are documented
E2000 boundaries, not claimed oracle matches. POSIX rules, OS TZif paths,
case-insensitive OS lookup and unset macOS TZ remain outside this host contract.
Errors are compared by evaluation category/E2000, not verbatim diagnostic text.
Windows, plain wasm, CI and publishing were not run.

All probe servers were terminated and waited for; no persistent service or
browser was opened. Current source, inputs, oracle/build/dependency caches and
evidence are retained. Nothing was moved to Trash, no moves are blocked and no
space is claimed freed. [Closeout manifest](numeric-local-timezone-rework1/closeout.json)
records Git state, fingerprints, activity and `df`; no recovery location applies.
