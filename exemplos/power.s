# =============================================================================
# Potência (base^expoente) — RISC-V RV32I
# =============================================================================
#
# Calcula base^expoente usando multiplicação por somas repetidas.
# Como RV32I não possui instrução mul, a multiplicação é feita em um
# sub-loop que soma a base expoente vezes.
#
# Algoritmo:
#   resultado = 1
#   para i de 1 até expoente:
#       resultado = resultado * base        ← loop externo
#
#   multiplicação (resultado * base):
#       temp = 0
#       para j de 1 até base:
#           temp = temp + resultado         ← loop interno
#       resultado = temp
#
# Este exemplo demonstra:
# - Loop duplo (loop externo + sub-loop de multiplicação)
# - Multiplicação manual via somas repetidas (sem instrução mul)
# - Acumulador que parte de 1 e é multiplicado N vezes
#
# Mapeamento de registradores:
#   x1 = base            (entrada)
#   x2 = expoente        (entrada; decrementado pelo loop externo)
#   x3 = resultado       (acumulador final)
#   x4 = temp            (acumulador parcial do sub-loop de multiplicação)
#   x5 = contador do sub-loop de multiplicação (copia de x1 no início)
#
# Entrada:            x1 = 2, x2 = 10
# Resultado esperado: x3 = 1024  (2^10 = 1024)
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/power.hex
#   riscv> run
#   riscv> reg        ← x3 deve ser 1024
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicialização ────────────────────────────────────────────────
    addi  x1, x0, 2          # x1 = base = 2
    addi  x2, x0, 10         # x2 = expoente = 10
    addi  x3, x0, 1          # x3 = resultado = 1 (identidade da multiplicação)

    # ─── Loop externo: repete 'expoente' vezes ────────────────────────
loop_externo:
    beq   x2, x0, fim        # se expoente == 0, termina

    # Sub-loop: calcula resultado = resultado * base via somas
    addi  x4, x0, 0          # x4 = temp = 0 (acumulador parcial)
    add   x5, x0, x1         # x5 = contador = base (faz 'base' somas)

loop_mult:
    beq   x5, x0, fim_mult   # se contador == 0, multiplicação concluída
    add   x4, x4, x3         # temp = temp + resultado  (soma parcial)
    addi  x5, x5, -1         # contador--
    jal   x0, loop_mult      # repete sub-loop

fim_mult:
    add   x3, x0, x4         # resultado = temp  (atualiza resultado)
    addi  x2, x2, -1         # expoente--
    jal   x0, loop_externo   # próxima iteração do loop externo

fim:
    # x3 = 1024  (2^10)
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT)
