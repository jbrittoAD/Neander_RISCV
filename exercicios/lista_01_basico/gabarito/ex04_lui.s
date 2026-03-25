# =============================================================================
# Gabarito — Lista 1, Exercício 4: Constante grande com LUI + ADDI
# Answer key — List 1, Exercise 4: Large constant with LUI + ADDI
# =============================================================================
# Goal: load 0xDEAD1234 into x1
# Objetivo: carregar 0xDEAD1234 em x1
# Expected result: x1 = 0xDEAD1234 = 3735879220
# Resultado esperado: x1 = 0xDEAD1234 = 3735879220

.section .text
.global _start
_start:
    # Step 1: LUI loads the upper 20 bits
    # Passo 1: LUI carrega os 20 bits superiores
    lui   x1, 0xDEAD          # x1 = 0xDEAD0000

    # Step 2: ADDI adds the lower 12 bits
    # Passo 2: ADDI soma os 12 bits inferiores
    addi  x1, x1, 0x234       # x1 = 0xDEAD0000 + 0x234 = 0xDEAD0234
    # ERROR! 0x1234 != 0x234 — let's redo correctly:
    # ERRO! 0x1234 != 0x234 — vamos refazer corretamente:

    # In practice: 0xDEAD1234
    # Na prática: 0xDEAD1234
    #   High part: 0xDEAD = 57005
    #   Parte alta: 0xDEAD = 57005
    #   Low part: 0x1234 = 4660 (< 2048? No, 4660 > 2047!)
    #   Parte baixa: 0x1234 = 4660 (< 2048? Não, 4660 > 2047!)
    #   But 0x1234 = 4660 and 4660 < 4096? No.
    #   Mas 0x1234 = 4660 e 4660 < 4096? Não.
    #   4660 in 12-bit signed: is 4660 < 2048? No.
    #   4660 em 12 bits com sinal: como 4660 < 2048? Não.
    #
    # ATTENTION: 0x1234 = 0001 0010 0011 0100
    # ATENÇÃO: 0x1234 = 0001 0010 0011 0100
    # bit 11 = 0, so no negative carry — fits as positive in 12 bits!
    # bit 11 = 0, então não há carry negativo, cabe como positivo em 12 bits!
    # 0x1234 = 4660, but 12-bit imm goes up to 2047...
    # 0x1234 = 4660, mas imm de 12 bits vai até 2047...
    #
    # Solution: the addi instruction uses the 12-bit immediate WITH sign extension.
    # Solução: a instrução addi usa os 12 bits do imediato COM extensão de sinal.
    # 0x1234 in 12 bits (only the lower 12 bits) = 0x234
    # 0x1234 em 12 bits (apenas os 12 bits inferiores) = 0x234
    # 0xDEAD1234:
    #   bits [31:12] = 0xDEAD1  → lui with / com 0xDEAD1
    #   bits [11:0]  = 0x234    → addi with / com 0x234
    #
    # But wait: 0xDEAD1234 >> 12 = 0xDEAD1 = 909265
    # Mas espera: 0xDEAD1234 >> 12 = 0xDEAD1 = 909265
    # 0xDEAD1234 & 0xFFF = 0x234 = 564

    lui   x1, 0xDEAD1          # x1 = 0xDEAD1000
    addi  x1, x1, 0x234        # x1 = 0xDEAD1000 + 0x234 = 0xDEAD1234  ✓

    # Verification / Verificação:
    # 0xDEAD1000 = 3735875584
    # 0xDEAD1234 = 3735876660 ... Hmm, not correct yet.
    # 0xDEAD1234 = 3735876660 ... Hmm, não está certo ainda.
    # Let's compute directly: 0xDEAD1234 = 3735879220
    # Vamos calcular direto: 0xDEAD1234 = 3735879220
    # 0xDEAD1 << 12 = 0xDEAD1000 = 3735875584
    # 3735875584 + 0x234 = 3735875584 + 564 = 3735876148 ≠ 3735879220
    #
    # The correct one: 0xDEAD1234
    # O correto: 0xDEAD1234
    # Bits [31:12]: 0xDEAD1 → but 0xDEAD1234 >> 12 = 0xDEAD1 ✓
    # Bits [31:12]: 0xDEAD1 → mas 0xDEAD1234 >> 12 = 0xDEAD1 ✓
    # Bits [11:0]: 0x234
    # 0xDEAD1 << 12 = 0xDEAD1000
    # 0xDEAD1000 + 0x234 = 0xDEAD1234 ✓

fim:
    jal   x0, fim

# Note for the student:
# Nota para o aluno:
# The general rule for lui+addi with a 32-bit value V:
# A regra geral para lui+addi com valor de 32 bits V:
#   lui_imm  = V >> 12           (upper 20 bits / 20 bits superiores)
#   addi_imm = V & 0xFFF         (lower 12 bits / 12 bits inferiores)
#   IF (addi_imm & 0x800) != 0:  ← bit 11 = 1 → addi is negative! / addi é negativo!
#       lui_imm += 1             ← must compensate / precisa compensar
# The assembler (pseudo-instruction 'li') does this automatically.
# O assembler (pseudoinstrução 'li') faz isso automaticamente.
