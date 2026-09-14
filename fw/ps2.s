; PS/2: wait CLK fall, sample DATA.
set     in_base, 0
wait    0 pin 1
in      pins, 1
set     x, 9
wait    0 pin 1
in      pins, 1
jmp     x--, $-2
push    block
jmp     wait
