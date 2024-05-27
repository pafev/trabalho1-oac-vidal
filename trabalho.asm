.data
filePathBuffer: .space 50
inputContentBuffer: .space 1024
inputDataSection: .space 512
inputTextSection: .space 512
outputDataSection: .space 768
outputTextSection: .space 768

.text
.globl main

main:
    la $a0, inputContentBuffer  # ponteiro para o buffer que irá armazenar o conteudo do arq de entrada
    jal getInputFile

    la $a0, inputContentBuffer  # ponteiro para o conteudo do arquivo .asm
    jal normalizeContent

    la $a0, inputContentBuffer  # ponteiro para o conteudo normalizado do arquivo .asm
    jal splitInputFile

    # la $a0, inputDataSection  # ponteiro do .data do arquivo .asm
    # jal encodeDataSection

    # la $a0, headerDataMif
    # la $a1, outputDataSection  # ponteiro do conteudo do arquivo .mif do data
    # la $a2, footerMif
    # jal generateMif

    # la $a0, inputTextSection  # ponteiro do .text do arquivo .asm
    # jal encodeTextSection

    # la $a0, headerTextMif
    # la $a1, outputTextSection  # ponteiro do conteudo do arquivo .mif do text
    # la $a2, footerMif
    # jal generateMif

    jal end


## Entrada: $a0: ponteiro para buffer que irá armazenar conteúdo do arquivo
## Saida: nada, pois o próprio buffer irá armazenar o conteúdo do arquivo
getInputFile:
    # prepara a pilha
    addi $sp, $sp, -4
    sw $ra, 0($sp)  # guarda o ra
    # guarda a entrada em s0
    move $s0, $a0
    # imprime mensagem para obter caminho do arquivo
    li $v0, 4
    la $a0, promptInputFile
    syscall
    # pega a entrada do usuário
    li $v0, 8
    la $a0, filePathBuffer
    la $a1, 50
    syscall
    # remove o '\n' no final da entrada do usuário
    la $a0, filePathBuffer
    jal removeNewLine
    # abre arquivo a partir do caminho passado pelo usuario
    li $v0, 13
    la $a0, filePathBuffer
    li $a1, 0
    li $a2, 0
    syscall
    # verifica se abriu corretamente
    slt $t1, $v0, $zero
    bne $t1, $zero, errorOpenInputFile
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
    removeNewLine:
        move $t0, $a0
        loopRemoveNewLine:
            lb $t1, 0($t0)
            addi $t0, $t0, 1
            bne $t1, '\n', loopRemoveNewLine
            sb $zero, -1($t0)
            jr $ra


## Entrada: $a0: ponteiro para o conteudo asciiz a ser normalizado
## Saida: nada, o próprio conteudo é diretamente normalizado
normalizeContent:
    move $t0, $a0  # guarda ponteiro para iterar em todos os chars do conteudo
    move $t3, $a0  # guarda ponteiro para sobrescrever conteudo com chars adequados
    # procurando pelo começo da linha
    searchForStart:
        lb $t1, 0($t0)
        addi $t0, $t0, 1
        beq $t1, '\n', searchForStart
        beq $t1, ' ', searchForStart
        beq $t1, $zero, endNormalizeContent
        addi $t0, $t0, -1
        j loopNormalizeLine
    # após encontrar começo da linha, normalizando ela
    loopNormalizeLine:
        lb $t1, 0($t0)  # bite atual
        lb $t2, 1($t0)  # bite atual + 1
        addi $t0, $t0, 1
        # checa se é um espaço repetido
        bne $t1, ' ', skipCheckSpace
        beq $t2, ' ', loopNormalizeLine
        beq $t2, '\n', loopNormalizeLine
        beq $t2, ',', loopNormalizeLine
        skipCheckSpace:
        beq $t1, $zero, endNormalizeContent  # checa se é o fim do conteudo original
        sb $t1, 0($t3)  # guarda char "que pode ser guardado" no conteudo
        addi $t3, $t3, 1
        beq $t1, '\n', searchForStart  # checa se é o fim da linha que está sendo normalizada
        j loopNormalizeLine  # continua normalizando
    endNormalizeContent:  # fim do conteudo
        sb $zero, 0($t3)
        jr $ra


## Entrada: $a0: ponteiro para o conteudo do arquivo .asm
## Saida: nada, pois os conteudos de .data e .text estarão em inputDataSection e inputTextSection, respectivamente
splitInputFile:
    move $t0, $a0
    move $t2, $zero  # ponteiro dataSection
    move $t3, $zero  # ponteiro textSection
    startSearchDirective:
    addi $t7, $zero, 1
    searchForDirective:
        lb $t1, 0($t0)
        addi $t0, $t0, 1
        bne $t1, '.', skipCheckDirective
        bne $t7, $zero, checkDirective
        skipCheckDirective:
        beq $t1, $zero, endSplitInputFile
        beq $t1, '\n', startSearchDirective
        move $t7, $zero
        j searchForDirective
    checkDirective:
        lb $t1, 0($t0)
        bne $t1, 'd', checkTextDirective
        lb $t1, 1($t0)
        bne $t1, 'a', isntDirective
        lb $t1, 2($t0)
        bne $t1, 't', isntDirective
        lb $t1, 3($t0)
        bne $t1, 'a', isntDirective
        lb $t1, 4($t0)
        bne $t1, '\n', isntDirective
        addi $t0, $t0, 5
        j getLineDataSection
        checkTextDirective:
        bne $t1, 't', isntDirective
        lb $t1, 1($t0)
        bne $t1, 'e', isntDirective
        lb $t1, 2($t0)
        bne $t1, 'x', isntDirective
        lb $t1, 3($t0)
        bne $t1, 't', isntDirective
        lb $t1, 4($t0)
        bne $t1, '\n', isntDirective
        addi $t0, $t0, 5
        j getLineTextSection
        isntDirective:
        j searchForDirective
    getLineDataSection:
        addi $t7, $zero, 1
        getCharDataSection:
            lb $t1, 0($t0)
            bne $t1, '.', skipCheckEndDataSection
            lb $t4, 1($t0)
            beq $t4, 'd', searchForDirective
            beq $t4, 't', searchForDirective
            skipCheckEndDataSection:
            addi $t0, $t0, 1
            beq $t1, $zero, endSplitInputFile
            sb $t1, inputDataSection($t2)
            addi $t2, $t2, 1
            beq $t1, '\n', getLineDataSection
            move $t7, $zero
            j getCharDataSection
    getLineTextSection:
        addi $t7, $zero, 1
        getCharTextSection:
            lb $t1, 0($t0)
            bne $t1, '.', skipCheckEndTextSection
            lb $t4, 1($t0)
            beq $t4, 'd', searchForDirective
            beq $t4, 't', searchForDirective
            skipCheckEndTextSection:
            addi $t0, $t0, 1
            beq $t1, $zero, endSplitInputFile
            sb $t1, inputTextSection($t3)
            addi $t3, $t3, 1
            beq $t1, '\n', getLineTextSection
            move $t7, $zero
            j getCharTextSection
    endSplitInputFile:
        sb $zero, inputDataSection($t2)
        sb $zero, inputTextSection($t3)
        jr $ra


## Entrada: nada
## Saida: nada
errorOpenInputFile:
    # imprime a mensagem
	li $v0, 4
    la $a0, errorOpenInputFileMsg
	syscall
	j end


## Entrada: nada
## Saida: nada
errorSyntax:
    # imprime a mensagem
    li $v0, 4
    la $a0, errorSyntaxMsg
    syscall
    j end


## Entrada: nada
## Saida: nada
end:
    li $v0, 10
    syscall

.data
headerDataMif: .asciiz "DEPTH = 16384;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
headerTextMif: .asciiz "DEPTH = 4096;\nWIDTH = 32;\nADDRESS_RADIX = HEX;\nDATA_RADIX = HEX;\nCONTENT\nBEGIN\n\n"
footerMif: .asciiz "\n\nEND;\n"
promptInputFile: .asciiz "Digite o caminho do arquivo .asm (completo): "
errorOpenInputFileMsg: .asciiz "Error: Nao foi possivel ler o arquivo"
errorSyntaxMsg: .asciiz "Error: Erro de sintaxe no codigo"

dataDirective: .asciiz "data"
textDirective: .asciiz "text
