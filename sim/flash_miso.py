"""Mode-0 SPI flash MISO: Hi-Z during the command, then canned JEDEC ID."""

from __future__ import annotations

JEDEC_ID = (0xEF, 0x40, 0x16)


class FlashMiso:
    def __init__(self, cmd: int = 0x9F, ident: tuple[int, int, int] = JEDEC_ID):
        self.cmd = cmd
        self.ident = ident
        self.last_sclk = 0
        self.last_cs = 1
        self.shift_in = 0
        self.n_in = 0
        self.n_out = 0
        self.reply = 0
        self.miso = 1
        self.active = False
        self.got_cmd: int | None = None

    def tick(self, resolved: int) -> int:
        mosi = resolved & 1
        sclk = (resolved >> 1) & 1
        cs = (resolved >> 3) & 1
        if cs == 1:
            self.last_sclk = sclk
            self.last_cs = 1
            self.shift_in = 0
            self.n_in = 0
            self.n_out = 0
            self.miso = 1
            self.active = False
            return self.miso
        if self.last_cs == 1 and cs == 0:
            self.shift_in = 0
            self.n_in = 0
            self.n_out = 0
            self.got_cmd = None
            self.active = True
            self.miso = 1
        if self.active and self.last_sclk == 0 and sclk == 1:
            if self.got_cmd is None:
                self.shift_in = ((self.shift_in << 1) | mosi) & 0xFF
                self.n_in += 1
                if self.n_in == 8:
                    self.got_cmd = self.shift_in
                    if self.got_cmd == self.cmd:
                        self.reply = (
                            (self.ident[0] << 16)
                            | (self.ident[1] << 8)
                            | self.ident[2]
                        )
                        self.n_out = 24
        if self.active and self.last_sclk == 1 and sclk == 0:
            if self.got_cmd == self.cmd and self.n_out > 0:
                self.n_out -= 1
                self.miso = (self.reply >> self.n_out) & 1
            elif self.got_cmd != self.cmd:
                self.miso = 1
        self.last_sclk = sclk
        self.last_cs = cs
        return self.miso
