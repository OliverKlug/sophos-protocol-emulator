"""Protocol pin monitors. Call on the resolved bus, not pin_out with OE ignored."""

from __future__ import annotations


class OdMonitor:
    """Open-drain: never (oe && pin_out) on SDA/SCL. START only while SCL=1."""

    def __init__(self, sda_bit: int = 0, scl_bit: int = 1):
        self.sda_bit = sda_bit
        self.scl_bit = scl_bit
        self.last_sda = 1
        self.last_scl = 1
        self.starts = 0
        self.stops = 0
        self.srs = 0
        self.started = False
        self.false_starts = 0

    def check(self, resolved: int, oe: int, pin_out: int) -> None:
        sda_m = 1 << self.sda_bit
        scl_m = 1 << self.scl_bit
        if (oe & sda_m) and (pin_out & sda_m):
            raise AssertionError("I2C drove SDA high")
        if (oe & scl_m) and (pin_out & scl_m):
            raise AssertionError("I2C drove SCL high")
        sda = (resolved >> self.sda_bit) & 1
        scl = (resolved >> self.scl_bit) & 1
        if self.last_sda == 1 and sda == 0:
            if scl == 1 and self.last_scl == 1:
                if self.started:
                    self.srs += 1
                self.starts += 1
                self.started = True
            else:
                self.false_starts += 1
        if self.last_sda == 0 and sda == 1 and scl == 1 and self.last_scl == 1:
            self.stops += 1
            self.started = False
        self.last_sda = sda
        self.last_scl = scl


def wire(oe: int, pin_out: int, slave_sda: int, slave_scl: int) -> int:
    """Wired-AND with pull-ups. slave_* is 0 when the slave drives low."""
    bus = 0xFF
    bus &= ~(oe & ~pin_out & 0xFF)
    if slave_sda == 0:
        bus &= ~1
    if slave_scl == 0:
        bus &= ~2
    return bus
