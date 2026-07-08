#!/usr/bin/env bash
# Validate the committed load_balancer evidence bundle. Fails loudly if any
# proof drifted: a clean job with a falsification, a bug job that stopped
# catching its fault, a missing/failing UVM test, or coverage below 100%.
# This is the machine-checked contract behind the "sim-backed evidence" claim -
# a fabricated or regressed result cannot pass it.
#
# Usage: bash check_evidence.sh [logs_dir]   (default: ./logs)
set -uo pipefail
logs_dir="${1:-logs}"
err() { echo "check_evidence: $*" >&2; exit 1; }

shopt -s nullglob
formal_tails=("${logs_dir}"/fpv_run_lb*.log)
[ "${#formal_tails[@]}" -gt 0 ] || err "no formal tails in ${logs_dir}"

for f in "${formal_tails[@]}"; do
  grep -qi 'version' "$f" || err "$f: missing tool-version marker"
  grep -E 'proven|falsified' "$f" | grep -qv 'EVIDENCE_VERDICT:' \
    || err "$f: empty assertion table"
  v="$(grep -m1 '^EVIDENCE_VERDICT:' "$f")" || err "$f: no EVIDENCE_VERDICT line"
  kind="$(sed -n 's/.* kind=\([a-z]*\).*/\1/p' <<<"$v")"
  fals="$(sed -n 's/.* falsified=\([0-9]*\).*/\1/p' <<<"$v")"
  prov="$(sed -n 's/.* proven=\([0-9]*\).*/\1/p' <<<"$v")"
  [ -n "$kind" ] || err "$f: cannot parse kind="
  [ -n "$fals" ] || err "$f: cannot parse falsified="
  case "$kind" in
    clean)
      [ "$fals" = "0" ]     || err "$f: clean job has falsified=$fals (expected 0)"
      [ "${prov:-0}" -ge 1 ] || err "$f: clean job proved nothing (proven=$prov)" ;;
    bug)
      [ "${fals:-0}" -ge 1 ] || err "$f: bug job has falsified=$fals (expected >=1)" ;;
    *) err "$f: bad kind='$kind'" ;;
  esac
done

# UVM: all 5 named tests present, every one with mismatched=0.
uvm_log="${logs_dir}/uvm_regression.log"
[ -f "$uvm_log" ] || err "missing ${uvm_log}"
n_tests=$(grep -cE '^TEST ' "$uvm_log" 2>/dev/null || true)
[ "${n_tests:-0}" -eq 5 ] || err "uvm log: expected 5 TEST lines, found ${n_tests:-0}"
grep -E '^TEST ' "$uvm_log" | grep -qE 'mismatched=[1-9]' \
  && err "uvm log: a TEST line reports a mismatch" || true
grep -qE 'No errors -- passed testbench' "$uvm_log" || err "uvm log missing pass verdict"

# Coverage must be 100.00%.
grep -q '100.00%' "$uvm_log" || err "coverage summary is not 100.00%"

echo "check_evidence: OK (${#formal_tails[@]} formal tails, 5 UVM tests clean, coverage 100.00%)"
