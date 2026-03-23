# =============================================================================
# Valor absoluto e cópia condicional — RISC-V RV32I
# =============================================================================
#
# Calcula o valor absoluto de um número inteiro com sinal.
# Demonstra desvio condicional (BLT/BGE) — equivalente ao JN do Neander.
#
# Algoritmo:
#   if x < 0:
#       result = -x    (inverte com SUB, pois não existe NEG em RV32I)
#   else:
#       result = x
#
# Também demonstra MIN e MAX de dois valores (bônus).
#
# Mapeamento de registradores:
#   x1  = valor de entrada (pode ser negativo)
#   x2  = resultado (valor absoluto)
#   x10 = primeiro valor para min/max
#   x11 = segundo valor para min/max
#   x12 = mínimo dos dois
#   x13 = máximo dos dois
#
# Resultados esperados:
#   x1=−15 → x2=15
#   x10=7, x11=3 → x12=3 (mínimo), x13=7 (máximo)
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/abs_value.hex
#   riscv> run
#   riscv> reg
# =============================================================================

.section .text
.global _start
_start:
    # ─── Calcula valor absoluto de x1 ────────────────────────────────
    addi  x1, x0, -15        # x1 = -15  (valor negativo para teste)

    bge   x1, x0, positivo   # se x1 >= 0, já é positivo
    sub   x2, x0, x1         # x2 = 0 - x1 = -(-15) = 15  (inverte sinal)
    jal   x0, pos_min_max

positivo:
    addi  x2, x1, 0          # x2 = x1  (copia o valor)

pos_min_max:
    # ─── Calcula mínimo e máximo de dois valores ──────────────────────
    addi  x10, x0, 7         # x10 = 7
    addi  x11, x0, 3         # x11 = 3

    # Mínimo: se x11 < x10, então x11 é o menor; senão x10 é o menor
    blt   x11, x10, x11_menor   # se x11 < x10, salta

    # x10 <= x11: x10 é o mínimo
    addi  x12, x10, 0            # min = x10
    addi  x13, x11, 0            # max = x11
    jal   x0, fim_minmax

x11_menor:
    addi  x12, x11, 0            # min = x11  (x11 < x10)
    addi  x13, x10, 0            # max = x10

fim_minmax:
    # Resultados:
    #   x2  = 15  (abs(-15))
    #   x12 = 3   (min(7,3))
    #   x13 = 7   (max(7,3))

fim:
    jal   x0, fim            # halt
