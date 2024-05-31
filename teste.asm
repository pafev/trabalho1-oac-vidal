.data
            128
0xf
dados:  .word 4147483649, -2,       
     0x10000010
dados2: .word 4,
 5, 6

.text

li    $t0, 0x10010000
lw   $t1, 0( $t0  )
label:    lw $t2, 4($t0)
la $s0, dados


lw $t3, 8($t0)
.data
    dados3:
    .word 32
,4322, 0x0313
