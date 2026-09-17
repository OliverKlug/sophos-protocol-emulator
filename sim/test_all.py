#!/usr/bin/env python3
"""Golden + SAT + protocol matrices. Fail if the ISA or replay is wrong."""

from __future__ import annotations

import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from golden import Core, Sm  # noqa: E402
from isa import decode_fields, encode, inn, jmp, out, sett, wait_pin  # noqa: E402
from monitors import OdMonitor  # noqa: E402
from sat_decode import prove_decode  # noqa: E402
import i2c_master  # noqa: E402
import jtag_shift  # noqa: E402
import ps2  # noqa: E402
import spi_master  # noqa: E402
import swd  # noqa: E402
import test_i2c_opendrain  # noqa: E402
import test_jtag_idcode  # noqa: E402
import test_spi_jedec  # noqa: E402
import test_uart_rx_jitter  # noqa: E402
import uart_rx  # noqa: E402
import test_usb_ls  # noqa: E402
import uart_tx  # noqa: E402


def hunt_uart_frame(pins: list[int], byte: int) -> list[int] | None:
    want = [0] + [(byte >> i) & 1 for i in range(8)] + [1]
    for i in range(len(pins) - 9):
        if pins[i : i + 10] == want:
            return want
    return None


def sample_uart_tx(byte: int = 0x55) -> list[int]:
    c = Core()
    c.load(uart_tx.program())
    c.sm0.tx.append(byte)
    c.start0 = True
    c.uio_in = 1
    pins = []
    for _ in range(48):
        resolved, _oe = c.step()
        pins.append(resolved & 1)
    bits = hunt_uart_frame(pins, byte)
    if bits is None:
        raise AssertionError(f"UART TX {byte:#x} not on pin0: {pins}")
    return pins


def expand_capture(records, first=0) -> list[int]:
    _ = first
    stream = []
    for hold, pins, _oe in records:
        stream.extend([pins] * hold)
    return stream


def test_wait_stall() -> None:
    c = Core()
    c.load([wait_pin(0, 0)])
    c.uio_in = 1
    c.start0 = True
    c.step()
    if c.sm0.pc != 0:
        raise AssertionError(f"WAIT did not stall, pc={c.sm0.pc}")
    c.uio_in = 0
    c.step()
    if c.sm0.pc != 1:
        raise AssertionError(f"WAIT did not retire, pc={c.sm0.pc}")


def test_sideset_on_wait() -> None:
    c = Core()
    c.load([wait_pin(0, 0, side=1)])
    c.uio_in = 1
    c.start0 = True
    c.step()
    if ((c.sm0.pin_out >> 1) & 1) != 1:
        raise AssertionError(f"side-set missing on WAIT stall: {c.sm0.pin_out:#x}")
    if c.sm0.pc != 0:
        raise AssertionError("WAIT moved PC while stalling")


def test_uart_rx_from_trace(byte: int = 0xB5) -> None:
    tx = Core()
    tx.load(uart_tx.program())
    tx.sm0.tx.append(byte)
    tx.start0 = True
    tx.cap_en = True
    tx.uio_in = 1
    trace = []
    for _ in range(48):
        res, _ = tx.step()
        trace.append(res & 1)
    if hunt_uart_frame(trace, byte) is None:
        raise AssertionError(f"TX missing {byte:#x}: {trace}")

    rx = Core()
    rx.load(uart_rx.program())
    rx.start0 = True
    rx.uio_in = 1
    for bit in trace:
        rx.uio_in = bit
        rx.step()
    if not rx.sm0.rx:
        raise AssertionError("RX FIFO empty after replay")
    got = rx.sm0.rx[0] & 0xFF
    # IN shifts left: first sample is ISR bit7. UART is LSB-first on the wire.
    rev = int(f"{got:08b}"[::-1], 2)
    if rev != byte:
        raise AssertionError(f"replay RX {got:#x} rev {rev:#x} != {byte:#x}")

    expanded = [p & 1 for p in expand_capture(tx.capture)]
    # Change-compress drops a stop bit that equals the last data bit.
    data = [0] + [(byte >> i) & 1 for i in range(8)]
    if not any(expanded[i : i + 9] == data for i in range(max(0, len(expanded) - 8))):
        raise AssertionError(f"capture expand lost the frame: {expanded}")


def test_spi_mode_bits() -> None:
    for cpol, cpha in spi_master.all_modes():
        for width, word in ((8, 0xA5), (16, 0xBEEF)):
            c = Core()
            c.load(spi_master.program(cpol, cpha, bits=width))
            c.sm0.tx.append(word)
            c.start0 = True
            mosi = []
            last_clk = cpol
            for _ in range(80):
                res, _ = c.step()
                clk = (res >> 1) & 1
                if cpha == 0 and last_clk == 0 and clk == 1:
                    mosi.append(res & 1)
                if cpha == 1 and last_clk == 1 and clk == 0:
                    mosi.append(res & 1)
                last_clk = clk
            if len(mosi) < width:
                raise AssertionError(f"SPI mode {cpol}{cpha} w={width} clocked {len(mosi)} bits")
            got = 0
            for i, b in enumerate(mosi[-width:]):
                got |= b << i
            if (word & ((1 << width) - 1)) != got:
                raise AssertionError(
                    f"SPI mode {cpol}{cpha} MOSI {got:#x} != {word:#x} bits={mosi}"
                )


def test_i2c_start_and_od() -> None:
    c = Core()
    c.load(i2c_master.program())
    for w in i2c_master.encode_byte(0xA5):
        c.sm0.tx.append(w)
    c.start0 = True
    c.uio_in = 0xFF
    mon = OdMonitor()
    saw_start = False
    last_sda, last_scl = 1, 1
    for _ in range(40):
        res, oe = c.step()
        mon.check(res, oe, c.sm0.pin_out)
        sda, scl = res & 1, (res >> 1) & 1
        if last_scl == 1 and last_sda == 1 and sda == 0 and scl == 1:
            saw_start = True
        last_sda, last_scl = sda, scl
    if not saw_start:
        raise AssertionError("no I2C START (SDA fall while SCL=1)")
    if mon.starts < 1:
        raise AssertionError("OD monitor missed START on resolved bus")


def test_baud_clkdiv() -> None:
    def frame_span(div: int) -> int:
        c = Core()
        c.load(uart_tx.program())
        c.div0 = div
        c.sm0.tx.append(0x00)
        c.start0 = True
        c.uio_in = 1
        pins = []
        for _ in range(80):
            res, _ = c.step()
            pins.append(res & 1)
        want = [0] * 9 + [1]
        for i in range(len(pins) - 9):
            if pins[i : i + 10] == want:
                return i
        raise AssertionError(f"no 0x00 frame at div={div}: {pins}")

    a = frame_span(1)
    b = frame_span(2)
    if b <= a:
        raise AssertionError(f"clkdiv=2 did not stretch the frame {a} vs {b}")


def test_swd_ps2_are_programs() -> None:
    for name, prog in (
        ("swd", swd.program()),
        ("ps2", ps2.program()),
    ):
        if not prog:
            raise AssertionError(name)
        if any(w > 0xFFFF for w in prog):
            raise AssertionError(name)
    if len(jtag_shift.program()) > 32:
        raise AssertionError("jtag IDCODE does not fit 32")


def test_pinoe_one_beat() -> None:
    c = Core()
    c.load([sett(5, 7), encode(3, (4 << 5) | 0)])
    c.sm0.osr = 0xA55A
    c.start0 = True
    c.step()
    c.step()
    if c.sm0.pin_out != 0x5A or c.sm0.pin_oe != 0xA5:
        raise AssertionError(f"PINOE {c.sm0.pin_out:#x}/{c.sm0.pin_oe:#x}")


def test_two_identical_sms() -> None:
    # Die is SM1-off. Keep the golden two-SM path, do not claim silicon.
    c = Core(sm1=True)
    if c.sm1 is None:
        return
    c.load(uart_tx.program())
    c.sm1.tx.append(0x01)
    c.start1 = True
    for _ in range(16):
        c.step()
    if (c.sm1.pin_oe & 1) != 1:
        raise AssertionError("SM1 did not assert OE")
    if c.sm1.pc == 0:
        raise AssertionError("SM1 PC stuck at 0")


def test_in_out_count() -> None:
    c = Core()
    c.load([inn(0, 2)])
    c.uio_in = 0b10
    c.start0 = True
    c.step()
    if c.sm0.isr != 0b01 or c.sm0.isr_cnt != 2:
        raise AssertionError(f"IN count=2 {c.sm0.isr:#x} cnt={c.sm0.isr_cnt}")

    d = Core()
    d.load([sett(5, 7), out(0, 2)])
    d.sm0.osr = 0b10
    d.start0 = True
    d.step()
    d.step()
    if (d.sm0.pin_out & 3) != 0b10:
        raise AssertionError(f"OUT count=2 {d.sm0.pin_out:#x}")


def test_constrained_random(n: int = 200, seed: int = 1) -> None:
    rng = random.Random(seed)
    c = Core()
    c.load([rng.randrange(65536) for _ in range(32)])
    c.start0 = True
    for _ in range(n):
        c.uio_in = rng.randrange(256)
        c.step()
        if not 0 <= c.sm0.pc <= 31:
            raise AssertionError("pc")
        if not 0 <= c.sm0.pin_out <= 255:
            raise AssertionError("pin")


def test_od_invariant_i2c_shape() -> None:
    for w in i2c_master.program():
        f = decode_fields(w)
        if f["op"] == 7 and ((f["payload"] >> 5) & 7) == 0:
            if (f["payload"] & 1) != 0:
                raise AssertionError("I2C firmware drives SDA high")


def test_jmp_page() -> None:
    try:
        jmp(32)
        raise AssertionError("jmp(32) must raise")
    except ValueError:
        pass


def test_capture_purity() -> None:
    c = Core()
    c.load([encode(5, (2 << 5) | 2)] * 4)
    c.cap_en = True
    snap = (c.sm0.pc, c.sm0.x, c.sm0.y, c.sm0.isr, c.sm0.osr)
    for pins in range(256):
        c.uio_in = pins
        c.step()
        now = (c.sm0.pc, c.sm0.x, c.sm0.y, c.sm0.isr, c.sm0.osr)
        if now != snap:
            raise AssertionError(f"halted capture mutated SM state {now}")
    if len(c.capture) < 2:
        raise AssertionError("capture wptr did not move on pin changes")


def test_uart_tb_words() -> None:
    words = uart_tx.program()
    want = [
        0xE001,
        0xE061,
        0x80A0,
        0xE000,
        0x6001,
        0x6001,
        0x6001,
        0x6001,
        0x6001,
        0x6001,
        0x6001,
        0x6001,
        0xE001,
        0x0002,
    ]
    if words != want:
        raise AssertionError(f"uart_tx drifted from Icarus TB: {words}")


def test_status_word() -> None:
    s = Sm()
    if s.status() != 0b101:
        raise AssertionError(f"idle STATUS {s.status():#b} != 0b101")
    s.tx.append(1)
    s.osr_cnt = 3
    s.rx.extend([0, 0, 0, 0])
    if s.status() != 0b010:
        raise AssertionError(f"busy STATUS {s.status():#b} != 0b010")


def test_one_cycle_nop() -> None:
    c = Core()
    c.load([encode(5, (2 << 5) | 2)])
    c.start0 = True
    c.step()
    if c.sm0.pc != 1:
        raise AssertionError(f"NOP is not one cycle, pc={c.sm0.pc}")


def write_expect_wave(pins: list[int], path: Path) -> None:
    bits = "".join("1" if p else "0" for p in pins)
    path.write_text(f"pin0 {bits}\n", encoding="utf-8")


def main() -> None:
    prove_decode()
    p55 = sample_uart_tx(0x55)
    sample_uart_tx(0x00)
    sample_uart_tx(0xFF)
    write_expect_wave(p55, ROOT / "sim" / "uart_tx_55.expect")
    test_wait_stall()
    test_sideset_on_wait()
    test_uart_rx_from_trace(0xB5)
    test_uart_rx_from_trace(0x55)
    test_spi_mode_bits()
    test_i2c_opendrain.main()
    test_i2c_start_and_od()
    test_uart_rx_jitter.main()
    test_spi_jedec.main()
    test_jtag_idcode.main()
    test_baud_clkdiv()
    test_swd_ps2_are_programs()
    test_usb_ls.main()
    test_pinoe_one_beat()
    test_two_identical_sms()
    test_in_out_count()
    test_constrained_random()
    test_od_invariant_i2c_shape()
    test_jmp_page()
    test_capture_purity()
    test_uart_tb_words()
    test_status_word()
    test_one_cycle_nop()
    import test_cap  # noqa: E402

    test_cap.main()
    print("golden+SAT: UART TX/RX replay 0xB5, frame RX jitter, SPI MOSI+JEDEC MISO,")
    print("I2C slave stretch/NACK/Sr, JTAG IDCODE, WAIT/side-set/clkdiv/SAT OK")


if __name__ == "__main__":
    main()
