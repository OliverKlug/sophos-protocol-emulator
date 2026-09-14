; UART TX 8n1 LSB-first. Idle high before OE.
set     pins, 1
set     pindirs, 1
pull    block
set     pins, 0
out     pins, 1
out     pins, 1
out     pins, 1
out     pins, 1
out     pins, 1
out     pins, 1
out     pins, 1
out     pins, 1
set     pins, 1
jmp     pull
