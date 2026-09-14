"""PS/2 device clock sample. CLK=pin1 wait, DATA=pin0."""

from isa import inn, jmp, push, sett, wait_pin


def program():
    return [
        sett(4, 0),
        wait_pin(0, 1),
        inn(0, 1),
        sett(1, 9),
        wait_pin(0, 1),
        inn(0, 1),
        jmp(4, cond=2),
        push(block=True),
        jmp(1),
    ]
