# =============================================================================
# Gabarito — Lista 3, Exercício 11: Soma de array com ponteiro
# =============================================================================
# Array: [5, 10, 15, 20, 25, 30]
# Resultado esperado: x2 = 105

.section .text
.global _start
_start:
    # ─── Inicializa array ─────────────────────────────────────────────
    addi  x1, x0, 0          # x1 = ponteiro = endereço base = 0

    addi  x10, x0, 5
    sw    x10, 0(x1)
    addi  x10, x0, 10
    sw    x10, 4(x1)
    addi  x10, x0, 15
    sw    x10, 8(x1)
    addi  x10, x0, 20
    sw    x10, 12(x1)
    addi  x10, x0, 25
    sw    x10, 16(x1)
    addi  x10, x0, 30
    sw    x10, 20(x1)

    # ─── Soma com ponteiro ────────────────────────────────────────────
    addi  x2, x0, 0          # x2 = soma = 0
    addi  x1, x0, 0          # x1 = ponteiro = base

    # x5 = endereço do fim = base + N*4 = 0 + 6*4 = 24
    addi  x5, x0, 24         # x5 = endereço fim (exclusivo)

loop:
    bge   x1, x5, fim        # se ponteiro >= fim, termina

    lw    x3, 0(x1)          # x3 = *ponteiro
    add   x2, x2, x3         # soma += x3
    addi  x1, x1, 4          # ponteiro++ (avança 4 bytes = 1 word)

    jal   x0, loop

fim:
    # x2 = 5+10+15+20+25+30 = 105 ✓
    jal   x0, fim
