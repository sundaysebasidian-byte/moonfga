# Rework 2 validation

Implementation: `42372149c5e00a4508a90c0cfc16fb9573f8e21c`; branch `compat-0.2.3`. Documentation commits do not change this implementation.
Toolchain: `MOON_HOME=/tmp/moon-new`, `/tmp/moon-new/bin` first on PATH.
Oracle: official OpenFGA v1.22.1, commit `44054f542f64e9b9589dd26a595081b3d2cfd942`.

## Completed command results

| Command | Exit |
| --- | --- |
| `moon check --deny-warn --target all` | 0 |
| `moon fmt --check` | 0 |
| `moon info` | 0 |
| `git diff --exit-code -- *.mbti` | 0 |
| `moon test --target all` | 0 |
| `scripts/conformance.sh` | 0 |
| `scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/r9-seed314159` | 0 |
| `scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/r9-seed271828` | 0 |
| `python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/r9-cel` | 0 |
| `python3 scripts/oracle_cel.py --seed 20261109 --output conformance-results/r9-cel-seed20261109` | 0 |
| `python3 scripts/oracle_openfga.py --corpus conformance-results/r8-divergences/corpus.json --output conformance-results/r9-directed` | 0 |
| `python3 scripts/audit_cel_surface.py` | 0 |
| `scripts/build-web.sh` | 0 |
| `node web/smoke.mjs` | 0 |
| `moon run cmd/language` | 0 |
| `python3 scripts/test-modules.py` | 0 |
| `node scripts/test-explain.mjs` | 0 |
| `moon bench --target native` | 0 |
| `git diff --check` | 0 |

All raw command logs are retained in `conformance-results/r9-validation/`; [command metadata](rework2/commands.json) records timing and exit codes.

- Four backend test runs: 226/226 each (wasm, wasm-gc, JS, native), including controlled FgaError for direct compilation of 10000 nested delimiters.
- Official matrix: Check 516/516, ListObjects 354/354, ListUsers 393/394; one missing-expectation upstream skip.
- Random seeds 314159 and 271828: each 1095 cases, 3285 comparisons, zero differences.
- CEL seeds 20261108 and 20261109: each 6662 models, 19986 comparison slots, zero differences. Rejected models are mirrored into three slots, rather than queried.
- Original r8 25-case corpus: 75 comparisons, zero differences. `python3 scripts/r8_divergences.py` regenerates its JSON input.
- Web bundle: 36/36 smoke checks. Language fixtures 29/29, module JSON 2/2, complete diagnostic lists 4/4 (24 diagnostics), fga.mod 9/9; missing module source fixture 06 remains unavailable upstream. Native/JS module containment and explain scripts pass.
- Separate surface audit remains 21/22; unconfigured Local is a deliberately disclosed host difference, not included in the zero-difference claim.

## Review findings

| Finding | Resolution / regression |
| --- | --- |
| Unary-chain default-budget rejection | Identical adjacent prefixes collapse by parity in the CEL parser. Single unary calls retain cost 1; setting all unary calls to zero would incorrectly admit an 8-element map with a nonconstant `!true` body. Tests cover chain lengths 1..400 and macro/operator/conversion cost thresholds. |
| RE2 counts and classes | Leading-zero/noncanonical repeat counts remain literal; canonical counts and adjacent quantifiers are validated. Shorthand/Unicode/POSIX classes followed by a dash do not act as scalar range starts; scalar range ends must remain scalar. |
| Numeric lexical forms | Reject 0X, trailing-dot float tokens and signed NaN conversion strings. Retain valid 0x floats and separators; test both literal conversion and supplied string context. |
| Map keys | Accept hashable scalar constructors, including double, IPAddress, null/type/duration/timestamp. Preserve typed double lookup without integer fallback, runtime IP indexing errors, and static index-overload rejection for null/type/duration/timestamp-keyed maps. Size, membership, equality and indexing are checked separately. |
| Null arithmetic | Null addition/subtraction accept models and error during evaluation; multiplication/division/remainder retain model-time rejection. Null ordering is accepted then errors at runtime. |
| Parser grammar and recursion | Limit recursive expression entry to 250; nested true-arm ternaries require parentheses. Unary repetition is iterative and normalized, not recursive descent. Direct compile of 10000 nested parentheses/lists is caught as FgaError on every backend. |
| Evidence scope | Comparison statuses now explicitly refer to listed passing corpora; default-budget cost equivalence is not universally certified. |

The added review module contributes 414 expressions (25 original + 389 family boundaries), included in both seeds and embedded offline expectations.

## Remaining exceptions / verification limits

- `getHours("Local")` without explicit host configuration errors locally; the server uses its OS local zone. Configure `condition_local_timezone` for the desired server-equivalent zone.
- The host supplies service deadlines/cancellation. Exact interruption timing and all cost paths at the default budget 100 **and** raised budgets are not proven equivalent; the reviewed default-budget false rejections are fixed.
- Generated Unicode 17.0.0/tzdb 2026f and regex compilation limits (3355443 instructions, nesting 1000) are fixed policies. Map iteration / multiple protobuf oneof initialization do not promise Go trace order.
- Unhashable bytes/list/map keys are rejected as invalid models. The r8 review observed an upstream HTTP 500 panic for `{b"a":1}.size()==1`; reproducing a server crash is deliberately excluded from compatibility and from the normal oracle.
- Windows runtime execution remains unverified locally. No platform dependency was added.

Before/after oracle mismatches found during this rework are retained locally; final summaries above are from completed clean runs. No full-CEL-equivalence claim is made.

## Benchmarks

`moon bench --target native`: 2/2. Initial raw results are retained, not replaced by repeats. A sequential same-host archived `c425bb2` / current implementation repeat also completes 2/2 each.

| Version | Check mean (us) | ListObjects mean (ms) |
| --- | --- | --- |
| c425bb2 archive | 6.20 | 30.99 |
| current repeat | 5.78 | 30.80 |

These are bounded 100k-tuple benchmarks, not a guarantee over all workloads or host loads. Both logs and the initial run are retained in this evidence directory.
