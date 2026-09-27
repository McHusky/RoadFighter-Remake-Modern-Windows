#!/usr/bin/env python3
"""Build the Road Fighter Modern Windows v9 binary patches.

Requirements:
  - Python 3
  - GNU binutils: as, ld, objcopy, nm
  - Original 2003 Windows RoadFighter.exe with the expected SHA-256

Usage:
  python build_patch.py /path/to/RoadFighter-original.exe --output dist
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

EXPECTED_SHA256 = "7a9adb389e1e367edd82b2503afeeea3b523bd6bac2c363a522166f6e64a2773"
IMAGE_BASE = 0x400000
CODE_VA = 0x42E200
CODE_OFF = 0x2E200
RFDATA_RVA = 0x3B000
RFDATA_RAW = 0x39000
RFDATA_RAW_SIZE = 0x1000
RFDATA_VSIZE = 0x1000
RESOLUTIONS = [(1920, 1080), (2160, 1440), (3840, 2160), (5120, 1440)]

THUNKS = {
    "rf_setvideomode": (0x11AC6, b"\xff\x25\x2c\xf1\x42\x00"),
    "rf_flip":         (0x11AF6, b"\xff\x25\x18\xf1\x42\x00"),
    "rf_hook_music":   (0x11B3E, b"\xff\x25\xbc\xf1\x42\x00"),
    "rf_open_audio":   (0x11B50, b"\xff\x25\xb4\xf1\x42\x00"),
    "rf_poll_event":   (0x11B14, b"\xff\x25\x04\xf1\x42\x00"),
}


def need(tool: str) -> None:
    if shutil.which(tool) is None:
        raise SystemExit(f"Missing required tool: {tool}")


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True)


def build_inject(source: Path, work: Path) -> tuple[bytes, dict[str, int]]:
    obj = work / "rf_patch_v9.o"
    elf = work / "rf_patch_v9.elf"
    raw = work / "rf_patch_v9.bin"
    subprocess.check_call(["as", "--32", "-o", str(obj), str(source)])
    subprocess.check_call(["ld", "-m", "elf_i386", "-Ttext", hex(CODE_VA), "-o", str(elf), str(obj)])
    subprocess.check_call(["objcopy", "-O", "binary", "--only-section=.text", str(elf), str(raw)])

    syms: dict[str, int] = {}
    for line in run(["nm", "-n", str(elf)]).splitlines():
        parts = line.split()
        if len(parts) >= 3:
            try:
                syms[parts[2]] = int(parts[0], 16)
            except ValueError:
                pass
    missing = set(THUNKS) - syms.keys()
    if missing:
        raise SystemExit(f"Missing symbols in inject: {sorted(missing)}")
    return raw.read_bytes(), syms


def u16(b: bytearray, o: int) -> int:
    return struct.unpack_from("<H", b, o)[0]


def u32(b: bytearray, o: int) -> int:
    return struct.unpack_from("<I", b, o)[0]


def p16(b: bytearray, o: int, v: int) -> None:
    struct.pack_into("<H", b, o, v)


def p32(b: bytearray, o: int, v: int) -> None:
    struct.pack_into("<I", b, o, v)


def jmp6(src_va: int, dst_va: int) -> bytes:
    return b"\xE9" + struct.pack("<i", dst_va - (src_va + 5)) + b"\x90"


def patch_one(original: bytes, code: bytes, syms: dict[str, int], width: int, height: int, outdir: Path) -> Path:
    b = bytearray(original)
    if len(code) > 0xD00:
        raise SystemExit(f"Injected code too large: {len(code)} bytes")
    if len(b) != RFDATA_RAW:
        raise SystemExit(f"Unexpected original file size 0x{len(b):X}; expected 0x{RFDATA_RAW:X}")
    if any(b[CODE_OFF:CODE_OFF + len(code)]):
        raise SystemExit("Code cave is not zero-filled as expected")

    pe = u32(b, 0x3C)
    if b[pe:pe + 4] != b"PE\0\0":
        raise SystemExit("Not a PE file")
    coff = pe + 4
    opt = coff + 20
    if u16(b, coff + 2) != 3:
        raise SystemExit("Expected exactly 3 original PE sections")
    if u16(b, opt) != 0x10B:
        raise SystemExit("Expected PE32 optional header")

    first_sec = opt + u16(b, coff + 16)
    text_hdr = first_sec
    if bytes(b[text_hdr:text_hdr + 8]).rstrip(b"\0") != b".text":
        raise SystemExit("First section is not .text")
    p32(b, text_hdr + 8, 0x2E000)
    b[CODE_OFF:CODE_OFF + len(code)] = code

    for name, (file_off, expected) in THUNKS.items():
        if bytes(b[file_off:file_off + 6]) != expected:
            raise SystemExit(f"Unexpected thunk bytes at 0x{file_off:X} for {name}")
        b[file_off:file_off + 6] = jmp6(IMAGE_BASE + file_off, syms[name])

    new_hdr = first_sec + 3 * 40
    if any(b[new_hdr:new_hdr + 40]):
        raise SystemExit("No room for fourth section header")
    sh = bytearray(40)
    sh[0:8] = b".rfdata\0"
    struct.pack_into(
        "<IIIIIIHHI", sh, 8,
        RFDATA_VSIZE, RFDATA_RVA, RFDATA_RAW_SIZE, RFDATA_RAW,
        0, 0, 0, 0, 0xC0000040,
    )
    b[new_hdr:new_hdr + 40] = sh
    p16(b, coff + 2, 4)
    p32(b, opt + 8, u32(b, opt + 8) + 0x1000)
    p32(b, opt + 56, 0x3C000)

    b.extend(b"\0" * RFDATA_RAW_SIZE)
    p32(b, RFDATA_RAW + 0x10, width)
    p32(b, RFDATA_RAW + 0x14, height)
    p32(b, RFDATA_RAW + 0x64, 30)  # default volume percentage
    p32(b, RFDATA_RAW + 0x68, 77)  # fixed-point volume scale
    tag = (
        f"RoadFighter direct patch v9 backbuffer+premix-volume+buffer4096 "
        f"{width}x{height} default30 F9/F10\0"
    ).encode("ascii")
    b[RFDATA_RAW + 0x100:RFDATA_RAW + 0x100 + len(tag)] = tag

    outdir.mkdir(parents=True, exist_ok=True)
    out = outdir / f"RoadFighter-{width}x{height}.exe"
    out.write_bytes(b)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("original_exe", type=Path)
    parser.add_argument("--output", type=Path, default=Path("dist"))
    args = parser.parse_args()

    for tool in ("as", "ld", "objcopy", "nm"):
        need(tool)

    original = args.original_exe.read_bytes()
    digest = hashlib.sha256(original).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit(f"Unexpected RoadFighter.exe SHA-256: {digest}")

    source = Path(__file__).with_name("rf_patch_v9.s")
    with tempfile.TemporaryDirectory(prefix="rfpatch-") as td:
        code, syms = build_inject(source, Path(td))

    for width, height in RESOLUTIONS:
        out = patch_one(original, code, syms, width, height, args.output)
        print(f"{out.name}  {hashlib.sha256(out.read_bytes()).hexdigest()}")


if __name__ == "__main__":
    main()
