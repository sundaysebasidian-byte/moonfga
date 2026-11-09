# OpenFGA v1.22.1 compatibility boundary

Reference: OpenFGA commit `44054f542f64e9b9589dd26a595081b3d2cfd942`.
0.2.3 is an unreleased compatibility increment, **not full CEL compatibility**.
“Consistent” below means the named tested surface, not all possible inputs.
Unimplemented CEL rows are required work toward the endpoint, not permanent exclusions.

## Endpoint and upstream environment

The endpoint is the full condition language exposed by the pinned OpenFGA server,
including model-time compilation/rejection, typed context conversion, partial evaluation,
standard overloads/macros, runtime errors and evaluation limits. Passing the authorization
matrix alone does not establish that endpoint.

Inspected public Apache-2.0 sources (semantics only; no implementation copied):

- [condition environment](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/condition.go):
  `cel.NewEnv`, custom type registrations, eager declaration validation, per-parameter
  variables, Boolean output requirement, partial evaluation; optional optimization,
  tracked cost, cost limit and interruption frequency.
- [parameter types](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/types/primitives.go):
  any, bool, string, int, uint, double, duration, timestamp, list<T>, map<string,T>;
  [ipaddress](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/internal/condition/types/ipaddress.go)
  adds `ipaddress(string)` and `ipaddress.in_cidr(string)`.
- [go.mod](https://github.com/openfga/openfga/blob/44054f542f64e9b9589dd26a595081b3d2cfd942/go.mod)
  pins cel-go v0.31.0. The condition environment does not explicitly enable extension
  libraries or cross-type numeric comparisons. Black-box probes confirm static
  `1 < 2.0` and `1 + 2.0` are rejected during model creation.

`bytes` is an expression type (literals/conversion), not an OpenFGA parameter enum.
No application protobuf message descriptors or extension libraries are registered in
this environment. Arbitrary protobuf constructors and string-extension capture APIs
are therefore outside this endpoint. RE2 grouping inside Boolean `matches` **is** in scope.

## API comparison

| Surface | Classification | Evidence / boundary |
| --- | --- | --- |
| Schema 1.1 DSL / JSON / validation | Consistent on fixtures | `cmd/language`: 29/29; exhaustive malformed-model equivalence unproven |
| Schema 1.2 modules / source metadata | Consistent on available fixtures | module JSON 2/2, diagnostics 4/4 (24 diagnostics), fga.mod 9/9; fixture 06 has no source input |
| Stores / authorization model IDs and history | Host interface equivalent for single engine | Host owns Engine/model/store lifetime; no server store registry, model ID/history API |
| Tuple write/delete/read | Host interface equivalent | `store/memory.mbt`, store tests, `TupleReader`; no wire protocol/pagination equivalence claim |
| ReadChanges | Explicitly not implemented | No change log; host must implement synchronization |
| Check | Consistent on matrix/oracle | 516/516, two seeded runs; errors/depth/contextual regression tests |
| BatchCheck | Host interface equivalent | In-process batch and per-item results; no server correlation ID/transport contract |
| Expand | Host interface equivalent | Engine/CLI tests; no full official differential for this API |
| ListObjects | Consistent on matrix/oracle | 354/354; complete in-memory result, no streamed transport |
| ListUsers | Consistent on matrix/oracle | 393/394, one missing-expectation skip |
| Assertions / .fga.yaml tests | Host interface equivalent | `storetest` runner; no assertion storage/read/write RPCs |
| Contextual tuples | Consistent on tested queries | engine tests and fixed/seeded oracle, including stored/contextual overlap |
| Conditions | Incomplete; see matrix below | Existing ABAC matrix plus new CEL corpus do not prove full CEL |
| HTTP/gRPC server, authn, persistence | Explicitly not implemented | Embeddable engine; host supplies transport, authentication and durable storage |
| Pagination / continuation tokens | Explicitly not implemented | Complete in-memory results; host must paginate |
| Consistency preference | Explicitly not implemented | No replica routing; host controls reader snapshot |
| Cancellation / CEL cost limits | Explicitly not implemented in this revision | Cannot reproduce upstream resource-exhaustion boundary; required for full condition endpoint |

## CEL type / function matrix

Evidence aliases: **U** = `cel/cel_test.mbt`; **R** = `cel/compat_test.mbt`
(52 fixed official expectations on every backend); **D** = `scripts/oracle_cel.py`
(52 fixed + 256 generated expressions, seed 20261108, 924 Check/ListObjects/ListUsers
comparisons); **A** = `scripts/audit_cel_surface.py` and
[evidence/cel-surface.json](evidence/cel-surface.json), explicit unresolved probes.
“Partial” always means incomplete, even if the successful overload has evidence.

| Type / function / operator | Status | Evidence and exact limit |
| --- | --- | --- |
| int / uint literals, + - * / %, unary - | Consistent for tested boundaries | U/R/D: checked overflow, divide by zero, MIN/-1 division and remainder errors; hex and direct MIN literal syntax not implemented |
| double, + - * / | Partial | U; division by zero currently errors instead of IEEE infinity/NaN (A) |
| bool, !, &&, \|\|, ?: | Consistent for tested inputs | U/R/D: short circuit and deciding-value error absorption; unknown/partial activation not implemented |
| string literals | Partial | U/R/D: UTF-8, Unicode/hex/octal escapes, raw/triple forms; complete CEL lexical/static rejection equivalence unproven |
| bytes literals, == != < <= > >=, +, size / .size | Consistent on corpus | R/D: arbitrary octets, UTF-8 size, raw/triple forms, escape rejection local tests |
| bytes(string), bytes(bytes), string(bytes) | Consistent on tested values | R/D: UTF-8 and invalid UTF-8 runtime error; invalid constant conversion can fail earlier in official model compilation |
| bytes in list / map values, in, indexing | Consistent on corpus | R/D: heterogeneous list and string-key map values; bytes map keys are not CEL standard keys |
| list, +, in, index, size / .size | Partial | U/R/D: ordinary and heterogeneous values; exact numeric cross-type equality at large magnitudes unproven |
| map, in, field/index, size / .size | Partial | U/R/D: string keys only; CEL bool/int/uint keys and duplicate-key errors not implemented (A) |
| exists, exists_one, all | Partial | U/R/D: list iteration and error absorption; map-key iteration not implemented (A) |
| map(v, expr), filter(v, predicate) | Partial | U: lists; map-key iteration absent |
| map(v, predicate, expr) | Not implemented | A: official true, local E2000 |
| has(field) | Partial | R/D: string-key maps; parser conflates field selection with zero-argument method calls; full static macro validation absent |
| size(value), value.size() | Partial | U/R/D: string code points, bytes octets, collection elements; exact invalid-arity/static rejection incomplete |
| contains / startsWith / endsWith | Consistent on tested strings | U; complete overload/static rejection not proven |
| matches | Partial | U: literals, dot, classes/ranges, escaped ASCII classes, * + ?, ^ $, top-level alternation; not RE2-equivalent |
| int(int/uint/double/string) | Partial | R/D: uint/double overflow; timestamp/duration conversions absent (A); numeric-string lexical equivalence unproven |
| uint(uint/int/double/string) | Partial | R/D: negative/overflow errors; numeric-string lexical equivalence unproven |
| double(double/int/uint/string) | Partial | U/R/D: basic conversions; infinity/NaN formatting and parser equivalence unproven |
| bool(bool/string) | Partial | R/D: true/false; full accepted string spelling set unproven |
| string(string/int/uint/double/bool/bytes/duration/timestamp) | Partial | U/R/D: string identity/uint suffix corrected; duration fractional formatting and floating point spelling not fully equivalent; invalid conversion overloads not statically rejected |
| duration(string/duration), timestamp(string/int/timestamp) | Partial | U: string constructors; identity/int constructors absent (A), duration range/precision and timestamp validation differences remain |
| duration +/-, timestamp +/- duration, timestamp - timestamp | Partial | U: normal values; overflow/range not fully checked |
| duration getHours/getMinutes/getSeconds/getMilliseconds | Partial | U: Seconds/Milliseconds only; Hours/Minutes absent (A) |
| timestamp getFullYear/getMonth/getDayOfYear/getDayOfMonth/getDate/getDayOfWeek/getHours/getMinutes/getSeconds/getMilliseconds | Partial | Only Seconds/Milliseconds implemented; Seconds incorrectly returns second-of-day, negative millis handling differs; all timezone arguments ignored/unsupported; A includes full-year and IANA-zone failures |
| dyn(value), any parameter | Partial | R/D: dyn identity; any context coercion/nested generic parameter representation incomplete |
| type(value), type constants | Not implemented | A: `type(b"a") == bytes` official true, local E2000 |
| ipaddress(string), in_cidr(string) | Consistent on tested addresses | U and pinned ABAC fixtures; exhaustive parser/error equivalence unproven |
| == / != cross-type numeric values | Partial | U; current Double conversion can lose large integer precision |
| cross-type numeric ordering / mixed arithmetic | Incompatible acceptance | A: local evaluates inputs official rejects at model creation; dynamic numeric ordering precision not fully equivalent |
| protobuf messages / optional / strings extension functions | Outside pinned environment | No application descriptors or extension libraries registered upstream; not a missing MoonFGA promise |

### RE2 differences and impact

The portable handwritten matcher is not a RE2 implementation. A proves grouping,
counted repetition, inline flags and Unicode properties currently return false where
the official server returns true. Named/noncapturing groups, lazy quantifiers, word
boundaries, escaped Unicode and supplementary-character indexing are not validated
as equivalent. Some unsupported syntax is treated as literal text instead of rejected;
backtracking has no RE2 linear-time bound. Do not use these patterns for authorization
until implemented and differentially checked. RE2 itself rejects backreferences and
lookaround; their absence is not a missing standard feature, but matching rejection
semantics still needs tests. Boolean `matches` does not return capture groups.

### Remaining work required for full compatibility

The incomplete matrix rows above are blockers. In particular, a typed CEL checker,
OpenFGA partial/unknown activation semantics, typed map keys, complete temporal
conversions/getters/timezones, precise numeric comparison, full RE2 behavior and
resource bounds are absent. Existing eager “all parameters required” handling can
reject requests that upstream partial evaluation resolves without the missing value.
No full compatibility or successful re-submission is claimed by this revision.

## Reproduce

Use the toolchain selected by `MOON_HOME`; do not replace it inside scripts.

```sh
scripts/conformance.sh
scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/seed314159
scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/seed271828
python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/cel
python3 scripts/audit_cel_surface.py
```

A is a gap inventory, not a passing conformance gate. D's zero differences apply only
to its corpus; compile-time acceptance/rejection is explicitly outside that gate.
