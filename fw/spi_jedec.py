"""SPI JEDEC RDID 0x9F, MSB-first on the wire.

CS=pin3, MOSI=pin0, SCLK=side-set pin1, MISO=in_base pin2, mode 0.
Host places the 8-bit reverse of the command in the TX low byte
(ISA has no MOV OSR). MOV ISR, OSR, bitrev still runs. 32 clocks,
two RX pushes.
"""

from isa import inn, jmp, mov, out, pull, push, sett

BITLOOP0 = 8
BITLOOP1 = 13


def program():
    return [
        sett(3, 0xB),
        sett(5, 1),
        sett(4, 2),
        sett(0, 8, side=0),
        pull(block=True),
        mov(6, 6, op=2),
        sett(0, 0, side=0),
        sett(1, 15),
        out(0, 1, side=0),
        inn(0, 1, side=1),
        jmp(BITLOOP0, cond=2),
        push(block=False),
        sett(1, 15),
        out(0, 1, side=0),
        inn(0, 1, side=1),
        jmp(BITLOOP1, cond=2),
        push(block=False),
        sett(0, 8, side=0),
        jmp(4),
    ]


def tx_word(cmd: int = 0x9F) -> int:
    """Low byte is 8-bit reverse of cmd. OUT is LSB-first; that is MSB-first on the wire.

    MOV bitrev has no OSR dest on this ISA (dest 6 is ISR), so the host
    places the reversed byte. The program still MOV ISR, OSR, bitrev.
    """
    return int(f"{cmd & 0xFF:08b}"[::-1], 2)
