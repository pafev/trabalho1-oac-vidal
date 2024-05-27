.data
a: .word 1, 2, 3

.text
li $t0, 0x10010000
lw $t1, 0($t0)
lw $t2, 4($t0)
lw $t3, 8($t0)
clo $t1, $t2
add $t1, $t2, $t3
xor $t4, $t1, $t2
Label: addi $t5, $t4, 10
xori $t6, $t5, 20
sw $t4, 0($t0)
sw $t5, 4($t0)
sw $t6, 8($t0)
lb $t1, 100($t2)
movn $t1, $t2, $t3
mul $t1, $t2, $t6
teq $t1, $t1
