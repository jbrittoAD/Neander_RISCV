# =============================================================================
# Gabarito — Lista 1, Exercício 5: Troca de valores com XOR
# Answer key — List 1, Exercise 5: Value swap with XOR
# =============================================================================
# Expected result: x1 = 25, x2 = 10
# Resultado esperado: x1 = 25, x2 = 10
# Technique: swap without auxiliary variable using XOR properties
# Técnica: swap sem variável auxiliar usando propriedades do XOR

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = 10
    addi  x2, x0, 25         # x2 = 25

    # Swap using XOR (without auxiliary register):
    # Troca usando XOR (sem registrador auxiliar):
    xor   x1, x1, x2         # x1 = 10 XOR 25 = 19  (0b01010 XOR 0b11001 = 0b10011 = 19)
    xor   x2, x1, x2         # x2 = 19 XOR 25 = 10  ← x2 now holds original x1 / agora x2 tem o valor original de x1!
    xor   x1, x1, x2         # x1 = 19 XOR 10 = 25  ← x1 now holds original x2 / agora x1 tem o valor original de x2!

    # Why does it work? / Por que funciona?
    # Let a=10, b=25 / Seja a=10, b=25
    # Step 1 / Passo 1: x1 = a XOR b
    # Step 2 / Passo 2: x2 = (a XOR b) XOR b = a XOR (b XOR b) = a XOR 0 = a  ✓
    # Step 3 / Passo 3: x1 = (a XOR b) XOR a = (a XOR a) XOR b = 0 XOR b = b  ✓

fim:
    jal   x0, fim
