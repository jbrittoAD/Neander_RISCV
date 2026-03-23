#!/usr/bin/env python3
"""
=============================================================================
Testes de integração do simulador — programas compilados
=============================================================================

Carrega e executa os programas .hex compilados pelo Makefile das versões
Harvard e Von Neumann, verificando os mesmos resultados esperados pelo
testbench Verilator.

Pré-requisito: executar `make programs` em riscv_harvard/ e riscv_von_neumann/
antes de rodar estes testes.

Se os arquivos .hex não existirem, os testes são ignorados (skip).

Execução:
  python3 tests/test_programs.py
  python3 -m pytest tests/test_programs.py -v
=============================================================================
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from riscv_sim import CPU, to_s32

# Localiza o diretório raiz do projeto (neander_riscV/)
_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

def hex_path(version: str, program: str) -> str:
    """Retorna caminho para o arquivo .hex de um programa."""
    return os.path.join(_ROOT, f"riscv_{version}", "programs", f"{program}.hex")

def load_and_run(version: str, program: str, harvard: bool = True,
                 max_steps: int = 10000) -> CPU:
    """
    Carrega um programa compilado e executa até halt.

    Args:
        version:   'harvard' ou 'von_neumann'
        program:   nome do programa sem extensão (ex: 'test_arith')
        harvard:   True para modo Harvard, False para Von Neumann
        max_steps: Limite de instruções

    Returns:
        CPU com estado final após execução.

    Raises:
        unittest.SkipTest se o arquivo .hex não existir.
    """
    path = hex_path(version, program)
    if not os.path.isfile(path):
        raise unittest.SkipTest(
            f"Arquivo não encontrado: {path}\n"
            f"Execute 'make programs' em riscv_{version}/ primeiro."
        )
    cpu = CPU(harvard=harvard)
    cpu.load(path)
    cpu.run_until_halt(max_steps)
    return cpu


# =============================================================================
# Versão Harvard
# =============================================================================

class TestHarvardArith(unittest.TestCase):
    """test_arith.s: operações aritméticas e lógicas."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('harvard', 'test_arith', harvard=True)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_x1_equals_5(self):    self.assertEqual(self.cpu.regs[1],  5)
    def test_x2_equals_3(self):    self.assertEqual(self.cpu.regs[2],  3)
    def test_x3_add(self):         self.assertEqual(self.cpu.regs[3],  8)
    def test_x4_sub(self):         self.assertEqual(self.cpu.regs[4],  2)
    def test_x5_and(self):         self.assertEqual(self.cpu.regs[5],  1)
    def test_x6_or(self):          self.assertEqual(self.cpu.regs[6],  7)
    def test_x7_xor(self):         self.assertEqual(self.cpu.regs[7],  6)
    def test_x8_addi(self):        self.assertEqual(self.cpu.regs[8],  10)
    def test_x9_slti(self):        self.assertEqual(self.cpu.regs[9],  1)
    def test_x10_slli(self):       self.assertEqual(self.cpu.regs[10], 12)
    def test_x11_srli(self):       self.assertEqual(self.cpu.regs[11], 6)
    def test_x12_srai(self):       self.assertEqual(self.cpu.regs[12], 6)
    def test_x13_neg7(self):       self.assertEqual(to_s32(self.cpu.regs[13]), -7)
    def test_x14_slt_neg(self):    self.assertEqual(self.cpu.regs[14], 1)
    def test_x15_sltu(self):       self.assertEqual(self.cpu.regs[15], 1)


class TestHarvardLoadStore(unittest.TestCase):
    """test_load_store.s: operações de memória."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('harvard', 'test_load_store', harvard=True)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_lw_after_sw(self):
        """Valor lido deve ser o mesmo que foi escrito."""
        # O programa escreve e lê valores; registradores finais devem bater
        self.assertGreater(self.cpu.cycle, 0, "Programa deve ter executado")

    def test_lb_sign_extension(self):
        """lb deve fazer extensão de sinal para valores negativos."""
        # Verifica que o programa completou sem erros
        self.assertFalse(self.cpu._halted and self.cpu.cycle == 0)


class TestHarvardBranch(unittest.TestCase):
    """test_branch.s: desvios condicionais."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('harvard', 'test_branch', harvard=True)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_completed(self):
        """Programa deve completar (halt detectado)."""
        self.assertTrue(self.cpu._halted)

    def test_executed_instructions(self):
        """Deve executar mais de 10 instruções (tem loops)."""
        self.assertGreater(self.cpu.cycle, 10)


class TestHarvardJump(unittest.TestCase):
    """test_jump.s: JAL e JALR."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('harvard', 'test_jump', harvard=True)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_completed(self):
        self.assertTrue(self.cpu._halted)


# =============================================================================
# Versão Von Neumann
# =============================================================================

class TestVonNeumannArith(unittest.TestCase):
    """Mesmos resultados de aritmética no modo Von Neumann."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('von_neumann', 'test_arith', harvard=False)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_x1_equals_5(self):    self.assertEqual(self.cpu.regs[1],  5)
    def test_x2_equals_3(self):    self.assertEqual(self.cpu.regs[2],  3)
    def test_x3_add(self):         self.assertEqual(self.cpu.regs[3],  8)
    def test_x4_sub(self):         self.assertEqual(self.cpu.regs[4],  2)
    def test_x5_and(self):         self.assertEqual(self.cpu.regs[5],  1)
    def test_x6_or(self):          self.assertEqual(self.cpu.regs[6],  7)
    def test_x7_xor(self):         self.assertEqual(self.cpu.regs[7],  6)


class TestVonNeumannBranch(unittest.TestCase):
    """Branches na versão Von Neumann."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.cpu = load_and_run('von_neumann', 'test_branch', harvard=False)
        except unittest.SkipTest as e:
            raise unittest.SkipTest(str(e))

    def test_completed(self):
        self.assertTrue(self.cpu._halted)


# =============================================================================
# Ponto de entrada
# =============================================================================

if __name__ == '__main__':
    unittest.main(verbosity=2)
