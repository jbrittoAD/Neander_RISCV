# =============================================================================
# Power (base^exponent) — RISC-V RV32I
# Potência (base^expoente) — RISC-V RV32I
# =============================================================================
#
# Calculates base^exponent using multiplication by repeated additions.
# Calcula base^expoente usando multiplicação por somas repetidas.
# Since RV32I has no mul instruction, multiplication is done in a
# Como RV32I não possui instrução mul, a multiplicação é feita em um
# sub-loop that adds the base exponent times.
# sub-loop que soma a base expoente vezes.
#
# Algorithm:
# Algoritmo:
#   result = 1
#   for i from 1 to exponent:
#   para i de 1 até expoente:
#       result = result * base        ← outer loop / loop externo
#
#   multiplication (result * base):
#   multiplicação (resultado * base):
#       temp = 0
#       for j from 1 to base:
#       para j de 1 até base:
#           temp = temp + result         ← inner loop / loop interno
#       result = temp
#
# This example demonstrates:
# Este exemplo demonstra:
# - Double loop (outer loop + multiplication sub-loop / loop externo + sub-loop de multiplicação)
# - Manual multiplication via repeated additions (no mul instruction / sem instrução mul)
# - Accumulator starting at 1 and multiplied N times
#   Acumulador que parte de 1 e é multiplicado N vezes
#
# Register mapping:
# Mapeamento de registradores:
#   x1 = base            (input / entrada)
#   x2 = exponent        (input; decremented by outer loop / entrada; decrementado pelo loop externo)
#   x3 = result          (final accumulator / acumulador final)
#   x4 = temp            (partial accumulator of multiplication sub-loop / acumulador parcial do sub-loop de multiplicação)
#   x5 = multiplication sub-loop counter (copy of x1 at start / copia de x1 no início)
#
# Input:            x1 = 2, x2 = 10 / Entrada: x1 = 2, x2 = 10
# Expected result:  x3 = 1024  (2^10 = 1024) / Resultado esperado: x3 = 1024
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/power.hex
#   riscv> run
#   riscv> reg        ← x3 should be 1024 / x3 deve ser 1024
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialization / Inicialização ───────────────────────────────────
    addi  x1, x0, 2          # x1 = base = 2
    addi  x2, x0, 10         # x2 = exponent = 10 / expoente = 10
    addi  x3, x0, 1          # x3 = result = 1 (multiplicative identity / identidade da multiplicação)

    # ─── Outer loop: repeats 'exponent' times / Loop externo: repete 'expoente' vezes ───
loop_externo:
    beq   x2, x0, fim        # if exponent == 0, finish / se expoente == 0, termina

    # Sub-loop: calculates result = result * base via additions
    # Sub-loop: calcula resultado = resultado * base via somas
    addi  x4, x0, 0          # x4 = temp = 0 (partial accumulator / acumulador parcial)
    add   x5, x0, x1         # x5 = counter = base (does 'base' additions / faz 'base' somas)

loop_mult:
    beq   x5, x0, fim_mult   # if counter == 0, multiplication done / se contador == 0, multiplicação concluída
    add   x4, x4, x3         # temp = temp + result  (partial sum / soma parcial)
    addi  x5, x5, -1         # counter-- / contador--
    jal   x0, loop_mult      # repeat sub-loop / repete sub-loop

fim_mult:
    add   x3, x0, x4         # result = temp  (update result / atualiza resultado)
    addi  x2, x2, -1         # exponent-- / expoente--
    jal   x0, loop_externo   # next outer loop iteration / próxima iteração do loop externo

fim:
    # x3 = 1024  (2^10)
    jal   x0, fim            # halt — infinite loop (equivalent to HLT) / loop infinito (equivalente ao HLT)
