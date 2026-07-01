# My experiments with SystemVerilog

Welcome to my SystemVerilog Playground! This repository contains a collection of SystemVerilog modules designed for various digital design and verification tasks. Below is an overview of the key modules and their functionalities.

## Main Highlights

### 1. Arbiter
The Arbiter module manages access to a shared resource among multiple requesters, ensuring that only one request is granted at a time based on priority.

- **Files**: `Arbiter.sv`, `Arbiter4Behavioral.sv`, `Arbiter4TB.sv`
- **Testbenches**: `Arbiter4TB.sv`
- **Verification**: Assertions in `assertions.sv` in the folder `ArbiterAssertions`. This file is then bound to the Arbiter module in the `top.sv` testbench in this folder.

### 2. FindFirstOne (FFO)
The FFO module identifies the position of the first '1' in a 32-bit input vector, useful in priority encoders and similar applications.

- **Folder**: FindFirstOne_Sequential
- **Files**: `FFO32.sv`, `FFO32s.sv`, `FFO32sMealy.sv`, `FFO32p.sv`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `fsm_moore.png`, `fsm_mealy.png`, `pipeline_flow.png`, `waveform_moore.png`, `waveform_mealy.png`, `waveform_pipeline.png`
- **Testbenches**: `FFO32stb.sv`, `FFO32sMealytb.sv`, `FFO32ptb.sv`
- **Verification**: Run `run_moore.do`, `run_mealy.do`, or `run_pipeline.do`. The Moore and Mealy variants have generated FSM diagrams; the pipeline variant has a pipeline-flow diagram instead of an FSM.

### 3. Sequential Multiplier
A parameterized sequential multiplier module for multiplying two binary numbers using sequential logic.

- **Files**: `multiplier.sv`
- **Testbenches**: `multtb.sv`

### 4. Braille Decoder
A module that decodes Braille input into readable text.

- **Files**: `BrailleDecoder.sv`
- **Testbenches**: `BrailleDecoderTB.sv`

### 5. Arithmetic Logic Unit (ALU)
A versatile ALU module capable of performing various arithmetic and logical operations. My design contains a cascaded version of an ALU. The folder contains different methodologies to test the design and verify its correctness. I have created a conventional testbench, class-based testbench and UVM testbench.

- **Folder**: CascadedTinyALU

### 6. Non-Overlapping Clock Generator
A module that generates non-overlapping clock signals for a given set of inputs.

- **Folder**: NonOverlappingClockGenerator
- **Files**: `novckgen_structural.sv`, `novckgen_tb.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `novckgen.png`, `waveforms.png`, `waveform_samples.csv`, `transcript.txt`
- **Testbench**: `novckgen_tb.sv` drives a 10 ns `CK`, checks `CK1 & CK2` never overlaps, checks both phases toggle, checks complements, and prints `No errors -- passed testbench` on success.
- **Verification**: Run `do run.do`. The farm waveform artifact is plotted from the generated VCD; no FSM artifact is applicable because the RTL has no state register or state transition process.

### 7. Line-Following Robot
A combinational controller that drives the two motors of a line-following robot from five photo-sensors, with `InMotion` and `Error` status outputs. Shipped as both a minimal-SOP dataflow model and a gate-primitive structural model that share one self-checking testbench.

- **Folder**: LineFollowingRobot
- **Files**: `robotdataflow.sv`, `robotstructural.sv`, `testbench.sv`, `run_dataflow.do`, `run_structural.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `logic_flow.png`, `waveforms.png`, `waveform_samples.csv`, `report.pdf`, `transcript_dataflow.txt`, `transcript_structural.txt`
- **Testbenches**: `testbench.sv` (sweeps all 32 sensor patterns against a behavioural reference; prints `No errors -- passed testbench` on success)
- **Verification**: Run `do run_dataflow.do` to verify the dataflow model, `do run_structural.do` for the structural model. Both compile with `-source -lint`; the dataflow run reports 100.00% filtered instance coverage and the waveform image is plotted from real checked-sample VCD data.

### 8. Barrel Shifter
A parameterized N-bit left-shift barrel shifter built in behavioural dataflow style. Five stages of N-bit 2:1 muxes — controlled bit-by-bit from `ShiftAmount` — cascade shifts of N/2, N/4, ... 1, with `ShiftIn` replicated into the vacated LSB positions. The 2:1 mux is its own module, instantiated `$clog2(N)` times so a single `N` parameter resizes both the data path and the cascade depth.

- **Folder**: BarrelShifter
- **Files**: `barrelshifter.sv` (contains `Mux2to1` and `BarrelShifter`), `testbench.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `stage_flow.png`, `waveforms.png`, `waveform_samples.csv`, `report.pdf`, `transcript.txt`
- **Testbenches**: `testbench.sv` (module `top`, default `N=32`; sweeps 7 directed patterns × all 32 shift amounts × both `ShiftIn` values plus 200 random vectors against a behavioural reference, prints `No errors -- passed testbench` after 648 self-checks)
- **Verification**: Run `do run.do`. Clean `Errors: 0, Warnings: 0` on every `vlog`/`vopt` stage; produces `BarrelShifter.ucdb` with 100.00% per-instance statement and branch coverage on all five mux instances. `waveforms.png` is plotted from the checked-transaction VCD samples.

### 9. Adder/Subtractor and Complex Numbers
A parameterized structural add/subtract unit built from full-adder instances, plus a SystemVerilog package for complex numbers backed by `shortreal` real and imaginary components.

- **Folder**: AdderSubtractorComplex
- **Files**: `fulladder.sv`, `addsub.sv`, `complexpkg.sv`, `complexm.sv`
- **Testbenches**: `fulladdertb.sv` exhaustively checks the full adder, `addsubtb.sv` exhaustively checks all default 8-bit add/sub input combinations against a procedural reference, and `complexm.sv` self-checks complex construction, addition, multiplication, printing, and component extraction.
- **Verification**: Run `do run_fulladder.do`, `do run_addsub.do`, and `do run_complex.do`. Each script compiles with `-source -lint`, saves coverage, and the testbench prints `No errors -- passed testbench` on success.

### 10. MIPS Instruction Decoder
A packed-union MIPS instruction decoder that views the same 32-bit word as raw bits, a generic opcode payload, or R/I/J instruction fields.

- **Folder**: MIPSInstructionDecoder
- **Files**: `mipspkg.sv`, `mipstest.sv`
- **Testbench**: `mipstest.sv` imports the package, checks R, I, and J field aliases from packed 32-bit instruction values, and calls `DecodeInstruction` for multiple examples.
- **Verification**: Run `do run.do`. The testbench prints decoded fields and ends with `No errors -- passed testbench` on success.

### 11. SimpleBus Multi-Memory Interface
A SimpleBus processor/memory model that uses a SystemVerilog interface, processor and memory modports, 24-bit addresses, and a generated bank of 64KB memory interfaces selected by the upper address byte.

- **Folder**: SimpleBusMultiMemory
- **Files**: `simplebusif.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `fsm.png`, `waveforms.png`, `report.pdf`
- **Testbench**: `top` in `simplebusif.sv` verifies generated memory selection, read/write transfers, shared local-offset isolation, boundary offsets, and unmapped-base timeout behavior.
- **Verification**: Run `do run.do`. Override the number of memories with `set NUMMEM <count>` before running; the default is 4. The testbench ends with `No errors -- passed testbench` on success.

### 12. Headlamp Button Controller
A synchronous button controller with short-press, hold, and recall outputs. The design uses a four-state one-hot FSM and parameterized timing thresholds.

- **Folder**: HeadlampButtonController
- **Files**: `buttons.sv`, `assertions.sv`, `testbench.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `fsm.png`, `waveforms.png`, `report.pdf`
- **Testbench**: `top` in `testbench.sv` instantiates `Buttons B0`, binds `ButtonAssertions BA0`, and checks reset, short press, immediate re-press, hold threshold, extended hold, idle recall, recall persistence, and recall clear on release.
- **Verification**: Run `do run.do`. The default thresholds are `HOLDTICKS=1000` and `RECALLTICKS=8000`; the testbench ends with `No errors -- passed testbench` on success.

### 13. Floating-Point Class Randomization
A class-based IEEE-754 single-precision bit-pattern generator with randomizable sign, exponent, and fraction attributes plus denormal, NaN, infinity, and exponent-range constraints.

- **Folder**: FloatingPointClassRandomization
- **Files**: `floatingpointpkg.sv`, `fpclass.sv`, `testbench.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `fsm.png`, `waveforms.png`, `waveform_samples.csv`, `report.pdf`, `transcript.txt`, `transcript_smoke.txt`
- **Testbench**: `top` in `testbench.sv` checks direct component-to-float construction, directed classification probes, each randomization constraint by mode, and one combined finite ranged-normal mode.
- **Verification**: Run `do run.do`. The default run completes 6005 self-checks with 0 errors and prints `No errors -- passed testbench`.

### 14. SystemVerilog Gotcha Gallery
A curriculum of 17 self-contained demos under `sv_gotchas/`, each a minimal DUT + testbench + `run.do` that makes a single language trap from Mark Faust's ECE 571 review (PSU, `sv_gotchas/sv_review.pdf`) observable on a Questa transcript. Every demo runs in isolation (`cd sv_gotchas/NN_Slug && do run.do`), instantiates a gotcha-prone module side-by-side with its corrected counterpart, and only prints `No errors -- passed testbench` if the trap actually fires on the buggy version while the fixed version stays clean. All 17 demos (`01_DanglingWire` through `17_NetDelayStack`) pass; per-demo transcripts and MANIFEST.txt files are checked in.

- **Folder**: sv_gotchas
- **Files**: `sv_gotchas/README.md` (catalogue and verification gate), `sv_gotchas/sv_review.pdf` (source slides), `sv_gotchas/_run_all_on_farm.sh` (driver that runs each demo on the PSU ECE farm), one subdirectory per demo
- **Testbenches**: one `NN_Slug_tb.sv` per demo, `module top`; drives buggy and fixed in parallel and counts both `GOTCHA OBSERVED` events and `*** FIX FAILED` events
- **Verification**: per-demo `transcript` + `MANIFEST.txt`; sims run on the PSU ECE farm via `~/claude-runs/<UTC>_<slug>/`. Two demos intentionally carry expected compile-time warnings called out in their `run.do` per the CLAUDE.md exception: `01_DanglingWire` triggers the `vlog -lint` implicit-net warning (which IS the lesson — the linter catches the typo), and `09_OutOfRangeBitSelect` triggers the `vlog/vopt -lint` out-of-bounds-bit-select warning.

### 15. Timing Gotchas
Two timing-window demos model min-delay and max-delay failures with picosecond
delays: `MinDelayHoldDemo` shows a 20 ps contamination path violating an 80 ps
hold window, while `MaxDelaySetupDemo` shows a 920 ps propagation path violating
a 150 ps setup window on a 1000 ps clock. Clean 120 ps and 700 ps instances run
beside them in the same testbench.

- **Folder**: timing_gotchas
- **Files**: `timing_gotchas.sv`, `timing_gotchas_tb.sv`, `run.do`, `README.md`, `MANIFEST.txt`, `make_artifacts.py`, `transcript`, `timing_gotchas_waveforms.vcd`, `waveform_samples.csv`, `waveforms.png`, `circuit_diagram.png`
- **Testbench**: `top` in `timing_gotchas_tb.sv` checks that both gotchas trigger and both clean paths stay quiet.
- **Verification**: Run `do run.do`. The checked-in transcript and VCD are from a PSU farm Questa 2021.3_1 run; `waveforms.png` is rendered from that VCD, and `circuit_diagram.png` shows the four parameterized lanes that generated it.

### 16. MAC Processing Element
A dual-mode low-precision MAC PE for AI datapath verification: INT8 mode accumulates signed products into a saturating INT32 accumulator, while BF16 mode flushes input denormals, promotes products to FP32, and accumulates with round-to-nearest-even behavior.

- **Folder**: MacPE
- **Files**: `mac_pe.sv`, `mac_pe_bfm.sv`, `mac_pe_pkg.sv`, UVM class files, `top.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `waveform_samples.csv`, `waveforms.png`, `datapath.png`, `transcript.txt`, `transcript_negative.txt`, `transcript_red.txt`
- **Testbench**: UVM environment with directed INT8 saturation, directed BF16 finite/special-value checks, constrained-random mixed-mode streams, scoreboard self-checks, and three covergroups for mode/control sequencing, INT8 corners, and BF16 classes.
- **Verification**: Run `do run.do`. The clean PSU farm transcript ends with `No errors -- passed testbench`, reports `UVM_ERROR: 0` and `UVM_FATAL: 0`, and closes all three covergroups at 100.00%. The commented `+define+SAT_SKIP_BUG` line provides the checked-in negative run, which ends with `Failed testbench` and 857 UVM errors.

### 17. Systolic Array
A 4x4 signed INT8 output-stationary systolic matrix-multiply tile. A generated PE grid skews A rows east and B columns south, accumulating each signed INT32 output element locally before exposing the flattened C matrix.

- **Folder**: SystolicArray
- **Files**: `systolic_array.sv`, `systolic_array_bfm.sv`, `systolic_array_pkg.sv`, UVM class files, `top.sv`, `run.do`, `design.md`, `MANIFEST.txt`, `make_artifacts.py`, `waveform_samples.csv`, `waveforms.png`, `datapath.png`, `transcript.txt`, `transcript_negative.txt`, `transcript_red.txt`
- **Testbench**: UVM environment with zero, identity, signed-corner, alternating-sign, and 300 constrained-random 4x4 matrix cases. The scoreboard recomputes the full signed INT32 reference matrix and checks every output plus final latency.
- **Verification**: Run `do run.do`. The clean PSU farm transcript ends with `No errors -- passed testbench`, reports `UVM_ERROR: 0` and `UVM_FATAL: 0`, and closes all three covergroups at 100.00%. The commented `+define+SKIP_PE_BUG` line provides the checked-in negative run, which ends with `Failed testbench` and 296 UVM errors.

## Verification

### Assertions
Assertions are used extensively to ensure the correctness of the modules. Key assertions include:
- Valid request and grant vectors
- Single cycle grant production
- No simultaneous grants

### Coverage
Coverage metrics are collected to ensure thorough testing of the modules. Coverage reports can be generated using the provided `.do` files.

## Running Simulations

To run simulations and generate coverage reports, use the provided `.do` files. For example, to run the Arbiter verification:
```sh
cd Arbiter
do run.do
```
