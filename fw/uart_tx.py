"""UART TX 8n1 LSB-first. Set idle before OE so we never drive a false start."""

from isa import jmp, out, pull, sett


def program():
    return [
        sett(0, 1),       # 0 idle level before OE
        sett(3, 1),       # 1 drive pin0
        pull(block=True), # 2
        sett(0, 0),       # 3 start
        out(0, 1),
        out(0, 1),
        out(0, 1),
        out(0, 1),
        out(0, 1),
        out(0, 1),
        out(0, 1),
        out(0, 1),
        sett(0, 1),       # 12 stop
        jmp(2),
    ]
