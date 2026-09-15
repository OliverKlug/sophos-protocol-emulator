"""JTAG IDCODE vs TAP model. Two RX words, not a length check."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from golden import Core  # noqa: E402
from jtag_tap import IDCODE, JtagTap  # noqa: E402
import jtag_shift  # noqa: E402


def rev16(x: int) -> int:
    return int(f"{x & 0xFFFF:016b}"[::-1], 2)


def test_idcode() -> None:
    prog = jtag_shift.program()
    if len(prog) > 32:
        raise AssertionError(f"jtag {len(prog)} > 32")
    c = Core()
    c.load(prog)
    c.start0 = True
    tap = JtagTap()
    for _ in range(200):
        c.uio_in = (0xFF & ~4) | ((tap.tdo & 1) << 2)
        resolved, _ = c.step()
        tap.tick(resolved)
    if len(c.sm0.rx) < 2:
        raise AssertionError(f"JTAG RX {list(c.sm0.rx)} state={tap.state}")
    w0, w1 = c.sm0.rx[0] & 0xFFFF, c.sm0.rx[1] & 0xFFFF
    lo = rev16(w0)
    hi = rev16(w1)
    got = (hi << 16) | lo
    if got != IDCODE:
        raise AssertionError(
            f"IDCODE {got:#010x} != {IDCODE:#010x} raw={w0:#x},{w1:#x} state={tap.state}"
        )


def main() -> None:
    test_idcode()
    print(f"JTAG IDCODE {IDCODE:#010x} OK")


if __name__ == "__main__":
    main()
