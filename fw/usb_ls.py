"""USB LS stretch: NRZI-ish TX on D- (pin0) / D+ (pin1). Not a PHY.

Firmware only. No chirp. Needs 12 MHz class clkdiv on the board.
"""

from isa import jmp, out, pull, sett


def program():
    return [
        sett(3, 3),
        pull(block=True),
        sett(1, 7),
        out(0, 1, delay=3),
        jmp(3, cond=2),
        sett(0, 0, delay=7),   # SE0-ish
        jmp(1),
    ]
