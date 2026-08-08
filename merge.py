#!/usr/bin/env python3
"""Merge the src/*.ahk splices into the runnable STD_HotKeys.ahk.

Splices are concatenated in filename order (numeric prefixes control the
sequence). The merged file is written as UTF-8 with a BOM and LF line
endings so AutoHotkey v2 renders the non-ASCII banner glyphs correctly.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "src"
OUT = ROOT / "STD_HotKeys.ahk"
REQUIRED_HEADER = "#Requires AutoHotkey v2.0"


def main() -> int:
    files = sorted(SRC.glob("*.ahk"))
    if not files:
        print(f"error: no splices found in {SRC}", file=sys.stderr)
        return 1

    parts = [f.read_text(encoding="utf-8-sig") for f in files]
    merged = "".join(parts)

    if REQUIRED_HEADER not in merged:
        print("error: merged output is missing the required header", file=sys.stderr)
        return 1

    OUT.write_bytes(merged.encode("utf-8-sig"))
    print(f"merged {len(files)} splices -> {OUT.name} ({OUT.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
