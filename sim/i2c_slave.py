"""I2C slave model: ACK or NACK, stretch 0 / 1 bit / 1 byte, START/STOP/Sr."""

from __future__ import annotations


class I2CSlave:
    def __init__(self, ack: bool = True, stretch: str = "none", hold: int = 0):
        if stretch not in ("none", "bit", "byte"):
            raise ValueError("stretch")
        self.ack = ack
        self.stretch = stretch
        self.hold = hold
        self.sda_drv = 1
        self.scl_drv = 1
        self.last_sda = 1
        self.last_scl = 1
        self.started = False
        self.bits: list[int] = []
        self.bytes: list[int] = []
        self.got_start = False
        self.got_stop = False
        self.got_sr = False
        self.stretch_left = 0
        self.stretched_once = False
        self.in_ack = False
        self.ack_seen_high = False
        self.need_ack = False
        self.bit_count = 0

    def _reset_byte(self) -> None:
        self.bits = []
        self.bit_count = 0
        self.in_ack = False
        self.ack_seen_high = False
        self.need_ack = False
        self.sda_drv = 1

    def observe(self, bus: int) -> None:
        sda, scl = bus & 1, (bus >> 1) & 1
        if self.last_scl == 1 and scl == 1:
            if self.last_sda == 1 and sda == 0:
                if not self.in_ack:
                    if self.started:
                        self.got_sr = True
                    self.started = True
                    self.got_start = True
                    self._reset_byte()
            elif self.last_sda == 0 and sda == 1 and not self.in_ack:
                self.got_stop = True
                self.started = False
                self._reset_byte()
                self.scl_drv = 1
                self.stretch_left = 0

        if self.started and self.last_scl == 0 and scl == 1:
            if self.in_ack:
                self.ack_seen_high = True
            elif not self.need_ack:
                self.bits.append(sda)
                self.bit_count += 1
                if self.bit_count == 8:
                    val = 0
                    for b in self.bits[-8:]:
                        val = (val << 1) | b
                    self.bytes.append(val)
                    self.bit_count = 0
                    self.need_ack = True

        if self.need_ack and self.last_scl == 1 and scl == 0:
            self.in_ack = True
            self.need_ack = False

        if self.in_ack:
            self.sda_drv = 0 if self.ack else 1
            if scl == 1:
                self.ack_seen_high = True
            if self.ack_seen_high and self.last_scl == 1 and scl == 0:
                self.in_ack = False
                self.ack_seen_high = False
                self.sda_drv = 1

        want_stretch = False
        if self.started and self.hold > 0 and self.stretch != "none":
            if not self.stretched_once:
                want_stretch = True
        if want_stretch and scl == 1 and self.stretch_left == 0:
            self.stretch_left = self.hold
            self.stretched_once = True

        if self.stretch_left > 0:
            self.scl_drv = 0
            self.stretch_left -= 1
            if self.stretch_left == 0:
                self.scl_drv = 1
        elif not self.started:
            self.scl_drv = 1

        self.last_sda, self.last_scl = sda, scl
