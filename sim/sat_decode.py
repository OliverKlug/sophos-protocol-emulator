"""SAT-on-decode: encode/decode is a bijection on the 16-bit word.

A one-hot loop over bits[15:13] is a tautology. This file proves the
field split we claimed: op, side, delay, payload pack and unpack.
"""

from __future__ import annotations

from isa import OP_NAMES, decode_fields, encode


def prove_decode() -> None:
    for word in range(65536):
        f = decode_fields(word)
        rebuilt = encode(f["op"], f["payload"], f["delay"], f["side"])
        if rebuilt != word:
            raise AssertionError(
                f"round-trip {word:#06x} -> {f} -> {rebuilt:#06x}"
            )
        if f["op"] > 7 or f["delay"] > 15 or f["side"] > 1:
            raise AssertionError(f"field range {word:#06x} {f}")

    counts = [0] * 8
    for op in range(8):
        for delay in range(16):
            for side in range(2):
                for payload in range(256):
                    w = encode(op, payload, delay, side)
                    f = decode_fields(w)
                    if f != {"op": op, "side": side, "delay": delay, "payload": payload}:
                        raise AssertionError(f"encode mismatch {f}")
                    counts[op] += 1
    for i, n in enumerate(counts):
        if n != 8192:
            raise AssertionError(f"{OP_NAMES[i]} occupancy {n}")


if __name__ == "__main__":
    prove_decode()
    print("SAT-on-decode: 65536-word encode/decode bijection OK")
