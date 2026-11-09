# Portable character and timezone data

The runtime is pure MoonBit. No system timezone lookup, Go, C regular-expression
library, Node package or platform process is needed by the shipped engine.

`cel/timezones_generated.mbt` contains 598 names and 343 distinct TZif transition
tables from the local IANA tzdb **2026f**. Historical transitions and POSIX future
M-rule tails are included; future daylight transitions are computed per year.
`Local` is deliberately not guessed. Set `condition_local_timezone` on Engine
(or `local_timezone` on the CEL evaluation API) to the intended named host zone.
Without that setting Local errors; unknown names also error.
`docs/evidence/timezone-input-hashes.json` fingerprints every input TZif file.

`cel/unicode_generated.mbt` contains Unicode **17.0.0** categories, scripts and
simple case-fold orbits, enumerated through the public Go unicode API by
`scripts/export_unicode.go` (local Go 1.27.1). The pinned OpenFGA release reports
Go 1.27.3 via `go version -m`; executable code is not copied from Go or RE2.
Unicode data license: [Unicode License](../third_party/UNICODE-LICENSE.txt).
IANA tzdb data are public domain.

Regeneration (build tooling only):

```sh
python3 scripts/generate_timezones.py
python3 scripts/generate_unicode.py
moon fmt
```

Use tzdb 2026f and Go with Unicode 17.0.0 to reproduce these tables. The generator
uses Python's TZif reader, emits independent MoonBit data and rejects unsupported
future-rule encodings rather than silently dropping them. New tzdb/Unicode inputs
require a reviewed data update and renewed official differential testing. Generated data use packed TZif transitions and lazy Unicode property construction;
initializers are split into functions so wasm's function-local limit is respected.
