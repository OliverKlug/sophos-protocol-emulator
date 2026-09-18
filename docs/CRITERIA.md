# Contest criteria

Maps the [Jane Street protocol-emulator ASIC brief](https://blog.janestreet.com/protocol-emulator-asic-competition/) onto this repo. Closed die: SHA `691c728`, top `tt_um_klug_sophos`, 6×4, 25 ns. Ledger: `docs/STATUS.md`. ISA formal is not a protocol waveform on RTL.

Nothing here has run on a pin or an FPGA.

## Brief → this repo

| Criterion | What this repo has | Status |
|---|---|---|
| Open-source general-purpose protocol emulator | 16-bit pin/wait/delay/shift/fifo/jump/mov ISA. Protocols are `fw/*` words loaded after tapeout. Apache-2.0, public `OliverKlug/sophos-protocol-emulator`. | Yes |
| Not a UART+SPI+I2C block trio | Host nibble IMEM write + FIFO + run (`docs/HOST.md`). Same engine, new words, no resynth. | Yes |
| Start with UART, SPI, I2C | UART TX 0x55 and frame RX; SPI modes 0–3 + JEDEC MISO `EF 40 16`; I2C OD START/ACK/stretch/Sr. Icarus + golden. | Yes |
| Stretch: low-speed USB | Host `encode_packet()` NRZI+stuff+CRC-16/USB+EOP. SM is four words. Icarus `PASS USB LS`. Not a device, not HID, not FS, PHY off-chip. | Partial — bit-layer TX |
| Stretch: 10 Mbit Ethernet | Not built. | Skip |
| Also named: JTAG, SWD, PS/2, CAN | JTAG IDCODE vs TAP `0x1234ABCD` (`PASS JTAG IDCODE`). SWD/PS2 are unlabeled pin-dances. CAN not built. | Partial — JTAG yes; SWD/PS2 dance; CAN skip |
| Unique function | 32-slot capture `{pin,oe,hold}`, dump peeks 11–14, SCLK-mode JEDEC, timed replay. Same signed die. | Yes |
| FPGA smoke | `fpga.yaml` `branches: none`. | Skip |
| Formal methods | SAT 65536-word encode/decode (Python + OCaml). SBY `formal/decode.sby` + `formal/step.sby`. Lockstep 8×8×32. Not a UART waveform proof on RTL. | Yes — ISA, not protocols |
| Constrained random | 200 random IMEM words + pin noise; UART baud ±0/2/5% and jitter. | Yes — golden / Icarus |
| CMOS5L template, `tiles: "6x4"` | `info.yaml`, `@ihp-cmos5l` / `ihp-sg13cmos5l`. Anish: stay on 6×4. | Yes |
| Full P&R + timing | Run 35215850540: 25 ns, vio 0, slow setup +0.79 ns, hold +0.13 ns, 11624 stdcells, 22.2% util. | Yes |
| Gate-level protocol | `gl_test` is UART 0x55 + capture dump, `TESTS=1`. Not idle. Not SPI/USB. | Partial — UART+dump |
| Sign-up / submit by 2027-01-18 | Sign-up mailed. Submit form not on the page. Kit: `docs/SUBMIT.md`. | Open — their form |

## What the firmware does / does not

| Protocol | Does | Does not |
|---|---|---|
| UART | 8N1 TX `0x55` on `uio[0]`; frame RX peek-10; GLS same vector + 12-record dump | FT232 on a desk |
| SPI | Modes 0–3 MOSI; JEDEC `0x9F` MISO `EF 40 16`; SCLK-mode capture of the 32 clocks | Physical W25Q |
| I2C | OD via OE, START, ACK, stretch, repeated START, NAK→STOP | Multi-master, 7-bit addressing as a stack |
| JTAG | IDCODE vs a TAP model | OpenOCD, IR-only cartoons as the claim |
| SWD / PS/2 | Words assemble | DPIDR, keyboard host |
| USB LS | SYNC+NRZI+stuff+EOP+CRC-16/USB on D−/D+ | Device, HID, FS/HS, analog PHY, hub 500 ppm |
| CAN / ETH | — | Not in tree |

Capture is not a protocol. It is the RE instrument: edge mode (pin/OE change) or SCLK rise while CS low. Hold saturates at 255. Replay restores inclusive holds onto `uio`.
