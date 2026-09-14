"""UART RX: wait start, one IN per bit, push. Matches unrolled TX bit times."""

from isa import inn, jmp, push, sett, wait_pin


def program():
    return [
        sett(4, 0),
        wait_pin(0, 0),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        inn(0, 1),
        push(block=True),
        jmp(1),
    ]
