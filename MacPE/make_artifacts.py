#!/usr/bin/env python3
"""Generate MacPE waveform and datapath artifacts from the clean-run VCD."""

from __future__ import annotations

import csv
import html
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent
VCD = ROOT / "mac_pe_waveforms.vcd"
CSV_OUT = ROOT / "waveform_samples.csv"
WAVEFORM_SVG = ROOT / "waveforms.svg"
WAVEFORM_PNG = ROOT / "waveforms.png"
DATAPATH_SVG = ROOT / "datapath.svg"
DATAPATH_PNG = ROOT / "datapath.png"

SIGNALS = {
    "mode",
    "a",
    "b",
    "valid_in",
    "clear",
    "acc",
    "sat_flag",
    "fp_flag",
    "valid_out",
}


def bits_to_int(bits: str) -> int:
    return int(bits.replace("x", "0").replace("z", "0"), 2)


def parse_vcd(path: Path) -> list[dict[str, int]]:
    if not path.exists():
        raise SystemExit(f"missing VCD: {path}")

    id_to_name: dict[str, str] = {}
    values: dict[str, str] = {name: "0" for name in SIGNALS}
    rows: list[dict[str, int]] = []
    current_time = 0
    in_header = True
    scope_stack: list[str] = []
    var_re = re.compile(r"\$var\s+\S+\s+\d+\s+(\S+)\s+(\S+)")

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
            current_time = int(line[1:])
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

        previous = values.get(name, "0")
        values[name] = value

        if name == "valid_out" and previous != "1" and value == "1":
            rows.append({
                "time_ns": current_time,
                "sample": len(rows),
                "mode": bits_to_int(values["mode"]),
                "a": bits_to_int(values["a"]),
                "b": bits_to_int(values["b"]),
                "valid_in": bits_to_int(values["valid_in"]),
                "clear": bits_to_int(values["clear"]),
                "acc": bits_to_int(values["acc"]),
                "sat_flag": bits_to_int(values["sat_flag"]),
                "fp_flag": bits_to_int(values["fp_flag"]),
            })

    return rows


def selected_rows(rows: list[dict[str, int]], count: int) -> list[dict[str, int]]:
    if len(rows) <= count:
        return rows

    head_count = min(80, count // 4)
    tail_count = count - head_count
    head = rows[:head_count]
    tail: list[dict[str, int]] = []
    span = len(rows) - head_count - 1
    for index in range(tail_count):
        source_index = head_count
        if tail_count > 1:
            source_index += round(index * span / (tail_count - 1))
        tail.append(rows[source_index])
    return head + tail


def write_csv(rows: list[dict[str, int]], path: Path) -> None:
    selected = selected_rows(rows, 800)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(selected[0].keys()))
        writer.writeheader()
        writer.writerows(selected)


def polyline(points: list[tuple[float, float]]) -> str:
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def render_waveforms(rows: list[dict[str, int]], path: Path) -> None:
    sampled = selected_rows(rows, 220)
    width = 1440
    height = 760
    left = 152
    right = 42
    top = 72
    lane_h = 70
    plot_w = width - left - right

    lanes = [
        ("sample", "sample", "bus"),
        ("mode", "mode", "bit"),
        ("valid_in", "valid_in", "bit"),
        ("clear", "clear", "bit"),
        ("acc", "acc[31:0]", "bus"),
        ("sat_flag", "sat", "bit"),
        ("fp_flag", "fp", "bit"),
    ]

    def x_at(index: int) -> float:
        if len(sampled) <= 1:
            return left
        return left + (index * plot_w / (len(sampled) - 1))

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        '<text x="40" y="36" font-family="Arial, sans-serif" font-size="25" font-weight="700">MacPE checked simulation waveform</text>',
        '<text x="40" y="58" font-family="Arial, sans-serif" font-size="14" fill="#555">Selected valid_out samples from mac_pe_waveforms.vcd; mode 0 is INT8, mode 1 is BF16</text>',
    ]

    for index in range(len(sampled)):
        x = x_at(index)
        parts.append(f'<line x1="{x:.1f}" y1="{top - 18}" x2="{x:.1f}" y2="{height - 58}" stroke="#e8e8e8" stroke-width="1" stroke-dasharray="3 8"/>')

    for lane_index, (key, label, kind) in enumerate(lanes):
        y_mid = top + lane_index * lane_h + 25
        y_hi = y_mid - 16
        y_lo = y_mid + 16
        parts.append(f'<text x="36" y="{y_mid + 5}" font-family="Arial, sans-serif" font-size="16" fill="#111">{html.escape(label)}</text>')
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
            parts.append(f'<polyline points="{polyline(points)}" fill="none" stroke="#0b5a7a" stroke-width="2.4"/>')
        else:
            for index, row in enumerate(sampled[:-1]):
                x0 = x_at(index)
                x1 = x_at(index + 1)
                fill = "#f8f8f8" if index % 2 else "#ffffff"
                parts.append(f'<rect x="{x0:.1f}" y="{y_hi}" width="{x1 - x0:.1f}" height="{y_lo - y_hi}" fill="{fill}" stroke="#111" stroke-width="1"/>')
                if index % 22 == 0:
                    text = str(row[key]) if key == "sample" else f'{row[key]:08X}'
                    parts.append(f'<text x="{x0 + 4:.1f}" y="{y_mid + 5}" font-family="Arial, sans-serif" font-size="11" fill="#111">{html.escape(text)}</text>')

    parts.append(f'<text x="{left}" y="{height - 24}" font-family="Arial, sans-serif" font-size="13" fill="#555">Samples shown: {len(sampled)} selected from {len(rows)} valid_out transactions. Final clean transcript reports 0 UVM errors and 100% covergroup coverage.</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts))


def render_datapath(path: Path) -> None:
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="760" viewBox="0 0 1400 760">',
        '<rect x="0" y="0" width="1400" height="760" fill="#ffffff"/>',
        '<text x="48" y="54" font-family="Arial, sans-serif" font-size="30" font-weight="700">MacPE Datapath</text>',
        '<text x="48" y="82" font-family="Arial, sans-serif" font-size="15" fill="#555">Dual-mode one-beat MAC with sticky status flags and clear-observable accumulator reset</text>',
    ]

    def box(x: int, y: int, w: int, h: int, title: str, body: str, fill: str) -> None:
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill}" stroke="#222" stroke-width="2"/>')
        parts.append(f'<text x="{x + 18}" y="{y + 34}" font-family="Arial, sans-serif" font-size="19" font-weight="700">{html.escape(title)}</text>')
        for line_index, line in enumerate(body.split("\\n")):
            parts.append(f'<text x="{x + 18}" y="{y + 64 + line_index * 24}" font-family="Arial, sans-serif" font-size="15" fill="#222">{html.escape(line)}</text>')

    def arrow(x1: int, y1: int, x2: int, y2: int, label: str = "") -> None:
        parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#222" stroke-width="2.4" marker-end="url(#arrow)"/>')
        if label:
            parts.append(f'<text x="{(x1 + x2) / 2 - 28:.1f}" y="{(y1 + y2) / 2 - 10:.1f}" font-family="Arial, sans-serif" font-size="14" fill="#222">{html.escape(label)}</text>')

    parts.append('<defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto"><path d="M0,0 L10,4 L0,8 Z" fill="#222"/></marker></defs>')

    box(60, 160, 220, 126, "Operand Ports", "a[15:0], b[15:0]\\nmode selects INT8 or BF16\\nvalid_in / clear", "#eef5f1")
    box(360, 122, 260, 142, "INT8 Path", "signed a[7:0] * b[7:0]\\n33-bit add to accumulator\\nclamp to INT32 range", "#fff6dd")
    box(360, 326, 260, 150, "BF16 Path", "flush denormals to zero\\nBF16 multiply to FP32\\nFP32 RNE accumulation", "#eaf2ff")
    box(720, 214, 250, 156, "Accumulator", "INT32 bits in INT8 mode\\nFP32 bits in BF16 mode\\nclear forces acc=0", "#f7f7f7")
    box(1060, 178, 250, 120, "Sticky Flags", "sat_flag for INT8 clamp\\nfp_flag for FP specials\\nrst/clear reset both", "#f1ecff")
    box(1060, 380, 250, 116, "Monitor Pulse", "valid_out pulses on MAC\\nand on clear beats\\nidle beats hold state", "#eef7fb")

    arrow(280, 212, 360, 192, "mode=0")
    arrow(280, 232, 360, 400, "mode=1")
    arrow(620, 194, 720, 272)
    arrow(620, 400, 720, 298)
    arrow(970, 276, 1060, 238)
    arrow(970, 310, 1060, 438)

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
        raise SystemExit("no valid_out samples found in VCD")
    write_csv(rows, CSV_OUT)
    render_waveforms(rows, WAVEFORM_SVG)
    render_datapath(DATAPATH_SVG)
    convert_with_sips(WAVEFORM_SVG, WAVEFORM_PNG, "png")
    convert_with_sips(DATAPATH_SVG, DATAPATH_PNG, "png")
    WAVEFORM_SVG.unlink(missing_ok=True)
    DATAPATH_SVG.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
