# =============================================================================
# Gabarito — Lista 2, Exercício 7: Máximo de dois números (com sinal)
# =============================================================================
# Resultado esperado: x3 = 3 (max(-5, 3))

.section .text
.global _start
_start:
    addi  x1, x0, -5         # x1 = -5
    addi  x2, x0, 3          # x2 = 3

    # Se x1 >= x2, máximo é x1; senão é x2
    blt   x1, x2, x2_maior   # se x1 < x2 (com sinal), pula para x2_maior
    addi  x3, x1, 0          # x3 = x1 (x1 é o maior)
    jal   x0, fim

x2_maior:
    addi  x3, x2, 0          # x3 = x2 (x2 é o maior)

fim:
    jal   x0, fim            # x3 = 3 ✓
