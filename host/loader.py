"""Host nibble stream for the TT RP2040 (or the Icarus TB).

ui_in[3:0]=nibble, [6:4]=cmd, [7]=strobe (rising).
"""

from __future__ import annotations


def nibble_ops(cmd: int, nib: int) -> tuple[int, int]:
    return (cmd & 7, nib & 15)


def shift16(word: int) -> list[tuple[int, int]]:
    w = word & 0xFFFF
    return [
        nibble_ops(0, (w >> 12) & 15),
        nibble_ops(0, (w >> 8) & 15),
        nibble_ops(0, (w >> 4) & 15),
        nibble_ops(0, w & 15),
    ]


def load_imem(words: list[int], base: int = 0) -> list[tuple[int, int]]:
    ops = shift16(base) + [nibble_ops(2, 0)]
    for w in words:
        ops.extend(shift16(w))
        ops.append(nibble_ops(1, 0))
    return ops


def fifo0(word: int) -> list[tuple[int, int]]:
    return shift16(word) + [nibble_ops(3, 0)]


def start_sm0(capture: bool = False) -> list[tuple[int, int]]:
    nib = 0b0001 | (0b0100 if capture else 0)
    return [nibble_ops(5, nib)]


def replay_sm0() -> list[tuple[int, int]]:
    return [nibble_ops(5, 0b1000)]


def peek(sel: int) -> list[tuple[int, int]]:
    return [nibble_ops(7, sel & 15)]


def set_cap_mode(bit: int) -> list[tuple[int, int]]:
    """Peek 15 loads cap_mode from shifter[0] and rewinds dump_idx."""
    return shift16(bit & 1) + peek(15)


def dump_cap(n: int) -> list[tuple[int, int]]:
    """Sequential dump. dump_idx is 0 after cap arm; rewind with set_cap_mode."""
    ops: list[tuple[int, int]] = []
    for _ in range(n):
        ops.extend(peek(11) + peek(12) + peek(13) + peek(14))
    return ops
