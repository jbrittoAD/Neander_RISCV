# =============================================================================
# Iterative Factorial — RISC-V RV32I
# Fatorial iterativo — RISC-V RV32I
# =============================================================================
#
# Calculates N! (factorial of N) iteratively.
# Calcula N! (fatorial de N) de forma iterativa.
#
# Algorithm:
# Algoritmo:
#   result = 1
#   for i = N; i > 1; i--:
#       result = result * i   ← multiplication via repeated addition
#                               multiplicação via soma repetida
#
# NOTE: RISC-V RV32I has no multiply instruction (it is part of the M
# ATENÇÃO: RISC-V RV32I não tem instrução de multiplicação (ela faz parte da
# extension). Here we implement multiplication with a sub-loop of additions.
# extensão M). Aqui implementamos multiplicação com um sub-loop de somas.
# This demonstrates how simple primitives build complex operations.
# Isso demonstra como primitivas simples constroem operações complexas.
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = N (number to calculate the factorial of / número a calcular o fatorial)
#   x2  = accumulated result (starts at 1 / resultado acumulado, começa em 1)
#   x3  = i (main loop counter, from N down to 2 / contador do loop principal, de N até 2)
#   x4  = temporary accumulator for multiplication / acumulador temporário para multiplicação
#   x5  = multiplication sub-loop counter / contador do sub-loop de multiplicação
#
# Expected result (N=5):
# Resultado esperado (N=5):
#   x2 = 120   (5! = 5 × 4 × 3 × 2 × 1 = 120)
#
# Other examples:
# Outros exemplos:
#   N=1 → 1,  N=2 → 2,  N=3 → 6,  N=4 → 24,  N=6 → 720
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/factorial.hex
#   riscv> run
#   riscv> reg             ← x2 should contain 120 / x2 deve conter 120
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialization / Inicialização ───────────────────────────────────
    addi  x1, x0, 5          # x1 = N = 5  (change here to test other values / mude aqui para testar outros valores)
    addi  x2, x0, 1          # x2 = result = 1 (base case: 0! = 1! = 1 / caso base: 0! = 1! = 1)
    addi  x3, x1, 0          # x3 = i = N  (loop from N down to 2 / loop de N até 2)

loop_principal:
    addi  x6, x0, 2
    blt   x3, x6, fim        # if i < 2, finish (i==1 does not change result / se i < 2, termina — i==1 não muda o resultado)

    # ─── Multiplication: x2 = x2 * x3 via repeated additions ─────────────
    # ─── Multiplicação: x2 = x2 * x3 via somas repetidas ─────────────────
    # Idea: x4 = x2 + x2 + ... + x2  (x3 times / vezes)
    addi  x4, x0, 0          # x4 = accumulator = 0 / acumulador = 0
    addi  x5, x0, 0          # x5 = addition counter = 0 / contador de somas = 0

loop_mult:
    bge   x5, x3, fim_mult   # if we added x3 times, done / se somamos x3 vezes, acabou
    add   x4, x4, x2         # x4 += x2
    addi  x5, x5, 1          # counter++ / contador++
    jal   x0, loop_mult

fim_mult:
    addi  x2, x4, 0          # x2 = x4  (result of multiplication / resultado da multiplicação)

    addi  x3, x3, -1         # i--
    jal   x0, loop_principal

fim:
    jal   x0, fim            # halt
