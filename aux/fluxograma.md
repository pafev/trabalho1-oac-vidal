# Fluxograma para confecção do código do trabalho 1 de OAC

.data
buffer para conteudo do arquivo .asm
buffer para conteudo do arquivo .mif data
buffer para conteudo do arquivo .mif text
buffer para uma linha em analise
buffer para um label
buffer para um tipo de data
buffer para um valor de data

s0 -> ponteiro para os bytes do conteudo do arquivo de entrada
s1 -> ponteiro para os bytes do conteudo do arquivo de saida do .data
s2 -> ponteiro para os bytes do conteudo do arquivo de saida do .text
s3 -> endereço de memoria do mif data
s4 -> endereço de memoria do mif text

- Ler caminhos de entrada a saida dos arquivos
- Guardar o conteudo do arquivo de entrada
- Iterar linha a linha do conteudo do arquivo de entrada

  - Se a linha comecar com ".data"
    - Verifique se o buffer da label está vazio. Se sim, vá para 1. Se não, lance erro
  - 1: inicializar s3 em 0 e iterar linha a linha, lendo data

    - Se a linha começar com ".text"
      - Verifique se o buffer da label está vazio.
        - Se sim, grave \0 no conteudo do arquivo .mif data e vá para 2
        - Se não, lance erro
    - tx -> ponteiro para buffer da label
    - tx+1 -> ponteiro para buffer do tipo'
    - tx+2 -> ponteiro para buffer de um valor
    - 1.1: Iterar char a char, procurando primeiro char da label
      - Se achar ' ', ignore
      - Se achar '\t', ignore
      - Se achar '\n', vá para a próxima linha
      - Se achar '.', lance erro
      - Se achar ':', lance erro
      - Se achar um numero, lance erro
      - Se achar qualquer char que não os de cima, adicione no buffer da label e vá para 1.2
    - 1.2: Iterar char a char, procurando ':' estando na label
      - Se achar ' '
        - Para o endereço de memória de s3, escreva ele no arquivo .mif data
        - Zere o buffer da label
        - Vá para 1.2.1
      - Se achar '\t'
        - Para o endereço de memória de s3, escreva ele no arquivo .mif data
        - Zere o buffer da label
        - Vá para 1.2.1
      - Se achar '\n', lance erro
      - Se achar ':'
        - Para o endereço de memória s3, escreva ele no arquivo .mif data
        - Zere o buffer da label
        - Vá para 1.3
      - Se achar qualquer char que não os de cima, adicione no buffer da label e vá para 1.2
    - 1.2.1: Iterar char a char, procurando ':' não estando na label
      - Se achar ' ', ignore
      - Se achar '\t', ignore
      - Se achar '\n', lance erro
      - Se achar ':'
        - Vá para 1.3
      - Se achar qualquer char que não os de cima, lance erro
    - 1.3: Iterar char a char, procurando '.'
      - Se achar ' ', ignore
      - Se achar '\t', ignore
      - Se achar '\n, ignore
      - Se achar ':', lance erro
      - Se achar '.', vá para 1.4
    - 1.4: Iterar char a char, validando os char's do tipo de data
      - Se achar "word ", vá para 1.5
      - Se achar qualquer outra sequencia de char, lance erro
    - 1.5: Iterar char a char, procurando o proximo segmento de dado
      - Se achar ' ', ignore
      - Se achar '\t', ignore
      - Se achar '\n', vá para 1.7
      - Se achar um '.'
        - Se o proximo for um 't'
          - Volte 1 char
          - Vá para a próxima linha
        - Se o proximo for qualquer outro char, lance um erro
      - Se achar qualquer char que não um numero
        - Volte 1 char
        - Zere o buffer de label
        - s3++
        - Vá para 1.1
      - Se achar um numero, adicione no buffer do valor e vá para 1.6
    - 1.6: Iterar char a char, procurando final do valor
      - Se achar ' '
        - Para o valor no buffer do valor, escreva ele no .mif data
        - Zere o buffer do valor
        - s3++
        - Escreva uma quebra de linha no .mif data
        - Vá para 1.5
      - Se achar '\t'
        - Para o valor no buffer do valor, escreva ele no .mif data
        - Zere o buffer do valor
        - s3++
        - Escreva uma quebra de linha no .mif data
        - Vá para 1.5
      - Se achar '\n'
        - Para o valor no buffer do valor, escreva ele no .mif data
        - Zere o buffer do valor
        - s3++
        - Vá para 1.7
      - Se achar um numero, adicione no buffer do valor e vá para 1.6
      - Se achar qualquer char que não um número, lance um erro
    - 1.7: Iterar char a char, validando se ainda estamos lendo valor de dado
      - Se achar ' ', ignore
      - Se achar '\t', ignore
      - Se achar '\n', ignore
      - Se achar um numero
        - Volte 1 char
        - Vá para 1.6
      - Se achar um '.'
        - Se o proximo for um 't'
          - Volte 1 char e vá para a próxima linha
        - Se o proximo for qualquer char que não um 't', lance um erro
      - Se achar qualquer char que não um número
        - Volte 1 char
        - Zere o buffer de label
        - s3++
        - Vá para 1.1

  - 2: Iterar linha a linha, lendo text
  - 4: Gravar \0 no conteudo do arquivo de saida text e finalizar iteracao linha a linha
