# Processador RISC-V RV32I — Arquitetura Von Neumann

Implementação educacional completa do conjunto de instruções base RISC-V de 32 bits
(RV32I), em **SystemVerilog**, simulada e validada com **Verilator**.

Inspirado na abordagem pedagógica do processador **Neander** (Weber, UFRGS), mas
usando a ISA RISC-V — padrão aberto, moderno, usado em chips reais.

Esta versão implementa a **Arquitetura Von Neumann**: instruções e dados
compartilham a mesma memória física e o mesmo espaço de endereçamento.

---

## Sumário

1. [O que é RISC-V e a conexão com Neander](#1-o-que-é-risc-v-e-a-conexão-com-neander)
2. [Pré-requisitos e Instalação](#2-pré-requisitos-e-instalação)
3. [Estrutura de Arquivos](#3-estrutura-de-arquivos)
4. [Arquitetura Von Neumann — Conceitos Profundos](#4-arquitetura-von-neumann--conceitos-profundos)
5. [A Diferença Crítica: Código e Dados no Mesmo Espaço](#5-a-diferença-crítica-código-e-dados-no-mesmo-espaço)
6. [Ciclo de Instrução Single-Cycle](#6-ciclo-de-instrução-single-cycle)
7. [Componentes do Hardware](#7-componentes-do-hardware)
8. [Codificação Binária das Instruções](#8-codificação-binária-das-instruções)
9. [Conjunto de Instruções Suportadas](#9-conjunto-de-instruções-suportadas)
10. [Rastreando Instruções pelo Datapath](#10-rastreando-instruções-pelo-datapath)
11. [Tabela de Sinais de Controle](#11-tabela-de-sinais-de-controle)
12. [Passo a Passo: Como Reproduzir do Zero](#12-passo-a-passo-como-reproduzir-do-zero)
13. [Como Executar os Testes](#13-como-executar-os-testes)
14. [Como Escrever Seus Próprios Programas](#14-como-escrever-seus-próprios-programas)
15. [Como Adicionar uma Nova Instrução](#15-como-adicionar-uma-nova-instrução)
16. [Pipeline — Conceitos Além do Single-Cycle](#16-pipeline--conceitos-além-do-single-cycle)
17. [Debugging com Verilator](#17-debugging-com-verilator)
18. [Diagrama Completo do Datapath](#18-diagrama-completo-do-datapath)

---

## 1. O que é RISC-V e a conexão com Neander

### Neander

O **Neander** (Neander Weber, UFRGS) é um processador hipotético criado para ensino de
arquitetura de computadores. Tem acumulador, 8 bits, poucas instruções (ADD, AND, NOT,
JN, JZ, JMP, LDA, STA, NOP, HLT). É simples o suficiente para ser implementado inteiro
numa tarde, mas completo o suficiente para ensinar os conceitos fundamentais:

- **Busca** da instrução na memória
- **Decodificação** do opcode
- **Execução** na ULA
- **Escrita** do resultado de volta

Este projeto preserva a intenção pedagógica do Neander, mas usa a **ISA RISC-V**,
um padrão moderno, aberto, royalty-free, que roda em chips reais.

### RISC-V

RISC-V (pronuncia-se "risk five") é uma ISA (Instruction Set Architecture) de código
aberto criada em 2010 na UC Berkeley. Diferente de x86 (Intel/AMD) e ARM (que exigem
licença), RISC-V é completamente livre.

**Por que RISC-V é melhor para aprender:**

| Característica | x86 | RISC-V |
|---|---|---|
| Número de instruções | 3000+ | 47 base (RV32I) |
| Codificação | Variável (1–15 bytes) | Fixo (4 bytes) |
| Regularidade | Baixa (CISC histórico) | Alta (projetado para ser simples) |
| Acesso livre | Não (Intel/AMD) | Sim |
| Usado em produção | Sim | Sim (SiFive, Google, RISC-V International) |

**RV32I** é o subconjunto base de 32 bits: 37 instruções, registradores de 32 bits,
endereçamento de 32 bits. É tudo que você precisa para rodar qualquer programa.

### A hierarquia RISC-V

```
RV32I   — base inteiro 32 bits (este projeto)
RV64I   — base inteiro 64 bits
M       — multiplicação/divisão (MUL, DIV, REM)
A       — operações atômicas (para sistemas operacionais)
F       — ponto flutuante simples
D       — ponto flutuante duplo
C       — instruções comprimidas de 16 bits
```

### Von Neumann neste projeto

Esta versão usa a arquitetura Von Neumann: **uma única memória para tudo** — tanto
as instruções do programa quanto as variáveis de dados. Isso significa que o
processador precisa ser cuidadoso para não sobrescrever seu próprio código com dados.

---

## 2. Pré-requisitos e Instalação

### Ferramentas necessárias

| Ferramenta | Versão testada | Função |
|---|---|---|
| **Verilator** | 5.042 | Simula SystemVerilog → C++ |
| **riscv64-unknown-elf-as** | GNU Binutils 2.45 | Monta Assembly RISC-V → binário |
| **riscv64-unknown-elf-objcopy** | 2.45 | Extrai binário do objeto ELF |
| **riscv64-unknown-elf-objdump** | 2.45 | Gera disassembly para inspeção |
| **Python 3** | 3.x | Converte binário para hex ($readmemh) |
| **make** | GNU Make | Automatiza compilação e testes |
| **g++ ou clang++** | qualquer recente | Compila o testbench C++ |

### Instalação no macOS

```bash
# Instala tudo de uma vez
brew install verilator riscv-gnu-toolchain python

# Verifica cada ferramenta
verilator --version
# Saída: Verilator 5.042 devel rev v5.042 (mod)

riscv64-unknown-elf-as --version
# Saída: GNU assembler (GNU Binutils) 2.45

python3 --version
# Saída: Python 3.x.x

make --version
# Saída: GNU Make 3.x.x (macOS inclui por padrão)
```

### Instalação no Linux (Ubuntu/Debian)

```bash
# Verilator (do repositório oficial — versão mais recente)
sudo apt install verilator

# Toolchain RISC-V
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

# Python e make
sudo apt install python3 make build-essential
```

### Por que Verilator?

O Verilator **compila** SystemVerilog para C++, gerando um executável nativo.
Isso é muito mais rápido do que simuladores interpretativos (ModelSim, Icarus Verilog)
e é gratuito. A desvantagem é que ele não suporta 100% da sintaxe SystemVerilog
(por exemplo, não suporta `initial` fora de `module`, mas para este projeto funciona
perfeitamente).

**Fluxo do Verilator:**

```
arquivo.sv  →  Verilator  →  arquivo.cpp (C++ equivalente)
                          →  g++ compila  →  executável binário
                                         →  ./executável  →  resultado
```

---

## 3. Estrutura de Arquivos

```
riscv_von_neumann/
│
├── src/                          # Hardware (SystemVerilog)
│   ├── alu.sv                    # ALU: 10 operações de 32 bits
│   ├── alu_control.sv            # Decodifica funct3/funct7 → op da ALU
│   ├── register_file.sv          # 32 registradores × 32 bits
│   ├── imm_gen.sv                # Extrai imediatos (5 formatos)
│   ├── control_unit.sv           # Decodifica opcode → sinais de controle
│   ├── unified_mem.sv            # ★ MEMÓRIA UNIFICADA (diferencial Von Neumann)
│   └── riscv_top.sv              # Top-level: interliga todos os módulos
│
├── tb/                           # Testbenches (C++ para Verilator)
│   ├── tb_alu.cpp                # Testa ALU isoladamente (26 verificações)
│   ├── tb_regfile.cpp            # Testa banco de registradores (8 verificações)
│   ├── tb_arith.cpp              # Testa instruções aritméticas (15 verificações)
│   ├── tb_loadstore.cpp          # Testa load/store com endereços 0x1000+ (8)
│   ├── tb_branch.cpp             # Testa instruções de branch (7 verificações)
│   └── tb_jump.cpp               # Testa JAL e JALR (5 verificações)
│
├── programs/                     # Programas em Assembly RISC-V
│   ├── test_arith.s              # Aritmética: ADD, SUB, AND, OR, XOR, SLT...
│   ├── test_load_store.s         # Load/Store: LW, SW, LB, SB, LBU, LH, SH, LHU
│   ├── test_branch.s             # Branches: BEQ, BNE, BLT, BGE, BLTU
│   ├── test_jump.s               # Jumps: JAL, JALR
│   ├── *.o                       # Objeto ELF (gerado pelo assembler)
│   ├── *.bin                     # Binário puro (gerado pelo objcopy)
│   ├── *.hex                     # Formato $readmemh (gerado pelo bin2hex.py)
│   └── *.dis                     # Disassembly (gerado pelo objdump)
│
├── scripts/
│   └── bin2hex.py                # Converte .bin → .hex (palavras little-endian)
│
├── sim/                          # Diretório de simulação (criado pelo Makefile)
│   └── program.hex               # Programa ativo copiado aqui antes de simular
│
├── obj_dir/                      # Artefatos do Verilator (criado automaticamente)
│   ├── Valu, Vregfile            # Executáveis dos testes unitários
│   ├── Varith, Vloadstore...     # Executáveis dos testes integrados
│   └── *.cpp, *.h, *.mk          # Código C++ gerado pelo Verilator
│
└── Makefile                      # Automatiza tudo
```

### Por que os executáveis ficam em `obj_dir/` e rodam em `sim/`?

O Makefile compila os simuladores para `obj_dir/Varith` etc., mas os executa
a partir do diretório `sim/`:

```makefile
cd sim && ../obj_dir/Varith
```

Isso porque `unified_mem.sv` carrega o programa com `$readmemh("program.hex", mem)` —
sem caminho absoluto, o arquivo é buscado no **diretório de trabalho atual**.
O Makefile copia o hex correto para `sim/program.hex` antes de executar.

---

## 4. Arquitetura Von Neumann — Conceitos Profundos

### A ideia original (1945)

John von Neumann propôs em 1945 que uma máquina de computação deveria ter:

1. **Memória única** que armazena tanto dados quanto o programa
2. **Unidade de Processamento** para executar operações
3. **Unidade de Controle** que lê instruções da memória e as executa
4. **Dispositivos de E/S** para comunicação com o mundo

A ideia chave: **o programa é dado**. Não há diferença física entre uma instrução
e um número inteiro — ambos são padrões de bits na mesma memória. Isso permite que
um programa modifique a si mesmo (auto-modificação), o que é poderoso e perigoso.

### Por que isso importa?

Antes de Von Neumann, as máquinas eram "programadas" fisicamente — você reconectava
fios ou reordenava engrenagens para mudar o que a máquina fazia. Von Neumann propôs
que o programa fosse carregado na memória como dados, permitindo trocar o programa
sem modificar o hardware.

### Von Neumann vs Harvard

```
VON NEUMANN:                        HARVARD:
┌─────────────────────────┐         ┌──────────────┐  ┌──────────────┐
│   MEMÓRIA UNIFICADA      │         │  MEM. INSTR. │  │  MEM. DADOS  │
│                          │         │  (ROM 4KB)   │  │  (RAM 4KB)   │
│  0x0000  instrução 1    │         └──────┬───────┘  └──────┬───────┘
│  0x0004  instrução 2    │                │                  │
│  0x0008  instrução 3    │              instr             dados
│  ...                     │                │                  │
│  0x1000  dado 1         │         ┌──────▼──────────────────▼──────┐
│  0x1004  dado 2         │         │         PROCESSADOR             │
│  0x1008  dado 3         │         └───────────────────────────────────┘
└─────────────────────────┘
         │         ▲
       instr      dado
         │         │
┌────────▼─────────┴──────────┐
│         PROCESSADOR          │
└─────────────────────────────┘
```

**Consequência:** No Von Neumann, a CPU usa o **mesmo barramento** para buscar
instruções e ler/escrever dados. Isso cria o **Gargalo de Von Neumann**: só uma
operação de memória por vez no barramento. É a razão pela qual processadores modernos
têm caches separadas de instrução e dados — mantendo a semântica Von Neumann no nível
do programador, mas Harvard internamente.

### Como esta implementação lida com o gargalo

Em um circuito real single-cycle Von Neumann com um único barramento físico, não seria
possível buscar instrução **e** acessar dados no mesmo ciclo — haveria conflito.

Esta implementação educacional usa um **array de memória único** com **duas portas
de leitura lógicas** (`instr_addr/instr_data` e `data_addr/data_rd`) e uma porta de
escrita síncrona. Isso preserva a semântica Von Neumann — o código e os dados
compartilham o **mesmo espaço de endereçamento** e o mesmo array `mem[0:4095]` —
mas permite que o simulador acesse os dois no mesmo ciclo de simulação para fins
educacionais.

Se você escreveu dados no endereço 0x00, a próxima busca de instrução nesse endereço
retornará exatamente os dados que você escreveu — comportamento Von Neumann genuíno.

### O mapa de memória neste projeto

```
Endereço    Tamanho    Uso
─────────────────────────────────────────
0x0000      variável   Código (instruções)
...
0x0FFF      —          Fim da área de código (máximo de ~1024 instruções)
0x1000      variável   Dados (variáveis de programas)
...
0x3FFF      —          Fim da memória (4096 palavras × 4 bytes = 16 KB total)
```

Esta separação é **por convenção**, não por hardware. Nada impede que você escreva
dados em 0x0000 (o que corromperia o código). Sua responsabilidade como programador
é manter dados além do código.

---

## 5. A Diferença Crítica: Código e Dados no Mesmo Espaço

Esta é **a** diferença entre as duas versões deste projeto.

### O problema: sobrescrita de código

```
Memória Von Neumann após reset:
┌──────────┬────────────────────────────────────┐
│ Endereço │ Conteúdo                           │
├──────────┼────────────────────────────────────┤
│ 0x0000   │ 0x00500093  (addi x1, x0, 5)      │ ← instrução 1
│ 0x0004   │ 0x00300113  (addi x2, x0, 3)      │ ← instrução 2
│ 0x0008   │ 0x002081B3  (add x3, x1, x2)      │ ← instrução 3
│ 0x000C   │ ...                                │
└──────────┴────────────────────────────────────┘

Se você executa:  sw x1, 0(x0)   (salva x1=5 no endereço 0)

Após SW:
┌──────────┬────────────────────────────────────┐
│ 0x0000   │ 0x00000005  (= 5)                  │ ← CÓDIGO CORROMPIDO!
│ 0x0004   │ 0x00300113  (addi x2, x0, 3)      │
│ 0x0008   │ 0x002081B3  (add x3, x1, x2)      │
└──────────┴────────────────────────────────────┘

Na próxima execução, PC=0x0000 buscará 0x00000005, que é uma instrução inválida!
```

### A solução: base de dados em 0x1000

Todos os programas Von Neumann deste projeto que acessam memória primeiro carregam
um endereço base seguro:

```assembly
lui x20, 1       # x20 = 0x00001000 = 4096 (decimal)
```

`lui` (Load Upper Immediate) carrega os 20 bits superiores de um registrador.
`lui x20, 1` coloca 1 nos 20 bits superiores, resultando em `0x00001000`.

Em seguida, todos os acessos à memória usam `x20` como base:

```assembly
sw  x1,  0(x20)   # mem[0x1000] = x1   ← seguro! bem além do código
lw  x2,  0(x20)   # x2 = mem[0x1000]
sb  x3,  4(x20)   # mem[0x1004] = byte de x3
lbu x4,  4(x20)   # x4 = zero_extend(mem[0x1004])
```

### Comparação direta Harvard vs Von Neumann

```assembly
# ──────── Harvard (test_load_store.s) ────────
sw  x1, 0(x0)    # endereço 0 → OK! Memória de dados separada fisicamente

# ──────── Von Neumann (test_load_store.s) ────
lui x20, 1       # x20 = 0x1000
sw  x1, 0(x20)   # endereço 0x1000 → OK! Além do código

# ──────── Von Neumann ERRADO ─────────────────
sw  x1, 0(x0)    # endereço 0 → CORROMPE a instrução 1 do programa!
```

### Calculando quantas instruções cabem antes de 0x1000

```
0x1000 / 4 = 1024 instruções
```

Para a maioria dos programas de teste (< 20 instruções), há margem enorme.
Se seu programa crescer além de ~900 instruções, use 0x2000:

```assembly
lui x20, 2       # x20 = 0x00002000
```

---

## 6. Ciclo de Instrução Single-Cycle

Em cada ciclo de clock, o processador completa uma instrução inteira. Não há pipeline —
cada instrução espera a anterior terminar antes de começar.

### As 5 fases (mesmo em single-cycle, acontecem em paralelo no mesmo ciclo)

```
Ciclo N:  ──── IF ──── ID ──── EX ──── MEM ──── WB ────►
Ciclo N+1:               ──── IF ──── ID ──── EX ──── MEM ──── WB ────►
```

Em um processador pipelined, cada fase seria um estágio separado e várias instruções
estariam em fases diferentes ao mesmo tempo. Neste processador single-cycle, tudo
acontece dentro de um único ciclo de clock:

#### IF — Instruction Fetch (Busca)

```
PC → instr_addr (Porta A da unified_mem) → instr_data → instr[31:0]
```

O PC (Program Counter) envia seu endereço para a porta A da memória unificada.
A memória retorna os 32 bits da instrução instantaneamente (lógica combinacional).

#### ID — Instruction Decode (Decodificação)

```
instr[6:0]   → opcode   → control_unit → sinais de controle
instr[14:12] → funct3
instr[31:25] → funct7
instr[19:15] → rs1_addr → register_file → rs1_data
instr[24:20] → rs2_addr → register_file → rs2_data
instr[31:0]  → imm_gen  → imm_i, imm_s, imm_b, imm_u, imm_j
```

Simultaneamente: a unidade de controle decodifica o opcode, o banco de registradores
lê os dois operandos fontes, e o gerador de imediatos extrai os imediatos.
Tudo em lógica combinacional — sem clock necessário para essas leituras.

#### EX — Execute (Execução na ALU)

```
alu_src_a ? PC : rs1_data  →  alu_a  ─┐
alu_src_b ? imm : rs2_data →  alu_b  ─┴→ ALU → alu_result, alu_zero
```

A ALU recebe seus operandos pelos multiplexadores e executa a operação selecionada
por `alu_sel`. Para loads/stores, calcula o endereço de memória. Para branches,
executa a comparação. Para R/I-type, executa a operação aritmética/lógica.

#### MEM — Memory Access (Acesso à Memória)

```
alu_result → data_addr (Porta B da unified_mem)
rs2_data   → data_wd
mem_write  → escreve na borda de subida do clock
mem_read   → leitura combinacional → mem_rd
```

Apenas loads e stores usam esta fase ativamente. Para outras instruções, os sinais
`mem_read` e `mem_write` ficam em 0.

#### WB — Write Back (Escrita nos Registradores)

```
mem_to_reg:
  00 → reg_wd = alu_result   (R-type, I-arith, AUIPC)
  01 → reg_wd = mem_rd       (LOAD: LW, LH, LB, LHU, LBU)
  10 → reg_wd = pc_plus4     (JAL, JALR: salva endereço de retorno)
  11 → reg_wd = imm_u        (LUI: carrega imediato de 20 bits)

Se reg_write=1: register_file[rd] ← reg_wd  (na borda de subida do clock)
```

### Atualização do PC

Também na borda de subida do clock, o PC é atualizado com `pc_next`:

```
pc_next:
  jump=1     → PC + imm_j          (JAL: salto incondicional relativo)
  jump_r=1   → {(rs1+imm_i)[31:1], 0}  (JALR: salto para registrador)
  take_branch→ PC + imm_b          (Branch tomado)
  default    → PC + 4              (instrução sequencial)
```

### Linha do tempo de um ciclo

```
Borda subida clock:
  ├─ PC registra pc_next
  ├─ register_file registra wd (se reg_write=1)
  └─ unified_mem escreve (se mem_write=1)

Durante o ciclo (lógica combinacional, propaga instantaneamente):
  ├─ unified_mem[PC] → instr
  ├─ control_unit(opcode) → sinais de controle
  ├─ register_file(rs1, rs2) → rs1_data, rs2_data
  ├─ imm_gen(instr) → imm_*
  ├─ alu(alu_a, alu_b, alu_sel) → alu_result, alu_zero
  ├─ unified_mem[alu_result] → mem_rd (se mem_read=1)
  ├─ mux write-back → reg_wd
  └─ next-PC logic → pc_next
```

O tempo máximo que o sinal precisa para propagar desde a saída do registrador de PC
até o próximo `pc_next` é o **caminho crítico** — ele determina a frequência máxima
do clock. Neste design educacional, não otimizamos isso, mas seria o primeiro passo
para aumentar a frequência.

---

## 7. Componentes do Hardware

### 7.1 — Memória Unificada (`src/unified_mem.sv`)

**Este é o componente que diferencia esta versão da Harvard.**

```systemverilog
module unified_mem #(
    parameter DEPTH = 4096,   // Palavras de 32 bits = 16 KB
    parameter AW    = 12      // Bits de endereço: log2(4096) = 12
) (
    input  logic        clk,

    // Porta A: Busca de Instrução (leitura combinacional)
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,

    // Porta B: Acesso a Dados
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [2:0]  funct3,       // Codifica tipo: LW/LH/LB/LHU/LBU
    input  logic [31:0] data_addr,
    input  logic [31:0] data_wd,      // Dado a escrever
    output logic [31:0] data_rd       // Dado lido
);
```

**Array central:**

```systemverilog
logic [31:0] mem [0:DEPTH-1];   // mem[0] a mem[4095]: 4096 palavras de 32 bits
```

É este mesmo array que ambas as portas acessam. Não há dois arrays separados — existe
apenas um. Isso é a essência Von Neumann.

**Inicialização:**

```systemverilog
initial begin
    integer i;
    for (i = 0; i < DEPTH; i = i + 1)
        mem[i] = 32'h0000_0013; // NOP (addi x0, x0, 0) — instrução segura
    $readmemh("program.hex", mem);
end
```

Todos os endereços são pré-carregados com NOPs. Assim, se o PC "escapar" para além
do programa, o processador executa NOPs infinitamente em vez de travar com instrução
inválida.

**Cálculo dos índices:**

```systemverilog
wire [AW-1:0] iidx = instr_addr[AW+1:2];  // bits [13:2] do endereço de instrução
wire [AW-1:0] didx = data_addr[AW+1:2];    // bits [13:2] do endereço de dados
wire [1:0]    boff = data_addr[1:0];        // bits [1:0] = offset dentro da palavra
```

Por que `addr[13:2]` em vez de `addr[11:0]`? Porque os endereços são em **bytes**,
mas o array é indexado por **palavras** (4 bytes). O índice de palavra é obtido
descartando os 2 bits menos significativos (divisão por 4).

```
Endereço byte 0x1000 = 0001 0000 0000 0000
Índice palavra      = 0001 0000 0000 00   (descarta 2 LSBs) = 0x400 = 1024
```

**Porta A — leitura combinacional de instrução:**

```systemverilog
assign instr_data = mem[iidx];
```

Uma linha. Sem condição, sem clock. O endereço de instrução entra, os 32 bits de
instrução saem instantaneamente (dentro do mesmo ciclo de simulação).

**Porta B — escrita síncrona de dados:**

```systemverilog
always_ff @(posedge clk) begin
    if (mem_write) begin
        case (funct3[1:0])
            2'b00: begin // SB — armazena só 1 byte
                case (boff)
                    2'b00: mem[didx][7:0]   <= data_wd[7:0];
                    2'b01: mem[didx][15:8]  <= data_wd[7:0];
                    2'b10: mem[didx][23:16] <= data_wd[7:0];
                    2'b11: mem[didx][31:24] <= data_wd[7:0];
                endcase
            end
            2'b01: begin // SH — armazena 2 bytes
                if (!boff[1])
                    mem[didx][15:0]  <= data_wd[15:0];
                else
                    mem[didx][31:16] <= data_wd[15:0];
            end
            2'b10: mem[didx] <= data_wd; // SW — armazena 4 bytes
        endcase
    end
end
```

Nota crítica: a escrita usa `<=` (atribuição não-bloqueante dentro de `always_ff`),
que é a prática correta para flip-flops em SystemVerilog. O valor só muda na
**borda de subida** do clock.

**Porta B — leitura combinacional de dados:**

```systemverilog
always_comb begin
    data_rd = 32'h0;
    if (mem_read) begin
        case (funct3)
            3'b000: // LB — lê 1 byte com extensão de sinal
            3'b001: // LH — lê 2 bytes com extensão de sinal
            3'b010: data_rd = mem[didx]; // LW
            3'b100: // LBU — lê 1 byte sem sinal (zero-extend)
            3'b101: // LHU — lê 2 bytes sem sinal (zero-extend)
        endcase
    end
end
```

**A leitura de dados também é combinacional** — sem clock, instantânea. Isso é
necessário para que o dado esteja disponível para o write-back no mesmo ciclo.

### 7.2 — ALU (`src/alu.sv`)

A ALU opera sobre dois valores de 32 bits e produz um resultado de 32 bits.

```
Entradas:
  a[31:0]   — operando A
  b[31:0]   — operando B
  op[3:0]   — seleciona a operação

Saídas:
  result[31:0]  — resultado da operação
  zero          — 1 se result == 0 (usado por BEQ/BNE)
```

**Tabela de operações:**

| `op` | Operação | Instrução RISC-V | Resultado |
|------|----------|------------------|-----------|
| 0000 | ADD | `add`, `addi`, loads, stores, JALR | `a + b` |
| 0001 | SUB | `sub`, BEQ, BNE | `a - b` |
| 0010 | AND | `and`, `andi` | `a & b` |
| 0011 | OR  | `or`, `ori` | `a \| b` |
| 0100 | XOR | `xor`, `xori` | `a ^ b` |
| 0101 | SLL | `sll`, `slli` | `a << b[4:0]` |
| 0110 | SRL | `srl`, `srli` | `a >> b[4:0]` (zeros à esquerda) |
| 0111 | SRA | `sra`, `srai` | `a >>> b[4:0]` (estende sinal) |
| 1000 | SLT | `slt`, `slti`, BLT, BGE | `(signed(a) < signed(b)) ? 1 : 0` |
| 1001 | SLTU | `sltu`, `sltiu`, BLTU, BGEU | `(a < b) ? 1 : 0` (sem sinal) |

**Por que `b[4:0]` para shifts?** RISC-V define que o campo de shamt (shift amount)
tem 5 bits, suficiente para valores 0–31. Os bits superiores de `b` são ignorados.

**Por que SUB é usado para BEQ/BNE?** Se `a == b`, então `a - b == 0`, então o flag
`zero` fica em 1. BEQ toma o branch quando `zero==1`, BNE quando `zero==0`.

### 7.3 — Controle da ALU (`src/alu_control.sv`)

A ALU não recebe o `opcode` diretamente. Existe um sistema de dois níveis:

```
Nível 1: control_unit  →  alu_op[1:0]  (4 categorias)
Nível 2: alu_control   →  alu_sel[3:0] (10 operações específicas)
```

**Por que dois níveis?** Modularidade: a `control_unit` não precisa conhecer os
detalhes de `funct3` e `funct7`. O `alu_control` especializado cuida disso.

**Tabela de decodificação:**

| `alu_op` | Categoria | Lógica |
|----------|-----------|--------|
| `00` | Load / Store | Sempre ADD (calcula endereço: rs1 + imm) |
| `01` | Branch | Olha `funct3`: BEQ→SUB, BNE→SUB+inv, BLT→SLT, BGE→SLT+inv, BLTU→SLTU, BGEU→SLTU+inv |
| `10` | R-type | Olha `funct3` + `funct7[5]`: ADD/SUB, SRL/SRA etc. |
| `11` | I-type arith | Olha `funct3` + `funct7[5]`: ADDI, SLLI, SLTI... |

**O sinal `branch_inv`:** Para BNE (`!=`), queremos tomar o branch quando os valores
são **diferentes**, mas a ALU nos diz se são iguais (via flag `zero`). Em vez de
adicionar outra saída à ALU, o `alu_control` gera `branch_inv=1` para BNE, BGE, BGEU.
O `riscv_top` inverte o resultado de comparação quando `branch_inv=1`.

### 7.4 — Banco de Registradores (`src/register_file.sv`)

```
32 registradores × 32 bits = 128 bytes no total

Portas:
  Escrita:
    clk, we (write enable), rd[4:0] (destino), wd[31:0] (dado)

  Leitura 1 (combinacional):
    rs1[4:0] → rd1[31:0]

  Leitura 2 (combinacional):
    rs2[4:0] → rd2[31:0]

  Debug (combinacional, externo ao datapath):
    dbg_reg_sel[4:0] → dbg_reg_val[31:0]
```

**x0 é hardwired zero:**

```systemverilog
// Escrita: nunca escreve em x0
always_ff @(posedge clk)
    if (we && (rd != 5'b0))
        regs[rd] <= wd;

// Leitura: x0 sempre retorna 0
assign rd1 = (rs1 == 5'b0) ? 32'h0 : regs[rs1];
assign rd2 = (rs2 == 5'b0) ? 32'h0 : regs[rs2];
```

Isso significa que mesmo que você tente `addi x0, x0, 5`, o registrador x0 permanece
zero. É uma das propriedades centrais do RISC-V — x0 é sempre disponível como zero.

**Porto de debug:** O testbench usa `dbg_reg_sel` para ler qualquer registrador
sem interferir nos sinais `rs1`/`rs2` do datapath. Isso é crucial para verificar
resultados após a execução.

**Convenção de nomes dos registradores RISC-V:**

| Registrador | ABI Name | Uso convencional |
|-------------|----------|------------------|
| x0 | zero | Sempre zero |
| x1 | ra | Return address |
| x2 | sp | Stack pointer |
| x3 | gp | Global pointer |
| x4 | tp | Thread pointer |
| x5–x7 | t0–t2 | Temporários |
| x8 | s0/fp | Saved / frame pointer |
| x9 | s1 | Saved |
| x10–x11 | a0–a1 | Argumentos / retorno de função |
| x12–x17 | a2–a7 | Argumentos de função |
| x18–x27 | s2–s11 | Saved registers |
| x28–x31 | t3–t6 | Temporários |

### 7.5 — Gerador de Imediatos (`src/imm_gen.sv`)

Extrai e estende com sinal os imediatos de todos os 5 formatos RISC-V. Recebe os
32 bits da instrução e produz 5 saídas de 32 bits simultaneamente.

```systemverilog
// I-type: bits[31:20] com extensão de sinal para 32 bits
assign imm_i = {{20{instr[31]}}, instr[31:20]};

// S-type: bits{31:25, 11:7} com extensão de sinal
assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

// B-type: {31, 7, 30:25, 11:8, 0} com extensão de sinal
assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

// U-type: bits{31:12} deslocados para posição superior
assign imm_u = {instr[31:12], 12'b0};

// J-type: {31, 19:12, 20, 30:21, 0} com extensão de sinal
assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
```

**Por que os bits estão embaralhados?** A ISA RISC-V posiciona os bits para que o
bit de sinal (`instr[31]`) sempre esteja na mesma posição, independentemente do
formato. Isso minimiza o hardware de extensão de sinal no chip físico.

**Por que imm_b e imm_j têm bit 0 sempre zero?** Branches e jumps sempre saltam para
endereços **alinhados a 2 bytes** (instruções comprimidas) ou 4 bytes (padrão).
O bit 0 codificado explicitamente como 0 garante isso — é uma instrução embutida
na ISA, não uma verificação extra em hardware.

### 7.6 — Unidade de Controle (`src/control_unit.sv`)

Decodifica o opcode (7 bits) e gera todos os sinais de controle. É lógica
combinacional pura — sem clock, sem estado.

```
Entrada:  opcode[6:0]

Saídas:
  reg_write    — 1 para escrever no banco de registradores
  alu_src_a    — 0=rs1, 1=PC (AUIPC usa PC como operando A)
  alu_src_b    — 0=rs2, 1=imediato
  mem_read     — 1 para ler dados da memória
  mem_write    — 1 para escrever dados na memória
  branch       — 1 para instrução de branch
  jump         — 1 para JAL
  jump_r       — 1 para JALR
  mem_to_reg   — 00=ALU, 01=MEM, 10=PC+4, 11=IMM_U
  alu_op       — 00=ADD, 01=BRANCH, 10=RTYPE, 11=IARITH
```

Os 9 opcodes decodificados:

```
0110011 (OP_R)       — R-type:    ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
0010011 (OP_I_ARITH) — I-arith:  ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
0000011 (OP_LOAD)    — Load:     LW, LH, LB, LHU, LBU
0100011 (OP_STORE)   — Store:    SW, SH, SB
1100011 (OP_BRANCH)  — Branch:   BEQ, BNE, BLT, BGE, BLTU, BGEU
1101111 (OP_JAL)     — JAL
1100111 (OP_JALR)    — JALR
0110111 (OP_LUI)     — LUI
0010111 (OP_AUIPC)   — AUIPC
```

### 7.7 — Top-level (`src/riscv_top.sv`)

Interliga todos os módulos. Contém também a lógica de PC e a decisão de branch.

**Lógica de branch:**

```systemverilog
always_comb begin
    if (branch) begin
        if (alu_sel == 4'b0001) // SUB → BEQ ou BNE (comparação de igualdade)
            take_branch = branch_inv ? ~alu_zero : alu_zero;
        else                    // SLT/SLTU → BLT/BGE/BLTU/BGEU (comparação de ordem)
            take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
    end else
        take_branch = 1'b0;
end
```

**Por que `alu_result[0]` para BLT/BGE?** A operação SLT retorna 1 (em bit 0) se
`a < b`, 0 caso contrário. `alu_result[0] = 1` significa "menor que" — BLT toma
o branch neste caso. BGE inverte: `branch_inv=1` então `~alu_result[0]` = toma
quando NOT menor_que = maior_ou_igual.

**Cálculo do endereço JALR:**

```systemverilog
logic [31:0] jalr_sum;
assign jalr_sum    = rs1_data + imm_i;
assign jalr_target = {jalr_sum[31:1], 1'b0};  // limpa bit 0
```

O bit 0 é explicitamente zerado no alvo do JALR, conforme a especificação RISC-V.
Isso garante alinhamento do endereço de instrução.

---

## 8. Codificação Binária das Instruções

Toda instrução RISC-V tem exatamente **32 bits** (4 bytes). Existem 6 formatos:

### Formato R-type (Register)

```
 31      25 24    20 19    15 14  12 11     7 6      0
┌──────────┬────────┬────────┬──────┬────────┬────────┐
│  funct7  │  rs2   │  rs1   │funct3│   rd   │ opcode │
│  7 bits  │ 5 bits │ 5 bits │3 bits│ 5 bits │ 7 bits │
└──────────┴────────┴────────┴──────┴────────┴────────┘
```

**Exemplo: `add x3, x1, x2`**

```
opcode = 0110011  (OP_R)
rd     = 00011    (x3)
funct3 = 000
rs1    = 00001    (x1)
rs2    = 00010    (x2)
funct7 = 0000000  (ADD, não SUB)

Montando:
  funct7  rs2    rs1   f3  rd     opcode
  0000000 00010 00001 000 00011 0110011

Binário: 0000000_00010_00001_000_00011_0110011
Hex: 0x002081B3
```

**Exemplo: `sub x4, x1, x2`**

```
funct7 = 0100000  (bit 5 = 1 → SUB em vez de ADD)
rd     = 00100    (x4)
Hex: 0x40208233
```

### Formato I-type (Immediate)

```
 31          20 19    15 14  12 11     7 6      0
┌──────────────┬────────┬──────┬────────┬────────┐
│   imm[11:0]  │  rs1   │funct3│   rd   │ opcode │
│   12 bits    │ 5 bits │3 bits│ 5 bits │ 7 bits │
└──────────────┴────────┴──────┴────────┴────────┘
```

**Exemplo: `addi x1, x0, 5`**

```
opcode   = 0010011  (OP_I_ARITH)
rd       = 00001    (x1)
funct3   = 000      (ADDI)
rs1      = 00000    (x0)
imm[11:0]= 000000000101  (+5)

Binário: 000000000101_00000_000_00001_0010011
Hex: 0x00500093
```

**Exemplo: `lw x2, 4(x20)` — load com offset**

```
opcode   = 0000011  (OP_LOAD)
rd       = 00010    (x2)
funct3   = 010      (LW)
rs1      = 10100    (x20)
imm[11:0]= 000000000100  (+4)

Binário: 000000000100_10100_010_00010_0000011
Hex: 0x004A2103
```

### Formato S-type (Store)

```
 31      25 24    20 19    15 14  12 11     7 6      0
┌──────────┬────────┬────────┬──────┬────────┬────────┐
│imm[11:5] │  rs2   │  rs1   │funct3│imm[4:0]│ opcode │
│  7 bits  │ 5 bits │ 5 bits │3 bits│ 5 bits │ 7 bits │
└──────────┴────────┴────────┴──────┴────────┴────────┘
```

O imediato é dividido em duas partes para manter rs1, rs2 sempre nas mesmas posições.

**Exemplo: `sw x1, 0(x20)`**

```
opcode     = 0100011  (OP_STORE)
funct3     = 010      (SW)
rs1        = 10100    (x20, base)
rs2        = 00001    (x1, dado)
imm[11:5]  = 0000000
imm[4:0]   = 00000

Binário: 0000000_00001_10100_010_00000_0100011
Hex: 0x001A2023
```

### Formato B-type (Branch)

```
 31   30    25 24    20 19    15 14  12 11  8  7  6      0
┌───┬────────┬────────┬────────┬──────┬──────┬───┬────────┐
│[12]│[10:5] │  rs2   │  rs1   │funct3│[4:1] │[11]│ opcode │
└───┴────────┴────────┴────────┴──────┴──────┴───┴────────┘
```

O offset de 13 bits (bit 0 sempre 0) é embaralhado para manter rs1/rs2 em posição fixa.

**Exemplo: `beq x1, x2, label` onde label está 8 bytes adiante**

```
offset = +8 = 0b0000000001000
bits: [12]=0, [11]=0, [10:5]=000000, [4:1]=0100, [0]=0 (sempre)

Binário: 0_000000_00010_00001_000_0100_0_1100011
Hex: 0x00208463
```

### Formato U-type (Upper Immediate)

```
 31              12 11     7 6      0
┌──────────────────┬────────┬────────┐
│     imm[31:12]   │   rd   │ opcode │
│     20 bits      │ 5 bits │ 7 bits │
└──────────────────┴────────┴────────┘
```

**Exemplo: `lui x20, 1`** (carrega 0x1000 em x20)

```
opcode   = 0110111  (OP_LUI)
rd       = 10100    (x20)
imm[31:12]= 00000000000000000001  (= 1, que fica em bit[12])

Resultado: x20 = 1 << 12 = 0x1000

Binário: 00000000000000000001_10100_0110111
Hex: 0x00001A37
```

### Formato J-type (Jump)

```
 31  30      21  20  19      12 11     7 6      0
┌───┬──────────┬───┬──────────┬────────┬────────┐
│[20]│[10:1]  │[11]│[19:12]  │   rd   │ opcode │
└───┴──────────┴───┴──────────┴────────┴────────┘
```

**Exemplo: `jal x0, 0`** (loop infinito: salta para si mesmo, offset=0)

```
opcode   = 1101111  (OP_JAL)
rd       = 00000    (x0 = descarta endereço de retorno)
imm      = 0        (offset 0: salta para PC+0 = mesmo endereço)

Hex: 0x0000006F
```

---

## 9. Conjunto de Instruções Suportadas

### R-type (opcode `0110011`)

| Instrução | funct3 | funct7[5] | Operação |
|-----------|--------|-----------|----------|
| `add`  | 000 | 0 | rd = rs1 + rs2 |
| `sub`  | 000 | 1 | rd = rs1 - rs2 |
| `sll`  | 001 | 0 | rd = rs1 << rs2[4:0] |
| `slt`  | 010 | 0 | rd = (signed(rs1) < signed(rs2)) ? 1 : 0 |
| `sltu` | 011 | 0 | rd = (rs1 < rs2) ? 1 : 0 |
| `xor`  | 100 | 0 | rd = rs1 ^ rs2 |
| `srl`  | 101 | 0 | rd = rs1 >> rs2[4:0] (lógico) |
| `sra`  | 101 | 1 | rd = rs1 >>> rs2[4:0] (aritmético) |
| `or`   | 110 | 0 | rd = rs1 \| rs2 |
| `and`  | 111 | 0 | rd = rs1 & rs2 |

### I-type aritmético (opcode `0010011`)

| Instrução | funct3 | Operação |
|-----------|--------|----------|
| `addi`  | 000 | rd = rs1 + sext(imm) |
| `slti`  | 010 | rd = (signed(rs1) < signed(imm)) ? 1 : 0 |
| `sltiu` | 011 | rd = (rs1 < imm) ? 1 : 0 |
| `xori`  | 100 | rd = rs1 ^ sext(imm) |
| `ori`   | 110 | rd = rs1 \| sext(imm) |
| `andi`  | 111 | rd = rs1 & sext(imm) |
| `slli`  | 001 | rd = rs1 << imm[4:0] |
| `srli`  | 101 | rd = rs1 >> imm[4:0] (lógico, funct7[5]=0) |
| `srai`  | 101 | rd = rs1 >>> imm[4:0] (aritmético, funct7[5]=1) |

### I-type load (opcode `0000011`)

| Instrução | funct3 | Operação |
|-----------|--------|----------|
| `lb`   | 000 | rd = sext(mem[rs1+imm][7:0]) |
| `lh`   | 001 | rd = sext(mem[rs1+imm][15:0]) |
| `lw`   | 010 | rd = mem[rs1+imm][31:0] |
| `lbu`  | 100 | rd = zext(mem[rs1+imm][7:0]) |
| `lhu`  | 101 | rd = zext(mem[rs1+imm][15:0]) |

### S-type store (opcode `0100011`)

| Instrução | funct3 | Operação |
|-----------|--------|----------|
| `sb`  | 000 | mem[rs1+imm][7:0] = rs2[7:0] |
| `sh`  | 001 | mem[rs1+imm][15:0] = rs2[15:0] |
| `sw`  | 010 | mem[rs1+imm] = rs2 |

### B-type branch (opcode `1100011`)

| Instrução | funct3 | Condição |
|-----------|--------|----------|
| `beq`  | 000 | PC += imm se rs1 == rs2 |
| `bne`  | 001 | PC += imm se rs1 != rs2 |
| `blt`  | 100 | PC += imm se signed(rs1) < signed(rs2) |
| `bge`  | 101 | PC += imm se signed(rs1) >= signed(rs2) |
| `bltu` | 110 | PC += imm se rs1 < rs2 (sem sinal) |
| `bgeu` | 111 | PC += imm se rs1 >= rs2 (sem sinal) |

### U-type e J-type

| Instrução | opcode | Operação |
|-----------|--------|----------|
| `lui`   | 0110111 | rd = imm << 12 (carrega 20 bits superiores) |
| `auipc` | 0010111 | rd = PC + (imm << 12) |
| `jal`   | 1101111 | rd = PC+4; PC += imm (salto relativo) |
| `jalr`  | 1100111 | rd = PC+4; PC = (rs1+imm) & ~1 (salto via registrador) |

---

## 10. Rastreando Instruções pelo Datapath

### Trace 1: `addi x1, x0, 5` (instrução mais simples)

**Instrução:** `0x00500093`

**Decodificação:**
```
bits[6:0]   = 0010011 → opcode = OP_I_ARITH
bits[11:7]  = 00001   → rd = x1
bits[14:12] = 000     → funct3 = 000 (ADDI)
bits[19:15] = 00000   → rs1 = x0
bits[31:20] = 000000000101 → imm = +5
```

**Sinais de controle gerados por `control_unit`:**
```
reg_write  = 1  (vamos escrever em x1)
alu_src_a  = 0  (operando A = rs1_data = x0 = 0)
alu_src_b  = 1  (operando B = imediato = 5)
mem_read   = 0
mem_write  = 0
branch     = 0
jump       = 0
mem_to_reg = 00 (write-back vem da ALU)
alu_op     = 11 (I-type arith)
```

**`alu_control` decodifica:**
```
alu_op=11, funct3=000 → alu_sel = 0000 (ADD)
branch_inv = 0
```

**ALU executa:**
```
alu_a = rs1_data = 0   (x0)
alu_b = imm_i    = 5
op    = ADD (0000)
result = 0 + 5 = 5
zero   = 0
```

**Write-back:**
```
mem_to_reg = 00 → reg_wd = alu_result = 5
reg_write = 1, rd = x1
→ register_file[x1] ← 5 (na borda de subida do clock)
```

**PC:**
```
jump=0, jump_r=0, take_branch=0 → pc_next = PC + 4
```

### Trace 2: `sw x1, 0(x20)` (Store Word — Von Neumann)

**Contexto:** x1=100, x20=0x1000 (base de dados carregada por `lui x20, 1`)

**Instrução montada:**
```
bits[6:0]   = 0100011 → OP_STORE
bits[14:12] = 010     → funct3 = SW
bits[19:15] = 10100   → rs1 = x20
bits[24:20] = 00001   → rs2 = x1
imm[11:5]   = 0000000
imm[4:0]    = 00000
→ imm_s = 0 (offset zero)
```

**Sinais de controle:**
```
reg_write  = 0  (SW não escreve em registrador)
alu_src_a  = 0  (rs1_data = x20 = 0x1000)
alu_src_b  = 1  (imediato = 0)
mem_read   = 0
mem_write  = 1  (escreve na memória!)
alu_op     = 00 (ADD: calcula endereço)
```

**ALU calcula endereço:**
```
alu_a = rs1_data = 0x1000
alu_b = imm_s    = 0
result = 0x1000 + 0 = 0x1000
```

**Memória unificada — Porta B:**
```
data_addr = alu_result = 0x1000
data_wd   = rs2_data   = 100
funct3    = 010 (SW)
didx      = 0x1000 >> 2 = 0x400 = 1024
→ mem[1024] ← 100  (na borda de subida do clock)
```

**Importante:** mem[1024] é o endereço de dados. mem[0] contém as instruções do
programa. SW em 0x1000 é seguro pois está além do código!

### Trace 3: `lw x2, 0(x20)` (Load Word)

**Contexto:** x20=0x1000, mem[0x1000]=100 (recém escrito pelo SW acima)

**Sinais de controle:**
```
reg_write  = 1  (LW escreve em x2)
alu_src_b  = 1  (imm_i = 0)
mem_read   = 1  (lê da memória)
mem_to_reg = 01 (write-back vem da memória, não da ALU)
alu_op     = 00 (ADD: calcula endereço)
```

**ALU:**
```
alu_a = rs1_data = 0x1000
alu_b = imm_i    = 0
result = 0x1000
```

**Memória unificada — Porta B (leitura):**
```
data_addr = 0x1000
funct3    = 010 (LW)
didx      = 0x400 = 1024
data_rd   = mem[1024] = 100  (combinacional)
```

**Write-back:**
```
mem_to_reg = 01 → reg_wd = mem_rd = 100
reg_write = 1, rd = x2
→ register_file[x2] ← 100
```

### Trace 4: `beq x1, x2, label` (Branch tomado)

**Contexto:** x1=5, x2=5 (iguais — branch será tomado)

**Instrução:** offset = +8 (label está 8 bytes adiante, PC atual = 0x10)

**Sinais de controle:**
```
reg_write  = 0
branch     = 1
alu_op     = 01 (branch comparison)
```

**`alu_control`:**
```
alu_op=01, funct3=000 → BEQ → alu_sel=0001 (SUB), branch_inv=0
```

**ALU:**
```
alu_a = rs1_data = 5
alu_b = rs2_data = 5
op    = SUB
result = 5 - 5 = 0
zero   = 1
```

**Decisão de branch:**
```
branch = 1
alu_sel == 0001 (SUB) → usa zero flag
branch_inv = 0 → take_branch = alu_zero = 1
```

**PC:**
```
take_branch = 1 → pc_next = PC + imm_b = 0x10 + 8 = 0x18
```

O programa salta para o endereço 0x18 (a instrução em `label`).

### Trace 5: `jal x1, func` (Jump and Link — Von Neumann)

**Contexto:** PC=0x14, func está em 0x24 (offset = 0x10 = 16)

**Instrução `jal x1, 16`:**
```
opcode = 1101111 (OP_JAL)
rd     = x1 (salva endereço de retorno)
imm_j  = +16
```

**Sinais de controle:**
```
reg_write  = 1  (salva PC+4 em x1)
jump       = 1
mem_to_reg = 10 (write-back = PC+4)
```

**Write-back:**
```
mem_to_reg = 10 → reg_wd = pc_plus4 = 0x14 + 4 = 0x18
reg_write = 1, rd = x1
→ register_file[x1] ← 0x18  (endereço de retorno!)
```

**PC:**
```
jump = 1 → pc_next = PC + imm_j = 0x14 + 16 = 0x24
```

Para retornar de `func`, executa `jalr x0, x1, 0`:
```
PC = (x1 + 0) & ~1 = 0x18
```

---

## 11. Tabela de Sinais de Controle

| Instrução | reg_write | alu_src_a | alu_src_b | mem_read | mem_write | branch | jump | jump_r | mem_to_reg | alu_op |
|-----------|-----------|-----------|-----------|----------|-----------|--------|------|--------|------------|--------|
| R-type    | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 00 | 10 |
| I-arith   | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 00 | 11 |
| LOAD      | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 01 | 00 |
| STORE     | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | -- | 00 |
| BRANCH    | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | -- | 01 |
| JAL       | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 10 | -- |
| JALR      | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 1 | 10 | 00 |
| LUI       | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 11 | -- |
| AUIPC     | 1 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 00 | 00 |

`--` = não importa (don't care)

---

## 12. Passo a Passo: Como Reproduzir do Zero

Esta seção assume que você está começando do zero em um Mac sem nada instalado.

### Passo 1 — Instalar Homebrew (gerenciador de pacotes macOS)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Passo 2 — Instalar as ferramentas

```bash
brew install verilator riscv-gnu-toolchain python make
```

Isso instala:
- **verilator** — simulador SystemVerilog
- **riscv-gnu-toolchain** — cross-compiler/assembler para RISC-V (inclui `as`, `objcopy`, `objdump`)
- **python** — Python 3
- **make** — build system

**Tempo estimado:** 5–15 minutos (riscv-gnu-toolchain é grande)

### Passo 3 — Clonar ou criar o projeto

Se este repositório já existe na sua máquina:

```bash
cd /caminho/para/neander_riscV/riscv_von_neumann
ls
# Deve mostrar: src/ tb/ programs/ scripts/ Makefile
```

### Passo 4 — Compilar e executar todos os testes

```bash
make all
```

Isso executa em sequência:
1. **Monta** todos os arquivos `.s` em `.o` → `.bin` → `.hex`
2. **Compila** cada testbench com Verilator: `alu`, `regfile`, `arith`, `loadstore`, `branch`, `jump`
3. **Executa** cada simulação e mostra os resultados

### Passo 5 — Interpretar a saída

Saída esperada de `make all`:

```
[bin2hex] 15 palavras → programs/test_arith.hex
[bin2hex] 13 palavras → programs/test_load_store.hex
[bin2hex] 13 palavras → programs/test_branch.hex
[bin2hex] 10 palavras → programs/test_jump.hex

=== Executando teste da ALU ===
Resultados: 26 aprovados, 0 reprovados

=== Executando teste do Banco de Registradores ===
Resultados: 8 aprovados, 0 reprovados

=== Executando: Teste Aritmético (Von Neumann) ===
[MEM] Carregando program.hex (Von Neumann) ...
[MEM] Carregado. mem[0]=0x00500093
Resultados: 15 aprovados, 0 reprovados

=== Executando: Teste Load/Store (Von Neumann) ===
[MEM] Carregando program.hex (Von Neumann) ...
[MEM] Carregado. mem[0]=0x00001A37
Resultados: 8 aprovados, 0 reprovados

=== Executando: Teste de Branches (Von Neumann) ===
[MEM] Carregando program.hex (Von Neumann) ...
Resultados: 7 aprovados, 0 reprovados

=== Executando: Teste de Jumps (Von Neumann) ===
[MEM] Carregando program.hex (Von Neumann) ...
Resultados: 5 aprovados, 0 reprovados

============================================
  Todos os testes (Von Neumann) concluidos!
============================================
```

### Passo 6 — Executar um teste manualmente (entender o processo)

```bash
# 1. Montar o arquivo assembly → objeto ELF
riscv64-unknown-elf-as \
    -march=rv32i -mabi=ilp32 \
    -o programs/test_arith.o \
    programs/test_arith.s

# Explicação dos flags:
#   -march=rv32i  → arquitetura alvo: RV32I (32 bits, inteiro base)
#   -mabi=ilp32   → ABI: int/long/pointer = 32 bits
#   -o            → arquivo de saída

# 2. Inspecionar o objeto com disassembly
riscv64-unknown-elf-objdump \
    -d -M no-aliases \
    programs/test_arith.o

# Saída parcial:
# 00000000 <_start>:
#    0: 00500093    addi    x1,x0,5
#    4: 00300113    addi    x2,x0,3
#    8: 002081b3    add     x3,x1,x2
#    ...

# 3. Extrair binário puro do ELF
riscv64-unknown-elf-objcopy \
    -O binary \
    programs/test_arith.o \
    programs/test_arith.bin

# Por que precisamos disso?
# O ELF contém cabeçalhos, metadados, seções. Precisamos só dos bytes das instruções.
# -O binary extrai exatamente os bytes do segmento .text.

# 4. Converter binário → formato $readmemh
python3 scripts/bin2hex.py \
    programs/test_arith.bin \
    programs/test_arith.hex

# bin2hex.py lê o binário little-endian de 4 em 4 bytes,
# monta cada palavra de 32 bits e escreve em hex:
# 00500093    ← addi x1, x0, 5
# 00300113    ← addi x2, x0, 3
# 002081b3    ← add x3, x1, x2
# ...

# 5. Ver o hex gerado
cat programs/test_arith.hex

# 6. Compilar o testbench com Verilator
verilator --cc --sv --exe --build \
    --Mdir obj_dir \
    -Isrc \
    -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_arith.cpp \
    -o Varith

# Explicação:
#   --cc          → gera código C++ (não SystemC)
#   --sv          → aceita SystemVerilog
#   --exe --build → compila automaticamente o executável
#   --Mdir obj_dir→ coloca artefatos em obj_dir/
#   -Isrc         → adiciona src/ ao include path
#   -Wall         → habilita todos os warnings
#   -Wno-UNUSEDSIGNAL → silencia warning de sinal não utilizado
#   --top-module  → módulo raiz da hierarquia
#   -o Varith     → nome do executável

# 7. Executar a simulação
mkdir -p sim
cp programs/test_arith.hex sim/program.hex
cd sim && ../obj_dir/Varith
```

### Passo 7 — Limpar e recompilar do zero

```bash
make clean   # Remove obj_dir/, sim/, programs/*.o, *.bin, *.dis, *.hex
make all     # Recompila tudo
```

---

## 13. Como Executar os Testes

### Testes disponíveis

| Alvo Make | O que testa | Verificações |
|-----------|-------------|--------------|
| `make alu` | ALU isolada (26 casos: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU) | 26 |
| `make regfile` | Banco de registradores (escrita, leitura, x0=0, dual-port) | 8 |
| `make arith` | Instruções aritméticas (R-type + I-type) | 15 |
| `make loadstore` | LW, SW, LB, SB, LBU, LH, SH, LHU — com endereços 0x1000+ | 8 |
| `make branch` | BEQ, BNE, BLT, BGE, BLTU | 7 |
| `make jump` | JAL, JALR | 5 |
| `make all` | Todos os acima em sequência | 69 |

### O que cada teste verifica em detalhes

**`make alu` — tb_alu.cpp:**

Testa a ALU isoladamente, sem o processador completo. Injeta `a`, `b`, `op`
diretamente nas portas e verifica `result` e `zero`.

```
ADD: 5+3=8, 0+0=0, -1+1=0(zero=1)
SUB: 5-3=2, 3-5=-2
AND: 0xFF & 0x0F = 0x0F
OR:  0xFF | 0x00 = 0xFF
XOR: 0xFF ^ 0xFF = 0x00
SLL: 1 << 3 = 8
SRL: 8 >> 1 = 4
SRA: -8 >>> 1 = -4 (preserva sinal)
SLT: -1 < 0 = 1 (com sinal)
SLTU: 0 < 1 = 1 (sem sinal)
```

**`make loadstore` — tb_loadstore.cpp:**

Valida o acesso à memória com endereços Von Neumann (0x1000+):

```
SW x1(=100) → mem[0x1000]; LW x2 ← mem[0x1000]; x2 == 100
SB x3(=0x55) → mem[0x1004]; LBU x4 ← mem[0x1004]; x4 == 0x55
SB x5(=-85=0xAB) → mem[0x1008]; LB x6 ← mem[0x1008]; x6 == -85 (sext!)
SH x7(=0x1234) → mem[0x100C]; LHU x8 ← mem[0x100C]; x8 == 0x1234
```

**`make branch` — tb_branch.cpp:**

```
BEQ x1(=5), x2(=5): branch tomado → OK
BNE x1(=5), x2(=3): branch tomado → OK
BLT x2(=3), x1(=5): branch tomado → OK (3 < 5 com sinal)
BGE x1(=5), x2(=3): branch tomado → OK (5 >= 3 com sinal)
BLTU x0(=0), x1(=5): branch tomado → OK (0 < 5 sem sinal)
BEQ x1(=5), x3(=8): branch NÃO tomado → OK
BNE x1(=5), x2(=5): branch NÃO tomado → OK
```

### Rodando testes com saída detalhada

```bash
# Salva toda saída em arquivo
make all 2>&1 | tee resultado_von_neumann.txt

# Conta quantos PASS e FAIL
make all 2>&1 | grep -c "\[PASS\]"
make all 2>&1 | grep -c "\[FAIL\]"

# Verifica resultado geral
make all && echo "TODOS PASSARAM" || echo "HOUVE FALHAS"
```

---

## 14. Como Escrever Seus Próprios Programas

### Template básico para Von Neumann

```assembly
# meu_programa.s
.section .text
.global _start
_start:
    # Passo 1 OBRIGATÓRIO: Configure a base de dados
    lui x28, 1                # x28 = BASE_DADOS = 0x1000

    # Seu código aqui
    addi x1, x0, 42           # x1 = 42

    # Para acessar memória, use sempre x28 como base
    sw   x1, 0(x28)           # mem[0x1000] = 42
    lw   x2, 0(x28)           # x2 = 42

    # Para mais variáveis, use offsets diferentes
    sw   x1, 4(x28)           # mem[0x1004] = 42 (segunda variável)
    sw   x1, 8(x28)           # mem[0x1008] = 42 (terceira variável)

halt:
    jal x0, halt              # loop infinito (halt)
```

### Exemplo 1: Soma de array

```assembly
# soma_array.s — Soma 5 elementos e guarda resultado
.section .text
.global _start
_start:
    lui   x28, 1              # x28 = base de dados = 0x1000

    # Inicializa array em mem[0x1000..0x1010]
    addi  x1, x0, 10          # elemento 0 = 10
    sw    x1,  0(x28)
    addi  x1, x0, 20          # elemento 1 = 20
    sw    x1,  4(x28)
    addi  x1, x0, 30          # elemento 2 = 30
    sw    x1,  8(x28)
    addi  x1, x0, 40          # elemento 3 = 40
    sw    x1, 12(x28)
    addi  x1, x0, 50          # elemento 4 = 50
    sw    x1, 16(x28)

    # Soma o array
    # x10 = soma, x11 = índice, x12 = limite
    addi  x10, x0, 0          # soma = 0
    addi  x11, x28, 0         # ponteiro = &array[0]
    addi  x12, x28, 20        # limite = &array[5]

loop:
    beq   x11, x12, fim       # se ponteiro == limite, termina
    lw    x1, 0(x11)          # carrega elemento atual
    add   x10, x10, x1        # soma += elemento
    addi  x11, x11, 4         # avança ponteiro
    jal   x0, loop

fim:
    sw    x10, 20(x28)        # guarda resultado em mem[0x1014]
halt:
    jal   x0, halt
# Resultado: x10 = 150, mem[0x1014] = 150
```

### Exemplo 2: Fatorial iterativo

```assembly
# fatorial.s — Calcula 5! = 120
.section .text
.global _start
_start:
    lui   x28, 1              # base de dados

    addi  x1, x0, 5           # n = 5
    addi  x2, x0, 1           # resultado = 1
    addi  x3, x0, 1           # contador para comparação

loop:
    blt   x1, x3, fim         # se n < 1, termina
    mul_step:
        # RISC-V base não tem MUL — implementamos com somas repetidas
        # x2 = x2 * x1 usando loop
        addi  x4, x0, 0       # acumulador temporário
        addi  x5, x0, 0       # contador interno
    inner:
        beq   x5, x1, done_mul # se contador == x1, termina
        add   x4, x4, x2       # acumulador += resultado anterior
        addi  x5, x5, 1
        jal   x0, inner
    done_mul:
        addi  x2, x4, 0        # resultado = acumulador
        addi  x1, x1, -1       # n--
        jal   x0, loop

fim:
    sw    x2, 0(x28)           # guarda resultado em mem[0x1000]
halt:
    jal   x0, halt
# Resultado: x2 = 120
```

### Montando e testando seu programa

```bash
# 1. Montar
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 \
    -o programs/meu_prog.o programs/meu_prog.s

# 2. Inspecionar (opcional, mas muito útil)
riscv64-unknown-elf-objdump -d -M no-aliases programs/meu_prog.o
# Mostra as instruções com endereços e hex — ótimo para debugar

# 3. Extrair binário
riscv64-unknown-elf-objcopy -O binary \
    programs/meu_prog.o programs/meu_prog.bin

# 4. Converter para hex
python3 scripts/bin2hex.py programs/meu_prog.bin programs/meu_prog.hex

# 5. Criar testbench (tb/tb_meu.cpp):
cat > tb/tb_meu.cpp << 'EOF'
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstdint>

void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

uint32_t reg(Vriscv_top* dut, int n) {
    dut->dbg_reg_sel = n; dut->eval();
    return dut->dbg_reg_val;
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    Vriscv_top* dut = new Vriscv_top{ctx};

    dut->clk = 0; dut->rst_n = 1; dut->dbg_reg_sel = 0;
    dut->eval();

    // Reset de 2 ciclos
    dut->rst_n = 0; tick(dut, ctx); tick(dut, ctx);
    dut->rst_n = 1;

    // Executa N ciclos (ajuste conforme necessário)
    for (int i = 0; i < 100; i++) tick(dut, ctx);

    // Verifica resultado no registrador x10
    uint32_t resultado = reg(dut, 10);
    printf("x10 = %d (esperado: 150)\n", resultado);
    printf("%s\n", (resultado == 150) ? "[PASS]" : "[FAIL]");

    dut->final(); delete dut; delete ctx;
    return (resultado == 150) ? 0 : 1;
}
EOF

# 6. Compilar com Verilator
verilator --cc --sv --exe --build \
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_meu.cpp -o Vmeu

# 7. Executar
mkdir -p sim
cp programs/meu_prog.hex sim/program.hex
cd sim && ../obj_dir/Vmeu
```

### Instruções úteis para programação

```assembly
# Carregar constante grande (> 12 bits)
lui   x1, 0xABCDE        # x1 = 0xABCDE000
addi  x1, x1, 0xF12      # x1 = 0xABCDEF12

# Copiar registrador
addi  x2, x1, 0          # x2 = x1

# Zerar registrador
xor   x1, x1, x1         # x1 = 0 (mais eficiente que addi x1, x0, 0)

# Verificar se x > 0
slt   x2, x0, x1         # x2 = 1 se 0 < x1 (ou seja, x1 > 0)

# Ponteiro para array (Von Neumann — use endereços >= 0x1000)
lui   x5, 1              # x5 = 0x1000 (base)
addi  x5, x5, 0         # elemento 0
addi  x6, x5, 4         # elemento 1 = base + 4
addi  x7, x5, 8         # elemento 2 = base + 8
```

---

## 15. Como Adicionar uma Nova Instrução

Vamos adicionar `MUL` (multiplicação, parte da extensão M do RISC-V) como exemplo.

**Aviso:** `MUL` não é parte do RV32I base. Esta seção demonstra o processo — na
prática, você estaria adicionando ao RV32I uma instrução customizada.

### Passo 1 — Verificar a codificação da instrução

Na ISA RISC-V, `MUL` tem:
```
opcode = 0110011 (igual ao R-type)
funct3 = 000
funct7 = 0000001   ← bit 1 de funct7 distingue M-extension do R-type base
```

Portanto, a instrução `mul x3, x1, x2` é codificada como:
```
funct7  rs2    rs1   f3  rd     opcode
0000001 00010 00001 000 00011 0110011
Hex: 0x022081B3
```

### Passo 2 — Adicionar operação à ALU (`src/alu.sv`)

```systemverilog
// Adiciona novo localparam
localparam ALU_MUL = 4'b1010;

// Adiciona case
ALU_MUL: result = a * b;  // Multiplicação (32 bits × 32 bits → 32 bits baixos)
```

### Passo 3 — Adicionar decodificação no controle da ALU (`src/alu_control.sv`)

```systemverilog
// No case de alu_op == 2'b10 (R-type), funct3 == 000:
3'b000: begin
    if (funct7[1])        // bit 1 = extensão M
        alu_sel = ALU_MUL;
    else if (funct7[5])   // bit 5 = SUB
        alu_sel = ALU_SUB;
    else
        alu_sel = ALU_ADD;
end
```

### Passo 4 — Não precisa alterar `control_unit.sv`

O opcode de MUL é `0110011` (mesmo do R-type). A unidade de controle já gera
os sinais corretos para R-type. A distinção entre ADD, SUB e MUL acontece
inteiramente dentro do `alu_control`, via `funct7`.

### Passo 5 — Escrever um programa de teste

```assembly
# test_mul.s
.section .text
.global _start
_start:
    addi  x1, x0, 6
    addi  x2, x0, 7
    mul   x3, x1, x2      # x3 = 6 * 7 = 42
loop:
    jal x0, loop
```

### Passo 6 — Escrever o testbench

```cpp
// tb/tb_mul.cpp
check(dut, 3, 42, "mul x1,x2");
```

### Compilar e testar

```bash
verilator --cc --sv --exe --build \
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_mul.cpp -o Vmul

mkdir -p sim
cp programs/test_mul.hex sim/program.hex
cd sim && ../obj_dir/Vmul
```

### Checklist para adicionar qualquer instrução nova

```
[ ] 1. Verificar opcode, funct3, funct7 na especificação RISC-V
[ ] 2. Se nova operação ALU: adicionar localparam + case em alu.sv
[ ] 3. Se novo opcode: adicionar case em control_unit.sv
[ ] 4. Se decodificação ALU diferente: adicionar em alu_control.sv
[ ] 5. Se novo formato de imediato: adicionar em imm_gen.sv (raro)
[ ] 6. Se nova fonte de write-back: adicionar caso em mem_to_reg (raro)
[ ] 7. Escrever programa de teste em Assembly
[ ] 8. Escrever testbench C++ com verificações específicas
[ ] 9. Montar, converter, compilar e simular
[ ] 10. Validar com make
```

---

## 16. Pipeline — Conceitos Além do Single-Cycle

Este processador é **single-cycle**: uma instrução por ciclo de clock, sem sobreposição.
O pipeline é o próximo passo natural para aumentar o desempenho.

### O que é pipeline?

Analogia: uma linha de montagem de carros. Em vez de um carro ser completamente montado
antes de começar o próximo, várias etapas acontecem em paralelo para carros diferentes.

```
Single-cycle (este projeto):
Ciclo 1: [IF──ID──EX──MEM──WB]
Ciclo 2:                       [IF──ID──EX──MEM──WB]
Ciclo 3:                                             [IF──ID──EX──MEM──WB]

Pipeline de 5 estágios:
Ciclo 1: [IF ]
Ciclo 2: [ID ] [IF ]
Ciclo 3: [EX ] [ID ] [IF ]
Ciclo 4: [MEM] [EX ] [ID ] [IF ]
Ciclo 5: [WB ] [MEM] [EX ] [ID ] [IF ]
Ciclo 6:       [WB ] [MEM] [EX ] [ID ] [IF ]
```

Em regime permanente (após o pipeline estar "cheio"), uma instrução termina a
cada ciclo — mesmo throughput que single-cycle, mas com clock muito mais rápido
(cada estágio leva apenas 1/5 do tempo).

### Hazards — os problemas do pipeline

#### Data Hazard (Dependência de Dados)

```assembly
add  x1, x2, x3    # escreve x1 no WB do ciclo 5
sub  x4, x1, x5    # lê x1 no ID do ciclo 3 — mas x1 ainda não está pronto!
and  x6, x1, x7    # idem
```

**Solução 1: Stall (bolha)** — insere ciclos de espera (bolhas) até o dado estar disponível.

**Solução 2: Forwarding (bypass)** — o resultado da ALU é encaminhado diretamente
para a entrada da ALU do ciclo seguinte, sem esperar chegar ao banco de registradores.

```
EX resultado → EX entrada (forwarding EX→EX)
MEM resultado → EX entrada (forwarding MEM→EX)
```

#### Control Hazard (Branch)

```assembly
beq  x1, x2, label    # PC atualizado no EX, mas IF/ID já buscaram instruções erradas
```

**Solução 1: Stall** — espera 2 ciclos depois de cada branch.

**Solução 2: Branch prediction** — prediz que branch não será tomado; desfaz se errar.

**Solução 3: Branch delay slot** — define que a instrução após o branch sempre executa
(MIPS usava isso; RISC-V não usa).

#### Load-Use Hazard

```assembly
lw   x1, 0(x20)    # dado disponível no final do MEM (ciclo 4)
add  x2, x1, x3    # precisa de x1 no EX (ciclo 3) — impossível!
```

Mesmo com forwarding, este hazard exige exatamente **1 stall** obrigatório.
O compilador pode reordenar instruções para evitar o stall (instruction scheduling).

### Por que single-cycle é mais simples para aprender

| Aspecto | Single-cycle | Pipeline |
|---------|--------------|---------|
| Registradores de pipeline | Não | Sim (IF/ID, ID/EX, EX/MEM, MEM/WB) |
| Detecção de hazards | Não necessário | Necessário (hardware extra) |
| Forwarding | Não necessário | Necessário para performance |
| Flush de pipeline | Não necessário | Necessário para branches |
| Linhas de código estimadas | ~300 | ~700+ |

### Abrindo caminho para pipeline

Para transformar este single-cycle em pipeline, os passos seriam:

1. **Adicionar registradores de pipeline** entre cada estágio (`always_ff`)
2. **Propagar sinais de controle** junto com os dados pelos estágios
3. **Implementar hazard detection unit** para detectar dependências
4. **Implementar forwarding unit** para resolver data hazards sem stalls
5. **Implementar branch resolution** no estágio EX e flush dos estágios IF/ID

---

## 17. Debugging com Verilator

### Técnica 1: Printf nos testbenches

A técnica mais simples é adicionar `printf` no testbench C++ para imprimir
valores de registradores e PC.

```cpp
// Imprime estado do processador a cada ciclo
for (int i = 0; i < 20; i++) {
    tick(dut, ctx);
    printf("Ciclo %2d: PC=0x%08X instr=0x%08X\n",
           i, dut->dbg_pc, dut->dbg_instr);
}
```

As portas de debug expostas pelo `riscv_top.sv`:
```cpp
dut->dbg_pc          // Program Counter atual
dut->dbg_instr       // Instrução sendo executada
dut->dbg_alu_result  // Resultado da ALU (= endereço de memória para loads/stores)
dut->dbg_reg_wd      // Dado a ser escrito no banco de registradores
dut->dbg_reg_we      // Write enable do banco de registradores
dut->dbg_reg_val     // Valor do registrador dbg_reg_sel
```

### Técnica 2: Dump de todos os registradores

```cpp
void dump_regs(Vriscv_top* dut) {
    printf("Registradores:\n");
    for (int i = 0; i < 32; i++) {
        dut->dbg_reg_sel = i;
        dut->eval();
        printf("  x%-2d = 0x%08X (%d)\n",
               i, dut->dbg_reg_val, (int32_t)dut->dbg_reg_val);
    }
}

// Uso: chame após executar o programa
dump_regs(dut);
```

### Técnica 3: Geração de arquivo VCD (waveform)

O Verilator pode gerar um arquivo `.vcd` que você visualiza com GTKWave:

```cpp
// No início de main(), antes de criar o DUT:
Verilated::traceEverOn(true);

// Após criar o DUT:
VerilatedVcdC* tfp = new VerilatedVcdC;
dut->trace(tfp, 99);              // profundidade 99 = todos os sinais
tfp->open("dump.vcd");            // cria o arquivo

// Dentro de tick():
void tick(Vriscv_top* dut, VerilatedContext* ctx, VerilatedVcdC* tfp) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    tfp->dump(ctx->time());        // dump na borda de descida
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
    tfp->dump(ctx->time());        // dump na borda de subida
}

// No final de main():
tfp->close();
```

Para compilar com suporte a VCD:
```bash
verilator --cc --sv --exe --build --trace \   # ← adiciona --trace
    --Mdir obj_dir -Isrc -Wall -Wno-UNUSEDSIGNAL \
    --top-module riscv_top \
    src/riscv_top.sv tb/tb_arith.cpp -o Varith
```

Para visualizar:
```bash
# Instala GTKWave
brew install gtkwave   # macOS

# Abre o arquivo
gtkwave dump.vcd
```

No GTKWave, você verá todos os sinais internos (`pc`, `instr`, `alu_result`,
`mem_write`, `reg_wd`, etc.) ao longo do tempo. Isso é equivalente a ter um
osciloscópio/lógico em todos os fios do circuito simultaneamente.

### Técnica 4: `$display` no SystemVerilog

Você também pode adicionar `$display` diretamente no SystemVerilog para imprimir
mensagens durante a simulação:

```systemverilog
// Em unified_mem.sv — já existe:
$display("[MEM] Carregando program.hex (Von Neumann) ...");
$display("[MEM] Carregado. mem[0]=0x%08X", mem[0]);

// Pode adicionar para debug de escrita:
always_ff @(posedge clk) begin
    if (mem_write) begin
        $display("[MEM WRITE] addr=0x%08X data=0x%08X funct3=%b",
                 data_addr, data_wd, funct3);
        // ... lógica de escrita
    end
end
```

O Verilator preserva os `$display` e os executa durante a simulação — você verá
as mensagens misturadas com a saída do testbench C++.

### Técnica 5: Inspecionar o hexadecimal do programa

Para verificar se a montagem está correta:

```bash
# Disassembly — lê do objeto ELF
riscv64-unknown-elf-objdump -d -M no-aliases programs/test_arith.o

# Saída:
# 00000000 <_start>:
#    0:   00500093    addi    x1,x0,5        ← endereço 0x00, hex 0x00500093
#    4:   00300113    addi    x2,x0,3        ← endereço 0x04
#    8:   002081b3    add     x3,x1,x2       ← endereço 0x08

# Compara com o hex gerado:
cat programs/test_arith.hex
# 00500093
# 00300113
# 002081b3
# ...

# Se os valores baterem, a conversão foi correta
```

### Técnica 6: Verificar o mapa de memória Von Neumann

Para garantir que dados e código não colidem:

```bash
# Conta quantas instruções tem o programa
riscv64-unknown-elf-objdump -d programs/test_load_store.o | grep "^   " | wc -l
# Exemplo: 13 instruções = 13 × 4 = 52 bytes = 0x34 bytes
# Código vai de 0x0000 a 0x0034
# 0x1000 >> 0x0034 → dados seguros!

# Ver endereço da última instrução
riscv64-unknown-elf-objdump -d programs/test_load_store.o | tail -5
#  30:   0006306f    jal     x0,30     ← última instrução em 0x30
# Base de dados 0x1000 >> 0x30 → seguro
```

### Técnica 7: Sinais internos via `__DOT__`

O Verilator expõe sinais internos de submódulos no testbench C++ usando a
notação `<top>__DOT__<sinal>`:

```cpp
// Sinais do riscv_top (já expostos via dbg_*):
printf("PC=0x%08X\n",    dut->dbg_pc);
printf("INSTR=0x%08X\n", dut->dbg_instr);
printf("ALU=0x%08X\n",   dut->dbg_alu_result);

// Sinais internos do riscv_top (via __DOT__):
printf("branch=%d\n",      dut->riscv_top__DOT__branch);
printf("take_branch=%d\n", dut->riscv_top__DOT__take_branch);
printf("alu_sel=%d\n",     dut->riscv_top__DOT__alu_sel);
printf("mem_write=%d\n",   dut->riscv_top__DOT__mem_write);
printf("reg_write=%d\n",   dut->riscv_top__DOT__reg_write);
printf("mem_to_reg=%d\n",  dut->riscv_top__DOT__mem_to_reg);

// Sinais dentro da memória unificada:
printf("iidx=%d\n",  dut->riscv_top__DOT__u_mem__DOT__iidx);
printf("didx=%d\n",  dut->riscv_top__DOT__u_mem__DOT__didx);
```

Para hierarquias profundas: `<top>__DOT__<instância>__DOT__<sinal>`.

### Dicas de debugging — Problemas comuns

```
Problema: registrador não tem o valor esperado
  Diagnóstico:
    → reg_write=1? (verifique dut->riscv_top__DOT__reg_write)
    → rd está correto? (bits [11:7] da instrução)
    → mem_to_reg seleciona a fonte certa? (00=ALU, 01=MEM, 10=PC+4, 11=IMM_U)
  Exemplo de print de diagnóstico:
    printf("reg_write=%d rd=%d mem_to_reg=%d alu=%08X mem_rd=%08X\n",
           dut->riscv_top__DOT__reg_write,
           dut->riscv_top__DOT__rd_addr,
           dut->riscv_top__DOT__mem_to_reg,
           dut->riscv_top__DOT__alu_result,
           dut->riscv_top__DOT__mem_rd);

Problema: branch não tomado quando deveria ser
  Diagnóstico:
    → alu_sel=SUB (0001) para BEQ/BNE? alu_sel=SLT (1000) para BLT/BGE?
    → zero flag correta? (alu_result deve ser 0 para BEQ tomado)
    → branch_inv correto? (1 para BNE/BGE/BGEU, 0 para BEQ/BLT/BLTU)
    → take_branch=1?
  Use $display em riscv_top.sv:
    $display("branch=%b alu_sel=%b zero=%b branch_inv=%b take=%b",
             branch, alu_sel, alu_zero, branch_inv, take_branch);

Problema: load retorna 0 ou valor errado
  Diagnóstico:
    → mem_read=1? (verifique o sinal)
    → alu_result (endereço) está correto? (deve ser rs1 + imm)
    → Von Neumann: o endereço está em 0x1000+? (não sobrescreveu código?)
    → funct3 correto? (LW=010, LH=001, LB=000, LHU=101, LBU=100)
    → Confirme que o hex foi carregado: $display em unified_mem.sv:
      $display("[DEBUG] mem[0x400]=%08X", mem[12'h400]); // mem[0x1000>>2]

Problema: SW escreve mas LW não lê o valor esperado
  Diagnóstico específico para Von Neumann:
    → SW e LW usam o mesmo endereço? (didx deve ser igual nos dois)
    → Confirme: boff (byte offset) é 0 para ambos? (SW/LW alinhados a 4 bytes)
    → O SW aconteceu antes do LW? (escrita síncrona @posedge, leitura combinacional)
    → Use $display no always_ff da unified_mem para confirmar a escrita:
      $display("[SW] didx=%0d data=0x%08X", didx, data_wd);

Problema: PC vai para endereço errado após JAL/JALR
  Diagnóstico:
    → Para JAL: imm_j correto? (bits J-type são embaralhados)
    → Para JALR: jalr_sum = rs1_data + imm_i? bit 0 zerado?
    → Verificar disassembly: o offset calculado bate com o esperado?
      riscv64-unknown-elf-objdump -d -M no-aliases programs/test_jump.o

Problema: instrução sendo executada parece inválida / NOP inesperado
  Causas possíveis (Von Neumann específico):
    → Um SW anterior sobrescreveu código (dados em endereço < 0x1000)
    → O PC "escapou" além do programa (executando os NOPs de inicialização)
    → O hex não foi copiado para sim/program.hex antes de rodar
  Verificação:
    printf("PC=0x%08X INSTR=0x%08X\n", dut->dbg_pc, dut->dbg_instr);
    // 0x00001013 = NOP (addi x0, x0, 0) → PC escapou do programa
    // 0x00000013 = NOP alternativo → idem
```

---

## 18. Diagrama Completo do Datapath

```
                    ┌───────────────────────────────────────────────────────────────────────┐
                    │              MEMÓRIA UNIFICADA VON NEUMANN (unified_mem.sv)           │
                    │                         4096 × 32 bits = 16 KB                        │
                    │                                                                        │
                    │   mem[0:4095]  ←  MESMO ARRAY para instruções E dados                │
                    │                                                                        │
                    │  ┌──────────────────────────────┐  ┌────────────────────────────────┐ │
                    │  │  PORTA A — Instrução          │  │  PORTA B — Dados               │ │
                    │  │  (leitura combinacional)       │  │  (leitura comb + escrita síncr)│ │
                    │  │  instr_addr[31:0] → iidx      │  │  data_addr[31:0] → didx        │ │
                    │  │  mem[iidx] → instr_data[31:0] │  │  mem[didx] → data_rd[31:0]     │ │
                    │  │                               │  │  data_wd → mem[didx] @posedge  │ │
                    │  └───────────┬───────────────────┘  └────────────────┬───────────────┘ │
                    └─────────────┼────────────────────────────────────────┼─────────────────┘
                                  │ instr[31:0]                            │ data_rd[31:0]
      ┌──────────┐                │                                        │
      │    PC    │                │        ┌───────────────────────────────┘
      │ 32 bits  ├────────────────┘        │
      └────┬─────┘                         │
           │ pc[31:0]                      │
           │                               ▼
           │  ┌────────────────────────────────────────────────────────────────────────────┐
           │  │                    DATAPATH (riscv_top.sv)                                  │
           │  │                                                                              │
           │  │  instr[31:0]                                                                │
           │  │    │                                                                         │
           │  │    ├──[6:0]──→ opcode ──→ ┌─────────────────┐ → reg_write                  │
           │  │    ├──[14:12]→ funct3 ──→ │  CONTROL UNIT   │ → alu_src_a, alu_src_b      │
           │  │    ├──[31:25]→ funct7 ──→ │ (control_unit.sv│ → mem_read, mem_write        │
           │  │    ├──[11:7]──→ rd ──────→ └────────┬────────┘ → branch, jump, jump_r     │
           │  │    ├──[19:15]→ rs1_addr             │ alu_op[1:0]  → mem_to_reg[1:0]      │
           │  │    ├──[24:20]→ rs2_addr             │                                       │
           │  │    │                                 ▼                                       │
           │  │    │          ┌─────────────────────────────────────┐                       │
           │  │    └──[31:0]─→│       IMM_GEN (imm_gen.sv)         │                       │
           │  │               │ → imm_i, imm_s, imm_b, imm_u, imm_j│                       │
           │  │               └─────────────────────────────────────┘                       │
           │  │                                                                              │
           │  │  ┌──────────────────────────────────────────────────────────────────────┐   │
           │  │  │           BANCO DE REGISTRADORES (register_file.sv)                  │   │
           │  │  │    32 registradores × 32 bits                                        │   │
           │  │  │    rs1_addr → rs1_data[31:0]  (combinacional)                        │   │
           │  │  │    rs2_addr → rs2_data[31:0]  (combinacional)                        │   │
           │  │  │    rd, reg_wd, reg_write → escrita @posedge clk                      │   │
           │  │  │    dbg_reg_sel → dbg_reg_val  (debug)                                │   │
           │  │  └──────────────────────────────────────────────────────────────────────┘   │
           │  │         │ rs1_data              │ rs2_data                                   │
           │  │         │                       │                                             │
           │  │  ┌──────▼──────┐        ┌───────▼────────────┐                             │
           │  │  │  MUX ALU_A  │        │     MUX ALU_B       │                             │
           │  │  │ 0: rs1_data │        │ 0: rs2_data         │                             │
           └──┼──│ 1: PC       │        │ 1: imm_sel          │                             │
    (AUIPC)   │  └──────┬──────┘        └───────┬─────────────┘                             │
              │         │ alu_a                  │ alu_b                                     │
              │         │                        │          ┌──────────────────────────────┐ │
              │         │         ┌──────────────┘          │  ALU CONTROL (alu_control.sv)│ │
              │         │         │                         │  alu_op, funct3, funct7      │ │
              │         │         │                         │  → alu_sel[3:0]              │ │
              │         │         │                         │  → branch_inv                │ │
              │         │         │                         └─────────────┬────────────────┘ │
              │         ▼         ▼                                       │ alu_sel           │
              │    ┌─────────────────────────────────┐                   │                   │
              │    │          ALU (alu.sv)            │ ←─────────────────┘                   │
              │    │  10 operações de 32 bits         │                                       │
              │    │  a, b, op → result, zero         │                                       │
              │    └─────────────┬───────────────────┘                                       │
              │                  │ alu_result[31:0]                                           │
              │                  │                                                             │
              │                  ├──────────────────────────→ data_addr (Porta B mem)         │
              │                  │                                        ↑                    │
              │                  │                                  (endereço de dados)        │
              │                  │                                                             │
              │    ┌─────────────▼──────────────────────────────────────────┐                 │
              │    │              MUX WRITE-BACK (mem_to_reg)                │                 │
              │    │  00: alu_result  (R-type, I-arith, AUIPC)               │                 │
              │    │  01: data_rd     (LOAD: LW, LH, LB, LHU, LBU)          │ ←── data_rd    │
              │    │  10: pc_plus4    (JAL, JALR: endereço de retorno)        │                 │
              │    │  11: imm_u       (LUI: carrega imediato de 20 bits)      │                 │
              │    └──────────────────────┬────────────────────────────────────┘                │
              │                          │ reg_wd[31:0]                                        │
              │                          └──────────────────────→ Banco de Registradores        │
              │                                                    (entrada wd)                  │
              └──────────────────────────────────────────────────────────────────────────────────┘

           Próximo PC (dentro de riscv_top.sv):
           ┌─────────────────────────────────────────────────────────────────────────┐
           │  branch_target = PC + imm_b                                             │
           │  jalr_target   = {(rs1_data + imm_i)[31:1], 1'b0}                      │
           │                                                                          │
           │  take_branch:                                                            │
           │    se alu_sel==SUB: usa flag zero (BEQ/BNE)                             │
           │    senão:          usa result[0]  (BLT/BGE/BLTU/BGEU)                  │
           │    branch_inv=1:   inverte a condição (BNE, BGE, BGEU)                  │
           │                                                                          │
           │  pc_next = jump      → PC + imm_j        (JAL)                          │
           │          = jump_r    → jalr_target        (JALR)                         │
           │          = branch    → branch_target       (branch tomado)               │
           │          = default   → PC + 4             (sequencial)                  │
           └─────────────────────────────────────────────────────────────────────────┘
```

---

## Comparação: Von Neumann vs Harvard

| Aspecto | Von Neumann (esta versão) | Harvard (`../riscv_harvard/`) |
|---------|--------------------------|-------------------------------|
| **Número de memórias** | 1 unificada (16 KB) | 2 separadas (4 KB instr + 4 KB dados) |
| **Arquivo central** | `unified_mem.sv` | `instr_mem.sv` + `data_mem.sv` |
| **Conflito de endereços** | Sim — código e dados no mesmo espaço | Não — espaços completamente separados |
| **Risco de corrupção** | Sim — SW em 0x0 destrói código | Não — fisicamente impossível |
| **Programação** | Requer disciplina (base 0x1000+) | Sem restrição de endereço |
| **Profundidade de memória** | 4096 palavras (DEPTH=4096) | 1024 palavras cada (DEPTH=1024) |
| **Espaço total** | 16 KB compartilhado | 4 KB + 4 KB = 8 KB total |
| **Auto-modificação** | Possível (programa pode reescrever código) | Impossível (ROM separada) |
| **Uso real** | PCs, smartphones, servidores | DSPs, microcontroladores (AVR, PIC), GPUs |
| **Gargalo teórico** | Sim (Von Neumann bottleneck) | Não (dois barramentos paralelos) |
| **Complexidade de HW** | Menor (1 memória) | Maior (2 memórias, 2 barramentos) |
| **Caches modernas** | Von Neumann logicamente, Harvard fisicamente | — |

### O paradoxo das CPUs modernas

Computadores modernos (x86, ARM, RISC-V Linux) são **Von Neumann logicamente** —
o programador enxerga um único espaço de endereçamento para código e dados.

Mas internamente, eles usam caches **Harvard** — L1 cache de instrução separada
da L1 cache de dados, com dois barramentos separados para busca de instrução e
acesso a dados simultâneos.

Essa arquitetura híbrida (chamada **Modified Harvard**) combina:
- **Simplicidade do modelo de programação** Von Neumann (um espaço de endereçamento)
- **Performance do hardware** Harvard (barramentos paralelos via cache)

```
Modelo de programação (visível ao programador):
  Memória unificada  →  Von Neumann

Hardware real (invisível ao programador):
  Cache L1-I  ←┐     ←  Harvard
  Cache L1-D  ←┘
  Cache L2         ←  Von Neumann (unificada)
  RAM              ←  Von Neumann (unificada)
```

Este processador educacional implementa Von Neumann "puro" — simples, fiel ao modelo
original e perfeito para entender os fundamentos antes de avançar para as sofisticações
dos processadores modernos.

---

*Para a versão Harvard deste processador, veja `../riscv_harvard/`.*
