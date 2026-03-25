# Parte 1 — Fundamentos e Ambiente

> **Ponto de partida:** esta é a primeira parte da série. Nenhum conhecimento prévio de RISC-V é necessário, mas familiaridade básica com lógica digital e SystemVerilog ajuda.

Esta série constrói um processador RISC-V RV32I completo do zero, peça por peça. Ao final você terá um processador funcional capaz de executar programas reais escritos em assembly RISC-V.

---

## O que vamos construir

O objetivo da série é um **processador single-cycle RISC-V RV32I** implementado em SystemVerilog e simulado com Verilator. "Single-cycle" significa que cada instrução completa sua execução em exatamente um ciclo de clock — sem pipeline, sem estágios intermediários. É a arquitetura mais simples possível e o ponto de partida ideal para entender como um processador funciona por dentro.

### Por que RISC-V?

O RISC-V é uma ISA (Instruction Set Architecture) aberta, criada na UC Berkeley em 2010. Diferente de x86 ou ARM, ela não tem décadas de cruft acumulado — foi projetada do zero com clareza e elegância como metas. RV32I, o subconjunto base de 32 bits com inteiros, tem apenas **37 instruções**. Você pode implementar 37 instruções em um fim de semana. Isso não é possível com x86.

### Arquitetura Harvard vs Von Neumann

Vamos implementar as duas abordagens ao longo da série e comparar:

**Arquitetura Harvard** (memórias separadas):
- Uma memória exclusiva para instruções (ROM)
- Uma memória exclusiva para dados (RAM)
- As duas memórias podem ser acessadas ao mesmo tempo, no mesmo ciclo

```
  CPU
  ┌────────────────────────┐
  │                        │
  │  PC ──► INSTR MEM ──►  │──► instrução
  │                        │
  │  ALU ──► DATA MEM ──►  │──► dado lido
  │          ◄─────────────│◄── dado escrito
  └────────────────────────┘
```

**Arquitetura Von Neumann** (memória unificada):
- Uma única memória guarda instruções e dados
- A CPU precisa arbitrar: buscar instrução OU acessar dado (não os dois ao mesmo tempo no modelo mais simples)

```
  CPU
  ┌────────────────────────┐
  │                        │     ┌──────────────┐
  │  PC  ──────────────────│────►│              │
  │                        │     │  MEM UNIF.   │
  │  ALU ──────────────────│────►│  (instr+dado)│
  │          ◄─────────────│◄────│              │
  └────────────────────────┘     └──────────────┘
```

Para o processador **single-cycle**, a arquitetura Harvard é a escolha natural: em cada ciclo precisamos buscar uma instrução E possivelmente ler/escrever um dado. Com Harvard, isso acontece simultaneamente sem conflito. Por isso começamos com Harvard (Partes 1-6) e depois revisitamos Von Neumann (Parte 7+).

---

## Pré-requisitos — ferramentas necessárias

### Verilator 5.x

O Verilator é o simulador que usaremos. Ele converte código SystemVerilog em C++, compila o C++ em um binário nativo e executa a simulação. É o simulador open-source mais rápido disponível para SystemVerilog.

**macOS (Homebrew):**
```bash
brew install verilator
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install verilator g++ make
```

**Fedora/RHEL:**
```bash
sudo dnf install verilator gcc-c++ make
```

### Toolchain RISC-V

Para compilar programas assembly para rodar no nosso processador:

**macOS:**
```bash
brew tap riscv-software-src/riscv
brew install riscv-gnu-toolchain
```

**Ubuntu:**
```bash
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf
```

> **Nota:** em alguns sistemas Ubuntu o toolchain está disponível como `riscv64-linux-gnu-*` em vez de `riscv64-unknown-elf-*`. Os comandos funcionam da mesma forma, apenas troque o prefixo.

### Python 3

Usado para scripts auxiliares (conversor de binário para hex, gerador de programas de teste):

**macOS:**
```bash
brew install python3
```

**Ubuntu:**
```bash
sudo apt install python3
```

### GTKWave (opcional)

Para visualizar formas de onda de sinais durante a simulação — muito útil para depuração:

**macOS:**
```bash
brew install --cask gtkwave
```

**Ubuntu:**
```bash
sudo apt install gtkwave
```

### Verificando as instalações

Execute estes comandos e confirme que cada um retorna uma versão válida:

```bash
verilator --version
# Esperado: Verilator 5.x.y ...

riscv64-unknown-elf-as --version
# Esperado: GNU assembler version 2.x.y ...

python3 --version
# Esperado: Python 3.x.y
```

Se o Verilator retornar versão 4.x ou inferior, atualize — as sintaxes de flag mudaram entre v4 e v5.

---

## Estrutura de diretórios

Crie a estrutura abaixo. Usaremos ela ao longo de toda a série:

```bash
mkdir -p meu_riscv/{src,tb,obj_dir,programs,scripts,sim}
cd meu_riscv
```

Resultado:
```
meu_riscv/
├── src/          # Módulos SystemVerilog (.sv)
├── tb/           # Testbenches em C++ (.cpp)
├── obj_dir/      # Gerado automaticamente pelo Verilator (não versionar)
├── programs/     # Programas assembly de teste (.s, .hex)
├── scripts/      # Scripts auxiliares Python
└── sim/          # Saídas da simulação (VCD, logs)
```

**Por que separar `src/` de `tb/`?**
Os arquivos em `src/` são o hardware real — o que seria sintetizado em um FPGA ou ASIC. Os arquivos em `tb/` são infraestrutura de teste, executam apenas em simulação. Mantê-los separados deixa claro o que é RTL (Register Transfer Level) e o que é ambiente de teste.

Adicione um `.gitignore` para não versionar arquivos gerados:

```bash
cat > .gitignore << 'EOF'
obj_dir/
sim/*.vcd
sim/*.log
*.o
EOF
```

---

## A ISA RISC-V RV32I — o que vamos implementar

### Registradores

O RISC-V RV32I define **32 registradores de uso geral**, cada um com **32 bits**:

| Registrador | Nome ABI | Uso convencional |
|-------------|----------|------------------|
| x0 | zero | Sempre zero (hardwired, escrita ignorada) |
| x1 | ra | Return address (endereço de retorno) |
| x2 | sp | Stack pointer |
| x3 | gp | Global pointer |
| x4 | tp | Thread pointer |
| x5-x7 | t0-t2 | Temporários |
| x8 | s0/fp | Saved / frame pointer |
| x9 | s1 | Saved |
| x10-x11 | a0-a1 | Argumentos / valores de retorno |
| x12-x17 | a2-a7 | Argumentos |
| x18-x27 | s2-s11 | Saved |
| x28-x31 | t3-t6 | Temporários |

A convenção de nomes ABI (a0, sp, ra, etc.) é apenas software — o hardware só vê x0 a x31. Qualquer instrução pode usar qualquer registrador; a ABI é uma convenção do compilador.

**Endereçamento:** como endereçar 32 registradores? Precisamos de log₂(32) = 5 bits. Por isso os campos `rs1`, `rs2` e `rd` nas instruções têm exatamente 5 bits.

### Os 6 formatos de instrução

Toda instrução RISC-V tem 32 bits. Os bits são organizados em seis formatos diferentes, dependendo do tipo de operação:

**R-type** — operações registrador-a-registrador (ADD, SUB, AND, OR, XOR, SLT, SLL, SRL, SRA):
```
 31      25 24   20 19   15 14  12 11    7 6      0
┌─────────┬───────┬───────┬──────┬───────┬────────┐
│ funct7  │  rs2  │  rs1  │funct3│  rd   │ opcode │
│  7 bits │ 5 bits│ 5 bits│3 bits│ 5 bits│ 7 bits │
└─────────┴───────┴───────┴──────┴───────┴────────┘
```
`rd = rs1 OP rs2` — lê dois registradores, escreve no terceiro. `funct7` e `funct3` juntos selecionam a operação específica.

**I-type** — imediato de 12 bits (loads, ADDI, SLTI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, JALR):
```
 31          20 19   15 14  12 11    7 6      0
┌─────────────┬───────┬──────┬───────┬────────┐
│  imm[11:0]  │  rs1  │funct3│  rd   │ opcode │
│   12 bits   │ 5 bits│3 bits│ 5 bits│ 7 bits │
└─────────────┴───────┴──────┴───────┴────────┘
```
`rd = rs1 OP imm` — o imediato é estendido em sinal para 32 bits antes de ser usado.

**S-type** — stores (SB, SH, SW). O imediato é **partido em dois campos**:
```
 31      25 24   20 19   15 14  12 11    7 6      0
┌─────────┬───────┬───────┬──────┬───────┬────────┐
│imm[11:5]│  rs2  │  rs1  │funct3│imm[4:0]│ opcode│
│  7 bits │ 5 bits│ 5 bits│3 bits│ 5 bits│ 7 bits │
└─────────┴───────┴───────┴──────┴───────┴────────┘
```
`mem[rs1 + imm] = rs2` — endereço base em rs1, offset em imm, dado a escrever em rs2. O imediato é partido para que rd fique sempre nos mesmos bits (facilita leitura do arquivo de registradores).

**B-type** — branches (BEQ, BNE, BLT, BGE, BLTU, BGEU). Imediato ainda mais scrambled:
```
 31  30      25 24   20 19   15 14  12 11   8 7  6      0
┌───┬─────────┬───────┬───────┬──────┬──────┬──┬────────┐
│im │imm[10:5]│  rs2  │  rs1  │funct3│im[4:1│im│ opcode │
│[12│  6 bits │ 5 bits│ 5 bits│3 bits│4 bits│[11 7 bits │
└───┴─────────┴───────┴───────┴──────┴──────┴──┴────────┘
```
Imediato completo: `{imm[12], imm[11], imm[10:5], imm[4:1], 1'b0}` — note que o bit 0 é sempre zero (branches só para endereços múltiplos de 2). O "scrambling" existe para que o bit 31 seja **sempre** o bit de sinal do imediato em todos os formatos.

**U-type** — Upper immediate (LUI, AUIPC). Imediato de 20 bits nos bits altos:
```
 31                  12 11    7 6      0
┌──────────────────────┬───────┬────────┐
│      imm[31:12]      │  rd   │ opcode │
│       20 bits        │ 5 bits│ 7 bits │
└──────────────────────┴───────┴────────┘
```
`rd = imm << 12` — carrega constante grande. LUI: `rd = imm`. AUIPC: `rd = PC + imm`.

**J-type** — Jump (JAL). Imediato de 21 bits embaralhado:
```
 31  30      21 20 19       12 11    7 6      0
┌───┬──────────┬──┬───────────┬───────┬────────┐
│im │imm[10:1] │im│ imm[19:12]│  rd   │ opcode │
│[20│ 10 bits  │[11  8 bits   │ 5 bits│ 7 bits │
└───┴──────────┴──┴───────────┴───────┴────────┘
```
`rd = PC + 4; PC = PC + imm` — salto incondicional com link.

**Por que o scrambling?** O bit 31 é SEMPRE o MSB do imediato em todos os formatos. Isso significa que o hardware de extensão de sinal é exatamente o mesmo para todos os formatos — apenas replica o bit 31. Sem o scrambling, diferentes formatos teriam o bit de sinal em posições diferentes e precisariam de lógica separada.

### Tabela de opcodes

O campo `opcode` (bits 6:0) identifica a classe da instrução:

| opcode (binário) | opcode (hex) | Tipo | Instruções |
|------------------|--------------|------|------------|
| `0110011` | `0x33` | R | ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA |
| `0010011` | `0x13` | I-arith | ADDI, SLTI, SLTIU, ANDI, ORI, XORI, SLLI, SRLI, SRAI |
| `0000011` | `0x03` | Load | LB, LH, LW, LBU, LHU |
| `0100011` | `0x23` | Store | SB, SH, SW |
| `1100011` | `0x63` | Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| `0110111` | `0x37` | U | LUI |
| `0010111` | `0x17` | U | AUIPC |
| `1101111` | `0x6F` | J | JAL |
| `1100111` | `0x67` | I | JALR |

Os bits 1:0 do opcode são **sempre `11`** nas instruções de 32 bits (instruções compactadas de 16 bits, extensão C, têm outros padrões). Nosso decodificador pode ignorar os bits 1:0.

### As 37 instruções do RV32I

**Aritmética e lógica:**
`ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU` (R-type)
`ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI` (I-type)

**Carregamento de constantes:**
`LUI, AUIPC`

**Memória:**
`LB, LH, LW, LBU, LHU` (loads)
`SB, SH, SW` (stores)

**Desvios condicionais:**
`BEQ, BNE, BLT, BGE, BLTU, BGEU`

**Saltos:**
`JAL, JALR`

**Sincronização:** `FENCE` (tratamos como NOP na nossa implementação)

**Chamadas de sistema:** `ECALL, EBREAK` (tratamos como NOP)

---

## Verilator — como funciona

O Verilator não é um simulador interpretado como o ModelSim ou o VCS. Ele é um **compilador**: converte SystemVerilog em C++, compila o C++ com g++ ou clang, e o resultado é um binário nativo que roda a simulação em velocidade próxima do metal.

### Fluxo de trabalho geral

```
arquivo.sv  ──►  Verilator  ──►  obj_dir/V*.cpp  ──►  g++  ──►  binário
testbench.cpp ──►                                  ──►
                                                         │
                                                         ▼
                                                   ./obj_dir/Vmodulo
                                                         │
                                                         ▼
                                                   saída no terminal
                                                   sim/dump.vcd (ondas)
```

### Comando padrão

```bash
# Padrão geral para compilar e executar:
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/meu_modulo.sv tb/tb_meu_modulo.cpp \
  -o Vmeu_modulo

./obj_dir/Vmeu_modulo
```

**Flags explicadas:**
- `--cc` — gera C++ (não SystemC)
- `--sv` — ativa extensões SystemVerilog (sempre use)
- `--exe` — inclui o testbench C++ no build
- `--build` — compila automaticamente após gerar C++
- `--Mdir obj_dir` — diretório de saída
- `-Wall` — habilita todos os avisos
- `-Wno-UNUSEDSIGNAL` — silencia aviso de sinal não conectado (útil durante desenvolvimento)
- `-o Vmeu_modulo` — nome do executável

### Arquivo de testbench C++ — estrutura mínima

```cpp
#include "Vmeu_modulo.h"      // header gerado pelo Verilator
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vmeu_modulo* dut = new Vmeu_modulo;  // instancia o módulo

    // Ciclo de simulação:
    for (int i = 0; i < 10; i++) {
        dut->clk = 0; dut->eval();   // borda de descida
        dut->clk = 1; dut->eval();   // borda de subida
    }

    dut->final();
    delete dut;
    return 0;
}
```

**Por que `eval()` duas vezes?** O `eval()` propaga sinais combinacionais. Para simular um clock, alternamos o sinal e propagamos duas vezes: uma para a borda de descida e uma para a subida. A lógica sequencial (`always_ff`) dispara na borda de subida.

---

## Primeiro teste: o "Hello World" do hardware

Antes de tocar no processador, vamos verificar que o ambiente funciona com um módulo simples: um contador de 4 bits.

### `src/contador.sv`

```systemverilog
// contador.sv
// Contador de 4 bits que incrementa a cada borda de subida do clock.
// Reseta para 0 quando rst_n é 0 (reset ativo-baixo).

module contador (
    input  logic       clk,
    input  logic       rst_n,   // reset ativo-baixo
    output logic [3:0] count
);
    // always_ff: bloco sequencial — só dispara em bordas de clock
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 4'b0000;   // reset assíncrono
        else
            count <= count + 1'b1;
    end
endmodule
```

**Por que `rst_n` (ativo-baixo)?** Convenção de hardware: sinais de reset costumam ser ativos-baixo porque são mais resistentes a ruído (ruído tende a gerar pulsos positivos; reset ativo-baixo não é ativado por esses pulsos).

### `tb/tb_contador.cpp`

```cpp
// tb_contador.cpp
// Testbench para o contador de 4 bits.
// Roda 20 ciclos de clock e imprime o valor do contador.

#include <iostream>
#include "Vcontador.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    // Instancia o DUT (Device Under Test)
    Vcontador* dut = new Vcontador;

    // Reset inicial: mantém rst_n=0 por 2 ciclos
    dut->rst_n = 0;
    dut->clk   = 0;
    dut->eval();
    dut->clk = 1; dut->eval();
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();

    // Solta o reset
    dut->rst_n = 1;

    std::cout << "Ciclo | count" << std::endl;
    std::cout << "------+------" << std::endl;

    // Roda 20 ciclos e imprime
    for (int ciclo = 0; ciclo < 20; ciclo++) {
        dut->clk = 0; dut->eval();
        dut->clk = 1; dut->eval();

        std::cout << "  " << ciclo
                  << "   |  " << (int)dut->count << std::endl;
    }

    // Verificação: após 16 ciclos o contador wraps para 0 (4 bits = 0-15)
    // Após 20 ciclos, o valor deve ser 20 % 16 = 4
    int esperado = 20 % 16;
    int obtido   = (int)dut->count;
    if (obtido == esperado) {
        std::cout << "\nPASS: contador = " << obtido
                  << " (esperado " << esperado << ")" << std::endl;
    } else {
        std::cout << "\nFAIL: contador = " << obtido
                  << " (esperado " << esperado << ")" << std::endl;
        return 1;
    }

    dut->final();
    delete dut;
    return 0;
}
```

### Compilando e executando

```bash
# Na raiz de meu_riscv/
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/contador.sv tb/tb_contador.cpp \
  -o Vcontador

./obj_dir/Vcontador
```

Saída esperada:
```
Ciclo | count
------+------
  0   |  1
  1   |  2
  2   |  3
  ...
  14  |  15
  15  |  0
  16  |  1
  17  |  2
  18  |  3
  19  |  4

PASS: contador = 4 (esperado 4)
```

Se você ver este output, o ambiente está funcionando corretamente. Podemos começar a construir o processador.

---

## Visão geral do processador single-cycle

Antes de mergulhar nos componentes individuais, veja como tudo se conecta. Este diagrama mostra o datapath completo — o caminho que os dados percorrem para executar uma instrução:

```
                    ┌─────────────────────────────────────────────────────────────────┐
                    │                     PROCESSADOR RISC-V RV32I                    │
                    │                                                                  │
  ┌──────────────┐  │  ┌──────────────┐   ┌───────────┐   ┌──────────────────────┐   │
  │  MEM INSTR   │  │  │              │   │  IMM_GEN  │   │   CONTROL UNIT       │   │
  │  (ROM)       │──┼─►│  INSTRUCTION │──►│  (imediato│   │                      │   │
  │  1024 words  │  │  │  REGISTER    │   │  de 32b)  │   │  opcode ──► sinais   │   │
  └──────────────┘  │  │  [31:0]      │   └─────┬─────┘   │  de controle         │   │
          ▲         │  └──────┬───────┘         │         └──────────┬───────────┘   │
          │         │         │ rs1,rs2,rd       │                    │               │
  ┌───────┴──────┐  │         ▼                  │                    │               │
  │      PC      │  │  ┌──────────────┐          │         ┌──────────┴───────────┐   │
  │  (32 bits)   │  │  │  REGISTER    │──►rd1────┼────────►│                      │   │
  │  PC+4 normal │  │  │  FILE        │          │         │       ALU            │   │
  │  PC+imm branch  │  │  (32×32 bits)│──►rd2    │         │  (10 operações)      │──►│──► resultado
  │  PC+imm JAL  │  │  │              │◄─────────┼──────── │                      │   │
  └──────────────┘  │  └──────────────┘  wd      │mux     └──────────┬───────────┘   │
                    │                             │  ▲                │               │
                    │                             ▼  │                ▼               │
                    │                           ┌────┴───┐   ┌──────────────┐         │
                    │                           │  MUX   │   │  DATA MEM    │         │
                    │                           │ ALU src│   │  (RAM)       │         │
                    │                           │0=rd2   │   │  LB/LH/LW   │         │
                    │                           │1=imm   │   │  SB/SH/SW   │         │
                    │                           └────────┘   └──────────────┘         │
                    └─────────────────────────────────────────────────────────────────┘
```

### Ordem de construção (bottom-up)

Construímos de baixo para cima: cada componente é testado individualmente antes de ser integrado:

```
Parte 2: ALU
  └── half_adder.sv
  └── full_adder.sv
  └── adder_32bit.sv
  └── alu_32bit.sv           ← testada isoladamente

Parte 3: Register File
  └── reg_file.sv            ← testado isoladamente

Parte 4: Memórias
  └── instr_mem.sv           ← testada isoladamente
  └── data_mem.sv            ← testada isoladamente

Parte 5: Controle
  └── imm_gen.sv             ← testado isoladamente
  └── control_unit.sv        ← testada isoladamente
  └── alu_control.sv         ← testada isoladamente

Parte 6: Integração
  └── riscv_cpu.sv           ← integra todos os módulos acima
      └── tb executa programas .hex reais
```

Esta abordagem incremental tem uma vantagem crucial: quando um bug aparece na integração, você já sabe que os componentes individuais funcionam. O espaço de busca do bug fica muito menor.

---

## Resumo da Parte 1

Nesta parte você:

1. Entendeu a diferença entre Harvard e Von Neumann e por que escolhemos Harvard para o processador single-cycle
2. Instalou todas as ferramentas necessárias
3. Criou a estrutura de diretórios do projeto
4. Aprendeu os 6 formatos de instrução RISC-V e a tabela de opcodes
5. Entendeu como o Verilator funciona
6. Compilou e executou o primeiro módulo SystemVerilog

**Próximo passo:** Parte 2 — A Unidade Lógica e Aritmética (ALU), onde construímos do meio-somador de 1 bit até a ALU completa de 32 bits.
