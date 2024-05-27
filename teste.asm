.data
dados:
        .word 1   ,  2, 3
            dados2: .word   4 , 5, 6
.text

li    $t0, 0x10010000
lw   $t1, 0($t0)
    lw $t2, 4($t0)


lw $t3, 8($t0)
