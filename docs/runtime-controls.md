# Host timezone, work budgets and CEL cost

These controls are shared by native, JS, wasm-gc and wasm. They do not read an OS
clock or environment variable implicitly.

## Local timezone

`Engine::new(..., condition_local_timezone=Some("America/Los_Angeles"))` selects
the zone used by timestamp getters with the explicit argument `"Local"`.
The CEL APIs accept the equivalent `local_timezone` argument. `None` resolves Local
to **UTC**, matching a UTC container or Go's empty `TZ`. A getter with no timezone
argument always uses UTC, even when Local is configured. `string(timestamp(...))`
retains the timestamp's parsed offset; setting Local does not change conversion.

`scripts/oracle_host.py` checks winter/summer hours, omitted getter arguments and
conversion against OpenFGA v1.22.1 with `TZ=""`, `UTC`, `America/Los_Angeles` and
`Asia/Kolkata`: 20/20 matching Check decisions. An unset TZ on a non-UTC OS can
resolve to that OS's localtime, so hosts must resolve their desired server TZ and
supply it explicitly. Accepted settings are supported IANA names and UTC;
numeric Local settings fall back to UTC by default, as Go's process TZ loader
does. Do not pass arbitrary POSIX TZ rules, TZif file paths or the alias Local as
a replacement zone. Unknown names produce E2000. Pinned tzdb data and updates
are described in [timezones.md](timezones.md).

Direct CEL getter arguments support numeric offsets in both the pinned oracle
and MoonFGA: `getHours("+05:30")`, `getHours("-08:00")`, `getHours("05:30")`,
`getHours("5:30")` and `getHours("8:+01")` are valid. Invalid hour/minute ranges,
malformed decimal components and unknown zones produce condition errors (E2000).
This behavior does not depend on the Local configuration or its opt-in flag.

A numeric **Local configuration** has different semantics from a direct getter
argument. Go/OpenFGA's process `TZ=+05:30`, `-08:00` or `05:30` falls back to UTC:
at `2026-03-08T10:00:00Z`, Local hour is 10. MoonFGA now defaults to the same
fallback for colon-containing Local configurations. To retain the former fixed
offset extension, explicitly set
`Engine::new(..., condition_local_timezone=Some("+05:30"), condition_allow_numeric_local_timezone=true)`.
The equivalent optional flag on `eval_expr_with_limit`, `eval_expr_with_cost`
and `eval_condition_with_limit` is `allow_numeric_local_timezone=true`.
Both flags default to **false**. With opt-in, the three Local hours are 15, 2 and
15; malformed offset settings still produce E2000. The flag is preserved across
contextual, list, inline-condition and budget-bound engine evaluations.

`scripts/r9_host_boundaries.py` now compares the three default UTC fallbacks and
four named zones, and separately asserts the opt-in extension. Names use
canonical case; Go filesystem lookups on a case-insensitive OS can accept
noncanonical spellings that this pinned, case-sensitive table rejects.
[Focused timestamp evidence](evidence/numeric-local-timezone.md) distinguishes
exact getter values, runtime error categories and host process TZ behavior.

## Request deadline / deterministic work budget

Create a fresh `@fga.ExecutionBudget::new(steps=10000)` per request, and bind it with
`engine.with_budget(budget)`. The original engine stays reusable; the copy and all
its contextual/list/terminal engine copies share the same budget. Existing Check,
CheckRequest, BatchCheck, Explain, ListObjects, ListUsers and Expand entry points
use it. BatchCheck captures failures in each item's `error_code`.

The optional `cancelled : () -> Bool` predicate can read the host's monotonic clock
and return true at a deadline, or read a cancellation flag. No clock unit, polling
thread or platform FFI is required. Hosts retain responsibility for reader I/O
and scheduling. A budget consumes portable work units at graph/tuple/edge loops,
CEL AST evaluation/optimization and regex input checkpoints (every 1024 positions).
These units are deterministic for the same execution path and are **separate from
CEL cost**. They are not OpenFGA dispatch counts or elapsed milliseconds.

Exhaustion or a true predicate raises `FgaError` **E4004** (`deadline_exceeded`).
Synchronous request validation runs before the first budget step, including Check
wrappers, list/Expand/Explain and batch items. Invalid requests retain their API
validation error even with zero/negative steps or a true cancellation predicate.
For valid requests, failure is sticky and cannot be absorbed by a deciding
union/boolean result. Budget units are an implementation work counter, not an API
promise that the same count remains unchanged across versions.
`ExecutionBudget::check` checks only the predicate/terminal state; `step` also
consumes one work unit. Zero/negative steps fail on the first step. Sharing a budget
across calls intentionally shares remaining work and cancellation state.

CEL's `eval_expr_with_limit`, `eval_expr_with_cost`, `eval_condition_with_limit` and
`regex_matches` also accept `budget=Some(budget)`. Model parsing/type checking and
regex program construction are not preemptible. An arbitrary blocking host reader
cannot be interrupted by this synchronous library; use cancellable I/O in the host.

## Condition cost and error semantics

`Engine::new(..., condition_cost_limit=100)` defaults to OpenFGA's per-condition
runtime limit. The cost-limit/report API is Int32; limits above 2147483647
are not expressible here, although the server/Go driver accepts uint64 limits.
`condition_cancelled` remains a per-condition callback; it and CEL's
`cancelled` argument produce E2000. Cost-limit errors also produce E2000 and contain
`cost limit exceeded`. Request budgets instead produce E4004 as above.
`eval_expr_with_cost` returns `(value, actual_cost)` on successful evaluation after
program optimization. Evaluation errors raise `FgaError`; no cost report is returned.
There is no separate MoonFGA static estimator. The differential retains cel-go's
static min/max estimates for inspection, but compares actual cost for successful
programs and error categories at limits 0, 100, cost-1, cost and cost+1.
OpenFGA itself refuses a configured cost limit below 100 at startup; those lower
boundaries are probed directly with cel-go. Full HTTP API probes use
100/101/199/200/1000. Static
estimates may differ from optimized runtime cost even upstream (constant containers
and membership); equating these numbers would be incorrect.

The pinned cancellation probe (`scripts/oracle_cancellation.py`) records real HTTP
responses with a 25ms request timeout and 1ms list deadlines. For 10000/50000-element
conditions, Check returned HTTP 500 `deadline_exceeded`; ListObjects/ListUsers
returned HTTP 200 with empty results. An earlier 1ns list probe returned
`deadline_exceeded` for ListObjects and empty ListUsers. A 100000-element request
instead exceeded the server's 616448-byte gRPC message limit (`resource_exhausted`),
so it supplies no condition-interruption evidence. The standalone pinned cel-go
cancelled-comprehension probe reports `operation interrupted: context canceled`;
OpenFGA wraps CEL evaluation failures as condition evaluation errors.

Exact timing and which layer wins a cancellation race are not portable. MoonFGA
reports E4004 from a request budget, including list APIs, and does not silently
return a partial list: its Array result has no completeness marker. A host wanting
OpenFGA's partial-list transport behavior must implement that policy explicitly.
This is a concrete remaining API behavior difference, not a missing interrupt hook.

## Tested index and conversion cost forms

The r9 regression fix follows the pinned interpreter's attribute planning: one
root charge per ordinary attribute path and one per field/index qualifier. An attribute
used as a dynamic qualifier does not add another root read. Computed nonattribute
subscripts still incur their expression costs. Conditional attributes have no
separate root charge; their selector condition and selected branch computations
are still charged. `[1,2,3][n]`, `{"a":1}[s]`, `[1,2,3][n]==1`,
`[n,2,3][1]` and `[1,2,3][0]` cost 2, 2, 3, 13 and 2 respectively at n=0/s="a".
The generated review corpus includes nested/conditional paths, macro-bound
containers and unsupported string/bytes indexing checker/runtime cases.

`int(double)` rejects values at or below -2^63 (and at or above +2^63);
integer/string representations of MinInt64 remain distinct supported overloads.
Timestamp subtraction of duration MinInt64 errors because the pinned interpreter's
intermediate duration negation overflows, even where the mathematical timestamp
would be representable. String-to-string and bytes-to-bytes identity conversions
cost one; size-dependent charging applies to encoding/decoding conversions.

The exact-cost corpus excludes the identified order-sensitive
`{1:2,3:4}.exists(k,k==3)` case. In the separate 200-run pinned probe it costs 10
or 13; limit=10 can therefore succeed or exceed cost. MoonFGA's deterministic map
order cannot reproduce each randomized Go traversal. The ordinary API corpus can
still test its Boolean result at the default budget 100. Separate order probes do
not participate in the deterministic zero-mismatch count. The remaining corpus is
finite; no cost-equivalence claim is made outside its measured inputs.
