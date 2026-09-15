"""UART frame RX vs synthesised waves: baud error, jitter, runt, bad stop."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from golden import Core  # noqa: E402
import uart_rx  # noqa: E402
import uart_rx_frame  # noqa: E402

BIT = 8


def rev8(x: int) -> int:
    return int(f"{x & 0xFF:08b}"[::-1], 2)


def frame_bits(byte: int, stop: int = 1) -> list[int]:
    return [0] + [(byte >> i) & 1 for i in range(8)] + [stop]


def synth(
    byte: int,
    bit_period: float,
    stop: int = 1,
    start_low: int | None = None,
    jitter: int = 0,
    idle: int = 16,
    tail: int = 24,
) -> list[int]:
    bits = frame_bits(byte, stop=stop)
    if start_low is not None:
        bits = [0]  # placeholder; start duration overridden
    wave = [1] * idle
    if start_low is not None:
        wave.extend([0] * start_low)
        wave.extend([1] * tail)
        return wave
    acc = 0.0
    for i, b in enumerate(bits):
        acc += bit_period
        n = int(round(acc)) - int(round(acc - bit_period))
        if jitter and i > 0:
            n += jitter if (i % 2 == 0) else -jitter
        wave.extend([b] * max(1, n))
    wave.extend([1] * tail)
    return wave


def feed(core: Core, wave: list[int]) -> None:
    for b in wave:
        core.uio_in = b & 1
        core.step()


def run_frame(wave: list[int], bit_ticks: int = BIT) -> list[int]:
    c = Core()
    prog = uart_rx_frame.program(bit_ticks)
    if len(prog) > 32:
        raise AssertionError(f"frame RX {len(prog)} > 32")
    c.load(prog)
    c.start0 = True
    c.uio_in = 1
    feed(c, wave)
    return [w & 0xFF for w in c.sm0.rx]


def test_baud_error() -> None:
    for err in (0.0, 0.02, -0.02, 0.05, -0.05):
        period = BIT * (1.0 + err)
        got = run_frame(synth(0xA5, period))
        if not got:
            raise AssertionError(f"baud {err:+.0%}: no RX")
        if rev8(got[0]) != 0xA5:
            raise AssertionError(f"baud {err:+.0%}: {rev8(got[0]):#x} != 0xA5 raw={got[0]:#x}")


def test_jitter() -> None:
    for j in (-1, 1):
        got = run_frame(synth(0x3C, float(BIT), jitter=j))
        if not got or rev8(got[0]) != 0x3C:
            raise AssertionError(f"jitter {j}: {got}")


def test_runt() -> None:
    for n in (1, 2, 3, 4):
        got = run_frame(synth(0x55, float(BIT), start_low=n))
        if got:
            raise AssertionError(f"runt {n} cycles pushed {got}")


def test_bad_stop_and_break() -> None:
    bad = run_frame(synth(0x55, float(BIT), stop=0))
    if bad:
        raise AssertionError(f"bad stop pushed {bad}")
    brk = [1] * 8 + [0] * (11 * BIT) + [1] * 16
    got = run_frame(brk)
    if got:
        raise AssertionError(f"break pushed {got}")
    recover = brk + synth(0xC3, float(BIT), idle=16)
    got = run_frame(recover)
    if not got or rev8(got[-1]) != 0xC3:
        raise AssertionError(f"no recover after break: {got}")
    after_bad = synth(0x55, float(BIT), stop=0, tail=8) + synth(0x81, float(BIT), idle=16)
    got = run_frame(after_bad)
    if not got or rev8(got[-1]) != 0x81:
        raise AssertionError(f"no recover after bad stop: {got}")
    if any(rev8(x) == 0x55 for x in got):
        raise AssertionError(f"bad-stop byte leaked: {got}")


def test_old_rx_fooled_by_glitch() -> None:
    c = Core()
    c.load(uart_rx.program())
    c.start0 = True
    c.uio_in = 1
    glitch = [1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
    feed(c, glitch)
    if not c.sm0.rx:
        raise AssertionError("old uart_rx should still push on a 1-cycle glitch")
    framed = run_frame(glitch + [1] * 8)
    if framed:
        raise AssertionError(f"frame RX pushed on the same glitch: {framed}")


def main() -> None:
    test_baud_error()
    test_jitter()
    test_runt()
    test_bad_stop_and_break()
    test_old_rx_fooled_by_glitch()
    print("UART frame RX: ±0/2/5% baud, jitter, runt, bad stop, old-RX glitch OK")


if __name__ == "__main__":
    main()
