#!/usr/bin/env bash
# Capture the load_balancer evidence bundle on the PSU ECE farm.
#
# Runs the clean formal proof, one bug-injected proof per BUG_* define, and the
# UVM simulation, then writes curated human-readable tails with a machine-
# parseable EVIDENCE_VERDICT line each. Raw tool databases are discarded; only
# the tails in logs/ are meant to be committed. check_evidence.sh validates them.
#
# Prereqs on the farm (vcf + vsim/vcover on PATH, licenses set). Run from this
# formal/ directory:  bash capture_evidence.sh
set -uo pipefail
cd "$(dirname "$0")"
mkdir -p logs
raw_dir="$(mktemp -d)"

# BUG_* define -> the property it must falsify (for the roll-up traceability).
declare -A bug_prop=(
  [BUG_DOUBLE_GRANT]=a_grant_onehot
  [BUG_GRANT_NOTREADY]=a_grant_only_ready
  [BUG_OCC_OVERFLOW]=a_occ_no_overflow
  [BUG_WRR_ZERO]=a_wrr_weight0_never
  [BUG_LL_NOTMIN]=a_ll_picks_min
  [BUG_RR_STUCK]=a_rr_bounded_fairness
)

# Count property rows (a_*/c_* names), not headers or the verdict line itself.
derive_counts() {
  local raw="$1" proven falsified covered
  proven=$(grep -iE '\b(a_|p_)[a-z0-9_]+' "$raw"    | grep -ic 'proven'     || true)
  falsified=$(grep -iE '\b(a_|p_)[a-z0-9_]+' "$raw" | grep -ic 'falsified'  || true)
  covered=$(grep -iE '\bc_[a-z0-9_]+' "$raw"        | grep -ic 'covered'    || true)
  echo "${proven:-0} ${falsified:-0} ${covered:-0}"
}

# --- clean formal proof ---
echo "RUN fpv_run_lb (clean)"
vcf -batch -f fpv_run_lb.tcl >"${raw_dir}/clean.raw" 2>&1 || true
{
  grep -m1 -i 'version' "${raw_dir}/clean.raw" || echo "Tool version: (not printed)"
  echo "----- assertion status -----"
  grep -iE 'proven|falsified|covered|unreachable' "${raw_dir}/clean.raw" | grep -viE 'EVIDENCE_VERDICT' || true
} > logs/fpv_run_lb.log
read -r p f c < <(derive_counts "${raw_dir}/clean.raw")
echo "EVIDENCE_VERDICT: job=fpv_run_lb kind=clean proven=${p} falsified=${f} covered=${c}" >> logs/fpv_run_lb.log

# --- bug-injected formal proofs (one per BUG_* define) ---
for bug in "${!bug_prop[@]}"; do
  job="fpv_run_lb_${bug,,}"
  raw="${raw_dir}/${job}.raw"
  echo "RUN ${job} (bug -> ${bug_prop[$bug]})"
  LB_BUG="$bug" vcf -batch -f fpv_run_lb_buginjected.tcl >"$raw" 2>&1 || true
  {
    grep -m1 -i 'version' "$raw" || echo "Tool version: (not printed)"
    echo "expected_falsified_property: ${bug_prop[$bug]}"
    echo "----- assertion status -----"
    grep -iE 'proven|falsified|covered|unreachable' "$raw" | grep -viE 'EVIDENCE_VERDICT' || true
  } > "logs/${job}.log"
  read -r p f c < <(derive_counts "$raw")
  echo "EVIDENCE_VERDICT: job=${job} kind=bug proven=${p} falsified=${f} covered=${c}" >> "logs/${job}.log"
done

# --- UVM simulation (clean) ---
echo "RUN uvm sim (clean)"
( cd .. && vsim -c -do "do run.do; quit -f" ) >"${raw_dir}/uvm.raw" 2>&1 || true
# Curated UVM tail: the per-test lines, the coverage summary, and the verdict.
{
  grep -m1 -iE 'Questa|ModelSim|version' "${raw_dir}/uvm.raw" || echo "Tool version: (not printed)"
  echo "----- per-test results -----"
  grep -E '^# TEST |^TEST ' "${raw_dir}/uvm.raw" | sed 's/^# //' || true
  echo "----- coverage -----"
  grep -iE 'Total coverage|Coverage.*%' "${raw_dir}/uvm.raw" | tail -5 || true
  echo "----- verdict -----"
  grep -E 'No errors -- passed testbench|Failed testbench' "${raw_dir}/uvm.raw" | tail -1 || true
} > logs/uvm_regression.log

echo "capture_evidence: wrote $(ls logs/*.log | wc -l) logs to logs/"
