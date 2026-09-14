# How to verify

From the repo root. Fail closed: if a command is missing, that layer did not run.

```
./sim/check.sh
```

That is the only script GHA runs (Python + Icarus). OCaml and SBY run when `dune` / `sby` are on `PATH`.

| Layer | Command | Pass signal |
|---|---|---|
| Python golden + SAT + protocol matrix | `python3 sim/test_all.py` | prints `golden+SAT: ... OK` |
| RTL UART + peek | `iverilog` + `vvp test/tb_uart.vvp` | `PASS UART TX 0x55` and `PASS peek PC` |
| OCaml SAT | `cd ocaml && dune exec ./sat_decode.exe` | `OCaml SAT-on-decode: 65536-word bijection OK` |
| OCaml UART golden | `cd ocaml && dune exec ./uart_tx.exe` | `OCaml UART TX 0x55 on pin0 OK` |
| SBY field split | `cd formal && sby -f decode.sby` | `SBY+... DONE (PASS, rc=0)` |
| Generic synth | `yosys -s sim/synth.ys` | elaborates; cell count is not STA |

OCaml env on this machine:

```
eval "$(opam env --switch=ocaml-base-compiler.5.3.0)"
```

Hardcaml is not installed and will not own the SM. SBY here is the field-split identity, not NuSMV. The 65536-word bijection in Python and OCaml is the decode proof that can actually fail if `encode` and `decode` drift.

No FT232, W25Q, or LibreLane command is listed because none of those have been run.
