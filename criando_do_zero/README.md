# Construindo o Processador RISC-V RV32I do Zero

Guia passo a passo para implementar um processador RISC-V RV32I completo em SystemVerilog, partindo de um simples meio-somador até um processador funcional capaz de executar as 37 instruções base — em duas arquiteturas de memória diferentes.

---

## Roteiro de construção

| Parte | Arquivo | Conteúdo | Tempo estimado |
|---|---|---|---|
| **1** | [parte1_fundamentos.md](parte1_fundamentos.md) | Ambiente, ISA, formatos de instrução, Verilator | 1h |
| **2** | [parte2_alu.md](parte2_alu.md) | Meio-somador → somador 32 bits → ALU completa (10 ops) | 2h |
| **3** | [parte3_regfile.md](parte3_regfile.md) | Banco de registradores (32×32 bits, dual-port) | 1h |
| **4** | [parte4_memoria.md](parte4_memoria.md) | ROM de instruções, RAM de dados, byte/half/word | 2h |
| **5** | [parte5_controle.md](parte5_controle.md) | Gerador de imediatos, unidade de controle | 2h |
| **6** | [parte6_datapath_harvard.md](parte6_datapath_harvard.md) | Datapath Harvard completo + 4 suites de teste | 3h |
| **7** | [parte7_von_neumann.md](parte7_von_neumann.md) | Adaptação para Von Neumann (memória unificada) | 1h |

**Total:** ~12 horas do zero ao processador completo testado.

---

## O que você vai construir

```
Parte 2          Parte 3         Parte 4              Parte 5
┌─────────┐    ┌──────────┐    ┌────────────┐    ┌────────────────┐
│   ALU   │    │  RegFile │    │  Memórias  │    │    Controle    │
│ 10 ops  │    │ 32 regs  │    │ ROM + RAM  │    │ imm_gen + ctrl │
└────┬────┘    └────┬─────┘    └─────┬──────┘    └───────┬────────┘
     │              │                │                    │
     └──────────────┴────────────────┴────────────────────┘
                                     │
                              Parte 6 & 7
                         ┌───────────┴───────────┐
                         │                       │
                  ┌──────┴──────┐         ┌──────┴──────┐
                  │   Harvard   │         │ Von Neumann │
                  │ ROM + RAM   │         │  Unificada  │
                  │  separadas  │         │             │
                  └─────────────┘         └─────────────┘
```

---

## Filosofia do guia

Cada parte segue o mesmo padrão:

1. **Por quê** — motivação do componente e decisões de projeto
2. **O que** — especificação (entradas, saídas, comportamento)
3. **Como** — código SystemVerilog completo e comentado
4. **Teste** — testbench C++ com verificações PASS/FAIL
5. **Compilar e rodar** — comandos exatos para Verilator

Nenhuma parte assume conhecimento da próxima. Você pode parar em qualquer ponto e ter um componente funcional e testado.

---

## Pré-requisitos

```bash
# Verificar ferramentas instaladas:
verilator --version          # requer 5.x
riscv64-unknown-elf-as --version
python3 --version

# Instalar no macOS:
brew install verilator riscv-gnu-toolchain python3

# Instalar no Ubuntu/Debian:
sudo apt install verilator g++ gcc-riscv64-unknown-elf python3
```

---

## Estrutura de diretórios a criar

```bash
mkdir -p meu_riscv/{src,tb,programs,scripts,sim,obj_dir}
cd meu_riscv
```

```
meu_riscv/
├── src/          # Módulos SystemVerilog
│   ├── half_adder.sv
│   ├── full_adder.sv
│   ├── adder32.sv
│   ├── alu.sv
│   ├── alu_control.sv
│   ├── register_file.sv
│   ├── instr_mem.sv       # Harvard
│   ├── data_mem.sv        # Harvard
│   ├── unified_mem.sv     # Von Neumann
│   ├── imm_gen.sv
│   ├── control_unit.sv
│   ├── pc_reg.sv
│   └── riscv_top.sv
├── tb/           # Testbenches C++ (um por módulo)
├── programs/     # Programas .s (assembly) e .hex gerados
├── scripts/      # bin2hex.py
├── sim/          # Arquivos de simulação (.vcd, etc.)
└── obj_dir/      # Saída do Verilator (auto-gerado)
```

---

## Referência rápida: instruções RV32I

| Tipo | Instruções | Opcode |
|---|---|---|
| R | `add sub and or xor sll srl sra slt sltu` | `0110011` |
| I (arith) | `addi andi ori xori slti sltiu slli srli srai` | `0010011` |
| I (load) | `lw lh lb lhu lbu` | `0000011` |
| S | `sw sh sb` | `0100011` |
| B | `beq bne blt bge bltu bgeu` | `1100011` |
| U | `lui auipc` | `0110111` / `0010111` |
| J | `jal jalr` | `1101111` / `1100111` |

---

## Resultado esperado ao final

Ao concluir a Parte 6, você terá um processador Harvard que:

- Executa as 37 instruções RV32I corretamente
- Passa em 4 suites de teste automatizadas (R-type, Load/Store, Branch, Jump)
- Carrega programas em assembly via arquivo `.hex`
- Pode ser simulado com Verilator em segundos

Ao concluir a Parte 7, você terá a versão Von Neumann, com apenas ~30 linhas modificadas, executando os mesmos testes.
