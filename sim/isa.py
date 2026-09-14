"""Shared 16-bit encodings. Decoder is the SAT object."""

OP_JMP, OP_WAIT, OP_IN, OP_OUT, OP_PP, OP_MOV, OP_IRQ, OP_SET = range(8)
OP_NAMES = ("JMP", "WAIT", "IN", "OUT", "PUSHPULL", "MOV", "IRQ", "SET")

SIDESET_COUNT = 1


def encode(op: int, payload: int = 0, delay: int = 0, side: int = 0) -> int:
    if not 0 <= op <= 7:
        raise ValueError("op")
    if not 0 <= delay <= 15:
        raise ValueError("delay")
    if side not in (0, 1):
        raise ValueError("side")
    return ((op & 7) << 13) | ((side & 1) << 12) | ((delay & 15) << 8) | (payload & 0xFF)


def decode_fields(word: int) -> dict:
    word &= 0xFFFF
    return {
        "op": (word >> 13) & 7,
        "side": (word >> 12) & 1,
        "delay": (word >> 8) & 15,
        "payload": word & 0xFF,
    }


def jmp(addr: int, cond: int = 0, delay: int = 0, side: int = 0) -> int:
    if not 0 <= addr <= 31:
        raise ValueError("jmp addr 0..31; MOV PC for long jumps")
    pay = ((cond & 7) << 5) | (addr & 31)
    return encode(OP_JMP, pay, delay, side)


def wait_pin(pol: int, idx: int, src: int = 0, delay: int = 0, side: int = 0) -> int:
    pay = ((pol & 1) << 7) | ((src & 3) << 5) | (idx & 31)
    return encode(OP_WAIT, pay, delay, side)


def inn(src: int, count: int, delay: int = 0, side: int = 0) -> int:
    c = 0 if count == 16 else count
    return encode(OP_IN, ((src & 7) << 5) | (c & 31), delay, side)


def out(dest: int, count: int, delay: int = 0, side: int = 0) -> int:
    c = 0 if count == 16 else count
    return encode(OP_OUT, ((dest & 7) << 5) | (c & 31), delay, side)


def pull(block: bool = True, iff: bool = False, delay: int = 0, side: int = 0) -> int:
    pay = (1 << 7) | ((1 if iff else 0) << 6) | ((1 if block else 0) << 5)
    return encode(OP_PP, pay, delay, side)


def push(block: bool = True, iff: bool = False, delay: int = 0, side: int = 0) -> int:
    pay = ((1 if iff else 0) << 6) | ((1 if block else 0) << 5)
    return encode(OP_PP, pay, delay, side)


def mov(dest: int, src: int, op: int = 0, delay: int = 0, side: int = 0) -> int:
    return encode(OP_MOV, ((dest & 7) << 5) | ((op & 3) << 3) | (src & 7), delay, side)


def irq(idx: int, clr: bool = False, wait: bool = False, delay: int = 0, side: int = 0) -> int:
    pay = ((1 if clr else 0) << 7) | ((1 if wait else 0) << 6) | (idx & 7)
    return encode(OP_IRQ, pay, delay, side)


def sett(dest: int, imm: int, delay: int = 0, side: int = 0) -> int:
    return encode(OP_SET, ((dest & 7) << 5) | (imm & 31), delay, side)


def nop(delay: int = 0, side: int = 0) -> int:
    return mov(2, 2, delay=delay, side=side)
