"""I2C master vs wired-AND slave: ACK, NACK→STOP, stretch, Sr, OD monitor."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from golden import Core  # noqa: E402
from i2c_slave import I2CSlave  # noqa: E402
from isa import decode_fields  # noqa: E402
from monitors import OdMonitor, wire  # noqa: E402
import i2c_master  # noqa: E402


def _wait_pcs() -> tuple[int, int]:
    waits = [
        i
        for i, w in enumerate(i2c_master.program())
        if decode_fields(w)["op"] == 1
    ]
    if len(waits) < 2:
        raise AssertionError("I2C needs WAIT SCL in the bitloop and ACK slot")
    return waits[0], waits[1]


def _tick(core: Core, slave: I2CSlave, mon: OdMonitor) -> tuple[int, int]:
    bus = wire(core.sm0.pin_oe, core.sm0.pin_out, slave.sda_drv, slave.scl_drv)
    core.uio_in = bus
    resolved, oe = core.step()
    bus2 = wire(core.sm0.pin_oe, core.sm0.pin_out, slave.sda_drv, slave.scl_drv)
    mon.check(bus2, oe, core.sm0.pin_out)
    slave.observe(bus2)
    return bus2, oe


def _run(
    data: list[int],
    ack: bool = True,
    stretch: str = "none",
    hold: int = 0,
    steps: int = 400,
) -> tuple[Core, I2CSlave, OdMonitor, int]:
    prog = i2c_master.program()
    if len(prog) > 32:
        raise AssertionError(f"I2C IMEM {len(prog)} > 32")
    c = Core()
    c.load(prog)
    for byte in data:
        for w in i2c_master.encode_byte(byte):
            c.sm0.tx.append(w)
    c.start0 = True
    slave = I2CSlave(ack=ack, stretch=stretch, hold=hold)
    mon = OdMonitor()
    stretch_pc, _ack_pc = _wait_pcs()
    stalled = 0
    for _ in range(steps):
        _tick(c, slave, mon)
        if c.sm0.pc == stretch_pc:
            stalled += 1
    return c, slave, mon, stalled


def test_ack_path() -> None:
    _c, slave, mon, _ = _run([0xA5], ack=True, steps=250)
    if not slave.got_start:
        raise AssertionError("ACK path: no START")
    if 0xA5 not in slave.bytes:
        raise AssertionError(f"ACK path bytes={slave.bytes}")
    if mon.starts < 1:
        raise AssertionError("monitor missed START")


def test_nack_stop() -> None:
    c, slave, mon, _ = _run([0x3C], ack=False, steps=250)
    if not slave.got_start:
        raise AssertionError("NACK: no START")
    if not slave.got_stop:
        raise AssertionError("NACK did not STOP")
    if slave.got_sr:
        raise AssertionError("NACK took Sr instead of STOP")
    if c.sm0.pc not in (26, 27):
        raise AssertionError(f"NACK did not park on STOP pc={c.sm0.pc}")
    if mon.stops < 1:
        raise AssertionError("monitor missed STOP")


def test_stretch(kind: str, hold: int) -> None:
    _c, slave, mon, stalled = _run([0x00], ack=True, stretch=kind, hold=hold, steps=300)
    if stalled < hold // 2:
        raise AssertionError(
            f"stretch {kind} hold={hold}: pc on WAIT SCL for {stalled} < {hold // 2}"
        )
    if 0x00 not in slave.bytes:
        raise AssertionError(f"stretch {kind} did not finish the byte: {slave.bytes}")
    if mon.starts < 1:
        raise AssertionError(f"stretch {kind}: no START")


def test_repeated_start() -> None:
    _c, slave, mon, _ = _run([0xA5, 0x5A], ack=True, steps=500)
    if not slave.got_sr:
        raise AssertionError(f"no Sr: bytes={slave.bytes} start={slave.got_start}")
    if slave.bytes[:2] != [0xA5, 0x5A]:
        raise AssertionError(f"Sr bytes {slave.bytes}")
    if mon.srs < 1:
        raise AssertionError("monitor missed Sr")


def test_od_on_resolved() -> None:
    c, _slave, mon, _ = _run([0xA5], ack=True, steps=80)
    if mon.false_starts and not mon.starts:
        raise AssertionError("START counted on SCL=0")
    if c.sm0.pin_oe & c.sm0.pin_out & 3:
        raise AssertionError("final drive-high residue")


def main() -> None:
    if len(i2c_master.program()) > 32:
        raise AssertionError("I2C program > 32")
    test_ack_path()
    test_nack_stop()
    test_stretch("bit", 16)
    test_stretch("byte", 64)
    test_repeated_start()
    test_od_on_resolved()
    print("I2C slave: ACK, NACK→STOP, stretch bit/byte, Sr, OD monitor OK")


if __name__ == "__main__":
    main()
