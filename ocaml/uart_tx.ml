(* UART-shaped golden for the ops the TX program actually uses.
   Week-1 fallback: a character leaves pin0 in OCaml, not Cyclesim. *)

type sm = {
  mutable pc : int;
  mutable osr : int;
  mutable pin_out : int;
  mutable pin_oe : int;
  tx : int Queue.t;
}

let uart_program =
  [|
    Isa.sett 0 1 ();
    Isa.sett 3 1 ();
    Isa.pull ~block:true ();
    Isa.sett 0 0 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.out 0 1 ();
    Isa.sett 0 1 ();
    Isa.jmp 2 ();
  |]

let step sm =
  let word = uart_program.(sm.pc) in
  let op, _side, _delay, pay = Isa.decode word in
  match op with
  | 0 -> sm.pc <- pay land 31
  | 3 ->
      sm.pin_out <- (sm.pin_out land lnot 1) lor (sm.osr land 1);
      sm.osr <- sm.osr lsr 1;
      sm.pc <- sm.pc + 1
  | 4 ->
      if Queue.is_empty sm.tx then ()
      else (
        sm.osr <- Queue.take sm.tx;
        sm.pc <- sm.pc + 1)
  | 7 ->
      let dest = (pay lsr 5) land 7 in
      let imm = pay land 31 in
      if dest = 0 then sm.pin_out <- (sm.pin_out land lnot 0x1f) lor imm
      else if dest = 3 then sm.pin_oe <- (sm.pin_oe land lnot 0x1f) lor imm;
      sm.pc <- sm.pc + 1
  | _ -> failwith "uart golden: unexpected op"

let hunt pins byte =
  let want = Array.make 10 0 in
  want.(0) <- 0;
  for i = 0 to 7 do
    want.(i + 1) <- (byte lsr i) land 1
  done;
  want.(9) <- 1;
  let rec find i =
    if i + 9 >= Array.length pins then false
    else if
      let rec eq k =
        k = 10 || (pins.(i + k) = want.(k) && eq (k + 1))
      in
      eq 0
    then true
    else find (i + 1)
  in
  find 0

let () =
  let sm =
    { pc = 0; osr = 0; pin_out = 0; pin_oe = 0; tx = Queue.create () }
  in
  Queue.add 0x55 sm.tx;
  let pins = Array.make 48 0 in
  for i = 0 to 47 do
    step sm;
    pins.(i) <- sm.pin_out land 1
  done;
  if not (hunt pins 0x55) then failwith "OCaml UART TX 0x55 not on pin0";
  if sm.pin_oe land 1 <> 1 then failwith "OCaml UART did not assert OE";
  print_endline "OCaml UART TX 0x55 on pin0 OK"
