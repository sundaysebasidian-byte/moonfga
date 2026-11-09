# Rework 1 validation

Validated implementation commit: `9d02e92fdea05823e8d8abc48f5cca68d99e6539`.
The final documentation commit has the same implementation. Branch: `compat-0.2.3`.
All changes are local; no push, tag or publication.

Toolchain: Moon 0.1.20261104 / moonc v0.10.20+65efd5b93.
The pinned oracle is official OpenFGA v1.22.1, commit
`44054f542f64e9b9589dd26a595081b3d2cfd942` (binary reports Go 1.27.3).

```sh
export MOON_HOME=/tmp/moon-new PATH=/tmp/moon-new/bin:$PATH
```

## Commands actually completed

| Command | Result | Exit |
| --- | --- | --- |
| `moon check --deny-warn --target all` | Pass; all targets, no warnings. | 0 |
| `moon fmt --check` | Pass. | 0 |
| `moon info` | Pass; generated interfaces unchanged. | 0 |
| `git diff --exit-code -- *.mbti` | Pass; zero .mbti diff after moon info. | 0 |
| `moon test --target all` | 223/223 each: wasm, wasm-gc, JS, native. Includes all 6248 embedded official CEL outcomes. | 0 |
| `scripts/conformance.sh` | Check 516/516; ListObjects 354/354; ListUsers 393/394 (one upstream missing-expectation skip). | 0 |
| `scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/rework1-seed314159` | 1095 models / 3285 API comparisons, zero differences. | 0 |
| `scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/rework1-seed271828` | 1095 models / 3285 API comparisons, zero differences. | 0 |
| `python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/rework1-cel` | 6248 models / 18744 API comparisons, zero differences; 112 model rejections, 910 evaluation errors. | 0 |
| `python3 scripts/oracle_cel.py --seed 20261109 --output conformance-results/rework1-cel-seed20261109` | 6248 models / 18744 API comparisons, zero differences; 112 model rejections, 919 evaluation errors. | 0 |
| `python3 scripts/audit_cel_surface.py` | Audit completed: 21/22 probes match. Unconfigured Local remains different; configured Local matches. This is an inventory, not a zero-difference gate. | 0 |
| `scripts/build-web.sh` | Pass. | 0 |
| `node web/smoke.mjs` | 36/36 bundle assertions. | 0 |
| `moon run cmd/language` | Single-file 29/29; module JSON 2/2, complete diagnostic lists 4/4 (24 diagnostics); fga.mod 9/9. Fixture 06 has no module source upstream. | 0 |
| `python3 scripts/test-modules.py` | Native and JS CLI validation/transform/store-test plus path containment pass. | 0 |
| `node scripts/test-explain.mjs` | Pass. | 0 |
| `moon bench --target native` | 2/2; 100k tuples. Check 4.49 µs mean, ListObjects 23.99 ms mean. | 0 |
| `git diff --check` | Pass. | 0 |

The command list and durations are in [rework1-commands.json](rework1-commands.json).
Model rejection is compared as a result category in all three output slots; no query
is sent for a rejected model. Each CEL seed has 6136 accepted models and 18408 actual
query calls, plus 112 model rejections mirrored into 336 comparison slots.
Logs and raw corpora are retained under `conformance-results/rework1-validation/`
and the output directories named above.

## Additional browser and performance checks

- Rendered browser smoke on the validated implementation: GitHub/Drive/ABAC each return the expected Check/ListObjects/ListUsers results and pass 4/4, 4/4, 3/3 assertions. A new protobuf/bytes/Unicode-regex condition passes all three query tabs; static `1 < 2.0` displays a model error and no query result. [Observed results](rework1-browser-smoke.json). Task-owned tabs and HTTP servers were closed.
- `scripts/bench-scale.sh conformance-results/perf-r1-fast-source --targets native js wasm-gc --sizes 10000 --operations check_hit objects_many users_many`: all 99 scenarios completed. Five warmups and 30 samples; 11 shapes, three operations, three backends.
- Continuous baseline/current repeat: `python3 .upstream/perf-r1-baseline/scripts/bench_scale.py conformance-results/perf-r1-recheck-before --targets native js wasm-gc --sizes 10000 --shapes wildcard ttu20 abac ttu2 --operations check_hit objects_many users_many`, then `scripts/bench-scale.sh conformance-results/perf-r1-recheck-after --targets native js wasm-gc --sizes 10000 --shapes wildcard ttu20 abac ttu2 --operations check_hit objects_many users_many`: 36 scenarios each, all completed.
- Baseline source is an archived `5a5ec462ec3ae84eb7a7c465d37f7e6d7c5071fd`; its benchmark helper uses the archived tracked-file inventory so the nested snapshot cannot accidentally collect current sources. Runtime sources are hash-checked against that commit. The original baseline measurement and all experiments remain retained.
- The full-run median p95 ratio is 1.024; the contemporaneous repeat median is 0.985. The full run includes JS tail outliers up to 6.17x; this large-list anomaly does not recur in the continuous repeat, while some short-query p95 slowdowns remain (including native wildcard 1.17 to 2.54 us). These measurements do not establish a uniform no-regression guarantee. [Full measurements](rework1-performance-summary.json). No 1m-scale or Windows runtime measurement was performed.

## Status of requested blockers

| Item | Status and evidence |
| --- | --- |
| Model-time checking | Implemented and differential-tested: types, overloads, Boolean output, undeclared names, malformed generic declarations, protobuf fields and constant-conversion failures. The model must be validated before installation; parser/data constructors are not model-creation endpoints. |
| Partial activation / missing context | Lazy reads, deciding results and error absorption implemented. The pinned server still rejects every missing declared parameter after CEL evaluation, even `true`; the implementation reproduces that observed E2000 behavior. |
| Maps, macros, reflection, conversions and numeric behavior | Implemented and tested, including typed/exact numeric-key lookup, 3-argument map, primitive constant membership and pinned mixed-double rounding without first narrowing integers to Double. |
| Time | Implemented getters, named/fixed-offset zones, checked arithmetic, parsing/formatting and full protobuf int64 timestamp seconds. Local requires explicit host configuration. |
| Regex | Independent code-point Thompson NFA; syntax and errors exercised against the binary. Runtime resource bounds and generated Unicode data version remain explicit. |
| Resources | Default cost 100 and standard program optimization shapes implemented; threshold tests include 444 constant map programs. Engine budget/cancellation options propagate to query copies. HTTP deadlines and Local belong to the host; cancellation timing and arbitrary raised-budget resource equivalence are not proven. |
| Differential / regression tests | Two seeds each 6248 models and 18744 result/error-category comparisons; zero differences. First seed is embedded in 25 offline test segments across every backend. Both seeds retain normal, boundary, rejected-model and evaluation-error outcomes. |
| Documentation | Proposal, README, function/type/API comparison, conformance notes and 0.2.3 changelog updated. No complete-compatibility claim. |
| Portability / performance | All four local compiler/test targets pass and no new platform dependency was added. Windows execution was unavailable locally; every performance scenario cannot be certified as regression-free. |

## Remaining incompatibilities and verification limits

1. Without `condition_local_timezone`, `timestamp("2026-01-01T00:00:00Z").getHours("Local") >= 0` returns E2000 locally and true in the pinned server. Configuring America/Los_Angeles reproduces hour 16. An embedded wasm/browser engine cannot infer the operating-system timezone of an arbitrary remote server.
2. Wall-clock request deadlines are not generated implicitly by the embedded library. The host must supply `condition_cancelled`; interruption is cooperative and checked more frequently than a server request boundary, not a guarantee of identical interruption timing.
3. Regex instruction/nesting caps (3355443 / 1000), fixed Unicode 17.0.0 / tzdb 2026f data and every raised-budget cost case are not proven resource-equivalent to every server OS/build. There is no remaining observed normal-budget syntax/function mismatch in the committed corpus; this is not a proof over all inputs.
4. Upstream map traversal and simultaneous protobuf oneof field initialization have no stable trace/iteration order. The corpus uses order-independent map predicates and one active protobuf oneof field. No trace-order equivalence is claimed.
5. Windows execution and uniform performance non-regression are not verified. The limitations above prevent claiming full acceptance.

The former unsupported standard-function/type buckets have been replaced with concrete implementation and evidence. See the [function matrix](../openfga-comparison.md) for individual overloads.
