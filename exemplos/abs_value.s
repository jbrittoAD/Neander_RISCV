# =============================================================================
# Absolute Value and Conditional Copy — RISC-V RV32I
# Valor absoluto e cópia condicional — RISC-V RV32I
# =============================================================================
#
# Calculates the absolute value of a signed integer.
# Calcula o valor absoluto de um número inteiro com sinal.
# Demonstrates conditional branch (BLT/BGE) — equivalent to JN in Neander.
# Demonstra desvio condicional (BLT/BGE) — equivalente ao JN do Neander.
#
# Algorithm:
# Algoritmo:
#   if x < 0:
#       result = -x    (invert with SUB, since NEG does not exist in RV32I)
#                      (inverte com SUB, pois não existe NEG em RV32I)
#   else:
#       result = x
#
# Also demonstrates MIN and MAX of two values (bonus).
# Também demonstra MIN e MAX de dois valores (bônus).
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = input value (may be negative / pode ser negativo)
#   x2  = result (absolute value / valor absoluto)
#   x10 = first value for min/max / primeiro valor para min/max
#   x11 = second value for min/max / segundo valor para min/max
#   x12 = minimum of the two / mínimo dos dois
#   x13 = maximum of the two / máximo dos dois
#
# Expected results:
# Resultados esperados:
#   x1=−15 → x2=15
#   x10=7, x11=3 → x12=3 (minimum / mínimo), x13=7 (maximum / máximo)
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/abs_value.hex
#   riscv> run
#   riscv> reg
# =============================================================================

.section .text
.global _start
_start:
    # ─── Calculate absolute value of x1 / Calcula valor absoluto de x1 ───
    addi  x1, x0, -15        # x1 = -15  (negative value for test / valor negativo para teste)

    bge   x1, x0, positivo   # if x1 >= 0, already positive / se x1 >= 0, já é positivo
    sub   x2, x0, x1         # x2 = 0 - x1 = -(-15) = 15  (invert sign / inverte sinal)
    jal   x0, pos_min_max

positivo:
    addi  x2, x1, 0          # x2 = x1  (copy the value / copia o valor)

pos_min_max:
    # ─── Calculate minimum and maximum of two values / Calcula mínimo e máximo de dois valores ───
    addi  x10, x0, 7         # x10 = 7
    addi  x11, x0, 3         # x11 = 3

    # Minimum: if x11 < x10, then x11 is smaller; else x10 is smaller
    # Mínimo: se x11 < x10, então x11 é o menor; senão x10 é o menor
    blt   x11, x10, x11_menor   # if x11 < x10, jump / se x11 < x10, salta

    # x10 <= x11: x10 is the minimum / x10 é o mínimo
    addi  x12, x10, 0            # min = x10
    addi  x13, x11, 0            # max = x11
    jal   x0, fim_minmax

x11_menor:
    addi  x12, x11, 0            # min = x11  (x11 < x10)
    addi  x13, x10, 0            # max = x10

fim_minmax:
    # Results / Resultados:
    #   x2  = 15  (abs(-15))
    #   x12 = 3   (min(7,3))
    #   x13 = 7   (max(7,3))

fim:
    jal   x0, fim            # halt
