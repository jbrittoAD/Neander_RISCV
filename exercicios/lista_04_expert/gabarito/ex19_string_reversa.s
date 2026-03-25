# =============================================================================
# Gabarito — Lista 4, Exercício 19: Inversão de String in-place
# Answer key — List 4, Exercise 19: In-place String Reversal
# =============================================================================
# Description / Descrição:
#   Stores the string "ABCDE\0" in data memory byte by byte, then reverses
#   the characters in-place (without the null byte) using two pointers.
#
#   Armazena a string "ABCDE\0" na memória de dados byte a byte, depois
#   inverte os caracteres in-place (sem byte nulo) usando dois ponteiros.
#
# Algorithm / Algoritmo:
#   1. Write "ABCDE\0" byte by byte with sb (addresses 0..5)
#      Grava "ABCDE\0" byte a byte com sb (endereços 0..5)
#   2. Calculate length: walk until null byte → length = 5
#      Calcula comprimento: percorre até byte nulo → comprimento = 5
#   3. Reversal with two pointers:
#      Inversão com dois ponteiros:
#      - left = 0, right = length - 1 / esquerda = 0, direita = comprimento - 1
#      - while left < right: swap bytes, left++, right--
#        enquanto esquerda < direita: troca bytes, esquerda++, direita--
#
# Register map / Mapa de registradores:
#   t0  (x5)  — auxiliary pointer/index (write string, compute length) / ponteiro/índice auxiliar (gravar string, calcular comprimento)
#   t1  (x6)  — temporary byte during swap / byte temporário durante a troca
#   t2  (x7)  — temporary byte during swap (second byte) / byte temporário durante a troca (segundo byte)
#   x2  (sp)  — reused here as string length (= 5) / reutilizado aqui como comprimento da string (= 5)
#               ATTENTION: x2 is normally the stack pointer; reused here to store
#               length per exercise specification.
#               ATENÇÃO: x2 normalmente é o stack pointer; aqui é reaproveitado
#               para armazenar o comprimento conforme especificação do exercício.
#   x3        — left pointer (left index, advances right) / ponteiro esquerda (índice left, avança para direita)
#   x4        — right pointer (right index, advances left) / ponteiro direita (índice right, avança para esquerda)
#
# Data memory (addresses 0..5) / Memória de dados (endereços 0..5):
#   Before / Antes: [0x41, 0x42, 0x43, 0x44, 0x45, 0x00]  = "ABCDE\0"
#   After / Depois: [0x45, 0x44, 0x43, 0x42, 0x41, 0x00]  = "EDCBA\0"
#
# Expected result / Resultado esperado:
#   x2 = 5  (string length / comprimento da string)
#   dmem[0] = 0x45 ('E'), dmem[1] = 0x44 ('D'), dmem[2] = 0x43 ('C'),
#   dmem[3] = 0x42 ('B'), dmem[4] = 0x41 ('A'), dmem[5] = 0x00 ('\0')
#
# How to verify / Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex19.o ex19_string_reversa.s
#   riscv64-unknown-elf-objcopy -O binary ex19.o ex19.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex19.bin ex19.hex
#   python3 ../../../../simulator/riscv_sim.py ex19.hex --run
#   # Verify: x2 = 5; mem 0x0000 2  → bytes 45 44 43 42 41 00
#   # Verificar: x2 = 5; mem 0x0000 2  → bytes 45 44 43 42 41 00
# =============================================================================

.section .text
.global _start

_start:
    # ── Stage 1: write "ABCDE\0" byte by byte into memory / Etapa 1: grava "ABCDE\0" byte a byte na memória ──────────────────────
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

    sb   x0, 5(x0)        # dmem[5] = 0x00  (null terminator / terminador nulo '\0')

    # ── Stage 2: compute string length / Etapa 2: calcula comprimento da string ─────────────────────────────
    addi t0, x0, 0        # t0 = index = 0 / índice = 0
    addi x2, x0, 0        # x2 = length = 0 / comprimento = 0

comprimento_loop:
    lb   t1, 0(t0)        # t1 = dmem[t0]  (read current byte / lê byte atual)
    beq  t1, x0, comprimento_fim    # if byte == 0, end of string / se byte == 0, fim da string
    addi x2, x2, 1        # length++ / comprimento++
    addi t0, t0, 1        # index++ / índice++
    jal  x0, comprimento_loop       # continue / continua

comprimento_fim:
    # x2 = 5  (string length, without null / comprimento da string, sem o nulo)

    # ── Stage 3: in-place reversal with two pointers / Etapa 3: inversão in-place com dois ponteiros ─────────────────────
    addi x3, x0, 0        # x3 = left = 0  (index of first character / índice do primeiro caractere)
    addi x4, x2, -1       # x4 = right = length - 1 = 4 / direita = comprimento - 1 = 4

inversao_loop:
    bge  x3, x4, inversao_fim   # if left >= right, reversal complete / se esquerda >= direita, inversão concluída

    lb   t1, 0(x3)        # t1 = dmem[left]   (left byte / byte da esquerda)
    lb   t2, 0(x4)        # t2 = dmem[right]  (right byte / byte da direita)

    sb   t2, 0(x3)        # dmem[left]  = right byte / byte da direita
    sb   t1, 0(x4)        # dmem[right] = left byte / byte da esquerda

    addi x3, x3, 1        # left++  (advance toward center / avança para o centro)
    addi x4, x4, -1       # right-- (retreat toward center / recua para o centro)

    jal  x0, inversao_loop        # continue reversal / continua a inversão

inversao_fim:
    # dmem[0..4] = "EDCBA", dmem[5] = 0x00

fim:
    jal x0, fim           # halt — infinite loop (equivalent to HLT) / parada — loop infinito (equivalente ao HLT)
