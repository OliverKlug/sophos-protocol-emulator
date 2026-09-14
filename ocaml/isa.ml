(* Shared 16-bit field split. Must match sim/isa.py and src/sm.v. *)

let encode op payload delay side =
  if op < 0 || op > 7 then failwith "op";
  if delay < 0 || delay > 15 then failwith "delay";
  if side <> 0 && side <> 1 then failwith "side";
  ((op land 7) lsl 13)
  lor ((side land 1) lsl 12)
  lor ((delay land 15) lsl 8)
  lor (payload land 0xff)

let decode word =
  let w = word land 0xffff in
  ( (w lsr 13) land 7,
    (w lsr 12) land 1,
    (w lsr 8) land 15,
    w land 0xff )

let jmp addr ?(cond = 0) ?(delay = 0) ?(side = 0) () =
  if addr < 0 || addr > 31 then failwith "jmp addr 0..31";
  encode 0 (((cond land 7) lsl 5) lor (addr land 31)) delay side

let out dest count ?(delay = 0) ?(side = 0) () =
  let c = if count = 16 then 0 else count in
  encode 3 (((dest land 7) lsl 5) lor (c land 31)) delay side

let pull ?(block = true) ?(iff = false) ?(delay = 0) ?(side = 0) () =
  let pay =
    (1 lsl 7)
    lor ((if iff then 1 else 0) lsl 6)
    lor ((if block then 1 else 0) lsl 5)
  in
  encode 4 pay delay side

let sett dest imm ?(delay = 0) ?(side = 0) () =
  encode 7 (((dest land 7) lsl 5) lor (imm land 31)) delay side
