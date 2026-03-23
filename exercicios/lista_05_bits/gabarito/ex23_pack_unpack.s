# =============================================================================
# Gabarito — Lista 5, Exercício 23: Empacotar e desempacotar dois valores de 16 bits
# =============================================================================
# Descrição:
#   Dados dois valores de 16 bits, empacota-os em um único registrador de 32 bits.
#   Depois, desempacota os dois valores novamente.
#
#   Esse padrão é comum em sistemas embarcados e protocolos de comunicação onde
#   dois valores menores são transmitidos ou armazenados juntos.
#
# Entrada:
#   x1 = 0x1234  (valor alto — vai para os 16 bits superiores)
#   x2 = 0x5678  (valor baixo — fica nos 16 bits inferiores)
#
# Resultado esperado:
#   x3 = 0x12345678  ← empacotado: (x1 << 16) | x2
#   x4 = 0x1234      ← desempacota parte alta: x3 >> 16
#   x5 = 0x5678      ← desempacota parte baixa: x3 & 0xFFFF
#
# Técnicas:
#   Empacotar:
#     slli x_high, x1, 16    → desloca x1 para posição alta
#     or   x3, x_high, x2    → combina com x2 na posição baixa
#
#   Desempacotar parte alta:
#     srli x4, x3, 16        → desloca para direita 16 bits (lógico: zeros entram)
#
#   Desempacotar parte baixa:
#     slli x5, x3, 16        → apaga a parte alta (desloca o lixo para fora)
#     srli x5, x5, 16        → volta ao lugar, com zeros na parte alta
#     (equivale a: x5 = x3 & 0x0000FFFF, sem precisar de máscara de 16 bits)
#
# Por que não usar andi para a máscara?
#   O imediato de 12 bits do ANDI só chega até 0x7FF (2047) com sinal positivo.
#   0xFFFF = 65535 está fora do alcance. Usar double-shift é mais limpo no RV32I.
#
# Como verificar:
#   python3 ../../../simulator/riscv_sim.py ex23_pack_unpack.hex --run
# =============================================================================

.section .text
.global _start

_start:
    # ─── Valores de entrada ──────────────────────────────────────────────
    addi  x1, x0, 0x234        # x1 = 0x234 (parte baixa de 0x1234)
    lui   x6, 1                # x6 = 0x1000
    or    x1, x1, x6           # x1 = 0x1234  ← valor alto

    lui   x2, 0x5              # x2 = 0x5000
    addi  x2, x2, 0x678        # x2 = 0x5678  ← valor baixo

    # ─── Empacotar: x3 = (x1 << 16) | x2 ───────────────────────────────
    slli  x3, x1, 16           # x3 = 0x12340000  (x1 deslocado para parte alta)
    or    x3, x3, x2           # x3 = 0x12340000 | 0x5678 = 0x12345678

    # ─── Desempacotar parte alta: x4 = x3 >> 16 ─────────────────────────
    srli  x4, x3, 16           # x4 = 0x00001234  (zeros entram pela esquerda)

    # ─── Desempacotar parte baixa: x5 = x3 & 0xFFFF ─────────────────────
    slli  x5, x3, 16           # x5 = 0x56780000  (apaga os 16 bits altos)
    srli  x5, x5, 16           # x5 = 0x00005678  (coloca de volta, zeros no topo)

fim:
    # x3 = 0x12345678 ✓
    # x4 = 0x1234     ✓
    # x5 = 0x5678     ✓
    jal   x0, fim              # halt
