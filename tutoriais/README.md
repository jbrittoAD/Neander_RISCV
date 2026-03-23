# Tutoriais — RISC-V RV32I do Zero

Série de 7 tutoriais progressivos para aprender assembly RISC-V partindo do zero,
com analogias ao processador Neander da UFRGS.

---

## Como usar os tutoriais

Cada tutorial:
1. Explica um conceito com exemplos em português
2. Mostra código assembly completo e comentado
3. Ensina como compilar e testar no simulador interativo
4. Termina com um exercício prático com solução

Para melhor aproveitamento, leia os tutoriais em ordem e pratique cada exercício antes de ver a solução.

---

## Sequência de tutoriais

| Tutorial | Título | Nível | Conceitos |
|---|---|---|---|
| [01](01_ola_mundo.md) | Olá Mundo | ⭐ | Registradores, addi, add, compilação |
| [02](02_aritmetica.md) | Aritmética | ⭐⭐ | Operações lógicas, shifts, LUI, constantes grandes |
| [03](03_desvios.md) | Desvios Condicionais | ⭐⭐ | if/else, beq, bne, blt, bge |
| [04](04_lacos.md) | Laços | ⭐⭐ | for/while em assembly, loops com contador |
| [05](05_memoria.md) | Memória | ⭐⭐⭐ | Arrays, lw/sw, lb/sb, ponteiros |
| [06](06_funcoes.md) | Funções | ⭐⭐⭐⭐ | jal/jalr, convenção de chamada, pilha |
| [07](07_depuracao.md) | Depuração | ⭐⭐⭐ | step, bp, watch, history, set, estratégia de depuração |

---

## Pré-requisito: compilador e simulador

### Instalar o compilador RISC-V (macOS)
```bash
brew install riscv-gnu-toolchain
```

### Compilar um programa tutorial
```bash
# Escreva seu programa em prog.s, depois:
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o prog.o prog.s
riscv64-unknown-elf-objcopy -O binary prog.o prog.bin
python3 ../riscv_harvard/scripts/bin2hex.py prog.bin prog.hex
```

### Rodar no simulador interativo
```bash
python3 ../simulator/riscv_sim.py prog.hex
```

### Comandos essenciais do simulador
```
riscv> step          executa 1 instrução
riscv> step 5        executa 5 instruções
riscv> run           executa até o halt
riscv> reg           mostra todos os registradores
riscv> mem 0x0000 8  mostra 8 words de dados
riscv> imem 0x0000   mostra instruções com desmontagem
riscv> reset         reinicia do início
riscv> quit          sai
```

### Comandos de depuração (Tutorial 07)
```
riscv> bp 0x0014     define/remove breakpoint no endereço
riscv> bps           lista breakpoints ativos
riscv> watch x2      para quando x2 mudar de valor
riscv> history 10    mostra as 10 últimas instruções executadas
riscv> set x2 120    força valor num registrador (para testar hipóteses)
riscv> trace on      imprime cada instrução ao executar
```

---

## Diferenças em relação ao Neander

| Aspecto | Neander | RISC-V RV32I |
|---|---|---|
| Tamanho | 8 bits | 32 bits |
| Registradores | 1 acumulador | 32 registradores (x0–x31) |
| Instruções | ~11 | 37 (base RV32I) |
| Memória | 256 bytes | até 4 GB (endereçável por byte) |
| Halt | `HLT` | `jal x0, fim` (loop para si mesmo) |
| Desvio | `JN`, `JZ` | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Chamada | não existe | `jal ra, funcao` + `jalr x0, ra, 0` |
| Memória | Von Neumann | Harvard ou Von Neumann (configurável) |

---

## Após os tutoriais

- **Exemplos comentados:** [`../exemplos/`](../exemplos/) — Fibonacci, Fatorial, Bubble Sort, Máximo de Array, etc. Cada programa tem o mesmo estilo de comentários dos tutoriais.
- **Simulador:** [`../simulator/README.md`](../simulator/README.md) — guia completo do simulador, incluindo todos os comandos, flags e como funciona internamente.
- **Hardware Harvard:** [`../riscv_harvard/README.md`](../riscv_harvard/README.md) — a implementação SystemVerilog do processador que você acabou de programar.
- **Hardware Von Neumann:** [`../riscv_von_neumann/README.md`](../riscv_von_neumann/README.md) — variação com memória unificada.

---

## Referência rápida

### Erros comuns — [`erros_comuns.md`](erros_comuns.md)

Guia de referência (não é um tutorial numerado) listando os 10 erros mais
frequentes ao escrever assembly RISC-V, com sintoma, causa, exemplo errado,
exemplo correto e como detectar no simulador. Inclui um checklist de depuração
de 5 pontos para usar antes de pedir ajuda.

Tópicos cobertos: `ra` não salvo antes de chamada aninhada, confusão entre
`t`-registers e `s`-registers, indexação de array sem `slli`, acesso não
alinhado, halt errado, imediato fora do alcance de 12 bits, stack pointer
não inicializado, condição de branch invertida, fall-through, e `xori` com
máscara errada para NOT de 32 bits.
