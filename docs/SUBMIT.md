# Submit kit

Product work is over. This file is what a later agent opens after context loss.

## Freeze

- Netlist freeze: SHA `691c728` (`tt_um_klug_sophos`). GDS / precheck / `gl_test` / STA: [run 35215850540](https://github.com/OliverKlug/sophos-protocol-emulator/actions/runs/35215850540). Artifact: `tt_submission` (GDS/OAS/LEF/GL/stats).
- Docs-only commits after this file change the git SHA. That is fine if `src/` and `info.yaml` `top_module` / `tiles` / `source_files` do not change. The routed netlist stays `691c728`. A `src/` or top-name edit needs a new GDS and a new freeze line here.
- Public URL: https://github.com/OliverKlug/sophos-protocol-emulator
- License: Apache-2.0. Tiles: `6x4`. Clock: 40 MHz STA.

## Jane Street

Sign-up already sent (`asic-competition@janestreet.com`, `docs/EMAIL_8x4.md`). The [contest page](https://blog.janestreet.com/protocol-emulator-asic-competition/) still says they will add the final form closer to 18 January 2027. There is nothing to click today.

When the form appears: repo URL, SHA of the docs freeze (or `691c728` if that is still HEAD), writeup `docs/WRITEUP.md`, criteria `docs/CRITERIA.md`. Mail that address only if the form is up and broken. Hardcaml and FPGA are not required (Advent 2025).

## Tiny Tapeout shuttle (not the Jane Street click)

Later, if they pay a coupon: https://app.tinytapeout.com/projects/create → paste the GitHub URL → **Submit a new revision**. Needs green `gds` + `precheck`. Docs action is for the datasheet, not the shuttle reject. Viewer/Pages is optional.

## Pages (human, optional)

Settings → Pages → Source = **GitHub Actions** on `OliverKlug/sophos-protocol-emulator`. Then re-run `gds.yaml` `viewer` or wait for the next push. The action may still print `OliverKlug/protoemu/settings/pages`. A red `viewer` job is not a silicon fail. Do not re-harden to fix it.

## Stop list

No RTL. No IHP SRAM. No SM1 on. No IMEM below or above 32. No 8×4 unless they mail a CMOS5L DEF. No CAN/ETH cartoons. No Hardcaml SM. No new GDS unless `src/` or the TT top changes. No treating a red workflow badge as a failed die.
