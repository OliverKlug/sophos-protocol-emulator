"""SPI master, all four modes. SCLK=side-set pin1, MOSI=pin0, MISO=in_base pin2.

CPOL is idle level of side-set. CPHA selects which instr samples.
"""

from isa import inn, jmp, out, pull, push, sett


def program(cpol: int, cpha: int, bits: int = 8):
    idle = cpol & 1
    # CPHA0: drive MOSI with clock low, sample on rising (side=1)
    # CPHA1: clock edge first, then sample
    if cpha == 0:
        body = [
            out(0, 1, side=idle),
            inn(0, 1, side=1 - idle),
        ]
    else:
        body = [
            out(0, 1, side=1 - idle),
            inn(0, 1, side=idle),
        ]
    return [
        sett(3, 3),          # oe pin0+1
        sett(5, 1),          # side_pin = 1
        sett(4, 2),          # in_base = 2
        sett(0, 0, side=idle),
        pull(block=True),
        sett(1, bits - 1),
        *body,
        jmp(6, cond=2),
        push(block=False),
        jmp(4),
    ]


def all_modes():
    return {(cpol, cpha): program(cpol, cpha) for cpol in (0, 1) for cpha in (0, 1)}
