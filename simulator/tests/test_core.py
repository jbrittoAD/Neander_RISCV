#!/usr/bin/env python3
"""
=============================================================================
Testes unitários do simulador RISC-V RV32I
=============================================================================

Testa diretamente as operações da CPU injetando instruções codificadas
como valores inteiros de 32 bits — sem necessidade de compilador RISC-V.

Cobertura:
  - Funções utilitárias (to_u32, to_s32, sign_extend)
  - Memória (leitura, escrita, limites)
  - Instruções R-type (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
  - Instruções I-type arith (addi, slti, sltiu, xori, ori, andi, slli, srli, srai)
  - Instruções I-type load (lw, lh, lb, lhu, lbu)
  - Instruções S-type store (sw, sh, sb)
  - Instruções B-type branch (beq, bne, blt, bge, bltu, bgeu)
  - Instruções J-type (jal, jalr)
  - Instruções U-type (lui, auipc)
  - Comportamento especial: x0 sempre zero, halt, reset

Execução:
  python3 tests/test_core.py
  python3 -m pytest tests/test_core.py -v   (requer pytest)
=============================================================================
"""

import sys
import os
import struct
import unittest
import io

# Adiciona o diretório pai ao path para importar riscv_sim
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from riscv_sim import CPU, Memory, Simulator, to_u32, to_s32, sign_extend


# =============================================================================
# Helpers para codificação de instruções RISC-V
# (usados apenas nos testes — não fazem parte do simulador)
# =============================================================================

def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    """Codifica instrução R-type."""
    return ((funct7 & 0x7F) << 25 | (rs2 & 0x1F) << 20 |
            (rs1 & 0x1F) << 15  | (funct3 & 0x7) << 12 |
            (rd  & 0x1F) << 7   | (opcode & 0x7F))

def enc_i(imm12, rs1, funct3, rd, opcode):
    """Codifica instrução I-type."""
    return ((imm12 & 0xFFF) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12  | (rd  & 0x1F) << 7  |
            (opcode & 0x7F))

def enc_s(imm12, rs2, rs1, funct3, opcode):
    """Codifica instrução S-type."""
    imm_11_5 = (imm12 >> 5) & 0x7F
    imm_4_0  = imm12 & 0x1F
    return (imm_11_5 << 25 | (rs2 & 0x1F) << 20 | (rs1 & 0x1F) << 15 |
            (funct3 & 0x7) << 12 | imm_4_0 << 7 | (opcode & 0x7F))

def enc_b(imm13, rs2, rs1, funct3, opcode):
    """Codifica instrução B-type (imm13 em bytes, bit0 sempre 0)."""
    b12   = (imm13 >> 12) & 1
    b11   = (imm13 >> 11) & 1
    b10_5 = (imm13 >> 5)  & 0x3F
    b4_1  = (imm13 >> 1)  & 0xF
    return (b12 << 31 | b10_5 << 25 | (rs2 & 0x1F) << 20 |
            (rs1 & 0x1F) << 15 | (funct3 & 0x7) << 12 |
            b4_1 << 8 | b11 << 7 | (opcode & 0x7F))

def enc_u(imm20, rd, opcode):
    """Codifica instrução U-type (imm20 é o valor dos 20 bits superiores)."""
    return ((imm20 & 0xFFFFF) << 12 | (rd & 0x1F) << 7 | (opcode & 0x7F))

def enc_j(imm21, rd, opcode):
    """Codifica instrução J-type (imm21 em bytes, bit0 sempre 0)."""
    b20    = (imm21 >> 20) & 1
    b10_1  = (imm21 >> 1)  & 0x3FF
    b11    = (imm21 >> 11) & 1
    b19_12 = (imm21 >> 12) & 0xFF
    return (b20 << 31 | b19_12 << 12 | b11 << 11 |
            b10_1 << 1 | (rd & 0x1F) << 7 | (opcode & 0x7F))

# Opcodes padrão RISC-V
OP_LUI   = 0b0110111
OP_AUIPC = 0b0010111
OP_JAL   = 0b1101111
OP_JALR  = 0b1100111
OP_BR    = 0b1100011
OP_LOAD  = 0b0000011
OP_STORE = 0b0100011
OP_IMMED = 0b0010011
OP_REG   = 0b0110011

# Instrução de halt: jal x0, 0  (salta para si mesmo)
HALT = enc_j(0, 0, OP_JAL)


def make_cpu(instructions: list, harvard: bool = True) -> CPU:
    """
    Cria uma CPU com as instruções fornecidas já carregadas em imem.

    Args:
        instructions: Lista de inteiros de 32 bits (instruções codificadas).
        harvard: True para modo Harvard (padrão).

    Returns:
        CPU pronta para executar.
    """
    cpu = CPU(harvard=harvard)
    for i, instr in enumerate(instructions):
        addr = i * 4
        if harvard:
            struct.pack_into('<I', cpu.imem.data, addr, instr)
        else:
            struct.pack_into('<I', cpu.mem.data, addr, instr)
    return cpu


def run_prog(instructions: list, harvard: bool = True, max_steps: int = 1000) -> CPU:
    """
    Cria CPU, carrega instruções e executa até halt.

    A instrução HALT (jal x0, 0) é automaticamente adicionada ao final.
    """
    cpu = make_cpu(instructions + [HALT], harvard=harvard)
    cpu.run_until_halt(max_steps)
    return cpu


# =============================================================================
# Testes de utilitários
# =============================================================================

class TestUtils(unittest.TestCase):

    def test_to_u32_positive(self):
        self.assertEqual(to_u32(5), 5)

    def test_to_u32_large(self):
        self.assertEqual(to_u32(0x1_0000_0001), 1)

    def test_to_u32_negative(self):
        self.assertEqual(to_u32(-1), 0xFFFF_FFFF)

    def test_to_s32_positive(self):
        self.assertEqual(to_s32(5), 5)

    def test_to_s32_negative(self):
        self.assertEqual(to_s32(0xFFFF_FFFF), -1)

    def test_to_s32_min(self):
        self.assertEqual(to_s32(0x8000_0000), -2147483648)

    def test_sign_extend_positive(self):
        self.assertEqual(sign_extend(5, 12), 5)

    def test_sign_extend_negative(self):
        self.assertEqual(sign_extend(0xFFF, 12), -1)

    def test_sign_extend_boundary(self):
        self.assertEqual(sign_extend(0x800, 12), -2048)

    def test_sign_extend_zero(self):
        self.assertEqual(sign_extend(0, 12), 0)


# =============================================================================
# Testes de memória
# =============================================================================

class TestMemory(unittest.TestCase):

    def setUp(self):
        self.mem = Memory(64)  # 64 bytes para testes

    def test_read_write_byte(self):
        self.mem.write8(0, 0xAB)
        self.assertEqual(self.mem.read8(0), 0xAB)

    def test_read_write_halfword(self):
        self.mem.write16(0, 0xBEEF)
        self.assertEqual(self.mem.read16(0), 0xBEEF)

    def test_read_write_word(self):
        self.mem.write32(0, 0xDEAD_BEEF)
        self.assertEqual(self.mem.read32(0), 0xDEAD_BEEF)

    def test_little_endian_layout(self):
        """Verifica que word é armazenado em little-endian."""
        self.mem.write32(0, 0x12345678)
        self.assertEqual(self.mem.read8(0), 0x78)  # byte menos significativo
        self.assertEqual(self.mem.read8(1), 0x56)
        self.assertEqual(self.mem.read8(2), 0x34)
        self.assertEqual(self.mem.read8(3), 0x12)  # byte mais significativo

    def test_reset_zeros(self):
        self.mem.write32(0, 0xFFFF_FFFF)
        self.mem.reset()
        self.assertEqual(self.mem.read32(0), 0)

    def test_out_of_bounds_read(self):
        with self.assertRaises(MemoryError):
            self.mem.read32(62)  # 62+4 = 66 > 64, fora do limite

    def test_out_of_bounds_write(self):
        with self.assertRaises(MemoryError):
            self.mem.write32(62, 0)  # 62+4 = 66 > 64


# =============================================================================
# Testes R-type (instruções entre registradores)
# =============================================================================

class TestRType(unittest.TestCase):
    """
    Instruções: add, sub, and, or, xor, sll, srl, sra, slt, sltu
    """

    def _enc_r(self, f7, rs2, rs1, f3, rd):
        return enc_r(f7, rs2, rs1, f3, rd, OP_REG)

    def _prog(self, *instrs):
        return run_prog(list(instrs))

    def test_add(self):
        # x1=5, x2=3; add x3, x1, x2 → x3=8
        cpu = self._prog(
            enc_i(5,  0, 0, 1, OP_IMMED),   # addi x1, x0, 5
            enc_i(3,  0, 0, 2, OP_IMMED),   # addi x2, x0, 3
            self._enc_r(0, 2, 1, 0, 3),     # add  x3, x1, x2
        )
        self.assertEqual(cpu.regs[3], 8)

    def test_sub(self):
        cpu = self._prog(
            enc_i(10, 0, 0, 1, OP_IMMED),   # addi x1, x0, 10
            enc_i(3,  0, 0, 2, OP_IMMED),   # addi x2, x0, 3
            enc_r(0b0100000, 2, 1, 0, 3, OP_REG),  # sub x3, x1, x2
        )
        self.assertEqual(cpu.regs[3], 7)

    def test_sub_negative_result(self):
        cpu = self._prog(
            enc_i(3,  0, 0, 1, OP_IMMED),   # addi x1, x0, 3
            enc_i(10, 0, 0, 2, OP_IMMED),   # addi x2, x0, 10
            enc_r(0b0100000, 2, 1, 0, 3, OP_REG),  # sub x3, x1, x2 → -7
        )
        self.assertEqual(to_s32(cpu.regs[3]), -7)

    def test_and(self):
        cpu = self._prog(
            enc_i(0b1010, 0, 0, 1, OP_IMMED),
            enc_i(0b1100, 0, 0, 2, OP_IMMED),
            self._enc_r(0, 2, 1, 7, 3),     # and x3, x1, x2
        )
        self.assertEqual(cpu.regs[3], 0b1000)

    def test_or(self):
        cpu = self._prog(
            enc_i(0b1010, 0, 0, 1, OP_IMMED),
            enc_i(0b1100, 0, 0, 2, OP_IMMED),
            self._enc_r(0, 2, 1, 6, 3),     # or x3, x1, x2
        )
        self.assertEqual(cpu.regs[3], 0b1110)

    def test_xor(self):
        cpu = self._prog(
            enc_i(0b1010, 0, 0, 1, OP_IMMED),
            enc_i(0b1100, 0, 0, 2, OP_IMMED),
            self._enc_r(0, 2, 1, 4, 3),     # xor x3, x1, x2
        )
        self.assertEqual(cpu.regs[3], 0b0110)

    def test_sll(self):
        cpu = self._prog(
            enc_i(1, 0, 0, 1, OP_IMMED),    # x1 = 1
            enc_i(4, 0, 0, 2, OP_IMMED),    # x2 = 4
            self._enc_r(0, 2, 1, 1, 3),     # sll x3, x1, x2 → 1<<4 = 16
        )
        self.assertEqual(cpu.regs[3], 16)

    def test_srl(self):
        cpu = self._prog(
            enc_i(32, 0, 0, 1, OP_IMMED),   # x1 = 32
            enc_i(2,  0, 0, 2, OP_IMMED),   # x2 = 2
            self._enc_r(0, 2, 1, 5, 3),     # srl x3, x1, x2 → 32>>2 = 8
        )
        self.assertEqual(cpu.regs[3], 8)

    def test_sra_negative(self):
        """SRA deve preencher com o bit de sinal (aritmético)."""
        cpu = self._prog(
            enc_i(to_u32(-8) & 0xFFF, 0, 0, 1, OP_IMMED),  # addi x1, x0, -8
            enc_i(2, 0, 0, 2, OP_IMMED),                    # x2 = 2
            enc_r(0b0100000, 2, 1, 5, 3, OP_REG),           # sra x3, x1, x2 → -8>>2 = -2
        )
        self.assertEqual(to_s32(cpu.regs[3]), -2)

    def test_slt_true(self):
        cpu = self._prog(
            enc_i(to_u32(-1) & 0xFFF, 0, 0, 1, OP_IMMED),  # x1 = -1
            enc_i(1, 0, 0, 2, OP_IMMED),                    # x2 = 1
            self._enc_r(0, 2, 1, 2, 3),                     # slt x3, x1, x2 → 1 (-1<1)
        )
        self.assertEqual(cpu.regs[3], 1)

    def test_slt_false(self):
        cpu = self._prog(
            enc_i(5, 0, 0, 1, OP_IMMED),
            enc_i(3, 0, 0, 2, OP_IMMED),
            self._enc_r(0, 2, 1, 2, 3),                     # slt x3, x1, x2 → 0 (5≥3)
        )
        self.assertEqual(cpu.regs[3], 0)

    def test_sltu_treats_as_unsigned(self):
        """sltu deve tratar como unsigned: -1 (como uint) > 1."""
        cpu = self._prog(
            enc_i(1, 0, 0, 1, OP_IMMED),                    # x1 = 1
            enc_i(to_u32(-1) & 0xFFF, 0, 0, 2, OP_IMMED),  # x2 = -1 (como unsigned: 0xFFFFFFFF)
            self._enc_r(0, 2, 1, 3, 3),                     # sltu x3, x1, x2 → 1 (1 < 0xFFFFFFFF)
        )
        self.assertEqual(cpu.regs[3], 1)


# =============================================================================
# Testes I-type arith
# =============================================================================

class TestITypeArith(unittest.TestCase):

    def test_addi_positive(self):
        cpu = run_prog([enc_i(7, 0, 0, 1, OP_IMMED)])   # addi x1, x0, 7
        self.assertEqual(cpu.regs[1], 7)

    def test_addi_negative(self):
        cpu = run_prog([enc_i(to_u32(-5) & 0xFFF, 0, 0, 1, OP_IMMED)])
        self.assertEqual(to_s32(cpu.regs[1]), -5)

    def test_addi_accumulate(self):
        cpu = run_prog([
            enc_i(10, 0, 0, 1, OP_IMMED),   # x1 = 10
            enc_i(5,  1, 0, 1, OP_IMMED),   # x1 = x1 + 5 = 15
            enc_i(3,  1, 0, 1, OP_IMMED),   # x1 = x1 + 3 = 18
        ])
        self.assertEqual(cpu.regs[1], 18)

    def test_slti_true(self):
        cpu = run_prog([
            enc_i(to_u32(-10) & 0xFFF, 0, 0, 1, OP_IMMED),  # x1 = -10
            enc_i(0, 1, 2, 1, OP_IMMED),                      # slti x1, x1, 0 → 1 (-10<0)
        ])
        self.assertEqual(cpu.regs[1], 1)

    def test_sltiu_unsigned(self):
        """sltiu compara como unsigned após sign-extend do imediato."""
        cpu = run_prog([
            enc_i(5, 0, 0, 1, OP_IMMED),    # x1 = 5
            enc_i(10, 1, 3, 1, OP_IMMED),   # sltiu x1, x1, 10 → 1 (5 < 10)
        ])
        self.assertEqual(cpu.regs[1], 1)

    def test_xori_flip_bits(self):
        """xori com -1 inverte todos os bits."""
        cpu = run_prog([
            enc_i(0b1010, 0, 0, 1, OP_IMMED),               # x1 = 0b1010
            enc_i(to_u32(-1) & 0xFFF, 1, 4, 1, OP_IMMED),  # xori x1, x1, -1
        ])
        self.assertEqual(cpu.regs[1], to_u32(~0b1010))

    def test_ori(self):
        cpu = run_prog([
            enc_i(0b1010, 0, 0, 1, OP_IMMED),
            enc_i(0b0101, 1, 6, 1, OP_IMMED),    # ori x1, x1, 5
        ])
        self.assertEqual(cpu.regs[1], 0b1111)

    def test_andi(self):
        cpu = run_prog([
            enc_i(0xFF, 0, 0, 1, OP_IMMED),
            enc_i(0x0F, 1, 7, 1, OP_IMMED),      # andi x1, x1, 0x0F
        ])
        self.assertEqual(cpu.regs[1], 0x0F)

    def test_slli(self):
        cpu = run_prog([
            enc_i(1, 0, 0, 1, OP_IMMED),
            enc_i(3, 1, 1, 1, OP_IMMED),          # slli x1, x1, 3 → 8
        ])
        self.assertEqual(cpu.regs[1], 8)

    def test_srli(self):
        cpu = run_prog([
            enc_i(16, 0, 0, 1, OP_IMMED),
            enc_i(2,  1, 5, 1, OP_IMMED),         # srli x1, x1, 2 → 4
        ])
        self.assertEqual(cpu.regs[1], 4)

    def test_srai_sign_preserving(self):
        imm12_neg8 = to_u32(-8) & 0xFFF
        cpu = run_prog([
            enc_i(imm12_neg8, 0, 0, 1, OP_IMMED),              # x1 = -8
            enc_i((0x20 << 5) | 1, 1, 5, 1, OP_IMMED),        # srai x1, x1, 1
        ])
        self.assertEqual(to_s32(cpu.regs[1]), -4)


# =============================================================================
# Testes Load / Store
# =============================================================================

class TestLoadStore(unittest.TestCase):

    def test_sw_lw(self):
        """Store word, depois load word — deve recuperar o mesmo valor."""
        cpu = run_prog([
            enc_i(42,  0, 0, 1, OP_IMMED),                   # x1 = 42
            enc_s(0,   1, 0, 2, OP_STORE),                   # sw x1, 0(x0) → dmem[0]=42
            enc_i(0,   0, 2, 2, OP_LOAD),                    # lw x2, 0(x0)
        ])
        self.assertEqual(cpu.regs[2], 42)

    def test_sw_lw_offset(self):
        """Store com offset diferente de zero."""
        cpu = run_prog([
            enc_i(99, 0, 0, 1, OP_IMMED),                    # x1 = 99
            enc_s(8,  1, 0, 2, OP_STORE),                    # sw x1, 8(x0)
            enc_i(8,  0, 2, 2, OP_LOAD),                     # lw x2, 8(x0)
        ])
        self.assertEqual(cpu.regs[2], 99)

    def test_sb_lb_sign_extension(self):
        """lb deve fazer extensão de sinal para valores >= 0x80."""
        cpu = run_prog([
            enc_i(0xFF, 0, 0, 1, OP_IMMED),                  # x1 = 255
            enc_s(0,    1, 0, 0, OP_STORE),                  # sb x1, 0(x0)
            enc_i(0,    0, 0, 2, OP_LOAD),                   # lb x2, 0(x0) → -1
        ])
        self.assertEqual(to_s32(cpu.regs[2]), -1)

    def test_sb_lbu_no_sign_extension(self):
        """lbu NÃO deve fazer extensão de sinal."""
        cpu = run_prog([
            enc_i(0xFF, 0, 0, 1, OP_IMMED),                  # x1 = 255
            enc_s(0,    1, 0, 0, OP_STORE),                  # sb x1, 0(x0)
            enc_i(0,    0, 4, 2, OP_LOAD),                   # lbu x2, 0(x0) → 255
        ])
        self.assertEqual(cpu.regs[2], 255)

    def test_sh_lh(self):
        """Store halfword e load halfword com extensão de sinal."""
        # Usa LUI para construir 0x8000 em x1 (não cabe em imediato de 12 bits)
        # lui x1, 0x8 → x1 = 0x8000 (8 << 12)
        # Depois sh e lh: lh deve retornar -32768 (extensão de sinal do bit 15)
        cpu = run_prog([
            enc_u(8, 1, OP_LUI),         # lui x1, 8 → x1 = 0x8000 = 32768
            enc_s(0, 1, 0, 1, OP_STORE), # sh x1, 0(x0) → escreve 0x8000 como halfword
            enc_i(0, 0, 1, 2, OP_LOAD),  # lh x2, 0(x0) → -32768 (bit 15 = 1 → negativo)
        ])
        self.assertEqual(to_s32(cpu.regs[2]), -32768)

    def test_sh_lhu_no_sign_extension(self):
        """lhu não deve fazer extensão de sinal."""
        cpu = run_prog([
            enc_u(8, 1, OP_LUI),         # lui x1, 8 → x1 = 0x8000 = 32768
            enc_s(0, 1, 0, 1, OP_STORE), # sh x1, 0(x0)
            enc_i(0, 0, 5, 2, OP_LOAD),  # lhu x2, 0(x0) → 32768 (sem extensão de sinal)
        ])
        self.assertEqual(cpu.regs[2], 32768)


# =============================================================================
# Testes Branch
# =============================================================================

class TestBranch(unittest.TestCase):
    """
    Cada teste verifica se o branch é tomado ou não.
    Estratégia: se branch tomado → pula instrução que escreve em x3=1.
    Ao final: x3==0 se tomado, x3==1 se não tomado.
    """

    def _branch_taken_test(self, x1_val, x2_val, funct3) -> bool:
        """
        Retorna True se o branch foi tomado.

        Programa:
          0x00: addi x1, x0, x1_val
          0x04: addi x2, x0, x2_val
          0x08: branch x1, x2, +8    ← pula para 0x10 se tomado
          0x0C: addi x3, x0, 1       ← executado se NÃO tomado
          0x10: jal  x0, 0           ← halt
        """
        # Constrói imediatos (limitados a 12 bits)
        imm1 = to_u32(x1_val) & 0xFFF
        imm2 = to_u32(x2_val) & 0xFFF
        cpu = run_prog([
            enc_i(imm1, 0, 0, 1, OP_IMMED),    # addi x1, x0, x1_val
            enc_i(imm2, 0, 0, 2, OP_IMMED),    # addi x2, x0, x2_val
            enc_b(8, 2, 1, funct3, OP_BR),     # branch x1, x2, +8
            enc_i(1, 0, 0, 3, OP_IMMED),       # addi x3, x0, 1  (sentinel)
            # halt virá do run_prog automaticamente
        ], max_steps=20)
        return cpu.regs[3] == 0  # True = branch foi tomado (sentinel não executou)

    def test_beq_equal(self):
        self.assertTrue(self._branch_taken_test(5, 5, 0))   # beq, 5==5

    def test_beq_not_equal(self):
        self.assertFalse(self._branch_taken_test(5, 3, 0))  # beq, 5!=3

    def test_bne_not_equal(self):
        self.assertTrue(self._branch_taken_test(5, 3, 1))   # bne, 5!=3

    def test_bne_equal(self):
        self.assertFalse(self._branch_taken_test(5, 5, 1))  # bne, 5==5

    def test_blt_signed_less(self):
        # x1=-1 (0xFFF como imm12), x2=1; -1 < 1 → tomado
        taken = self._branch_taken_test(to_u32(-1) & 0xFFF, 1, 4)  # blt
        self.assertTrue(taken)

    def test_blt_signed_not_less(self):
        self.assertFalse(self._branch_taken_test(5, 3, 4))  # blt, 5>=3

    def test_bge_greater_or_equal(self):
        self.assertTrue(self._branch_taken_test(5, 3, 5))   # bge, 5>=3

    def test_bge_not_satisfied(self):
        taken = self._branch_taken_test(to_u32(-1) & 0xFFF, 1, 5)  # bge, -1 < 1
        self.assertFalse(taken)

    def test_bltu_unsigned(self):
        """bltu: x1=1, x2=0xFFF (positivo, mas testa unsigned). 1 < 0xFFF → tomado."""
        self.assertTrue(self._branch_taken_test(1, 0xFFF, 6))  # bltu

    def test_bgeu_unsigned(self):
        """bgeu: x1=0xFFF >= x2=1 → tomado."""
        self.assertTrue(self._branch_taken_test(0xFFF, 1, 7))  # bgeu


# =============================================================================
# Testes JAL / JALR
# =============================================================================

class TestJumps(unittest.TestCase):

    def test_jal_jumps_to_target(self):
        """JAL deve saltar para PC+imm e salvar PC+4 em rd."""
        # 0x00: addi x1, x0, 1      → x1=1 (executada)
        # 0x04: jal x2, +8          → x2=0x08, salta para 0x0C
        # 0x08: addi x1, x0, 99     → NÃO executada (pulada pelo jal)
        # 0x0C: halt
        cpu = run_prog([
            enc_i(1, 0, 0, 1, OP_IMMED),       # x1 = 1
            enc_j(8, 2, OP_JAL),                # jal x2, +8
            enc_i(99, 0, 0, 1, OP_IMMED),      # x1 = 99 (não executada)
        ], max_steps=10)
        self.assertEqual(cpu.regs[1], 1)         # x1 não foi sobrescrito
        self.assertEqual(cpu.regs[2], 0x08)      # link register = PC+4 = 4+4=8

    def test_jalr_jumps_to_register_plus_offset(self):
        """JALR salta para rs1 + imm, alinhado em 2 bytes."""
        # 0x00: addi x1, x0, 0x10   → x1 = 16
        # 0x04: jalr x2, x1, 0      → salta para x1+0=0x10, x2=0x08
        # 0x08: addi x3, x0, 42     → NÃO executada
        # 0x0C: addi x3, x0, 77     → NÃO executada
        # 0x10: halt (inserido por run_prog na posição 4)
        # A instrução halt fica em 0x10 (índice 4 na lista)
        cpu = run_prog([
            enc_i(0x10, 0, 0, 1, OP_IMMED),    # x1 = 0x10 = 16
            enc_i(0,    1, 0, 2, OP_JALR),     # jalr x2, x1, 0  → PC=0x10
            enc_i(42, 0, 0, 3, OP_IMMED),      # não executada
            enc_i(77, 0, 0, 3, OP_IMMED),      # não executada
        ], max_steps=10)
        self.assertEqual(cpu.regs[3], 0)         # instrução 42/77 não executou
        self.assertEqual(cpu.regs[2], 0x08)      # link = 0x04+4 = 0x08

    def test_jalr_clears_bit0(self):
        """JALR deve limpar o bit 0 do endereço de destino."""
        # x1 = 0x11 (endereço ímpar), jalr deve ir para 0x10
        cpu = make_cpu([
            enc_i(0x10, 0, 0, 1, OP_IMMED),    # x1 = 0x10
            enc_i(1,    1, 0, 0, OP_JALR),     # jalr x0, x1, 1 → (0x10+1)&~1 = 0x10
            enc_i(99, 0, 0, 3, OP_IMMED),      # não executada
            HALT,                               # @ 0x0C
            HALT,                               # @ 0x10 ← destino
        ])
        cpu.run_until_halt(10)
        self.assertEqual(cpu.regs[3], 0)


# =============================================================================
# Testes U-type (LUI, AUIPC)
# =============================================================================

class TestUType(unittest.TestCase):

    def test_lui(self):
        """LUI carrega o imediato nos 20 bits superiores de rd."""
        cpu = run_prog([enc_u(0xABCDE, 1, OP_LUI)])   # lui x1, 0xABCDE
        self.assertEqual(cpu.regs[1], 0xABCDE000)

    def test_lui_zero(self):
        cpu = run_prog([enc_u(0, 1, OP_LUI)])
        self.assertEqual(cpu.regs[1], 0)

    def test_auipc(self):
        """AUIPC soma imm<<12 com o PC atual."""
        # Na posição 0x00: auipc x1, 1 → x1 = 0x00 + (1<<12) = 0x1000
        cpu = run_prog([enc_u(1, 1, OP_AUIPC)])        # auipc x1, 1
        self.assertEqual(cpu.regs[1], 0x1000)

    def test_auipc_not_zero_pc(self):
        """AUIPC com PC != 0."""
        # 0x00: addi x0, x0, 0 (nop)
        # 0x04: auipc x1, 1 → x1 = 0x04 + 0x1000 = 0x1004
        cpu = run_prog([
            enc_i(0, 0, 0, 0, OP_IMMED),    # nop (addi x0, x0, 0)
            enc_u(1, 1, OP_AUIPC),           # auipc x1, 1
        ])
        self.assertEqual(cpu.regs[1], 0x1004)


# =============================================================================
# Testes de comportamento especial
# =============================================================================

class TestSpecialBehavior(unittest.TestCase):

    def test_x0_always_zero(self):
        """Escrita em x0 deve ser ignorada."""
        cpu = run_prog([enc_i(42, 0, 0, 0, OP_IMMED)])  # addi x0, x0, 42
        self.assertEqual(cpu.regs[0], 0)

    def test_halt_detection(self):
        """jal x0, 0 deve ser detectado como halt."""
        cpu = make_cpu([HALT])
        result = cpu.step()
        self.assertTrue(result['halted'])
        self.assertTrue(cpu._halted)

    def test_reset_clears_registers(self):
        cpu = run_prog([enc_i(99, 0, 0, 1, OP_IMMED)])
        self.assertEqual(cpu.regs[1], 99)
        cpu.reset()
        self.assertEqual(cpu.regs[1], 0)
        self.assertEqual(cpu.pc, 0)
        self.assertEqual(cpu.cycle, 0)

    def test_reset_reloads_program(self):
        """Após reset, CPU volta ao estado inicial mas mantém programa em memória."""
        # run_prog usa make_cpu (injeção direta), sem _hex_path — usa imem diretamente
        cpu = run_prog([
            enc_i(5, 0, 0, 1, OP_IMMED),   # x1=5
        ])
        self.assertEqual(cpu.regs[1], 5)
        self.assertEqual(cpu.pc, 4)  # HALT está em 0x04 (segundo word)
        # Reseta sem _hex_path: zera registradores, pc e ciclos, mas não limpa imem
        old_imem_data = bytes(cpu.imem.data)
        cpu.regs = [0] * 32
        cpu.pc = 0
        cpu.cycle = 0
        cpu._halted = False
        cpu.dmem.reset()
        # imem mantida (programa ainda lá)
        self.assertEqual(bytes(cpu.imem.data), old_imem_data)
        cpu.run_until_halt(10)
        self.assertEqual(cpu.regs[1], 5)

    def test_cycle_counter(self):
        """Contador de ciclos deve incrementar a cada instrução, incluindo halt."""
        cpu = run_prog([
            enc_i(1, 0, 0, 1, OP_IMMED),
            enc_i(2, 0, 0, 2, OP_IMMED),
            enc_i(3, 0, 0, 3, OP_IMMED),
        ])
        # 3 instruções úteis + 1 jal halt = 4 ciclos
        # (o halt (jal x0,0) também incrementa o ciclo antes de ser detectado)
        self.assertEqual(cpu.cycle, 4)

    def test_von_neumann_mode(self):
        """CPU em modo Von Neumann deve usar memória unificada."""
        cpu = CPU(harvard=False)
        self.assertIsNone(cpu.imem)
        self.assertIsNone(cpu.dmem)
        self.assertIsNotNone(cpu.mem)

    def test_step_result_contains_reg_write(self):
        """step() deve retornar as escritas em registradores."""
        cpu = make_cpu([enc_i(7, 0, 0, 1, OP_IMMED)])  # addi x1, x0, 7
        result = cpu.step()
        self.assertEqual(len(result['reg_writes']), 1)
        rd, old, new = result['reg_writes'][0]
        self.assertEqual(rd, 1)
        self.assertEqual(old, 0)
        self.assertEqual(new, 7)

    def test_step_result_contains_mem_write(self):
        """step() deve retornar as escritas em memória."""
        cpu = make_cpu([
            enc_i(42, 0, 0, 1, OP_IMMED),              # x1 = 42
            enc_s(0, 1, 0, 2, OP_STORE),               # sw x1, 0(x0)
        ])
        cpu.step()  # addi
        result = cpu.step()  # sw
        self.assertEqual(len(result['mem_writes']), 1)
        addr, nbytes, val = result['mem_writes'][0]
        self.assertEqual(addr, 0)
        self.assertEqual(nbytes, 4)
        self.assertEqual(val, 42)

    def test_disasm_addi(self):
        cpu = CPU()
        instr = enc_i(5, 0, 0, 1, OP_IMMED)   # addi x1, x0, 5
        dis = cpu.disasm(instr, 0)
        self.assertIn('addi', dis)
        self.assertIn('x1', dis)
        self.assertIn('5', dis)

    def test_disasm_branch_shows_target(self):
        cpu = CPU()
        # beq x1, x2, +8 (offset 8 bytes)
        instr = enc_b(8, 2, 1, 0, OP_BR)
        dis = cpu.disasm(instr, 0)
        self.assertIn('beq', dis)
        self.assertIn('0x8', dis)


# =============================================================================
# Teste de integração: programa aritmético completo
# =============================================================================

class TestIntegrationArith(unittest.TestCase):
    """
    Replica o programa test_arith.s em instruções codificadas.
    Verifica os mesmos resultados esperados pelo testbench Verilator.
    """

    def test_arith_program(self):
        cpu = run_prog([
            enc_i(5,  0, 0, 1, OP_IMMED),   # x1 = 5
            enc_i(3,  0, 0, 2, OP_IMMED),   # x2 = 3
            enc_r(0,  2, 1, 0, 3, OP_REG),  # x3 = x1+x2 = 8      (add)
            enc_r(0b0100000, 2, 1, 0, 4, OP_REG),  # x4 = x1-x2 = 2 (sub)
            enc_r(0,  2, 1, 7, 5, OP_REG),  # x5 = x1&x2 = 1      (and)
            enc_r(0,  2, 1, 6, 6, OP_REG),  # x6 = x1|x2 = 7      (or)
            enc_r(0,  2, 1, 4, 7, OP_REG),  # x7 = x1^x2 = 6      (xor)
            enc_i(5,  1, 0, 8, OP_IMMED),   # x8 = x1+5 = 10      (addi)
            enc_i(5,  2, 2, 9, OP_IMMED),   # x9 = 1 (3<5, slti)
            enc_i(2, 2, 1, 10, OP_IMMED),   # x10 = x2<<2 = 12    (slli)
            enc_i(1, 10, 5, 11, OP_IMMED),  # x11 = 12>>1 = 6     (srli)
            enc_i((0x20 << 5) | 1, 10, 5, 12, OP_IMMED),  # x12=6 (srai)
            enc_i(to_u32(-7) & 0xFFF, 0, 0, 13, OP_IMMED),  # x13 = -7
            enc_r(0, 0, 13, 2, 14, OP_REG), # x14 = slt(-7, 0)=1
            enc_r(0, 1, 0, 3, 15, OP_REG),  # x15 = sltu(0, 5)=1
        ], max_steps=20)

        self.assertEqual(cpu.regs[1],  5)
        self.assertEqual(cpu.regs[2],  3)
        self.assertEqual(cpu.regs[3],  8)
        self.assertEqual(cpu.regs[4],  2)
        self.assertEqual(cpu.regs[5],  1)
        self.assertEqual(cpu.regs[6],  7)
        self.assertEqual(cpu.regs[7],  6)
        self.assertEqual(cpu.regs[8],  10)
        self.assertEqual(cpu.regs[9],  1)
        self.assertEqual(cpu.regs[10], 12)
        self.assertEqual(cpu.regs[11], 6)
        self.assertEqual(cpu.regs[12], 6)
        self.assertEqual(to_s32(cpu.regs[13]), -7)
        self.assertEqual(cpu.regs[14], 1)
        self.assertEqual(cpu.regs[15], 1)


# =============================================================================
# Testes dos novos comandos do Simulator (watch, set, history)
# =============================================================================

def _make_sim(instructions):
    """Cria CPU + Simulator sem cores para captura de output."""
    cpu = make_cpu(instructions, harvard=True)
    return Simulator(cpu, color=False)


class TestSimulatorWatch(unittest.TestCase):
    """Testa o comando watch — monitora mudanças em registradores."""

    def test_watch_toggle_on(self):
        sim = _make_sim([enc_i(7, 0, 0, 1, OP_IMMED)])  # addi x1, x0, 7
        sim.cmd_watch(['x1'])
        self.assertIn(1, sim.watches)

    def test_watch_toggle_off(self):
        sim = _make_sim([enc_i(7, 0, 0, 1, OP_IMMED)])
        sim.watches.add(1)
        sim.cmd_watch(['x1'])
        self.assertNotIn(1, sim.watches)

    def test_watch_abi_name(self):
        sim = _make_sim([enc_i(7, 0, 0, 10, OP_IMMED)])  # a0 = x10
        sim.cmd_watch(['a0'])
        self.assertIn(10, sim.watches)

    def test_watch_mark_appears_in_fmt_step(self):
        sim = _make_sim([enc_i(7, 0, 0, 1, OP_IMMED)])
        sim.watches.add(1)
        result = sim.cpu.step()
        out = io.StringIO()
        sys.stdout, old = out, sys.stdout
        sim._fmt_step(result)
        sys.stdout = old
        self.assertIn('★ WATCH', out.getvalue())

    def test_watch_invalid_reg(self):
        sim = _make_sim([])
        out = io.StringIO()
        sys.stdout, old = out, sys.stdout
        sim.cmd_watch(['x99'])
        sys.stdout = old
        self.assertIn('inválido', out.getvalue())
        self.assertEqual(len(sim.watches), 0)


class TestSimulatorSet(unittest.TestCase):
    """Testa o comando set — define valor de registrador."""

    def test_set_decimal(self):
        sim = _make_sim([])
        sim.cmd_set(['x1', '42'])
        self.assertEqual(sim.cpu.regs[1], 42)

    def test_set_hex(self):
        sim = _make_sim([])
        sim.cmd_set(['a0', '0xFF'])
        self.assertEqual(sim.cpu.regs[10], 255)

    def test_set_abi_name(self):
        sim = _make_sim([])
        sim.cmd_set(['ra', '100'])
        self.assertEqual(sim.cpu.regs[1], 100)

    def test_set_x0_rejected(self):
        sim = _make_sim([])
        sim.cmd_set(['x0', '99'])
        self.assertEqual(sim.cpu.regs[0], 0)  # x0 permanece 0

    def test_set_negative(self):
        sim = _make_sim([])
        sim.cmd_set(['x5', '-1'])
        self.assertEqual(sim.cpu.regs[5], to_u32(-1))

    def test_set_missing_args(self):
        sim = _make_sim([])
        out = io.StringIO()
        sys.stdout, old = out, sys.stdout
        sim.cmd_set(['x1'])
        sys.stdout = old
        self.assertIn('Uso:', out.getvalue())


class TestSimulatorHistory(unittest.TestCase):
    """Testa o comando history — histórico de instruções executadas."""

    def test_history_accumulates(self):
        sim = _make_sim([
            enc_i(1, 0, 0, 1, OP_IMMED),  # addi x1, x0, 1
            enc_i(2, 0, 0, 2, OP_IMMED),  # addi x2, x0, 2
        ])
        # step silenciando output
        import io
        for _ in range(2):
            r = sim.cpu.step()
            out = io.StringIO()
            sys.stdout, old = out, sys.stdout
            sim._fmt_step(r)
            sys.stdout = old
        self.assertEqual(len(sim._history), 2)

    def test_history_limit(self):
        sim = _make_sim([enc_i(1, 0, 0, 1, OP_IMMED)] * 10)
        sim._history_max = 3
        for _ in range(5):
            r = sim.cpu.step()
            out = io.StringIO()
            sys.stdout, old = out, sys.stdout
            sim._fmt_step(r)
            sys.stdout = old
        self.assertLessEqual(len(sim._history), 3)

    def test_history_cleared_on_reset(self):
        sim = _make_sim([enc_i(1, 0, 0, 1, OP_IMMED)])
        r = sim.cpu.step()
        out = io.StringIO()
        sys.stdout, old = out, sys.stdout
        sim._fmt_step(r)
        sys.stdout = old
        self.assertEqual(len(sim._history), 1)
        sys.stdout, old = out, sys.stdout
        sim.cmd_reset([])
        sys.stdout = old
        self.assertEqual(len(sim._history), 0)

    def test_history_empty_message(self):
        sim = _make_sim([])
        out = io.StringIO()
        sys.stdout, old = out, sys.stdout
        sim.cmd_history([])
        sys.stdout = old
        self.assertIn('vazio', out.getvalue())


# =============================================================================
# Ponto de entrada
# =============================================================================

if __name__ == '__main__':
    # Executa com verbosidade se rodado diretamente
    unittest.main(verbosity=2)
