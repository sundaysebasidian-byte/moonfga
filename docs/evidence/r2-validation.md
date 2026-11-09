# 0.2.3 worktree validation

Executed locally on Darwin arm64 with `MOON_HOME=/tmp/moon-new`, using that toolchain's bin directory first in PATH. No Linux/Windows execution or browser-rendered UI validation was performed. `web/smoke.mjs` tests the browser bundle's exported API in Node.

| Command | Observed result |
| --- | --- |
| `moon check --deny-warn --target all` | exit 0 |
| `moon fmt --check` | exit 0 |
| `moon info` then `git diff --exit-code -- '*.mbti'` (after committing generated interfaces) | exit 0, zero interface differences |
| `moon test --target all` | wasm / wasm-gc / JS / native: each 195/195, zero failures |
| `scripts/conformance.sh` | Check 516/516; ListObjects 354/354; ListUsers 393/394, one upstream missing-expectation skip; zero failures |
| `scripts/oracle-openfga.sh --cases 1000 --seed 314159 --output conformance-results/seed314159` | 1095 cases, 3285 comparisons, zero mismatches |
| `scripts/oracle-openfga.sh --cases 1000 --seed 271828 --output conformance-results/seed271828` | 1095 cases, 3285 comparisons, zero mismatches |
| `python3 scripts/oracle_cel.py --seed 20261108 --output conformance-results/cel` | 52 fixed + 256 generated expressions; 308 cases, 924 comparisons, zero mismatches |
| `python3 scripts/audit_cel_surface.py` | 17 probes recorded; unresolved differences, deliberately not reported as passing conformance |
| `scripts/build-web.sh` then `node web/smoke.mjs` | build exit 0; 36/36 checks |
| `moon run cmd/language` | single-file 29/29; module supplied-input cases 6/6, missing source fixture 06 explicitly unavailable; fga.mod 9/9 |
| `python3 scripts/test-modules.py` | native and JS module CLI / path containment passed |
| `node scripts/test-explain.mjs` | CLI / JS decision and witness checks passed |
| `git diff --check` | exit 0 |

Initial CEL runs exposed the official `INT64_MIN % -1` error and the corpus was corrected with the implementation. A download attempt returned HTTP 504; the existing release archive was copied read-only from the original checkout and validated by the script's pinned SHA-256. A simultaneous oracle start exited before readiness while scripts extracted to the same executable path; extraction now skips identical binaries and atomically replaces changed binaries. Seed 271828 passed on rerun. These failed attempts are not counted as successful validation.

All source commits are local on `compat-0.2.3`. No push, tag or publish. The original checkout's dirty proposal remains outside this worktree. Full condition compatibility is still blocked by the explicitly enumerated [CEL gaps](../openfga-comparison.md); the zero-difference corpus must not be presented as full compatibility.
