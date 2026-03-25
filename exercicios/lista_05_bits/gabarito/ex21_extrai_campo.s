# =============================================================================
# Gabarito — Lista 5, Exercício 21: Extração de campo de bits
# Answer key — List 5, Exercise 21: Bit field extraction
# =============================================================================
# Description / Descrição:
#   Given x1 = 0x7AB4D3AF, extract bits [11:4] (8 bits).
#   Dado x1 = 0x7AB4D3AF, extraia os bits [11:4] (8 bits).
#
# Technique / Técnica:
#   Step 1 / Passo 1: srli x2, x1, 4  → shifts x1 right 4 positions,
#                                        aligning the desired field at [7:0]
#                                        desloca x1 para a direita 4 posições,
#                                        alinhando o campo desejado em [7:0]
#   Step 2 / Passo 2: andi x2, x2, 0xFF → zeroes all bits above bit 7
#                                          (8-bit mask = 0xFF = 255)
#                                          zera todos os bits acima do bit 7
#                                          (máscara 8 bits = 0xFF = 255)
#
# Calculation / Cálculo:
#   x1 = 0x7AB4D3AF
#   0x7AB4D3AF >> 4 = 0x07AB4D3A
#   0x07AB4D3A & 0x000000FF = 0x3A = 58
#
# Expected result / Resultado esperado:
#   x2 = 58 (0x3A)   ← bits [11:4] of 0x7AB4D3AF / de 0x7AB4D3AF
#   x3 = 0 (verif.)  ← field zeroed above bit 7 / campo zerado acima do bit 7
#
# How to verify / Como verificar:
#   python3 ../../../simulator/riscv_sim.py ex21_extrai_campo.hex --run
#   # Verify: x2 = 58 / Verificar: x2 = 58
# =============================================================================

.section .text
.global _start

_start:
    # ─── Load input value / Carrega valor de entrada ────────────────────────────────────────
    lui   x1, 0x7AB4D       # x1[31:12] = 0x7AB4D000
    addi  x1, x1, 0x3AF     # CAUTION: 0x3AF = 943, positive → x1 = 0x7AB4D3AF / CUIDADO: 0x3AF = 943, positivo → x1 = 0x7AB4D3AF

    # ─── Extract bits [11:4] / Extrai bits [11:4] ──────────────────────────────────────────────
    srli  x2, x1, 4          # x2 = x1 >> 4 = 0x07AB4D3A  (logical: zeros enter / lógico: zeros entram)
    andi  x2, x2, 0xFF       # x2 = x2 & 0xFF = 0x3A = 58

    # ─── Verify bits above [7:0] are zeroed / Verifica que bits acima de [7:0] estão zerados ─────────────────
    srli  x3, x2, 8          # x3 = x2 >> 8; if x2 <= 0xFF then x3 = 0 / se x2 <= 0xFF, então x3 = 0

fim:
    # x2 = 58 (0x3A) ✓
    jal   x0, fim            # halt / parada
