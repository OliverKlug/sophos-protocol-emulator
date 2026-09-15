; UART frame RX. WAIT idle, WAIT start, centre, JMP PIN runt, 8 IN, stop check.
set     in_base, 0
wait    1 pin 0          ; idle high (break / bad stop)
wait    0 pin 0          ; start; delay to centre is in the encoding
jmp     pin, start       ; runt if already high
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
jmp     pin, push        ; stop must be 1
jmp     idle
push    block
jmp     idle
