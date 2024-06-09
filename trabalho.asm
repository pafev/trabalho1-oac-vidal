.data
filepath: .space 50
output_filepath: .space 55
asm_content: .space 1024
asm_data_content: .space 512
asm_text_content: .space 512
mif_data_content: .space 768
mif_text_content: .space 768
label_buffer: .space 20
mif_addr_buffer: .space 9  # formato: "00000000"
mif_value_buffer: .space 9  # formato: "00000000"
mif_line_buffer: .space 22  # formato: "00000000 : 00000000;"
data_labels: .space 128  # formato "label:${addr};label2:${addr + 4x};-"
text_labels: .space 128  # formato "label:${addr};label2:${addr + 4x};-"
dec_asciiz_buffer: .space 11
hex_asciiz_buffer: .space 9
register_buffer: .space 5
instruction_buffer: .space 5

.text
.globl main

main:
    la $a0, asm_content  # ponteiro para o buffer que irá armazenar o conteudo do arq de entrada
    jal get_input_file

    la $a0, asm_content  # ponteiro para o conteudo do arquivo .asm
    jal format_content

    la $a0, asm_content  # ponteiro para o conteudo normalizado do arquivo .asm
    jal split_asm_content

    la $a0, asm_data_content  # ponteiro do .data do arquivo .asm
    jal encode_data_asm

    move $a0, $v0  # tamanho do mif_data_content
    jal generate_data_mif

    la $a0, asm_text_content  # ponteiro do .text do arquivo .asm
    jal encode_text_asm

    move $a0, $v0  # tamanho do mif_text_content
    jal generate_text_mif

    jal end


## Funcoes Auxiliares


## Entrada: $a0: ponteiro para o buffer contendo asciiz, entrada na conversao
## Saida:   $v0: saida com valor em word convertido
convert_hex_asciiz_to_word:
    move $t1, $zero  # acumulador em word
    convert_hex_asciiz_to_word_loop:
        lb $t0, 0($a0)
        beq $t0, $zero, end_convert_hex_asciiz_to_word
        addi $a0, $a0, 1
        blt $t0, 48, error_conversion_hex_asciiz
        bgt $t0, 57, read_upper_alpha_digit_hex
        sub $t0, $t0, '0'
        j convert_digit_hex
        read_upper_alpha_digit_hex:
        blt $t0, 65, error_conversion_hex_asciiz
        bgt $t0, 70, read_lower_alpha_digit_hex
        sub $t0, $t0, 'A'
        addi $t0, $t0, 10
        j convert_digit_hex
        read_lower_alpha_digit_hex:
        blt $t0, 97, error_conversion_hex_asciiz
        bgt $t0, 102, error_conversion_hex_asciiz
        sub $t0, $t0, 'a'
        addi $t0, $t0, 10
        convert_digit_hex:
        sll $t1, $t1, 4
        add $t1, $t1, $t0
        j convert_hex_asciiz_to_word_loop
    end_convert_hex_asciiz_to_word:
    move $v0, $t1
    jr $ra


## Entrada: nada, pois utilizará no dec_asciiz_buffer como entrada
## Saida:   $v0: word com o valor convertido
convert_dec_asciiz_to_word:
    move $t1, $zero  # indice do dec_asciiz_buffer
    move $t2, $zero  # acumulador da word
    move $t7, $zero  # flag de negativo
    # verifica se o asciiz em representacao dec eh negativo
    lb $t0, dec_asciiz_buffer($t1)
    beq $t0, '-', is_dec_asciiz_negative  # se eh negativo, seta flag de negativo
    j convert_dec_asciiz_to_word_loop
    is_dec_asciiz_negative:
    li $t7, 1
    addi $t1, $t1, 1
    convert_dec_asciiz_to_word_loop:
        lb $t0, dec_asciiz_buffer($t1)
        beq $t0, $zero, end_convert_dec_asciiz_to_word
        addi $t1, $t1, 1
        sub $t0, $t0, '0'
        mul $t2, $t2, 10
        add $t2, $t2, $t0
        j convert_dec_asciiz_to_word_loop
    end_convert_dec_asciiz_to_word:
    beq $t7, $zero, skip_negate_word
    sub $t2, $zero, $t2  # nega a conversao se a entrada eh negativa
    skip_negate_word:
    move $v0, $t2
    jr $ra


## Entrada: $a0: tamanho de char's do resultado
##          $a1: ponteiro para o buffer a ser preenchido com o resultado
##          Utiliza o que está em dec_asciiz_buffer como entrada da conversao
## Saida: nada, pois o próprio buffer passado é alterado
convert_dec_asciiz_to_hex_asciiz:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # inicializacoes
    move $t1, $zero  # indice do dec_asciiz_buffer
    move $t2, $zero  # acumulador da word
    move $t7, $zero  # flag de negativo
    # verifica se o asciiz representado em dec é negativo
    lb $t3, dec_asciiz_buffer($t1)
    beq $t3, '-', is_negative_intermediary
    j convert_dec_asciiz_to_word_intermediary
    # se negativo, seta uma flag para o convert_word_to_hex_asciiz
    is_negative_intermediary:
    li $t7, 1
    addi $t1, $t1, 1
    # primeiro converte para inteiro .word
    convert_dec_asciiz_to_word_intermediary:
        lb $t3, dec_asciiz_buffer($t1)  # pega o char do int asciiz
        bne $t3, $zero, skip_end_dec_asciiz  # se não terminou de converter em word
        move $a3, $a1
        move $a1, $t2
        move $a2, $t7
        jal convert_word_to_hex_asciiz
        j end_convert_dec_asciiz_to_hex_asciiz
        skip_end_dec_asciiz:
        sub $t3, $t3, '0'  # converte o byte do char para seus bits em representação numérica
        mul $t2, $t2, 10  # multiplica o acumulador decimal por 10
        add $t2, $t2, $t3  # acrescenta o byte convertido ao acumulador do valor decimal
        addi $t1, $t1, 1  # incremeta para iterar para o proximo char do inteiro asciiz
        j convert_dec_asciiz_to_word_intermediary
    # fim da conversao :)
    end_convert_dec_asciiz_to_hex_asciiz:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: $a0: tamanho de char's do resultado
##          $a1: word a ser convertida para asciiz, com representacao hex
##          $a2: flag de negativo
##          $a3: ponteiro para o buffer a ser preenchido com o resultado
## Saida: nada, pois o próprio buffer passado é alterado
convert_word_to_hex_asciiz:
    beq $a2, $zero, skip_negate_word_intermediary  # se o inteiro é negativo, nega os bits dele
    sub $a1, $zero, $a1
    # se é positivo, segue normal
    skip_negate_word_intermediary:
    move $t1, $a1  # valor decimal em t1
    move $t2, $zero  # contador de dígitos para o valor em hexadecimal asciiz
    # conta os bytes necessarios para a representacao de hexadecimal em asciiz
    count_digits_hex_asciiz:
        beq $t1, $zero, calculate_lsb_digit_hex_asciiz
        srl $t1, $t1, 4
        addi $t2, $t2, 1
        j count_digits_hex_asciiz
    # calcula por onde começa a preencher o hex_asciiz_buffer
    calculate_lsb_digit_hex_asciiz:
        sub $t2, $a0, $t2
        # se foi pedido menos bytes do que o necessário para representação em asciiz
        blt $t2, $zero, internal_error_bits_conversion
        add $a0, $a0, $a3
        add $t2, $t2, $a3
        move $t0, $a0
    # comeca a converter cada 4 bits do valor inteiro para o byte correspondente
    convert_digits_hex_asciiz:
        beq $t0, $t2, fill_with_zeros
        addi $t0, $t0, -1
        andi $t3, $a1, 0xF
        blt $t3, 10, is_num_hex_asciiz
        addi $t3, $t3, 87
        j store_char_in_buffer
        is_num_hex_asciiz:
        addi $t3, $t3, 48
        # aqui preencho o hex_asciiz_buffer com o char convertido
        store_char_in_buffer:
            sb $t3, 0($t0)
            srl $a1, $a1, 4
            j convert_digits_hex_asciiz
        # preencho com zeros a esquerda
    fill_with_zeros:
        beq $t0, $a3, end_convert_word_to_hex_asciiz
        addi $t0, $t0, -1
        li $t3, 48
        sb $t3, 0($t0)
        j fill_with_zeros
    # fim da conversao :)
    end_convert_word_to_hex_asciiz:
    sb $zero, 0($a0)
    jr $ra


## Entrada: nada, pois a string do registrador estara em register_buffer
## Saida: $v0: os 5 bits que representam a string passada como registrador
get_register_word:
    la $t1, register_buffer
    lb $t0, 0($t1)
        blt $t0, 48, skip_check_register_number
        bgt $t0, 57, skip_check_register_number
        sub $t0, $t0, '0'
        add $t2, $zero, $t0
        lb $t0, 1($t1)
        bne $t0, $zero, skip_end_register_number
        move $v0, $t2
        j end_get_register_word
    skip_end_register_number:
        blt $t0, 48, error_register_syntax
        bgt $t0, 57, error_register_syntax
        sub $t0, $t0, '0'
        mul $t2, $t2, 10
        add $t2, $t2, $t0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        blt $t2, $zero, error_register_syntax
        bgt $t2, 31, error_register_syntax
        move $v0, $t2
        j end_get_register_word
    skip_check_register_number:
        bne $t0, 'z', skip_check_register_zero
        lb $t0, 1($t1)
        bne $t0, 'e', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, 'r', error_register_syntax
        lb $t0, 3($t1)
        bne $t0, 'o', error_register_syntax
        lb $t0, 4($t1)
        bne $t0, $zero, error_register_syntax
        move $v0, $zero
        j end_get_register_word
    skip_check_register_zero:
        bne $t0, 'v', skip_check_register_v
        lb $t0, 1($t1)
        bne $t0, '0', skip_check_register_v0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 2
        j end_get_register_word
    skip_check_register_v0:
        bne $t0, '1', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 3
        j end_get_register_word
    skip_check_register_v:
        bne $t0, 'a', skip_check_register_a
        lb $t0, 1($t1)
        bne $t0, 't', skip_check_register_at
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 1
        j end_get_register_word
    skip_check_register_at:
        bne $t0, '0', skip_check_register_a0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 4
        j end_get_register_word
    skip_check_register_a0:
        bne $t0, '1', skip_check_register_a1
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 5
        j end_get_register_word
    skip_check_register_a1:
        bne $t0, '2', skip_check_register_a2
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 6
        j end_get_register_word
    skip_check_register_a2:
        bne $t0, '3', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 7
        j end_get_register_word
    skip_check_register_a:
        bne $t0, 't', skip_check_register_t
        lb $t0, 1($t1)
        bne $t0, '0', skip_check_register_t0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 8
        j end_get_register_word
    skip_check_register_t0:
        bne $t0, '1', skip_check_register_t1
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 9
        j end_get_register_word
    skip_check_register_t1:
        bne $t0, '2', skip_check_register_t2
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 10
        j end_get_register_word
    skip_check_register_t2:
        bne $t0, '3', skip_check_register_t3
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 11
        j end_get_register_word
    skip_check_register_t3:
        bne $t0, '4', skip_check_register_t4
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 12
        j end_get_register_word
    skip_check_register_t4:
        bne $t0, '5', skip_check_register_t5
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 13
        j end_get_register_word
    skip_check_register_t5:
        bne $t0, '6', skip_check_register_t6
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 14
        j end_get_register_word
    skip_check_register_t6:
        bne $t0, '7', skip_check_register_t7
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 15
        j end_get_register_word
    skip_check_register_t7:
        bne $t0, '8', skip_check_register_t8
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 24
        j end_get_register_word
    skip_check_register_t8:
        bne $t0, '9', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 25
        j end_get_register_word
    skip_check_register_t:
        bne $t0, 's', skip_check_register_s
        lb $t0, 1($t1)
        bne $t0, '0', skip_check_register_s0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 16
        j end_get_register_word
    skip_check_register_s0:
        bne $t0, '1', skip_check_register_s1
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 17
        j end_get_register_word
    skip_check_register_s1:
        bne $t0, '2', skip_check_register_s2
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 18
        j end_get_register_word
    skip_check_register_s2:
        bne $t0, '3', skip_check_register_s3
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 19
        j end_get_register_word
    skip_check_register_s3:
        bne $t0, '4', skip_check_register_s4
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 20
        j end_get_register_word
    skip_check_register_s4:
        bne $t0, '5', skip_check_register_s5
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 21
        j end_get_register_word
    skip_check_register_s5:
        bne $t0, '6', skip_check_register_s6
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 22
        j end_get_register_word
    skip_check_register_s6:
        bne $t0, '7', skip_check_register_s7
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 23
        j end_get_register_word
    skip_check_register_s7:
        bne $t0, 'p', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 29
        j end_get_register_word
    skip_check_register_s:
        bne $t0, 'k', skip_check_register_k
        lb $t0, 1($t1)
        bne $t0, '0', skip_check_register_k0
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 26
        j end_get_register_word
    skip_check_register_k0:
        bne $t0, '1', error_register_syntax
        lb $t0, 2($t1)
        bne $t0, $zero, error_register_syntax
        li $v0, 27
        j end_get_register_word
    skip_check_register_k:
        bne $t0, 'g', skip_check_register_gp
        lb $t0, 1($t1)
        bne $t0, 'p', error_register_syntax
        li $v0, 28
        j end_get_register_word
    skip_check_register_gp:
        bne $t0, 'f', skip_check_register_fp
        lb $t0, 1($t1)
        bne $t0, 'p', error_register_syntax
        li $v0, 30
        j end_get_register_word
    skip_check_register_fp:
        bne $t0, 'r', error_register_syntax
        lb $t0, 1($t1)
        bne $t0, 'a', error_register_syntax
        li $v0, 31
        j end_get_register_word
    end_get_register_word:
    jr $ra


## Entrada: $a0: ponteiro ao conjunto de labels em que sera buscada a label que esta em label_buffer
## Saida:   $v0: flag de existencia da label (se 1, label existe no conjunto passado. Se 0, nao)
##          $v1: endereco da label, se encontrada
get_label_addr:
    move $t2, $a0  # indice do conjunto de labels
    move $v0, $zero  # flag de existencia da label
    move $v1, $zero  # endereco da label
    start_checks_equality_labels:
        move $t3, $zero  # indice do label_buffer
        checks_equality_labels:
            lb $t0, 0($t2)
            addi $t2, $t2, 1
            lb $t1, label_buffer($t3)
            addi $t3, $t3, 1
            beq $t0, '-', end_get_label_addr
            bne $t0, ':', skip_end_checks_equality_labels
            bne $t1, $zero, skip_label_in_labels
            li $v0, 1
            j end_checks_equality_labels
            skip_end_checks_equality_labels:
            beq $t0, $t1, checks_equality_labels
    skip_label_in_labels:
        lb $t0, 0($t2)
        addi $t2, $t2, 1
        beq $t0, ';', start_checks_equality_labels
        j skip_label_in_labels
    end_checks_equality_labels:
        move $t0, $zero
        lb $t0, 0($t2)
        addu $v1, $v1, $t0
        lb $t0, 1($t2)
        sll $t0, $t0, 8
        addu $v1, $v1, $t0
        lb $t0, 2($t2)
        sll $t0, $t0, 16
        addu $v1, $v1, $t0
        lb $t0, 3($t2)
        sll $t0, $t0, 24
        addu $v1, $v1, $t0
    end_get_label_addr:
        jr $ra


## Entrada: $a0: conjunto de instrucoes em que ira checar o pertencimento do que esta em instruction_buffer
## Saida: $v0: flag de pertencimento (se 1, pertence a esse conjunto de instrucoes. Se 0, nao pertence)
##        $v1: posicao do ';' apos a instrucao igual a passada, caso pertenca ao grupo
belongs_to_instruction_set:
    move $t2, $a0  # indice do conjunto de instrucoes
    move $t7, $zero  # flag de pertencimento ao conjunto
    start_checks_equality_instructions:
        move $t3, $zero  # indice do instruction_buffer
        checks_equality_instructions:
            lb $t0, 0($t2)
            addi $t2, $t2, 1
            lb $t1, instruction_buffer($t3)
            addi $t3, $t3, 1
            beq $t0, $zero, end_belongs_to_instruction_set
            bne $t0, ';', skip_end_checks_equality_instructions
            bne $t1, $zero, start_checks_equality_instructions
            li $t7, 1
            j end_belongs_to_instruction_set
            skip_end_checks_equality_instructions:
            beq $t0,, $t1, checks_equality_instructions
    skip_instruction_in_instruction_set:
        lb $t0, 0($t2)
        addi $t2, $t2, 1
        beq $t0, ';', start_checks_equality_instructions
        j skip_instruction_in_instruction_set
    end_belongs_to_instruction_set:
        move $v0, $t7
        sub $v1, $t2, $a0
        jr $ra


## Entrada: $a0: valor em word do endereço da label no .asm (multiplo de 4)
##          utiliza o nome da label em label_buffer
## Saida: nada, pois o próprio valor de data_labels é alterado
save_data_label:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $a1, $a0  # valor do endereço em word
    li $a0, 4
    move $a2, $zero
    la $a3, hex_asciiz_buffer  # irá receber o valor do endereço em asciiz, representando hexadecimal
    jal convert_word_to_hex_asciiz
    move $t2, $zero
    search_end_data_labels:
        lb $t0, data_labels($t2)
        beq $t0, $zero, append_data_labels
        addi $t2, $t2, 1
        j search_end_data_labels
    append_data_labels:
    move $t1, $zero
    append_label_in_data_labels:
        lb $t0, label_buffer($t1)
        beq $t0, $zero, append_separator_in_data_labels
        addi $t1, $t1, 1
        sb $t0, data_labels($t2)
        addi $t2, $t2, 1
        j append_label_in_data_labels
    append_separator_in_data_labels:
        li $t0, 58
        sb $t0, data_labels($t2)
        addi $t2, $t2, 1
    move $t1, $zero
    append_addr_in_data_labels:
        lb $t0, hex_asciiz_buffer($t1)
        beq $t0, $zero, end_save_data_label
        addi $t1, $t1, 1
        sb $t0, data_labels($t2)
        addi $t2, $t2, 1
        j append_addr_in_data_labels    
    end_save_data_label:
        li $t0, 59
        sb $t0, data_labels($t2)
        addi $t2, $t2, 1
        sb $zero, data_labels($t2)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: $a0: valor em word do endereco da text label no .asm (0x004XXXXX e multiplo de 4)
##          Utiliza o nome da label em label_buffer
## Saida: Nada, pois o próprio text_labels eh alterado
save_text_label:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $t1, $zero  # indice de onde comecar a acrescentar a nova label em text_label
    search_end_text_labels:  # procura final do text_labels, para entao fazer o append
        lb $t0, text_labels($t1)
        beq $t0, '-', append_text_labels
        addi $t1, $t1, 1
        j search_end_text_labels
    append_text_labels:
    move $t2, $zero  # indice do label_buffer
    append_label_in_text_labels:
        lb $t0, label_buffer($t2)
        beq $t0, $zero, append_separator_in_text_labels
        addi $t2, $t2, 1
        sb $t0, text_labels($t1)
        addi $t1, $t1, 1
        j append_label_in_text_labels
    append_separator_in_text_labels:
        li $t0, 58
        sb $t0, text_labels($t1)
        addi $t1, $t1, 1
    append_addr_in_text_labels:
        sb $a0, text_labels($t1)
        addi $t1, $t1, 1
        srl $a0, $a0, 8
        sb $a0, text_labels($t1)
        addi $t1, $t1, 1
        srl $a0, $a0, 8
        sb $a0, text_labels($t1)
        addi $t1, $t1, 1
        srl $a0, $a0 8
        sb $a0, text_labels($t1)
        addi $t1, $t1, 1
    li $t0, 59
    sb $t0, text_labels($t1)
    addi $t1, $t1, 1
    li $t0, 45
    sb $t0, text_labels($t1)
    addi $t1, $t1, 1
    sb $zero, text_labels($t1)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: nada, pois o próprio asm_text_content é examinado
## Saida:   nada, pois os próprios asm_text_content e text_labels são alterados
extract_text_labels:
    addi $sp, $sp, -20
    sw $s3, 16($sp)
    sw $s2, 12($sp)
    sw $s1, 8($sp)
    sw $s0, 4($sp)
    sw $ra, 0($sp)
    # prepara text_labels (pradonizada finalizar com '-')
    li $t0, 45
    sb $t0, text_labels($zero)
    # comeca extracao
    move $s0, $zero  # indice do asm_text_content antigo
    li $s1, 0x400000  # endereco da linha
    move $s2, $zero  # indice do asm_text_content novo
    examines_text_label_in_line:
        move $s3, $s0
        move $t2, $zero
        sb $zero, label_buffer($zero)
        examines_text_label_in_line_loop:
            lb $t0, asm_text_content($s3)
            addi $s3, $s3, 1
            beq $t0, $zero, update_text_line_without_label
            beq $t0, '\n', update_text_line_without_label
            beq $t0, ':', save_text_label_for_asm
            sb $t0, label_buffer($t2)
            addi $t2, $t2, 1
            j examines_text_label_in_line_loop
    update_text_line_without_label:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        sb $t0, asm_text_content($s2)
        addi $s2, $s2, 1
        beq $t0, $zero, end_examines_text_label_in_line
        bne $t0, '\n', update_text_line_without_label
        addi $s1, $s1, 4
        j examines_text_label_in_line
    save_text_label_for_asm:
        sb $zero, label_buffer($t2)
        move $a0, $s1
        jal save_text_label
        lb $t0, asm_text_content($s3)
        bne $t0, '\n', skip_check_end_line
        addi $s0, $s3, 1
        j examines_text_label_in_line
        skip_check_end_line:
        move $s0, $s3
        j update_text_line_without_label
    end_examines_text_label_in_line:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra


## Funcoes Principais


## Entrada: nada
## Saida: $v0: tamanho do mif_data_content
encode_data_asm:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $s0, $zero  # indice do asm_data_content
    move $s1, $zero  # indice do mif_data_content
    move $s2, $zero  # valor do endereço asm
    move $s3, $zero  # valor do endereço mif
    start_identifying_label:
        move $t1, $zero  # indice do label_buffer
        li $t6, 1  # flag de começo de label
    identifying_label:  # identificando label que está iterando
        lb $t0, asm_data_content($s0)  # pega byte do conteudo asm
        beq $t6, $zero, isnt_number_first_char  # é o primeiro char da label?
        blt $t0, 48, isnt_number_first_char  # se é o primeiro char, verificar se ele é um numero
        bgt $t0, 57, isnt_number_first_char
        j identifying_data_value
        isnt_number_first_char:
        addi $s0, $s0, 1  # incrementa para dps pegar o prox byte
        move $t6, $zero  # zera flag de começo de label
        beq $t0, '\n', error_syntax  # se tem uma quebra de linha no meio da label, é problema
        beq $t0, $zero, error_syntax
        beq $t0, ':', save_label_for_asm  # se é o fim da label, temos que gravar ela pro mips
        sb $t0, label_buffer($t1)
        addi $t1, $t1, 1
        j identifying_label
    save_label_for_asm:
        sb $zero, label_buffer($t1)
        move $a0, $s2  # valor do endereço asm
        jal save_data_label
        sb $zero, label_buffer($zero)
    identifying_data_type:
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, '\n', skip_check_nl_after_label
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        skip_check_nl_after_label:
        bne $t0, '.', error_data_type
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, 'w', error_data_type
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, 'o', error_data_type
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, 'r', error_data_type
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, 'd', error_data_type
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        bne $t0, ' ', error_data_type
        j identifying_data_value
    identifying_data_value:
        lb $t0, asm_data_content($s0)
        beq $t0, $zero, end_encode_data_asm
        beq $t0, '-', start_decimal_data_value
        blt $t0, 48, start_identifying_label
        bgt $t0, 57, start_identifying_label
        bne $t0, '0', start_decimal_data_value
        addi $s0, $s0, 1
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        beq $t0, 'x', hex_data_value
        addi $s0, $s0, -1
        j start_decimal_data_value
    start_decimal_data_value:
        move $t1, $zero  # indice do dec_asciiz_buffer
        li $t6, 1  # flag de começo de valor
    decimal_data_value:
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        blt $t0, 48, isnt_num_decimal_data_value  # se é um número, continua para guardar no int_asciiz_bufer iterativamente
        bgt $t0, 57, error_syntax
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j decimal_data_value
    isnt_num_decimal_data_value:
        beq $t0, $zero, end_decimal_data_value
        beq $t0, ' ', end_decimal_data_value
        beq $t0, '\n', end_decimal_data_value
        bne $t0, '-', error_syntax
        beq $t6, $zero, error_syntax
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j decimal_data_value
    end_decimal_data_value:
        # -- pega o que tá no dec_asciiz_buffer e converte para hexa asciiz
        sb $zero, dec_asciiz_buffer($t1)
        li $a0, 8
        la $a1, mif_value_buffer
        jal convert_dec_asciiz_to_hex_asciiz  # preenchi o mif_value_buffer
        # -- pega o endereço do data do mif e converte para hexa asciiz
        li $a0, 8
        move $a1, $s3
        move $a2, $zero
        la $a3, mif_addr_buffer
        jal convert_word_to_hex_asciiz  # preenchi o mif_addr_buffer
        # -- escreve uma linha no mif_data_content
        la $a0, mif_data_content
        move $a1, $s1
        jal generate_mif_line
        # -- zera buffers
        sb $zero, mif_value_buffer($zero)
        sb $zero, mif_addr_buffer($zero) 
        # -- atualiza indices dos mif_data_content e asm_data_content
        move $s1, $v0
        addi $s2, $s2, 4  # atualizou endereço do data do asm
        addi $s3, $s3, 1  # atualizou endereço do data do mif
        j identifying_data_value
    hex_data_value:
        move $t1, $s0
        count_digits_hex_data_value:
            lb $t0, asm_data_content($t1)
            beq $t0, $zero, end_count_digits_hex_data_value
            beq $t0, ' ', end_count_digits_hex_data_value
            beq $t0, '\n', end_count_digits_hex_data_value
            blt $t0, 48, error_syntax
            beq $t0, 'a', valid_digit_hex_data_value
            beq $t0, 'b', valid_digit_hex_data_value
            beq $t0, 'c', valid_digit_hex_data_value
            beq $t0, 'd', valid_digit_hex_data_value
            beq $t0, 'e', valid_digit_hex_data_value
            beq $t0, 'f', valid_digit_hex_data_value
            bgt $t0, 57, error_syntax
            valid_digit_hex_data_value:
            addi $t1, $t1, 1
            j count_digits_hex_data_value
        end_count_digits_hex_data_value:
            sub $t1, $t1, $s0
            li $t2, 8
            sub $t1, $t2, $t1  # calcula primeiro indice a preencher com hex data value
            bltz $t1, internal_error_bits_conversion
            move $t2, $t1  # calcula até onde preencher com zeros a esquerda
        store_hex_data_value:
            beq $t1, 8, fill_zeros_hex_mif_value
            lb $t0, asm_data_content($s0)
            addi $s0, $s0, 1
            sb $t0, mif_value_buffer($t1)
            addi $t1, $t1, 1
            j store_hex_data_value
        fill_zeros_hex_mif_value:
            beq $t2, $zero, end_hex_data_value
            addi $t2, $t2, -1
            li $t0, 48
            sb $t0, mif_value_buffer($t2)
            j fill_zeros_hex_mif_value
        end_hex_data_value:
            li $t1, 8
            sb $zero, mif_value_buffer($t1)  # finalizei de preencher o mif_value_buffer
            # -- pega o endereço do data do mif e converte para hexa asciiz
            li $a0, 8
            move $a1, $s3
            move $a2, $zero
            la $a3, mif_addr_buffer
            jal convert_word_to_hex_asciiz  # preenchi o mif_addr_buffer
             # -- escreve uma linha no mif_data_content
            la $a0, mif_data_content
            move $a1, $s1
            jal generate_mif_line
            # -- zera buffers
            sb $zero, mif_value_buffer($zero)
            sb $zero, mif_addr_buffer($zero) 
            # -- atualiza indices dos mif_data_content e asm_data_content
            addi $s0, $s0, 1
            move $s1, $v0
            addi $s2, $s2, 4  # atualizou endereço do data do asm
            addi $s3, $s3, 1  # atualizou endereço do data do mif
            j identifying_data_value
    end_encode_data_asm:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    move $v0, $s1
    jr $ra


## Entrada: Nada
## Saida: $v0: tamanho do mif_text_content
encode_text_asm:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal extract_text_labels

    move $s0, $zero  # indice do asm_text_content
    move $s1, $zero  # endereco do mif
    move $s2, $zero  # valor do mif
    move $s3, $zero  # indice do mif_text_content
    start_search_for_text_instruction:
        li $t7, 1  # flag de comeco de linha
        move $t1, $zero  # indice do instruction_buffer
        sb $zero, instruction_buffer($zero)  # zerando buffer da instrucao
    search_for_text_instruction:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t7, $zero, skip_check_first_char_text_instruction
        beq $t0, $zero, end_encode_text_asm
        beq $t0, '\n', start_search_for_text_instruction
        skip_check_first_char_text_instruction:
        move $t7, $zero
        beq $t0, $zero, error_syntax
        beq $t0, '\n', error_syntax
        beq $t0, ' ', process_text_instruction
        sb $t0, instruction_buffer($t1)
        addi $t1, $t1, 1
        j search_for_text_instruction
    process_text_instruction:
        sb $zero, instruction_buffer($t1)
        # identifica qual a instrucao que sera lida e faz o encode apropriado
        la $a0, instructions_arithlog
        jal belongs_to_instruction_set
        beq $v0, 1, encode_arithlog_instruction
        
        la $a0, instructions_divmult
        jal belongs_to_instruction_set
        beq $v0, 1, encode_divmult_instruction
        
        la $a0, instructions_move_from
        jal belongs_to_instruction_set
        beq $v0, 1, encode_move_from_instruction
        
        la $a0, instructions_jump_r
        jal belongs_to_instruction_set
        beq $v0, 1, encode_jump_r_instruction
        
        la $a0, instructions_jump_alr
        jal belongs_to_instruction_set
        beq $v0, 1, encode_jump_alr_instruction
        
        la $a0, instructions_shift
        jal belongs_to_instruction_set
        beq $v0, 1, encode_shift_instruction
        
        la $a0, instructions_shift_v
        jal belongs_to_instruction_set
        beq $v0, 1, encode_shift_v_instruction
        
        la $a0, instructions_cl
        jal belongs_to_instruction_set
        beq $v0, 1, encode_cl_instruction
        
        la $a0, instructions_arithlog_i
        jal belongs_to_instruction_set
        beq $v0, 1, encode_arithlog_i_instruction
        
        la $a0, instructions_branch_z
        jal belongs_to_instruction_set
        beq $v0, 1, encode_branch_z_instruction

        la $a0, instructions_load_store
        jal belongs_to_instruction_set
        beq $v0, 1, encode_load_store_instruction

        la $a0, instructions_branch
        jal belongs_to_instruction_set
        beq $v0, 1, encode_branch_instruction

        la $a0, instructions_load_i
        jal belongs_to_instruction_set
        beq $v0, 1, encode_load_i_instruction

        la $a0, instructions_jump
        jal belongs_to_instruction_set
        beq $v0, 1, encode_jump_instruction

        j error_unknown_opcode    
    end_encode_instruction:
        # preenchendo mif_addr_buffer com o que ha em s1
        li $a0, 8
        move $a1, $s1
        move $a2, $zero
        la $a3, mif_addr_buffer
        jal convert_word_to_hex_asciiz
        # preenchendo mif_value_buffer com o que ha em s2
        li $a0, 8
        move $a1, $s2
        move $a2, $zero
        la $a3, mif_value_buffer
        jal convert_word_to_hex_asciiz
        # gerando a linha no mif_text_content
        la $a0, mif_text_content
        move $a1, $s3
        jal generate_mif_line
        # atualizando indice/tamanho do mif_text_content
        addi $s3, $s3, 21
        # verifica se ja acabou o .text
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, $zero, end_encode_text_asm
        bne $t0, '\n', error_syntax
        # atualiza o endereco da linha do .text
        addi $s1, $s1, 1
        # zera o s2 para a montagem da prox instrucao
        move $s2, $zero
        j start_search_for_text_instruction
    end_encode_text_asm:
    move $v0, $s3
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Montagem das instrucoes ArithLog
encode_arithlog_instruction:
    beq $v1, 4, get_add_function
    beq $v1, 8, get_sub_function
    beq $v1, 12, get_and_function
    beq $v1, 15, get_or_function
    beq $v1, 19, get_nor_function
    beq $v1, 23, get_xor_function
    beq $v1, 27, get_slt_function
    beq $v1, 32, get_addu_function
    beq $v1, 37, get_subu_function
    beq $v1, 42, get_movn_function
    beq $v1, 47, get_sltu_function
    beq $v1, 51, get_mul_function
    get_add_function:
        addiu $s2, $s2, 32
        j start_get_d_register_arithlog
    get_sub_function:
        addiu $s2, $s2, 34
        j start_get_d_register_arithlog
    get_and_function:
        addiu $s2, $s2, 36
        j start_get_d_register_arithlog
    get_or_function:
        addiu $s2, $s2, 37
        j start_get_d_register_arithlog
    get_nor_function:
        addiu $s2, $s2, 39
        j start_get_d_register_arithlog
    get_xor_function:
        addiu $s2, $s2, 38
        j start_get_d_register_arithlog
    get_slt_function:
        addiu $s2, $s2, 42
        j start_get_d_register_arithlog
    get_addu_function:
        addiu $s2, $s2, 33
        j start_get_d_register_arithlog
    get_subu_function:
        addiu $s2, $s2, 35
        j start_get_d_register_arithlog
    get_movn_function:
        addiu $s2, $s2, 11
        j start_get_d_register_arithlog
    get_sltu_function:
        addiu $s2, $s2, 43
        j start_get_d_register_arithlog
    get_mul_function:
        addiu $s2, $s2, 1879048194
    start_get_d_register_arithlog:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_d_register_arithlog:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_d_register_arithlog
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_d_register_arithlog
    save_d_register_arithlog:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 11
        addu $s2, $s2, $v0
    start_get_s_register_arithlog:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_s_register_arithlog:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_s_register_arithlog
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_arithlog
    save_s_register_arithlog:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
    start_get_t_register_arithlog:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_t_register_arithlog:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_t_register_arithlog
        beq $t0, '\n', save_t_register_arithlog
        beq $t0, ' ', save_t_register_arithlog
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_arithlog
    save_t_register_arithlog:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
        j end_encode_instruction

encode_divmult_instruction:
    beq $v1, 4, get_div_function
    beq $v1, 9, get_mult_function
    get_div_function:
        addiu $s2, $s2, 26
        j start_get_s_register_divmult
    get_mult_function:
        addiu $s2, $s2, 24
    start_get_s_register_divmult:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_s_register_divmult:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_s_register_divmult
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_divmult
    save_s_register_divmult:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
    start_get_t_register_divmult:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_t_register_divmult:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_t_register_divmult
        beq $t0, '\n', save_t_register_divmult
        beq $t0, ' ', save_t_register_divmult
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_divmult
    save_t_register_divmult:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_move_from_instruction:
    beq $v1, 5, get_mfhi_function
    beq $v1, 10, get_mflo_function
    get_mfhi_function:
        addiu $s2, $s2, 16
        j start_get_d_register_movefrom
    get_mflo_function:
        addiu $s2, $s2, 18
    start_get_d_register_movefrom:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        bne $t0, '$', error_unknown_instruction
        move $t1, $zero
        sb $zero, register_buffer($zero)
    get_d_register_movefrom:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_d_register_movefrom
        beq $t0, '\n', save_d_register_movefrom
        beq $t0, ' ', save_d_register_movefrom
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_d_register_movefrom
    save_d_register_movefrom:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 11
        addu $s2, $s2, $v0
        j end_encode_instruction

encode_jump_r_instruction:
    addiu $s2, $s2, 8
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_s_register_jumpr:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_s_register_jumpr
        beq $t0, '\n', save_s_register_jumpr
        beq $t0, ' ', save_s_register_jumpr
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_jumpr
    save_s_register_jumpr:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_jump_alr_instruction:
    addiu $s2, $s2, 63497
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_s_register_jumpalr:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_s_register_jumpalr
        beq $t0, '\n', save_s_register_jumpalr
        beq $t0, ' ', save_s_register_jumpalr
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_jumpalr
    save_s_register_jumpalr:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_shift_instruction:
    beq $v1, 4, start_get_d_register_shift
    beq $v1, 8, get_srl_function
    beq $v1, 12, get_sra_function
    get_srl_function:
        addiu $s2, $s2, 2
        j start_get_d_register_shift
    get_sra_function:
        addiu $s2, $s2, 3
    start_get_d_register_shift:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_d_register_shift:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_d_register_shift
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_d_register_shift
    save_d_register_shift:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 11
        addu $s2, $s2, $v0
    start_get_t_register_shift:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_t_register_shift:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_t_register_shift
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_shift
    save_t_register_shift:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
    start_get_a_shift:
    move $t1, $zero  # indice do dec_asciiz_buffer
    sb $zero, dec_asciiz_buffer($zero)
    get_a_shift:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_a_shift
        beq $t0, '\n', save_a_shift
        beq $t0, ' ', save_a_shift
        addi $s0, $s0, 1
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_a_shift
    save_a_shift:
        sb $zero, dec_asciiz_buffer($t1)
        jal convert_dec_asciiz_to_word
        bgt $v0, 31, internal_error_bits_conversion
        sll $v0, $v0, 6
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_shift_v_instruction:
    beq $v1, 5, get_sllv_function
    beq $v1, 10, get_srav_function
    get_sllv_function:
        addiu $s2, $s2, 4
        j start_get_d_register_shiftv
    get_srav_function:
        addiu $s2, $s2, 7
    start_get_d_register_shiftv:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        bne $t0, '$', error_unknown_instruction
        move $t1, $zero
        sb $zero, register_buffer($zero)
    get_d_register_shiftv:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_d_register_shiftv
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_d_register_shiftv
    save_d_register_shiftv:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 11
        addu $s2, $s2, $v0
    start_get_t_register_shiftv:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_t_register_shiftv:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_t_register_shiftv
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_shiftv
    save_t_register_shiftv:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
    start_get_s_register_shiftv:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_s_register_shiftv:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_s_register_shiftv
        beq $t0, '\n', save_s_register_shiftv
        beq $t0, ' ', save_s_register_shiftv
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_shiftv
    save_s_register_shiftv:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_cl_instruction:
    beq $v1, 4, get_clo_function
    beq $v1, 8, get_clz_function
    get_clo_function:
        addiu $s2, $s2, 1879048225
        j start_get_d_register_cl
    get_clz_function:
        addiu $s2, $s2, 1879048224
    start_get_d_register_cl:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_d_register_cl:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_d_register_cl
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_d_register_cl
    save_d_register_cl:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 11
        addu $s2, $s2, $v0
    start_get_s_register_cl:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_s_register_cl:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_s_register_cl
        beq $t0, '\n', save_s_register_cl
        beq $t0, ' ', save_s_register_cl
        addi $s0, $s0, 1
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_cl
    save_s_register_cl:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_arithlog_i_instruction:
    beq $v1, 5, get_addi_opcode
    beq $v1, 10, get_andi_opcode
    beq $v1, 14, get_ori_opcode
    beq $v1, 19, get_xori_opcode
    beq $v1, 25, get_addiu_opcode
    beq $v1, 30, get_slti_opcode
    get_addi_opcode:
        addiu $s2, $s2, 0x20000000
        j start_get_t_register_arithlog_i
    get_andi_opcode:
        addiu $s2, $s2, 0x30000000
        j start_get_t_register_arithlog_i
    get_ori_opcode:
        addiu $s2, $s2, 0x34000000
        j start_get_t_register_arithlog_i
    get_xori_opcode:
        addiu $s2, $s2, 0x38000000
        j start_get_t_register_arithlog_i
    get_addiu_opcode:
        addiu $s2, $s2, 0x24000000
        j start_get_t_register_arithlog_i
    get_slti_opcode:
        addiu $s2, $s2, 0x28000000
    start_get_t_register_arithlog_i:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_t_register_arithlog_i:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_t_register_arithlog_i
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_arithlog_i
    save_t_register_arithlog_i:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
    start_get_s_register_arithlog_i:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_s_register_arithlog_i:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_s_register_arithlog_i
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_arithlog_i
    save_s_register_arithlog_i:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
    start_get_i_arithlog_i:
    move $t1, $zero  # indice do buffer que vai armazenar i
    lb $t0, asm_text_content($s0)
    bne $t0, '0', start_get_i_dec_arithlog_i
    addi $s0, $s0, 1
    lb $t0, asm_text_content($s0)
    bne $t0, 'x', start_get_i_dec_arithlog_i
    addi $s0, $s0, 1
    j start_get_i_hex_arithlog_i
    start_get_i_dec_arithlog_i:
    sb $zero, dec_asciiz_buffer($zero)
    get_i_dec_arithlog_i:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_i_dec_arithlog_i
        beq $t0, '\n', save_i_dec_arithlog_i
        beq $t0, ' ', save_i_dec_arithlog_i
        addi $s0, $s0, 1
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_dec_arithlog_i
    save_i_dec_arithlog_i:
        sb $zero, dec_asciiz_buffer($t1)
        jal convert_dec_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
        j end_encode_instruction
    start_get_i_hex_arithlog_i:
    sb $zero, hex_asciiz_buffer($zero)
    get_i_hex_arithlog_i:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_i_hex_arithlog_i
        beq $t0, '\n', save_i_hex_arithlog_i
        beq $t0, ' ', save_i_hex_arithlog_i
        addi $s0, $s0, 1
        sb $t0, hex_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_hex_arithlog_i
    save_i_hex_arithlog_i:
        sb $zero, hex_asciiz_buffer($t1)
        la $a0, hex_asciiz_buffer
        jal convert_hex_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_branch_z_instruction:

encode_load_store_instruction:
    beq $v1, 3, get_lw_opcode
    beq $v1, 6, get_sw_opcode
    beq $v1, 9, get_lb_opcode
    beq $v1, 12, get_sb_opcode
    beq $v1, 16, get_lhu_opcode
    get_lw_opcode:
        addiu $s2, $s2, 0x8c000000
        j start_get_t_register_loadstore
    get_sw_opcode:
        addiu $s2, $s2, 0xac000000
        j start_get_t_register_loadstore
    get_lb_opcode:
        addiu $s2, $s2, 0x80000000
        j start_get_t_register_loadstore
    get_sb_opcode:
        addiu $s2, $s2, 0xa0000000
        j start_get_t_register_loadstore
    get_lhu_opcode:
        addiu $s2, $s2, 0x94000000
    start_get_t_register_loadstore:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_t_register_loadstore:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_t_register_loadstore
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_loadstore
    save_t_register_loadstore:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
    start_get_i_loadstore:
    move $t1, $zero  # indice do buffer que vai armazenar i
    lb $t0, asm_text_content($s0)
    bne $t0, '0', start_get_i_dec_loadstore
    addi $s0, $s0, 1
    lb $t0, asm_text_content($s0)
    bne $t0, 'x', start_get_i_dec_loadstore
    addi $s0, $s0, 1
    j start_get_i_hex_loadstore
    start_get_i_dec_loadstore:
    sb $zero, dec_asciiz_buffer($zero)
    get_i_dec_loadstore:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, '(', save_i_dec_loadstore
        blt $t0, 48, error_syntax
        bgt $t0, 57, error_syntax
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_dec_loadstore
    save_i_dec_loadstore:
        sb $zero, dec_asciiz_buffer($t1)
        jal convert_dec_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
        j start_get_s_register_loadstore
    start_get_i_hex_loadstore:
    sb $zero, hex_asciiz_buffer($zero)
    get_i_hex_loadstore:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, '(', save_i_hex_loadstore
        blt $t0, 48, error_syntax
        sb $t0, hex_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_hex_loadstore
    save_i_hex_loadstore:
        sb $zero, hex_asciiz_buffer($t1)
        la $a0, hex_asciiz_buffer
        jal convert_hex_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
    start_get_s_register_loadstore:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero  # indice do register_buffer
    sb $zero, register_buffer($zero)  # zerando register_buffer
    get_s_register_loadstore:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ')', save_s_register_loadstore
        blt $t0, 48, error_syntax
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_s_register_loadstore
    save_s_register_loadstore:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 21
        addu $s2, $s2, $v0
    end_encode_loadstore_instruction:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, end_encode_instruction
        bne $t0, '\n', error_syntax
        j end_encode_instruction


encode_branch_instruction:

encode_load_i_instruction:
    addiu $s2, $s2, 0x3c000000
    start_get_t_register_loadi:
    lb $t0, asm_text_content($s0)
    addi $s0, $s0, 1
    bne $t0, '$', error_unknown_instruction
    move $t1, $zero
    sb $zero, register_buffer($zero)
    get_t_register_loadi:
        lb $t0, asm_text_content($s0)
        addi $s0, $s0, 1
        beq $t0, ' ', save_t_register_loadi
        sb $t0, register_buffer($t1)
        addi $t1, $t1, 1
        j get_t_register_loadi
    save_t_register_loadi:
        sb $zero, register_buffer($t1)
        jal get_register_word
        sll $v0, $v0, 16
        addu $s2, $s2, $v0
    start_get_i_loadi:
    move $t1, $zero  # indice do buffer que vai armazenar i
    lb $t0, asm_text_content($s0)
    bne $t0, '0', start_get_i_dec_loadi
    addi $s0, $s0, 1
    lb $t0, asm_text_content($s0)
    bne $t0, 'x', start_get_i_dec_loadi
    addi $s0, $s0, 1
    j start_get_i_hex_loadi
    start_get_i_dec_loadi:
    sb $zero, dec_asciiz_buffer($zero)
    get_i_dec_loadi:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_i_dec_loadi
        beq $t0, '\n', save_i_dec_loadi
        beq $t0, ' ', save_i_dec_loadi
        addi $s0, $s0, 1
        sb $t0, dec_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_dec_loadi
    save_i_dec_loadi:
        sb $zero, dec_asciiz_buffer($t1)
        jal convert_dec_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
        j end_encode_instruction
    start_get_i_hex_loadi:
    sb $zero, hex_asciiz_buffer($zero)
    get_i_hex_loadi:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_i_hex_loadi
        beq $t0, '\n', save_i_hex_loadi
        beq $t0, ' ', save_i_hex_loadi
        addi $s0, $s0, 1
        sb $t0, hex_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j get_i_hex_loadi
    save_i_hex_loadi:
        sb $zero, hex_asciiz_buffer($t1)
        la $a0, hex_asciiz_buffer
        jal convert_hex_asciiz_to_word
        bgt $v0, 0xffff, internal_error_bits_conversion
        addu $s2, $s2, $v0
        j end_encode_instruction


encode_jump_instruction:
    beq $v1, 2, get_j_opcode
    beq $v1, 6, get_jal_opcode
    get_j_opcode:
        addiu $s2, $s2, 0x8000000
        j start_get_label_jump
    get_jal_opcode:
        addiu $s2, $s2, 0xc000000
    start_get_label_jump:
    move $t1, $zero  # indice do label_buffer
    sb $zero, label_buffer($zero)  # zerando label_buffer
    get_label_jump:
        lb $t0, asm_text_content($s0)
        beq $t0, $zero, save_label_jump
        beq $t0, '\n', save_label_jump
        beq $t0, ' ', error_syntax
        addi $s0, $s0, 1
        sb $t0, label_buffer($t1)
        addi $t1, $t1, 1
        j get_label_jump
    save_label_jump:
        sb $zero, label_buffer($t1)
        la $a0, text_labels
        jal get_label_addr
        beq $v0, $zero, error_syntax
        srl $v1, $v1, 2
        addu $s2, $s2, $v1
        j end_encode_instruction


## Entrada: $a0: ponteiro para o conteudo asciiz a ser normalizado
## Saida: nada, o próprio conteudo é diretamente normalizado
format_content:
    move $t0, $a0  # guarda ponteiro para iterar em todos os chars do conteudo
    move $t3, $a0  # guarda ponteiro para sobrescrever conteudo com chars adequados
    # procurando pelo começo da linha
    search_for_start_line:
        lb $t1, 0($t0)
        addi $t0, $t0, 1
        beq $t1, '\n', search_for_start_line
        beq $t1, ' ', search_for_start_line
        beq $t1, ',', search_for_start_line
        beq $t1, $zero, end_format_content
        addi $t0, $t0, -1
        j loop_format_line
    # após encontrar começo da linha, normalizando ela
    loop_format_line:
        lb $t1, 0($t0)  # char atual
        addi $t0, $t0, 1
        # ignora virgulas
        beq $t1, ',', loop_format_line
        # checa se é um espaço repetido e, se sim, o ignora
        bne $t1, ' ', skip_check_space
        lb $t2, 0($t0)  # guarda prox char (char atual + 1) em t2
        beq $t2, ' ', loop_format_line  # se proximo char é um desses char's, ignora char atual
        beq $t2, '\n', loop_format_line
        beq $t2, ',', loop_format_line
        beq $t2, ':', loop_format_line
        beq $t2, ')', loop_format_line
        beq $t2, '(', loop_format_line
        beq $t2, '.', loop_format_line
        lb $t2, -2($t0)  # guarda char anterior (char atual - 1) em t2
        beq $t2, ':', loop_format_line  # se o char anterior é um desses char's, ignora char atual
        beq $t2, '(', loop_format_line
        skip_check_space:
        beq $t1, $zero, end_format_content  # fim do conteudo original
        sb $t1, 0($t3)  # guarda char "que pode ser guardado" no conteudo
        addi $t3, $t3, 1
        beq $t1, '\n', search_for_start_line  # checa se é o fim da linha que está sendo normalizada
        j loop_format_line  # continua normalizando
    end_format_content:  # fim do conteudo
        sb $zero, 0($t3)
        jr $ra


## Entrada: $a0: ponteiro para o conteudo do arquivo .asm
## Saida: nada, pois os conteudos de .data e .text estarão em asm_data_content e asm_text_content, respectivamente
split_asm_content:
    move $t0, $a0
    move $t2, $zero  # ponteiro dataSection
    move $t3, $zero  # ponteiro textSection
    start_search_directive:
    addi $t7, $zero, 1
    search_directive:
        lb $t1, 0($t0)
        addi $t0, $t0, 1
        bne $t1, '.', skip_check_directive
        bne $t7, $zero, check_directive
        skip_check_directive:
        beq $t1, $zero, end_split_asm_content
        beq $t1, '\n', start_search_directive
        move $t7, $zero
        j search_directive
    check_directive:
        lb $t1, 0($t0)
        bne $t1, 'd', check_text_directive
        lb $t1, 1($t0)
        bne $t1, 'a', isnt_directive
        lb $t1, 2($t0)
        bne $t1, 't', isnt_directive
        lb $t1, 3($t0)
        bne $t1, 'a', isnt_directive
        lb $t1, 4($t0)
        bne $t1, '\n', isnt_directive
        addi $t0, $t0, 5
        j get_lines_data
        check_text_directive:
        bne $t1, 't', isnt_directive
        lb $t1, 1($t0)
        bne $t1, 'e', isnt_directive
        lb $t1, 2($t0)
        bne $t1, 'x', isnt_directive
        lb $t1, 3($t0)
        bne $t1, 't', isnt_directive
        lb $t1, 4($t0)
        bne $t1, '\n', isnt_directive
        addi $t0, $t0, 5
        j get_lines_text
        isnt_directive:
        j search_directive
    get_lines_data:
        addi $t7, $zero, 1
        get_chars_data:
            lb $t1, 0($t0)
            bne $t1, '.', skip_check_end_data
            lb $t4, 1($t0)
            beq $t4, 'd', search_directive
            beq $t4, 't', search_directive
            skip_check_end_data:
            addi $t0, $t0, 1
            beq $t1, $zero, end_split_asm_content
            sb $t1, asm_data_content($t2)
            addi $t2, $t2, 1
            beq $t1, '\n', get_lines_data
            move $t7, $zero
            j get_chars_data
    get_lines_text:
        addi $t7, $zero, 1
        get_chars_text:
            lb $t1, 0($t0)
            bne $t1, '.', skip_check_end_text
            lb $t4, 1($t0)
            beq $t4, 'd', search_directive
            beq $t4, 't', search_directive
            skip_check_end_text:
            addi $t0, $t0, 1
            beq $t1, $zero, end_split_asm_content
            sb $t1, asm_text_content($t3)
            addi $t3, $t3, 1
            beq $t1, '\n', get_lines_text
            move $t7, $zero
            j get_chars_text
    end_split_asm_content:
        sb $zero, asm_data_content($t2)
        sb $zero, asm_text_content($t3)
        jr $ra


## Entrada: $a0: endereço do mif_xxxx_content que deseja escrever a linha,
##          a partir do que há nos mif_addr_buffer e mif_value_buffer
##          $a1: indice em que se deseja comecar a escrever a nova linha
## Saida: nada, pois o próprio mif_xxxx_content será alterado
generate_mif_line:
    addi $sp, $sp, -4
    sw $s0, 0($sp)
    add $s0, $a0, $a1
    move $t1, $zero  # indice do mif_addr_buffer
    save_mif_addr_in_line:
        lb $t0, mif_addr_buffer($t1)
        beq $t0, $zero, end_save_mif_addr_in_line
        sb $t0, 0($s0)
        addi $t1, $t1, 1
        addi $s0, $s0, 1
        j save_mif_addr_in_line
    end_save_mif_addr_in_line:
        li $t0, 32
        sb $t0, 0($s0)
        addi $s0, $s0, 1
        li $t0, 58
        sb $t0, 0($s0)
        addi $s0, $s0, 1
        li $t0, 32
        sb $t0, 0($s0)
        addi $s0, $s0, 1
    move $t1, $zero
    save_mif_value_in_line:
        lb $t0, mif_value_buffer($t1)
        beq $t0, $zero, end_save_mif_value_in_line
        sb $t0, 0($s0)
        addi $t1, $t1, 1
        addi $s0, $s0, 1
        j save_mif_value_in_line
    end_save_mif_value_in_line:
        li $t0, 59
        sb $t0, 0($s0)
        addi $s0, $s0, 1
        li $t0, 10
        sb $t0, 0($s0)
        addi $s0, $s0, 1
    sub $v0, $s0, $a0
    lw $s0, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: $a0: tamanho do mif_data_content
## Saida: nada, pois será gerado o arquivo automaticamente a partir dos conteudo pro data.mif
generate_data_mif:
    addi $sp, $sp, -8
    sw $s0, 4($sp)
    sw $ra, 0($sp)
    move $s0, $a0
    jal generate_filepath_data_output
    # abrindo arquivo
    li $v0, 13
    la $a0, filepath
    li $a1, 1  # modo escrita
    syscall
    move $a0, $v0  # descritor do arquivo aberto está em v0
    # escrevendo a string no arquivo
    li $v0, 15
    la $a1, header_mif_data
    li $a2, 81
    syscall
    li $v0, 15
    la $a1, mif_data_content
    move $a2, $s0
    syscall
    li $v0, 15
    la $a1, footer_mif
    li $a2, 6
    syscall
    # fechando arquivo
    li $v0, 16
    syscall
    # restaurando pilha
    lw $ra, 0($sp)  # recupera ra
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra


## Entrada: nada
## Saida: nada, pois será alterado diretamente o filepath
generate_filepath_data_output:
    move $t0, $zero
    search_dot_filepath:
        lb $t1, filepath($t0)
        addi $t0, $t0, 1
        bne $t1, '.', search_dot_filepath
    addi $t0, $t0, -1
    li $t1, 95
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 100
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 97
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 116
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 97
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 46
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 109
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 105
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 102
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    sb $zero, filepath($t0)
    jr $ra


## Entrada: $a0: tamanho do mif_text_content
## Saida: nada, pois será gerado o arquivo automaticamente a partir dos conteudo pro text mif
generate_text_mif:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $s0, $a0
    jal generate_filepath_text_output
    # abrindo arquivo
    li $v0, 13
    la $a0, filepath
    li $a1, 1  # modo escrita
    syscall
    move $a0, $v0  # descritor do arquivo aberto está em v0
    # escrevendo a string no arquivo
    li $v0, 15
    la $a1, header_mif_text
    li $a2, 80
    syscall
    li $v0, 15
    la $a1, mif_text_content
    move $a2, $s0
    syscall
    li $v0, 15
    la $a1, footer_mif
    li $a2, 6
    syscall
    # fechando arquivo
    li $v0, 16
    syscall
    # restaurando pilha
    lw $ra, 0($sp)  # recupera ra
    addi $sp, $sp, 4
    jr $ra


## Entrada: nada
## Saida: nada, pois será alterado diretamente o filepath
generate_filepath_text_output:
    move $t0, $zero
    search_dot_filepath2:
        lb $t1, filepath($t0)
        addi $t0, $t0, 1
        bne $t1, '.', search_dot_filepath2
    addi $t0, $t0, -6
    li $t1, 95
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 116
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 101
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 120
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 116
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 46
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 109
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 105
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    li $t1, 102
    sb $t1, filepath($t0)
    addi $t0, $t0, 1
    sb $zero, filepath($t0)
    jr $ra


## Funcoes para Interacao com Usuario

## Entrada: $a0: ponteiro para buffer que irá armazenar conteúdo do arquivo
## Saida: nada, pois o próprio buffer irá armazenar o conteúdo do arquivo
get_input_file:
    # prepara a pilha
    addi $sp, $sp, -4
    sw $ra, 0($sp)  # guarda o ra
    # guarda a entrada em s0
    move $s0, $a0
    # imprime mensagem para obter caminho do arquivo
    li $v0, 4
    la $a0, prompt_input_filepath
    syscall
    # pega a entrada do usuário
    li $v0, 8
    la $a0, filepath
    la $a1, 50
    syscall
    # remove o '\n' no final da entrada do usuário
    la $a0, filepath
    jal remove_newline
    # abre arquivo a partir do caminho passado pelo usuario
    li $v0, 13
    la $a0, filepath
    li $a1, 0
    li $a2, 0
    syscall
    # verifica se abriu corretamente
    slt $t1, $v0, $zero
    bne $t1, $zero, error_open_file
    # guardando descritor do arquivo
    move $t0, $v0
    # lendo arquivo e guardando conteudo
    li $v0, 14
    move $a0, $t0
    move $a1, $s0  # s0 aramzena endereço do buffer de entrada
    li $a2, 1024
    syscall
    # fechando arquivo
    li $v0, 16
    move $a0, $t0
    syscall
    # libera a pilha e recupera ra (não precisa recuperar a0)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # retorno
    jr $ra
    ## Entrada: $a0: ponteiro para a string com newline
    ## Saida: nada, pq a manipulacao já é na string com newline
    remove_newline:
        move $t0, $a0
        loop_remove_newline:
            lb $t1, 0($t0)
            addi $t0, $t0, 1
            bne $t1, '\n', loop_remove_newline
            sb $zero, -1($t0)
            jr $ra

## Tratamento de erro ao abrir arquivo
error_open_file:
    la $a0, error_open_file_msg
	j error


## Tratamento de erro de sintaxe genérico
error_syntax:
    la $a0, error_syntax_msg
    j error


## Tratamento de erro de tipo de dado em .data desconhecido
error_data_type:
    la $a0, error_data_type_msg
    j error


## Tratamento de erro de registrador desconhecido
error_register_syntax:
    la $a0, error_register_syntax_msg
    j error


## Tratamento de erro de opcode desconhecido
error_unknown_opcode:
    la $a0, error_unknown_opcode_msg
    j error


## Tratamento de erro de instrucao desconhecida
error_unknown_instruction:
    la $a0, error_unknown_instruction_msg
    j error


## Tratamento de erro de conversao de bits
internal_error_bits_conversion:
    la $a0, internal_error_bits_conversion_msg
    j error


## Tratamento de erro de conversao de numero hexadecimal
error_conversion_hex_asciiz:
    la $a0, error_conversion_hex_asciiz_msg
    j error


error:
    li $v0, 4
    syscall
    j end

## Entrada: nada
## Saida: nada
end:
    li $v0, 10
    syscall

.data
header_mif_data: .asciiz "DEPTH = 16384;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
header_mif_text: .asciiz "DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
footer_mif: .asciiz "\nEND;\n"
prompt_input_filepath: .asciiz "Digite o caminho do arquivo .asm (completo): "
error_open_file_msg: .asciiz "Error: nao foi possivel ler o arquivo"
error_syntax_msg: .asciiz "Error: erro de sintaxe no codigo"
internal_error_bits_conversion_msg: .asciiz "Error: bytes insuficientes para escrever o valor desejado"
error_data_type_msg: .asciiz "Error: tipo de dado não reconhecido"
error_register_syntax_msg: .asciiz "Error: nao foi possivel compreender o registrador passado"
error_unknown_opcode_msg: .asciiz "Error: opcode desconhecido"
error_unknown_instruction_msg: .asciiz "Error: instrucao desconhecida"
error_conversion_hex_asciiz_msg: .asciiz "Error: erro ao ler numero hexadecimal"

instructions_arithlog: .asciiz "add;sub;and;or;nor;xor;slt;addu;subu;movn;sltu;mul;"
instructions_divmult: .asciiz "div;mult;"
instructions_move_from: .asciiz "mfhi;mflo;"
instructions_jump_r: .asciiz "jr;"
instructions_jump_alr: .asciiz "jalr;"
instructions_shift: .asciiz "sll;srl;sra;"
instructions_shift_v: .asciiz "sllv;srav;"
instructions_cl: .asciiz "clo;clz;"
instructions_arithlog_i: .asciiz "addi;andi;ori;xori;addiu;slti;"
instructions_branch_z: .asciiz "bgez;bgezal;bltzal;"
instructions_load_store: .asciiz "lw;sw;lb;sb;lhu;"
instructions_branch: .asciiz "beq;bne;"
instructions_load_i: .asciiz "lui;"
instructions_jump: "j;jal;"
