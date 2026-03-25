# =============================================================================
# GCD (Greatest Common Divisor) — RISC-V RV32I
# MDC (Máximo Divisor Comum) — RISC-V RV32I
# =============================================================================
#
# Calculates the GCD of two numbers using Euclid's algorithm by repeated
# Calcula o MDC de dois números usando o algoritmo de Euclides por subtrações
# subtraction: while a ≠ b, if a > b subtract b from a, else subtract a from b.
# repetidas: enquanto a ≠ b, se a > b subtraia b de a, senão subtraia a de b.
# When a = b, the result is the GCD.
# Quando a = b, o resultado é o MDC.
#
# Algorithm:
# Algoritmo:
#   while a ≠ b:
#   enquanto a ≠ b:
#       if a > b: a = a - b
#       se a > b: a = a - b
#       else:     b = b - a
#       senão:    b = b - a
#   GCD = a  (= b)
#   MDC = a  (= b)
#
# This example demonstrates:
# Este exemplo demonstra:
# - Nested conditional branches (bne, bgt) / Desvios condicionais aninhados (bne, bgt)
# - Iterative subtraction without division (RV32I has no rem)
#   Subtração iterativa sem divisão (RV32I não tem rem)
# - Two variables converging to the same value
#   Uso de duas variáveis que convergem para o mesmo valor
#
# Register mapping:
# Mapeamento de registradores:
#   x1 = a  (first value; will be the result at the end / primeiro valor; será o resultado ao final)
#   x2 = b  (second value; will equal x1 at the end / segundo valor; será igual a x1 ao final)
#
# Input:            x1 = 48, x2 = 18 / Entrada: x1 = 48, x2 = 18
# Expected result:  x1 = 6, x2 = 6  (GCD(48,18) = 6 / MDC(48,18) = 6)
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/gcd.hex
#   riscv> run
#   riscv> reg        ← x1 and x2 should be 6 / x1 e x2 devem ser 6
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialization / Inicialização ───────────────────────────────────
    addi  x1, x0, 48         # x1 = a = 48
    addi  x2, x0, 18         # x2 = b = 18

    # ─── Subtraction loop / Loop de subtrações ────────────────────────────
loop:
    beq   x1, x2, fim        # if a == b, we found the GCD → exit / se a == b, encontramos o MDC → sai
    blt   x2, x1, maior_a    # if b < a (i.e. a > b), go to maior_a / se b < a (ou seja, a > b), vai para maior_a

    # Case: b > a → b = b - a / Caso: b > a → b = b - a
    sub   x2, x2, x1         # b = b - a
    jal   x0, loop           # return to loop start / volta ao início do loop

maior_a:
    # Case: a > b → a = a - b / Caso: a > b → a = a - b
    sub   x1, x1, x2         # a = a - b
    jal   x0, loop           # return to loop start / volta ao início do loop

fim:
    # x1 = x2 = GCD(48, 18) = 6 / MDC(48, 18) = 6
    jal   x0, fim            # halt — infinite loop (equivalent to HLT) / loop infinito (equivalente ao HLT)
