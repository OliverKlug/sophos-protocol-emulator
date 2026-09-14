To: asic-competition@janestreet.com
Subject: CMOS5L 8x4 tile — no DEF in tt-support-tools

Hi Ben, Anish,

The contest post says set `tiles` to 8x4. On the CMOS5L flow that actually hardens (`tt-gds-action@ihp-cmos5l` → `tt-support-tools` branch `ihp-sg13cmos5l`), `tech/ihp-sg13cmos5l/tile_sizes.yaml` has no 8x4 key and there is no `tt_block_8x4_pgvdd.def`. Height-4 DEFs stop at 6x4; the 8-wide floorplan is 8x2. The 1724.16 x 710.64 µm 8x4 entry is on `ihp-sg13g2` `main`, which is the other PDK.

Please confirm you will add an 8x4 CMOS5L DEF, or tell us to floorplan 6x4 / 8x2 until you do.

We are designing to 8x4 from the blog until you say otherwise.

Thanks,
Oliver
