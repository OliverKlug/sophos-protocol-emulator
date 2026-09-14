"""Cycle-accurate golden for one SM + a tiny two-SM core (host/capture)."""

from __future__ import annotations

from collections import deque
from isa import decode_fields

PC_MASK = 31
IMEM_WORDS = 32


class Sm:
    def __init__(self):
        self.pc = 0
        self.x = 0
        self.y = 0
        self.isr = 0
        self.osr = 0
        self.isr_cnt = 0
        self.osr_cnt = 0
        self.pin_out = 0
        self.pin_oe = 0
        self.delay_cnt = 0
        self.side_done = False
        self.in_base = 0
        self.side_pin = 1
        self.tx = deque()
        self.rx = deque()
        self.irq_set = None
        self.irq_clr = None
        self.tx_pop = False
        self.rx_push = False

    def status(self) -> int:
        tx_empty = int(len(self.tx) == 0)
        rx_full = int(len(self.rx) >= 4)
        osre = int(self.osr_cnt == 0)
        return (tx_empty << 2) | (rx_full << 1) | osre

    def _wait_bit(self, src, idx, pin_in, irq):
        if src == 0:
            return (pin_in >> (idx & 7)) & 1
        if src == 1:
            return (irq >> (idx & 7)) & 1
        return (pin_in >> self.in_base) & 1

    def step(self, instr: int, pin_in: int, irq: int, tick: bool, start: bool) -> None:
        self.irq_set = None
        self.irq_clr = None
        self.tx_pop = False
        self.rx_push = False
        if not start:
            self.pc = 0
            self.delay_cnt = 0
            self.side_done = False
            return
        if not tick:
            return
        f = decode_fields(instr)
        op, side, delay, pay = f["op"], f["side"], f["delay"], f["payload"]
        if self.delay_cnt:
            self.delay_cnt -= 1
            return

        wait_src = (pay >> 5) & 3
        wait_pol = (pay >> 7) & 1
        wait_idx = pay & 31
        stall_wait = op == 1 and self._wait_bit(wait_src, wait_idx, pin_in, irq) != wait_pol
        is_pull = (pay >> 7) & 1
        pp_iff = (pay >> 6) & 1
        pp_block = (pay >> 5) & 1
        osre = self.osr_cnt == 0
        pull_stall = op == 4 and is_pull and pp_block and (len(self.tx) == 0) and ((not pp_iff) or osre)
        push_stall = op == 4 and (not is_pull) and pp_block and (len(self.rx) >= 4) and ((not pp_iff) or self.isr_cnt != 0)
        # ponytail: IRQ wait stalls while the flag is clear (wait-for-set), matching sm.v.
        # Retire still pulses irq_set. Invert both if a wait-for-clear program shows up.
        irq_wait = op == 6 and ((pay >> 6) & 1) and not ((pay >> 7) & 1)
        stall_irq = irq_wait and not ((irq >> (pay & 7)) & 1)
        stall = stall_wait or pull_stall or push_stall or stall_irq

        apply_side = not self.side_done
        if apply_side:
            bit = 1 << self.side_pin
            self.pin_out = (self.pin_out & ~bit) | (side << self.side_pin)

        if stall:
            self.side_done = True
            return

        self.delay_cnt = delay
        self.side_done = False
        io = (pay >> 5) & 7
        count = 16 if (pay & 31) == 0 else (pay & 31)
        cond = (pay >> 5) & 7
        addr = pay & 31

        def _side_wins() -> None:
            if apply_side:
                b = 1 << self.side_pin
                self.pin_out = (self.pin_out & ~b) | (side << self.side_pin)

        if op == 0:
            taken = {
                0: True,
                1: self.x == 0,
                2: self.x != 0,
                3: self.y == 0,
                4: self.y != 0,
                5: ((pin_in >> self.in_base) & 1) == 1,
                6: osre,
                7: self.x != self.y,
            }[cond]
            if cond == 2 and self.x:
                self.x -= 1
            if cond == 4 and self.y:
                self.y -= 1
            self.pc = addr if taken else ((self.pc + 1) & PC_MASK)
            _side_wins()
            return

        if op == 1:
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        if op == 2:
            if io in (0, 7):
                for k in range(count):
                    bit = (pin_in >> ((self.in_base + k) & 7)) & 1
                    self.isr = ((self.isr << 1) | bit) & 0xFFFF
                    self.isr_cnt = min(16, self.isr_cnt + 1)
            else:
                srcs = {1: self.x, 2: self.y, 3: 0, 4: self.isr, 5: self.osr, 6: self.status()}
                self.isr = srcs.get(io, 0) & 0xFFFF
                self.isr_cnt = count
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        if op == 3:
            if io == 0:
                for k in range(count):
                    bit = self.osr & 1
                    self.pin_out = (self.pin_out & ~(1 << (k & 7))) | (bit << (k & 7))
                    self.osr >>= 1
                    self.osr_cnt = max(0, self.osr_cnt - 1)
            elif io == 1:
                self.x = self.osr
            elif io == 2:
                self.y = self.osr
            elif io == 3:
                self.pin_oe = self.osr & 0xFF
            elif io == 4:
                self.pin_out = self.osr & 0xFF
                self.pin_oe = (self.osr >> 8) & 0xFF
                self.osr_cnt = 0
            elif io == 5:
                self.pc = self.osr & PC_MASK
                _side_wins()
                return
            elif io == 6:
                self.isr = self.osr
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        if op == 4:
            # Match sm.v: non-block PULL/PUSH still pulse when the FIFO is empty/full.
            pull_ok = is_pull and ((not pp_iff) or osre) and (len(self.tx) > 0 or not pp_block)
            push_ok = (not is_pull) and ((not pp_iff) or self.isr_cnt != 0) and (
                len(self.rx) < 4 or not pp_block
            )
            if pull_ok:
                self.osr = (self.tx.popleft() if self.tx else 0) & 0xFFFF
                self.osr_cnt = 16
                self.tx_pop = True
            elif push_ok:
                if len(self.rx) < 4:
                    self.rx.append(self.isr)
                self.isr = 0
                self.isr_cnt = 0
                self.rx_push = True
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        if op == 5:
            srcs = {
                0: pin_in,
                1: self.x,
                2: self.y,
                3: 0,
                4: self.status(),
                5: self.isr,
                6: self.osr,
                7: (self.pin_oe << 8) | self.pin_out,
            }
            val = srcs[pay & 7] & 0xFFFF
            mop = (pay >> 3) & 3
            if mop == 1:
                val = (~val) & 0xFFFF
            elif mop == 2:
                val = int(f"{val:016b}"[::-1], 2)
            dest = io
            if dest == 0:
                self.pin_out = val & 0xFF
            elif dest == 1:
                self.x = val
            elif dest == 2:
                self.y = val
            elif dest == 3:
                self.pin_oe = val & 0xFF
            elif dest == 4:
                self.pin_out = val & 0xFF
                self.pin_oe = (val >> 8) & 0xFF
            elif dest == 5:
                self.pc = val & PC_MASK
                _side_wins()
                return
            elif dest == 6:
                self.isr = val
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        if op == 6:
            idx = pay & 7
            if (pay >> 7) & 1:
                self.irq_clr = idx
            else:
                self.irq_set = idx
            self.pc = (self.pc + 1) & PC_MASK
            _side_wins()
            return

        dest = io
        imm = pay & 31
        if dest == 0:
            self.pin_out = (self.pin_out & ~0x1F) | imm
        elif dest == 1:
            self.x = imm
        elif dest == 2:
            self.y = imm
        elif dest == 3:
            self.pin_oe = (self.pin_oe & ~0x1F) | imm
        elif dest == 4:
            self.in_base = imm & 7
        elif dest == 5:
            self.side_pin = imm & 7
        self.pc = (self.pc + 1) & PC_MASK
        _side_wins()


class Core:
    def __init__(self, sm1: bool = False):
        self.imem = [0] * IMEM_WORDS
        self.sm0 = Sm()
        self.sm1 = Sm() if sm1 else None
        self.start0 = False
        self.start1 = False
        self.irq = 0
        self.div0 = 1
        self.div1 = 1
        self.phase0 = 0
        self.phase1 = 0
        self.uio_in = 0
        self.capture = []
        self.cap_en = False
        self.last_pins = 0
        self.delta = 0

    def load(self, words, base=0):
        for i, w in enumerate(words):
            self.imem[(base + i) & PC_MASK] = w & 0xFFFF

    def tick_div(self, phase, div):
        thresh = (div if div else 1) * 256
        nxt = phase + 256
        if nxt >= thresh:
            return nxt - thresh, True
        return nxt, False

    def step(self):
        self.phase0, t0 = self.tick_div(self.phase0, self.div0 if self.start0 else 0)
        t1 = False
        if self.sm1 is not None:
            self.phase1, t1 = self.tick_div(self.phase1, self.div1 if self.start1 else 0)
        if not self.start0:
            t0 = False
            self.phase0 = 0
        if self.sm1 is None or not self.start1:
            t1 = False
            self.phase1 = 0
        oe1 = 0 if self.sm1 is None else self.sm1.pin_oe
        out1 = 0 if self.sm1 is None else self.sm1.pin_out
        oe = self.sm0.pin_oe | oe1
        driven = (out1 & oe1) | (self.sm0.pin_out & self.sm0.pin_oe & ~oe1)
        resolved = driven | (self.uio_in & ~oe)
        self.sm0.step(self.imem[self.sm0.pc & PC_MASK], resolved, self.irq, t0, self.start0)
        if self.sm1 is not None:
            self.sm1.step(self.imem[self.sm1.pc & PC_MASK], resolved, self.irq, t1, self.start1)
        if self.sm0.irq_set is not None:
            self.irq |= 1 << self.sm0.irq_set
        if self.sm0.irq_clr is not None:
            self.irq &= ~(1 << self.sm0.irq_clr)
        if self.sm1 is not None and self.sm1.irq_set is not None:
            self.irq |= 1 << self.sm1.irq_set
        if self.sm1 is not None and self.sm1.irq_clr is not None:
            self.irq &= ~(1 << self.sm1.irq_clr)
        if self.cap_en:
            pins = driven | (self.uio_in & ~oe)
            if pins != self.last_pins or self.delta == 255:
                self.capture.append((self.delta, pins, oe))
                self.last_pins = pins
                self.delta = 0
            else:
                self.delta += 1
        return resolved, oe

    def replay_pins(self) -> list[int]:
        return [p for _, p, _ in self.capture]
