# Status

As of 2026-09-18. One SHA, one die. Do not re-harden this chip unless `src/` or `info.yaml` `top_module` changes.

## Closed die

- Product: Sophos. Repo: [OliverKlug/sophos-protocol-emulator](https://github.com/OliverKlug/sophos-protocol-emulator) (public, Apache-2.0).
- SHA: `691c728`. Top: `tt_um_klug_sophos`. Tiles: `6x4`. Clock: 25 ns / 40 MHz.
- GHA [run 35215850540](https://github.com/OliverKlug/sophos-protocol-emulator/actions/runs/35215850540): `gds` 1h20m green, `precheck` 55m green, `gl_test` 47s green (`test.test_uart_0x55`, `TESTS=1`, not idle). Artifact `tt_submission` is on that run.
- STA from that run `GDS_logs` `55-openroad-stapostpnr/summary.rpt` + `final/metrics.json`: setup/hold vio count 0. Slow setup WS **+0.79 ns**. Overall hold WS **+0.13 ns**. Post-P&R stdcells **11624**, util **22.2%**.
- On the die: one SM (`PROTOEMU_SM1=0`), 32×16 flop IMEM, 32-slot capture `{pin, oe, hold}`. No IHP SRAM.

The workflow badge is red because `viewer` died in 12s. Silicon jobs are green. Pages is a human skip (see below). That is not a GDS fail.

Previous die, history only: `8e4ef83` / `tt_um_klug_protoemu`, 16-slot capture, run 35023276762, slow setup +0.50 ns, hold +0.11 ns, 8284 stdcells, 15.5% util. Not the January binary.

## What was run

Local `./sim/check.sh`: Python golden + SAT, Icarus UART TX/RX, SPI MISO, JTAG IDCODE, USB LS, UART/SPI/JEDEC capture, three-proto host-load, lockstep. OCaml SAT and SBY decode+step when `dune` / `sby` are on `PATH`. GHA `test.yaml` is check.sh without those two.

UART `0x55` is 12 capture records. SCLK-mode JEDEC `0x9F` is 32 samples, ID `EF 40 16`. USB LS is host-encoded bit-layer TX on this die (Icarus), not GLS.

Anish 2026-09-15: stay on 6×4 until they mail a CMOS5L 8×4 DEF. Copy: `docs/EMAIL_8x4.md`.

## Skip list (write once)

- Viewer / GitHub Pages: Settings → Pages → Source = **GitHub Actions** on `OliverKlug/sophos-protocol-emulator`. The action still prints `OliverKlug/protoemu/settings/pages`. Optional. Not silicon.
- FPGA (`fpga.yaml` `branches: none`).
- SDF GLS. SPI / I2C / USB / JEDEC in `test.py`. GLS is UART 0x55 + halt + peek-6==12 + pin/oe dump, `TESTS=1`.
- Two SMs on this GDS. Hardcaml / Amaranth SM. Verilator protocol twin.
- `dune` / `sby` on GHA `test.yaml` (local only).
- FT232, physical W25Q, OpenOCD. USB device / HID / FS / HS / hub 500 ppm. CAN / ETH / FAULT.
- IHP SRAM (CMOS5L has no TopMetal2). 8×4 CMOS5L DEF. Local LibreLane.

Contest submit: form is not on the Jane Street page yet. Kit: `docs/SUBMIT.md`. Criteria map: `docs/CRITERIA.md`.
