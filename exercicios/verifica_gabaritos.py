#!/usr/bin/env python3
"""
=============================================================================
Verificador automático de gabaritos — RISC-V RV32I
=============================================================================

Compila e executa todos os 20 gabaritos de exercício usando o simulador
Python, verificando os resultados esperados automaticamente.

Não requer pytest — usa unittest padrão da biblioteca Python.

Uso:
    python3 exercicios/verifica_gabaritos.py          # run from project root
    python3 exercicios/verifica_gabaritos.py -v       # verbose

Pré-requisito: compilador RISC-V instalado (riscv64-unknown-elf-as)
Se o compilador não estiver disponível, o exercício é pulado (SkipTest).
=============================================================================
"""

import sys
import os
import struct
import subprocess
import tempfile
import unittest

# Caminho raiz do projeto (um nível acima deste script)
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Adiciona o simulador ao path
sys.path.insert(0, os.path.join(PROJECT_ROOT, 'simulator'))
from riscv_sim import CPU, Memory, to_u32, to_s32


# =============================================================================
# Helpers
# =============================================================================

def _toolchain_available() -> bool:
    """Verifica se o compilador RISC-V está instalado."""
    try:
        subprocess.run(['riscv64-unknown-elf-as', '--version'],
                       capture_output=True, timeout=5)
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def _compile_to_hex(asm_path: str) -> str:
    """
    Compila arquivo .s para .hex em diretório temporário.
    Retorna o caminho do .hex gerado.
    Lança subprocess.CalledProcessError em caso de erro de montagem.
    """
    tmpdir = tempfile.mkdtemp()
    base   = os.path.splitext(os.path.basename(asm_path))[0]
    obj    = os.path.join(tmpdir, base + '.o')
    binf   = os.path.join(tmpdir, base + '.bin')
    hexf   = os.path.join(tmpdir, base + '.hex')
    bin2hex = os.path.join(PROJECT_ROOT, 'riscv_harvard', 'scripts', 'bin2hex.py')

    subprocess.run(
        ['riscv64-unknown-elf-as', '-march=rv32i', '-mabi=ilp32', '-o', obj, asm_path],
        check=True, capture_output=True
    )
    subprocess.run(
        ['riscv64-unknown-elf-objcopy', '-O', 'binary', obj, binf],
        check=True, capture_output=True
    )
    subprocess.run(
        ['python3', bin2hex, binf, hexf],
        check=True, capture_output=True
    )
    return hexf


def _run(asm_path: str) -> CPU:
    """Compila o arquivo .s e executa no simulador. Retorna a CPU no estado final."""
    if not _toolchain_available():
        raise unittest.SkipTest("Compilador riscv64-unknown-elf-as não encontrado.")
    hexf = _compile_to_hex(asm_path)
    cpu  = CPU(harvard=True)
    cpu.load(hexf)
    cpu.run_until_halt()
    return cpu


def _gabarito(lista: str, nome: str) -> str:
    """Retorna o caminho absoluto do arquivo de gabarito."""
    return os.path.join(PROJECT_ROOT, 'exercicios', lista, 'gabarito', nome)


def _reg(cpu: CPU, n: int) -> int:
    """Retorna valor sem sinal do registrador n."""
    return cpu.regs[n]


def _mem_word(cpu: CPU, addr: int) -> int:
    """Retorna word de dados no endereço addr."""
    mem = cpu.dmem if cpu.harvard else cpu.mem
    return mem.read32(addr)


def _mem_byte(cpu: CPU, addr: int) -> int:
    """Retorna byte de dados no endereço addr."""
    mem = cpu.dmem if cpu.harvard else cpu.mem
    return mem.read8(addr)


# =============================================================================
# Lista 1 — Básico (Ex. 1–5)
# =============================================================================

class TestLista1(unittest.TestCase):

    def test_ex01_soma(self):
        """x3 = 42"""
        cpu = _run(_gabarito('lista_01_basico', 'ex01_soma.s'))
        self.assertEqual(_reg(cpu, 3), 42)

    def test_ex02_logico(self):
        """x3=130, x4=254, x5=124, x6=complemento de 202 (como uint32)"""
        cpu = _run(_gabarito('lista_01_basico', 'ex02_logico.s'))
        self.assertEqual(_reg(cpu, 3), 130)
        self.assertEqual(_reg(cpu, 4), 254)
        self.assertEqual(_reg(cpu, 5), 124)
        # NOT de 202 em 32 bits = 0xFFFFFF35 = 4294967093 (ou -203 signed)
        self.assertEqual(to_s32(_reg(cpu, 6)), -203)

    def test_ex03_shifts(self):
        """x2=8, x3=2, x4=signed(-8 como uint), x5=1073741816"""
        cpu = _run(_gabarito('lista_01_basico', 'ex03_shifts.s'))
        self.assertEqual(_reg(cpu, 2), 8)
        self.assertEqual(_reg(cpu, 3), 2)
        self.assertEqual(to_s32(_reg(cpu, 4)), -8)
        self.assertEqual(_reg(cpu, 5), 1073741816)

    def test_ex04_lui(self):
        """x1 = 0xDEAD1234"""
        cpu = _run(_gabarito('lista_01_basico', 'ex04_lui.s'))
        self.assertEqual(_reg(cpu, 1), 0xDEAD1234)

    def test_ex05_swap_xor(self):
        """x1=25, x2=10 (XOR swap)"""
        cpu = _run(_gabarito('lista_01_basico', 'ex05_swap_xor.s'))
        self.assertEqual(_reg(cpu, 1), 25)
        self.assertEqual(_reg(cpu, 2), 10)


# =============================================================================
# Lista 2 — Intermediário (Ex. 6–10)
# =============================================================================

class TestLista2(unittest.TestCase):

    def test_ex06_abs(self):
        """x2 = 42 (valor absoluto de -42)"""
        cpu = _run(_gabarito('lista_02_intermediario', 'ex06_abs.s'))
        self.assertEqual(_reg(cpu, 2), 42)

    def test_ex07_max(self):
        """x3 = 3 (máximo de 3 e 1 — ou máximo dos dois valores do ex)"""
        cpu = _run(_gabarito('lista_02_intermediario', 'ex07_max.s'))
        self.assertEqual(_reg(cpu, 3), 3)

    def test_ex08_soma_n(self):
        """x2 = 55 (soma 1..10)"""
        cpu = _run(_gabarito('lista_02_intermediario', 'ex08_soma_n.s'))
        self.assertEqual(_reg(cpu, 2), 55)

    def test_ex09_popcount(self):
        """x2 = 5 (popcount de 0b10110101 = 5 bits 1)"""
        cpu = _run(_gabarito('lista_02_intermediario', 'ex09_popcount.s'))
        self.assertEqual(_reg(cpu, 2), 5)

    def test_ex10_busca(self):
        """x2 = 2 (índice do 42 no array)"""
        cpu = _run(_gabarito('lista_02_intermediario', 'ex10_busca.s'))
        self.assertEqual(_reg(cpu, 2), 2)


# =============================================================================
# Lista 3 — Avançado (Ex. 11–15)
# =============================================================================

class TestLista3(unittest.TestCase):

    def test_ex11_soma_ponteiro(self):
        """x2 = 105"""
        cpu = _run(_gabarito('lista_03_avancado', 'ex11_soma_ponteiro.s'))
        self.assertEqual(_reg(cpu, 2), 105)

    def test_ex12_inverte_array(self):
        """mem = [5,4,3,2,1] (em words de 4 bytes a partir do endereço 0)"""
        cpu = _run(_gabarito('lista_03_avancado', 'ex12_inverte_array.s'))
        expected = [5, 4, 3, 2, 1]
        for i, val in enumerate(expected):
            self.assertEqual(_mem_word(cpu, i * 4), val,
                             msg=f"mem[{i*4}] deve ser {val}")

    def test_ex13_funcao_dobro(self):
        """x11=14 (dobro de 7), x10=42 (dobro de 21)"""
        cpu = _run(_gabarito('lista_03_avancado', 'ex13_funcao_dobro.s'))
        self.assertEqual(_reg(cpu, 11), 14)
        self.assertEqual(_reg(cpu, 10), 42)

    def test_ex14_funcao_fatorial(self):
        """x11=120 (5!), x10=6 (argumento original preservado)"""
        cpu = _run(_gabarito('lista_03_avancado', 'ex14_funcao_fatorial.s'))
        self.assertEqual(_reg(cpu, 11), 120)
        self.assertEqual(_reg(cpu, 10), 6)

    def test_ex15_fibonacci_check(self):
        """x3=34 (F(9)), x20=1 (verificação F(6)==8 passou)"""
        cpu = _run(_gabarito('lista_03_avancado', 'ex15_fibonacci_check.s'))
        self.assertEqual(_reg(cpu, 3),  34)
        self.assertEqual(_reg(cpu, 20),  1)


# =============================================================================
# Lista 4 — Expert (Ex. 16–20)
# =============================================================================

class TestLista4(unittest.TestCase):

    def test_ex16_fib_recursivo(self):
        """x10 = 21 (fib(8) recursivo)"""
        cpu = _run(_gabarito('lista_04_expert', 'ex16_fib_recursivo.s'))
        self.assertEqual(_reg(cpu, 10), 21)

    def test_ex17_fat_recursivo(self):
        """x10 = 720 (6! recursivo)"""
        cpu = _run(_gabarito('lista_04_expert', 'ex17_fat_recursivo.s'))
        self.assertEqual(_reg(cpu, 10), 720)

    def test_ex18_busca_binaria(self):
        """s0 (x8) = 6 (índice do 38 no array ordenado)"""
        cpu = _run(_gabarito('lista_04_expert', 'ex18_busca_binaria.s'))
        self.assertEqual(_reg(cpu, 8), 6)

    def test_ex19_string_reversa(self):
        """dmem = 'EDCBA\\0' (bytes 0x45,0x44,0x43,0x42,0x41,0x00)"""
        cpu = _run(_gabarito('lista_04_expert', 'ex19_string_reversa.s'))
        expected_bytes = [0x45, 0x44, 0x43, 0x42, 0x41, 0x00]  # "EDCBA\0"
        for i, b in enumerate(expected_bytes):
            self.assertEqual(_mem_byte(cpu, i), b,
                             msg=f"dmem[{i}] deve ser 0x{b:02x}")

    def test_ex20_mmc(self):
        """x3 = 36 (MMC(12,18)=36)"""
        cpu = _run(_gabarito('lista_04_expert', 'ex20_mmc.s'))
        self.assertEqual(_reg(cpu, 3), 36)


# =============================================================================
# Ponto de entrada
# =============================================================================

# =============================================================================
# Lista 5 — Bits (Ex. 21–23)
# =============================================================================

class TestLista5(unittest.TestCase):

    def test_ex21_extrai_campo(self):
        """x2 = 58 (bits [11:4] de 0x7AB4D3AF = 0x3A)"""
        cpu = _run(_gabarito('lista_05_bits', 'ex21_extrai_campo.s'))
        self.assertEqual(_reg(cpu, 2), 58)

    def test_ex22_set_clear_toggle(self):
        """x2=186 (set bit4), x3=42 (clear bit7), x4=168 (toggle bit1)"""
        cpu = _run(_gabarito('lista_05_bits', 'ex22_set_clear_toggle.s'))
        self.assertEqual(_reg(cpu, 2), 186)
        self.assertEqual(_reg(cpu, 3),  42)
        self.assertEqual(_reg(cpu, 4), 168)

    def test_ex23_pack_unpack(self):
        """x3=0x12345678, x4=0x1234, x5=0x5678"""
        cpu = _run(_gabarito('lista_05_bits', 'ex23_pack_unpack.s'))
        self.assertEqual(_reg(cpu, 3), 0x12345678)
        self.assertEqual(_reg(cpu, 4), 0x1234)
        self.assertEqual(_reg(cpu, 5), 0x5678)


# =============================================================================
# Capstone — Insertion Sort + Binary Search + Soma (Ex. único)
# =============================================================================

class TestCapstone(unittest.TestCase):

    def test_capstone(self):
        """x10=5 (índice de 23), x11=146 (soma), dmem=[4,5,8,11,16,23,37,42]"""
        cpu = _run(_gabarito('capstone', 'capstone.s'))
        self.assertEqual(_reg(cpu, 10), 5,   msg="x10 deve ser 5 (índice de 23)")
        self.assertEqual(_reg(cpu, 11), 146, msg="x11 deve ser 146 (soma do array)")
        expected = [4, 5, 8, 11, 16, 23, 37, 42]
        for i, val in enumerate(expected):
            self.assertEqual(_mem_word(cpu, i * 4), val,
                             msg=f"dmem[{i*4}] deve ser {val}")


def main():
    # Muda para o diretório raiz do projeto para que caminhos relativos funcionem
    os.chdir(PROJECT_ROOT)

    loader = unittest.TestLoader()
    suite  = unittest.TestSuite()
    for cls in [TestLista1, TestLista2, TestLista3, TestLista4, TestLista5, TestCapstone]:
        suite.addTests(loader.loadTestsFromTestCase(cls))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == '__main__':
    main()
