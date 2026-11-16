# Rework 3 validation — 0.2.5

Implementation: `29529ea` on `compat-0.2.5`, based on main
`88912977aaa3a81edf6c2f2717d7287f5ca4ba86`. Later documentation commits do not change code.
No main-checkout edits, repository fetch, push, tag or publish were performed.

Toolchain: `MOON_HOME=/tmp/moon-new`, moon 0.1.20261104 (940aa18), moonc
v0.10.20+65efd5b93, moonrun 0.1.20261104. Final JS/CLI/web checks used Node
**v22.23.5**, matching CI's requested major. An earlier Node v24.18.0 run is retained
locally. OpenFGA v1.22.1 is checksum-verified by the existing oracle downloader;
Go dependencies pin cel-go v0.31.0 in scripts/cel-oracle/go.mod and go.sum.

## Exact command results

All 45 final local commands exited 0. [Command metadata](rework3/commands.json)
records each command, exit and duration. [Full real output](rework3/acceptance-output.txt)
pastes every result, including CLI examples. Paths are made portable and trailing
line whitespace is removed in committed transcripts; raw logs remain in
`conformance-results/rework3/validation-delivery/`.

| # | Command | Exit |
| ---: | --- | ---: |
| 0 | `moon version --all` | 0 |
| 1 | `node --version` | 0 |
| 2 | `moon update` | 0 |
| 3 | `moon info` | 0 |
| 4 | `git diff --exit-code -- '*.mbti'` | 0 |
| 5 | `moon check --deny-warn` | 0 |
| 6 | `moon check --deny-warn --target native` | 0 |
| 7 | `moon check --deny-warn --target wasm-gc` | 0 |
| 8 | `moon check --deny-warn --target js` | 0 |
| 9 | `moon check --deny-warn --target wasm` | 0 |
| 10 | `moon build` | 0 |
| 11 | `moon fmt --check` | 0 |
| 12 | `moon test --target native` | 0 |
| 13 | `moon test --target wasm-gc` | 0 |
| 14 | `moon test --target js` | 0 |
| 15 | `moon test --target wasm` | 0 |
| 16 | `scripts/build-web.sh` | 0 |
| 17 | `node web/smoke.mjs` | 0 |
| 18 | `moon run examples/library` | 0 |
| 19 | `moon run cmd/main -- validate examples/basic/model.fga` | 0 |
| 20 | `moon run cmd/main -- transform examples/basic/model.fga --to json` | 0 |
| 21 | `moon run cmd/main -- transform examples/basic/model.fga --to dsl` | 0 |
| 22 | `moon run cmd/main -- check --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer --user user:bob --explain` | 0 |
| 23 | `moon run cmd/main -- list-objects --model examples/basic/model.fga --store examples/basic/tuples.fga --type document --relation viewer --user user:bob` | 0 |
| 24 | `moon run cmd/main -- list-users --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer --filters user` | 0 |
| 25 | `moon run cmd/main -- expand --model examples/basic/model.fga --store examples/basic/tuples.fga --object document:budget --relation viewer` | 0 |
| 26 | `moon run cmd/main -- check --model examples/abac/model.fga --store examples/abac/tuples.fga --object document:plan --relation viewer --user user:dana --context '{"office":"hq","allowed":["remote"]}'` | 0 |
| 27 | `moon run cmd/main -- test examples/basic/store.fga.yaml` | 0 |
| 28 | `moon run cmd/main -- test examples/abac/store.fga.yaml` | 0 |
| 29 | `scripts/conformance.sh` | 0 |
| 30 | `moon run cmd/language` | 0 |
| 31 | `env CONFORMANCE_TARGET=native scripts/conformance.sh` | 0 |
| 32 | `moon run --target native cmd/language` | 0 |
| 33 | `python3 scripts/test-modules.py` | 0 |
| 34 | `node scripts/test-explain.mjs` | 0 |
| 35 | `scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/rework3-seed314159` | 0 |
| 36 | `scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/rework3-seed271828` | 0 |
| 37 | `python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/rework3-cel` | 0 |
| 38 | `python3 scripts/oracle_cel.py --seed 20261109 --output conformance-results/rework3-cel-seed20261109` | 0 |
| 39 | `python3 scripts/r8_divergences.py` | 0 |
| 40 | `python3 scripts/oracle_openfga.py --corpus conformance-results/r8-divergences/corpus.json --output conformance-results/rework3-directed` | 0 |
| 41 | `python3 scripts/audit_cel_surface.py` | 0 |
| 42 | `python3 scripts/oracle_host.py` | 0 |
| 43 | `python3 scripts/oracle_cost_openfga.py` | 0 |
| 44 | `git diff --check` | 0 |

Additional completed commands:

| Command | Result |
| --- | --- |
| `python3 scripts/oracle_cost.py --output conformance-results/rework3-cost-final4` | 9556 programs, 0 mismatches; full counts below |
| `TZ=UTC python3 scripts/oracle_directed.py . conformance-results/rework3-existing-directed` | 204 cases / 612 comparisons / 0 mismatches |
| `python3 scripts/oracle_cancellation.py` | raw server/CEL cancellation responses retained |
| `scripts/fetch-upstream.sh` (isolated download staging) | fixed TLS route: exit 0; 130 downloaded fixture hashes match protected cached inputs |
| `python3 scripts/generate_cost_regressions.py ...` then `moon fmt`, `git diff --exit-code -- cel/cost_oracle_test.mbt` | 9168 embedded fixtures reproduce exactly |
| `python3 -m py_compile` (new Python oracle/generator scripts) | exit 0 |
| `bash -n scripts/fetch-upstream.sh scripts/conformance.sh` | exit 0 |
| `moon bench --target native` | interleaved main/current; all runs 2/2; below |

Real final test/conformance output:

```text
$ moon test --target native
Total tests: 269, passed: 269, failed: 0.
$ moon test --target wasm-gc
Total tests: 269, passed: 269, failed: 0.
$ moon test --target js
Total tests: 269, passed: 269, failed: 0.
$ moon test --target wasm
Total tests: 269, passed: 269, failed: 0.

totals: check 516/516, list_objects 354/354, list_users 393/394
check        516/516  100.00%  (target 95%)
list_objects 354/354  100.00%  (target 90%)
list_users   393/394  99.75%  (target 90%)
```

## Differential counts and scope

- Graph seeds 314159 / 271828: each 1095 cases, 3285 comparisons, zero mismatches.
- CEL seeds 20261108 / 20261109: each 6662 models, 19986 comparison slots, zero mismatches. Rejected models occupy three mirrored slots, rather than three queries.
- Original r8 corpus: 25 cases / 75 comparisons / zero mismatches. The separate existing directed script also passes 204 cases / 612 comparisons.
- Surface audit: **22/22**, including unconfigured/configured Local (formerly 21/22). Host-TZ checks: **20/20** across empty/UTC/Los_Angeles/Kolkata, winter/summer, omitted getters and offset-preserving conversion.
- New direct CEL corpus: **9556 programs**: **9168 successful actual-cost comparisons**, **388 evaluation-error categories**, plus **44471 limit-category comparisons**, zero mismatches. 304 compile exclusions (including invalid overloads and unregistered OpenFGA extensions) are preserved in raw `compile-exclusions.json`; the HTTP corpus covers the OpenFGA extension. Direct Go declarations are n:int, s:string, t:string; other typed/missing contexts use the full API corpus.
- Full API cost corpus: **990 models / 2970 comparisons**, zero mismatches at limits 100/101/199/200/1000, including IPAddress and 500k/300k string cost-overflow probes. The pinned server panics on a configured limit below 100; [startup output](rework3/server-sub100-rejection.txt) is retained. Lower limits are tested directly with cel-go.
- 9168 successful costs are embedded in `cel/cost_oracle_test.mbt`, including exact-limit and one-below-limit checks on every backend. Runtime errors do not expose local cost reports; their error categories are compared instead. cel-go static estimate bounds are retained in raw expected.json; MoonFGA has no separate static estimator, so no static-estimate equivalence claim is made.
- Official matrix: Check 516/516, ListObjects 354/354, ListUsers 393/394; one upstream missing-expectation skip. Language 29/29; supplied module JSON/complete diagnostic fixtures and fga.mod pass; module fixture 06 lacks upstream source inputs. Web smoke: 36/36.

[Cost counts](rework3/cost-summary.json), [API cost counts](rework3/cost-api-summary.json),
[host responses](rework3/host-probes.json), [cancellation responses](rework3/cancellation-probes.json)
and [random-map probe](rework3/map-order-probe.json) retain independent evidence.
Large corpus bodies/expected/actual/errors remain under the corresponding ignored
`conformance-results/rework3-*` directories; generation scripts and offline outcomes
are committed. No finite corpus is described as a proof for all programs.

## Repairs and before/after evidence

- Local no longer raises E2000 when unconfigured; it resolves to UTC. A configured
  host zone affects explicit Local getters only. Omitted getter timezones remain UTC;
  converting a parsed timestamp to string preserves the offset.
- Constant primitive membership, exists_one false iterations, dyn, index/field/has
  costs and duration string floating-second rounding now match the pinned corpus.
- An earlier ListUsers branch condition error could hide a later exhausted budget.
  The api=2 / steps=12 reproducer fails before and passes after the priority fix;
  the regression sweeps all three query APIs over budgets 0..31. Error defers keep
  the pinned compiler deny-warn cleanup rule satisfied.
- Request ExecutionBudget is shared through contextual/list/terminal/explain/batch
  copies and CEL optimization/evaluation/NFA checkpoints. E4004 is sticky even when
  graph/logical branches could otherwise absorb an evaluation error. Conditions
  retain E2000 for cost and their existing cancellation callback.
- The larger wasm fixture module exposed stack exhaustion in nested singleton-list
  inference. The archived main CEL suite passes 42/42; the expanded module failed
  at 248 nested lists ([failure](rework3/wasm-before.txt)). Iterative singleton peeling
  fixes it without changing types. Final full wasm suite: 269/269.
- Size-dependent string/regex cost multiplication used Int32 and could wrap negative.
  The 500000-character `s.contains(s)` regression fails before the fix and passes
  after ([before](rework3/overflow-before.txt), [after](rework3/overflow-after.txt)).
  Wide multiplication rejects both overflowing contains and regex costs. A repeated
  inline-flags pattern provides a large-cost/small-program independent oracle case.
- The system curl route failed with `LibreSSL SSL_connect: SSL_ERROR_SYSCALL`.
  Python standard-library TLS downloads succeeded; the fetch script now uses that
  portable route. All 130 fixture file hashes match cached inputs. No failed download
  was counted as successful ([before](rework3/fetch-before.txt), [after](rework3/fetch-after.txt)).

An exploratory 300000-character literal regex oracle evaluation did not complete
within the inspection window. Its task-owned Go process was terminated; the failed
run is retained locally as cost-final3.txt. It is not counted as a completed regex
comparison. The final large-regex probe uses 75000 inline-flag groups to exercise
same-size cost overflow with an empty compiled program. Arbitrary enormous regex
compile/evaluation performance equivalence remains unverified.

## Workflow step coverage

| Workflow step | Local result / limit |
| --- | --- |
| actions/checkout@v4 | Existing requested worktree switched from main to compat-0.2.5 without fetch; main ref unchanged. This is not a GitHub Actions checkout execution. |
| Unix MoonBit installer + update | Installer not rerun: user required the already-installed pinned /tmp toolchain. `moon update` completed (0). CI itself still installs the current toolchain. |
| Windows installer / execution policy / MSVC setup | Not executable on this macOS host; not claimed tested. No global execution policy changed locally. |
| Toolchain version; native/wasm-gc checks; build; native tests; format; moon info/diff | All command equivalents pass, with generated mbti committed. `moon build` uses default wasm-gc. |
| setup-node@v4 node-version 22 | Actual Node v22.23.5 used for final JS unit, web and CLI-script checks; the GitHub setup action itself was not run locally. |
| extra-targets check/test wasm-gc and js | Both pass on macOS; Linux runner execution not claimed. Additional plain wasm passes; CI does not currently run it. |
| web + Pages build/smoke | Build and 36/36 Node smoke checks pass; identical commands are shared by both workflows. No new browser-rendered smoke was requested/run. |
| README library / validate / transform JSON+DSL / check+explain / list-objects / list-users / expand / ABAC / both store tests | Every command passes; full output above. |
| Fetch pinned data | Real staged download passes after TLS fix; 130/130 hashes agree with inputs used by the matrix. |
| OpenFGA offline matrix / language fixtures | Default and native variants pass. New Windows steps run native offline matrix/language; no Go/OpenFGA process required. |
| Windows generated differential expectations | Native unit tests include committed cost/model outcomes and budget/deadline tests. CI configuration is wired, not proof of a completed Windows run. |
| upload-artifact@v4 | Reports exist locally. GitHub artifact upload not executed. |
| configure-pages / upload-pages-artifact / deploy-pages | Not executed: no publish/deploy authorization; explicit task prohibition retained. |

Existing Windows CI therefore covers native execution, native/wasm-gc checking,
default build, formatting/interfaces and now native offline conformance/language.
JS/wasm-gc test execution is in Linux jobs. Live Go/server differentials are manual
macOS-arm64/Linux-amd64 scripts, not existing CI jobs. No local Windows run or new
GitHub CI run is claimed in this no-push task.

## Benchmarks

A = main 8891297 source archive; B = current branch. Same pinned toolchain,
existing 100k-tuple Check/ListObjects benchmarks, `A B B A A B` order per series.
All samples, including noisy/contended exploratory runs, are retained. Compilation
is outside MoonBit's benchmark timing. Values below are medians of the three
reported per-run means; individual samples/ranges remain in text transcripts.

| Series / code | A Check us | B Check us | B vs A | A ListObjects ms | B ListObjects ms | B vs A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| bench-clean / 72714c8 | 4.62 | 4.53 | -1.95% | 23.13 | 23.44 | +1.34% |
| bench-final / 6e45e29 | 5.05 | 4.91 | -2.77% | 26.34 | 25.52 | -3.11% |
| bench-release / 83f682e | 4.49 | 4.53 | +0.89% | 23.62 | 23.47 | -0.64% |

| bench-delivery / 29529ea | 4.52 | 4.58 | +1.33% | 23.07 | 23.34 | +1.17% |

The first exploratory series (`bench-*` without a clean/final/release suffix)
overlapped oracle work and is explicitly not acceptance evidence; its raw samples
are retained. The later short interleaved series were run without our oracle
processes. Host load still varies; neither removing slow runs nor selecting only the
best series would be valid. These bounded runs do not show a consistent regression,
but do not establish a universal or statistically tight "no regression" guarantee.
The benchmarks contain no CEL conditions, so they do not establish ABAC/regex
performance equivalence or production latency.

## Remaining concrete boundaries

The old unconfigured Local error and missing graph-wide interruption hook are
resolved. Remaining boundaries are enumerated, with reasons, in
[comparison](../openfga-comparison.md#host-boundaries-and-remaining-verification-limits)
and [runtime controls](../runtime-controls.md): Go's randomized map traversal can
change cost/limit results; the embedded list API fails with E4004 rather than
returning unmarked partial results; arbitrary host I/O/model parsing/regex
construction cannot be preempted; finite regex memory and pinned Unicode/tzdb data
remain deliberate policies; upstream unhashable-key process crashes are rejected
safely; Windows execution and full-input cost equivalence are not proven by this
macOS run. No unsupported function gap is hidden behind these limits.

## Closeout

Closeout performed no Trash moves or manual permanent deletions. Access to the native Trash was denied
with `Operation not permitted`; per the supplied closeout rules it was not retried
or bypassed. One reproducible download-staging candidate (632872 logical bytes,
132 files) remains blocked. The current worktree, shared dependencies/toolchains,
source baseline, generated inputs and all test evidence are retained. No task-owned
server remains needed; each server was terminated in its runner's finally block,
and the one interrupted large-literal oracle process was explicitly stopped.

The local manifest, empty restore map and execution log are retained at
`conformance-results/rework3/closeout/`. Final Git state/source archive and process
inventory are recorded there after the documentation commit. No disk-space release
is claimed: no Trash move occurred, and same-volume Trash movement would not itself
free space. The protected repository retains Git history; the delivery source archive
contains current tracked files only, rather than copying old contact-bearing history.
