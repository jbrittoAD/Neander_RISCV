# =============================================================================
# Gabarito — Lista 4, Exercício 19: Inversão de String in-place
# =============================================================================
# Descrição:
#   Armazena a string "ABCDE\0" na memória de dados byte a byte, depois
#   inverte os caracteres in-place (sem byte nulo) usando dois ponteiros.
#
# Algoritmo:
#   1. Grava "ABCDE\0" byte a byte com sb (endereços 0..5)
#   2. Calcula comprimento: percorre até byte nulo → comprimento = 5
#   3. Inversão com dois ponteiros:
#      - esquerda = 0, direita = comprimento - 1
#      - enquanto esquerda < direita: troca bytes, esquerda++, direita--
#
# Mapa de registradores:
#   t0  (x5)  — ponteiro/índice auxiliar (gravar string, calcular comprimento)
#   t1  (x6)  — byte temporário durante a troca
#   t2  (x7)  — byte temporário durante a troca (segundo byte)
#   x2  (sp)  — reutilizado aqui como comprimento da string (= 5)
#               ATENÇÃO: x2 normalmente é o stack pointer; aqui é reaproveitado
#               para armazenar o comprimento conforme especificação do exercício.
#   x3        — ponteiro esquerda (índice left, avança para direita)
#   x4        — ponteiro direita  (índice right, avança para esquerda)
#
# Memória de dados (endereços 0..5):
#   Antes: [0x41, 0x42, 0x43, 0x44, 0x45, 0x00]  = "ABCDE\0"
#   Depois: [0x45, 0x44, 0x43, 0x42, 0x41, 0x00]  = "EDCBA\0"
#
# Resultado esperado:
#   x2 = 5  (comprimento da string)
#   dmem[0] = 0x45 ('E'), dmem[1] = 0x44 ('D'), dmem[2] = 0x43 ('C'),
#   dmem[3] = 0x42 ('B'), dmem[4] = 0x41 ('A'), dmem[5] = 0x00 ('\0')
#
# Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex19.o ex19_string_reversa.s
#   riscv64-unknown-elf-objcopy -O binary ex19.o ex19.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex19.bin ex19.hex
#   python3 ../../../../simulator/riscv_sim.py ex19.hex --run
#   # Verificar: x2 = 5; mem 0x0000 2  → bytes 45 44 43 42 41 00
# =============================================================================

.section .text
.global _start

_start:
    # ── Etapa 1: grava "ABCDE\0" byte a byte na memória ──────────────────────
    addi t0, x0, 0x41     # t0 = 0x41 = 'A'
    sb   t0, 0(x0)        # dmem[0] = 'A'

    addi t0, x0, 0x42     # t0 = 0x42 = 'B'
    sb   t0, 1(x0)        # dmem[1] = 'B'

    addi t0, x0, 0x43     # t0 = 0x43 = 'C'
    sb   t0, 2(x0)        # dmem[2] = 'C'

    addi t0, x0, 0x44     # t0 = 0x44 = 'D'
    sb   t0, 3(x0)        # dmem[3] = 'D'

    addi t0, x0, 0x45     # t0 = 0x45 = 'E'
    sb   t0, 4(x0)        # dmem[4] = 'E'

    sb   x0, 5(x0)        # dmem[5] = 0x00  (terminador nulo '\0')

    # ── Etapa 2: calcula comprimento da string ─────────────────────────────
    addi t0, x0, 0        # t0 = índice = 0
    addi x2, x0, 0        # x2 = comprimento = 0

comprimento_loop:
    lb   t1, 0(t0)        # t1 = dmem[t0]  (lê byte atual)
    beq  t1, x0, comprimento_fim    # se byte == 0, fim da string
    addi x2, x2, 1        # comprimento++
    addi t0, t0, 1        # índice++
    jal  x0, comprimento_loop       # continua

comprimento_fim:
    # x2 = 5  (comprimento da string, sem o nulo)

    # ── Etapa 3: inversão in-place com dois ponteiros ─────────────────────
    addi x3, x0, 0        # x3 = esquerda = 0  (índice do primeiro caractere)
    addi x4, x2, -1       # x4 = direita = comprimento - 1 = 4

inversao_loop:
    bge  x3, x4, inversao_fim   # se esquerda >= direita, inversão concluída

    lb   t1, 0(x3)        # t1 = dmem[esquerda]  (byte da esquerda)
    lb   t2, 0(x4)        # t2 = dmem[direita]   (byte da direita)

    sb   t2, 0(x3)        # dmem[esquerda] = byte da direita
    sb   t1, 0(x4)        # dmem[direita]  = byte da esquerda

    addi x3, x3, 1        # esquerda++  (avança para o centro)
    addi x4, x4, -1       # direita--   (recua para o centro)

    jal  x0, inversao_loop        # continua a inversão

inversao_fim:
    # dmem[0..4] = "EDCBA", dmem[5] = 0x00

fim:
    jal x0, fim           # halt — loop infinito (equivalente ao HLT)
