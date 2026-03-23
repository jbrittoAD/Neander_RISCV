# =============================================================================
# Gabarito — Lista 2, Exercício 8: Soma de 1 até N
# =============================================================================
# Resultado esperado: x2 = 55  (1+2+3+...+10)

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = N = 10
    addi  x2, x0, 0          # x2 = soma = 0
    addi  x3, x0, 1          # x3 = i = 1 (começa em 1)

loop:
    bgt   x3, x1, fim        # se i > N, termina
    add   x2, x2, x3         # soma += i
    addi  x3, x3, 1          # i++
    jal   x0, loop

fim:
    # x2 = 55 = 10*11/2 ✓
    jal   x0, fim
