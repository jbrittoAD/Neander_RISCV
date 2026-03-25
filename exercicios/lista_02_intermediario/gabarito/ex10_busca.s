# =============================================================================
# Gabarito — Lista 2, Exercício 10: Busca linear em array
# Answer key — List 2, Exercise 10: Linear search in array
# =============================================================================
# Array: [10, 25, 42, 7, 99] in data memory / na memória de dados
# Searching for 42 → index = 2 / Busca por 42 → índice = 2
# Expected result: x2 = 2
# Resultado esperado: x2 = 2

.section .text
.global _start
_start:
    # ─── Initialize array in data memory / Inicializa array na memória de dados ─────────────────────────
    addi  x1, x0, 0          # x1 = base address / endereço base

    addi  x10, x0, 10
    sw    x10, 0(x1)         # array[0] = 10

    addi  x10, x0, 25
    sw    x10, 4(x1)         # array[1] = 25

    addi  x10, x0, 42
    sw    x10, 8(x1)         # array[2] = 42  ← will be found here / será encontrado aqui

    addi  x10, x0, 7
    sw    x10, 12(x1)        # array[3] = 7

    addi  x10, x0, 99
    sw    x10, 16(x1)        # array[4] = 99

    # ─── Linear search / Busca linear ─────────────────────────────────────────────────
    addi  x4, x0, 42         # x4 = value to search for = 42 / valor a buscar = 42
    addi  x5, x0, 5          # x5 = N = 5 elements / 5 elementos
    addi  x3, x0, 0          # x3 = index i = 0 / índice i = 0
    addi  x2, x0, -1         # x2 = result = -1 (not found yet / não encontrado ainda)

loop:
    bge   x3, x5, fim        # if i >= N, not found / se i >= N, não encontrou

    slli  x6, x3, 2          # x6 = i * 4
    add   x6, x1, x6         # x6 = base + i*4
    lw    x7, 0(x6)          # x7 = array[i]

    beq   x7, x4, achou      # if array[i] == value, found! / se array[i] == valor, encontrou!

    addi  x3, x3, 1          # i++
    jal   x0, loop

achou:
    addi  x2, x3, 0          # x2 = found index / índice encontrado

fim:
    # x2 = 2 ✓
    jal   x0, fim
