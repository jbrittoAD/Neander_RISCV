# =============================================================================
# Gabarito — Lista 2, Exercício 6: Valor absoluto
# =============================================================================
# Resultado esperado: x2 = 42 (abs(-42))

.section .text
.global _start
_start:
    addi  x1, x0, -42        # x1 = -42

    bge   x1, x0, positivo   # se x1 >= 0, já é positivo
    sub   x2, x0, x1         # x2 = 0 - (-42) = 42
    jal   x0, fim

positivo:
    addi  x2, x1, 0          # x2 = x1 (copia o valor positivo)

fim:
    jal   x0, fim
