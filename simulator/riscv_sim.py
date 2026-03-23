#!/usr/bin/env python3
"""
=============================================================================
Simulador Interativo RISC-V RV32I
=============================================================================

Simula o processador RISC-V ciclo a ciclo com interface de linha de comando.
Suporta as 37 instruções base RV32I, modos Harvard e Von Neumann.

Uso básico:
    python3 riscv_sim.py programa.hex          # modo Harvard (padrão)
    python3 riscv_sim.py programa.hex --vn     # modo Von Neumann
    python3 riscv_sim.py programa.hex --run    # executa sem parar e imprime registradores

Comandos interativos:
    step [n]          Executa n instruções (padrão: 1)   | s
    run               Executa até halt ou breakpoint      | r
    reg               Mostra registradores                | regs
    mem <addr> [n]    Mostra n words de dados             | m
    imem [addr] [n]   Mostra n words de instruções        | i
    bp <addr>         Ativa/desativa breakpoint
    bps               Lista breakpoints
    watch [<reg>]     Monitora mudanças em registrador    | w
    set <reg> <val>   Define valor de registrador
    history [n]       Últimas n instruções executadas     | hist
    load <arquivo>    Carrega novo programa .hex
    reset             Reinicia CPU (mantém programa)
    trace [on|off]    Ativa/desativa trace automático
    help              Ajuda                               | h
    quit              Sai                                 | q, exit

Autor: Projeto Neander-RISC-V (educacional)
=============================================================================
"""

import sys
import os
import struct
import argparse

# readline pode não estar disponível em todos os ambientes
try:
    import readline
    _READLINE = True
except ImportError:
    _READLINE = False

# =============================================================================
# Cores ANSI para terminal
# =============================================================================

_COLORS = {
    'reset':  '\033[0m',
    'bold':   '\033[1m',
    'dim':    '\033[2m',
    'red':    '\033[31m',
    'green':  '\033[32m',
    'yellow': '\033[33m',
    'cyan':   '\033[36m',
    'white':  '\033[37m',
}

def _c(text: str, *keys, enabled: bool = True) -> str:
    """Aplica cores ANSI ao texto."""
    if not enabled:
        return text
    prefix = ''.join(_COLORS.get(k, '') for k in keys)
    return f"{prefix}{text}{_COLORS['reset']}"


# =============================================================================
# Nomes ABI dos registradores (x0..x31)
# =============================================================================

REGS_ABI = [
    'zero', 'ra',  'sp',  'gp',  'tp',  't0',  't1',  't2',
    's0',   's1',  'a0',  'a1',  'a2',  'a3',  'a4',  'a5',
    'a6',   'a7',  's2',  's3',  's4',  's5',  's6',  's7',
    's8',   's9',  's10', 's11', 't3',  't4',  't5',  't6',
]


# =============================================================================
# Funções auxiliares de aritmética de 32 bits
# =============================================================================

def to_u32(x: int) -> int:
    """Trunca inteiro para 32 bits sem sinal."""
    return x & 0xFFFF_FFFF


def to_s32(x: int) -> int:
    """Interpreta inteiro de 32 bits como com sinal (complemento de 2)."""
    x = x & 0xFFFF_FFFF
    return x - 0x1_0000_0000 if x >= 0x8000_0000 else x


def sign_extend(value: int, bits: int) -> int:
    """Extensão de sinal: interpreta 'value' como inteiro de 'bits' bits com sinal."""
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


# =============================================================================
# Classe Memory — memória byte-endereçável
# =============================================================================

class Memory:
    """
    Memória byte-endereçável de tamanho fixo.

    Internamente armazena os dados em um bytearray. Suporta leitura e escrita
    de 1, 2 e 4 bytes em formato little-endian (convenção RISC-V).
    """

    def __init__(self, size: int = 4096):
        """
        Args:
            size: Tamanho em bytes (padrão 4096 = 4 KB).
        """
        self.size = size
        self.data = bytearray(size)

    def reset(self):
        """Limpa toda a memória (preenche com zeros)."""
        self.data = bytearray(self.size)

    def load_hex(self, path: str):
        """
        Carrega arquivo .hex no formato $readmemh do SystemVerilog.

        Formato esperado: uma palavra de 32 bits por linha, em hexadecimal,
        sem prefixo '0x'. Exemplo: '00500093'

        A palavra na linha i é armazenada no endereço de byte i*4,
        em formato little-endian.
        """
        self.reset()
        with open(path) as f:
            for i, line in enumerate(f):
                line = line.strip()
                if not line or line.startswith('//') or line.startswith('#'):
                    continue
                try:
                    word = int(line, 16)
                except ValueError:
                    continue
                addr = i * 4
                if addr + 4 > self.size:
                    raise OverflowError(
                        f"Programa excede tamanho da memória ({self.size} bytes). "
                        f"Linha {i+1} → endereço 0x{addr:04x}."
                    )
                struct.pack_into('<I', self.data, addr, word)

    # ── Leituras ──────────────────────────────────────────────────────────────

    def read8(self, addr: int) -> int:
        """Lê 1 byte sem sinal no endereço 'addr'."""
        addr = to_u32(addr)
        if addr >= self.size:
            raise MemoryError(f"Leitura fora dos limites: 0x{addr:08x} (memória de {self.size} bytes)")
        return self.data[addr]

    def read16(self, addr: int) -> int:
        """Lê 2 bytes sem sinal (little-endian) no endereço 'addr'."""
        addr = to_u32(addr)
        if addr + 2 > self.size:
            raise MemoryError(f"Leitura fora dos limites: 0x{addr:08x}")
        return struct.unpack_from('<H', self.data, addr)[0]

    def read32(self, addr: int) -> int:
        """Lê 4 bytes sem sinal (little-endian) no endereço 'addr'."""
        addr = to_u32(addr)
        if addr + 4 > self.size:
            raise MemoryError(f"Leitura fora dos limites: 0x{addr:08x}")
        return struct.unpack_from('<I', self.data, addr)[0]

    # ── Escritas ──────────────────────────────────────────────────────────────

    def write8(self, addr: int, value: int):
        """Escreve 1 byte no endereço 'addr'."""
        addr = to_u32(addr)
        if addr >= self.size:
            raise MemoryError(f"Escrita fora dos limites: 0x{addr:08x}")
        self.data[addr] = value & 0xFF

    def write16(self, addr: int, value: int):
        """Escreve 2 bytes (little-endian) no endereço 'addr'."""
        addr = to_u32(addr)
        if addr + 2 > self.size:
            raise MemoryError(f"Escrita fora dos limites: 0x{addr:08x}")
        struct.pack_into('<H', self.data, addr, value & 0xFFFF)

    def write32(self, addr: int, value: int):
        """Escreve 4 bytes (little-endian) no endereço 'addr'."""
        addr = to_u32(addr)
        if addr + 4 > self.size:
            raise MemoryError(f"Escrita fora dos limites: 0x{addr:08x}")
        struct.pack_into('<I', self.data, addr, value & 0xFFFF_FFFF)

    def dump(self, start: int, count: int = 8):
        """Retorna lista de (addr, word) para exibição."""
        result = []
        start = to_u32(start) & ~3  # alinha em word
        for i in range(count):
            addr = start + i * 4
            if addr + 4 > self.size:
                break
            result.append((addr, self.read32(addr)))
        return result


# =============================================================================
# Classe CPU — processador RISC-V RV32I single-cycle
# =============================================================================

class CPU:
    """
    Processador RISC-V RV32I single-cycle.

    Implementa as 37 instruções base: R-type, I-type (arith, load, jalr),
    S-type, B-type, U-type (lui, auipc) e J-type (jal).

    Modos de memória:
    - Harvard (padrão): imem separada de dmem (como riscv_harvard/)
    - Von Neumann (--vn): memória unificada (como riscv_von_neumann/)
    """

    # Limite de instruções para evitar loops infinitos no modo run
    HALT_LIMIT = 10_000_000

    # Tamanho padrão das memórias
    IMEM_SIZE = 4096   # 4 KB instrução
    DMEM_SIZE = 4096   # 4 KB dados (Harvard)
    MEM_SIZE  = 65536  # 64 KB unificado (Von Neumann)

    def __init__(self, harvard: bool = True):
        """
        Args:
            harvard: True para modo Harvard (default), False para Von Neumann.
        """
        self.harvard = harvard
        self.regs = [0] * 32   # x0..x31, x0 sempre 0
        self.pc = 0
        self.cycle = 0
        self._halted = False
        self._hex_path = None

        if harvard:
            self.imem = Memory(self.IMEM_SIZE)
            self.dmem = Memory(self.DMEM_SIZE)
            self.mem  = None
        else:
            self.imem = None
            self.dmem = None
            self.mem  = Memory(self.MEM_SIZE)

    # ── Carga de programa ─────────────────────────────────────────────────────

    def load(self, path: str):
        """Carrega arquivo .hex na memória de instruções."""
        self._hex_path = os.path.abspath(path)
        self._halted = False
        if self.harvard:
            self.imem.load_hex(path)
        else:
            self.mem.load_hex(path)

    def reset(self):
        """
        Reinicia CPU: zera registradores, PC e ciclos.
        Recarrega o programa se havia um carregado.
        """
        self.regs = [0] * 32
        self.pc = 0
        self.cycle = 0
        self._halted = False
        if self.harvard:
            self.imem.reset()
            self.dmem.reset()
            if self._hex_path:
                self.imem.load_hex(self._hex_path)
        else:
            self.mem.reset()
            if self._hex_path:
                self.mem.load_hex(self._hex_path)

    # ── Acesso a memória (despacha para imem/dmem ou mem unificada) ───────────

    def _ifetch(self) -> int:
        """Busca instrução no PC atual (instruction fetch)."""
        if self.harvard:
            return self.imem.read32(self.pc)
        else:
            return self.mem.read32(self.pc)

    def _dread8(self, addr: int)  -> int: return (self.dmem if self.harvard else self.mem).read8(addr)
    def _dread16(self, addr: int) -> int: return (self.dmem if self.harvard else self.mem).read16(addr)
    def _dread32(self, addr: int) -> int: return (self.dmem if self.harvard else self.mem).read32(addr)
    def _dwrite8(self, addr: int, v: int):  (self.dmem if self.harvard else self.mem).write8(addr, v)
    def _dwrite16(self, addr: int, v: int): (self.dmem if self.harvard else self.mem).write16(addr, v)
    def _dwrite32(self, addr: int, v: int): (self.dmem if self.harvard else self.mem).write32(addr, v)

    # ── Decodificação de imediatos ────────────────────────────────────────────

    @staticmethod
    def _imm_i(instr: int) -> int:
        """Imediato I-type: bits [31:20], com extensão de sinal de 12 bits."""
        return sign_extend((instr >> 20) & 0xFFF, 12)

    @staticmethod
    def _imm_s(instr: int) -> int:
        """Imediato S-type: bits [31:25] e [11:7], extensão de 12 bits."""
        imm = ((instr >> 25) << 5) | ((instr >> 7) & 0x1F)
        return sign_extend(imm, 12)

    @staticmethod
    def _imm_b(instr: int) -> int:
        """Imediato B-type: bits [31,7,30:25,11:8], extensão de 13 bits."""
        b12   = (instr >> 31) & 1
        b11   = (instr >> 7) & 1
        b10_5 = (instr >> 25) & 0x3F
        b4_1  = (instr >> 8) & 0xF
        imm = (b12 << 12) | (b11 << 11) | (b10_5 << 5) | (b4_1 << 1)
        return sign_extend(imm, 13)

    @staticmethod
    def _imm_u(instr: int) -> int:
        """Imediato U-type: bits [31:12] nos 20 bits superiores (já shiftado)."""
        return instr & 0xFFFFF000

    @staticmethod
    def _imm_j(instr: int) -> int:
        """Imediato J-type: bits [31,19:12,20,30:21], extensão de 21 bits."""
        b20    = (instr >> 31) & 1
        b10_1  = (instr >> 21) & 0x3FF
        b11    = (instr >> 20) & 1
        b19_12 = (instr >> 12) & 0xFF
        imm = (b20 << 20) | (b19_12 << 12) | (b11 << 11) | (b10_1 << 1)
        return sign_extend(imm, 21)

    # ── Desmontagem (disassembly) para exibição ───────────────────────────────

    def disasm(self, instr: int, pc: int) -> str:
        """
        Retorna string legível da instrução (ex: 'addi x1, x0, 5').

        Args:
            instr: Palavra de 32 bits da instrução.
            pc:    Endereço do PC onde a instrução está (usado para targets de branch/jump).
        """
        op     = instr & 0x7F
        rd     = (instr >> 7) & 0x1F
        f3     = (instr >> 12) & 0x7
        rs1    = (instr >> 15) & 0x1F
        rs2    = (instr >> 20) & 0x1F
        f7     = (instr >> 25) & 0x7F
        shamt  = rs2  # para shifts imediatos

        def rn(r): return f"x{r}"

        if op == 0b0110111:  # LUI
            return f"lui {rn(rd)}, 0x{self._imm_u(instr) >> 12:x}"

        if op == 0b0010111:  # AUIPC
            tgt = to_u32(pc + self._imm_u(instr))
            return f"auipc {rn(rd)}, 0x{self._imm_u(instr) >> 12:x}  # → 0x{tgt:x}"

        if op == 0b1101111:  # JAL
            imm = self._imm_j(instr)
            tgt = to_u32(pc + imm)
            return f"jal {rn(rd)}, 0x{tgt:x}  # PC{imm:+d}"

        if op == 0b1100111:  # JALR
            imm = self._imm_i(instr)
            return f"jalr {rn(rd)}, {rn(rs1)}, {imm}"

        if op == 0b1100011:  # BRANCH
            imm = self._imm_b(instr)
            tgt = to_u32(pc + imm)
            names = {0:'beq',1:'bne',4:'blt',5:'bge',6:'bltu',7:'bgeu'}
            name = names.get(f3, f'b?{f3}')
            return f"{name} {rn(rs1)}, {rn(rs2)}, 0x{tgt:x}  # PC{imm:+d}"

        if op == 0b0000011:  # LOAD
            imm = self._imm_i(instr)
            names = {0:'lb',1:'lh',2:'lw',4:'lbu',5:'lhu'}
            name = names.get(f3, f'l?{f3}')
            return f"{name} {rn(rd)}, {imm}({rn(rs1)})"

        if op == 0b0100011:  # STORE
            imm = self._imm_s(instr)
            names = {0:'sb',1:'sh',2:'sw'}
            name = names.get(f3, f's?{f3}')
            return f"{name} {rn(rs2)}, {imm}({rn(rs1)})"

        if op == 0b0010011:  # I-type arith
            imm = self._imm_i(instr)
            if f3 == 0: return f"addi  {rn(rd)}, {rn(rs1)}, {imm}"
            if f3 == 2: return f"slti  {rn(rd)}, {rn(rs1)}, {imm}"
            if f3 == 3: return f"sltiu {rn(rd)}, {rn(rs1)}, {imm & 0xFFF}"
            if f3 == 4: return f"xori  {rn(rd)}, {rn(rs1)}, {imm}"
            if f3 == 6: return f"ori   {rn(rd)}, {rn(rs1)}, {imm}"
            if f3 == 7: return f"andi  {rn(rd)}, {rn(rs1)}, {imm}"
            if f3 == 1: return f"slli  {rn(rd)}, {rn(rs1)}, {shamt}"
            if f3 == 5:
                if f7 == 0x20: return f"srai  {rn(rd)}, {rn(rs1)}, {shamt}"
                else:          return f"srli  {rn(rd)}, {rn(rs1)}, {shamt}"

        if op == 0b0110011:  # R-type
            if f3 == 0:
                if f7 == 0x20: return f"sub   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
                else:          return f"add   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 1: return f"sll   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 2: return f"slt   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 3: return f"sltu  {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 4: return f"xor   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 5:
                if f7 == 0x20: return f"sra   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
                else:          return f"srl   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 6: return f"or    {rn(rd)}, {rn(rs1)}, {rn(rs2)}"
            if f3 == 7: return f"and   {rn(rd)}, {rn(rs1)}, {rn(rs2)}"

        return f"??? (0x{instr:08x})"

    # ── Execução de uma instrução ─────────────────────────────────────────────

    def step(self) -> dict:
        """
        Executa uma instrução e retorna um dicionário com o trace da execução.

        Retorna:
            {
              'pc':          int   — PC antes da execução,
              'instr':       int   — palavra de 32 bits da instrução,
              'disasm':      str   — desmontagem legível,
              'reg_writes':  list  — [(rd, valor_antes, valor_depois), ...],
              'mem_writes':  list  — [(addr, nbytes, valor), ...],
              'branch_taken': bool — (apenas para branches),
              'halted':      bool  — True se halt detectado,
              'error':       str   — mensagem de erro, ou None,
            }
        """
        result = {
            'pc': self.pc, 'instr': 0, 'disasm': '',
            'reg_writes': [], 'mem_writes': [],
            'halted': False, 'error': None,
        }

        if self._halted:
            result['halted'] = True
            result['disasm'] = '--- (halt)'
            return result

        # ── Instruction Fetch ─────────────────────────────────────────────────
        try:
            instr = self._ifetch()
        except (MemoryError, OverflowError) as e:
            result['error'] = str(e)
            result['halted'] = True
            self._halted = True
            return result

        result['instr'] = instr
        result['disasm'] = self.disasm(instr, self.pc)

        # ── Decode ────────────────────────────────────────────────────────────
        op    = instr & 0x7F
        rd    = (instr >> 7) & 0x1F
        f3    = (instr >> 12) & 0x7
        rs1   = (instr >> 15) & 0x1F
        rs2   = (instr >> 20) & 0x1F
        f7    = (instr >> 25) & 0x7F
        shamt = rs2  # para shifts imediatos

        pc_cur = self.pc
        new_pc = pc_cur + 4

        def reg_write(dest, val):
            """Escreve em registrador, ignora x0, registra a mudança."""
            if dest == 0:
                return
            old = self.regs[dest]
            new = to_u32(val)
            self.regs[dest] = new
            if old != new:
                result['reg_writes'].append((dest, old, new))

        # ── Execute ───────────────────────────────────────────────────────────
        try:
            if op == 0b0110111:  # LUI: rd = imm << 12
                reg_write(rd, self._imm_u(instr))

            elif op == 0b0010111:  # AUIPC: rd = PC + (imm << 12)
                reg_write(rd, pc_cur + self._imm_u(instr))

            elif op == 0b1101111:  # JAL: rd = PC+4; PC = PC + imm
                imm = self._imm_j(instr)
                reg_write(rd, new_pc)
                new_pc = to_u32(pc_cur + imm)

            elif op == 0b1100111:  # JALR: rd = PC+4; PC = (rs1+imm) & ~1
                imm = self._imm_i(instr)
                target = (self.regs[rs1] + imm) & ~1
                reg_write(rd, new_pc)
                new_pc = to_u32(target)

            elif op == 0b1100011:  # BRANCH
                imm = self._imm_b(instr)
                r1, r2 = self.regs[rs1], self.regs[rs2]
                s1, s2 = to_s32(r1), to_s32(r2)
                taken = {
                    0: r1 == r2,           # beq
                    1: r1 != r2,           # bne
                    4: s1 < s2,            # blt  (com sinal)
                    5: s1 >= s2,           # bge  (com sinal)
                    6: r1 < r2,            # bltu (sem sinal)
                    7: r1 >= r2,           # bgeu (sem sinal)
                }.get(f3, False)
                result['branch_taken'] = taken
                if taken:
                    new_pc = to_u32(pc_cur + imm)

            elif op == 0b0000011:  # LOAD
                imm  = self._imm_i(instr)
                addr = to_u32(self.regs[rs1] + imm)
                val = {
                    0: sign_extend(self._dread8(addr),  8),   # lb
                    1: sign_extend(self._dread16(addr), 16),  # lh
                    2: self._dread32(addr),                    # lw
                    4: self._dread8(addr),                     # lbu
                    5: self._dread16(addr),                    # lhu
                }.get(f3)
                if val is None:
                    raise ValueError(f"funct3 inválido para LOAD: {f3}")
                reg_write(rd, val)

            elif op == 0b0100011:  # STORE
                imm  = self._imm_s(instr)
                addr = to_u32(self.regs[rs1] + imm)
                val  = self.regs[rs2]
                if   f3 == 0: self._dwrite8(addr, val);  result['mem_writes'].append((addr, 1, val & 0xFF))
                elif f3 == 1: self._dwrite16(addr, val); result['mem_writes'].append((addr, 2, val & 0xFFFF))
                elif f3 == 2: self._dwrite32(addr, val); result['mem_writes'].append((addr, 4, val & 0xFFFFFFFF))
                else: raise ValueError(f"funct3 inválido para STORE: {f3}")

            elif op == 0b0010011:  # I-type arith
                imm = self._imm_i(instr)
                r1  = self.regs[rs1]
                s1  = to_s32(r1)
                val = {
                    0: r1 + imm,                                          # addi
                    2: 1 if s1 < imm else 0,                              # slti
                    3: 1 if r1 < to_u32(imm) else 0,                     # sltiu
                    4: r1 ^ to_u32(imm),                                  # xori
                    6: r1 | to_u32(imm),                                  # ori
                    7: r1 & to_u32(imm),                                  # andi
                    1: r1 << shamt,                                       # slli
                    5: (to_s32(r1) >> shamt if f7 == 0x20 else r1 >> shamt),  # srai/srli
                }.get(f3)
                if val is None:
                    raise ValueError(f"funct3 inválido para I-arith: {f3}")
                reg_write(rd, val)

            elif op == 0b0110011:  # R-type
                r1, r2 = self.regs[rs1], self.regs[rs2]
                s1, s2 = to_s32(r1), to_s32(r2)
                shamt_r = r2 & 0x1F
                val = {
                    0: (r1 - r2 if f7 == 0x20 else r1 + r2),             # sub/add
                    1: r1 << shamt_r,                                     # sll
                    2: 1 if s1 < s2 else 0,                              # slt
                    3: 1 if r1 < r2 else 0,                              # sltu
                    4: r1 ^ r2,                                           # xor
                    5: (s1 >> shamt_r if f7 == 0x20 else r1 >> shamt_r), # sra/srl
                    6: r1 | r2,                                           # or
                    7: r1 & r2,                                           # and
                }.get(f3)
                if val is None:
                    raise ValueError(f"funct3 inválido para R-type: {f3}")
                reg_write(rd, val)

            else:
                raise ValueError(f"Opcode desconhecido: 0x{op:02x} em PC=0x{pc_cur:x}")

        except (MemoryError, OverflowError, ValueError) as e:
            result['error'] = str(e)
            result['halted'] = True
            self._halted = True
            return result

        # ── Detecção de halt: JAL para si mesmo (loop infinito no mesmo endereço) ──
        if new_pc == pc_cur:
            self._halted = True
            result['halted'] = True

        self.pc = new_pc
        self.cycle += 1
        return result

    def run_until_halt(self, max_cycles: int = None) -> int:
        """
        Executa até halt ou limite de ciclos.

        Args:
            max_cycles: Limite de ciclos (default: HALT_LIMIT).

        Returns:
            Número de instruções executadas.
        """
        limit = max_cycles if max_cycles is not None else self.HALT_LIMIT
        count = 0
        while not self._halted and count < limit:
            self.step()
            count += 1
        return count


# =============================================================================
# Classe Simulator — REPL interativo
# =============================================================================

class Simulator:
    """
    Interface interativa para o simulador RISC-V.

    Gerencia o REPL (Read-Eval-Print Loop), breakpoints,
    modo trace e formatação de saída colorida.
    """

    def __init__(self, cpu: CPU, color: bool = True):
        self.cpu = cpu
        self.breakpoints: set = set()
        self.trace: bool = False
        self.use_color: bool = color
        self.watches: set = set()          # índices de registradores monitorados
        self._history: list = []           # buffer de (pc, disasm) executados
        self._history_max: int = 200       # tamanho máximo do histórico

    def c(self, text, *keys) -> str:
        """Aplica cores condicionalmente."""
        return _c(text, *keys, enabled=self.use_color)

    # ── Formatação de saída ───────────────────────────────────────────────────

    def _fmt_step(self, result: dict):
        """Imprime linha de trace de uma instrução executada."""
        pc    = result['pc']
        instr = result['instr']
        dis   = result['disasm']

        # Acumula histórico
        self._history.append((pc, dis))
        if len(self._history) > self._history_max:
            self._history.pop(0)

        # Linha principal: PC, desmontagem, hex
        pc_str    = self.c(f"[0x{pc:08x}]", 'cyan')
        dis_str   = self.c(dis, 'bold')
        hex_str   = self.c(f"(0x{instr:08x})", 'dim')
        print(f"  {pc_str} {dis_str}  {hex_str}")

        # Escritas em registradores
        for rd, old, new in result.get('reg_writes', []):
            abi = REGS_ABI[rd]
            watch_mark = self.c(" ★ WATCH", 'yellow', 'bold') if rd in self.watches else ""
            line = (
                f"    {self.c(f'x{rd}({abi})', 'yellow')}: "
                f"0x{old:08x} → {self.c(f'0x{new:08x}', 'green')} "
                f"({to_s32(new)}){watch_mark}"
            )
            print(line)

        # Escritas em memória de dados
        for addr, nbytes, val in result.get('mem_writes', []):
            line = (
                f"    {self.c('mem', 'yellow')}[0x{addr:08x}] ← "
                f"{self.c(f'0x{val:08x}', 'green')} ({nbytes}B)"
            )
            print(line)

        # Status de branch
        if 'branch_taken' in result:
            taken = result['branch_taken']
            s = self.c("✓ tomado", 'green') if taken else self.c("✗ não tomado", 'dim')
            print(f"    branch: {s}")

        # Erro ou halt
        if result.get('error'):
            print(self.c(f"    ERRO: {result['error']}", 'red', 'bold'))
        elif result.get('halted'):
            print(self.c("    *** HALT ***", 'red', 'bold'))

    def _fmt_reg_line(self, n: int) -> str:
        """Retorna linha formatada de um registrador."""
        abi = REGS_ABI[n]
        val = self.cpu.regs[n]
        s   = to_s32(val)
        return f"  x{n:<2d} ({abi:<4s}) = 0x{val:08x}  ({s:>12d})"

    # ── Handlers de comandos ──────────────────────────────────────────────────

    def cmd_step(self, args):
        """step [n] — executa n instruções."""
        try:
            n = int(args[0]) if args else 1
        except ValueError:
            print("Uso: step [n]")
            return
        for _ in range(n):
            result = self.cpu.step()
            self._fmt_step(result)
            if result['halted']:
                break
            if self.cpu.pc in self.breakpoints:
                print(self.c(f"  Breakpoint em 0x{self.cpu.pc:08x}", 'yellow'))
                break

    def cmd_run(self, args):
        """run — executa até halt ou breakpoint."""
        count = 0
        last_result = None
        while not self.cpu._halted:
            result = self.cpu.step()
            count += 1
            last_result = result
            if self.trace:
                self._fmt_step(result)
            if result['halted']:
                if not self.trace:
                    self._fmt_step(result)
                break
            if self.cpu.pc in self.breakpoints:
                if not self.trace:
                    self._fmt_step(result)
                print(self.c(f"  Breakpoint em 0x{self.cpu.pc:08x}", 'yellow'))
                break
            if count >= CPU.HALT_LIMIT:
                print(self.c(
                    f"  Limite de {CPU.HALT_LIMIT} instruções atingido. "
                    "Use 'reset' para reiniciar.", 'red'
                ))
                break
        n_word = "instrução executada" if count == 1 else "instruções executadas"
        print(self.c(f"  ({count} {n_word})", 'dim'))

    def cmd_reg(self, args):
        """reg — mostra todos os registradores."""
        print("Registradores:")
        for i in range(32):
            print(self._fmt_reg_line(i))
        print(f"  PC        = 0x{self.cpu.pc:08x}")
        print(f"  Ciclos    = {self.cpu.cycle}")

    def cmd_mem(self, args):
        """mem <addr> [n] — mostra n words de dados."""
        if not args:
            print("Uso: mem <addr> [n]")
            return
        try:
            addr = int(args[0], 0)
            n    = int(args[1]) if len(args) > 1 else 8
        except ValueError:
            print("Endereço ou contagem inválidos.")
            return
        mem = self.cpu.dmem if self.cpu.harvard else self.cpu.mem
        print(f"Memória de dados em 0x{addr & ~3:08x}:")
        for a, w in mem.dump(addr, n):
            s = to_s32(w)
            print(f"  [0x{a:08x}]  0x{w:08x}  ({s:>12d})")

    def cmd_imem(self, args):
        """imem [addr] [n] — mostra n words de instruções com desmontagem."""
        addr = int(args[0], 0) if args else self.cpu.pc
        n    = int(args[1]) if len(args) > 1 else 8
        mem  = self.cpu.imem if self.cpu.harvard else self.cpu.mem
        pc   = self.cpu.pc
        print(f"Memória de instruções em 0x{addr & ~3:08x}:")
        for a, w in mem.dump(addr, n):
            dis    = self.cpu.disasm(w, a)
            marker = self.c(" ← PC", 'cyan') if a == pc else ""
            print(f"  [0x{a:08x}]  0x{w:08x}  {dis}{marker}")

    def cmd_bp(self, args):
        """bp <addr> — ativa/desativa breakpoint."""
        if not args:
            print("Uso: bp <addr>")
            return
        try:
            addr = int(args[0], 0)
        except ValueError:
            print("Endereço inválido.")
            return
        if addr in self.breakpoints:
            self.breakpoints.remove(addr)
            print(f"  Breakpoint removido em 0x{addr:08x}")
        else:
            self.breakpoints.add(addr)
            print(self.c(f"  Breakpoint definido em 0x{addr:08x}", 'yellow'))

    def cmd_bps(self, args):
        """bps — lista breakpoints ativos."""
        if not self.breakpoints:
            print("  Nenhum breakpoint definido.")
        else:
            print("Breakpoints ativos:")
            for a in sorted(self.breakpoints):
                print(f"  0x{a:08x}")

    def cmd_reset(self, args):
        """reset — reinicia CPU mantendo o programa."""
        self.cpu.reset()
        self._history.clear()
        print(self.c("  CPU reiniciada.", 'green'))

    def cmd_load(self, args):
        """load <arquivo.hex> — carrega novo programa."""
        if not args:
            print("Uso: load <arquivo.hex>")
            return
        path = args[0]
        if not os.path.isfile(path):
            print(self.c(f"  Arquivo não encontrado: {path}", 'red'))
            return
        try:
            self.cpu.reset()
            self.cpu.load(path)
            print(self.c(f"  Programa carregado: {path}", 'green'))
        except Exception as e:
            print(self.c(f"  Erro ao carregar: {e}", 'red'))

    def cmd_trace(self, args):
        """trace [on|off] — ativa/desativa trace durante 'run'."""
        if args:
            self.trace = args[0].lower() in ('on', '1', 'sim', 'yes', 'true')
        else:
            self.trace = not self.trace
        estado = "ativado" if self.trace else "desativado"
        print(f"  Trace: {estado}")

    # ── Comandos novos ────────────────────────────────────────────────────────

    def _parse_reg(self, s: str):
        """Converte 'x5', 'a0', 'ra', etc. para índice 0-31. Retorna None se inválido."""
        s = s.lower().strip()
        if s.startswith('x'):
            try:
                n = int(s[1:])
                if 0 <= n <= 31:
                    return n
            except ValueError:
                pass
        if s in REGS_ABI:
            return REGS_ABI.index(s)
        print(f"  Registrador inválido: '{s}'. Use x0–x31 ou nome ABI (ra, sp, a0, ...).")
        return None

    def cmd_watch(self, args):
        """watch [<reg>] — monitora mudanças em um registrador durante step/run."""
        if not args:
            if not self.watches:
                print("  Nenhum watch ativo.")
            else:
                print("Watches ativos:")
                for r in sorted(self.watches):
                    abi = REGS_ABI[r]
                    val = self.cpu.regs[r]
                    print(f"  x{r:<2d} ({abi:<4s}) = 0x{val:08x}  ({to_s32(val)})")
            return
        reg_num = self._parse_reg(args[0])
        if reg_num is None:
            return
        if reg_num in self.watches:
            self.watches.discard(reg_num)
            print(f"  Watch removido: x{reg_num} ({REGS_ABI[reg_num]})")
        else:
            self.watches.add(reg_num)
            print(self.c(f"  Watch ativado: x{reg_num} ({REGS_ABI[reg_num]})", 'yellow'))

    def cmd_set(self, args):
        """set <reg> <val> — define valor de um registrador diretamente."""
        if len(args) < 2:
            print("Uso: set <reg> <val>   (ex: set a0 42, set x5 0xFF)")
            return
        reg_num = self._parse_reg(args[0])
        if reg_num is None:
            return
        if reg_num == 0:
            print("  x0 (zero) é sempre 0 — não pode ser modificado.")
            return
        try:
            val = int(args[1], 0)
        except ValueError:
            print(f"  Valor inválido: '{args[1]}'. Use decimal ou 0x hexadecimal.")
            return
        old = self.cpu.regs[reg_num]
        self.cpu.regs[reg_num] = to_u32(val)
        abi = REGS_ABI[reg_num]
        print(
            f"  x{reg_num} ({abi}): "
            f"0x{old:08x} → {self.c(f'0x{to_u32(val):08x}', 'green')} "
            f"({to_s32(to_u32(val))})"
        )

    def cmd_history(self, args):
        """history [n] — mostra as últimas n instruções executadas."""
        try:
            n = int(args[0]) if args else 20
        except ValueError:
            n = 20
        hist = self._history[-n:]
        if not hist:
            print("  Histórico vazio. Execute algumas instruções primeiro.")
            return
        print(f"Últimas {len(hist)} instrução(ões) executadas:")
        for i, (pc, dis) in enumerate(hist):
            marker = self.c("  ← última", 'dim') if i == len(hist) - 1 else ""
            print(f"  {self.c(f'[0x{pc:08x}]', 'cyan')} {dis}{marker}")

    def cmd_help(self, args):
        """help — exibe ajuda."""
        print("""
Comandos do simulador RISC-V RV32I:
─────────────────────────────────────────────────────────────────────
  step [n]          Executa n instrução(ões) (padrão: 1)   | alias: s
  run               Executa até halt ou breakpoint          | alias: r
  reg               Mostra todos os registradores           | alias: regs
  mem <addr> [n]    Mostra n words de dados (padrão: 8)    | alias: m
  imem [addr] [n]   Mostra n words de instruções c/ disasm | alias: i
  bp <addr>         Ativa/desativa breakpoint no endereço
  bps               Lista todos os breakpoints
  watch [<reg>]     Monitora mudança em registrador (★)    | alias: w
  set <reg> <val>   Define valor de um registrador
  history [n]       Mostra últimas n instruções executadas  | alias: hist
  load <arquivo>    Carrega novo arquivo .hex
  reset             Reinicia CPU (mantém o programa)
  trace [on|off]    Exibe trace durante 'run'
  help              Esta ajuda                              | alias: h
  quit              Sai do simulador                        | alias: q, exit
─────────────────────────────────────────────────────────────────────
Exemplos:
  step 5              → executa 5 instruções
  mem 0x0000 16       → mostra 16 words de dados
  bp 0x10             → define breakpoint em 0x10
  watch a0            → marca ★ em a0 (x10) durante step/run
  set a0 42           → força a0=42 antes de continuar
  history 10          → últimas 10 instruções executadas
  run                 → executa até halt
  trace on; run       → trace completo
─────────────────────────────────────────────────────────────────────""")

    # ── REPL principal ────────────────────────────────────────────────────────

    def run_repl(self):
        """Inicia o loop interativo de comandos."""
        # Histórico de comandos com readline
        histfile = os.path.expanduser("~/.riscv_sim_history")
        if _READLINE:
            try:
                readline.read_history_file(histfile)
            except OSError:
                pass
            readline.set_history_length(500)

        # Tabela de comandos
        commands = {
            'step':    self.cmd_step,    's':    self.cmd_step,
            'run':     self.cmd_run,     'r':    self.cmd_run,
            'reg':     self.cmd_reg,     'regs': self.cmd_reg,
            'mem':     self.cmd_mem,     'm':    self.cmd_mem,
            'imem':    self.cmd_imem,    'i':    self.cmd_imem,
            'bp':      self.cmd_bp,
            'bps':     self.cmd_bps,
            'watch':   self.cmd_watch,   'w':    self.cmd_watch,
            'set':     self.cmd_set,
            'history': self.cmd_history, 'hist': self.cmd_history,
            'reset':   self.cmd_reset,
            'load':    self.cmd_load,
            'trace':   self.cmd_trace,
            'help':    self.cmd_help,    'h':    self.cmd_help,
        }

        modo = "Harvard" if self.cpu.harvard else "Von Neumann"
        prog = os.path.basename(self.cpu._hex_path or "(nenhum)")
        print(self.c("╔══════════════════════════════════════════╗", 'cyan'))
        print(self.c("║   Simulador RISC-V RV32I  — Educacional  ║", 'cyan', 'bold'))
        print(self.c("╚══════════════════════════════════════════╝", 'cyan'))
        print(f"  Modo    : {modo}")
        print(f"  Programa: {prog}")
        print(f"  Digite {self.c('help', 'bold')} para ver os comandos.\n")

        prompt = self.c("riscv> ", 'cyan', 'bold')

        try:
            while True:
                try:
                    line = input(prompt)
                except EOFError:
                    print()
                    break

                line = line.strip()
                if not line:
                    continue

                # Permite múltiplos comandos separados por ";"
                for sub in line.split(';'):
                    parts = sub.strip().split()
                    if not parts:
                        continue
                    cmd  = parts[0].lower()
                    args = parts[1:]

                    if cmd in ('quit', 'q', 'exit'):
                        if _READLINE:
                            try:
                                readline.write_history_file(histfile)
                            except Exception:
                                pass
                        return

                    handler = commands.get(cmd)
                    if handler:
                        try:
                            handler(args)
                        except Exception as e:
                            print(self.c(f"  Erro: {e}", 'red'))
                    else:
                        print(f"  Comando desconhecido: '{cmd}'. Digite 'help'.")
        finally:
            if _READLINE:
                try:
                    readline.write_history_file(histfile)
                except Exception:
                    pass


# =============================================================================
# Modo batch: --run (executa programa e imprime estado final)
# =============================================================================

def run_batch(cpu: CPU, use_color: bool = True):
    """Executa o programa até halt e imprime registradores finais."""
    count = cpu.run_until_halt()
    c = lambda t, *k: _c(t, *k, enabled=use_color)

    print(c(f"Halt em PC=0x{cpu.pc:08x} após {count} {'instrução' if count == 1 else 'instruções'}", 'dim'))
    print()
    print("Registradores finais:")

    # Mostra apenas registradores com valor != 0 (mais limpo)
    any_nonzero = False
    for i in range(1, 32):  # x0 é sempre 0, omitir
        v = cpu.regs[i]
        if v != 0:
            abi = REGS_ABI[i]
            s = to_s32(v)
            print(f"  x{i:<2d} ({abi:<4s}) = 0x{v:08x}  ({s})")
            any_nonzero = True
    if not any_nonzero:
        print("  (todos os registradores são zero)")


# =============================================================================
# main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Simulador interativo RISC-V RV32I",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos:
  python3 riscv_sim.py programa.hex
  python3 riscv_sim.py programa.hex --vn
  python3 riscv_sim.py programa.hex --run
  python3 riscv_sim.py programa.hex --no-color
        """
    )
    parser.add_argument(
        'hex_file', nargs='?',
        help='Arquivo .hex a carregar (formato $readmemh)'
    )
    parser.add_argument(
        '--vn', '--von-neumann', action='store_true',
        help='Modo Von Neumann (memória unificada). Padrão: Harvard.'
    )
    parser.add_argument(
        '--run', action='store_true',
        help='Executa até halt sem interatividade e imprime registradores.'
    )
    parser.add_argument(
        '--no-color', action='store_true',
        help='Desativa cores ANSI.'
    )
    parser.add_argument(
        '--imem-size', type=int, default=4096,
        help='Tamanho da memória de instruções em bytes (padrão: 4096).'
    )
    parser.add_argument(
        '--dmem-size', type=int, default=4096,
        help='Tamanho da memória de dados em bytes (padrão: 4096).'
    )
    parser.add_argument(
        '--mem-size', type=int, default=65536,
        help='Tamanho da memória unificada em bytes, modo VN (padrão: 65536).'
    )

    args = parser.parse_args()

    # Cria CPU com tamanhos configuráveis
    harvard = not args.vn
    cpu = CPU(harvard=harvard)
    if harvard:
        cpu.imem = Memory(args.imem_size)
        cpu.dmem = Memory(args.dmem_size)
    else:
        cpu.mem = Memory(args.mem_size)

    # Carrega programa, se fornecido
    if args.hex_file:
        if not os.path.isfile(args.hex_file):
            print(f"Erro: arquivo não encontrado: {args.hex_file}", file=sys.stderr)
            sys.exit(1)
        try:
            cpu.load(args.hex_file)
        except Exception as e:
            print(f"Erro ao carregar programa: {e}", file=sys.stderr)
            sys.exit(1)

    use_color = not args.no_color

    if args.run:
        if not args.hex_file:
            print("Erro: --run requer um arquivo .hex.", file=sys.stderr)
            sys.exit(1)
        run_batch(cpu, use_color=use_color)
    else:
        sim = Simulator(cpu, color=use_color)
        sim.run_repl()


if __name__ == '__main__':
    main()
