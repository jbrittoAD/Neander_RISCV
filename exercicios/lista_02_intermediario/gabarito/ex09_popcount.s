# =============================================================================
# Gabarito — Lista 2, Exercício 9: Contagem de bits 1 (popcount)
# =============================================================================
# x1 = 0b10110101 = 181
# Bits 1: posições 0,2,4,5,7 → 5 bits ligados
# Resultado esperado: x2 = 5

.section .text
.global _start
_start:
    addi  x1, x0, 181        # x1 = 181 = 0b10110101
    addi  x2, x0, 0          # x2 = count = 0

loop:
    beq   x1, x0, fim        # se x1 == 0, todos os bits foram verificados

    andi  x3, x1, 1          # x3 = bit 0 de x1 (0 ou 1)
    add   x2, x2, x3         # count += x3

    srli  x1, x1, 1          # x1 >>= 1  (desloca para verificar próximo bit)

    jal   x0, loop

fim:
    # x2 = 5 ✓
    # Bits de 181 = 10110101: posições 0,2,4,5,7 = 5 bits ✓
    jal   x0, fim
