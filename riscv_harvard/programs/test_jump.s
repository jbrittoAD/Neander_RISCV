# =============================================================================
# Test 4: Jumps (JAL and JALR) — RISC-V RV32I
# Teste 4: Jumps (JAL e JALR) — RISC-V RV32I
#
# Memory layout (addresses after assembly):
# Layout de memória (endereços após montagem):
#   0x00  _start:    jal x1, func_a      → x1=0x04, jumps to func_a / salta para func_a
#   0x04  ret_a:     addi x5, x0, 77     → x5=77 (executed on return / executado no retorno)
#   0x08             jal x0, test_jalr
#   0x0C  func_a:    addi x2, x0, 42     → x2=42
#   0x10             jalr x0, x1, 0      → returns to ret_a (0x04) / retorna para ret_a (0x04)
#
#   0x14  test_jalr: addi x10, x0, 0     → x10 = address of func_b / endereço de func_b
#   0x18             auipc x10, 0        → x10 = PC (0x18)
#   0x1C             addi x10, x10, 16  → x10 = 0x18+16 = 0x28 = func_b
#   0x20             jalr x3, x10, 0    → x3=0x24, jumps to func_b / salta para func_b
#   0x24  ret_b:     jal x0, loop
#
#   0x28  func_b:    addi x4, x0, 99    → x4=99
#   0x2C             jalr x0, x3, 0     → returns to ret_b (0x24) / retorna para ret_b (0x24)
#
#   0x30  loop:      jal x0, loop
#
# Expected results:
# Resultado esperado:
#   x1  = 0x04  (JAL link / link de JAL)
#   x2  = 42    (executed in func_a / executado em func_a)
#   x3  = 0x24  (JALR link / link de JALR)
#   x4  = 99    (executed in func_b / executado em func_b)
#   x5  = 77    (executed after return from func_a / executado após retorno de func_a)
# =============================================================================
.section .text
.global _start
_start:
    jal   x1,  func_a         # 0x00: x1=0x04, jump to func_a / jump para func_a
ret_a:
    addi  x5,  x0, 77         # 0x04: x5=77 (return point of func_a / ponto de retorno de func_a)
    jal   x0,  test_jalr      # 0x08: jumps to test_jalr / pula para test_jalr

func_a:                       # 0x0C
    addi  x2,  x0, 42         # x2 = 42
    jalr  x0,  x1, 0          # returns to ret_a via x1 / retorna para ret_a via x1

test_jalr:                    # 0x14
    auipc x10, 0              # x10 = PC (0x14 = address of this instruction / endereço desta instrução)
    addi  x10, x10, 16        # x10 = 0x14 + 0x10 = 0x24 → points to func_b / aponta para func_b
    jalr  x3,  x10, 0         # x3 = 0x24 (PC+4 of jalr), jumps to func_b / salta para func_b
ret_b:
    jal   x0,  loop           # 0x24: goes to loop / vai para loop

func_b:                       # 0x28
    addi  x4,  x0, 99         # x4 = 99
    jalr  x0,  x3, 0          # returns to ret_b via x3 / retorna para ret_b via x3

loop:                         # 0x30
    jal   x0,  loop           # halt
