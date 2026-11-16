# OpenFGA v1.22.1 comparison

Target: `44054f542f64e9b9589dd26a595081b3d2cfd942`, cel-go v0.31.0.
Version 0.2.5 targets the tested environment below. A passing finite corpus
establishes its tested inputs, not a proof of equivalence for arbitrary programs.

## Condition endpoint

The endpoint includes model-time type checking/rejection, Boolean output, typed
context conversion, the default CEL standard library/macros, runtime errors,
partial activation and evaluation limits, plus OpenFGA's ipaddress library.

Public Apache-2.0 semantic references; no upstream executable code copied:

- [condition environment](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/condition.go):
  default `cel.NewEnv`, eager declarations, partial evaluation, optional optimization,
  cost tracking/limit and interruption frequency. No extension libraries or explicit
  cross-type comparison option are enabled.
- [parameter types](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/types/primitives.go):
  any, bool, string, int, uint, double, duration, timestamp, recursive list<T> and
  map<string,T>. [IP library](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/types/ipaddress.go):
  `ipaddress(string)` and receiver `in_cidr(string)`.
- [numeric/context conversion](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/types/converters.go):
  numeric strings use 64-bit-precision big.Float; int64 narrowing saturates, and
  uint parameters narrow through int64. MoonFGA reproduces these observable bounds,
  including decimal/binary exponents and exact narrowing checks for double strings.
- [CEL runtime cost semantics](https://chromium.googlesource.com/external/github.com/google/cel-go/+/refs/tags/v0.31.0/interpreter/runtimecost.go):
  used as a cost specification, with an independently written counter and macro lowering.
  [program optimization semantics](https://chromium.googlesource.com/external/github.com/google/cel-go/+/refs/tags/v0.31.0/interpreter/decorators.go)
  define constant containers/conversions and primitive constant membership.
- [RE2 syntax](https://github.com/google/re2/wiki/Syntax): Boolean matching uses an
  independently written Thompson NFA. OpenFGA actually uses Go regexp; `\C`,
  backreferences and lookaround are rejected by the pinned binary.

`bytes` is an expression type, not a parameter enum. The default protobuf registry
also exposes Timestamp, Duration, Empty, Any, Value, ListValue, Struct (including
Struct.FieldsEntry) and the nine scalar wrapper messages. Their object constructors,
field checks, primitive/JSON adaptation and Any wire decoding are in scope.
FieldMask and application-specific message constructors are rejected by the pinned
environment; extension libraries are not enabled. Boolean `matches` has no capture-result API; grouping syntax
is in scope and implemented.

Two black-box findings qualify intuitive interpretations of CEL:

- Missing **declared** parameters still produce E2000 in the pinned server, even for
  `true` or `true || n > 0`. MoonFGA binds supplied parameters lazily but preserves
  the server's final missing-parameter rejection. This is not advertised as a missing
  feature that could be fixed by returning true.
- `dyn(9007199254740993) == dyn(9007199254740992.0)` is true upstream, while ordinary
  same-type integer equality remains exact. Mixed-double rounding is reproduced with
  integer-domain ties-to-even, without first casting an integer to Double. Static
  `1 < 2.0`, `1 + 2.0`, and `1 == 1.0` are rejected at model validation.

## API comparison

| Surface | Classification | Evidence / scope |
| --- | --- | --- |
| Schema 1.1 DSL / JSON | Consistent on fixtures | `cmd/language`: 29/29 |
| Schema 1.2 modules / source metadata | Consistent on supplied fixtures | 2 JSON, 4 complete diagnostic lists (24 diagnostics), fga.mod 9/9; fixture 06 lacks source input |
| Stores / model IDs / model history | Host interface equivalent for one engine | Host owns Engine/model/store; no server registry or ID/history RPC |
| Tuple write/delete/read | Host interface equivalent | MemoryStore and TupleReader tests; no transport/pagination contract |
| ReadChanges | Explicitly not implemented | No change log; synchronization belongs to host |
| Check | Consistent on tested queries | 516/516 matrix plus two seeded official binary runs |
| BatchCheck | Host interface equivalent | In-process batch/per-item results; no transport correlation contract |
| Expand | Host interface equivalent | Engine/CLI tests; no full official differential for Expand |
| ListObjects | Consistent on tested queries | 354/354; returns full in-memory result |
| ListUsers | Consistent on tested queries | 393/394; one upstream missing-expectation skip |
| Assertions / .fga.yaml | Host interface equivalent | storetest; no assertion storage/read/write RPC |
| Contextual tuples | Consistent on tested queries | Matrix and fixed/seeded oracle, including stored/contextual overlap |
| Conditions / CEL | Implemented surface with known exceptions | Function matrix and explicit counterexamples below |
| HTTP/gRPC / authentication / durable storage | Explicitly not implemented | Embedded engine; host supplies service, identity and storage |
| Pagination | Explicitly not implemented | Complete in-memory results; host paginates |
| Consistency preference | Host interface equivalent for reader snapshot | No replica routing; host controls reader snapshot |
| Condition cost and cancellation | Partial / host interface equivalent | Default condition cost 100; per-request ExecutionBudget shared across graph/CEL; E4004 deadlines, E2000 condition cost/cancellation; list timeout policy differs (below) |

Model creation corresponds to `validate.validate_model` (used by CLI/Playground and
modular model validation). `model_from_json`, DSL parsing and mutable AuthModel data
construction remain parsing/data APIs; callers must validate before installing a model.
The oracle explicitly runs validation before queries and distinguishes rejected models
from accepted models with evaluation errors. No unchecked constructor is described as
an OpenFGA WriteAuthorizationModel equivalent. Direct `cel.compile` and model checking both enforce the 250 recursive-expression boundary; ternary true arms require parentheses for nested conditionals.

## Function and type matrix

Evidence: **D** = `scripts/oracle_cel.py` (two seeds; model acceptance and all three
query APIs); **R** = `cel/oracle_test.mbt` (embedded official outcomes on every backend);
**U** = `cel/cel_test.mbt`, `cel/compat_test.mbt`; **L** = `cel/limits_test.mbt` and
`engine/condition_limits_test.mbt`; **A** = `scripts/audit_cel_surface.py` (former gaps
and host-boundary probes). Results and commands are
in [current rework validation](evidence/rework3-validation.md); earlier rework evidence is historical.
**C** = `scripts/oracle_cost.py`, `scripts/oracle_cost_openfga.py` and
`cel/cost_oracle_test.mbt` (generated actual-cost and limit regressions).

“Consistent” means the specified tested overloads, not a proof over arbitrary inputs.
Known exceptions apply even when the ordinary overload is implemented.

| Type / function / operator | Status | Behavior | Evidence |
| --- | --- | --- | --- |
| Static type / overload checking  | 所列语料通过 | Boolean output, undeclared names, unary/binary overloads, arity, conditional types, collection indexing, macros and conversions; errors at validation time | D/R, including model rejection categories |
| int / uint literals  | 所列语料通过 | Decimal and lowercase 0x hex, uint suffix, direct signed minimum, out-of-range and uppercase 0X rejection | D/R/U |
| int / uint + - * / %, unary -  | 所列语料通过 | Checked signed/unsigned overflow, division by zero, MIN/-1 division/remainder errors; repeated identical unary prefixes collapse by parity before evaluation | D/R/U |
| double + - * /  | 所列语料通过 | IEEE infinity/NaN, no integer-style divide-by-zero error; modulo rejected | D/R |
| == != < <= > >= numeric values  | 所列语料通过 | Exact same-type integer/int↔uint; pinned mixed-double rounding and unordered NaN; mixed static types rejected | D/R |
| bool, !, &&, \|\|, ?: | 所列语料通过 | Short circuit, deciding-value error absorption; undeclared/missing parameter behavior as described above | D/R/U |
| string / bytes literals  | 所列语料通过 | Unicode/hex/octal/control escapes (code points in strings, octets in bytes), BOM preservation, raw/triple forms, UTF-8 validation, byte-range errors; trailing collection commas | D/R/U |
| string / bytes == != ordering +  | 所列语料通过 | Unicode string / octet bytes comparison, concatenation | D/R/U |
| bytes(string/bytes), string(bytes)  | 所列语料通过 | UTF-8 encode/decode including invalid-byte errors; constant conversion rejection at validation | D/R |
| list / map values  | 所列语料通过 | Heterogeneous collections; string/int/uint/double/bool/null/type/duration/timestamp/ipaddress literal map keys; distinct literal numeric key types; typed-key precedence, numeric fallback for integer-keyed maps and type-strict double-keyed lookup; duplicate keys overwrite as observed upstream | D/R |
| in / index / field  | 所列语料通过 | Lists and maps, numeric-key conversion, missing key and bounds errors; field syntax distinct from zero-argument calls | D/R |
| size(x), x.size()  | 所列语料通过 | Code points for strings, octets for bytes, entry/element counts | D/R/U |
| has(field)  | 所列语料通过 | Field-presence macro, static macro-form validation | D/R |
| all / exists / exists_one  | 所列语料通过 | List values and map keys; deciding result/error propagation and macro costs | D/R/U |
| map(v,expr), map(v,predicate,expr), filter  | 所列语料通过 | Lists and map keys; selected-element evaluation and result lists | D/R/U |
| contains / startsWith / endsWith  | 所列语料通过 | Receiver string overloads | D/R/U |
| matches  | 所列语料通过 | Receiver and global overloads; groups/named/noncapturing groups, alternation, counted/lazy repetition (leading-zero counts stay literal), i/m/s/U flags, boundaries, ASCII/POSIX/Unicode classes, scalar escapes, quoted literals | D/R/U; NFA stress L; program bound below |
| int(int/uint/double/string/duration/timestamp)  | 所列语料通过 | Checked casts, decimal lexical rules, duration nanoseconds, timestamp epoch seconds | D/R |
| uint(uint/int/double/string)  | 所列语料通过 | Decimal lexical rules, negative and range errors | D/R |
| double(double/int/uint/string)  | 所列语料通过 | Decimal/hex strings and valid separators, exponent, unsigned NaN/Inf and malformed/overflow errors; signed NaN rejected | D/R |
| bool(bool/string)  | 所列语料通过 | Pinned accepted true/false/t/f/1/0 and case spellings; invalid values error | D/R |
| string(string/int/uint/double/bool/bytes/duration/timestamp)  | 所列语料通过 | Scalar formatting, negative zero, scientific exponent spelling, precise temporal forms; unsupported dynamic conversions error | D/R/U |
| duration(string/duration)  | 所列语料通过 | Exact decimal fractional parsing, Go units, signed nanosecond bounds and identity conversion | D/R |
| timestamp(string/int/timestamp)  | 所列语料通过 | RFC3339, epoch seconds, identity; constructor/context parsing differences, signed/range errors | D/R |
| duration +/-; timestamp +/- duration; timestamp - timestamp  | 所列语料通过 | Checked duration range and timestamp endpoints | D/R/U |
| duration getHours/getMinutes/getSeconds/getMilliseconds  | 所列语料通过 | Truncation toward zero at each unit | D/R |
| timestamp getFullYear/getMonth/getDate/getDayOfMonth/getDayOfWeek/getDayOfYear/getHours/getMinutes/getSeconds/getMilliseconds  | 所列语料通过；Local 默认 UTC | UTC/default, numeric offsets and named IANA zones; historical and future DST; negative epochs and sub-milliseconds | D/R; 20 host-TZ probes |
| dyn(value), any parameter  | 所列语料通过 | Erased annotation, dynamic JSON numbers as double, nested generic context types | D/R |
| type(value), type constants  | 所列语料通过 | Primitive/collection/type/null_type, google.protobuf.Duration/Timestamp/Empty and Struct.FieldsEntry; wrapper/JSON/Any names rejected as standalone type expressions | D/R |
| protobuf Timestamp / Duration constructors  | 所列语料通过 | int64 seconds/int32 nanos; normalization, full-width Go time ordering/getters/formatting; Duration saturation differs from duration(string) overflow | D/R; 864 generated extreme temporal predicates |
| BoolValue / BytesValue / StringValue / DoubleValue / FloatValue / Int32Value / Int64Value / UInt32Value / UInt64Value  | 所列语料通过 | Field types and dynamic value checks; defaults, primitive adaptation, float32 rounding, int32/uint32 narrowing errors | D/R |
| Value / Struct / ListValue / Struct.FieldsEntry  | 所列语料通过 | Null/defaults, oneof field adaptation, JSON double numbers, bytes base64, temporal strings, field presence | D/R; multi-oneof ordering caveat below |
| Any  | 所列语料通过 | Resolve supported well-known messages; independently implemented protobuf varints, fixed fields, strings, nested messages, unknown fields/groups, UTF-8 and malformed wire errors | D/R; unresolvable descriptors error |
| Qualified root names  | 所列语料通过 | `.int`, `.n`, `.google.protobuf.Timestamp`; absolute `.has` is not a registered macro | D/R |
| ipaddress(string), in_cidr(string)  | 所列语料通过 | Existing address/CIDR library and typed coercion | U and pinned ABAC matrix |
| Typed context numeric values  | 所列语料通过 | Primitive and string inputs, 64-bit binary precision decimal conversion, saturating signed narrowing, uint-through-int64, exact double narrowing | D/R, including extreme-exponent saturation |
| Cost / cancellation | 所列成本语料通过；宿主接口等价 | Per-condition cost 100; request work/deadline budget; optimized runtime cost reporting, macro/string/container costs and interruption checkpoints | C/D/R/L; concrete order/timeout policies below |
Unicode 17.0.0 and tzdb 2026f are generated data, with reproducible generators and
licenses described in [timezones.md](timezones.md). No runtime Go/OS/Node dependency
was added. Browser, JS, native and wasm all use the same MoonBit matcher and data.

## Host boundaries and remaining verification limits

1. **Local and host TZ are defined.** Unconfigured Local now means UTC. Hosts can
   configure a supported IANA zone or numeric offset; omitted getter arguments
   always use UTC and timestamp string conversion preserves the parsed offset.
   Four server TZ settings / winter and summer / conversion probes match 20/20.
   An unset TZ on macOS may use OS localtime rather than a UTC container. Host
   configuration and exact semantics are in [runtime controls](runtime-controls.md).
2. **Cost evidence and unordered maps.** The generated cel-go v0.31.0 corpus covers
   9556 programs (9168 actual-cost comparisons and 388 evaluation-error categories)
   and 44471 limit comparisons with no mismatches. It found and fixed
   constant-list membership, false `exists_one` iterations, dyn, attribute/index
   accounting, duration-string rounding and 32-bit string/regex cost overflow. 9168 successful actual-cost cases are
   embedded offline, with exact limit and one-below-limit checks on each backend.
   The separate HTTP corpus includes OpenFGA's IPAddress extension and costs at
   100/101/199/200/1000; results are in current validation evidence.
   The direct Go driver declares n:int, s:string and t:string. Type-invalid or
   OpenFGA-specific declarations are retained as compile exclusions; other typed
   contexts are covered by the existing full API corpus. Missing-declared-parameter
   cases use the API corpus because the server rejects them after partial evaluation.
   There is no local static estimator; the oracle's static estimate bounds are
   retained separately from actual runtime costs.

   A concrete irreducible difference remains for order-sensitive map short circuit:
   `{"k0":0,...,"k19":19}.exists(k,k=="k0")` at cost 100. Repeating the identical
   program 64 times upstream produces both success and cost-limit errors, with
   costs ranging from 10 to 101. Go randomizes map traversal; MoonFGA's traversal
   is deterministic. No deterministic evaluator can match each random run's exact
   visited-key count. Ordinary cost comparisons therefore use order-independent
   map predicates, and preserve the random-order probe separately. Map result order
   and multiple mutually exclusive protobuf Value oneof initialization likewise
   have no stable upstream order contract. Finite tests do not prove all inputs.
3. **Request deadlines are first-class and cooperative.** `Engine::with_budget`
   accepts an ExecutionBudget shared by Check/list/Expand/Explain/batch and CEL.
   Steps and a host cancellation/deadline predicate raise sticky E4004; per-condition
   costs/callbacks retain E2000. Host clocks/I/O remain external. The pinned server
   can return partial/empty list results on timeout, whereas this library raises
   E4004 instead of presenting an incomplete Array as complete. Timing/race winners
   and preemption of arbitrary host calls cannot be made equivalent in a synchronous
   embedded API. See [probe results and semantics](runtime-controls.md).
4. **Compilation/data resource policy.** Runtime NFA compilation remains bounded
   at 3355443 instructions and nesting at 1000 to bound memory; arbitrary
   raised-budget regex programs can hit this explicit resource error before Go.
   Model parsing/type checking and regex construction are not preemptible.
   Unicode 17.0.0 and tzdb 2026f are pinned data, so arbitrary newer server data
   require regeneration and renewed comparison. The former 100000-instruction
   rejection is fixed; this larger finite memory policy is retained deliberately.
5. **Upstream crashes are not reproduced.** Unhashable bytes/list/map keys are
   rejected locally as invalid models. The prior independent r8 review observed
   HTTP 500/panic for `{b"a":1}.size()==1`; reproducing a process crash would make an
   embedded authorization library unsafe. This deliberate difference remains
   excluded from normal valid-model comparisons.
6. **Windows coverage is explicit.** The existing windows-latest job runs native
   tests, the default build, native and wasm-gc checks, formatting and generated-interface checks.
   Build is the default wasm-gc target. It now also runs pinned offline Check/ListObjects/ListUsers and language fixtures
   on native, including generated cost/budget tests. No Go/server oracle is needed.
   JS/wasm-gc execution remains Linux CI jobs. Live server differentials are manual
   macOS-arm64/Linux-amd64 scripts, not existing CI jobs. Windows
   runtime has not been run locally or newly on GitHub in this no-push task.


## Reproduce

```sh
scripts/conformance.sh
scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/rework1-seed314159
scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/rework1-seed271828
python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/rework1-cel
python3 scripts/oracle_cel.py --seed 20261109 --output conformance-results/rework1-cel-seed20261109
python3 scripts/audit_cel_surface.py
python3 scripts/oracle_host.py
python3 scripts/oracle_cancellation.py
python3 scripts/oracle_cost.py
python3 scripts/oracle_cost_openfga.py
```

D compares Boolean values, result sets and error categories: model rejection
`M:invalid_authorization_model`, evaluation `E2000`, and other mapped request errors.
Unknown errors fail the runner. The separate host audit retains timezone and timeout responses. The raw outputs retain both model-creation and query HTTP errors.

## Rework 2 review closure

Evidence and exact commands: [Rework 2 validation](evidence/rework2-validation.md).
`scripts/r8_divergences.py` preserves the independent 25-case reproducer;
`scripts/cel_review_corpus.py` adds 389 further expressions. Both feed D and R.
These cover unary parity and macro costs, numeric token/conversion spellings,
counted-repeat grammar and character-class escape/range endpoints, hashable map
keys and indexing categories, null operators, ternary grammar and recursion limits.
Passing these examples does not establish equality for untested spellings/functions.

Map literals accept hashable scalar keys beyond protobuf/JSON map key types. The
pinned checker rejects indexing statically null/type/duration/timestamp-keyed maps;
IPAddress indexing fails at evaluation; double-keyed maps do not fall back to int
keys. Size, membership and equality are tested separately. Do not infer indexing
support from constructor acceptance.

Rework 3 adds the runtime controls and generated cost evidence described above.
