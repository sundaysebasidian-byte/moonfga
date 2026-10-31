#!/usr/bin/env bash
# Run the pinned OpenFGA conformance matrix and enforce the project targets.
#   Check       >= 95%
#   ListObjects >= 90%
#   ListUsers   >= 90%
# Results are written to conformance-results/ (git-ignored).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.moon/bin:$PATH"

CHECK_TARGET="${CHECK_TARGET:-95}"
LIST_TARGET="${LIST_TARGET:-90}"

if [[ ! -f .upstream/openfga/consolidated_1_1_tests.yaml ||
      ! -f .upstream/openfga/abac_tests.yaml ]]; then
  scripts/fetch-upstream.sh
fi

mkdir -p conformance-results
set +e
moon run cmd/conformance "$@" 2>&1 | tee conformance-results/summary.txt
runner_status=${PIPESTATUS[0]}
moon run cmd/conformance -- --json "$@" > conformance-results/summary.json 2>/dev/null
set -e

totals_line="$(grep '^totals:' conformance-results/summary.txt | tail -n 1 || true)"
if [[ -z "$totals_line" ]]; then
  echo "conformance: no totals line in output" >&2
  exit 2
fi

read -r check list_objects list_users <<<"$(awk '
  /^totals:/ {
    gsub(",", "");
    print $3, $5, $7;
  }
' <<<"$totals_line")"

percent() {
  awk -v p="$1" -v t="$2" 'BEGIN { if (t == 0) print "0.00"; else printf "%.2f", (p / t) * 100 }'
}

split_count() {
  echo "${1%/*} ${1#*/}"
}

read -r check_pass check_total <<<"$(split_count "$check")"
read -r objects_pass objects_total <<<"$(split_count "$list_objects")"
read -r users_pass users_total <<<"$(split_count "$list_users")"

check_pct="$(percent "$check_pass" "$check_total")"
objects_pct="$(percent "$objects_pass" "$objects_total")"
users_pct="$(percent "$users_pass" "$users_total")"

echo "check        ${check_pass}/${check_total}  ${check_pct}%  (target ${CHECK_TARGET}%)"
echo "list_objects ${objects_pass}/${objects_total}  ${objects_pct}%  (target ${LIST_TARGET}%)"
echo "list_users   ${users_pass}/${users_total}  ${users_pct}%  (target ${LIST_TARGET}%)"

failed=0
if ! awk -v v="$check_pct" -v t="$CHECK_TARGET" 'BEGIN { exit !(v + 0 >= t + 0) }'; then
  echo "conformance: check below target" >&2
  failed=1
fi
for value in "$objects_pct" "$users_pct"; do
  if ! awk -v v="$value" -v t="$LIST_TARGET" 'BEGIN { exit !(v + 0 >= t + 0) }'; then
    echo "conformance: list API below target" >&2
    failed=1
  fi
done
if [[ $runner_status -ne 0 ]]; then
  echo "conformance: runner reported failures (exit $runner_status)" >&2
  failed=1
fi

exit $failed
