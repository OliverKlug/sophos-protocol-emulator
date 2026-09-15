"""I2C master: open-drain via PINOE. SDA=pin0, SCL=pin1.

FIFO words are PINOE beats, not raw data bytes. Use encode_byte().
Drive 0 = {oe=1, val=0}. HiZ = {oe=0, val=0}. Never val=1 on SDA.

9th SCL is the ACK slot. JMP PIN (SDA): ACK → repeated START, NAK → STOP.
"""

from isa import jmp, out, pull, sett, wait_pin

BITLOOP = 5
STOP = 22


def pinoe_word(oe: int, val: int = 0) -> int:
    return ((oe & 0xFF) << 8) | (val & 0xFF)


def encode_byte(byte: int) -> list[int]:
    """MSB-first. Two PINOE words per bit: SCL=0, then SCL HiZ (stretch)."""
    words: list[int] = []
    for i in range(7, -1, -1):
        bit = (byte >> i) & 1
        sda_oe = 0 if bit else 1
        words.append(pinoe_word(sda_oe | 2, 0))
        words.append(pinoe_word(sda_oe, 0))
    return words


def program():
    return [
        sett(3, 0),
        sett(0, 0),
        sett(3, 1),
        sett(3, 3),
        sett(1, 7),
        pull(block=True),
        out(4, 0),
        pull(block=True),
        out(4, 0),
        wait_pin(1, 1),
        jmp(BITLOOP, cond=2),
        sett(3, 2),
        sett(3, 0),
        wait_pin(1, 1),
        jmp(STOP, cond=5),
        sett(3, 2),
        sett(3, 0),
        sett(3, 1),
        sett(0, 0),
        sett(3, 3),
        sett(1, 7),
        jmp(BITLOOP),
        sett(3, 3),
        sett(0, 0),
        sett(3, 1),
        wait_pin(1, 1),
        sett(3, 0),
        jmp(26),
    ]
