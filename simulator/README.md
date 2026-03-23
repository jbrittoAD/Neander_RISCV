# Simulador Interativo RISC-V RV32I

Simula o processador RISC-V ciclo a ciclo com interface de linha de comando.
Equivalente ao simulador do Neander, mas para a ISA RISC-V de 32 bits.

---

## Pré-requisitos

Apenas Python 3.6+. Sem dependências externas.

```bash
python3 --version   # deve ser 3.6 ou superior
```

---

## Início rápido

```bash
# A partir do diretório raiz do projeto:

# Compila os programas de teste (precisa do compilador RISC-V)
cd riscv_harvard && make programs && cd ..

# Inicia o simulador com um programa
python3 simulator/riscv_sim.py riscv_harvard/programs/test_arith.hex

# Modo Von Neumann
python3 simulator/riscv_sim.py riscv_von_neumann/programs/test_arith.hex --vn

# Executa até halt e imprime registradores (modo batch, sem interação)
python3 simulator/riscv_sim.py riscv_harvard/programs/test_arith.hex --run
```

---

## Comandos interativos

Ao entrar no simulador, você verá o prompt `riscv>`. Comandos disponíveis:

| Comando            | Alias  | Descrição |
|---|---|---|
| `step [n]`         | `s`    | Executa n instruções (padrão: 1) |
| `run`              | `r`    | Executa até halt ou breakpoint |
| `reg`              | `regs` | Mostra todos os 32 registradores |
| `mem <addr> [n]`   | `m`    | Mostra n words de dados (padrão: 8) |
| `imem [addr] [n]`  | `i`    | Mostra n words de instruções com desmontagem |
| `bp <addr>`        |        | Ativa/desativa breakpoint |
| `bps`              |        | Lista breakpoints ativos |
| `watch [<reg>]`    | `w`    | Monitora mudanças em registrador (marca ★ no trace) |
| `set <reg> <val>`  |        | Define valor de um registrador diretamente |
| `history [n]`      | `hist` | Mostra as últimas n instruções executadas |
| `load <arquivo>`   |        | Carrega novo programa .hex |
| `reset`            |        | Reinicia CPU (mantém programa) |
| `trace [on\|off]`  |        | Exibe trace completo durante `run` |
| `help`             | `h`    | Ajuda |
| `quit`             | `q`    | Sai |

### Exemplos de sessão

```
riscv> step          ← executa 1 instrução, mostra o que aconteceu
riscv> step 5        ← executa 5 instruções
riscv> reg           ← mostra todos os registradores
riscv> mem 0x0000 8  ← mostra 8 words de dados a partir do endereço 0
riscv> imem 0x0000   ← mostra instruções a partir do endereço 0 (com PC marcado)
riscv> bp 0x10       ← define breakpoint no endereço 0x10
riscv> run           ← executa até halt ou breakpoint
riscv> watch a0      ← monitora x10 (a0) durante step/run — aparece ★ nas mudanças
riscv> set a0 42     ← força a0=42 para testar outro caminho de execução
riscv> history 10    ← mostra as últimas 10 instruções executadas
riscv> trace on      ← ativa trace
riscv> run           ← agora imprime cada instrução executada
riscv> reset         ← volta ao início (limpa histórico)
riscv> quit          ← sai
```

---

## Saída de uma instrução (`step`)

```
  [0x00000000] addi  x1, x0, 5  (0x00500093)
    x1(ra): 0x00000000 → 0x00000005 (5)
```

- `[0x00000000]` — endereço do PC onde a instrução estava
- `addi x1, x0, 5` — desmontagem legível
- `(0x00500093)` — valor hexadecimal da instrução
- `x1(ra): 0x00... → 0x00...` — registrador alterado: valor antes → valor depois

---

## Modos de memória

### Harvard (padrão)
Memórias separadas, como na implementação `riscv_harvard/`:
- **imem**: 4 KB para instruções (read-only após carga)
- **dmem**: 4 KB para dados (read-write, começa zerada)

```bash
python3 simulator/riscv_sim.py programa.hex
```

Comando `mem` mostra **dados** (dmem). Comando `imem` mostra **instruções** (imem).

### Von Neumann (`--vn`)
Memória unificada de 64 KB, como em `riscv_von_neumann/`:
- Código e dados compartilham o mesmo espaço
- Por convenção, dados ficam em 0x1000+

```bash
python3 simulator/riscv_sim.py programa.hex --vn
```

---

## Flags de linha de comando

```
python3 riscv_sim.py [arquivo.hex] [opções]

Opções:
  --vn              Modo Von Neumann (padrão: Harvard)
  --run             Executa sem interação e imprime registradores finais
  --no-color        Desativa cores ANSI (útil em terminais sem suporte)
  --imem-size N     Tamanho da imem em bytes (padrão: 4096)
  --dmem-size N     Tamanho da dmem em bytes (padrão: 4096)
  --mem-size N      Tamanho da mem unificada VN em bytes (padrão: 65536)
```

---

## Testes

```bash
# Testes unitários (não precisam do compilador RISC-V):
python3 simulator/tests/test_core.py

# Testes de integração (precisam de make programs):
python3 simulator/tests/test_programs.py

# Todos os testes:
bash simulator/tests/run_all.sh
```

**Cobertura dos testes unitários (89 testes):**
- Funções auxiliares: to_u32, to_s32, sign_extend
- Memória: leitura/escrita de 1/2/4 bytes, limites, little-endian
- R-type: add, sub, and, or, xor, sll, srl, sra, slt, sltu
- I-type: addi, slti, sltiu, xori, ori, andi, slli, srli, srai
- Load/Store: lw/sw, lh/sh/lhu, lb/sb/lbu
- Branch: beq, bne, blt, bge, bltu, bgeu
- Jumps: jal, jalr (com alinhamento de bit 0)
- U-type: lui, auipc
- Comportamento especial: x0=0, halt, reset, trace de registradores/memória
- **Simulator.watch**: ativar/desativar, marca ★ no trace, validação de nome ABI
- **Simulator.set**: decimal/hex/negativo, rejeita x0, aceita nome ABI
- **Simulator.history**: acumula, respeita limite máximo, limpa no reset
- Integração: programa aritmético completo (replica test_arith.s)

---

## Como funciona por dentro

O simulador é composto por três classes:

```
Memory          — bytearray byte-endereçável, leitura/escrita de 1/2/4 bytes
CPU             — registradores, PC, fetch/decode/execute por ciclo
Simulator       — REPL interativo, breakpoints, formatação colorida
```

### Ciclo de execução (CPU.step)

Para cada instrução:
1. **Fetch**: lê 32 bits no PC (`imem` ou `mem`)
2. **Decode**: extrai opcode, rd, rs1, rs2, funct3, funct7, imediato
3. **Execute**: executa a operação conforme o opcode
4. **Writeback**: escreve em rd e/ou memória de dados
5. **PC update**: avança para próxima instrução ou salta (branch/jump)
6. **Halt check**: se novo PC == PC atual → loop infinito → halt

### Comparação com o hardware SystemVerilog

| Aspecto | Hardware (Verilator) | Simulador Python |
|---|---|---|
| Execução | Ciclo de clock real | `CPU.step()` |
| Fetch | `instr_mem.sv` | `imem.read32(pc)` |
| Decode | `control_unit.sv` | extração de campos de bits |
| ALU | `alu.sv` + `alu_control.sv` | aritmética Python |
| Registradores | `register_file.sv` | `regs[32]` |
| Memória | `data_mem.sv` | `dmem.read/write` |

---

## Diferença do simulador Neander

O simulador Neander da UFRGS tem interface gráfica e 11 instruções.
Este simulador tem interface de linha de comando e implementa as **37 instruções RV32I**.

| Neander | Este simulador |
|---|---|
| GUI (janela gráfica) | Terminal (REPL) |
| 8 bits | 32 bits |
| 11 instruções | 37 instruções |
| 256 posições de memória | 4 KB imem + 4 KB dmem (Harvard) |
| Acumulador único | 32 registradores |
| step/run/breakpoint | step/run/breakpoint/trace/imem |
