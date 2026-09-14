# OCaml fallback (not Hardcaml)

Week-1 named path after Cyclesim missed: Verilog SM stays the RTL. This directory is the OCaml golden for the 16-bit field split and the UART TX ops.

```
eval "$(opam env --switch=ocaml-base-compiler.5.3.0)"
dune exec ./sat_decode.exe
dune exec ./uart_tx.exe
```

`uart_tx.ml` implements SET / PULL / OUT / JMP only. It is not a second SM. `sim/golden.py` is the full model.
