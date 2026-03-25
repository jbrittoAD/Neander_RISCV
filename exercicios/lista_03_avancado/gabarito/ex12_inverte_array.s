# =============================================================================
# Gabarito — Lista 3, Exercício 12: Inversão de array in-place
# Answer key — List 3, Exercise 12: In-place array reversal
# =============================================================================
# Input:  mem = [1, 2, 3, 4, 5] / Entrada:  mem = [1, 2, 3, 4, 5]
# Result: mem = [5, 4, 3, 2, 1] / Resultado: mem = [5, 4, 3, 2, 1]

.section .text
.global _start
_start:
    # ─── Initialize array / Inicializa array ─────────────────────────────────────────────
    addi  x1, x0, 0          # base address / endereço base

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

    # ─── In-place reversal / Inversão in-place ───────────────────────────────────────────
    # x2 = left pointer = base (i=0) / ponteiro esquerdo = base (i=0)
    # x3 = right pointer = base + (N-1)*4 = 0 + 4*4 = 16 (j=N-1) / ponteiro direito = base + (N-1)*4
    addi  x2, x0, 0          # left pointer / ponteiro esquerdo
    addi  x3, x0, 16         # right pointer (base + (5-1)*4) / ponteiro direito (base + (5-1)*4)

loop:
    bge   x2, x3, fim        # if left >= right, finish (reversal complete) / se esquerdo >= direito, termina (inversão completa)

    lw    x4, 0(x2)          # x4 = array[i]  (left element / elemento da esquerda)
    lw    x5, 0(x3)          # x5 = array[j]  (right element / elemento da direita)

    sw    x5, 0(x2)          # array[i] = x5  (left receives right / esquerda recebe direita)
    sw    x4, 0(x3)          # array[j] = x4  (right receives left / direita recebe esquerda)

    addi  x2, x2, 4          # i++ (left pointer advances / ponteiro esquerdo avança)
    addi  x3, x3, -4         # j-- (right pointer retreats / ponteiro direito recua)

    jal   x0, loop

fim:
    # Memory: [5, 4, 3, 2, 1] ✓ / Memória: [5, 4, 3, 2, 1] ✓
    # Check with: riscv> mem 0x0000 5 / Verifique com: riscv> mem 0x0000 5
    jal   x0, fim
