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
