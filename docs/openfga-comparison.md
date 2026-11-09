# OpenFGA v1.22.1 comparison

Target: `44054f542f64e9b9589dd26a595081b3d2cfd942`, cel-go v0.31.0.
This unreleased 0.2.3 revision has known incompatibilities below. It is not a claim
of complete CEL compatibility. A passing corpus establishes its tested inputs only.

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
| Condition cost and cancellation | Partial / host interface equivalent | Default budget 100; Engine constructor accepts condition_cost_limit and condition_cancelled; no implicit server request deadline |

Model creation corresponds to `validate.validate_model` (used by CLI/Playground and
modular model validation). `model_from_json`, DSL parsing and mutable AuthModel data
construction remain parsing/data APIs; callers must validate before installing a model.
The oracle explicitly runs validation before queries and distinguishes rejected models
from accepted models with evaluation errors. No unchecked constructor is described as
an OpenFGA WriteAuthorizationModel equivalent.

## Function and type matrix

Evidence: **D** = `scripts/oracle_cel.py` (two seeds; model acceptance and all three
query APIs); **R** = `cel/oracle_test.mbt` (embedded official outcomes on every backend);
**U** = `cel/cel_test.mbt`, `cel/compat_test.mbt`; **L** = `cel/limits_test.mbt` and
`engine/condition_limits_test.mbt`; **A** = `scripts/audit_cel_surface.py` (former gaps
and separate, deliberately failing known-boundary probes). Results and commands are
in [rework validation](evidence/rework1-validation.md).

“Consistent” means the specified tested overloads, not a proof over arbitrary inputs.
Known exceptions apply even when the ordinary overload is implemented.

| Type / function / operator | Status | Behavior | Evidence |
| --- | --- | --- | --- |
| Static type / overload checking  | 一致（已测） | Boolean output, undeclared names, unary/binary overloads, arity, conditional types, collection indexing, macros and conversions; errors at validation time | D/R, including model rejection categories |
| int / uint literals  | 一致（已测） | Decimal and hex, uint suffix, direct signed minimum, out-of-range rejection | D/R/U |
| int / uint + - * / %, unary -  | 一致（已测） | Checked signed/unsigned overflow, division by zero, MIN/-1 division/remainder errors | D/R/U |
| double + - * /  | 一致（已测） | IEEE infinity/NaN, no integer-style divide-by-zero error; modulo rejected | D/R |
| == != < <= > >= numeric values  | 一致（已测） | Exact same-type integer/int↔uint; pinned mixed-double rounding and unordered NaN; mixed static types rejected | D/R |
| bool, !, &&, \|\|, ?: | 一致（已测） | Short circuit, deciding-value error absorption; undeclared/missing parameter behavior as described above | D/R/U |
| string / bytes literals  | 一致（已测） | Unicode/hex/octal/control escapes (code points in strings, octets in bytes), BOM preservation, raw/triple forms, UTF-8 validation, byte-range errors; trailing collection commas | D/R/U |
| string / bytes == != ordering +  | 一致（已测） | Unicode string / octet bytes comparison, concatenation | D/R/U |
| bytes(string/bytes), string(bytes)  | 一致（已测） | UTF-8 encode/decode including invalid-byte errors; constant conversion rejection at validation | D/R |
| list / map values  | 一致（已测） | Heterogeneous collections; string/int/uint/bool map keys; distinct literal numeric key types; exact typed-key precedence and exact numeric fallback; duplicate keys overwrite as observed upstream | D/R |
| in / index / field  | 一致（已测） | Lists and maps, numeric-key conversion, missing key and bounds errors; field syntax distinct from zero-argument calls | D/R |
| size(x), x.size()  | 一致（已测） | Code points for strings, octets for bytes, entry/element counts | D/R/U |
| has(field)  | 一致（已测） | Field-presence macro, static macro-form validation | D/R |
| all / exists / exists_one  | 一致（已测） | List values and map keys; deciding result/error propagation and macro costs | D/R/U |
| map(v,expr), map(v,predicate,expr), filter  | 一致（已测） | Lists and map keys; selected-element evaluation and result lists | D/R/U |
| contains / startsWith / endsWith  | 一致（已测） | Receiver string overloads | D/R/U |
| matches  | 一致（已测） | Receiver and global overloads; groups/named/noncapturing groups, alternation, counted/lazy repetition, i/m/s/U flags, boundaries, ASCII/POSIX/Unicode classes, scalar escapes, quoted literals | D/R/U; NFA stress L; program bound below |
| int(int/uint/double/string/duration/timestamp)  | 一致（已测） | Checked casts, decimal lexical rules, duration nanoseconds, timestamp epoch seconds | D/R |
| uint(uint/int/double/string)  | 一致（已测） | Decimal lexical rules, negative and range errors | D/R |
| double(double/int/uint/string)  | 一致（已测） | Decimal/hex strings, exponent, NaN/Inf and malformed/overflow errors | D/R |
| bool(bool/string)  | 一致（已测） | Pinned accepted true/false/t/f/1/0 and case spellings; invalid values error | D/R |
| string(string/int/uint/double/bool/bytes/duration/timestamp)  | 一致（已测） | Scalar formatting, negative zero, scientific exponent spelling, precise temporal forms; unsupported dynamic conversions error | D/R/U |
| duration(string/duration)  | 一致（已测） | Exact decimal fractional parsing, Go units, signed nanosecond bounds and identity conversion | D/R |
| timestamp(string/int/timestamp)  | 一致（已测） | RFC3339, epoch seconds, identity; constructor/context parsing differences, signed/range errors | D/R |
| duration +/-; timestamp +/- duration; timestamp - timestamp  | 一致（已测） | Checked duration range and timestamp endpoints | D/R/U |
| duration getHours/getMinutes/getSeconds/getMilliseconds  | 一致（已测） | Truncation toward zero at each unit | D/R |
| timestamp getFullYear/getMonth/getDate/getDayOfMonth/getDayOfWeek/getDayOfYear/getHours/getMinutes/getSeconds/getMilliseconds  | 一致（显式时区）；Local 需宿主配置 | UTC/default, numeric offsets and named IANA zones; historical and future DST; negative epochs and sub-milliseconds | D/R; Local exception below |
| dyn(value), any parameter  | 一致（已测） | Erased annotation, dynamic JSON numbers as double, nested generic context types | D/R |
| type(value), type constants  | 一致（已测） | Primitive/collection/type/null_type, google.protobuf.Duration/Timestamp/Empty and Struct.FieldsEntry; wrapper/JSON/Any names rejected as standalone type expressions | D/R |
| protobuf Timestamp / Duration constructors  | 一致（已测） | int64 seconds/int32 nanos; normalization, full-width Go time ordering/getters/formatting; Duration saturation differs from duration(string) overflow | D/R; 864 generated extreme temporal predicates |
| BoolValue / BytesValue / StringValue / DoubleValue / FloatValue / Int32Value / Int64Value / UInt32Value / UInt64Value  | 一致（已测） | Field types and dynamic value checks; defaults, primitive adaptation, float32 rounding, int32/uint32 narrowing errors | D/R |
| Value / Struct / ListValue / Struct.FieldsEntry  | 一致（已测） | Null/defaults, oneof field adaptation, JSON double numbers, bytes base64, temporal strings, field presence | D/R; multi-oneof ordering caveat below |
| Any  | 一致（已测） | Resolve supported well-known messages; independently implemented protobuf varints, fixed fields, strings, nested messages, unknown fields/groups, UTF-8 and malformed wire errors | D/R; unresolvable descriptors error |
| Qualified root names  | 一致（已测） | `.int`, `.n`, `.google.protobuf.Timestamp`; absolute `.has` is not a registered macro | D/R |
| ipaddress(string), in_cidr(string)  | 一致（已测） | Existing address/CIDR library and typed coercion | U and pinned ABAC matrix |
| Typed context numeric values  | 一致（已测） | Primitive and string inputs, 64-bit binary precision decimal conversion, saturating signed narrowing, uint-through-int64, exact double narrowing | D/R, including extreme-exponent saturation |
| Cost / cancellation  | 部分 / 宿主接口等价 | Portable per-condition state, default cost 100, counted string operations, macro lowering, constant program optimization, host cancellation, regex interruption checks | D/R/L; optimizer exceptions below |
Unicode 17.0.0 and tzdb 2026f are generated data, with reproducible generators and
licenses described in [timezones.md](timezones.md). No runtime Go/OS/Node dependency
was added. Browser, JS, native and wasm all use the same MoonBit matcher and data.

## Host boundaries and remaining verification limits

1. **Unconfigured Local differs from the server.** The final audit has one difference:
   the default embedded engine returns E2000 for `getHours("Local")`, while the
   server uses its OS-configured local zone. This is now a host interface: set
   `Engine::new(..., condition_local_timezone=Some("America/Los_Angeles"))`, or the
   CEL evaluation API's `local_timezone`. The configured Local probe matches the
   official server's hour 16 at 2026-01-01T00:00:00Z. There is no universal default
   Local across server, browser and wasm environments; it must be supplied by the
   host. The missing-host-setting difference is not hidden in a zero-difference claim.
2. **Costs and service deadlines.** Default-budget macro/string thresholds are
   differential-tested, including 444 additional constant-conversion/container map
   programs that previously exposed premature budget errors. The pinned program
   optimization shapes are implemented independently: constant containers, standard
   unary conversions and primitive constant membership. Exact cost equivalence over
   every possible program and raised budget is unproven. The Engine accepts condition_cost_limit and a
   condition_cancelled callback, retained through Check/list engine copies. HTTP
   request and List API wall-clock deadlines remain transport responsibilities.
   Cancellation is cooperative during expression/NFA execution, not a preemptive
   interrupt during arbitrary host work or model parsing.
3. **Compilation/data resource limits.** Regex model validation now parses syntax
   separately from NFA construction; the former 100000-instruction rejection
   counterexample is resolved. Runtime NFA compilation is bounded at 3355443
   instructions and nesting at 1000; this is an implementation memory policy, not
   an unsupported syntax list. Default-cost corpus and the former bound probe match;
   arbitrary raised-budget/large-program memory equivalence is unproven. Named
   timezone data are pinned to 2026f, rather than tracking an arbitrary server OS's
   later data updates. Regeneration and renewed comparison are required for updates.

The former function/type blockers are implemented and covered by the pinned oracle.
This is a tested-surface statement, not a proof of equivalence over all programs. The ordinary surface probes pass, but the unconfigured Local counterexample
and the host/resource verification limits prevent a claim of complete compatibility.
For multi-key map macros the oracle uses order-independent predicates; no map
iteration-order guarantee or trace-order equivalence is claimed. Initializing several
mutually exclusive protobuf Value oneof fields likewise has no stable field-order
contract upstream; the differential uses a single active oneof field. Windows runtime
execution remains unverified locally. The browser-rendered Playground smoke passes
its three examples, new CEL condition queries and static-rejection check.

## Reproduce

```sh
scripts/conformance.sh
scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/rework1-seed314159
scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/rework1-seed271828
python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/rework1-cel
python3 scripts/oracle_cel.py --seed 20261109 --output conformance-results/rework1-cel-seed20261109
python3 scripts/audit_cel_surface.py
```

D compares Boolean values, result sets and error categories: model rejection
`M:invalid_authorization_model`, evaluation `E2000`, and other mapped request errors.
Unknown errors fail the runner. A separate host-boundary audit is not merged into a zero-difference
claim. The raw outputs retain both model-creation and query HTTP errors.
