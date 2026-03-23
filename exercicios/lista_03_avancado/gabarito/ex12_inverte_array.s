# =============================================================================
# Gabarito — Lista 3, Exercício 12: Inversão de array in-place
# =============================================================================
# Entrada:  mem = [1, 2, 3, 4, 5]
# Resultado: mem = [5, 4, 3, 2, 1]

.section .text
.global _start
_start:
    # ─── Inicializa array ─────────────────────────────────────────────
    addi  x1, x0, 0          # endereço base

    addi  x10, x0, 1
    sw    x10, 0(x1)
    addi  x10, x0, 2
    sw    x10, 4(x1)
    addi  x10, x0, 3
    sw    x10, 8(x1)
    addi  x10, x0, 4
    sw    x10, 12(x1)
    addi  x10, x0, 5
    sw    x10, 16(x1)

    # ─── Inversão in-place ───────────────────────────────────────────
    # x2 = ponteiro esquerdo = base (i=0)
    # x3 = ponteiro direito  = base + (N-1)*4 = 0 + 4*4 = 16 (j=N-1)
    addi  x2, x0, 0          # ponteiro esquerdo
    addi  x3, x0, 16         # ponteiro direito (base + (5-1)*4)

loop:
    bge   x2, x3, fim        # se esquerdo >= direito, termina (inversão completa)

    lw    x4, 0(x2)          # x4 = array[i]  (elemento da esquerda)
    lw    x5, 0(x3)          # x5 = array[j]  (elemento da direita)

    sw    x5, 0(x2)          # array[i] = x5  (esquerda recebe direita)
    sw    x4, 0(x3)          # array[j] = x4  (direita recebe esquerda)

    addi  x2, x2, 4          # i++ (ponteiro esquerdo avança)
    addi  x3, x3, -4         # j-- (ponteiro direito recua)

    jal   x0, loop

fim:
    # Memória: [5, 4, 3, 2, 1] ✓
    # Verifique com: riscv> mem 0x0000 5
    jal   x0, fim
