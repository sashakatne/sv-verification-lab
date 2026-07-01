#!/usr/bin/env python3
"""Generate SystolicArray waveform, block, schedule, and datapath artifacts."""

from __future__ import annotations

import csv
import html
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VCD = ROOT / "systolic_array_waveforms.vcd"
CSV_OUT = ROOT / "waveform_samples.csv"
WAVEFORM_SVG = ROOT / "waveforms.svg"
WAVEFORM_PNG = ROOT / "waveforms.png"
DATAPATH_SVG = ROOT / "datapath.svg"
DATAPATH_PNG = ROOT / "datapath.png"
BLOCK_DIAGRAM_SVG = ROOT / "block_diagram.svg"
BLOCK_DIAGRAM_PNG = ROOT / "block_diagram.png"
SCHEDULE_SVG = ROOT / "schedule.svg"
SCHEDULE_PNG = ROOT / "schedule.png"

SIGNALS = {
    "clk",
    "rst",
    "start",
    "busy",
    "done",
    "cycle_count",
    "pe_active",
    "c_matrix",
}


def bits_to_unsigned(bits: str) -> int:
    return int(bits.replace("x", "0").replace("z", "0"), 2)


def bits_to_signed(bits: str) -> int:
    unsigned = bits_to_unsigned(bits)
    width = len(bits)
    if width and bits[0] == "1":
        return unsigned - (1 << width)
    return unsigned


def popcount(value: int) -> int:
    return bin(value).count("1")


def slice_bits(bits: str, lsb: int, width: int) -> str:
    clean = bits.replace("x", "0").replace("z", "0").zfill(lsb + width)
    start = len(clean) - lsb - width
    end = len(clean) - lsb
    return clean[start:end]


def matrix_cell(bits: str, row: int, col: int) -> int:
    linear = row * 4 + col
    return bits_to_signed(slice_bits(bits, linear * 32, 32))


def parse_vcd(path: Path) -> list[dict[str, int]]:
    if not path.exists():
        raise SystemExit(f"missing VCD: {path}")

    id_to_name: dict[str, str] = {}
    values: dict[str, str] = {name: "0" for name in SIGNALS}
    rows: list[dict[str, int]] = []
    current_time = 0
    have_time = False
    last_clk = "0"
    in_header = True
    scope_stack: list[str] = []
    var_re = re.compile(r"\$var\s+\S+\s+\d+\s+(\S+)\s+(\S+)")

    def sample_current_time() -> None:
        nonlocal last_clk
        clk_value = values["clk"]
        if last_clk != "1" and clk_value == "1":
            c_bits = values["c_matrix"]
            active = bits_to_unsigned(values["pe_active"])
            rows.append({
                "time_ns": current_time,
                "sample": len(rows),
                "rst": bits_to_unsigned(values["rst"]),
                "start": bits_to_unsigned(values["start"]),
                "busy": bits_to_unsigned(values["busy"]),
                "done": bits_to_unsigned(values["done"]),
                "cycle_count": bits_to_unsigned(values["cycle_count"]),
                "pe_active_hex": active,
                "active_count": popcount(active),
                "c00": matrix_cell(c_bits, 0, 0),
                "c03": matrix_cell(c_bits, 0, 3),
                "c30": matrix_cell(c_bits, 3, 0),
                "c33": matrix_cell(c_bits, 3, 3),
            })
        last_clk = clk_value

    for raw_line in path.read_text(errors="replace").splitlines():
        line = raw_line.strip()
        if not line:
            continue

        if in_header:
            if line.startswith("$scope "):
                fields = line.split()
                if len(fields) >= 3:
                    scope_stack.append(fields[2])
                continue
            if line.startswith("$upscope"):
                if scope_stack:
                    scope_stack.pop()
                continue
            match = var_re.match(line)
            if match:
                code, name = match.groups()
                clean_name = name.split("[", 1)[0]
                if scope_stack == ["top", "bfm"] and clean_name in SIGNALS:
                    id_to_name[code] = clean_name
            if line == "$enddefinitions $end":
                in_header = False
            continue

        if line.startswith("#"):
            if have_time:
                sample_current_time()
            current_time = int(line[1:])
            have_time = True
            continue

        if line[0] in "01xz":
            code = line[1:]
            value = line[0]
        elif line[0] in "bB":
            fields = line[1:].split()
            if len(fields) != 2:
                continue
            value, code = fields
        else:
            continue

        name = id_to_name.get(code)
        if name is None:
            continue

        values[name] = value

    if have_time:
        sample_current_time()
    return rows


def write_csv(rows: list[dict[str, int]], path: Path) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def selected_rows(rows: list[dict[str, int]], count: int) -> list[dict[str, int]]:
    active = [row for row in rows if row["sample"] > 3]
    if len(active) <= count:
        return active
    return active[:count]


def polyline(points: list[tuple[float, float]]) -> str:
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def render_waveforms(rows: list[dict[str, int]], path: Path) -> None:
    sampled = selected_rows(rows, 96)
    width = 1500
    height = 840
    left = 166
    right = 48
    top = 82
    lane_h = 76
    plot_w = width - left - right

    lanes = [
        ("start", "start", "bit"),
        ("busy", "busy", "bit"),
        ("done", "done", "bit"),
        ("cycle_count", "cycle", "bus"),
        ("active_count", "active PEs", "bus"),
        ("pe_active_hex", "pe_active", "hex"),
        ("c00", "c[0][0]", "signed"),
        ("c33", "c[3][3]", "signed"),
    ]

    def x_at(index: int) -> float:
        if len(sampled) <= 1:
            return left
        return left + (index * plot_w / (len(sampled) - 1))

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        '<text x="42" y="38" font-family="Arial, sans-serif" font-size="26" font-weight="700">SystolicArray clean simulation waveform</text>',
        '<text x="42" y="62" font-family="Arial, sans-serif" font-size="14" fill="#555">Clock samples parsed from top.bfm in systolic_array_waveforms.vcd; final transaction latency index is 9.</text>',
    ]

    for index in range(len(sampled)):
        x = x_at(index)
        if sampled[index]["done"]:
            parts.append(f'<rect x="{x - 2:.1f}" y="{top - 20}" width="4" height="{height - 122}" fill="#d7efe4"/>')
        elif sampled[index]["start"]:
            parts.append(f'<rect x="{x - 1:.1f}" y="{top - 20}" width="2" height="{height - 122}" fill="#d8e3f8"/>')

    for lane_index, (key, label, kind) in enumerate(lanes):
        y_mid = top + lane_index * lane_h + 25
        y_hi = y_mid - 16
        y_lo = y_mid + 16
        parts.append(f'<text x="38" y="{y_mid + 5}" font-family="Arial, sans-serif" font-size="16" fill="#111">{html.escape(label)}</text>')
        parts.append(f'<line x1="{left}" y1="{y_lo}" x2="{width - right}" y2="{y_lo}" stroke="#d0d0d0" stroke-width="1"/>')

        if kind == "bit":
            points: list[tuple[float, float]] = []
            previous_y = y_lo
            for index, row in enumerate(sampled):
                x = x_at(index)
                y = y_hi if row[key] else y_lo
                if index:
                    points.append((x, previous_y))
                points.append((x, y))
                previous_y = y
            parts.append(f'<polyline points="{polyline(points)}" fill="none" stroke="#145c74" stroke-width="2.5"/>')
        else:
            for index, row in enumerate(sampled[:-1]):
                x0 = x_at(index)
                x1 = x_at(index + 1)
                fill = "#f8f8f8" if index % 2 else "#ffffff"
                parts.append(f'<rect x="{x0:.1f}" y="{y_hi}" width="{x1 - x0:.1f}" height="{y_lo - y_hi}" fill="{fill}" stroke="#222" stroke-width="0.8"/>')
                if index % 14 == 0 or row["done"]:
                    if kind == "hex":
                        text = f'{row[key]:04X}'
                    else:
                        text = str(row[key])
                    parts.append(f'<text x="{x0 + 4:.1f}" y="{y_mid + 5}" font-family="Arial, sans-serif" font-size="11" fill="#111">{html.escape(text)}</text>')

    done_count = sum(1 for row in rows if row["done"])
    parts.append(f'<text x="{left}" y="{height - 28}" font-family="Arial, sans-serif" font-size="13" fill="#555">CSV rows: {len(rows)} clock samples. Done pulses observed: {done_count}. Green bands mark checked matrix results sampled by the UVM monitor.</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def render_datapath(path: Path) -> None:
    width = 1400
    height = 860
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        '<defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="#222"/></marker></defs>',
        '<text x="48" y="54" font-family="Arial, sans-serif" font-size="30" font-weight="700">4x4 Output-Stationary Systolic Array</text>',
        '<text x="48" y="82" font-family="Arial, sans-serif" font-size="15" fill="#555">A rows skew east, B columns skew south, and each PE accumulates one signed INT32 C element.</text>',
    ]

    def box(x: int, y: int, w: int, h: int, title: str, body: str, fill: str) -> None:
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="#222" stroke-width="2"/>')
        parts.append(f'<text x="{x + 16}" y="{y + 32}" font-family="Arial, sans-serif" font-size="18" font-weight="700">{html.escape(title)}</text>')
        for line_index, line in enumerate(body.split("\\n")):
            parts.append(f'<text x="{x + 16}" y="{y + 60 + line_index * 22}" font-family="Arial, sans-serif" font-size="14" fill="#222">{html.escape(line)}</text>')

    def arrow(x1: int, y1: int, x2: int, y2: int, label: str = "") -> None:
        parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#222" stroke-width="2.2" marker-end="url(#arrow)"/>')
        if label:
            parts.append(f'<text x="{(x1 + x2) / 2 - 34:.1f}" y="{(y1 + y2) / 2 - 10:.1f}" font-family="Arial, sans-serif" font-size="13" fill="#222">{html.escape(label)}</text>')

    box(48, 126, 230, 128, "Input Latch", "Flattened signed INT8\\nA[4][4], B[4][4]\\nloaded on start", "#eef5f1")
    box(48, 560, 230, 130, "Controller", "cycle_count 0..9\\nbusy during wavefront\\ndone after final PE settles", "#f4f4f4")
    box(1110, 258, 230, 138, "Output Matrix", "Flattened signed INT32\\nC[row][col] from PE acc\\nchecked on done pulse", "#eef7fb")
    box(1110, 520, 230, 132, "Bug Hook", "SKIP_PE_BUG disables\\nthe bottom-right PE\\nnegative run must fail", "#f7eef1")

    grid_x = 418
    grid_y = 182
    cell = 118
    gap = 22

    for row in range(4):
        y = grid_y + row * (cell + gap)
        parts.append(f'<text x="{grid_x - 70}" y="{y + 64}" font-family="Arial, sans-serif" font-size="14" fill="#333">A row {row}</text>')
        arrow(grid_x - 36, y + 58, grid_x - 4, y + 58)

    for col in range(4):
        x = grid_x + col * (cell + gap)
        parts.append(f'<text x="{x + 24}" y="{grid_y - 42}" font-family="Arial, sans-serif" font-size="14" fill="#333">B col {col}</text>')
        arrow(x + 58, grid_y - 30, x + 58, grid_y - 4)

    for row in range(4):
        for col in range(4):
            x = grid_x + col * (cell + gap)
            y = grid_y + row * (cell + gap)
            fill = "#fff7df" if (row + col) % 2 == 0 else "#eaf2ff"
            parts.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="6" fill="{fill}" stroke="#222" stroke-width="2"/>')
            parts.append(f'<text x="{x + 28}" y="{y + 34}" font-family="Arial, sans-serif" font-size="17" font-weight="700">PE {row},{col}</text>')
            parts.append(f'<text x="{x + 20}" y="{y + 64}" font-family="Arial, sans-serif" font-size="13" fill="#222">acc C[{row}][{col}]</text>')
            parts.append(f'<text x="{x + 20}" y="{y + 88}" font-family="Arial, sans-serif" font-size="13" fill="#222">active t={row + col}..{row + col + 3}</text>')
            if col < 3:
                arrow(x + cell, y + 58, x + cell + gap - 4, y + 58)
            if row < 3:
                arrow(x + 58, y + cell, x + 58, y + cell + gap - 4)

    arrow(278, 190, grid_x - 42, 240, "A skew")
    arrow(278, 620, grid_x - 42, 660, "enable")
    arrow(grid_x + 4 * cell + 3 * gap + 18, grid_y + 258, 1110, 326, "C")
    arrow(grid_x + 3 * (cell + gap) + 80, grid_y + 3 * (cell + gap) + 118, 1110, 586, "PE 3,3")

    note = "For PE(row,col), valid products occur when k = cycle_count - row - col and 0 <= k < 4. The final bottom-right product occurs at cycle index 9."
    parts.append(f'<text x="420" y="780" font-family="Arial, sans-serif" font-size="14" fill="#555">{html.escape(note)}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def render_block_diagram(path: Path) -> None:
    width = 1600
    height = 900
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        '<defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="#222"/></marker></defs>',
        '<text x="52" y="56" font-family="Arial, sans-serif" font-size="30" font-weight="700">SystolicArray Block and Verification Diagram</text>',
        '<text x="52" y="84" font-family="Arial, sans-serif" font-size="15" fill="#555">One self-contained UVM harness drives flattened INT8 matrices into the RTL and checks every INT32 output element.</text>',
    ]

    def box(x: int, y: int, w: int, h: int, title: str, body: str, fill: str) -> None:
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="#222" stroke-width="2"/>')
        parts.append(f'<text x="{x + 16}" y="{y + 31}" font-family="Arial, sans-serif" font-size="18" font-weight="700">{html.escape(title)}</text>')
        for line_index, line in enumerate(body.split("\\n")):
            parts.append(f'<text x="{x + 16}" y="{y + 58 + line_index * 22}" font-family="Arial, sans-serif" font-size="14" fill="#222">{html.escape(line)}</text>')

    def arrow(x1: int, y1: int, x2: int, y2: int, label: str = "") -> None:
        parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#222" stroke-width="2.2" marker-end="url(#arrow)"/>')
        if label:
            parts.append(f'<text x="{(x1 + x2) / 2 - 42:.1f}" y="{(y1 + y2) / 2 - 10:.1f}" font-family="Arial, sans-serif" font-size="13" fill="#222">{html.escape(label)}</text>')

    box(62, 142, 230, 126, "Sequence", "Directed cases\\n300 random cases\\nstart pulse per item", "#eef5f1")
    box(62, 354, 230, 126, "Reference Model", "Signed INT32 C=A*B\\nfull 4x4 matrix\\nlatency index = 9", "#fff7df")
    box(360, 142, 230, 126, "Driver + BFM", "packs A/B matrices\\ndrives start/clear\\nwaits for done", "#eaf2ff")
    box(650, 120, 250, 160, "Input Capture", "a_matrix[127:0]\\nb_matrix[127:0]\\nlatch on start\\nclear PE accumulators", "#eef5f1")
    box(958, 120, 250, 160, "Skew Feeders", "A[row][k] enters west\\nB[k][col] enters north\\ncycle-aligned wavefront", "#f4f4f4")
    box(650, 370, 558, 198, "Generated PE Array", "16 identical PEs arranged as a 4x4 mesh\\nA shifts east, B shifts south, accumulators stay local\\npe_active[row*4+col] mirrors each MAC enable\\nSKIP_PE_BUG disables only PE(3,3)", "#fff7df")
    box(1270, 208, 242, 144, "Output Matrix", "c_matrix[511:0]\\n16 signed INT32 cells\\ndone after final PE settles", "#eef7fb")
    box(1270, 444, 242, 126, "Monitor", "samples on done\\nunpacks A/B/C\\npublishes transaction", "#eaf2ff")
    box(958, 650, 250, 134, "Coverage", "case type\\nINT8 corner classes\\noutput value classes", "#f7eef1")
    box(650, 650, 250, 134, "Scoreboard", "checks all 16 C cells\\nchecks latency\\nreports UVM errors", "#f7eef1")
    box(360, 650, 230, 134, "Verdict", "No errors -- passed\\nor Failed testbench\\nwritten after report_phase", "#eef5f1")

    arrow(292, 205, 360, 205, "seq_item")
    arrow(590, 205, 650, 200, "A/B")
    arrow(900, 200, 958, 200, "latched")
    arrow(1208, 200, 1270, 280, "C")
    arrow(1390, 352, 1390, 444, "done")
    arrow(1270, 506, 1208, 716)
    arrow(1270, 506, 900, 716)
    arrow(650, 716, 590, 716)
    arrow(292, 416, 650, 716, "expected")
    arrow(1208, 466, 1270, 280, "outputs")
    arrow(958, 720, 900, 720)

    parts.append('<text x="650" y="610" font-family="Arial, sans-serif" font-size="14" fill="#555">RTL boundary: input capture, skew feeders, PE mesh, output matrix, controller.</text>')
    parts.append('<text x="650" y="632" font-family="Arial, sans-serif" font-size="14" fill="#555">Verification boundary: UVM sequence, driver/BFM, monitor, scoreboard, coverage.</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def render_schedule(path: Path) -> None:
    width = 1420
    height = 1000
    left = 118
    top = 176
    cell_w = 94
    cell_h = 38
    row_gap = 6
    cycles = range(10)
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        '<text x="48" y="54" font-family="Arial, sans-serif" font-size="30" font-weight="700">PE Activation Schedule</text>',
        '<text x="48" y="82" font-family="Arial, sans-serif" font-size="15" fill="#555">Each PE performs four MACs. Product k is valid when cycle_count - row - col = k.</text>',
        '<text x="48" y="106" font-family="Arial, sans-serif" font-size="15" fill="#555">The final bottom-right product lands at cycle index 9.</text>',
    ]

    for cycle in cycles:
        x = left + cycle * cell_w
        fill = "#eef7fb" if cycle == 9 else "#f7f7f7"
        parts.append(f'<rect x="{x}" y="{top - 48}" width="{cell_w}" height="34" fill="{fill}" stroke="#222" stroke-width="1"/>')
        parts.append(f'<text x="{x + 36}" y="{top - 25}" font-family="Arial, sans-serif" font-size="15" font-weight="700">{cycle}</text>')

    parts.append(f'<text x="{left + 10 * cell_w + 24}" y="{top - 25}" font-family="Arial, sans-serif" font-size="14" fill="#555">cycle_count</text>')

    for row in range(4):
        for col in range(4):
            lane = row * 4 + col
            y = top + lane * (cell_h + row_gap)
            parts.append(f'<text x="48" y="{y + 25}" font-family="Arial, sans-serif" font-size="14" fill="#111">PE {row},{col}</text>')
            for cycle in cycles:
                x = left + cycle * cell_w
                k = cycle - row - col
                active = 0 <= k < 4
                fill = "#fff2c7" if active else "#ffffff"
                if cycle == 9:
                    fill = "#d7efe4" if active else "#eef7fb"
                parts.append(f'<rect x="{x}" y="{y}" width="{cell_w}" height="{cell_h}" fill="{fill}" stroke="#bbb" stroke-width="1"/>')
                if active:
                    parts.append(f'<text x="{x + 26}" y="{y + 24}" font-family="Arial, sans-serif" font-size="13" fill="#111">k={k}</text>')
            first = row + col
            last = row + col + 3
            parts.append(f'<text x="{left + 10 * cell_w + 24}" y="{y + 25}" font-family="Arial, sans-serif" font-size="13" fill="#333">active {first}..{last}</text>')

    legend_y = top + 16 * (cell_h + row_gap) + 26
    parts.append(f'<rect x="{left}" y="{legend_y}" width="28" height="18" fill="#fff2c7" stroke="#aaa"/>')
    parts.append(f'<text x="{left + 38}" y="{legend_y + 15}" font-family="Arial, sans-serif" font-size="14" fill="#333">MAC active for product k</text>')
    parts.append(f'<rect x="{left + 270}" y="{legend_y}" width="28" height="18" fill="#d7efe4" stroke="#aaa"/>')
    parts.append(f'<text x="{left + 308}" y="{legend_y + 15}" font-family="Arial, sans-serif" font-size="14" fill="#333">final bottom-right product at cycle 9</text>')
    parts.append(f'<text x="{left}" y="{legend_y + 54}" font-family="Arial, sans-serif" font-size="14" fill="#555">The UVM monitor samples one clock later on done, so the final C matrix is visible after all nonblocking PE updates settle.</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def convert_with_sips(source: Path, dest: Path, fmt: str) -> None:
    if shutil.which("sips") is None:
        raise SystemExit("sips is required to render artifacts on this machine")
    subprocess.run(
        ["sips", "-s", "format", fmt, str(source), "--out", str(dest)],
        check=True,
        stdout=subprocess.DEVNULL,
    )


def main() -> None:
    rows = parse_vcd(VCD)
    if not rows:
        raise SystemExit("no clock samples found in VCD")
    write_csv(rows, CSV_OUT)
    render_waveforms(rows, WAVEFORM_SVG)
    render_datapath(DATAPATH_SVG)
    render_block_diagram(BLOCK_DIAGRAM_SVG)
    render_schedule(SCHEDULE_SVG)
    convert_with_sips(WAVEFORM_SVG, WAVEFORM_PNG, "png")
    convert_with_sips(DATAPATH_SVG, DATAPATH_PNG, "png")
    convert_with_sips(BLOCK_DIAGRAM_SVG, BLOCK_DIAGRAM_PNG, "png")
    convert_with_sips(SCHEDULE_SVG, SCHEDULE_PNG, "png")
    WAVEFORM_SVG.unlink(missing_ok=True)
    DATAPATH_SVG.unlink(missing_ok=True)
    BLOCK_DIAGRAM_SVG.unlink(missing_ok=True)
    SCHEDULE_SVG.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
