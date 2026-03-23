# =============================================================================
# Fatorial iterativo — RISC-V RV32I
# =============================================================================
#
# Calcula N! (fatorial de N) de forma iterativa.
#
# Algoritmo:
#   result = 1
#   for i = N; i > 1; i--:
#       result = result * i   ← multiplicação via soma repetida
#
# ATENÇÃO: RISC-V RV32I não tem instrução de multiplicação (ela faz parte da
# extensão M). Aqui implementamos multiplicação com um sub-loop de somas.
# Isso demonstra como primitivas simples constroem operações complexas.
#
# Mapeamento de registradores:
#   x1  = N (número a calcular o fatorial)
#   x2  = resultado acumulado (começa em 1)
#   x3  = i (contador do loop principal, de N até 2)
#   x4  = acumulador temporário para multiplicação
#   x5  = contador do sub-loop de multiplicação
#
# Resultado esperado (N=5):
#   x2 = 120   (5! = 5 × 4 × 3 × 2 × 1 = 120)
#
# Outros exemplos:
#   N=1 → 1,  N=2 → 2,  N=3 → 6,  N=4 → 24,  N=6 → 720
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/factorial.hex
#   riscv> run
#   riscv> reg             ← x2 deve conter 120
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicialização ────────────────────────────────────────────────
    addi  x1, x0, 5          # x1 = N = 5  (mude aqui para testar outros valores)
    addi  x2, x0, 1          # x2 = resultado = 1 (caso base: 0! = 1! = 1)
    addi  x3, x1, 0          # x3 = i = N  (loop de N até 2)

loop_principal:
    addi  x6, x0, 2
    blt   x3, x6, fim        # se i < 2, termina (i==1 não muda o resultado)

    # ─── Multiplicação: x2 = x2 * x3 via somas repetidas ─────────────
    # Ideia: x4 = x2 + x2 + ... + x2  (x3 vezes)
    addi  x4, x0, 0          # x4 = acumulador = 0
    addi  x5, x0, 0          # x5 = contador de somas = 0

loop_mult:
    bge   x5, x3, fim_mult   # se somamos x3 vezes, acabou
    add   x4, x4, x2         # x4 += x2
    addi  x5, x5, 1          # contador++
    jal   x0, loop_mult

fim_mult:
    addi  x2, x4, 0          # x2 = x4  (resultado da multiplicação)

    addi  x3, x3, -1         # i--
    jal   x0, loop_principal

fim:
    jal   x0, fim            # halt
