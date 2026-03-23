# Processador RISC-V RV32I — Harvard e Von Neumann

![CI](https://github.com/YOUR_REPO/actions/workflows/ci.yml/badge.svg)

Implementação educacional completa do conjunto de instruções RISC-V base de 32 bits
(RV32I) em **SystemVerilog**, simulada e validada com **Verilator**.

Inspirado na abordagem pedagógica do processador **Neander** (Weber, UFRGS), mas
usando a ISA RISC-V — padrão aberto, moderno, usado em chips reais (SiFive, RISC-V
International, Google, etc.).

---

## Duas versões

| Versão | Diretório | Memória |
|---|---|---|
| **Harvard** | `riscv_harvard/` | Instruções e dados em memórias **separadas** (ROM + RAM) |
| **Von Neumann** | `riscv_von_neumann/` | Instruções e dados na **mesma memória** unificada |

Ambas implementam o mesmo conjunto de instruções RV32I completo e passam nos
mesmos testes. A diferença está na organização da memória.

---

## Início rápido

```bash
# Testa a versão Harvard
cd riscv_harvard
make all

# Testa a versão Von Neumann
cd ../riscv_von_neumann
make all
```

---

## Instruções suportadas (ambas as versões)

**37 instruções RV32I base:**

| Tipo | Instruções |
|---|---|
| R-type | `add sub and or xor sll srl sra slt sltu` |
| I-type (arith) | `addi andi ori xori slti sltiu slli srli srai` |
| I-type (load) | `lw lh lb lhu lbu` |
| S-type (store) | `sw sh sb` |
| B-type (branch) | `beq bne blt bge bltu bgeu` |
| U-type | `lui auipc` |
| J-type | `jal jalr` |

---

## Resultados dos testes

| Teste | Componente testado | Verificações |
|---|---|---|
| ALU (unitário) | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU | 26 |
| Banco de Registradores | Escrita, leitura, x0=0, dual-port | 8 |
| Aritmético | Instruções R-type e I-type | 15 |
| Load/Store | LW, SW, LB, SB, LBU, LH, SH, LHU | 8 |
| Branches | BEQ, BNE, BLT, BGE, BLTU | 7 |
| Jumps | JAL, JALR | 5 |
| **Total** | | **69** |

Todos os 69 testes passam em ambas as versões.

---

## Pacote didático completo

Este repositório inclui tudo para reproduzir a experiência do Neander com RISC-V:

| Recurso | Diretório | Descrição |
|---|---|---|
| **Simulador interativo** | [`simulator/`](simulator/) | Step-by-step, breakpoints, watch, history — como o simulador Neander |
| **Tutoriais** | [`tutoriais/`](tutoriais/) | 7 tutoriais do zero ao avançado + guia de erros comuns |
| **Exercícios** | [`exercicios/`](exercicios/) | 20 exercícios em 4 listas com gabarito verificado automaticamente |
| **Exemplos** | [`exemplos/`](exemplos/) | 12 programas clássicos + guia C→RISC-V |
| **Referência** | [`referencia/`](referencia/) | Cartão de todas as 37 instruções |

### Simulador interativo

```bash
# Compilar um programa e rodar no simulador
cd riscv_harvard && make programs && cd ..

python3 simulator/riscv_sim.py riscv_harvard/programs/test_arith.hex
```

```
riscv> step 5        # executa 5 instruções
riscv> reg           # mostra registradores
riscv> mem 0x0000 8  # mostra memória de dados
riscv> watch a0      # monitora mudanças em a0 (★ no trace)
riscv> set a0 99     # força valor de registrador
riscv> history 10    # últimas 10 instruções executadas
riscv> run           # executa até o halt
riscv> reset         # reinicia
```

Testes do simulador (89 verificações, sem dependências externas):
```bash
python3 simulator/tests/test_core.py
```

Verificador automático de gabaritos (20 exercícios):
```bash
python3 exercicios/verifica_gabaritos.py
```

### Por onde começar?

1. Leia [`tutoriais/README.md`](tutoriais/README.md)
2. Siga o Tutorial 01 (Olá Mundo)
3. Resolva os exercícios da Lista 1
4. Explore os programas de exemplo
5. Estude a implementação em SystemVerilog

---

## Documentação do hardware

- [`riscv_harvard/README.md`](riscv_harvard/README.md) — Documentação completa da versão Harvard
- [`riscv_von_neumann/README.md`](riscv_von_neumann/README.md) — Documentação completa da versão Von Neumann

---

## Instalação

```bash
# macOS e Linux — script automático:
./install.sh

# Ou manualmente (macOS):
brew install verilator riscv-gnu-toolchain python
```

O script `install.sh` detecta o sistema operacional (macOS, Ubuntu/Debian, Arch), instala as dependências e executa os testes do simulador como verificação final.

Versões testadas: Verilator 5.042, GNU Binutils 2.45, Python 3.x

---

## Usando com Docker (sem instalar nada localmente)

```bash
# Constrói a imagem (uma vez)
docker build -t neander-riscv .

# Abre um shell interativo com todas as ferramentas
docker run --rm -it -v $(pwd):/project neander-riscv bash

# Ou com docker-compose:
docker-compose run --rm riscv

# Dentro do container:
python3 simulator/tests/test_core.py          # testes do simulador
python3 exercicios/verifica_gabaritos.py       # todos os gabaritos
make -C exemplos all                           # compila exemplos
```

O Docker é ideal para:
- Windows (via Docker Desktop)
- Linux sem acesso root para instalar pacotes
- Ambiente reproduzível para correção automática
