# Changelog

## 0.2.0

- Add schema 1.2 module composition, forward type extensions, fga.mod YAML parsing and host-supplied module contents APIs.
- Preserve module/source_info metadata across JSON imports and exports; reject conflicting definitions and validate cross-file references and cycles.
- Add native POSIX / JS fga.mod CLI loading, canonical path containment and model_file support in store tests. Wasm callers supply contents; wasm CLI refuses modular file loading.
- Add two official full-JSON module transformations, four invalid-module rejection checks and nine fga.mod acceptance/rejection checks; retain 29 single-file fixtures. The complex upstream fixture lacks module inputs; only its JSON metadata roundtrip is checked. Complete official diagnostic arrays and YAML intermediate locations remain unsupported.
- Expected generated interfaces: fga AuthModel.metadata; dsl ModuleFile/merge_modules; model parse_mod/modules_to_model; storetest optional check_module_path; language module fixture entrypoints; new host path-containment package.


All notable changes to MoonFGA are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2026-11-01

- Build ListObjects reverse proofs only for transitive query dependencies; retain fresh reads for writes, deletes and contextual tuples without a shared cache.
- Add reproducible native/JS scale experiments (10k/100k/1m tuples, three fanouts, 20 group levels), latency distributions, process peak RSS and graph-build attribution.
- Add an independent TupleReader snapshot host and executable contracts for exact reads, empty results and host failures; keep the engine API unchanged.


- Fix Check depth accounting: cap full dispatches at 25 while retaining computed aliases and terminal userset/TTU joins; add 29 boundary and mixed-chain regressions.

- Fix CEL logical error absorption, Unicode code point size, and RFC3339 timestamp strings with nanoseconds and numeric offsets.
- Replace per-candidate List evaluation with reverse object proofs and user-set expansion; preserve List condition errors and API-specific depth semantics.
- Record Explain witnesses on the actual successful Check path; share the non-fatal explanation status model between CLI and JS.
- Expand the oracle to five scenario families and 64 frozen upstream regression fixtures; reject failed model/write setup.

- Add a browser playground (`playground/` JS exports, static page in `web/`, GitHub Pages workflow) with a Node smoke test.
- Playground passes the engine's explain result through unchanged and marks an incomplete explanation; `filters` and `tuples` reject malformed values.
- Move `model_file` reading out of `storetest` (`load_store_test` takes an optional reader), so the playground bundle imports no Node modules.
- Fix resolver path cleanup on condition errors, contextual triple shadowing and identifier bounds.
- Add depth/cycle, wildcard exclusion, condition and input regression tests (177 tests per backend).
- Reuse parsed users and index object types; measured native queries improve about 38% on the documented workload.
- Hide engine/store internals and validation helpers before the first published API.
- Add a pinned OpenFGA v1.22.1 differential oracle matching the matrix commit: two seeds, 6570 comparisons, zero differences.
- Fix wildcard intersection witnesses and subtraction in ListUsers; freeze nine counterexamples as regression tests.
- Match OpenFGA contextual condition semantics: Check shadows triples; List APIs combine both streams.
- Align CI installers with official documentation; initialize Windows MSVC and pin Node 22.

## [0.1.0] - 2026-10-31

First public release, published to Mooncakes as
`sundaysebasidian-byte/moonfga@0.1.0`. Requires MoonBit toolchain 0.1.20261028 or newer.

### Added

- OpenFGA schema 1.1 DSL: `model`, `schema 1.1`, `type`, `relations`, `define`,
  direct restrictions (`[user, group#member, user:*, user with cond]`),
  `or` / `and` / `but not`, computed usersets, tuple-to-userset (`X from Y`),
  parentheses, `condition` declarations, and comments.
- AuthorizationModel JSON import/export and a DSL ↔ JSON transformer. Export
  follows `openfga/language`: empty `type_definitions` are omitted and every
  relation receives a `metadata.relations` entry.
- Semantic model validation with line and column positions: unknown types and
  relations, invalid tuple restrictions, forbidden cycles, duplicate
  definitions, and condition parameter checks. Error codes mirror OpenFGA
  (`E2000`, `E2001`, `E2002`, `E2003`, `E2021`, `E2022`, `E2027`).
- Indexed in-memory tuple store (`object#relation`, user indexes), contextual
  tuple overlays, and a `TupleReader` trait for embedding.
- `Check` with depth limit 25, cycle detection, wildcard users, union /
  intersection / difference short-circuiting, tuple-to-userset traversal, and
  conditional relationships.
- `BatchCheck`, `ListObjects`, `ListUsers` (including userset filters),
  `Expand`, and explainable checks that return resolution paths.
- Self-contained CEL subset covering `int`, `uint`, `double`, `bool`, `string`,
  `duration`, `timestamp`, `list`, `map`, and `ipaddress`, with operators,
  ternaries, `exists` / `exists_one` / `all` / `map` / `filter`, and common
  string, time, and network helpers.
- CLI with `validate`, `transform`, `check`, `list-objects`, `list-users`,
  `expand`, and `test` commands. Tuple input accepts JSON, YAML, and
  `object#relation@user` text.
- `.fga.yaml` store test runner supporting `model` / `model_file`, suite and
  per-test tuples, Check / ListObjects / ListUsers assertions, `context`,
  `contextualTuples`, userset filters, and `errorCode`.
- Conformance harness that replays the pinned OpenFGA matrix and the
  `openfga/language` DSL ↔ JSON fixtures, with per-assertion JSON reports and
  configurable pass thresholds (`scripts/conformance.sh`).
- Runnable examples for basic ReBAC, ABAC conditions, and library embedding.

### Conformance

Pinned upstream revisions:

- `openfga/openfga` `44054f542f64e9b9589dd26a595081b3d2cfd942` (v1.22.1)
- `openfga/language` `ed62a11e759a0faa1354404ead761f956469e149`

| API | Passed | Total | Failed | Skipped |
| --- | ---: | ---: | ---: | ---: |
| Check | 516 | 516 | 0 | 0 |
| ListObjects | 354 | 354 | 0 | 0 |
| ListUsers | 393 | 394 | 0 | 1 |
| DSL ↔ JSON fixtures | 29 | 29 | 0 | 0 |

The single skipped ListUsers assertion (`simple_computeduserset_indirect_ref`)
has no top-level expectation or `errorCode` in the upstream file and is
reported as `skip/no_expectation` rather than counted as a pass.

### Known limitations

- No FGA modules (`module` / `extends`); single-file models are fully
  supported.
- No `ReadChanges`; the in-memory store has no change log.
- No persistent or distributed storage, HTTP/gRPC server, pagination, or
  consistency preferences.
- The CEL implementation is an OpenFGA-oriented subset, not the complete CEL
  standard library (for example, `bytes` and regex capture groups are absent).
