(* Exhaustive encode/decode bijection. Same claim as sim/sat_decode.py. *)

let () =
  for word = 0 to 65535 do
    let op, side, delay, payload = Isa.decode word in
    let rebuilt = Isa.encode op payload delay side in
    if rebuilt <> word then
      failwith (Printf.sprintf "round-trip %04x -> %04x" word rebuilt);
    if op > 7 || delay > 15 || side > 1 then
      failwith "field range"
  done;
  for op = 0 to 7 do
    for delay = 0 to 15 do
      for side = 0 to 1 do
        for payload = 0 to 255 do
          let w = Isa.encode op payload delay side in
          let op', side', delay', payload' = Isa.decode w in
          if (op', side', delay', payload') <> (op, side, delay, payload) then
            failwith "encode mismatch"
        done
      done
    done
  done;
  print_endline "OCaml SAT-on-decode: 65536-word bijection OK"
