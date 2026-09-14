#!/usr/bin/env python3
"""Walk the 8x8x32 opcode cube on golden.Sm and write expect for tb_sm_lockstep."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))

from golden import PC_MASK, Sm  # noqa: E402

DELAYS = (0, 1, 15)
EXPECT_PATH = ROOT / "sim" / "lockstep_expect.txt"


def pack(op: int, field: int, payload: int, delay: int, side: int) -> int:
    return ((op & 7) << 13) | ((side & 1) << 12) | ((delay & 15) << 8) | ((field & 7) << 5) | (payload & 31)


def run_case(instr: int, n_ticks: int) -> tuple[Sm, int, int]:
    sm = Sm()
    for _ in range(n_ticks):
        sm.step(instr, 0, 0, True, True)
    return sm, int(sm.tx_pop), int(sm.rx_push)


def cases() -> list[tuple[int, int, int]]:
    out: list[tuple[int, int, int]] = []
    for op in range(8):
        for field in range(8):
            for payload in range(32):
                for delay in DELAYS:
                    out.append((pack(op, field, payload, delay, 0), delay, 1 + delay))
    for op in (1, 3, 7):
        for field in (0, 3):
            for payload in (0, 1):
                for delay in DELAYS:
                    out.append((pack(op, field, payload, delay, 1), delay, 1 + delay))
    return out


def write_expect(path: Path = EXPECT_PATH) -> int:
    rows = cases()
    lines = [f"{len(rows)}\n"]
    for instr, delay, n_ticks in rows:
        sm, tx_pop, rx_push = run_case(instr, n_ticks)
        lines.append(
            f"{instr:04x} {delay} {n_ticks} {sm.pc & PC_MASK:02x} {sm.x:04x} {sm.y:04x} "
            f"{sm.isr:04x} {sm.osr:04x} {sm.pin_out:02x} {sm.pin_oe:02x} {tx_pop} {rx_push}\n"
        )
    path.write_text("".join(lines), encoding="utf-8")
    return len(rows)


def main() -> None:
    n = write_expect()
    print(f"lockstep expect cases={n} -> {EXPECT_PATH}")


if __name__ == "__main__":
    main()
