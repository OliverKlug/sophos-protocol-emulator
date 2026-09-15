"""JTAG IDCODE: TMS=1×5 → TLR, TMS 0,1,0,0 → Shift-DR, 32 TCK TDI=0.

TCK=side pin1, TDI=pin0, TMS=pin3, TDO=in_base pin2. Two 16-bit RX pushes.
"""

from isa import inn, jmp, push, sett

TLR_TCK = 4
SHIFT0 = 16
SHIFT1 = 21


def program():
    return [
        sett(3, 0xB),
        sett(5, 1),
        sett(4, 2),
        sett(1, 4),
        sett(0, 8, side=0),
        sett(0, 8, side=1),
        jmp(TLR_TCK, cond=2),
        sett(0, 0, side=0),
        sett(0, 0, side=1),
        sett(0, 8, side=0),
        sett(0, 8, side=1),
        sett(0, 0, side=0),
        sett(0, 0, side=1),
        sett(0, 0, side=0),
        sett(0, 0, side=1),
        sett(1, 15),
        sett(0, 0, side=0),
        inn(0, 1, side=1),
        jmp(SHIFT0, cond=2),
        push(block=False),
        sett(1, 15),
        sett(0, 0, side=0),
        inn(0, 1, side=1),
        jmp(SHIFT1, cond=2),
        push(block=False),
        jmp(25),
    ]
