# =============================================================================
# Teste 2: Load e Store — RISC-V RV32I (Von Neumann)
#
# DIFERENÇA CRÍTICA em relação à versão Harvard:
#   Na Arquitetura Von Neumann, instruções e dados compartilham o MESMO
#   espaço de memória. Por isso, os dados devem ser armazenados em endereços
#   ALÉM do código (para não sobrescrever as instruções).
#   Usamos 0x1000 (4096 bytes) como base de dados.
#
# Resultado esperado:
#   x1  = 100    (valor a armazenar)
#   x2  = 100    (lido da memória — word)
#   x3  = 0x55   (byte armazenado)
#   x4  = 0x55   (lido via LBU)
#   x5  = 0xAB   (valor byte com sinal negativo em extensão)
#   x6  = -85    (LB com extensão de sinal: 0xAB = -85)
#   x7  = 0x1234 (half-word armazenada)
#   x8  = 0x1234 (LHU)
# =============================================================================
.section .text
.global _start
_start:
    # Configura base de dados em 0x1000 (área segura, além do código)
    lui   x20, 1              # x20 = 0x00001000

    # --- Teste Word (LW / SW) ---
    addi  x1, x0, 100         # x1 = 100
    sw    x1, 0(x20)          # mem[0x1000] = 100
    lw    x2, 0(x20)          # x2 = 100

    # --- Teste Byte sem sinal (LBU / SB) ---
    addi  x3, x0, 0x55        # x3 = 0x55
    sb    x3, 4(x20)          # mem[0x1004] = 0x55
    lbu   x4, 4(x20)          # x4 = 0x55

    # --- Teste Byte com sinal (LB / SB) ---
    addi  x5, x0, -85         # x5 = -85 = 0xFFFFFFAB
    sb    x5, 8(x20)          # mem[0x1008] = 0xAB
    lb    x6, 8(x20)          # x6 = sext(0xAB) = -85

    # --- Teste Half-word (LHU / SH) ---
    addi  x7, x0,  0x12
    slli  x7, x7,  8
    ori   x7, x7,  0x34       # x7 = 0x1234
    sh    x7, 12(x20)         # mem[0x100C] = 0x1234
    lhu   x8, 12(x20)         # x8 = 0x1234

loop:
    jal   x0, loop            # halt
