# MAC Processing Element

`mac_pe` is a dual-mode multiply-accumulate processing element intended as a
tile-friendly verification target for low-precision AI datapaths. The port shape
keeps both operand inputs at 16 bits: INT8 mode uses the low byte of each operand,
while BF16 mode uses the full operand.

## Interface

- `mode=0`: signed INT8 multiply-accumulate into a signed saturating INT32 accumulator.
- `mode=1`: BF16 multiply promoted to FP32, accumulated into a FP32 accumulator.
- `valid_in`: accepts one MAC beat.
- `clear`: synchronously clears the accumulator and sticky flags. A clear beat
  also pulses `valid_out` so the UVM monitor and scoreboard observe the reset.
- `valid_out`: one-cycle pulse when `acc` is updated or cleared.

## Verification Intent

The UVM environment drives directed INT8 saturation, directed BF16 finite and
special-value cases, and mixed constrained-random mode streams. The scoreboard
checks INT8 exactly and checks BF16 against a `shortreal` reference with a
one-ULP tolerance for finite values. NaN values are checked by class, infinities
by class and sign, and sticky status flags are compared transaction by
transaction.

`SAT_SKIP_BUG` deliberately bypasses the INT8 saturation clamp so the same
scoreboard produces a negative run.
