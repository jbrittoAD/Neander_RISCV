# =============================================================================
# Test 2: Load and Store — RISC-V RV32I (Von Neumann)
# Teste 2: Load e Store — RISC-V RV32I (Von Neumann)
#
# CRITICAL DIFFERENCE from the Harvard version:
# DIFERENÇA CRÍTICA em relação à versão Harvard:
#   In the Von Neumann architecture, instructions and data share the SAME
#   Na Arquitetura Von Neumann, instruções e dados compartilham o MESMO
#   memory space. Therefore, data must be stored at addresses BEYOND the
#   espaço de memória. Por isso, os dados devem ser armazenados em endereços
#   code (to avoid overwriting instructions).
#   ALÉM do código (para não sobrescrever as instruções).
#   We use 0x1000 (4096 bytes) as the data base address.
#   Usamos 0x1000 (4096 bytes) como base de dados.
#
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
    # Set data base at 0x1000 (safe area, beyond code) / Configura base de dados em 0x1000 (área segura, além do código)
    lui   x20, 1              # x20 = 0x00001000

    # --- Word Test (LW / SW) ---
    # --- Teste Word (LW / SW) ---
    addi  x1, x0, 100         # x1 = 100
    sw    x1, 0(x20)          # mem[0x1000] = 100
    lw    x2, 0(x20)          # x2 = 100

    # --- Unsigned Byte Test (LBU / SB) ---
    # --- Teste Byte sem sinal (LBU / SB) ---
    addi  x3, x0, 0x55        # x3 = 0x55
    sb    x3, 4(x20)          # mem[0x1004] = 0x55
    lbu   x4, 4(x20)          # x4 = 0x55

    # --- Signed Byte Test (LB / SB) ---
    # --- Teste Byte com sinal (LB / SB) ---
    addi  x5, x0, -85         # x5 = -85 = 0xFFFFFFAB
    sb    x5, 8(x20)          # mem[0x1008] = 0xAB
    lb    x6, 8(x20)          # x6 = sext(0xAB) = -85

    # --- Half-word Test (LHU / SH) ---
    # --- Teste Half-word (LHU / SH) ---
    addi  x7, x0,  0x12
    slli  x7, x7,  8
    ori   x7, x7,  0x34       # x7 = 0x1234
    sh    x7, 12(x20)         # mem[0x100C] = 0x1234
    lhu   x8, 12(x20)         # x8 = 0x1234

loop:
    jal   x0, loop            # halt
