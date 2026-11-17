# Numeric Local timezone compatibility

Branch `eco-r3`, baseline `543bda293319177f64ae8ce811c7796c5e12e8b5`
(MoonFGA 0.2.5). No version bump, push, tag or publish. Tools: moon
0.1.20261104 (940aa18), Go go1.27.1 darwin/arm64, Node v24.18.0.
Oracle: cel-go v0.31.0 from the tracked `scripts/cel-oracle/go.mod` / `go.sum`,
and OpenFGA v1.22.1 commit `44054f542f64e9b9589dd26a595081b3d2cfd942`.
The OpenFGA archive SHA-256 was checked by the existing oracle loader:
`4d64ccd3ead676e3b13154bb32372421f3cd4735eda0211f5d0b7d244c689b90`.
[Machine-readable counts and input/binary hashes](numeric-local-timezone/summary.json).

## What actually differed

The three old differences were **host Local settings**, not direct CEL getter
arguments. At `2026-03-08T10:00:00Z`:

| Local host setting / Go process TZ | Pinned Go Local hour | Previous MoonFGA | New default | Explicit opt-in |
| --- | ---: | ---: | ---: | ---: |
| `+05:30` | 10 | 15 | 10 | 15 |
| `-08:00` | 10 | 2 | 10 | 2 |
| `05:30` | 10 | 15 | 10 | 15 |

Go's process TZ loader falls back to UTC for these invalid TZ settings; it does
not make the getter fail. Default MoonFGA now does the same. The former extension
requires `allow_numeric_local_timezone=true` on the CEL evaluation APIs or
`condition_allow_numeric_local_timezone=true` on `Engine::new`, both default off.
The flag affects only replacement of the explicit `"Local"` getter argument.
All Engine copies and named/inline conditions propagate it.

In contrast, direct CEL numeric arguments already match the oracle and remain
available without opt-in: `+05:30`, `-08:00`, `05:30`, `5:30`, `+5:30`, `-00:30`,
`00:00`, `+23:59`, `-23:59`, `8:+01`. The oracle also accepts empty-string UTC,
`UTC`, `Local` and `America/Los_Angeles`. The focused invalid inputs are
`24:00`, `+24:00`, `-24:00`, `00:60`, `8:-01`, `0x8:00`, `1_0:00`,
`+05:30:00`, `:30`, `5:`, `+0530`, `Z`; all produce evaluation errors in both.
[Exact direct oracle probe, including error text](numeric-local-timezone/direct-probe.json).
No numeric getter parsing change was needed.

## Reproduction and results

Run from the worktree root (`$REPO` below denotes that root):

```sh
export MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH
moon update
# Before the fix, using the original r9 script:
python3 scripts/r9_host_boundaries.py
# named_zones_matched=4, documented_numeric_offset_extensions=3,
# server_validation_errors=7
# The newly added default-fallback test before the implementation fix:
moon test --target native -p cel
# 92 tests, 91 passed, 1 failed (the numeric Local default regression)

export GOFLAGS=-mod=mod GOPROXY=off
python3 scripts/oracle_timestamp.py --output conformance-results/offset-compat/timestamp
python3 scripts/r9_host_boundaries.py --output conformance-results/offset-compat/host
python3 scripts/oracle_host.py --output conformance-results/offset-compat/original-host
moon fmt
moon fmt --check
moon check --target native
moon check --target js
moon check --target wasm-gc
moon test --target native
moon test --target js
moon test --target wasm-gc
moon info
python3 -m py_compile scripts/oracle_cel.py scripts/oracle_timestamp.py scripts/r9_host_boundaries.py
git diff --check
```

All final commands exited **0**. The intentional before-fix failing regression
is retained in [before-test.txt](numeric-local-timezone/before-test.txt).
[Final test output](numeric-local-timezone/tests.txt) and
[format/check/info command exits](numeric-local-timezone/validation-commands.json)
retain the actual results.

- Native, JS, wasm-gc: **283/283 each, 0 failed** (849 test executions).
- Direct pinned cel-go: **520 comparisons**, all 10 getters, 26 zone strings,
  literal and context arguments; **280 exact integer values + 240 evaluation
  error categories**, **0 differences**.
- Focused HTTP timestamp corpus: **2291 models / 6873 comparison slots**, with
  **2291/2291** matching in each of Check, ListObjects and ListUsers;
  **0 differences**. It includes all timestamp predicates from seed 20261108,
  the offset matrix shared with `oracle_cel.py`, and exact successful getter
  predicates generated from the independent cel-go results.
- Revised r9 host probe: **7/7 server Check comparisons**, comprising the
  **3 former numeric Local deviations + 4 named zones**. It additionally checks
  **21 default local API outcomes**, **9 opt-in local API outcomes** and
  **7 server invalid-relation errors**. Only Check is sent to the r9 host servers;
  the extra list assertions are local. [Records](numeric-local-timezone/host-results.json).
- Original host probe: **20/20**, covering winter/summer Local, omitted timezone
  arguments and timestamp string conversion under four server TZ settings.
- Updated interfaces are committed; after that commit,
  `moon info && git diff --exit-code -- '*.mbti'` exits **0**.

Raw reproducible inputs, full HTTP expected/actual/error results, server logs and
binaries remain in `conformance-results/offset-compat/` and `.upstream/oracle/`.
The tracked generator, pinned module files and summary hashes identify the inputs
and tool versions. The three old deviations are superseded by matched default
comparisons; opt-in extension assertions are separate from oracle comparisons.

## Limits and closeout

Runtime error comparisons check the evaluation category (MoonFGA E2000), not
verbatim Go diagnostic strings. This finite timestamp corpus does not prove
arbitrary-input CEL equivalence. Windows, plain wasm, publishing and CI were not
run in this task. The previously documented POSIX TZ rules, filesystem TZif paths,
noncanonical zone spellings and unset macOS process TZ limits are unchanged.

No old source copies, tester instances or long-running services were created.
Each oracle server was terminated and waited for by its probe. Current source,
inputs, tool/oracle caches and evidence are retained; no files were moved to Trash
and no recovered space is claimed. The final process/status/storage audit and
empty removal-candidate manifest are in
[closeout.json](numeric-local-timezone/closeout.json); a Trash recovery location
is not applicable because nothing was moved.
