"""IEEE 1149.1 TAP: canned 32-bit IDCODE on TDO in Shift-DR."""

from __future__ import annotations

IDCODE = 0x1234ABCD

# TLR --0--> RTI --1--> Select-DR --0--> Capture-DR --0--> Shift-DR
_NEXT = {
    "TLR": {0: "RTI", 1: "TLR"},
    "RTI": {0: "RTI", 1: "Select-DR"},
    "Select-DR": {0: "Capture-DR", 1: "Select-IR"},
    "Capture-DR": {0: "Shift-DR", 1: "Exit1-DR"},
    "Shift-DR": {0: "Shift-DR", 1: "Exit1-DR"},
    "Exit1-DR": {0: "Pause-DR", 1: "Update-DR"},
    "Pause-DR": {0: "Pause-DR", 1: "Exit2-DR"},
    "Exit2-DR": {0: "Shift-DR", 1: "Update-DR"},
    "Update-DR": {0: "RTI", 1: "Select-DR"},
    "Select-IR": {0: "Capture-IR", 1: "TLR"},
    "Capture-IR": {0: "Shift-IR", 1: "Exit1-IR"},
    "Shift-IR": {0: "Shift-IR", 1: "Exit1-IR"},
    "Exit1-IR": {0: "Pause-IR", 1: "Update-IR"},
    "Pause-IR": {0: "Pause-IR", 1: "Exit2-IR"},
    "Exit2-IR": {0: "Shift-IR", 1: "Update-IR"},
    "Update-IR": {0: "RTI", 1: "Select-DR"},
}


class JtagTap:
    def __init__(self, idcode: int = IDCODE):
        self.idcode = idcode & 0xFFFFFFFF
        self.state = "TLR"
        self.last_tck = 0
        self.shifter = idcode & 0xFFFFFFFF
        self.tdo = 1

    def tick(self, resolved: int) -> int:
        tdi = resolved & 1
        tck = (resolved >> 1) & 1
        tms = (resolved >> 3) & 1
        if self.last_tck == 0 and tck == 1:
            was = self.state
            self.state = _NEXT.get(was, _NEXT["TLR"])[tms]
            if self.state == "Capture-DR":
                self.shifter = self.idcode
            elif was == "Shift-DR":
                self.shifter = ((tdi << 31) | (self.shifter >> 1)) & 0xFFFFFFFF
            elif self.state == "TLR":
                self.shifter = self.idcode
        if self.last_tck == 1 and tck == 0:
            if self.state == "Shift-DR":
                self.tdo = self.shifter & 1
            else:
                self.tdo = 1
        self.last_tck = tck
        return self.tdo
