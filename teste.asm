.data
            128
0xf
dados:  .word 4147483649, -2,       
     0x10000010
dados2: .word 4,
 5, 6

.text
add $t2, $t2, $s0
or $s0, $s0, $t4
sltu $v0, $zero, $a1
.data
    dados3:
    .word 32
,4322, 0x0313
