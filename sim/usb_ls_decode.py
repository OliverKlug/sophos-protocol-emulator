"""USB LS line decoder: NRZI, destuff-by-delete, SYNC/PID/EOP/CRC16."""

from __future__ import annotations

J = 0b01
K = 0b10
SE0 = 0b00
SE1 = 0b11


def line_state(dm: int, dp: int) -> int:
    return ((dp & 1) << 1) | (dm & 1)


def name_state(st: int) -> str:
    return {J: "J", K: "K", SE0: "SE0", SE1: "SE1"}[st]


def destuff_nrzi(symbols: list[int]) -> tuple[list[int], int]:
    """NRZI (0=flip) then drop stuffed 0 after six 1s. Idle J. Returns (nrz, eop_index)."""
    i = 0
    n = len(symbols)
    while i < n and symbols[i] == J:
        i += 1
    if i >= n:
        raise AssertionError("FAIL USB LS SYNC")
    prev = J
    nrz: list[int] = []
    ones = 0
    while i < n:
        st = symbols[i]
        if st == SE1:
            raise AssertionError("FAIL USB LS SE1")
        if st == SE0:
            break
        bit = 0 if st != prev else 1
        prev = st
        if ones == 6:
            if bit != 0:
                raise AssertionError("FAIL USB LS stuff")
            ones = 0
            i += 1
            continue
        nrz.append(bit)
        ones = ones + 1 if bit else 0
        i += 1
    else:
        raise AssertionError("FAIL USB LS EOP")
    return nrz, i


def bits_to_bytes(nrz: list[int]) -> list[int]:
    if len(nrz) % 8:
        raise AssertionError(f"FAIL USB LS SYNC len {len(nrz)}")
    out: list[int] = []
    for i in range(0, len(nrz), 8):
        b = 0
        for k, bit in enumerate(nrz[i : i + 8]):
            b |= bit << k
        out.append(b)
    return out


def pid_ok(pid: int) -> bool:
    return (pid & 0xF) == ((~pid >> 4) & 0xF)


def decode_symbols(symbols: list[int]) -> list[int]:
    nrz, eop_i = destuff_nrzi(symbols)
    if eop_i + 2 >= len(symbols):
        raise AssertionError("FAIL USB LS EOP")
    if symbols[eop_i] != SE0 or symbols[eop_i + 1] != SE0:
        raise AssertionError("FAIL USB LS EOP")
    if eop_i + 2 >= len(symbols) or symbols[eop_i + 2] != J:
        raise AssertionError("FAIL USB LS EOP")
    body = bits_to_bytes(nrz)
    if not body or body[0] != 0x80:
        raise AssertionError(f"FAIL USB LS SYNC {body[:1]}")
    if len(body) < 2 or not pid_ok(body[1]):
        raise AssertionError("FAIL USB LS PID")
    return body


def downsample(trace: list[tuple[int, int]], bit_ticks: int) -> list[int]:
    """trace is (resolved[1:0], oe[1:0]) per sysclk. Lock first driven K, sample bit centre."""
    if bit_ticks < 1:
        raise ValueError("bit_ticks")
    lock = None
    for i, (pins, oe) in enumerate(trace):
        if (oe & 3) != 3:
            continue
        if (pins & 3) == K:
            lock = i
            break
    if lock is None:
        raise AssertionError("FAIL USB LS SYNC")
    centre = lock + bit_ticks // 2
    symbols: list[int] = []
    i = centre
    while i < len(trace):
        pins, oe = trace[i]
        if (oe & 3) == 0:
            break
        symbols.append(pins & 3)
        i += bit_ticks
    return symbols
