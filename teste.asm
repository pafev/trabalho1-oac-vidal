.data
            128
0xf
dados:  .word 4147483649, -2,       
     0x10000010
dados2: .word 4,
 5, 6

.text
add $t2,             $t2, $s0
or $s0, $s0, $t4
sltu $v0,           $zero, $a1
mult $t1 $t2
mfhi     $s0
jr $ra
jalr $s0

label: sllv $s0,     $s4, $s3
srav $s3, $a1, $a2
mul $t1, $t3, $t7


clo $v0, $v1
            clz $a1,          $a2
sll $t1, $t1, 2
label2: srl $t5, $a3, 31
addi $t2, $t2, 32
label3:
lw $t2, 100   ($a0)
sb $v1      ,          0x12     ($t3)

lui $t2 8
j label
j label2
jal label3
.data
    dados3:
    .word 32
,4322, 0x0313
