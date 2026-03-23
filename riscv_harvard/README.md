# Processador RISC-V RV32I — Arquitetura Harvard
## Documentação Técnica Completa

> Implementação educacional single-cycle do ISA RISC-V RV32I em SystemVerilog,
> simulada com Verilator. Inspirada no processador Neander (Weber, UFRGS), mas
> usando a ISA padrão aberta RISC-V — usada em chips reais da SiFive, Google,
> Western Digital e centenas de outros fabricantes.

---

## Índice

1. [O que é RISC-V e por que ele importa](#1-o-que-é-risc-v-e-por-que-ele-importa)
2. [Pré-requisitos e Instalação](#2-pré-requisitos-e-instalação)
3. [Estrutura de Arquivos](#3-estrutura-de-arquivos)
4. [Arquitetura Harvard — Conceito Profundo](#4-arquitetura-harvard--conceito-profundo)
5. [O Ciclo de Instrução Single-Cycle](#5-o-ciclo-de-instrução-single-cycle)
6. [Componentes — Explicação Detalhada](#6-componentes--explicação-detalhada)
   - 6.1 [ALU](#61-alu--srcalusv)
   - 6.2 [Unidade de Controle da ALU](#62-unidade-de-controle-da-alu--srcalu_controlsv)
   - 6.3 [Banco de Registradores](#63-banco-de-registradores--srcregister_filesv)
   - 6.4 [Gerador de Imediatos](#64-gerador-de-imediatos--srcimm_gensv)
   - 6.5 [Unidade de Controle Principal](#65-unidade-de-controle-principal--srccontrol_unitsv)
   - 6.6 [Memória de Instruções](#66-memória-de-instruções--srcinstr_memsv)
   - 6.7 [Memória de Dados](#67-memória-de-dados--srcdata_memsv)
   - 6.8 [Top-Level](#68-top-level--srcriscv_topsv)
7. [Formatos de Instrução RISC-V — Encoding Binário](#7-formatos-de-instrução-risc-v--encoding-binário)
8. [Conjunto de Instruções — Tabela Completa](#8-conjunto-de-instruções--tabela-completa)
9. [Trace de Execução — Passo a Passo por Instrução](#9-trace-de-execução--passo-a-passo-por-instrução)
10. [Sinais de Controle — Tabela Detalhada](#10-sinais-de-controle--tabela-detalhada)
11. [Como Reproduzir do Zero](#11-como-reproduzir-do-zero)
12. [Como Executar os Testes](#12-como-executar-os-testes)
13. [Como Escrever Seu Próprio Programa](#13-como-escrever-seu-próprio-programa)
14. [Como Adicionar uma Nova Instrução](#14-como-adicionar-uma-nova-instrução)
15. [Conceito de Pipeline — Do Single-Cycle ao Pipeline 5 Estágios](#15-conceito-de-pipeline--do-single-cycle-ao-pipeline-5-estágios)
16. [Como Depurar com Verilator](#16-como-depurar-com-verilator)
17. [Diagrama Completo do Datapath](#17-diagrama-completo-do-datapath)
18. [Comparação Harvard vs Von Neumann](#18-comparação-harvard-vs-von-neumann)

---

## 1. O que é RISC-V e por que ele importa

**RISC-V** (pronuncia-se "risk five") é uma ISA (*Instruction Set Architecture*)
aberta, livre de royalties, criada na UC Berkeley em 2010. Diferente de x86 (Intel/AMD)
ou ARM (que cobram licenças), qualquer pessoa pode implementar RISC-V.

### Conexão com o Neander

O **Neander** é um processador didático de 8 bits criado pelo Prof. Raul Weber (UFRGS),
muito usado no ensino de Organização de Computadores no Brasil. Este projeto segue
a mesma filosofia — simplicidade educacional — mas com a ISA RISC-V de 32 bits:

| Aspecto | Neander | Este projeto (RISC-V RV32I) |
|---|---|---|
| Largura de dados | 8 bits | 32 bits |
| Registradores | 1 (acumulador) | 32 (x0–x31) |
| Instruções | ~10 | 37 |
| ISA | Proprietária (didática) | Padrão aberto (RISC-V) |
| Implementação | Lógica discreta / simulação | SystemVerilog + Verilator |
| Uso real | Apenas educacional | Chips reais (SiFive, Google...) |

### Por que single-cycle?

A implementação single-cycle é a mais simples conceitualmente:
**cada instrução completa em exatamente 1 ciclo de clock**.
O clock precisa ser lento o suficiente para a instrução mais lenta completar.
Em implementações reais, o pipeline divide a instrução em estágios para
aumentar a frequência. Veja a [Seção 15](#15-conceito-de-pipeline) para detalhes.

---

## 2. Pré-requisitos e Instalação

### Ferramentas necessárias

| Ferramenta | Para que serve | Versão testada |
|---|---|---|
| **Verilator** | Compila SystemVerilog → C++ e simula | 5.042 |
| **riscv64-unknown-elf-as** | Monta assembly RISC-V → binário | GNU Binutils 2.45 |
| **riscv64-unknown-elf-objcopy** | Extrai binário puro do ELF | GNU Binutils 2.45 |
| **riscv64-unknown-elf-objdump** | Mostra disassembly | GNU Binutils 2.45 |
| **Python 3** | Converte binário → hex ($readmemh) | 3.x |
| **make** | Automatiza a compilação | GNU Make |
| **clang++ ou g++** | Compila o testbench C++ | qualquer recente |

### Instalação no macOS

```bash
# Instala via Homebrew (https://brew.sh)
brew install verilator riscv-gnu-toolchain python make

# Verifica as instalações
verilator --version
# → Verilator 5.042 2025-11-02 rev UNKNOWN.REV

riscv64-unknown-elf-as --version
# → GNU assembler (GNU Binutils) 2.45

python3 --version
# → Python 3.x.x

make --version
# → GNU Make 3.x ou superior
```

### Instalação no Ubuntu/Debian Linux

```bash
# Verilator (via apt — pode ser versão antiga, prefira compilar da fonte)
sudo apt-get install verilator

# Para Verilator 5.x da fonte:
git clone https://github.com/verilator/verilator
cd verilator
autoconf && ./configure && make -j$(nproc)
sudo make install

# Toolchain RISC-V
sudo apt-get install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

# Python e make
sudo apt-get install python3 make
```

### Por que cada ferramenta é necessária?

**Verilator** transforma o SystemVerilog em código C++ otimizado e compila uma
simulação executável. É muito mais rápido que simuladores como ModelSim/Questa.

**riscv64-unknown-elf-as** é o assembler da toolchain GNU para RISC-V sem sistema
operacional (`bare-metal`). O sufixo `unknown-elf` indica que não há SO alvo.
Usamos `-march=rv32i` (apenas inteiros 32-bit) e `-mabi=ilp32` (ABI de inteiros).

**bin2hex.py** converte o binário ELF extraído para o formato de hex que o
`$readmemh()` do SystemVerilog entende: uma palavra de 32 bits em hexadecimal
por linha, sem prefixo `0x`.

---

## 3. Estrutura de Arquivos

```
riscv_harvard/
│
├── src/                        ← Código-fonte SystemVerilog
│   ├── alu.sv                  ← Unidade Lógica e Aritmética
│   ├── alu_control.sv          ← Decodificador de operação da ALU
│   ├── register_file.sv        ← Banco de 32 registradores × 32 bits
│   ├── imm_gen.sv              ← Extrai e estende imediatos dos 5 formatos
│   ├── control_unit.sv         ← Decodifica opcode → sinais de controle
│   ├── instr_mem.sv            ← ROM de instruções (4 KB, Harvard)
│   ├── data_mem.sv             ← RAM de dados (4 KB, Harvard)
│   └── riscv_top.sv            ← Top: conecta todos os módulos + datapath
│
├── tb/                         ← Testbenches C++ para Verilator
│   ├── tb_alu.cpp              ← Testa ALU isoladamente (26 casos)
│   ├── tb_regfile.cpp          ← Testa banco de registradores (8 casos)
│   ├── tb_arith.cpp            ← Testa processador: instruções aritméticas
│   ├── tb_loadstore.cpp        ← Testa processador: load e store
│   ├── tb_branch.cpp           ← Testa processador: branches
│   └── tb_jump.cpp             ← Testa processador: JAL e JALR
│
├── programs/                   ← Programas de teste em Assembly RV32I
│   ├── test_arith.s            ← Testa: ADD, SUB, AND, OR, XOR, SLL, SLT...
│   ├── test_arith.hex          ← (gerado pelo Makefile)
│   ├── test_arith.dis          ← (disassembly gerado pelo Makefile)
│   ├── test_load_store.s       ← Testa: LW, SW, LB, SB, LBU, LH, SH, LHU
│   ├── test_branch.s           ← Testa: BEQ, BNE, BLT, BGE, BLTU
│   └── test_jump.s             ← Testa: JAL, JALR
│
├── scripts/
│   └── bin2hex.py              ← Conversor binário→hex para $readmemh
│
├── sim/                        ← Diretório de execução da simulação
│   └── program.hex             ← Programa ativo (copiado pelo Makefile)
│
├── obj_dir/                    ← Artefatos gerados pelo Verilator
│   ├── Varith                  ← Executável: simulador com testbench aritmético
│   ├── Vbranch                 ← Executável: simulador com testbench de branches
│   ├── Vjump                   ← Executável: simulador com testbench de jumps
│   ├── Vloadstore              ← Executável: simulador com testbench load/store
│   ├── Valu                    ← Executável: teste unitário da ALU
│   ├── Vregfile                ← Executável: teste unitário do banco
│   └── *.cpp, *.h, *.a         ← Código C++ gerado pelo Verilator
│
└── Makefile                    ← Automatiza montagem, compilação e testes
```

---

## 4. Arquitetura Harvard — Conceito Profundo

### O que significa "Harvard"?

O nome vem do **Mark I** da Universidade de Harvard (1944), que usava fitas
magnéticas separadas para instruções e dados. Em contraste, o **IAS** de Von
Neumann (1945) usava memória unificada.

```
╔══════════════════════════════════════════════════════════════════╗
║                   ARQUITETURA HARVARD                           ║
║                                                                  ║
║  ┌────────────────┐      ┌───────────────┐      ┌────────────┐  ║
║  │ Memória Instr  │──────│               │──────│ Memória    │  ║
║  │   (ROM 4KB)    │      │   PROCESSADOR │      │ de Dados   │  ║
║  │                │      │               │      │  (RAM 4KB) │  ║
║  │ 0x000: 00500093│      │  PC | ALU     │      │ 0x000: 064 │  ║
║  │ 0x004: 00300113│      │  RegFile      │      │ 0x004: 055 │  ║
║  │ 0x008: 002081B3│      │  Control      │      │ ...        │  ║
║  │    ...         │      │               │      │            │  ║
║  └────────────────┘      └───────────────┘      └────────────┘  ║
║         ▲                       ║                    ▲          ║
║         ║ busca instrução        ║ lê/escreve dados  ║          ║
║         ╚═══════════════════════╝════════════════════╝          ║
║                                                                  ║
║  DOIS BARRAMENTOS INDEPENDENTES → acesso paralelo!              ║
╚══════════════════════════════════════════════════════════════════╝
```

### Vantagem prática em single-cycle

Num processador single-cycle Harvard, no **mesmo ciclo de clock**:
- A **memória de instruções** fornece a instrução atual (busca/fetch)
- A **memória de dados** pode ser lida (load) ou escrita (store)

Isso é possível porque são fisicamente separadas. Em Von Neumann, seria necessário
um árbitro de barramento ou uma cache L1 com portas separadas.

### Como está implementado

```
instr_mem.sv: leitura combinacional (como uma ROM)
  - addr = PC (atualizado a cada posedge clk)
  - instr = mem[PC >> 2]  → disponível imediatamente (mesmo ciclo)

data_mem.sv: leitura combinacional + escrita síncrona
  - leitura: rd = mem[addr >> 2] → disponível combinacionalmente
  - escrita: always_ff @(posedge clk) mem[addr >> 2] <= wd
```

---

## 5. O Ciclo de Instrução Single-Cycle

Em um processador single-cycle, **cada instrução passa por todas as fases
dentro de um único período de clock**. O clock deve ser lento o suficiente
para a instrução mais lenta (tipicamente `load`) completar.

### As 5 fases em single-cycle (paralelas dentro do ciclo)

```
PERÍODO DO CLOCK
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  [1] FETCH      [2] DECODE     [3] EXECUTE  [4] MEM   [5] WB   │
│  Busca a        Decodifica     ALU opera    Lê/escreve Escreve  │
│  instrução      controles      sobre        memória    no       │
│  em imem        e imediatos    rs1, rs2     de dados   RegFile  │
│                                                                 │
│  (tudo isso acontece como lógica combinacional!)                │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  posedge clk:  PC ← PC_next                                     │
│                RegFile[rd] ← write_data   (se reg_write=1)      │
│                DataMem[addr] ← rs2_data   (se mem_write=1)      │
└─────────────────────────────────────────────────────────────────┘
```

### Por que isso funciona?

Toda a lógica entre dois registros (PC e RegFile) é **combinacional** — sem
memória, sem estado. No instante em que o PC tem um novo valor, a instrução
aparece na saída da memória de instruções, os controles são calculados, a ALU
opera, e o resultado está pronto para ser escrito. Tudo isso acontece
"instantaneamente" (na prática, após o atraso de propagação dos gates).

### Limitação: frequência de clock

O clock deve esperar pela instrução mais lenta. Tipicamente:

```
Instrução mais rápida: R-type (sem memória)
  Caminho crítico: imem → decodificador → ALU → RegFile write
  ≈ T_imem + T_ctrl + T_alu + T_rf_write

Instrução mais lenta: Load (lw)
  Caminho crítico: imem → decodificador → ALU(endereço) → dmem → RegFile
  ≈ T_imem + T_ctrl + T_alu + T_dmem + T_rf_write
```

Todas as instruções devem esperar pelo caminho mais longo (load).
O **pipeline** resolve isso dividindo em estágios — veja a [Seção 15](#15-conceito-de-pipeline).

---

## 6. Componentes — Explicação Detalhada

### 6.1 ALU — `src/alu.sv`

A ALU realiza todas as operações aritméticas e lógicas do processador.

```
          ┌─────────────────────────────────────┐
  a[31:0] ─┤                                     ├─ result[31:0]
  b[31:0] ─┤              ALU                    │
  op[3:0] ─┤                                     ├─ zero
          └─────────────────────────────────────┘
```

**Tabela de operações:**

| `op` binário | Operação | Expressão | Usada por |
|---|---|---|---|
| `0000` | ADD  | `result = a + b` | add, addi, lw, sw, auipc, jalr |
| `0001` | SUB  | `result = a - b` | sub, beq, bne |
| `0010` | AND  | `result = a & b` | and, andi |
| `0011` | OR   | `result = a \| b` | or, ori |
| `0100` | XOR  | `result = a ^ b` | xor, xori |
| `0101` | SLL  | `result = a << b[4:0]` | sll, slli |
| `0110` | SRL  | `result = a >> b[4:0]` (lógico) | srl, srli |
| `0111` | SRA  | `result = $signed(a) >>> b[4:0]` (aritmético) | sra, srai |
| `1000` | SLT  | `result = ($signed(a) < $signed(b)) ? 1 : 0` | slt, slti, blt, bge |
| `1001` | SLTU | `result = (a < b) ? 1 : 0` | sltu, sltiu, bltu, bgeu |

**Flag `zero`:** `zero = (result == 0)`. Usada para BEQ/BNE.

**Por que SLT para branches?**
BLT (branch if less than) usa a ALU com operação SLT. Se `SLT(rs1, rs2) = 1`,
então `rs1 < rs2` (com sinal), e o branch é tomado. BGE usa `SLT` com
`branch_inv = 1` (inverte a decisão).

**SRA vs SRL:** A diferença é crucial para números negativos:
```
Número: 0x80000000 (-2147483648 em complemento de 2)
SRL 1:  0x40000000 (copia 0 no bit mais significativo)
SRA 1:  0xC0000000 (copia o bit de sinal = 1)
```

### 6.2 Unidade de Controle da ALU — `src/alu_control.sv`

Esta unidade recebe `alu_op` (2 bits, da unidade de controle principal),
`funct3` (3 bits) e `funct7[5]` (1 bit) e determina qual operação a ALU executa.

```
  alu_op[1:0] ──┐
  funct3[2:0] ──┼──► ALU Control ──► alu_sel[3:0]
  funct7[6:0] ──┘                 └──► branch_inv
```

**Por que dois níveis de controle?**

A abordagem de dois níveis é mais modular: a unidade de controle principal
decide o "tipo geral" da operação (ADD para load/store, branch, R-type,
I-arith), e a unidade da ALU refina com os bits funct3/funct7.

**Lógica de `alu_op`:**

```
alu_op = 00: Força ADD   → usado em LOAD (lw,lh,lb) e STORE (sw,sh,sb)
              O endereço é sempre rs1 + imm_signed → ADD

alu_op = 01: Branch     → usa funct3 para determinar tipo de comparação:
              funct3=000 (BEQ):  SUB, branch se zero=1
              funct3=001 (BNE):  SUB, branch se zero=0  (branch_inv=1)
              funct3=100 (BLT):  SLT, branch se result[0]=1
              funct3=101 (BGE):  SLT, branch se result[0]=0 (branch_inv=1)
              funct3=110 (BLTU): SLTU, branch se result[0]=1
              funct3=111 (BGEU): SLTU, branch se result[0]=0 (branch_inv=1)

alu_op = 10: R-type     → usa funct3 + funct7[5]:
              funct3=000, funct7[5]=0: ADD
              funct3=000, funct7[5]=1: SUB
              funct3=001:              SLL
              funct3=010:              SLT
              funct3=011:              SLTU
              funct3=100:              XOR
              funct3=101, funct7[5]=0: SRL
              funct3=101, funct7[5]=1: SRA
              funct3=110:              OR
              funct3=111:              AND

alu_op = 11: I-type arith → igual ao R-type, mas sem SUB (nunca funct7[5]=1
                             exceto para SRAI):
              funct3=000: ADD   (ADDI)
              funct3=001: SLL   (SLLI)
              funct3=010: SLT   (SLTI)
              funct3=011: SLTU  (SLTIU)
              funct3=100: XOR   (XORI)
              funct3=101, funct7[5]=0: SRL (SRLI)
              funct3=101, funct7[5]=1: SRA (SRAI)
              funct3=110: OR    (ORI)
              funct3=111: AND   (ANDI)
```

### 6.3 Banco de Registradores — `src/register_file.sv`

O RISC-V RV32I tem **32 registradores de propósito geral** de 32 bits:

```
┌──────────────────────────────────────────────────────────────┐
│                  BANCO DE REGISTRADORES                      │
│                                                              │
│  x0  = 0 (sempre)   x8  = s0/fp   x16 = a6    x24 = s8     │
│  x1  = ra (ret.addr)x9  = s1      x17 = a7    x25 = s9     │
│  x2  = sp (stack)   x10 = a0      x18 = s2    x26 = s10    │
│  x3  = gp           x11 = a1      x19 = s3    x27 = s11    │
│  x4  = tp           x12 = a2      x20 = s4    x28 = t3     │
│  x5  = t0           x13 = a3      x21 = s5    x29 = t4     │
│  x6  = t1           x14 = a4      x22 = s6    x30 = t5     │
│  x7  = t2           x15 = a5      x23 = s7    x31 = t6     │
│                                                              │
│  Nomes de ABI: ra=return addr, sp=stack ptr, a0-a7=args     │
│  s0-s11=saved, t0-t6=temporários, gp=global ptr            │
└──────────────────────────────────────────────────────────────┘
```

**x0 — o registrador especial:**
x0 é **hardwired zero**. No hardware, não há circuito flip-flop para ele:
qualquer leitura retorna 0, qualquer escrita é descartada silenciosamente.
Isso é incrivelmente útil:
```assembly
add  x1, x0, x2    # x1 = 0 + x2 = x2  (move/copy)
sub  x3, x0, x4    # x3 = 0 - x4 = -x4 (negação)
beq  x5, x0, label # branch se x5 == 0  (beqz)
sw   x6, 0(x0)     # store em endereço 0
```

**Portos do módulo:**

```systemverilog
// Escrita (1 porta, síncrona):
input  clk, we          // Clock e write-enable
input  [4:0] rd         // Registrador destino
input  [31:0] wd        // Dado a escrever

// Leitura (2 portas, combinacional):
input  [4:0] rs1, rs2   // Endereços a ler
output [31:0] rd1, rd2  // Dados lidos

// Debug (combinacional):
input  [4:0] dbg_reg_sel
output [31:0] dbg_reg_val
```

**Por que leitura combinacional?**
Em single-cycle, a leitura dos registradores acontece no mesmo ciclo que a
execução. Se fosse síncrona, precisaríamos de um ciclo extra só para ler.
A leitura combinacional dispensa isso — os dados ficam disponíveis
imediatamente após `rs1`/`rs2` se estabilizarem.

### 6.4 Gerador de Imediatos — `src/imm_gen.sv`

O RISC-V tem 5 formatos de instrução, e cada um codifica o imediato de forma
diferente. O gerador extrai e faz **extensão de sinal** (sign-extension) do
imediato de 12 ou 20 bits para 32 bits.

**Por que extensão de sinal?**

Se um imediato de 12 bits representa `-1` (= `0xFFF` = `111111111111b`), ao
estendê-lo para 32 bits, queremos `0xFFFFFFFF` (= -1 em 32 bits), não
`0x00000FFF`. A extensão de sinal copia o bit mais significativo do imediato
para todos os bits superiores:

```systemverilog
// Extensão de sinal de 12 para 32 bits:
imm_i = {{20{instr[31]}}, instr[31:20]};
//        ^20 cópias do bit 31^   ^12 bits do imediato^
```

**Formatos e como o imediato é extraído:**

```
I-type [arith, load, jalr]:
  31          20 19    15 14  12 11     7 6      0
  ┌────────────┬─────────┬──────┬────────┬────────┐
  │ imm[11:0]  │   rs1   │funct3│   rd   │ opcode │
  └────────────┴─────────┴──────┴────────┴────────┘
  imm_i = sext(inst[31:20])

S-type [store]:
  31      25 24    20 19    15 14  12 11     7 6      0
  ┌─────────┬────────┬────────┬──────┬────────┬────────┐
  │imm[11:5]│  rs2   │  rs1   │funct3│imm[4:0]│ opcode │
  └─────────┴────────┴────────┴──────┴────────┴────────┘
  imm_s = sext({inst[31:25], inst[11:7]})
  (imediato dividido em duas partes na instrução)

B-type [branch]:
  31    30    25 24  20 19  15 14  12 11   8  7  6      0
  ┌──┬──────────┬──────┬──────┬──────┬──────┬──┬────────┐
  │12│ imm[10:5]│ rs2  │ rs1  │funct3│imm[4:1]│11│opcode│
  └──┴──────────┴──────┴──────┴──────┴──────┴──┴────────┘
  imm_b = sext({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})
  (bit 0 sempre 0: branches são alinhados em 2 bytes)
  (bits embaralhados para maximizar compartilhamento com outros formatos)

U-type [lui, auipc]:
  31                  12 11     7 6      0
  ┌────────────────────┬─────────┬────────┐
  │    imm[31:12]      │   rd    │ opcode │
  └────────────────────┴─────────┴────────┘
  imm_u = {inst[31:12], 12'b0}
  (20 bits superiores, 12 bits inferiores = 0)

J-type [jal]:
  31  30      21  20  19      12 11     7 6      0
  ┌──┬──────────┬──┬────────────┬─────────┬────────┐
  │20│ imm[10:1]│11│ imm[19:12] │   rd    │ opcode │
  └──┴──────────┴──┴────────────┴─────────┴────────┘
  imm_j = sext({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})
  (bit 0 sempre 0: jumps alinhados em 2 bytes)
```

**Por que os bits do B-type e J-type são "embaralhados"?**

O RISC-V embaralha os bits do imediato para maximizar o número de bits em
posições idênticas entre os formatos I, S, B e J. Isso economiza lógica
no hardware real — o mesmo circuito pode extrair bits de múltiplos formatos
sem demultiplexadores extras.

### 6.5 Unidade de Controle Principal — `src/control_unit.sv`

Recebe apenas o **opcode** (7 bits, `inst[6:0]`) e gera todos os sinais que
controlam o datapath. É completamente combinacional.

**Os 9 opcodes RV32I suportados:**

```
0110011 (0x33) → R-type:      add, sub, and, or, xor, sll, srl, sra, slt, sltu
0010011 (0x13) → I-arith:     addi, andi, ori, xori, slti, sltiu, slli, srli, srai
0000011 (0x03) → Load:        lw, lh, lb, lhu, lbu
0100011 (0x23) → Store:       sw, sh, sb
1100011 (0x63) → Branch:      beq, bne, blt, bge, bltu, bgeu
1101111 (0x6F) → JAL
1100111 (0x67) → JALR
0110111 (0x37) → LUI
0010111 (0x17) → AUIPC
```

**Sinais gerados e seu significado:**

| Sinal | Largura | Significado |
|---|---|---|
| `reg_write` | 1 bit | Habilita escrita no banco de registradores (posedge clk) |
| `alu_src_a` | 1 bit | `0`=operando A é rs1; `1`=operando A é PC (para AUIPC) |
| `alu_src_b` | 1 bit | `0`=operando B é rs2; `1`=operando B é imediato |
| `mem_read`  | 1 bit | Habilita leitura da memória de dados |
| `mem_write` | 1 bit | Habilita escrita na memória de dados (posedge clk) |
| `branch`    | 1 bit | Indica instrução de branch (avalia condição) |
| `jump`      | 1 bit | Indica JAL (salto incondicional relativo ao PC) |
| `jump_r`    | 1 bit | Indica JALR (salto incondicional relativo a registrador) |
| `mem_to_reg`| 2 bits | Seleciona o dado para escrita no registrador |
| `alu_op`    | 2 bits | Código para a unidade de controle da ALU |

**`mem_to_reg` — seletor de write-back:**

```
mem_to_reg = 00: escreve resultado da ALU  (R-type, I-arith, AUIPC)
mem_to_reg = 01: escreve dado da memória   (loads: lw, lh, lb...)
mem_to_reg = 10: escreve PC+4             (JAL e JALR: link register)
mem_to_reg = 11: escreve imm_u diretamente (LUI: coloca imediato no registrador)
```

### 6.6 Memória de Instruções — `src/instr_mem.sv`

```
              PC[11:2]
                  │
      ┌───────────▼────────────┐
      │      ROM 1024×32       │   ← inicializada com $readmemh
      │   mem[0] = 0x00500093  │
      │   mem[1] = 0x00300113  │
      │   mem[2] = 0x002081B3  │
      │      ...               │
      └───────────┬────────────┘
                  │
              instr[31:0]
```

**Como o endereçamento funciona:**

O PC é um endereço de byte (32 bits). As instruções têm 4 bytes e estão sempre
alinhadas em múltiplos de 4. Para indexar o array de palavras de 32 bits:

```systemverilog
wire [9:0] iidx = addr[11:2];  // divide por 4 (descarta 2 bits inferiores)
assign instr = mem[iidx];
```

Exemplo: `PC = 0x0C` (12 em decimal) → `iidx = 12 >> 2 = 3` → `mem[3]`

**Carregamento do programa:**

```systemverilog
initial begin
    $readmemh("program.hex", mem);
end
```

O `$readmemh` lê um arquivo de texto onde cada linha é uma palavra de 32 bits
em hexadecimal. O Makefile copia o hex correto para `sim/program.hex` antes
de executar cada simulação.

**Por que ROM e não RAM?**

Na arquitetura Harvard, a memória de instruções é tipicamente somente leitura
durante a execução. O processador nunca escreve nela (não há Store na imem).
Isso é exatamente o modelo Harvard original.

### 6.7 Memória de Dados — `src/data_mem.sv`

```
              addr[11:2]           funct3    wd[31:0]   clk
                  │                   │          │       │
      ┌───────────▼───────────────────▼──────────▼───────▼──┐
      │                  RAM 1024×32                         │
      │  ┌─────────────────────────────────────────────────┐ │
      │  │ Escrita síncrona (posedge clk):                 │ │
      │  │   SB: escreve 1 byte no offset byte_off         │ │
      │  │   SH: escreve 2 bytes no offset byte_off[1]     │ │
      │  │   SW: escreve a palavra inteira                  │ │
      │  └─────────────────────────────────────────────────┘ │
      │  ┌─────────────────────────────────────────────────┐ │
      │  │ Leitura combinacional:                          │ │
      │  │   LB:  sext(byte selecionado)                   │ │
      │  │   LBU: zext(byte selecionado)                   │ │
      │  │   LH:  sext(half-word selecionada)              │ │
      │  │   LHU: zext(half-word selecionada)              │ │
      │  │   LW:  palavra inteira                          │ │
      │  └─────────────────────────────────────────────────┘ │
      └──────────────────────────────────┬─────────────────── ┘
                                         │ rd[31:0]
```

**Endereçamento de bytes:**

O RISC-V usa endereçamento de bytes (byte-addressable). Para uma palavra
em `mem[widx]` (array de 32 bits), o byte no offset 0 está em `mem[widx][7:0]`:

```
Endereço 0x0C (decimal 12):
  widx    = 0x0C >> 2 = 3      (índice da palavra)
  byte_off = 0x0C & 3 = 0      (byte offset dentro da palavra)

  LB:   rd = sext(mem[3][7:0])   byte_off=0 → bits 7:0
  LBU:  rd = zext(mem[3][7:0])   (sem sinal)

Endereço 0x0D (decimal 13):
  widx    = 3
  byte_off = 1
  LB:   rd = sext(mem[3][15:8])  byte_off=1 → bits 15:8
```

**Por que `funct3` diferencia LB de LBU?**

`LB` (load byte) faz extensão de sinal: se o byte lido for `0xAB = 10101011b`,
o bit mais significativo é 1, então o valor é negativo em complemento de 2.
Após extensão de sinal: `0xFFFFFFAB = -85`.

`LBU` (load byte unsigned) faz extensão de zero: `0xAB` → `0x000000AB = 171`.

```
funct3 = 000: LB  (byte com sinal)
funct3 = 001: LH  (half com sinal)
funct3 = 010: LW  (word — sempre 32 bits, sem extensão)
funct3 = 100: LBU (byte sem sinal)
funct3 = 101: LHU (half sem sinal)
```

### 6.8 Top-Level — `src/riscv_top.sv`

O módulo top conecta todos os outros e implementa o **datapath completo**:

```
Entradas:  clk, rst_n
Saídas:    dbg_pc, dbg_instr, dbg_alu_result, dbg_reg_wd, dbg_reg_we
Bidirec.:  dbg_reg_sel (in), dbg_reg_val (out)
```

**Fluxo de dados completo:**

```
1. PC → instr_mem → instr[31:0]
2. instr[6:0] → control_unit → sinais de controle
3. instr[31:0] → imm_gen → imm_i, imm_s, imm_b, imm_u, imm_j
4. instr[19:15] → regfile (rs1) → rs1_data
5. instr[24:20] → regfile (rs2) → rs2_data
6. [alu_src_a ? PC : rs1_data] → alu_a
7. [alu_src_b ? imm_sel : rs2_data] → alu_b
8. {funct3, funct7, alu_op} → alu_control → alu_sel
9. {alu_a, alu_b, alu_sel} → alu → alu_result, zero
10. alu_result → data_mem (endereço) → mem_rd
11. mem_to_reg → MUX → reg_wd
12. @posedge: regfile[rd] ← reg_wd  (se reg_write)
13. @posedge: data_mem[alu_result] ← rs2_data  (se mem_write)
14. Lógica de branch/jump → pc_next
15. @posedge: PC ← pc_next
```

---

## 7. Formatos de Instrução RISC-V — Encoding Binário

### Como decodificar uma instrução manualmente

Dado o hexadecimal `0x002081B3`, vamos decodificar:

```
Hex:    0x002081B3
Binary: 0000 0000 0010 0000 1000 0001 1011 0011

Bits:   31..25   24..20  19..15  14..12  11..7   6..0
        0000000  00010   00001   000     00011   0110011
        funct7   rs2=2   rs1=1   funct3  rd=3    opcode

opcode = 0110011 → R-type
funct3 = 000, funct7 = 0000000 → ADD
rd=3, rs1=1, rs2=2

Instrução: add x3, x1, x2  (x3 = x1 + x2)
```

### Exemplos de encoding para cada formato

#### R-type: `sub x4, x1, x2`

```
sub x4, x1, x2:
  funct7 = 0100000  (bit 5 = 1 → subtração)
  rs2    = 00010    (x2)
  rs1    = 00001    (x1)
  funct3 = 000
  rd     = 00100    (x4)
  opcode = 0110011

Binário: 0100000_00010_00001_000_00100_0110011
       = 0100 0000 0010 0000 1000 0010 0011 0011
       = 0x40208233
```

#### I-type: `addi x8, x1, 5`

```
addi x8, x1, 5:
  imm[11:0] = 000000000101  (5 em 12 bits)
  rs1       = 00001          (x1)
  funct3    = 000
  rd        = 01000          (x8)
  opcode    = 0010011

Binário: 000000000101_00001_000_01000_0010011
       = 0000 0000 0101 0000 1000 0100 0001 0011
       = 0x00508413
```

#### S-type: `sw x1, 0(x0)`

```
sw x1, 0(x0):
  imm = 0 → imm[11:5] = 0000000, imm[4:0] = 00000
  rs2    = 00001  (x1, dado a escrever)
  rs1    = 00000  (x0, endereço base)
  funct3 = 010    (word)
  opcode = 0100011

Binário: 0000000_00001_00000_010_00000_0100011
       = 0x00102023
```

#### B-type: `beq x1, x2, +8` (salto para frente de 8 bytes)

```
beq x1, x2, 8:
  offset = 8 = 0b0000_0000_1000
  imm[12]=0, imm[11]=0, imm[10:5]=000000, imm[4:1]=0100
  rs2    = 00010  (x2)
  rs1    = 00001  (x1)
  funct3 = 000    (BEQ)
  opcode = 1100011

Encoding: [31]=0 [30:25]=000000 [24:20]=00010 [19:15]=00001
          [14:12]=000 [11:8]=0100 [7]=0 [6:0]=1100011

Binário: 0_000000_00010_00001_000_0100_0_1100011
       = 0000 0000 0010 0000 1000 0100 0110 0011
       = 0x00208463
```

#### U-type: `lui x10, 1` (carrega 0x1000 em x10)

```
lui x10, 1:
  imm[31:12] = 00000000000000000001  (= 1)
  rd         = 01010  (x10)
  opcode     = 0110111

Resultado: x10 = {imm[31:12], 12'b0} = 0x00001000 = 4096

Binário: 00000000000000000001_01010_0110111
       = 0x00001537
```

#### J-type: `jal x1, 12` (salto de +12 bytes)

```
jal x1, 12:
  offset = 12 = 0b0000_0000_1100
  imm[20]=0, imm[10:1]=0000000110, imm[11]=0, imm[19:12]=00000000
  rd = 00001 (x1)
  opcode = 1101111

Encoding (J-type bits embaralhados):
  [31]=imm[20]=0
  [30:21]=imm[10:1]=0000000110
  [20]=imm[11]=0
  [19:12]=imm[19:12]=00000000
  [11:7]=rd=00001
  [6:0]=opcode=1101111

Binário: 0_0000001100_0_00000000_00001_1101111
       = 0x00C000EF
```

---

## 8. Conjunto de Instruções — Tabela Completa

### Instruções R-type (funct7 + funct3 + opcode = 0110011)

| Instrução | funct7 | funct3 | Operação | Exemplo |
|---|---|---|---|---|
| `add`  | 0000000 | 000 | `rd = rs1 + rs2` | `add x3, x1, x2` |
| `sub`  | 0100000 | 000 | `rd = rs1 - rs2` | `sub x4, x1, x2` |
| `sll`  | 0000000 | 001 | `rd = rs1 << rs2[4:0]` | `sll x5, x1, x2` |
| `slt`  | 0000000 | 010 | `rd = (rs1 <ₛ rs2) ? 1 : 0` | `slt x6, x1, x2` |
| `sltu` | 0000000 | 011 | `rd = (rs1 <ᵤ rs2) ? 1 : 0` | `sltu x7, x1, x2` |
| `xor`  | 0000000 | 100 | `rd = rs1 ^ rs2` | `xor x8, x1, x2` |
| `srl`  | 0000000 | 101 | `rd = rs1 >> rs2[4:0]` (lógico) | `srl x9, x1, x2` |
| `sra`  | 0100000 | 101 | `rd = rs1 >>> rs2[4:0]` (arith) | `sra x10, x1, x2` |
| `or`   | 0000000 | 110 | `rd = rs1 \| rs2` | `or x11, x1, x2` |
| `and`  | 0000000 | 111 | `rd = rs1 & rs2` | `and x12, x1, x2` |

### Instruções I-type Aritméticas (opcode = 0010011)

| Instrução | funct3 | Operação |
|---|---|---|
| `addi`  | 000 | `rd = rs1 + sext(imm12)` |
| `slli`  | 001 | `rd = rs1 << imm[4:0]` |
| `slti`  | 010 | `rd = (rs1 <ₛ sext(imm12)) ? 1 : 0` |
| `sltiu` | 011 | `rd = (rs1 <ᵤ sext(imm12)) ? 1 : 0` |
| `xori`  | 100 | `rd = rs1 ^ sext(imm12)` |
| `srli`  | 101 | `rd = rs1 >> imm[4:0]` (funct7[5]=0) |
| `srai`  | 101 | `rd = rs1 >>> imm[4:0]` (funct7[5]=1) |
| `ori`   | 110 | `rd = rs1 \| sext(imm12)` |
| `andi`  | 111 | `rd = rs1 & sext(imm12)` |

### Instruções de Load (opcode = 0000011)

| Instrução | funct3 | Operação |
|---|---|---|
| `lb`  | 000 | `rd = sext(mem[rs1+imm][7:0])` |
| `lh`  | 001 | `rd = sext(mem[rs1+imm][15:0])` |
| `lw`  | 010 | `rd = mem[rs1+imm][31:0]` |
| `lbu` | 100 | `rd = zext(mem[rs1+imm][7:0])` |
| `lhu` | 101 | `rd = zext(mem[rs1+imm][15:0])` |

### Instruções de Store (opcode = 0100011)

| Instrução | funct3 | Operação |
|---|---|---|
| `sb` | 000 | `mem[rs1+imm][7:0] = rs2[7:0]` |
| `sh` | 001 | `mem[rs1+imm][15:0] = rs2[15:0]` |
| `sw` | 010 | `mem[rs1+imm][31:0] = rs2[31:0]` |

### Instruções de Branch (opcode = 1100011)

| Instrução | funct3 | Condição |
|---|---|---|
| `beq`  | 000 | `PC += sext(imm13)` se `rs1 == rs2` |
| `bne`  | 001 | `PC += sext(imm13)` se `rs1 != rs2` |
| `blt`  | 100 | `PC += sext(imm13)` se `rs1 <ₛ rs2` |
| `bge`  | 101 | `PC += sext(imm13)` se `rs1 ≥ₛ rs2` |
| `bltu` | 110 | `PC += sext(imm13)` se `rs1 <ᵤ rs2` |
| `bgeu` | 111 | `PC += sext(imm13)` se `rs1 ≥ᵤ rs2` |

O offset é em bytes e sempre par (bit 0 = 0 implicitamente).

### Instruções de Jump

| Instrução | opcode | Operação |
|---|---|---|
| `jal rd, imm` | 1101111 | `rd = PC+4; PC = PC + sext(imm21)` |
| `jalr rd, rs1, imm` | 1100111 | `rd = PC+4; PC = (rs1 + sext(imm12)) & ~1` |

**`jal x0, loop`** é o "halt" do RISC-V: salta para si mesmo (`jal` com `rd=x0`
descarta o endereço de retorno, formando um loop infinito de 1 instrução).

### Instruções U-type

| Instrução | opcode | Operação |
|---|---|---|
| `lui rd, imm` | 0110111 | `rd = imm20 << 12` (zeros nos 12 bits baixos) |
| `auipc rd, imm` | 0010111 | `rd = PC + (imm20 << 12)` |

**Como carregar um valor de 32 bits com `lui` + `addi`:**
```assembly
lui  x1, 0xDEADB   # x1 = 0xDEADB000
addi x1, x1, 0xEEF # x1 = 0xDEADB000 + 0xEEF = 0xDEADBEEF
                    # (cuidado: addi faz sext de 12 bits — se bit 11 for 1,
                    #  o sext é negativo e você deve compensar no lui)
```

---

## 9. Trace de Execução — Passo a Passo por Instrução

### Exemplo: `add x3, x1, x2` (assumindo x1=5, x2=3)

**Encoding:** `0x002081B3`

```
Fase 1 — FETCH (combinacional, instantâneo após PC estabilizar):
  PC = 0x08
  instr = imem[0x08 >> 2] = imem[2] = 0x002081B3

Fase 2 — DECODE:
  opcode  = 0110011  → R-type
  funct3  = 000
  funct7  = 0000000
  rd      = 00011  = 3
  rs1     = 00001  = 1
  rs2     = 00010  = 2

  control_unit gera:
    reg_write  = 1
    alu_src_a  = 0  (usa rs1_data)
    alu_src_b  = 0  (usa rs2_data, não imediato)
    mem_read   = 0
    mem_write  = 0
    branch     = 0
    jump       = 0
    jump_r     = 0
    mem_to_reg = 00  (resultado da ALU)
    alu_op     = 10  (R-type)

  imm_gen:  não importa para R-type (sinais de controle não selecionam imediato)

  regfile lê:
    rs1_data = regfile[1] = 5
    rs2_data = regfile[2] = 3

Fase 3 — EXECUTE:
  alu_a = rs1_data = 5      (alu_src_a=0)
  alu_b = rs2_data = 3      (alu_src_b=0)

  alu_control:
    alu_op=10 (R-type), funct3=000, funct7[5]=0 → alu_sel = ADD (0000)

  ALU: result = 5 + 3 = 8, zero = 0

Fase 4 — MEMÓRIA:
  mem_read=0, mem_write=0 → nenhum acesso à memória de dados

Fase 5 — WRITE-BACK:
  reg_wd = alu_result = 8   (mem_to_reg=00)
  PC_next = PC + 4 = 0x0C   (sem branch, sem jump)

@posedge clk:
  regfile[3] ← 8            (reg_write=1, rd=3)
  PC ← 0x0C
```

### Exemplo: `lw x2, 0(x0)` (carrega palavra do endereço 0)

**Encoding:** `0x00002103`

```
FETCH:   instr = 0x00002103
DECODE:  opcode=0000011 (Load), funct3=010 (LW), rd=2, rs1=0, imm_i=0

  control_unit:
    reg_write  = 1
    alu_src_b  = 1  (usa imediato)
    mem_read   = 1  ← habilita leitura da memória de dados
    mem_to_reg = 01 ← escreve dado da memória no registrador

EXECUTE:
  alu_a = regfile[0] = 0     (rs1=x0, sempre 0)
  alu_b = imm_i = 0          (imediato = 0)
  alu_sel = ADD              (alu_op=00)
  alu_result = 0 + 0 = 0     (endereço = 0)

MEMÓRIA:
  mem_read=1 → data_mem lê endereço 0x00000000
  funct3=010 → leitura de word: rd = mem[0][31:0]
  Suponha que mem[0] = 0x00000064 (= 100)
  mem_rd = 0x00000064

WRITE-BACK:
  reg_wd = mem_rd = 0x00000064 = 100   (mem_to_reg=01)

@posedge: regfile[2] ← 100
```

### Exemplo: `beq x1, x2, +8` — branch tomado (x1=x2=5)

```
FETCH:   instr = 0x00208463
DECODE:  opcode=1100011 (Branch), funct3=000 (BEQ), rs1=1, rs2=2, imm_b=+8

  control_unit:
    branch  = 1
    alu_op  = 01   (branch comparison)
    reg_write=0, mem_read=0, mem_write=0

EXECUTE:
  alu_a = rs1_data = 5
  alu_b = rs2_data = 5
  alu_sel = SUB (alu_op=01, funct3=000 → BEQ)
  ALU: result = 5 - 5 = 0, zero = 1

LÓGICA DE BRANCH:
  take_branch logic:
    alu_sel == SUB (0001) → usa zero flag
    branch_inv = 0 (BEQ não inverte)
    take_branch = (branch=1) && (zero=1) = 1  ← branch tomado!

  branch_target = PC + imm_b = 0x08 + 8 = 0x10

PRÓXIMO PC:
  pc_next = branch_target = 0x10   (take_branch=1)

@posedge: PC ← 0x10
Resultado: pula 2 instruções (0x08→0x10)
```

### Exemplo: `jal x1, +12`

```
FETCH:   instr = 0x00C000EF
DECODE:  opcode=1101111 (JAL), rd=1, imm_j=+12

  control_unit:
    jump     = 1
    reg_write = 1
    mem_to_reg = 10  (escreve PC+4 em rd)

EXECUTE:
  PC = 0x00 (suponha que é a primeira instrução)
  pc_plus4 = 0x04
  pc_next = PC + imm_j = 0x00 + 12 = 0x0C

WRITE-BACK:
  reg_wd = pc_plus4 = 0x04   (mem_to_reg=10 → endereço de retorno)

@posedge:
  regfile[1] ← 0x04          (link register = PC+4)
  PC ← 0x0C                  (salta para PC+12)
```

---

## 10. Sinais de Controle — Tabela Detalhada

| Instrução | `rw` | `src_a` | `src_b` | `mr` | `mw` | `br` | `j` | `jr` | `m2r` | `aop` |
|---|---|---|---|---|---|---|---|---|---|---|
| R-type (add,sub...) | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 00 | 10 |
| I-arith (addi...)   | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 00 | 11 |
| lw, lh, lb, lbu, lhu| 1 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 01 | 00 |
| sw, sh, sb          | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 00 | 00 |
| beq, bne, blt...    | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 00 | 01 |
| jal                 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 10 | -- |
| jalr                | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 10 | 00 |
| lui                 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 11 | -- |
| auipc               | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 00 | 00 |

Legenda: `rw`=reg_write, `src_a`=alu_src_a, `src_b`=alu_src_b, `mr`=mem_read,
`mw`=mem_write, `br`=branch, `j`=jump, `jr`=jump_r, `m2r`=mem_to_reg, `aop`=alu_op

---

## 11. Como Reproduzir do Zero

Esta seção assume que você está começando do zero em um Mac sem nada instalado.

### Passo 1 — Instalar Homebrew (gerenciador de pacotes macOS)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Homebrew é o gerenciador de pacotes mais usado no macOS. Sem ele, você precisaria
baixar e compilar cada ferramenta manualmente.

### Passo 2 — Instalar as ferramentas

```bash
brew install verilator riscv-gnu-toolchain python make
```

Isso instala:
- **verilator** — compila SystemVerilog para C++ e simula
- **riscv-gnu-toolchain** — cross-compiler para RISC-V sem SO (`as`, `objcopy`, `objdump`)
- **python** — Python 3 (para o script bin2hex.py)
- **make** — automatiza o processo de build

**Tempo estimado:** 5–15 minutos (riscv-gnu-toolchain é o maior pacote)

### Passo 3 — Verificar instalação

```bash
verilator --version
# Saída: Verilator 5.042 (ou superior)

riscv64-unknown-elf-as --version
# Saída: GNU assembler (GNU Binutils) 2.45

python3 --version
# Saída: Python 3.x.x

make --version
# Saída: GNU Make 3.x
```

Se alguma ferramenta não for encontrada:
```bash
# Verificar se está no PATH
echo $PATH
# Se o Homebrew foi instalado em /opt/homebrew (Apple Silicon):
export PATH="/opt/homebrew/bin:$PATH"
```

### Passo 4 — Navegar até o diretório

```bash
cd /caminho/para/neander_riscV/riscv_harvard
ls src/
# Deve listar: alu.sv  alu_control.sv  control_unit.sv  data_mem.sv
#              imm_gen.sv  instr_mem.sv  register_file.sv  riscv_top.sv
```

### Passo 5 — Compilar e executar todos os testes

```bash
make all
```

### Passo 6 — O que acontece internamente no `make all`

```
make programs  (monta todos os assembly):
  Para cada .s em programs/:
    1. riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 → .o (ELF 32-bit)
    2. riscv64-unknown-elf-objdump -d -M no-aliases → .dis (disassembly)
    3. riscv64-unknown-elf-objcopy -O binary → .bin (binário puro)
    4. python3 scripts/bin2hex.py → .hex (formato $readmemh)

make alu  (teste unitário da ALU):
    verilator --cc --sv --exe --build \
        --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
        --top-module alu \
        src/alu.sv tb/tb_alu.cpp -o Valu
    → gera obj_dir/Valu (executável C++)
    obj_dir/Valu  → executa 26 verificações

make regfile  (teste unitário do banco de registradores):
    verilator ... register_file.sv tb/tb_regfile.cpp -o Vregfile
    obj_dir/Vregfile  → executa 8 verificações

make arith  (teste integrado — processador completo):
    verilator ... src/riscv_top.sv tb/tb_arith.cpp -o Varith
    cp programs/test_arith.hex sim/program.hex
    cd sim && ../obj_dir/Varith  → executa 15 verificações

make loadstore, branch, jump  (idem, outros programas)
```

### Passo 7 — Executar um teste manualmente (entender cada etapa)

```bash
# 1. Montar o arquivo assembly → objeto ELF
riscv64-unknown-elf-as \
    -march=rv32i \    # arquitetura alvo: RV32I (base inteiro 32 bits)
    -mabi=ilp32 \     # ABI: int/long/pointer = 32 bits
    -o programs/test_arith.o \
    programs/test_arith.s

# Explicação dos flags:
#   -march=rv32i  → sem extensões (sem M/A/F/D/C). Exatamente RV32I base.
#   -mabi=ilp32   → "integer/long/pointer = 32 bits". Necessário para 32-bit.

# 2. Inspecionar com disassembly (muito útil para debug)
riscv64-unknown-elf-objdump \
    -d \              # disassembla a seção .text
    -M no-aliases \   # mostra nomes reais: "addi x1, x0, 5" (não "li x1, 5")
    programs/test_arith.o

# Saída:
# 00000000 <_start>:
#    0: 00500093    addi    x1,x0,5      ← endereço 0x00, encoding 0x00500093
#    4: 00300113    addi    x2,x0,3
#    8: 002081b3    add     x3,x1,x2
#    ...

# 3. Extrair binário puro (sem cabeçalhos ELF)
riscv64-unknown-elf-objcopy \
    -O binary \       # formato de saída: binário puro (só os bytes das instruções)
    programs/test_arith.o \
    programs/test_arith.bin

# Por que precisamos disso?
# O arquivo .o é formato ELF: tem cabeçalho, seções, metadados.
# O $readmemh do SystemVerilog precisa de bytes brutos de instrução.
# -O binary extrai exatamente o conteúdo da seção .text, sem nada extra.

# 4. Converter binário → formato $readmemh
python3 scripts/bin2hex.py \
    programs/test_arith.bin \
    programs/test_arith.hex

# bin2hex.py lê o .bin de 4 em 4 bytes (little-endian),
# e escreve cada palavra de 32 bits como uma linha hex:
# 00500093    ← addi x1, x0, 5
# 00300113    ← addi x2, x0, 3
# 002081b3    ← add x3, x1, x2
# ...

# 5. Ver o hex gerado
cat programs/test_arith.hex
# Se bater com o disassembly: conversão correta!

# 6. Compilar o testbench com Verilator
verilator \
    --cc \                  # gera código C++ (não SystemC)
    --sv \                  # aceita SystemVerilog (não só Verilog)
    --exe \                 # inclui o arquivo C++ do testbench
    --build \               # compila automaticamente após gerar C++
    --Mdir obj_dir \        # coloca todos os artefatos em obj_dir/
    -Isrc \                 # adiciona src/ ao include path do Verilator
    -Wall \                 # todos os warnings habilitados
    -Wno-UNUSEDSIGNAL \     # silencia warning de sinal não utilizado
    --top-module riscv_top \ # módulo raiz da hierarquia SystemVerilog
    src/riscv_top.sv \      # arquivo SystemVerilog principal (inclui os outros)
    tb/tb_arith.cpp \       # testbench C++
    -o Varith               # nome do executável gerado

# O Verilator gera em obj_dir/:
#   Vriscv_top.h     ← header C++ do módulo simulado
#   Vriscv_top.cpp   ← implementação C++ do hardware
#   Varith           ← executável final

# 7. Executar a simulação
mkdir -p sim
cp programs/test_arith.hex sim/program.hex
cd sim && ../obj_dir/Varith
```

### Passo 8 — Saída esperada completa de `make all`

```
[bin2hex] 16 palavras → programs/test_arith.hex
[bin2hex] 5 palavras → programs/test_load_store.hex
[bin2hex] 22 palavras → programs/test_branch.hex
[bin2hex] 12 palavras → programs/test_jump.hex

=== Executando teste da ALU ===
=== Teste da ALU RISC-V RV32I ===
[ ADD ]
  [PASS] 5 + 3 = 8
  ...
Resultados: 26 aprovados, 0 reprovados

=== Executando teste do Banco de Registradores ===
=== Teste do Banco de Registradores ===
  [PASS] x1 = 42 apos escrita
  ...
Resultados: 8 aprovados, 0 reprovados

=== Executando: Teste Aritmético ===
[IMEM] Carregando program.hex ...
[IMEM] Carregado. mem[0]=0x00500093
=== Teste Aritmético (test_arith.hex) ===
[ Verificando registradores após execução ]
  [PASS] x1  addi x0,5            = 0x00000005 (5)
  [PASS] x2  addi x0,3            = 0x00000003 (3)
  [PASS] x3  add x1,x2            = 0x00000008 (8)
  ...
Resultados: 15 aprovados, 0 reprovados

=== Executando: Teste Load/Store ===
[IMEM] Carregado. mem[0]=0x00500093
Resultados: 8 aprovados, 0 reprovados

=== Executando: Teste de Branches ===
[IMEM] Carregado. mem[0]=0x00500093
Resultados: 7 aprovados, 0 reprovados

=== Executando: Teste de Jumps ===
[IMEM] Carregado. mem[0]=0x00C000EF
Resultados: 5 aprovados, 0 reprovados

============================================
  Todos os testes concluidos!
============================================
```

**Total: 69 verificações, 0 falhas.**

### Passo 9 — Limpar e recompilar do zero

```bash
make clean   # Remove obj_dir/, sim/, programs/*.o, *.bin, *.dis, *.hex
make all     # Recompila tudo do início
```

### Passo 10 — Executar testes individuais

```bash
make programs   # só monta os assembly → hex
make alu        # só testa a ALU (26 verificações)
make regfile    # só testa o banco de registradores (8)
make arith      # processador completo: aritmética (15)
make loadstore  # processador completo: load/store (8)
make branch     # processador completo: branches (7)
make jump       # processador completo: jumps (5)
make clean      # remove tudo gerado
```

### Instalação no Linux (Ubuntu/Debian)

```bash
# Verilator
sudo apt install verilator

# Para versão 5.x da fonte (recomendado para Ubuntu < 22.04):
git clone https://github.com/verilator/verilator
cd verilator
autoconf && ./configure && make -j$(nproc)
sudo make install

# Toolchain RISC-V
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

# Python e make
sudo apt install python3 make build-essential
```

---

## 12. Como Executar os Testes

### Execução completa com log

```bash
make all 2>&1 | tee test_output.txt
grep -c "PASS" test_output.txt  # deve ser 69
grep -c "FAIL" test_output.txt  # deve ser 0
```

### Executar um teste específico passo a passo

```bash
# 1. Montar o programa manualmente
cd riscv_harvard
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 \
    -o programs/test_arith.o \
    programs/test_arith.s

# 2. Ver o disassembly (instrução + endereço + encoding hex)
riscv64-unknown-elf-objdump -d -M no-aliases programs/test_arith.o
# Saída exemplo:
# 00000000 <_start>:
#    0:  00500093   addi   ra,zero,5
#    4:  00300113   addi   sp,zero,3
#    8:  002081b3   add    gp,ra,sp
# ...

# 3. Extrair binário
riscv64-unknown-elf-objcopy -O binary \
    programs/test_arith.o programs/test_arith.bin

# 4. Converter para hex
python3 scripts/bin2hex.py \
    programs/test_arith.bin programs/test_arith.hex

# 5. Verificar o hex
cat programs/test_arith.hex
# Saída:
# 00500093
# 00300113
# 002081b3
# ...

# 6. Compilar o simulador (Verilator)
verilator --cc --sv --exe --build \
    --Mdir obj_dir \
    -Isrc \
    -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv \
    tb/tb_arith.cpp \
    -o Varith

# Verilator gera em obj_dir/:
#   Vriscv_top.h     ← header C++ do módulo simulado
#   Vriscv_top.cpp   ← implementação do módulo
#   Varith           ← executável final

# 7. Executar a simulação
mkdir -p sim
cp programs/test_arith.hex sim/program.hex
cd sim && ../obj_dir/Varith
```

### Entendendo a saída do testbench

```
[IMEM] Carregando program.hex ...
[IMEM] Carregado. mem[0]=0x00500093   ← primeira instrução carregada

=== Teste Aritmético (test_arith.hex) ===

[ Verificando registradores após execução ]
  [PASS] x1  addi x0,5            = 0x00000005 (5)
         ↑    ↑                     ↑           ↑
         ok   nome do teste         valor hex   decimal
  [FAIL] x3  add x1,x2            : esperado=0x00000008, obtido=0x00000000
         ↑    ↑                      ↑                   ↑
         falha nome                  valor esperado       valor real
```

---

## 13. Como Escrever Seu Próprio Programa

### Sintaxe básica do assembly RISC-V

```assembly
# Comentários com #
.section .text      # Seção de código
.global _start      # Ponto de entrada (necessário para o assembler)
_start:             # Label: define um endereço com nome
    instrução       # Indentação com tab (boa prática)
    ...
loop:
    jal x0, loop   # Loop infinito = "halt"
```

### Exemplo 1: Calcular o fatorial de 5

```assembly
# fatorial.s — calcula 5! = 120
.section .text
.global _start
_start:
    addi x1, x0, 5     # x1 = 5 (contador, começa em n)
    addi x2, x0, 1     # x2 = 1 (acumulador do resultado)
loop:
    beq  x1, x0, done  # se x1 == 0, termina
    # Multiplica x2 por x1 (usando adições repetidas)
    # RISC-V RV32I não tem MUL (apenas na extensão M)
    # Implementação simples: x3 = x2 * x1 via soma
    addi x3, x0, 0     # x3 = 0 (resultado parcial)
    addi x4, x0, 0     # x4 = contador de somas
mul_loop:
    beq  x4, x1, mul_done  # se x4 == x1, termina multiplicação
    add  x3, x3, x2        # x3 += x2
    addi x4, x4, 1         # x4++
    jal  x0, mul_loop
mul_done:
    addi x2, x3, 0         # x2 = resultado (x3)
    addi x1, x1, -1        # x1--
    jal  x0, loop
done:
    # x2 = 120 (5!)
    jal  x0, done          # halt
```

```bash
# Monta, converte e testa
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o programs/fatorial.o programs/fatorial.s
riscv64-unknown-elf-objcopy -O binary programs/fatorial.o programs/fatorial.bin
python3 scripts/bin2hex.py programs/fatorial.bin programs/fatorial.hex
cp programs/fatorial.hex sim/program.hex
cd sim && ../obj_dir/Varith  # verifica o estado dos registradores
```

### Exemplo 2: Fibonacci em memória

```assembly
# fibonacci.s — calcula F(0)..F(9) e armazena em memória
.section .text
.global _start
_start:
    addi x1, x0, 0      # F(0) = 0
    addi x2, x0, 1      # F(1) = 1
    addi x3, x0, 0      # endereço base (Harvard: mem de dados)
    addi x4, x0, 8      # contador: vai calcular 8 termos mais

    sw   x1, 0(x3)      # mem[0] = F(0) = 0
    addi x3, x3, 4
    sw   x2, 0(x3)      # mem[4] = F(1) = 1
    addi x3, x3, 4

loop:
    beq  x4, x0, done
    add  x5, x1, x2     # F(n) = F(n-1) + F(n-2)
    sw   x5, 0(x3)      # armazena em memória
    addi x3, x3, 4      # avança endereço
    addi x1, x2, 0      # F(n-2) ← F(n-1)
    addi x2, x5, 0      # F(n-1) ← F(n)
    addi x4, x4, -1     # decrementa contador
    jal  x0, loop
done:
    jal  x0, done
```

### Exemplo 3: Template de testbench para programa próprio

```cpp
// tb/tb_meu_programa.cpp
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>

// Funções utilitárias
void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx); tick(dut, ctx);  // 2 ciclos de reset
    dut->rst_n = 1;
}

uint32_t read_reg(Vriscv_top* dut, int n) {
    dut->dbg_reg_sel = n;
    dut->eval();
    return dut->dbg_reg_val;
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    Vriscv_top* dut = new Vriscv_top{ctx};
    dut->clk        = 0;
    dut->rst_n      = 1;
    dut->dbg_reg_sel= 0;
    dut->eval();

    reset(dut, ctx);

    // Executa N ciclos (ajuste conforme o número de instruções do seu programa)
    int NUM_CYCLES = 100;
    for (int i = 0; i < NUM_CYCLES; i++)
        tick(dut, ctx);

    // Verifica os resultados
    int pass = 0, fail = 0;
    auto check = [&](int reg, uint32_t expected, const char* name) {
        uint32_t got = read_reg(dut, reg);
        if (got == expected) {
            printf("[PASS] x%-2d %-20s = 0x%08X\n", reg, name, got);
            pass++;
        } else {
            printf("[FAIL] x%-2d %-20s : esperado=0x%08X, obtido=0x%08X\n",
                   reg, name, expected, got);
            fail++;
        }
    };

    // Substitua com seus valores esperados:
    check(2, 120, "fatorial de 5");  // x2 deve ser 120

    printf("\nResultados: %d PASS, %d FAIL\n", pass, fail);

    dut->final();
    delete dut;
    delete ctx;
    return (fail == 0) ? 0 : 1;
}
```

```bash
# Compila e executa
verilator --cc --sv --exe --build \
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_meu_programa.cpp -o Vmeu

cp programs/fatorial.hex sim/program.hex
cd sim && ../obj_dir/Vmeu
```

---

## 14. Como Adicionar uma Nova Instrução

Vamos adicionar a instrução `mul` (multiplicação), que faz parte da
extensão RISC-V **M** (`rv32im`). O passo a passo se aplica a qualquer
instrução nova.

### Análise: o que `mul` precisa?

```
mul rd, rs1, rs2  → rd = (rs1 * rs2)[31:0]
Encoding: opcode=0110011 (R-type), funct3=000, funct7=0000001
```

É R-type, então os sinais de controle são os mesmos que `add` — só muda
a operação da ALU.

### Passo 1: Adicionar operação na ALU (`src/alu.sv`)

```systemverilog
// Adicionar o localparam:
localparam ALU_MUL = 4'b1010;  // nova operação

// Adicionar o case:
ALU_MUL: result = rs1 * rs2;   // multiplicação 32×32→32 (bits baixos)
```

**Nota:** Em SystemVerilog, `*` para `logic [31:0]` realiza multiplicação
inteira sem sinal. Para multiplicação com sinal, use `$signed(a) * $signed(b)`.

### Passo 2: Adicionar decodificação na unidade de controle da ALU (`src/alu_control.sv`)

```systemverilog
// No bloco alu_op=10 (R-type), adicionar antes do default:
3'b000: begin
    if (funct7 == 7'b0000001)
        alu_sel = ALU_MUL;    // funct7[0]=1 → mul (extensão M)
    else if (funct7[5])
        alu_sel = ALU_SUB;    // funct7[5]=1 → sub
    else
        alu_sel = ALU_ADD;    // funct7=0 → add
end
```

### Passo 3: A unidade de controle principal não precisa mudar

`mul` é R-type com `opcode=0110011`, igual a `add`. Os sinais de controle
são idênticos: `reg_write=1, alu_op=10, alu_src_b=0`, etc.

### Passo 4: Escrever um teste

```assembly
# programs/test_mul.s
.section .text
.global _start
_start:
    addi x1, x0, 6        # x1 = 6
    addi x2, x0, 7        # x2 = 7
    .word 0x02208033       # mul x0, x1, x2  (encoding manual)
    # ou use: mul x3, x1, x2  (se o assembler suportar -march=rv32im)
loop:
    jal x0, loop
```

**Encoding manual de `mul x3, x1, x2`:**
```
funct7 = 0000001, rs2=00010, rs1=00001, funct3=000, rd=00011, opcode=0110011
= 0000001_00010_00001_000_00011_0110011
= 0x02208033   → .word 0x02208033  no assembly
```

```bash
# Para usar o mnemônico mul diretamente:
riscv64-unknown-elf-as -march=rv32im -mabi=ilp32 -o programs/test_mul.o programs/test_mul.s
```

### Passo 5: Criar testbench

```cpp
// tb/tb_mul.cpp (adaptado do tb_arith.cpp)
check(dut, 3, 42, "mul 6*7=42");
```

### Passo 6: Compilar e testar

```bash
verilator --cc --sv --exe --build \
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_mul.cpp -o Vmul

riscv64-unknown-elf-as -march=rv32im -mabi=ilp32 \
    -o programs/test_mul.o programs/test_mul.s
riscv64-unknown-elf-objcopy -O binary programs/test_mul.o programs/test_mul.bin
python3 scripts/bin2hex.py programs/test_mul.bin programs/test_mul.hex
cp programs/test_mul.hex sim/program.hex
cd sim && ../obj_dir/Vmul
```

### Resumo: checklist para adicionar uma instrução

```
☐ 1. Identificar o opcode, funct3, funct7 (RISC-V spec ou manual)
☐ 2. Determinar que tipo de operação é (nova ALU op? novo tipo de memória?)
☐ 3. Implementar a operação na ALU (alu.sv) — se necessário
☐ 4. Adicionar decodificação na ALU control (alu_control.sv) — se nova op ALU
☐ 5. Atualizar a unidade de controle (control_unit.sv) — se novo opcode
☐ 6. Ajustar o datapath (riscv_top.sv) — se precisar de novos sinais
☐ 7. Escrever um programa de teste (.s)
☐ 8. Montar, converter para hex e testar com Verilator
```

---

## 15. Conceito de Pipeline — Do Single-Cycle ao Pipeline 5 Estágios

### Por que pipeline?

No processador single-cycle:
```
Clock period = T_instrução_mais_lenta = T_load
= T_imem + T_ctrl + T_alu + T_dmem + T_regfile_write
≈ (5 + 1 + 3 + 5 + 1) ns = 15 ns → fmax ≈ 67 MHz
```

Com pipeline de 5 estágios:
```
Clock period = max(T_estágio) ≈ max(5, 1, 3, 5, 1) = 5 ns → fmax ≈ 200 MHz
(3× mais rápido para a mesma tecnologia!)
```

O pipeline executa múltiplas instruções simultaneamente, cada uma em um
estágio diferente:

```
Ciclo:      1    2    3    4    5    6    7    8    9
Instrução 1: IF   ID   EX   MEM  WB
Instrução 2:      IF   ID   EX   MEM  WB
Instrução 3:           IF   ID   EX   MEM  WB
Instrução 4:                IF   ID   EX   MEM  WB
Instrução 5:                     IF   ID   EX   MEM  WB
```

No ciclo 5, todas as 5 instruções estão em execução simultânea!

### Os 5 estágios do pipeline RV32I

```
┌──────────────────────────────────────────────────────────────────┐
│     IF          ID          EX          MEM         WB           │
│  Instruction  Instruction  Execute    Memory     Write-Back      │
│  Fetch        Decode                  Access                     │
│                                                                  │
│  • PC → imem  • Decodifica  • ALU      • Lê/escreve• Escreve     │
│  • Lê         • Lê regfile  • opera    • dmem      • no regfile  │
│    instrução  • Gera imm    • calcula  • (load/    • rd ← wd     │
│  • PC+4       • Controles   • endereço • store)                  │
│                             • branch?              • mem_to_reg  │
└──────────────────────────────────────────────────────────────────┘
```

### Hazards (conflitos) no pipeline

O pipeline introduz três tipos de conflito:

#### 1. Hazard de dados (Data Hazard)

```assembly
add x1, x2, x3   # escreve x1 no WB (ciclo 5)
sub x4, x1, x5   # lê x1 no ID (ciclo 3) — ainda não foi escrito!
```

Solução: **Forwarding (bypassing)** — passa o resultado diretamente do
estágio EX ou MEM para a entrada da ALU, sem esperar pelo WB.

```
           ┌──────────────────────────────────────┐
           │                FORWARDING            │
           │                                      │
EX_result ─┼───────────────────────────────────>──┤ MUX → ALU_a
MEM_result─┼──────────────────────────────>───────┤ MUX → ALU_b
RegFile   ─┼──────────────────────────────────────┘
```

#### 2. Hazard de controle (Branch Hazard)

```assembly
beq x1, x2, target  # branch: resultado só conhecido no EX
add x3, x4, x5      # instrução seguinte (pode não dever executar!)
sub x6, x7, x8      # outra instrução sendo buscada...
```

Solução: **Branch prediction** (assumir "não tomado" ou "tomado") e
inserir **NOP** (bolhas) se errar. Ou: calcular o branch no ID
(requer forwarding extra).

#### 3. Hazard de load-use

```assembly
lw  x1, 0(x2)       # x1 só fica disponível após MEM (ciclo 4)
add x3, x1, x4      # precisa de x1 no EX (ciclo 3) — 1 ciclo cedo!
```

Forwarding não resolve — precisa de **stall** (parar o pipeline 1 ciclo):

```
Ciclo:    1    2    3    4    5    6
lw:       IF   ID   EX   MEM  WB
(stall):             --   --
add:      IF   ID   --   EX   MEM  WB   ← add espera 1 ciclo
```

### Como implementar pipeline (conceitual)

Para converter este processador single-cycle em pipeline:

1. **Adicionar registros de pipeline** entre os estágios:
   ```systemverilog
   // Registro IF/ID
   logic [31:0] if_id_pc, if_id_instr;
   always_ff @(posedge clk) begin
       if_id_pc    <= pc;
       if_id_instr <= instr;
   end
   ```

2. **Propagar sinais de controle** pelos estágios:
   ```systemverilog
   // Registro ID/EX
   logic id_ex_reg_write, id_ex_alu_src, ...;
   always_ff @(posedge clk) begin
       id_ex_reg_write <= reg_write;
       id_ex_alu_src   <= alu_src;
       ...
   end
   ```

3. **Implementar unidade de hazard detection**:
   ```systemverilog
   // Detecta load-use hazard
   wire load_use_hazard = (id_ex_mem_read &&
                           (id_ex_rd == if_id_rs1 || id_ex_rd == if_id_rs2));
   ```

4. **Implementar forwarding unit**:
   ```systemverilog
   // Forward do EX/MEM para EX
   wire [1:0] forward_a =
       (ex_mem_reg_write && ex_mem_rd != 0 && ex_mem_rd == id_ex_rs1) ? 2'b10 :
       (mem_wb_reg_write && mem_wb_rd != 0 && mem_wb_rd == id_ex_rs1) ? 2'b01 :
       2'b00;
   ```

Esses são os conceitos fundamentais — a implementação completa do pipeline
fica como exercício (ou próxima versão do projeto!).

---

## 16. Como Depurar com Verilator

### Método 1: Adicionar `$display` no SystemVerilog

```systemverilog
// Em riscv_top.sv, dentro do always_ff do PC:
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        pc <= 0;
    else begin
        $display("CLOCK: PC=0x%08X INSTR=0x%08X ALU=0x%08X WB=0x%08X",
                 pc, instr, alu_result, reg_wd);
        pc <= pc_next;
    end
end
```

Execute normalmente — os `$display` aparecerão no stdout da simulação.

### Método 2: Gerar VCD (waveform) com Verilator

```cpp
// Adicionar no testbench (tb/tb_arith.cpp):
#include <verilated_vcd_c.h>

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    ctx->traceEverOn(true);    // habilita rastreamento

    Vriscv_top* dut = new Vriscv_top{ctx};

    // Cria arquivo VCD
    VerilatedVcdC* vcd = new VerilatedVcdC;
    dut->trace(vcd, 99);       // 99 = níveis de hierarquia
    vcd->open("sim/waves.vcd");

    // ... resto do testbench ...
    // Dentro do tick():
    ctx->timeInc(1);
    vcd->dump(ctx->time());    // salva estado no VCD

    vcd->close();
    // ...
}
```

```bash
# Compilar com suporte a VCD
verilator --cc --sv --exe --build \
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --trace \                     # ← habilita VCD
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_arith.cpp -o Varith_vcd

# Executar
cd sim && ../obj_dir/Varith_vcd

# Abrir o VCD (waveform)
gtkwave sim/waves.vcd &     # Linux/macOS com GTKWave instalado
```

### Método 3: Leitura direta de sinais internos no testbench

O Verilator expõe todos os sinais do módulo como membros C++ da classe gerada:

```cpp
// Após dut->eval():
printf("PC=0x%08X\n", dut->dbg_pc);
printf("INSTR=0x%08X\n", dut->dbg_instr);
printf("ALU=0x%08X\n", dut->dbg_alu_result);

// Sinais internos (usando hierarquia):
printf("branch=%d\n", dut->riscv_top__DOT__branch);
printf("take_branch=%d\n", dut->riscv_top__DOT__take_branch);
printf("alu_sel=%d\n", dut->riscv_top__DOT__alu_sel);
```

O nome do sinal interno segue o padrão: `<top>__DOT__<sinal>`.
Para sinais dentro de submódulos: `<top>__DOT__<inst>__DOT__<sinal>`.

### Método 4: Trace ciclo a ciclo no testbench

```cpp
// Imprimir estado a cada ciclo para verificar progresso
for (int i = 0; i < 20; i++) {
    printf("Ciclo %2d: PC=0x%08X INSTR=0x%08X ALU=0x%08X WB=%d x%d=0x%08X\n",
           i,
           dut->dbg_pc,
           dut->dbg_instr,
           dut->dbg_alu_result,
           dut->dbg_reg_we,
           0,  // rd não exposto diretamente
           dut->dbg_reg_wd);
    tick(dut, ctx);
}
```

### Dicas de debugging

```
Problema: registrador não atualizado
  → Verificar: reg_write=1? rd correto? mem_to_reg seleciona certo?

Problema: branch não tomado
  → Verificar: alu_sel=SUB? zero flag correta? take_branch lógica?
  → Usar $display para ver zero, alu_result, branch, branch_inv

Problema: load retorna zero
  → Verificar: mem_read=1? alu_result (endereço) correto?
  → Confirmar que hex foi carregado: $display mem[0] no initial

Problema: instrução executando no endereço errado
  → Verificar: PC atualização correta? imm_b/imm_j corretos?
  → Checar encoding da instrução no disassembly (.dis)
```

---

## 17. Diagrama Completo do Datapath

```
                           ARQUITETURA HARVARD — DATAPATH
                           ================================

  rst_n ──┐
          ▼
       ┌──────┐  pc_next   ┌─────────────────────────────────────────────┐
       │  PC  │◄───────────│            LÓGICA DE PRÓXIMO PC             │
       │(FF)  │            │                                              │
       └──┬───┘            │  jump:     pc_next = PC + imm_j             │
          │ PC             │  jump_r:   pc_next = (rs1+imm_i) & ~1       │
          │                │  branch:   pc_next = PC + imm_b             │
          │                │  normal:   pc_next = PC + 4                 │
          │                └─────────────────────────────────────────────┘
          │                      ▲         ▲         ▲
          │                  jump│     jump_r│   branch│ take_branch
          │                      │           │         │
          ▼                      │           │  ┌──────┴──────┐
  ┌──────────────┐               │           │  │  take_branch│
  │  MEMÓRIA DE  │               │           │  │   logic      │◄─ zero
  │  INSTRUÇÕES  │               │           │  │             │◄─ alu_result[0]
  │  (ROM 4KB)   │               │           │  └─────────────┘
  │              │               │           │         ▲ branch
  │ mem[PC>>2]   │               │           │         │
  └──────┬───────┘               │           │   ┌─────┴────────┐
         │ instr[31:0]           │           │   │  CONTROLE    │
         │                       │           │   │  PRINCIPAL   │
         ├──[6:0]────────────────┼───────────┼──►│  (opcode)    │
         │  opcode               │           │   └──────┬───────┘
         │                       │           │          │ todos os
         │  ┌────────────────────┘           │          │ sinais
         │  │ imm_j (J-type)                 │          │
         │  │                                │          ▼
         ├──┼────────►[IMM_GEN]──►imm_i      │   ┌──────────────────────────┐
         │  │                 └──►imm_s       │   │  UNIDADE DE CONTROLE     │
         │  │                 └──►imm_b────────┤  │  DA ALU                  │
         │  │                 └──►imm_u       │   │                          │
         │  │                 └──►imm_j───────┘   │  alu_op + funct3 + funct7│
         │  │                                      │  → alu_sel               │
         ├──┼──[19:15]─►rs1────►[REGFILE]─►rd1    └──────────┬───────────────┘
         ├──┼──[24:20]─►rs2           │   ─►rd2               │ alu_sel[3:0]
         └──┼──[11:7]──►rd            │                        │
            │           ▲             │                        ▼
            │           │ we←reg_write│         ┌─────────────────────────┐
            │           │             │   alu_a  │                         │
            │           │  wd◄─┐      ├────────►│          ALU             │
            │           │      │      │         │  add/sub/and/or/xor/     │
            │           └──────┘      │  alu_b  │  sll/srl/sra/slt/sltu   │
            │                  ▲      ├────────►│                         │
            │                  │      │         └────────┬────────────────┘
            │              ┌───┴──┐   │                  │ alu_result
            │              │ MUX  │   │  (alu_src_a)      │ zero
            │              │write │   │  ┌───MUX─┐       │
            │              │back  │   └──┤ 0:rs1 │       │
            │              └──────┘      │ 1:PC  ├───────┘ (para alu_a)
            │              ▲  ▲  ▲  ▲   └───────┘
            │   mem_to_reg─┘  │  │  │           PC
            │   00:ALU result  │  │  │
            │   01:mem data◄───┘  │  │   ┌──────────────────────────────┐
            │   10:PC+4◄──────────┘  │   │     MEMÓRIA DE DADOS          │
            │   11:imm_u◄────────────┘   │        (RAM 4KB)              │
            │                           │                                 │
            │                    alu_result──►addr                       │
            │                    rs2_data───►wd   (se mem_write)        │
            │                    funct3─────►funct3                      │
            └───────────────────────────────►rd (se mem_read)           │
                                            └──────────────────────────── ┘
```

---

## 18. Comparação Harvard vs Von Neumann

| Aspecto | Harvard (esta versão) | Von Neumann (`../riscv_von_neumann/`) |
|---|---|---|
| Memórias | 2 separadas (4 KB cada) | 1 unificada (16 KB) |
| Módulo de memória | `instr_mem.sv` + `data_mem.sv` | `unified_mem.sv` |
| Paralelismo | Busca instrução + acesso dados simultâneos | Portas separadas na mesma memória |
| Espaço de endereço | Separado (código em [0,4KB), dados em [0,4KB)) | Unificado (código e dados em [0,16KB)) |
| Risco de corrupção | Impossível (memórias separadas) | Possível se dados sobrescreverem código |
| `sw x1, 0(x0)` | OK: escreve na dmem | PERIGO: sobrescreve a instrução na posição 0! |
| Requisito ao programar | Dados em qualquer endereço da dmem | Dados em endereços após o código (use 0x1000+) |
| Hardware real | Microcontroladores (PIC, AVR, DSPs) | PCs, smartphones, servidores |
| Complexidade HW | Maior (2 barramentos) | Menor (1 barramento) |

Para ver a versão Von Neumann, consulte `../riscv_von_neumann/README.md`.
