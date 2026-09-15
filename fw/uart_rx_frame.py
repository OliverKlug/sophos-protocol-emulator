"""UART RX: WAIT idle, WAIT start, delay to bit centre, runt JMP PIN, 8×IN, stop check.

Uses the shared delay field. No extra delay opcode.
IN shifts left; host bit-reverses the FIFO byte vs LSB-first UART.
"""

from isa import inn, jmp, push, sett, wait_pin

WAIT_IDLE = 1
WAIT_START = 2
DO_PUSH = 14


def program(bit_ticks: int = 8):
    if bit_ticks < 4 or bit_ticks - 1 > 15:
        raise ValueError("bit_ticks 4..16")
    half = bit_ticks // 2
    wait_d = max(0, half - 1)
    bit_d = bit_ticks - 1
    return [
        sett(4, 0),
        wait_pin(1, 0),
        wait_pin(0, 0, delay=wait_d),
        jmp(WAIT_START, cond=5, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        inn(0, 1, delay=bit_d),
        jmp(DO_PUSH, cond=5),
        jmp(WAIT_IDLE),
        push(block=True),
        jmp(WAIT_IDLE),
    ]
