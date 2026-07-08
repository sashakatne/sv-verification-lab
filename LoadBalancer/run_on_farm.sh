#!/usr/bin/env bash
# Drive the full load_balancer evidence run on the PSU ECE farm (katnemo =
# katne@mo.ece.pdx.edu), then pull the curated logs and transcripts back here.
#
# Steps: sync this module to a timestamped run dir on the farm, source the tool
# env, run the UVM sim (clean) + the formal capture (clean + per-bug), validate
# with check_evidence.sh, and rsync logs/transcripts back. Run from this dir.
set -euo pipefail
cd "$(dirname "$0")"

FARM=katnemo
STAMP=$(ssh "$FARM" 'date -u +%Y-%m-%dT%H-%M-%SZ')
RUN_DIR="claude-runs/${STAMP}_loadbalancer"

echo ">> farm run dir: ~/${RUN_DIR}"
ssh "$FARM" "mkdir -p ~/${RUN_DIR}"
rsync -az --exclude 'logs' --exclude '*.vcd' --exclude '*.ucdb' ./ "$FARM:~/${RUN_DIR}/"

# Tool env: source the farm package script BEFORE any strict-mode, per the
# repo convention (an unbound var during sourcing silently aborts otherwise).
ssh "$FARM" bash -s <<EOF
set +u
source /pkgs/pkgs/PKGSsh 2>/dev/null || true
export PATH=/pkgs/mentor/questa/2021.3_1/questasim/bin:/pkgs/synopsys/current/bin:\$PATH
export MGLS_LICENSE_FILE=1717@mentor-lic.cecs.pdx.edu
export MTI_VCO_MODE=64
set -u
cd ~/${RUN_DIR}

echo "=== clean UVM sim ==="
vsim -c -do "do run.do; quit -f" | tee transcript.txt

echo "=== negative UVM sim (BUG_RR_STUCK) ==="
sed 's|^vlog -source -lint load_balancer.sv\$|vlog -source -lint +define+BUG_RR_STUCK load_balancer.sv|' run.do > run_bug.do
vsim -c -do "do run_bug.do; quit -f" | tee transcript_negative.txt

echo "=== formal capture (clean + per-bug) ==="
cd formal && bash capture_evidence.sh && bash check_evidence.sh
ln -sfn ${STAMP}_loadbalancer ~/claude-runs/latest
EOF

echo ">> pulling evidence back"
rsync -az "$FARM:~/${RUN_DIR}/formal/logs/" ./formal/logs/
rsync -az "$FARM:~/${RUN_DIR}/transcript.txt" ./transcript.txt
rsync -az "$FARM:~/${RUN_DIR}/transcript_negative.txt" ./transcript_negative.txt
rsync -az "$FARM:~/${RUN_DIR}/load_balancer_waveforms.vcd" ./load_balancer_waveforms.vcd 2>/dev/null || true

echo ">> local validation"
( cd formal && bash check_evidence.sh )
echo ">> done. farm run: ~/${RUN_DIR}"
