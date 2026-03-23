# =============================================================================
# Gabarito — Lista 1, Exercício 3: Deslocamentos (shifts)
# =============================================================================
# x2 = 8  (1 << 3)
# x3 = 2  (8 >> 2, lógico)
# x4 = -8 (-32 >> 2, aritmético — preserva sinal)
# x5 = 0x3FFFFFF8  (-32 >> 2, lógico — não preserva sinal)

.section .text
.global _start
_start:
    addi  x1, x0, 1          # x1 = 1

    slli  x2, x1, 3          # x2 = 1 << 3 = 8     (shift left lógico)
    srli  x3, x2, 2          # x3 = 8 >> 2 = 2     (shift right lógico)

    addi  x10, x0, -32       # x10 = -32 (usado para x4 e x5)

    srai  x4, x10, 2         # x4 = -32 >> 2 = -8  (aritmético: preenche com sinal)
    srli  x5, x10, 2         # x5 = -32 >> 2 = 0x3FFFFFF8 (lógico: preenche com 0)

    # Ponto chave: -32 = 0xFFFFFFE0
    # srai (aritmético): 0xFFFFFFE0 >> 2 = 0xFFFFFFF8 = -8
    # srli (lógico):     0xFFFFFFE0 >> 2 = 0x3FFFFFF8 = 1073741816

fim:
    jal   x0, fim
