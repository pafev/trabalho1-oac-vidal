.data
filepath: .space 50
output_filepath: .space 55
asm_content: .space 1024
asm_data_section: .space 512
asm_text_section: .space 512
mif_data_content: .space 768
mif_text_content: .space 768
label_buffer: .space 20
mif_addr_buffer: .space 9
mif_value_buffer: .space 9
mif_line_buffer: .space 22
labels: .space 128
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

    la $a0, asm_data_section  # ponteiro do .data do arquivo .asm
    jal encode_data_asm

    move $a0, $v0  # tamanho do mif_data_content
    jal generate_data_mif

    la $a0, asm_text_section  # ponteiro do .text do arquivo .asm
    jal encode_text_asm

    move $a0, $v0  # tamanho do mif_text_content
    jal generate_text_mif

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
        lb $t1, 0($t0)  # bite atual
        addi $t0, $t0, 1
        # ignora virgulas
        beq $t1, ',', loop_format_line
        # checa se é um espaço repetido e, se sim, o ignora
        bne $t1, ' ', skip_check_space
        lb $t2, 0($t0)  # bite atual + 1
        beq $t2, ' ', loop_format_line
        beq $t2, '\n', loop_format_line
        beq $t2, ',', loop_format_line
        beq $t2, ':', loop_format_line
        beq $t2, ')', loop_format_line
        lb $t2, -2($t0)
        beq $t2, ':', loop_format_line
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
## Saida: nada, pois os conteudos de .data e .text estarão em asm_data_section e asm_text_section, respectivamente
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
            sb $t1, asm_data_section($t2)
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
            sb $t1, asm_text_section($t3)
            addi $t3, $t3, 1
            beq $t1, '\n', get_lines_text
            move $t7, $zero
            j get_chars_text
    end_split_asm_content:
        sb $zero, asm_data_section($t2)
        sb $zero, asm_text_section($t3)
        jr $ra


## Entrada: $a0: ponteiro para o conteudo a ser montado
## Saida: $v0: tamanho do mif_data_content
encode_data_asm:
addi $sp, $sp, -4
sw $ra, 0($sp)
lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra


## Entrada: $a0: endereço do mif_addr_buffer
##          $a1: endereço do mif_value_buffer
## Saida: nada, pois o próprio mif_line_buffer será alterado
generate_mif_line:
jr $ra


## Entrada: $a0: endereço do label_buffer
##          $a1: valor em int do endereço da label no mips
## Saida: nada, pois o próprio valor de labels é alterado
save_label:
jr $ra


## Entrada: $a0: valor em int do endereço da label no mips
## Saida: nada, pois o próprio valor de label_addr_buffer é alterado
convert_int_to_label_addr:
jr $ra


## Entrada: #a0: tamanho do hex_asciiz_buffer
##          $a1: endereço do int_asciiz_buffer
## Saida: nada, pois o próprio hex_asciiz_buffer é alterado
convert_int_asciiz_to_hex_asciiz:
jr $ra


## Entrada: $a0: tamanho do hex_asciiz_buffer
##          $a1: valor inteiro a ser convertido para hex (asciiz)
## Saida: nada, pois o próprio hex_asciiz_buffer é alterado
convert_int_to_hex_asciiz:
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
addi $sp, $sp, -4
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
end:
    li $v0, 10
    syscall

.data
header_mif_data: .asciiz "DEPTH = 16384;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
header_mif_text: .asciiz "DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
footer_mif: .asciiz "\n\nEND;\n"
prompt_input_filepath: .asciiz "Digite o caminho do arquivo .asm (completo): "
error_open_file_msg: .asciiz "Error: Nao foi possivel ler o arquivo"
error_syntax_msg: .asciiz "Error: Erro de sintaxe no codigo"
