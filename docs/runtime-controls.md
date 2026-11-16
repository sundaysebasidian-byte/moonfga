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
supply it explicitly. Accepted settings are supported IANA names, UTC or numeric
offsets. Do not pass arbitrary POSIX TZ rules, TZif file paths or the alias Local
as a replacement zone. Unknown names produce E2000. Pinned tzdb data and updates
are described in [timezones.md](timezones.md).

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
Failure is sticky and cannot be absorbed by a deciding union/boolean result.
`ExecutionBudget::check` checks only the predicate/terminal state; `step` also
consumes one work unit. Zero/negative steps fail on the first step. Sharing a budget
across calls intentionally shares remaining work and cancellation state.

CEL's `eval_expr_with_limit`, `eval_expr_with_cost`, `eval_condition_with_limit` and
`regex_matches` also accept `budget=Some(budget)`. Model parsing/type checking and
regex program construction are not preemptible. An arbitrary blocking host reader
cannot be interrupted by this synchronous library; use cancellable I/O in the host.

## Condition cost and error semantics

`Engine::new(..., condition_cost_limit=100)` defaults to OpenFGA's per-condition
runtime limit. `condition_cancelled` remains a per-condition callback; it and CEL's
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
