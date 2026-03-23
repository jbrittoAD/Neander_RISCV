# Tutorial 01 — Olá, Mundo em Assembly RISC-V

**Nível:** ⭐ (iniciante)
**Tempo estimado:** 30 minutos

---

## Objetivo

Escrever, compilar e executar o seu primeiro programa em assembly RISC-V. Ao final deste tutorial você será capaz de:

- Entender o que é linguagem assembly e por que ela é útil
- Conhecer os registradores do RISC-V e para que servem
- Carregar valores constantes em registradores com `addi`
- Somar dois valores com `add`
- Usar o simulador interativo para inspecionar cada instrução executada
- Compilar um arquivo `.s` para `.hex` e carregá-lo no simulador

---

## 1. O que é assembly?

Quando você escreve um programa em C ou Python, o código passa por uma etapa de tradução antes de ser executado pelo processador. O compilador converte o código de alto nível em **linguagem de máquina** — sequências de bits que o hardware entende diretamente.

Assembly é o nível intermediário: cada instrução assembly corresponde a exatamente uma instrução de máquina, escrita em forma legível por humanos. É o nível mais próximo do hardware onde você ainda consegue ler o que está acontecendo.

**Por que aprender assembly?**

- Você vê exatamente o que o processador faz, instrução por instrução
- É a base para entender compiladores, sistemas operacionais e depuração de baixo nível
- Em sistemas embarcados e jogos de alta performance, assembly ainda é escrito à mão

### Comparação com o Neander

O **Neander** (Weber, UFRGS) é um processador didático com 8 bits e 11 instruções simples. O RISC-V RV32I é o passo seguinte: 32 bits, 32 registradores e 37 instruções, mas com a mesma filosofia pedagógica — instruções regulares, simples e ortogonais.

| Aspecto | Neander | RISC-V RV32I |
|---|---|---|
| Largura dos dados | 8 bits | 32 bits |
| Registradores | 1 (acumulador AC) | 32 (x0 a x31) |
| Memória | 256 posições | 4 KB imem + 4 KB dmem |
| Instruções | 11 | 37 |

---

## 2. Registradores

O RISC-V tem **32 registradores de propósito geral**, chamados `x0` a `x31`. Cada um armazena um valor inteiro de 32 bits (4 bytes).

Registradores que você vai usar agora:

| Registrador | Nome ABI | Papel |
|---|---|---|
| `x0` | `zero` | Sempre vale 0. Não pode ser alterado. |
| `x1` | `ra` | Convencionalmente: endereço de retorno de funções |
| `x2` | `sp` | Convencionalmente: ponteiro de pilha |
| `x3` a `x7` | `gp`, `tp`, `t0`–`t2` | Temporários |
| `x10`–`x17` | `a0`–`a7` | Argumentos e retornos de funções |

Por enquanto, ignore a convenção ABI. Você pode usar qualquer registrador de `x1` a `x31` como variável. `x0` é sempre zero — escrever nele não tem efeito.

> **Analogia com o Neander:** O Neander tem apenas um registrador, o Acumulador (AC). No RISC-V você tem 31 registradores livres — escolha qualquer um como "variável" do seu programa.

---

## 3. Instruções básicas

### `addi` — adicionar imediato

```
addi  rd, rs1, imm
```

Lê o valor de `rs1`, soma a constante `imm` (imediato, de -2048 a 2047), e guarda em `rd`.

Exemplos:
```asm
addi  x1, x0, 10     # x1 = x0 + 10 = 0 + 10 = 10
addi  x2, x0, 7      # x2 = 7
addi  x3, x1, 5      # x3 = x1 + 5 = 15
addi  x4, x0, -3     # x4 = -3  (aceita negativos)
```

Como `x0` é sempre zero, `addi xN, x0, K` é a forma de carregar a constante K em xN. É o equivalente ao `LDA` do Neander, mas em vez de carregar da memória você carrega uma constante diretamente na instrução.

### `add` — adicionar registradores

```
add  rd, rs1, rs2
```

Lê `rs1` e `rs2`, soma os dois, guarda em `rd`.

```asm
add  x3, x1, x2      # x3 = x1 + x2
```

---

## 4. Estrutura de um programa

Todo programa assembly RISC-V deste projeto segue este esqueleto:

```asm
.section .text
.global _start
_start:
    # suas instruções aqui

fim:
    jal  x0, fim     # halt — salta para si mesmo (equivalente ao HLT do Neander)
```

- `.section .text` — declara que o que vem a seguir são instruções (código)
- `.global _start` — torna o símbolo `_start` visível para o montador (é o ponto de entrada)
- `_start:` — label (rótulo) que marca o endereço do início do programa
- `fim:` — label que marca o endereço do halt
- `jal x0, fim` — salta incondicionalmente para `fim`, criando um loop infinito

O simulador detecta automaticamente quando o PC (contador de programa) para de avançar e marca o programa como encerrado ("halt").

---

## 5. Primeiro programa

Salve o arquivo como `ola_mundo.s`:

```asm
# =============================================================================
# Olá, Mundo em Assembly RISC-V — Tutorial 01
# =============================================================================
#
# Carrega dois valores, soma-os e guarda o resultado.
#
# Mapeamento de registradores:
#   x1 = valor A = 5
#   x2 = valor B = 3
#   x3 = resultado = A + B = 8
#
# Resultado esperado:
#   x1 = 5
#   x2 = 3
#   x3 = 8

.section .text
.global _start
_start:
    addi  x1, x0, 5          # x1 = 5  (primeiro operando)
    addi  x2, x0, 3          # x2 = 3  (segundo operando)
    add   x3, x1, x2         # x3 = x1 + x2 = 5 + 3 = 8

fim:
    jal   x0, fim            # halt — fim do programa
```

Leia o código linha por linha:

1. `addi x1, x0, 5` — coloca o valor 5 no registrador x1. Lemos x0 (que é sempre 0) e somamos 5.
2. `addi x2, x0, 3` — coloca o valor 3 no registrador x2.
3. `add x3, x1, x2` — soma x1 e x2, guarda em x3. Resultado: 8.
4. `jal x0, fim` — salta para o label `fim` (que é este mesmo endereço), criando o halt.

---

## 6. Compilando o programa

Você precisa do compilador RISC-V instalado. No macOS:

```bash
brew install riscv-gnu-toolchain
```

### Passo a passo: `.s` → `.hex`

O processo de compilação tem três etapas:

```bash
# Passo 1: montar (.s → .o)
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ola_mundo.o ola_mundo.s

# Passo 2: extrair binário (.o → .bin)
riscv64-unknown-elf-objcopy -O binary ola_mundo.o ola_mundo.bin

# Passo 3: converter para hex legível (.bin → .hex)
python3 /caminho/para/riscv_harvard/scripts/bin2hex.py ola_mundo.bin ola_mundo.hex
```

O arquivo `.hex` é uma lista de palavras de 32 bits em hexadecimal, uma por linha, que o simulador e o hardware entendem.

**Visualizando o disassembly (opcional):**
```bash
riscv64-unknown-elf-objdump -d ola_mundo.o
```
Saída esperada:
```
00000000 <_start>:
   0:   00500093    addi    x1, x0, 5
   4:   00300113    addi    x2, x0, 3
   8:   002081b3    add     x3, x1, x2

0000000c <fim>:
   c:   0000006f    jal     x0, 0xc
```

Cada instrução ocupa 4 bytes (32 bits). O endereço avança de 4 em 4: 0x00, 0x04, 0x08, 0x0c.

---

## 7. Executando no simulador

### Iniciando o simulador

```bash
python3 /caminho/para/simulator/riscv_sim.py ola_mundo.hex
```

Você verá o prompt:
```
RISC-V RV32I Simulator (Harvard)
Loaded: ola_mundo.hex (4 instructions)
riscv>
```

### Comandos essenciais

| Comando | O que faz |
|---|---|
| `step` ou `s` | Executa uma instrução |
| `step N` | Executa N instruções de uma vez |
| `reg` | Mostra todos os 32 registradores |
| `run` | Executa até o halt |
| `reset` | Reinicia a CPU (volta ao início) |
| `quit` ou `q` | Sai do simulador |

### Sessão passo a passo

Execute o programa instrução por instrução e observe o que acontece:

```
riscv> step
  [0x00000000] addi  x1, x0, 5  (0x00500093)
    x1(ra): 0x00000000 → 0x00000005 (5)

riscv> step
  [0x00000004] addi  x2, x0, 3  (0x00300113)
    x2(sp): 0x00000000 → 0x00000003 (3)

riscv> step
  [0x00000008] add   x3, x1, x2  (0x002081b3)
    x3(gp): 0x00000000 → 0x00000008 (8)

riscv> step
  [0x0000000c] jal   x0, 0x0000000c  (0x0000006f)
    [HALT detectado — PC não avançou]

riscv> reg
```

O comando `reg` mostra todos os registradores. Procure as linhas de x1, x2 e x3:

```
x0  (zero) = 0x00000000 (0)
x1  (ra)   = 0x00000005 (5)      ← A = 5
x2  (sp)   = 0x00000003 (3)      ← B = 3
x3  (gp)   = 0x00000008 (8)      ← A + B = 8
...
```

### Executando tudo de uma vez

Se não quiser usar o modo interativo, use `--run`:

```bash
python3 /caminho/para/simulator/riscv_sim.py ola_mundo.hex --run
```

Isso executa o programa até o halt e imprime os registradores finais automaticamente.

---

## 8. Pontos de atenção

**`x0` é sempre zero.**
Você não consegue guardar nada em `x0`. Se escrever `addi x0, x0, 5`, a instrução executa mas o valor é descartado. `x0` continua 0.

**Imediatos têm limite.**
O campo imediato de `addi` é de 12 bits com sinal: aceita valores de -2048 a +2047. Para constantes maiores, é necessário usar `lui` + `addi` (veja o Tutorial 02).

**Labels e maiúsculas/minúsculas.**
Labels são sensíveis a maiúsculas: `fim`, `Fim` e `FIM` são três labels diferentes. Use letras minúsculas por convenção.

**Comentários com `#`.**
Em RISC-V assembly (GNU Assembler), o caractere `#` inicia um comentário até o fim da linha. Não existe comentário de bloco.

**O halt é obrigatório.**
Todo programa deve terminar com `jal x0, fim` (onde `fim` é o mesmo label). Sem isso, o processador continua executando memória não inicializada, produzindo comportamento indefinido.

---

## 9. Exercício prático

**Enunciado:** Escreva um programa que calcule `(10 + 4) - 6` e guarde o resultado em `x5`.

**Dicas:**
- Use `addi` para carregar as constantes 10, 4 e 6 em registradores separados
- Use `add` para somar
- Use `sub` para subtrair: `sub rd, rs1, rs2` calcula `rd = rs1 - rs2`
- O resultado esperado é 8

**Solução:**

```asm
.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = 10
    addi  x2, x0, 4          # x2 = 4
    addi  x3, x0, 6          # x3 = 6

    add   x4, x1, x2         # x4 = 10 + 4 = 14
    sub   x5, x4, x3         # x5 = 14 - 6 = 8

fim:
    jal   x0, fim            # halt
```

Para verificar:
```bash
# compila e executa
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o exercicio.o exercicio.s
riscv64-unknown-elf-objcopy -O binary exercicio.o exercicio.bin
python3 bin2hex.py exercicio.bin exercicio.hex
python3 riscv_sim.py exercicio.hex --run
# procure: x5 = 0x00000008 (8)
```

---

## Próximo tutorial

[Tutorial 02 — Aritmética e Operações Lógicas](02_aritmetica.md) — aprenda todas as operações disponíveis: and, or, xor, shifts, comparações com sinal e sem sinal, e como representar constantes grandes.
