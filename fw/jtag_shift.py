"""JTAG shift-DR: TCK=side pin1, TDI=pin0, TMS=pin3, TDO=in_base pin2."""

from isa import inn, jmp, out, pull, push, sett


def program():
    return [
        sett(3, 0xB),        # oe TDI TCK TMS
        sett(5, 1),
        sett(4, 2),
        pull(block=True),
        sett(1, 7),
        out(0, 1, side=0),
        inn(0, 1, side=1),
        jmp(5, cond=2),
        push(block=False),
        jmp(3),
    ]
