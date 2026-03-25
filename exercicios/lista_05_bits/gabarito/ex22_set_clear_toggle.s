# =============================================================================
# Gabarito — Lista 5, Exercício 22: Set, Clear e Toggle de bits
# Answer key — List 5, Exercise 22: Set, Clear and Toggle bits
# =============================================================================
# Description / Descrição:
#   Given x1 = 0b10101010 = 0xAA = 170, perform three bit operations:
#   Dado x1 = 0b10101010 = 0xAA = 170, realize três operações de bit:
#
#   Set   bit 4: force bit 4 to 1 (regardless of current value)
#   Set   bit 4: coloca o bit 4 em 1 (independente do valor atual)
#   Clear bit 7: force bit 7 to 0 (regardless of current value)
#   Clear bit 7: coloca o bit 7 em 0 (independente do valor atual)
#   Toggle bit 1: invert bit 1 / Toggle bit 1: inverte o bit 1
#
# Techniques / Técnicas:
#   Set   bit N → x = x | (1 << N)     — OR with 1-bit mask / OR com máscara de 1 bit
#   Clear bit N → x = x & ~(1 << N)    — AND with inverted mask / AND com máscara invertida
#   Toggle bit N → x = x ^ (1 << N)    — XOR with 1-bit mask / XOR com máscara de 1 bit
#
# Calculation / Cálculo:
#   x1 = 0b10101010
#
#   Set bit 4:    0b10101010 | 0b00010000 = 0b10111010 = 0xBA = 186
#   Clear bit 7:  0b10101010 & 0b01111111 = 0b00101010 = 0x2A =  42
#   Toggle bit 1: 0b10101010 ^ 0b00000010 = 0b10101000 = 0xA8 = 168
#
# Expected result / Resultado esperado:
#   x2 = 186 (0xBA)   ← set bit 4
#   x3 =  42 (0x2A)   ← clear bit 7
#   x4 = 168 (0xA8)   ← toggle bit 1
#
# How to verify / Como verificar:
#   python3 ../../../simulator/riscv_sim.py ex22_set_clear_toggle.hex --run
# =============================================================================

.section .text
.global _start

_start:
    # ─── Input value / Valor de entrada ─────────────────────────────────────────────────
    addi  x1, x0, 0b10101010   # x1 = 0xAA = 170
    # Note: the assembler accepts binary literals with 0b prefix
    # Nota: o assembler aceita literais binários com 0b prefixo

    # ─── Set bit 4: x2 = x1 | (1 << 4) ─────────────────────────────────────────────
    addi  x5, x0, 1            # x5 = 1
    slli  x5, x5, 4            # x5 = 1 << 4 = 0b00010000 = 16
    or    x2, x1, x5           # x2 = 0b10101010 | 0b00010000 = 0b10111010 = 186

    # ─── Clear bit 7: x3 = x1 & ~(1 << 7) ──────────────────────────────────────────
    addi  x5, x0, 1            # x5 = 1
    slli  x5, x5, 7            # x5 = 1 << 7 = 0b10000000 = 128
    xori  x5, x5, -1           # x5 = ~x5 = 0b...01111111  (XOR with all 1s = NOT / XOR com todos 1s = NOT)
    and   x3, x1, x5           # x3 = 0b10101010 & 0b01111111 = 0b00101010 = 42

    # ─── Toggle bit 1: x4 = x1 ^ (1 << 1) ──────────────────────────────────────────
    addi  x5, x0, 1            # x5 = 1
    slli  x5, x5, 1            # x5 = 1 << 1 = 0b00000010 = 2
    xor   x4, x1, x5           # x4 = 0b10101010 ^ 0b00000010 = 0b10101000 = 168

fim:
    # x2 = 186 ✓  x3 = 42 ✓  x4 = 168 ✓
    jal   x0, fim              # halt / parada
