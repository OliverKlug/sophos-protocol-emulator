"""SPI JEDEC MISO oracle: RX sees EF 40 16, not MOSI loopback."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from flash_miso import JEDEC_ID, FlashMiso  # noqa: E402
from golden import Core  # noqa: E402
import spi_jedec  # noqa: E402


def rev8(x: int) -> int:
    return int(f"{x & 0xFF:08b}"[::-1], 2)


def test_jedec_miso() -> None:
    prog = spi_jedec.program()
    if len(prog) > 32:
        raise AssertionError(f"spi_jedec {len(prog)} > 32")
    c = Core()
    c.load(prog)
    c.sm0.tx.append(spi_jedec.tx_word(0x9F))
    c.start0 = True
    flash = FlashMiso()
    mosi_bits: list[int] = []
    last_clk = 0
    for _ in range(120):
        c.uio_in = (0xFF & ~4) | ((flash.miso & 1) << 2)
        resolved, _oe = c.step()
        clk = (resolved >> 1) & 1
        if last_clk == 0 and clk == 1 and ((resolved >> 3) & 1) == 0:
            mosi_bits.append(resolved & 1)
        flash.tick(resolved)
        last_clk = clk
    if len(c.sm0.rx) < 2:
        raise AssertionError(f"SPI RX FIFO {list(c.sm0.rx)}")
    w0, w1 = c.sm0.rx[0] & 0xFFFF, c.sm0.rx[1] & 0xFFFF
    b0, b1 = (w0 >> 8) & 0xFF, w0 & 0xFF
    b2, b3 = (w1 >> 8) & 0xFF, w1 & 0xFF
    if b0 != 0xFF:
        raise AssertionError(f"MISO during 9F should be Hi-Z 0xFF, got {b0:#x}")
    if (b1, b2, b3) != JEDEC_ID:
        raise AssertionError(f"JEDEC {(b1, b2, b3)} != {JEDEC_ID} raw={w0:#x},{w1:#x}")
    if flash.got_cmd != 0x9F:
        raise AssertionError(f"flash saw cmd {flash.got_cmd}")
    cmd_bits = mosi_bits[:8]
    got_cmd = 0
    for b in cmd_bits:
        got_cmd = (got_cmd << 1) | b
    if got_cmd != 0x9F:
        raise AssertionError(f"MOSI cmd {got_cmd:#x} bits={cmd_bits}")
    if w0 == w1 and w0 == 0x9F:
        raise AssertionError("MOSI loopback labeled as JEDEC")
    miso_bytes = (b1, b2, b3)
    if miso_bytes == (got_cmd, got_cmd, got_cmd):
        raise AssertionError("MISO == MOSI")


def main() -> None:
    test_jedec_miso()
    print("SPI JEDEC MISO: EF 40 16 after 0x9F OK")


if __name__ == "__main__":
    main()
