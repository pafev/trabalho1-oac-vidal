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
labels: .space 128  # formato "label:0000;label2:0008;"
int_asciiz_buffer: .space 11
hex_asciiz_buffer: .space 9

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

    # la $a0, asm_text_content  # ponteiro do .text do arquivo .asm
    # jal encode_text_asm

    # move $a0, $v0  # tamanho do mif_text_content
    # jal generate_text_mif

    jal end


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
        beq $t2, '.', loop_format_line
        beq $t2, '$', loop_format_line
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
        jal save_label
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
        move $t1, $zero  # indice do int_asciiz_buffer
        li $t6, 1  # flag de começo de valor
    decimal_data_value:
        lb $t0, asm_data_content($s0)
        addi $s0, $s0, 1
        blt $t0, 48, isnt_num_decimal_data_value  # se é um número, continua para guardar no int_asciiz_bufer iterativamente
        bgt $t0, 57, error_syntax
        sb $t0, int_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j decimal_data_value
    isnt_num_decimal_data_value:
        beq $t0, $zero, end_decimal_data_value
        beq $t0, ' ', end_decimal_data_value
        beq $t0, '\n', end_decimal_data_value
        bne $t0, '-', error_syntax
        beq $t6, $zero, error_syntax
        sb $t0, int_asciiz_buffer($t1)
        addi $t1, $t1, 1
        j decimal_data_value
    end_decimal_data_value:
        # -- pega o que tá no int_asciiz_buffer e converte para hexa asciiz
        sb $zero, int_asciiz_buffer($t1)
        li $a0, 8
        la $a1, mif_value_buffer
        jal convert_int_asciiz_to_hex_asciiz  # preenchi o mif_value_buffer
        # -- pega o endereço do data do mif e converte para hexa asciiz
        li $a0, 8
        move $a1, $s3
        move $a2, $zero
        la $a3, mif_addr_buffer
        jal convert_int_to_hex_asciiz  # preenchi o mif_addr_buffer
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
            jal convert_int_to_hex_asciiz  # preenchi o mif_addr_buffer
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


## Entrada: $a0: endereço do mif_xxxx_content que deseja escrever a linha,
##          a partir do que há nos mif_addr_buffer e mif_value_buffer
##          $a1: tamanho do mif_xxxx_content
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


## Entrada: $a0: valor em word do endereço da label no .asm
##          utiliza o nome da label em label_buffer
## Saida: nada, pois o próprio valor de labels é alterado
save_label:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $a1, $a0  # valor do endereço em word
    li $a0, 4
    move $a2, $zero
    la $a3, hex_asciiz_buffer  # irá receber o valor do endereço em asciiz, representando hexadecimal
    jal convert_int_to_hex_asciiz
    move $t2, $zero
    search_end_labels:
        lb $t0, labels($t2)
        beq $t0, $zero, append_labels
        addi $t2, $t2, 1
        j search_end_labels
    append_labels:
    move $t1, $zero
    append_label_in_labels:
        lb $t0, label_buffer($t1)
        beq $t0, $zero, append_separator_in_labels
        addi $t1, $t1, 1
        sb $t0, labels($t2)
        addi $t2, $t2, 1
        j append_label_in_labels
    append_separator_in_labels:
        li $t0, 58
        sb $t0, labels($t2)
        addi $t2, $t2, 1
    move $t1, $zero
    append_addr_in_labels:
        lb $t0, hex_asciiz_buffer($t1)
        beq $t0, $zero, end_save_label
        addi $t1, $t1, 1
        sb $t0, labels($t2)
        addi $t2, $t2, 1
        j append_addr_in_labels    
    end_save_label:
        li $t0, 59
        sb $t0, labels($t2)
        addi $t2, $t2, 1
        sb $zero, labels($t2)
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: $a0: tamanho do hex_asciiz_buffer
##          $a1: ponteiro para o buffer a ser preenchido com o resultado
## Saida: nada, pois o próprio buffer passado é alterado
convert_int_asciiz_to_hex_asciiz:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # inicializacoes
    move $t1, $zero # indice do int_asciiz_buffer
    move $t2, $zero  # acumulador do valor decimal
    move $t7, $zero  # flag de negativo
    # verifica se o inteiro asciiz é negativo
    lb $t3, int_asciiz_buffer($t1)
    beq $t3, '-', is_negative
    j convert_int_asciiz_to_int
    # se negativo, seta uma flag para o convert_int_to_hex_asciiz
    is_negative:
    li $t7, 1
    addi $t1, $t1, 1
    # primeiro converte para inteiro .word
    convert_int_asciiz_to_int:
        lb $t3, int_asciiz_buffer($t1)  # pega o char do int asciiz
        bne $t3, $zero, skip_end_int_asciiz  # se não terminou de converter em word
        move $a3, $a1
        move $a1, $t2
        move $a2, $t7
        jal convert_int_to_hex_asciiz
        j end_convert_int_asciiz_to_hex_asciiz
        skip_end_int_asciiz:
        sub $t3, $t3, '0'  # converte o byte do char para seus bits em representação numérica
        mul $t2, $t2, 10  # multiplica o acumulador decimal por 10
        add $t2, $t2, $t3  # acrescenta o byte convertido ao acumulador do valor decimal
        addi $t1, $t1, 1  # incremeta para iterar para o proximo char do inteiro asciiz
        j convert_int_asciiz_to_int
    # fim da conversao :)
    end_convert_int_asciiz_to_hex_asciiz:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


## Entrada: $a0: tamanho do hex_asciiz_buffer
##          $a1: valor inteiro a ser convertido para hex (asciiz)
##          $a2: flag de negativo
##          $a3: ponteiro para o buffer a ser preenchido com o resultado
## Saida: nada, pois o próprio hex_asciiz_buffer é alterado
convert_int_to_hex_asciiz:
    beq $a2, $zero, skip_negate_int  # se o inteiro é negativo, nega os bits dele
    sub $a1, $zero, $a1
    # se é positivo, segue normal
    skip_negate_int:
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
        beq $t0, $a3, end_convert_int_to_hex_asciiz
        addi $t0, $t0, -1
        li $t3, 48
        sb $t3, 0($t0)
        j fill_with_zeros
    # fim da conversao :)
    end_convert_int_to_hex_asciiz:
    sb $zero, 0($a0)
    jr $ra


## Entrada: $a0: ponteiro para o conteudo a ser montado
## Saida: $v0: tamanho do mif_text_content
encode_text_asm:
    move $v0, $zero
    jr $ra


## Entrada: $a0: valor do register em asciiz
## Saida: nada, pois o próprio hex_asciiz_buffer é alterado
convert_register_to_hex_asciiz:
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
    li $a2, 7
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


## Entrada: nada
## Saida: nada
error_open_file:
    # imprime a mensagem
	li $v0, 4
    la $a0, error_open_file_msg
	syscall
	j end


## Entrada: nada
## Saida: nada
error_syntax:
    # imprime a mensagem
    li $v0, 4
    la $a0, error_syntax_msg
    syscall
    j end


## Entrada: nada
## Saida: nada
error_data_type:
    # imprime a mensagem
    li $v0, 4
    la $a0, error_data_type_msg
    syscall
    j end


## Entrada: nada
## Saida: nada
internal_error_bits_conversion:
    # imprime a mensagem
    li $v0, 4
    la $a0, internal_error_bits_conversion_msg
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
internal_error_bits_conversion_msg: .asciiz "Error: bytes insuficientes para escrever o valor hexadecimal em asciiz"
error_data_type_msg: .asciiz "Error: tipo de dado não reconhecido"
