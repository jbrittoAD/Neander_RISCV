# =============================================================================
# Gabarito — Lista 5, Exercício 21: Extração de campo de bits
# =============================================================================
# Descrição:
#   Dado x1 = 0x7AB4D3AF, extraia os bits [11:4] (8 bits).
#
# Técnica:
#   Passo 1: srli x2, x1, 4       → desloca x1 para a direita 4 posições,
#                                    alinhando o campo desejado em [7:0]
#   Passo 2: andi x2, x2, 0xFF    → zera todos os bits acima do bit 7
#                                    (máscara 8 bits = 0xFF = 255)
#
# Cálculo:
#   x1 = 0x7AB4D3AF
#   0x7AB4D3AF >> 4 = 0x07AB4D3A
#   0x07AB4D3A & 0x000000FF = 0x3A = 58
#
# Resultado esperado:
#   x2 = 58 (0x3A)   ← bits [11:4] de 0x7AB4D3AF
#   x3 = 0 (verif.)  ← campo zerado acima do bit 7
#
# Como verificar:
#   python3 ../../../simulator/riscv_sim.py ex21_extrai_campo.hex --run
#   # Verificar: x2 = 58
# =============================================================================

.section .text
.global _start

_start:
    # ─── Carrega valor de entrada ────────────────────────────────────────
    lui   x1, 0x7AB4D       # x1[31:12] = 0x7AB4D000
    addi  x1, x1, 0x3AF     # CUIDADO: 0x3AF = 943, positivo → x1 = 0x7AB4D3AF

    # ─── Extrai bits [11:4] ──────────────────────────────────────────────
    srli  x2, x1, 4          # x2 = x1 >> 4 = 0x07AB4D3A  (lógico: zeros entram)
    andi  x2, x2, 0xFF       # x2 = x2 & 0xFF = 0x3A = 58

    # ─── Verifica que bits acima de [7:0] estão zerados ─────────────────
    srli  x3, x2, 8          # x3 = x2 >> 8; se x2 ≤ 0xFF, então x3 = 0

fim:
    # x2 = 58 (0x3A) ✓
    jal   x0, fim            # halt
