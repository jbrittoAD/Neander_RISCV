# =============================================================================
# Test 3: Branches — RISC-V RV32I
# Teste 3: Branches — RISC-V RV32I
# Expected results:
# Resultado esperado:
#   x1  = 5
#   x2  = 5
#   x3  = 99   (BEQ taken → x3 does not receive 1 / BEQ tomado → x3 não recebe 1)
#   x4  = 0    (BNE not taken when x1==x2 / BNE não tomado quando x1==x2)
#   x5  = 1    (BLT taken: 3 < 5 / BLT tomado: 3 < 5)
#   x6  = 1    (BGE taken: 5 >= 5 / BGE tomado: 5 >= 5)
#   x7  = 1    (BLTU taken: 0 < 0xFFFF unsigned / BLTU tomado: 0 < 0xFFFF sem sinal)
# =============================================================================
.section .text
.global _start
_start:
    addi  x1, x0,  5          # x1 = 5
    addi  x2, x0,  5          # x2 = 5

    # --- BEQ: x1 == x2 → should skip addi x3,x0,1 ---
    # --- BEQ: x1 == x2 → deve pular addi x3,x0,1 ---
    beq   x1, x2, skip_eq     # BEQ: x1==x2 → skip / pula
    addi  x3, x0,  1          # MUST NOT execute / NÃO deve executar
skip_eq:
    addi  x3, x0,  99         # x3 = 99 (confirms branch was taken / confirma que branch foi tomado)

    # --- BNE: x1 == x2 → MUST NOT skip ---
    # --- BNE: x1 == x2 → NÃO deve pular ---
    bne   x1, x2, skip_ne     # BNE: x1==x2, does not skip / não pula
    addi  x4, x0,  0          # x4 = 0 (BNE was not taken / BNE não foi tomado)
skip_ne:

    # --- BLT: 3 < 5 → should jump to set_blt ---
    # --- BLT: 3 < 5 → deve pular para set_blt ---
    addi  x10, x0, 3          # x10 = 3
    blt   x10, x1, set_blt    # 3 < 5 → skip / pula
    addi  x5,  x0, 0          # MUST NOT execute / NÃO deve executar
    jal   x0,  skip_blt
set_blt:
    addi  x5,  x0, 1          # x5 = 1
skip_blt:

    # --- BGE: 5 >= 5 → should skip ---
    # --- BGE: 5 >= 5 → deve pular ---
    bge   x1, x2, set_bge     # 5 >= 5 → skip / pula
    addi  x6, x0, 0           # MUST NOT execute / NÃO deve executar
    jal   x0, skip_bge
set_bge:
    addi  x6, x0, 1           # x6 = 1
skip_bge:

    # --- BLTU: 0 < 0xFFFF unsigned → should skip ---
    # --- BLTU: 0 < 0xFFFF sem sinal → deve pular ---
    addi  x11, x0, -1         # x11 = 0xFFFFFFFF
    bltu  x0,  x11, set_bltu  # 0 < 0xFFFFFFFF unsigned → skip / sem sinal → pula
    addi  x7,  x0, 0
    jal   x0,  skip_bltu
set_bltu:
    addi  x7, x0, 1           # x7 = 1
skip_bltu:

loop:
    jal   x0, loop            # halt
