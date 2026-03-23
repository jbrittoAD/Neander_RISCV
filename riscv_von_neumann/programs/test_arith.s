# =============================================================================
# Teste 1: Aritmética Básica — RISC-V RV32I
# Resultado esperado após execução:
#   x1  = 5
#   x2  = 3
#   x3  = 8   (x1 + x2)
#   x4  = 2   (x1 - x2)
#   x5  = 1   (x1 & x2 = 0101 & 0011 = 0001)
#   x6  = 7   (x1 | x2 = 0101 | 0011 = 0111)
#   x7  = 6   (x1 ^ x2 = 0101 ^ 0011 = 0110)
#   x8  = 10  (addi: x1 + 5)
#   x9  = 1   (slt: x2 < x1 = 3 < 5 = 0, x1 < x2 invertido: usa x2 < x1)
#   x10 = 20  (sll: x2 << 2 = 3 << 2 = 12 ... ajustado)
# =============================================================================
.section .text
.global _start
_start:
    addi  x1,  x0,  5      # x1 = 5
    addi  x2,  x0,  3      # x2 = 3
    add   x3,  x1,  x2     # x3 = 8
    sub   x4,  x1,  x2     # x4 = 2
    and   x5,  x1,  x2     # x5 = 1
    or    x6,  x1,  x2     # x6 = 7
    xor   x7,  x1,  x2     # x7 = 6
    addi  x8,  x1,  5      # x8 = 10
    slti  x9,  x2,  5      # x9 = 1 (3 < 5)
    slli  x10, x2,  2      # x10 = 12 (3 << 2)
    srli  x11, x10, 1      # x11 = 6  (12 >> 1)
    srai  x12, x10, 1      # x12 = 6  (12 >> 1 arith)
    addi  x13, x0,  -7     # x13 = -7
    slt   x14, x13, x0     # x14 = 1 (-7 < 0 com sinal)
    sltu  x15, x0,  x1     # x15 = 1 (0 < 5 sem sinal)
loop:
    jal   x0,  loop        # loop infinito (halt)
