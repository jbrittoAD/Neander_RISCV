# =============================================================================
# Gabarito — Lista 2, Exercício 8: Soma de 1 até N
# Answer key — List 2, Exercise 8: Sum from 1 to N
# =============================================================================
# Expected result: x2 = 55  (1+2+3+...+10)
# Resultado esperado: x2 = 55  (1+2+3+...+10)

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = N = 10
    addi  x2, x0, 0          # x2 = sum = 0 / soma = 0
    addi  x3, x0, 1          # x3 = i = 1 (starts at 1 / começa em 1)

loop:
    bgt   x3, x1, fim        # if i > N, finish / se i > N, termina
    add   x2, x2, x3         # sum += i / soma += i
    addi  x3, x3, 1          # i++
    jal   x0, loop

fim:
    # x2 = 55 = 10*11/2 ✓
    jal   x0, fim
