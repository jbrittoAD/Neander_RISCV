# =============================================================================
# Gabarito — Lista 3, Exercício 11: Soma de array com ponteiro
# Answer key — List 3, Exercise 11: Array sum with pointer
# =============================================================================
# Array: [5, 10, 15, 20, 25, 30]
# Expected result: x2 = 105
# Resultado esperado: x2 = 105

.section .text
.global _start
_start:
    # ─── Initialize array / Inicializa array ─────────────────────────────────────────────
    addi  x1, x0, 0          # x1 = pointer = base address = 0 / ponteiro = endereço base = 0

    addi  x10, x0, 5
    sw    x10, 0(x1)
    addi  x10, x0, 10
    sw    x10, 4(x1)
    addi  x10, x0, 15
    sw    x10, 8(x1)
    addi  x10, x0, 20
    sw    x10, 12(x1)
    addi  x10, x0, 25
    sw    x10, 16(x1)
    addi  x10, x0, 30
    sw    x10, 20(x1)

    # ─── Sum with pointer / Soma com ponteiro ────────────────────────────────────────────
    addi  x2, x0, 0          # x2 = sum = 0 / soma = 0
    addi  x1, x0, 0          # x1 = pointer = base / ponteiro = base

    # x5 = end address = base + N*4 = 0 + 6*4 = 24
    # x5 = endereço do fim = base + N*4 = 0 + 6*4 = 24
    addi  x5, x0, 24         # x5 = end address (exclusive) / endereço fim (exclusivo)

loop:
    bge   x1, x5, fim        # if pointer >= end, finish / se ponteiro >= fim, termina

    lw    x3, 0(x1)          # x3 = *pointer / *ponteiro
    add   x2, x2, x3         # sum += x3 / soma += x3
    addi  x1, x1, 4          # pointer++ (advance 4 bytes = 1 word / avança 4 bytes = 1 word)

    jal   x0, loop

fim:
    # x2 = 5+10+15+20+25+30 = 105 ✓
    jal   x0, fim
