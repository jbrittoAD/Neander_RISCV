# Processador RISC-V RV32I — Harvard e Von Neumann

[![CI](https://github.com/jbrittoAD/Neander_RISCV/actions/workflows/ci.yml/badge.svg)](https://github.com/jbrittoAD/Neander_RISCV/actions/workflows/ci.yml)
![Linguagem](https://img.shields.io/badge/SystemVerilog-HDL-blue)
![Simulador](https://img.shields.io/badge/Simulador-Python%203-yellow)
![Testes](https://img.shields.io/badge/Testes-202%20verificações-brightgreen)
![Licença](https://img.shields.io/badge/Licença-MIT-lightgrey)

Implementação educacional completa do conjunto de instruções RISC-V de 32 bits (**RV32I**) em **SystemVerilog**, simulada e validada com **Verilator**. O projeto oferece duas arquiteturas de memória, um simulador interativo em Python, exercícios progressivos com gabarito verificado automaticamente e documentação em PDF.

Inspirado na abordagem pedagógica do processador **Neander** (Weber, UFRGS), mas usando a ISA RISC-V — padrão aberto, moderno, adotado em chips reais (SiFive, Google, Western Digital, etc.).

---

## Arquiteturas implementadas

| Versão | Diretório | Modelo de memória |
|---|---|---|
| **Harvard** | [`riscv_harvard/`](riscv_harvard/) | Instrução e dados em memórias **separadas** (ROM + RAM) |
| **Von Neumann** | [`riscv_von_neumann/`](riscv_von_neumann/) | Instrução e dados na **mesma memória** unificada |

Ambas implementam as **37 instruções RV32I** completas e passam nos mesmos testes de integração. A diferença está exclusivamente na organização da memória — ideal para comparar os dois modelos em sala de aula.

---

## Início rápido

```bash
# Clone o repositório
git clone https://github.com/jbrittoAD/Neander_RISCV.git
cd Neander_RISCV

# macOS / Linux — instala dependências automaticamente
./install.sh

# Ou instale manualmente no macOS:
brew install verilator riscv-gnu-toolchain python

# Roda todos os testes (hardware + simulador + exercícios)
make all
```

### Com Docker (sem instalar nada localmente)

```bash
docker build -t neander-riscv .
docker run --rm -it -v $(pwd):/project neander-riscv bash

# Dentro do container:
make all
```

Ideal para **Windows** (via Docker Desktop) e ambientes sem acesso root.

---

## Instruções RV32I suportadas

**37 instruções base**, todas implementadas e testadas:

| Tipo | Instruções |
|---|---|
| R-type | `add` `sub` `and` `or` `xor` `sll` `srl` `sra` `slt` `sltu` |
| I-type aritmético | `addi` `andi` `ori` `xori` `slti` `sltiu` `slli` `srli` `srai` |
| I-type carga | `lw` `lh` `lb` `lhu` `lbu` |
| S-type armazenamento | `sw` `sh` `sb` |
| B-type desvio | `beq` `bne` `blt` `bge` `bltu` `bgeu` |
| U-type | `lui` `auipc` |
| J-type salto | `jal` `jalr` |

---

## Resultados dos testes

### Hardware (Verilator)

| Suite | Componente | Verificações |
|---|---|---|
| ALU unitária | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | 26 |
| Banco de registradores | Escrita, leitura, x0=0, dual-port | 8 |
| Aritmético integrado | R-type e I-type no processador completo | 15 |
| Load/Store | LW, SW, LB, SB, LBU, LH, SH, LHU | 8 |
| Branches | BEQ, BNE, BLT, BGE, BLTU | 7 |
| Jumps | JAL, JALR | 5 |
| **Total hardware** | | **69** |

Todos os 69 testes passam nas duas versões (Harvard e Von Neumann).

### Simulador Python

| Suite | Verificações |
|---|---|
| Instruções aritméticas e lógicas | 28 |
| Load/Store (byte, half, word) | 18 |
| Branches e jumps | 10 |
| Comandos interativos (watch, set, history) | 33 |
| **Total simulador** | **89** |

### Gabaritos de exercícios

| Listas | Exercícios compilados e executados | Verificações |
|---|---|---|
| Listas 1–5 + Capstone | 24 programas assembly | 24 |

**Total geral: 202 verificações automatizadas.**

---

## Conteúdo do repositório

```
Neander_RISCV/
├── riscv_harvard/          # Processador Harvard (ROM + RAM separadas)
│   ├── src/                # SystemVerilog: ALU, regfile, control, top
│   ├── tb/                 # Testbenches C++ para Verilator
│   └── programs/           # Programas de teste em assembly
├── riscv_von_neumann/      # Processador Von Neumann (memória unificada)
│   └── ...                 # Mesma estrutura do Harvard
├── simulator/              # Simulador interativo em Python
│   └── tests/              # 89 testes unitários
├── tutoriais/              # 7 tutoriais + guia de erros comuns
├── exercicios/             # 5 listas + capstone (24 gabaritos)
│   ├── lista_01_basico/
│   ├── lista_02_intermediario/
│   ├── lista_03_avancado/
│   ├── lista_04_expert/
│   ├── lista_05_bits/
│   └── capstone/
├── exemplos/               # 12 programas clássicos + guia C→RISC-V
├── referencia/             # Cartão de referência das 37 instruções
├── Dockerfile              # Ambiente completo (Ubuntu 24.04 + Verilator 5.x)
└── install.sh              # Script de instalação (macOS, Ubuntu, Arch)
```

---

## Simulador interativo

O simulador emula o processador passo a passo, com breakpoints e inspeção de estado — similar ao simulador Neander original.

```bash
# Monta um programa e carrega no simulador
cd riscv_harvard && make programs && cd ..
python3 simulator/riscv_sim.py riscv_harvard/programs/test_arith.hex
```

Comandos disponíveis no prompt `riscv>`:

| Comando | Descrição |
|---|---|
| `step [n]` | Executa n instruções (padrão: 1) |
| `run` | Executa até o halt ou breakpoint |
| `reg` | Exibe todos os registradores |
| `mem <addr> [n]` | Exibe n words da memória de dados |
| `imem <addr>` | Exibe instruções com o PC marcado |
| `bp <addr>` | Define breakpoint |
| `watch <reg>` | Monitora alterações em um registrador |
| `set <reg> <val>` | Força valor em um registrador |
| `history [n]` | Exibe últimas n instruções executadas |
| `reset` | Reinicia a simulação |

```bash
# Testes do simulador (89 verificações, sem dependências externas):
python3 simulator/tests/test_core.py

# Verificador de gabaritos (compila e executa os 24 exercícios):
python3 exercicios/verifica_gabaritos.py
```

---

## Material didático

### Tutoriais ([`tutoriais/`](tutoriais/))

| # | Arquivo | Tema | Nível |
|---|---|---|---|
| 01 | [`01_ola_mundo.md`](tutoriais/01_ola_mundo.md) | Primeiro programa, halt, simulador | ⭐ |
| 02 | [`02_aritmetica.md`](tutoriais/02_aritmetica.md) | Operações aritméticas e lógicas | ⭐ |
| 03 | [`03_desvios.md`](tutoriais/03_desvios.md) | Desvios condicionais e incondicionais | ⭐⭐ |
| 04 | [`04_lacos.md`](tutoriais/04_lacos.md) | Laços com branch | ⭐⭐ |
| 05 | [`05_memoria.md`](tutoriais/05_memoria.md) | Load/Store, arrays, ponteiros | ⭐⭐ |
| 06 | [`06_funcoes.md`](tutoriais/06_funcoes.md) | Funções, pilha, convenção de chamada | ⭐⭐⭐ |
| 07 | [`07_depuracao.md`](tutoriais/07_depuracao.md) | Depuração com o simulador | ⭐⭐⭐ |
| — | [`erros_comuns.md`](tutoriais/erros_comuns.md) | 10 erros clássicos com diagnóstico | — |

### Exercícios ([`exercicios/`](exercicios/))

| Lista | Tema | Exercícios |
|---|---|---|
| [Lista 1 — Básico ⭐](exercicios/lista_01_basico/enunciado.md) | Aritmética, lógica, shifts, LUI, XOR swap | 5 |
| [Lista 2 — Intermediário ⭐⭐](exercicios/lista_02_intermediario/enunciado.md) | Abs, máximo, soma de N, popcount, busca linear | 5 |
| [Lista 3 — Avançado ⭐⭐⭐](exercicios/lista_03_avancado/enunciado.md) | Ponteiros, funções, fatorial, Fibonacci | 5 |
| [Lista 4 — Expert ⭐⭐⭐⭐](exercicios/lista_04_expert/enunciado.md) | Recursão, busca binária, inversão de string, MMC | 5 |
| [Lista 5 — Bits ⭐⭐](exercicios/lista_05_bits/enunciado.md) | Extração de campo, set/clear/toggle, pack/unpack | 3 |
| [Capstone ⭐⭐⭐⭐⭐](exercicios/capstone/enunciado.md) | Insertion Sort + Busca Binária + Soma de Array | 1 |

Todos os 24 gabaritos são compilados e verificados automaticamente com `verifica_gabaritos.py`.

### Exemplos ([`exemplos/`](exemplos/))

12 programas clássicos prontos para rodar no simulador:
`factorial` · `fibonacci` · `bubblesort` · `selection_sort` · `binary_search` · `gcd` · `power` · `strlen` · `sum_array` · `max_array` · `abs_value` · `counter`

Guia de tradução C → RISC-V assembly: [`exemplos/c_para_riscv.md`](exemplos/c_para_riscv.md)

### Referência ([`referencia/`](referencia/))

Cartão de referência completo com todas as 37 instruções, formatos de codificação, extensões de sinal e exemplos de uso: [`referencia/instrucoes_riscv32.md`](referencia/instrucoes_riscv32.md)

---

## CI/CD

O repositório usa **GitHub Actions** com pipeline de 3 estágios em sequência:

```
Simulador Python (89 testes)
        ↓
Gabaritos (24 exercícios compilados e verificados)
        ↓
Hardware Verilator (Harvard + Von Neumann — 69 verificações)
```

Todo push aciona o pipeline automaticamente. O badge no topo desta página reflete o estado atual da branch `main`.

---

## Dependências e versões testadas

| Ferramenta | Versão testada | Instalação |
|---|---|---|
| Verilator | 5.042 | `brew install verilator` / `apt install verilator` |
| GNU Binutils RISC-V | 2.45 | `brew install riscv-gnu-toolchain` |
| Python | 3.x | `brew install python` |
| GCC (para Docker) | 13.x | incluído na imagem |

---

## Documentação em PDF

Toda a documentação está disponível em PDF gerado automaticamente a partir dos arquivos Markdown:

- [`README.pdf`](README.pdf) — Este documento
- [`tutoriais/`](tutoriais/) — Um PDF por tutorial
- [`exercicios/`](exercicios/) — Um PDF por lista de exercícios
- [`referencia/instrucoes_riscv32.pdf`](referencia/instrucoes_riscv32.pdf) — Cartão de referência

---

## Por onde começar?

1. Instale as dependências com `./install.sh`
2. Leia [`tutoriais/README.md`](tutoriais/README.md) para ter uma visão geral
3. Siga o **Tutorial 01** (Olá Mundo) do início ao fim
4. Resolva os exercícios da **Lista 1**
5. Use o simulador interativo para depurar seus programas
6. Estude a implementação em SystemVerilog em `riscv_harvard/src/`

---

## Licença

MIT — veja [`LICENSE`](LICENSE).
