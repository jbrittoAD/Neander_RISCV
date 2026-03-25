# =============================================================================
# Gabarito — Lista 1, Exercício 1: Soma de dois números
# Answer key — List 1, Exercise 1: Sum of two numbers
# =============================================================================
# Expected result: x3 = 42
# Resultado esperado: x3 = 42

.section .text
.global _start
_start:
    addi  x1, x0, 15         # x1 = 15
    addi  x2, x0, 27         # x2 = 27
    add   x3, x1, x2         # x3 = x1 + x2 = 42
fim:
    jal   x0, fim            # halt / parada
