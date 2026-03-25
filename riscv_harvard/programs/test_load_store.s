# =============================================================================
# Test 2: Load and Store — RISC-V RV32I
# Teste 2: Load e Store — RISC-V RV32I
# Expected results:
# Resultado esperado:
#   x1  = 100    (value to store / valor a armazenar)
#   x2  = 100    (read from memory — word / lido da memória — word)
#   x3  = 0x55   (stored byte / byte armazenado)
#   x4  = 0x55   (read via LBU / lido via LBU)
#   x5  = 0xAB   (byte value with negative sign extension / valor byte com sinal negativo em extensão)
#   x6  = -85    (LB with sign extension: 0xAB = -85 / LB com extensão de sinal: 0xAB = -85)
#   x7  = 0x1234 (stored half-word / half-word armazenada)
#   x8  = 0x1234 (LHU)
# =============================================================================
.section .text
.global _start
_start:
    # --- Word Test (LW / SW) ---
    # --- Teste Word (LW / SW) ---
    addi  x1, x0, 100        # x1 = 100
    sw    x1, 0(x0)          # mem[0] = 100
    lw    x2, 0(x0)          # x2 = mem[0] = 100

    # --- Unsigned Byte Test (LBU / SB) ---
    # --- Teste Byte sem sinal (LBU / SB) ---
    addi  x3, x0, 0x55       # x3 = 0x55
    sb    x3, 4(x0)          # mem[4] = 0x55
    lbu   x4, 4(x0)          # x4 = 0x55 (no sign extension / sem extensão de sinal)

    # --- Signed Byte Test (LB / SB) ---
    # --- Teste Byte com sinal (LB / SB) ---
    addi  x5, x0, -85        # x5 = -85 = 0xFFFFFFAB
    sb    x5, 8(x0)          # mem[8] = 0xAB (byte)
    lb    x6, 8(x0)          # x6 = sext(0xAB) = -85

    # --- Half-word Test (LH / SH) ---
    # --- Teste Half-word (LH / SH) ---
    addi  x7, x0,  0x12      # x7 = 0x12
    slli  x7, x7,  8         # x7 = 0x1200
    ori   x7, x7,  0x34      # x7 = 0x1234
    sh    x7, 12(x0)         # mem[12] = 0x1234
    lhu   x8, 12(x0)         # x8 = 0x1234

loop:
    jal   x0, loop           # halt
