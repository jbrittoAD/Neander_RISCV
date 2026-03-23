# =============================================================================
# Gabarito — Lista 1, Exercício 5: Troca de valores com XOR
# =============================================================================
# Resultado esperado: x1 = 25, x2 = 10
# Técnica: swap sem variável auxiliar usando propriedades do XOR

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = 10
    addi  x2, x0, 25         # x2 = 25

    # Troca usando XOR (sem registrador auxiliar):
    xor   x1, x1, x2         # x1 = 10 XOR 25 = 19  (0b01010 XOR 0b11001 = 0b10011 = 19)
    xor   x2, x1, x2         # x2 = 19 XOR 25 = 10  ← agora x2 tem o valor original de x1!
    xor   x1, x1, x2         # x1 = 19 XOR 10 = 25  ← agora x1 tem o valor original de x2!

    # Por que funciona?
    # Seja a=10, b=25
    # Passo 1: x1 = a XOR b
    # Passo 2: x2 = (a XOR b) XOR b = a XOR (b XOR b) = a XOR 0 = a  ✓
    # Passo 3: x1 = (a XOR b) XOR a = (a XOR a) XOR b = 0 XOR b = b  ✓

fim:
    jal   x0, fim
