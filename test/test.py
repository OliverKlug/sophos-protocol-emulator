# SPDX-License-Identifier: Apache-2.0
# GL / cocotb vector is UART TX 0x55, not reset-idle.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

UART_WORDS = [
    0xE001,
    0xE061,
    0x80A0,
    0xE000,
    0x6001,
    0x6001,
    0x6001,
    0x6001,
    0x6001,
    0x6001,
    0x6001,
    0x6001,
    0xE001,
    0x0002,
]


async def host(dut, cmd: int, nib: int) -> None:
    await FallingEdge(dut.clk)
    dut.ui_in.value = (cmd << 4) | (nib & 0xF)
    await FallingEdge(dut.clk)
    dut.ui_in.value = (1 << 7) | (cmd << 4) | (nib & 0xF)
    await FallingEdge(dut.clk)
    dut.ui_in.value = (cmd << 4) | (nib & 0xF)


async def shift16(dut, word: int) -> None:
    await host(dut, 0, (word >> 12) & 0xF)
    await host(dut, 0, (word >> 8) & 0xF)
    await host(dut, 0, (word >> 4) & 0xF)
    await host(dut, 0, word & 0xF)


@cocotb.test()
async def test_uart_0x55(dut):
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0xFF
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    await shift16(dut, 0)
    await host(dut, 2, 0)
    for w in UART_WORDS:
        await shift16(dut, w)
        await host(dut, 1, 0)
    await shift16(dut, 0x0055)
    await host(dut, 3, 0)
    await host(dut, 5, 0b0001)

    bits = []
    for _ in range(40):
        await ClockCycles(dut.clk, 1)
        bits.append(int(dut.uio_out.value) & 1)
    frame = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1]
    found = any(bits[i : i + 10] == frame for i in range(len(bits) - 9))
    assert found, f"UART 0x55 not in uio[0] {bits}"
