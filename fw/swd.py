"""SWD header-ish: SWCLK=side pin1, SWDIO={value,oe} on pin0. Turnaround is PINOE."""

from isa import jmp, out, pull, sett


def program():
    return [
        sett(5, 1),
        sett(3, 3),
        pull(block=True),
        sett(1, 7),
        out(0, 1, side=0),
        out(0, 1, side=1),
        jmp(4, cond=2),
        out(4, 16),          # PINOE: HiZ SWDIO for turnaround
        jmp(2),
    ]
