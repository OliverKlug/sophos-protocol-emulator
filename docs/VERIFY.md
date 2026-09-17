# How to verify

From the repo root. Fail closed: if a command is missing, that layer did not run.

```
./sim/check.sh
```

That is the only script GHA `test.yaml` runs (Python + Icarus UART TX/RX, SPI MISO, JTAG IDCODE, USB LS, UART/SPI/JEDEC capture-replay, three-proto host-load, lockstep). OCaml and SBY run when `dune` / `sby` are on `PATH`.

| Layer | Command | Pass signal |
|---|---|---|
| Python golden + SAT + protocol matrix | `python3 sim/test_all.py` | prints `golden+SAT: ... OK` |
| RTL UART TX + peek PC | `vvp test/tb_uart.vvp` | `PASS UART TX 0x55` and `PASS peek PC` |
| RTL UART RX peek-10 | `vvp test/tb_uart_rx.vvp` | `PASS UART RX peek-10` |
| RTL SPI MISO | `vvp test/tb_spi.vvp` | `PASS SPI MISO` |
| RTL JTAG IDCODE | `vvp test/tb_jtag.vvp` | `PASS JTAG IDCODE` |
| RTL USB LS bit-layer TX | `vvp test/tb_usb.vvp` | `PASS USB LS` (ACK + DATA0 0xFF/0x00) |
| RTL UART capture | `vvp test/tb_cap.vvp` | `PASS UART CAP`, `PASS CAP dump`, `PASS CAP timed replay` |
| RTL SPI capture replay | `vvp test/tb_spi_cap.vvp` | `PASS SPI CAP replay` (edge mode) |
| RTL JEDEC capture | `vvp test/tb_jedec_cap.vvp` | `PASS JEDEC CAP` |
| RTL three proto host-load | `vvp test/tb_three_proto.vvp` | `PASS three proto host-load` |
| SM lockstep | `python3 sim/lockstep.py` then `vvp test/tb_sm_lockstep.vvp` | `PASS lockstep cases=…` |
| OCaml SAT | `cd ocaml && dune exec ./sat_decode.exe` | `OCaml SAT-on-decode: 65536-word bijection OK` |
| OCaml UART golden | `cd ocaml && dune exec ./uart_tx.exe` | `OCaml UART TX 0x55 on pin0 OK` |
| SBY field split | `cd formal && sby -f decode.sby` | `SBY+... DONE (PASS, rc=0)` |
| SBY opcode step | `cd formal && sby -f step.sby` | `DONE (PASS, rc=0)` |
| Generic synth | `yosys -s sim/synth.ys` | elaborates; no `sram_flop`; cell count is not STA |
| GHA GDS | `gds.yaml` `@ihp-cmos5l` | job green; do not commit `runs/` |
| GHA precheck | same workflow | job green (ignore viewer Pages 404) |
| GHA GLS | `gl_test` / `test.test_uart_0x55` | `TESTS=1 PASS=1 FAIL=0` |
| Signoff STA | `GDS_logs` `55-openroad-stapostpnr/summary.rpt` + `final/metrics.json` | 25 ns, setup/hold vio count 0 |

OCaml env on this machine:

```
eval "$(opam env --switch=ocaml-base-compiler.5.3.0)"
```

Hardcaml is not installed and will not own the SM. SBY here is the field-split identity, not NuSMV. The 65536-word bijection in Python and OCaml is the decode proof that can actually fail if `encode` and `decode` drift.

No FT232, physical W25Q, OpenOCD, FPGA bitstream, FPGA HID, CAN/ETH, or local LibreLane command is listed because none of those have been run. Those are named skips, not silent holes. STA numbers come from the GHA `GDS_logs` artifact, not from a PDK on this machine. USB LS is bit-layer TX on the Phase 5 die (Icarus RTL), not GLS and not a device.
