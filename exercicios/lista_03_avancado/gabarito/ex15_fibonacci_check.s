# =============================================================================
# Gabarito — Lista 3, Exercício 15: Fibonacci com verificação
# Answer key — List 3, Exercise 15: Fibonacci with verification
# =============================================================================
# Computes F(0)..F(9) and checks whether F(6) == 8
# Calcula F(0)..F(9) e verifica se F(6) == 8
# Expected results / Resultados esperados:
#   x3  = 34  (last term = F(9) / último termo = F(9))
#   x20 = 1   (verification passed: mem[24] == 8 / verificação passou: mem[24] == 8)

.section .text
.global _start
_start:
    # ─── Initialization / Inicialização ────────────────────────────────────────────────
    addi  x5, x0, 10         # N = 10 terms / 10 termos
    addi  x6, x0, 0          # base address = 0 / endereço base = 0

    addi  x2, x0, 0          # F(0) = 0
    addi  x3, x0, 1          # F(1) = 1

    sw    x2, 0(x6)          # mem[0] = F(0) = 0
    sw    x3, 4(x6)          # mem[4] = F(1) = 1

    addi  x1, x0, 2          # i = 2
    addi  x7, x6, 8          # current address = base + 8 / endereço atual = base + 8

loop:
    bge   x1, x5, verifica   # if i >= 10, go to verification / se i >= 10, vai para verificação

    add   x4, x2, x3         # x4 = F(i) = F(i-2) + F(i-1)
    sw    x4, 0(x7)          # mem[x7] = F(i)

    addi  x2, x3, 0          # x2 = F(i-1)
    addi  x3, x4, 0          # x3 = F(i)

    addi  x1, x1, 1          # i++
    addi  x7, x7, 4          # advance pointer / avança ponteiro

    jal   x0, loop

verifica:
    # Check: mem[6*4] = mem[24] should be 8 (F(6))
    # Verifica: mem[6*4] = mem[24] deve ser 8 (F(6))
    lw    x15, 24(x6)        # x15 = mem[24] = F(6)
    addi  x16, x0, 8         # x16 = expected value = 8 / valor esperado = 8

    addi  x20, x0, 0         # x20 = 0 (assumes failure / pressupõe falha)
    beq   x15, x16, correto  # if F(6) == 8, correct! / se F(6) == 8, correto!
    jal   x0, fim

correto:
    addi  x20, x0, 1         # x20 = 1 (verification passed / verificação passou)

fim:
    # x3  = 34 (F(9) was the last computed before i=10 / F(9) foi o último calculado antes de i=10)
    # x20 = 1  ✓
    jal   x0, fim
