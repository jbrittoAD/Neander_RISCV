# =============================================================================
# Teste 4: Jumps (JAL e JALR) — RISC-V RV32I
#
# Layout de memória (endereços após montagem):
#   0x00  _start:    jal x1, func_a      → x1=0x04, salta para func_a
#   0x04  ret_a:     addi x5, x0, 77     → x5=77 (executado no retorno)
#   0x08             jal x0, test_jalr
#   0x0C  func_a:    addi x2, x0, 42     → x2=42
#   0x10             jalr x0, x1, 0      → retorna para ret_a (0x04)
#
#   0x14  test_jalr: addi x10, x0, 0     → x10 = endereço de func_b
#   0x18             auipc x10, 0        → x10 = PC (0x18)
#   0x1C             addi x10, x10, 16  → x10 = 0x18+16 = 0x28 = func_b
#   0x20             jalr x3, x10, 0    → x3=0x24, salta para func_b
#   0x24  ret_b:     jal x0, loop
#
#   0x28  func_b:    addi x4, x0, 99    → x4=99
#   0x2C             jalr x0, x3, 0     → retorna para ret_b (0x24)
#
#   0x30  loop:      jal x0, loop
#
# Resultado esperado:
#   x1  = 0x04  (link de JAL)
#   x2  = 42    (executado em func_a)
#   x3  = 0x24  (link de JALR)
#   x4  = 99    (executado em func_b)
#   x5  = 77    (executado após retorno de func_a)
# =============================================================================
.section .text
.global _start
_start:
    jal   x1,  func_a         # 0x00: x1=0x04, jump para func_a
ret_a:
    addi  x5,  x0, 77         # 0x04: x5=77 (ponto de retorno de func_a)
    jal   x0,  test_jalr      # 0x08: pula para test_jalr

func_a:                       # 0x0C
    addi  x2,  x0, 42         # x2 = 42
    jalr  x0,  x1, 0          # retorna para ret_a via x1

test_jalr:                    # 0x14
    auipc x10, 0              # x10 = PC (0x14 = endereço desta instrução)
    addi  x10, x10, 16        # x10 = 0x14 + 0x10 = 0x24 → aponta para func_b
    jalr  x3,  x10, 0         # x3 = 0x24 (PC+4 do jalr), salta para func_b
ret_b:
    jal   x0,  loop           # 0x24: vai para loop

func_b:                       # 0x28
    addi  x4,  x0, 99         # x4 = 99
    jalr  x0,  x3, 0          # retorna para ret_b via x3

loop:                         # 0x30
    jal   x0,  loop           # halt
