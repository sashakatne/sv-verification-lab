# SystolicArray

`systolic_array` is a 4x4 INT8 output-stationary matrix-multiply tile. Each
processing element accumulates one output element of `C = A * B` into a signed
INT32 accumulator. A wavefront schedule feeds A values from the west side and B
values from the north side, so the array fills, computes, and drains over
`3*N-2` cycles. The `done` pulse reports the final cycle count and exposes the
full 4x4 output matrix.

## Interface

- `start`: accepts one flattened pair of 4x4 signed INT8 matrices.
- `clear`: clears state and output matrix.
- `busy`: asserted while the wavefront is active.
- `done`: one-cycle pulse when all outputs are valid.
- `cycle_count`: final wavefront cycle index, expected to be `3*N-3`.
- `pe_active`: one bit per PE, useful for utilization and waveform evidence.

## Verification Intent

The UVM environment drives zero, identity, signed-corner, alternating-sign, and
constrained-random matrix cases. The scoreboard computes a full signed INT32
matrix-multiply reference and checks every output element plus the final latency.
Coverage tracks matrix case type, signed INT8 corner combinations, output value
classes, output positions, and bottom-right PE activity at pipeline drain.

`SKIP_PE_BUG` deliberately suppresses one PE accumulation so the same scoreboard
produces a negative run.

## Implementation Notes

The RTL latches one flattened A/B matrix pair on `start`, then injects A rows
and B columns with the classic systolic skew. PE `(row,col)` is enabled when
`k = cycle_count - row - col` and `0 <= k < N`; each enabled PE accumulates one
signed INT8 product into its local signed INT32 accumulator. The final
bottom-right product occurs at cycle index `3*N-3`, and `done` is delayed one
clock so the UVM monitor samples the settled final accumulator values.

`pe_active` mirrors the PE enable mask and therefore ends with `16'h8000` for
the bottom-right PE on the final checked sample.

## Evidence

The checked-in `transcript.txt` is the clean PSU farm run: every compile and
vopt stage reports `Errors: 0, Warnings: 0`, the UVM summary reports
`UVM_ERROR: 0` and `UVM_FATAL: 0`, all three covergroups close at 100.00%, and
the final appended verdict line is `No errors -- passed testbench`.

`transcript_negative.txt` recompiles the same DUT with `+define+SKIP_PE_BUG`.
It keeps the compile/vopt stages clean but ends with `Failed testbench` and 296
scoreboard errors on the suppressed bottom-right PE. `transcript_red.txt`
captures the pre-implementation RED gate against the initial stub.

`make_artifacts.py` parses the clean VCD into `waveform_samples.csv`, renders
`waveforms.png` from 3,652 checked clock samples, and draws `datapath.png` for
the implemented 4x4 PE grid.
