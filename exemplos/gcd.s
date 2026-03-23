# =============================================================================
# MDC (Máximo Divisor Comum) — RISC-V RV32I
# =============================================================================
#
# Calcula o MDC de dois números usando o algoritmo de Euclides por subtrações
# repetidas: enquanto a ≠ b, se a > b subtraia b de a, senão subtraia a de b.
# Quando a = b, o resultado é o MDC.
#
# Algoritmo:
#   enquanto a ≠ b:
#       se a > b: a = a - b
#       senão:    b = b - a
#   MDC = a  (= b)
#
# Este exemplo demonstra:
# - Desvios condicionais aninhados (bne, bgt)
# - Subtração iterativa sem divisão (RV32I não tem rem)
# - Uso de duas variáveis que convergem para o mesmo valor
#
# Mapeamento de registradores:
#   x1 = a  (primeiro valor; será o resultado ao final)
#   x2 = b  (segundo valor;  será igual a x1 ao final)
#
# Entrada:          x1 = 48, x2 = 18
# Resultado esperado: x1 = 6, x2 = 6  (MDC(48,18) = 6)
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/gcd.hex
#   riscv> run
#   riscv> reg        ← x1 e x2 devem ser 6
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicialização ────────────────────────────────────────────────
    addi  x1, x0, 48         # x1 = a = 48
    addi  x2, x0, 18         # x2 = b = 18

    # ─── Loop de subtrações ───────────────────────────────────────────
loop:
    beq   x1, x2, fim        # se a == b, encontramos o MDC → sai
    blt   x2, x1, maior_a    # se b < a (ou seja, a > b), vai para maior_a

    # Caso: b > a → b = b - a
    sub   x2, x2, x1         # b = b - a
    jal   x0, loop           # volta ao início do loop

maior_a:
    # Caso: a > b → a = a - b
    sub   x1, x1, x2         # a = a - b
    jal   x0, loop           # volta ao início do loop

fim:
    # x1 = x2 = MDC(48, 18) = 6
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT)
