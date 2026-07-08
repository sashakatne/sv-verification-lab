#!/usr/bin/env python3
"""Generate load_balancer waveform, block-diagram, and CSV artifacts.

Parses the VCD produced by run.do (load_balancer_waveforms.vcd), writes a
checked-sample CSV, renders a waveform SVG and a block-diagram SVG, then
rasterizes both to PNG with `sips` (matching the repo's other modules - no
matplotlib/cairosvg dependency). Run after a sim that dumped the VCD:

    python3 make_artifacts.py
"""

from __future__ import annotations

import csv
import html
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
VCD = ROOT / "load_balancer_waveforms.vcd"
CSV_OUT = ROOT / "waveform_samples.csv"
WAVE_SVG = ROOT / "waveforms.svg"
WAVE_PNG = ROOT / "waveforms.png"
BLOCK_SVG = ROOT / "block_diagram.svg"
BLOCK_PNG = ROOT / "block_diagram.png"

# scalar/vector signals of interest, by VCD symbol resolution below
WANTED = {"clk", "rst_n", "policy", "req_valid", "req_ready",
          "be_ready", "be_valid", "be_done", "occ_flat"}


def parse_vcd(path: Path) -> list[dict[str, str]]:
    """Return one row per posedge-clk sample with the wanted signals."""
    if not path.exists():
        raise SystemExit(f"VCD not found: {path} (run the sim first)")
    sym_to_name: dict[str, str] = {}
    name_width: dict[str, int] = {}
    current: dict[str, str] = {}
    rows: list[dict[str, str]] = []
    in_defs = True
    prev_clk = "0"

    def snapshot() -> None:
        rows.append({n: current.get(n, "x") for n in
                     ["policy", "req_valid", "req_ready", "be_ready",
                      "be_valid", "be_done", "occ_flat"]})

    with path.open() as fh:
        for line in fh:
            line = line.strip()
            if in_defs and line.startswith("$var"):
                # $var wire N <sym> <name> [range] $end
                parts = line.split()
                width = int(parts[2])
                sym = parts[3]
                name = parts[4]
                if name in WANTED:
                    sym_to_name[sym] = name
                    name_width[name] = width
                continue
            if line.startswith("$enddefinitions"):
                in_defs = False
                continue
            if in_defs:
                continue
            # value changes
            if line.startswith("b"):
                val, sym = line[1:].split()
                if sym in sym_to_name:
                    current[sym_to_name[sym]] = val
            elif line and line[0] in "01xz":
                val, sym = line[0], line[1:]
                if sym in sym_to_name:
                    name = sym_to_name[sym]
                    current[name] = val
                    if name == "clk":
                        if prev_clk == "0" and val == "1":
                            snapshot()
                        prev_clk = val
    return rows


def write_csv(rows: list[dict[str, str]], path: Path) -> None:
    if not rows:
        raise SystemExit("no clock samples parsed from VCD")
    with path.open("w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def sample_rows(rows: list[dict[str, str]], count: int) -> list[dict[str, str]]:
    """Pick the first `count` rows that show an actual dispatch, for a lively plot."""
    active = [r for r in rows if r.get("be_valid", "0").strip("0") not in ("", "x")]
    picked = active[:count] if len(active) >= count else rows[:count]
    return picked


def render_waveforms(rows: list[dict[str, str]], path: Path) -> None:
    rows = sample_rows(rows, 24)
    signals = ["policy", "req_valid", "req_ready", "be_ready", "be_valid",
               "be_done", "occ_flat"]
    left, top, col_w, row_h = 150, 40, 34, 40
    width = left + col_w * len(rows) + 40
    height = top + row_h * len(signals) + 60
    p = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
         f'font-family="Arial, sans-serif">']
    p.append(f'<rect width="{width}" height="{height}" fill="#ffffff"/>')
    p.append(f'<text x="{left}" y="24" font-size="16" fill="#111">'
             f'load_balancer - dispatch waveform ({len(rows)} checked samples)</text>')
    for si, sig in enumerate(signals):
        y = top + si * row_h
        p.append(f'<text x="10" y="{y + row_h//2 + 4}" font-size="13" fill="#333">{sig}</text>')
        for ci, r in enumerate(rows):
            x = left + ci * col_w
            val = r.get(sig, "x")
            disp = val if len(val) <= 6 else val[-4:]
            fill = "#eef5ff"
            if sig == "be_valid" and val.strip("0") not in ("", "x"):
                fill = "#d7efe4"           # highlight actual dispatch cycles
            elif sig in ("req_valid", "req_ready") and val == "1":
                fill = "#fff2c7"
            p.append(f'<rect x="{x}" y="{y+4}" width="{col_w-2}" height="{row_h-8}" '
                     f'fill="{fill}" stroke="#ccd"/>')
            p.append(f'<text x="{x + col_w//2}" y="{y + row_h//2 + 4}" text-anchor="middle" '
                     f'font-size="10" fill="#222">{disp}</text>')
    p.append(f'<text x="{left}" y="{height-26}" font-size="12" fill="#555">'
             f'Green = one-hot backend dispatch; yellow = active request handshake. '
             f'Samples are posedge-clk snapshots from the UVM run VCD.</text>')
    p.append("</svg>")
    path.write_text("\n".join(p))


def render_block_diagram(path: Path) -> None:
    p = ['<svg xmlns="http://www.w3.org/2000/svg" width="820" height="420" '
         'font-family="Arial, sans-serif">']
    p.append('<rect width="820" height="420" fill="#ffffff"/>')
    p.append('<text x="24" y="30" font-size="18" fill="#111">load_balancer - request distributor (N=4)</text>')

    def box(x, y, w, h, title, body, fill="#ffffff"):
        p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="#334155"/>')
        p.append(f'<text x="{x+w//2}" y="{y+22}" text-anchor="middle" font-size="14" fill="#111">{html.escape(title)}</text>')
        for i, ln in enumerate(body):
            p.append(f'<text x="{x+w//2}" y="{y+42+i*16}" text-anchor="middle" font-size="11" fill="#444">{html.escape(ln)}</text>')

    def arrow(x1, y1, x2, y2, label=""):
        p.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#334155" stroke-width="2" marker-end="url(#a)"/>')
        if label:
            p.append(f'<text x="{(x1+x2)//2}" y="{(y1+y2)//2 - 6}" text-anchor="middle" font-size="11" fill="#334155">{label}</text>')

    p.append('<defs><marker id="a" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">'
             '<path d="M0,0 L8,3 L0,6 Z" fill="#334155"/></marker></defs>')

    box(24, 90, 150, 80, "upstream", ["req_valid / req_id", "req_ready (out)"], "#eef5ff")
    box(300, 70, 220, 120, "select (comb.)",
        ["policy: RR / WRR / LL", "elig = ready and policy", "one-hot grant"], "#fff2c7")
    box(300, 250, 220, 90, "state (regs)",
        ["rr_ptr, credit[N]", "occ[N] (saturating)"], "#f4ecff")
    box(640, 60, 150, 60, "backend 0..3", ["be_valid / be_id (out)", "be_ready / be_done (in)"], "#d7efe4")

    arrow(174, 130, 300, 130, "request")
    arrow(520, 130, 640, 90, "dispatch")
    arrow(410, 190, 410, 250, "advance")
    arrow(410, 250, 410, 190)
    p.append('<text x="300" y="380" font-size="12" fill="#555">'
             'Grant is a pure function of policy, be_ready, and registered state; '
             'occupancy tracks outstanding work for the least-loaded policy.</text>')
    p.append("</svg>")
    path.write_text("\n".join(p))


def to_png(src: Path, dst: Path) -> None:
    if shutil.which("sips") is None:
        raise SystemExit("sips is required to rasterize SVG->PNG on this machine")
    subprocess.run(["sips", "-s", "format", "png", str(src), "--out", str(dst)],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> None:
    rows = parse_vcd(VCD)
    write_csv(rows, CSV_OUT)
    render_waveforms(rows, WAVE_SVG)
    render_block_diagram(BLOCK_SVG)
    to_png(WAVE_SVG, WAVE_PNG)
    to_png(BLOCK_SVG, BLOCK_PNG)
    WAVE_SVG.unlink(missing_ok=True)
    BLOCK_SVG.unlink(missing_ok=True)
    print(f"make_artifacts: wrote {CSV_OUT.name}, {WAVE_PNG.name}, {BLOCK_PNG.name} "
          f"({len(rows)} samples)")


if __name__ == "__main__":
    main()
