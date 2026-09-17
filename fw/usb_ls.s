; USB LS bit-layer TX. Host pushes encode_packet() PINOE words.
; D-=pin0 D+=pin1. side_pin=7 so PULL does not smash D+.
; EOP and HiZ live in the FIFO stream, not a SET delay.
set     side_pin, 7
pull    block
out     pinoe, 16
jmp     pull
