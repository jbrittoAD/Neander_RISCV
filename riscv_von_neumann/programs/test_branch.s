# =============================================================================
# Teste 3: Branches — RISC-V RV32I
# Resultado esperado:
#   x1  = 5
#   x2  = 5
#   x3  = 99   (BEQ tomado → x3 não recebe 1)
#   x4  = 0    (BNE não tomado quando x1==x2)
#   x5  = 1    (BLT tomado: 3 < 5)
#   x6  = 1    (BGE tomado: 5 >= 5)
#   x7  = 1    (BLTU tomado: 0 < 0xFFFF sem sinal)
# =============================================================================
.section .text
.global _start
_start:
    addi  x1, x0,  5          # x1 = 5
    addi  x2, x0,  5          # x2 = 5

    # --- BEQ: x1 == x2 → deve pular addi x3,x0,1 ---
    beq   x1, x2, skip_eq     # BEQ: x1==x2 → pula
    addi  x3, x0,  1          # NÃO deve executar
skip_eq:
    addi  x3, x0,  99         # x3 = 99 (confirma que branch foi tomado)

    # --- BNE: x1 == x2 → NÃO deve pular ---
    bne   x1, x2, skip_ne     # BNE: x1==x2, não pula
    addi  x4, x0,  0          # x4 = 0 (BNE não foi tomado)
skip_ne:

    # --- BLT: 3 < 5 → deve pular para set_blt ---
    addi  x10, x0, 3          # x10 = 3
    blt   x10, x1, set_blt    # 3 < 5 → pula
    addi  x5,  x0, 0          # NÃO deve executar
    jal   x0,  skip_blt
set_blt:
    addi  x5,  x0, 1          # x5 = 1
skip_blt:

    # --- BGE: 5 >= 5 → deve pular ---
    bge   x1, x2, set_bge     # 5 >= 5 → pula
    addi  x6, x0, 0           # NÃO deve executar
    jal   x0, skip_bge
set_bge:
    addi  x6, x0, 1           # x6 = 1
skip_bge:

    # --- BLTU: 0 < 0xFFFF sem sinal → deve pular ---
    addi  x11, x0, -1         # x11 = 0xFFFFFFFF
    bltu  x0,  x11, set_bltu  # 0 < 0xFFFFFFFF sem sinal → pula
    addi  x7,  x0, 0
    jal   x0,  skip_bltu
set_bltu:
    addi  x7, x0, 1           # x7 = 1
skip_bltu:

loop:
    jal   x0, loop            # halt
