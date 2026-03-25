# =============================================================================
# Gabarito — Lista 5, Exercício 23: Empacotar e desempacotar dois valores de 16 bits
# Answer key — List 5, Exercise 23: Pack and unpack two 16-bit values
# =============================================================================
# Description / Descrição:
#   Given two 16-bit values, packs them into a single 32-bit register.
#   Then, unpacks the two values again.
#   Dados dois valores de 16 bits, empacota-os em um único registrador de 32 bits.
#   Depois, desempacota os dois valores novamente.
#
#   This pattern is common in embedded systems and communication protocols where
#   two smaller values are transmitted or stored together.
#   Esse padrão é comum em sistemas embarcados e protocolos de comunicação onde
#   dois valores menores são transmitidos ou armazenados juntos.
#
# Input / Entrada:
#   x1 = 0x1234  (high value — goes into the upper 16 bits / valor alto — vai para os 16 bits superiores)
#   x2 = 0x5678  (low value — stays in the lower 16 bits / valor baixo — fica nos 16 bits inferiores)
#
# Expected result / Resultado esperado:
#   x3 = 0x12345678  ← packed: (x1 << 16) | x2 / empacotado: (x1 << 16) | x2
#   x4 = 0x1234      ← unpack high part: x3 >> 16 / desempacota parte alta: x3 >> 16
#   x5 = 0x5678      ← unpack low part: x3 & 0xFFFF / desempacota parte baixa: x3 & 0xFFFF
#
# Techniques / Técnicas:
#   Pack / Empacotar:
#     slli x_high, x1, 16    → shifts x1 to high position / desloca x1 para posição alta
#     or   x3, x_high, x2    → combines with x2 in low position / combina com x2 na posição baixa
#
#   Unpack high part / Desempacotar parte alta:
#     srli x4, x3, 16        → shift right 16 bits (logical: zeros enter / lógico: zeros entram)
#
#   Unpack low part / Desempacotar parte baixa:
#     slli x5, x3, 16        → clears high part (shifts noise out / apaga a parte alta — desloca o lixo para fora)
#     srli x5, x5, 16        → shifts back, with zeros in high part / volta ao lugar, com zeros na parte alta
#     (equivalent to: x5 = x3 & 0x0000FFFF, without needing a 16-bit mask)
#     (equivale a: x5 = x3 & 0x0000FFFF, sem precisar de máscara de 16 bits)
#
# Why not use andi for the mask? / Por que não usar andi para a máscara?
#   The 12-bit immediate of ANDI only reaches 0x7FF (2047) as a positive signed value.
#   O imediato de 12 bits do ANDI só chega até 0x7FF (2047) com sinal positivo.
#   0xFFFF = 65535 is out of range. Using double-shift is cleaner in RV32I.
#   0xFFFF = 65535 está fora do alcance. Usar double-shift é mais limpo no RV32I.
#
# How to verify / Como verificar:
#   python3 ../../../simulator/riscv_sim.py ex23_pack_unpack.hex --run
# =============================================================================

.section .text
.global _start

_start:
    # ─── Input values / Valores de entrada ──────────────────────────────────────────────
    addi  x1, x0, 0x234        # x1 = 0x234 (low part of 0x1234 / parte baixa de 0x1234)
    lui   x6, 1                # x6 = 0x1000
    or    x1, x1, x6           # x1 = 0x1234  ← high value / valor alto

    lui   x2, 0x5              # x2 = 0x5000
    addi  x2, x2, 0x678        # x2 = 0x5678  ← low value / valor baixo

    # ─── Pack: x3 = (x1 << 16) | x2 / Empacotar: x3 = (x1 << 16) | x2 ──────────────────────────────────────────────
    slli  x3, x1, 16           # x3 = 0x12340000  (x1 shifted to high position / x1 deslocado para parte alta)
    or    x3, x3, x2           # x3 = 0x12340000 | 0x5678 = 0x12345678

    # ─── Unpack high part: x4 = x3 >> 16 / Desempacotar parte alta: x4 = x3 >> 16 ───────────────────────────────────────
    srli  x4, x3, 16           # x4 = 0x00001234  (zeros enter from left / zeros entram pela esquerda)

    # ─── Unpack low part: x5 = x3 & 0xFFFF / Desempacotar parte baixa: x5 = x3 & 0xFFFF ────────────────────────────────────────
    slli  x5, x3, 16           # x5 = 0x56780000  (clears high 16 bits / apaga os 16 bits altos)
    srli  x5, x5, 16           # x5 = 0x00005678  (puts back in place, zeros on top / coloca de volta, zeros no topo)

fim:
    # x3 = 0x12345678 ✓
    # x4 = 0x1234     ✓
    # x5 = 0x5678     ✓
    jal   x0, fim              # halt / parada
