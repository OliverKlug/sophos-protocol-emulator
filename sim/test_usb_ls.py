"""USB LS encoder/decoder. Destuff-by-delete, PID, CRC16, not a length check."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sim"))
sys.path.insert(0, str(ROOT / "fw"))

from golden import Core  # noqa: E402
from usb_ls_decode import SE0, decode_symbols, destuff_nrzi, downsample, pid_ok  # noqa: E402
import usb_ls  # noqa: E402

BIT_TICKS = 3  # PULL + OUT + JMP at clkdiv 1


def test_crc_vectors() -> None:
    if usb_ls.crc16_usb(b"\x00\x01\x02\x03") != 0x7AEF:
        raise AssertionError("CRC16 USB-IF 00 01 02 03")
    if usb_ls.crc16_usb(b"\xFF") != 0xFF00:
        raise AssertionError("CRC16 FF swapped?")
    if usb_ls.crc16_usb(b"\x00") != 0xBF40:
        raise AssertionError("CRC16 00")
    if usb_ls.crc16_usb(b"") != 0:
        raise AssertionError("CRC16 empty")
    crc = usb_ls.crc16_usb(b"\xFF")
    blob = b"\xFF" + bytes([crc & 0xFF, crc >> 8])
    # residue is the no-xorout remainder; 0xB001 == spec 0x800D reflected
    residue = usb_ls.crc16_usb(blob) ^ 0xFFFF
    if residue != 0xB001:
        raise AssertionError(f"residue {residue:#x} != 0xB001")
    if (crc & 0xFF, crc >> 8) == (0xFF, 0x00):
        raise AssertionError("CRC bytes FF 00 are swapped")


def test_stuff_before_eop() -> None:
    s = usb_ls.stuff([1] * 6)
    if s != [1, 1, 1, 1, 1, 1, 0]:
        raise AssertionError(f"stuff-before-EOP {s}")


def test_pid_check() -> None:
    if not pid_ok(usb_ls.ACK):
        raise AssertionError("ACK PID")
    if pid_ok(0xD3):
        raise AssertionError("FAIL USB LS PID should reject D3")


def _body_from_words(words: list[int]) -> list[int]:
    symbols = []
    for w in words:
        oe = (w >> 8) & 0xFF
        val = w & 0xFF
        if (oe & 3) == 0:
            break
        symbols.append(val & 3)
    return decode_symbols(symbols)


def test_encoder_packets() -> None:
    ack = _body_from_words(usb_ls.encode_packet(usb_ls.ACK))
    if ack != [0x80, 0xD2]:
        raise AssertionError(f"ACK {ack}")
    dff = _body_from_words(usb_ls.encode_packet(usb_ls.DATA0, b"\xFF"))
    if dff != [0x80, 0xC3, 0xFF, 0x00, 0xFF]:
        raise AssertionError(f"DATA0+FF {dff} (CRC swapped?)")
    d00 = _body_from_words(usb_ls.encode_packet(usb_ls.DATA0, b"\x00"))
    if d00 != [0x80, 0xC3, 0x00, 0x40, 0xBF]:
        raise AssertionError(f"DATA0+00 {d00}")
    empty = _body_from_words(usb_ls.encode_packet(usb_ls.DATA0, b""))
    if empty != [0x80, 0xC3, 0x00, 0x00]:
        raise AssertionError(f"empty DATA0 {empty}")


def test_destuff_delete() -> None:
    words = usb_ls.encode_packet(usb_ls.DATA0, b"\xFF")
    symbols = [w & 3 for w in words if (w >> 8) & 3]
    nrz, _ = destuff_nrzi(symbols)
    if len(nrz) != 40:
        raise AssertionError(f"destuff len {len(nrz)}")
    stuffed = []
    prev = 0b01
    for st in symbols:
        if st == SE0:
            break
        bit = 0 if st != prev else 1
        prev = st
        stuffed.append(bit)
    if stuffed == nrz:
        raise AssertionError("stuffed 0 was not present to delete")
    if len(stuffed) <= len(nrz):
        raise AssertionError("destuff did not drop bits")


def test_nak_forbidden() -> None:
    try:
        usb_ls.encode_packet(0x5A)
    except ValueError:
        return
    raise AssertionError("NAK must not encode")


def run_sm(pid: int, payload: bytes | None) -> list[int]:
    prog = usb_ls.program()
    if len(prog) > 32:
        raise AssertionError(f"usb_ls {len(prog)} > 32")
    words = usb_ls.encode_packet(pid, payload)
    c = Core()
    c.uio_in = J_IDLE
    c.load(prog)
    nxt = 0

    def feed() -> None:
        nonlocal nxt
        while len(c.sm0.tx) < 4 and nxt < len(words):
            c.sm0.tx.append(words[nxt])
            nxt += 1

    feed()
    c.start0 = True
    trace: list[tuple[int, int]] = []
    extra = 0
    for _ in range(len(words) * BIT_TICKS + 16):
        feed()
        if nxt < len(words) and len(c.sm0.tx) == 0:
            raise AssertionError("PULL stall mid-packet")
        res, oe = c.step()
        trace.append((res & 3, oe & 3))
        if nxt >= len(words) and (oe & 3) == 0:
            extra += 1
            if extra > BIT_TICKS:
                break
    symbols = downsample(trace, BIT_TICKS)
    return decode_symbols(symbols)


J_IDLE = 0x01


def test_sm_packets() -> None:
    if run_sm(usb_ls.ACK, None) != [0x80, 0xD2]:
        raise AssertionError("SM ACK")
    if run_sm(usb_ls.DATA0, b"\xFF") != [0x80, 0xC3, 0xFF, 0x00, 0xFF]:
        raise AssertionError("SM DATA0+FF")
    if run_sm(usb_ls.DATA0, b"\x00") != [0x80, 0xC3, 0x00, 0x40, 0xBF]:
        raise AssertionError("SM DATA0+00")


def main() -> None:
    test_crc_vectors()
    test_stuff_before_eop()
    test_pid_check()
    test_encoder_packets()
    test_destuff_delete()
    test_nak_forbidden()
    test_sm_packets()
    print("USB LS SYNC+NRZI+stuff+EOP OK")


if __name__ == "__main__":
    main()
