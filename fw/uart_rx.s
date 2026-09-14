; UART RX. Wait falling start, eight IN, push.
; IN shifts left, so FIFO byte is bit-reversed vs LSB-first UART. Host reverses.
set     in_base, 0
wait    0 pin 0
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
in      pins, 1
push    block
jmp     wait
