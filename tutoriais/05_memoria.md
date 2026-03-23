# Tutorial 05 — Memória: Arrays e Acesso a Dados

**Nível:** ⭐⭐⭐ (intermediário)
**Tempo estimado:** 60 minutos

---

## Objetivo

Entender como o RISC-V acessa a memória de dados e como organizar estruturas como arrays. Ao final deste tutorial você será capaz de:

- Explicar a diferença entre memória de instruções e de dados (Harvard vs Von Neumann)
- Usar `sw`/`lw` para escrever e ler words (4 bytes) na memória
- Usar `sh`/`lh`/`lhu` para halfwords (2 bytes) e `sb`/`lb`/`lbu` para bytes (1 byte)
- Entender o endereçamento com deslocamento: `lw x1, 8(x2)`
- Indexar arrays corretamente com `slli` + `add`
- Inicializar e percorrer um array na memória de dados

---

## 1. Memória de Instruções vs Memória de Dados

### Arquitetura Harvard

Na arquitetura **Harvard** (usada por padrão neste projeto), existem duas memórias físicas separadas:

- **imem (Instruction Memory):** armazena o código do programa. Somente leitura após a carga. O PC (contador de programa) aponta para cá.
- **dmem (Data Memory):** armazena dados do programa (variáveis, arrays, etc.). Leitura e escrita. Começa toda zerada.

Quando você usa `lw` ou `sw`, você está acessando a **dmem**. Quando o processador busca a próxima instrução, ele lê da **imem**.

```
         ┌─────────────┐        ┌─────────────┐
         │    imem     │        │    dmem     │
PC ───→  │  (código)   │        │   (dados)   │
         │  read-only  │   ←──→ │  read/write │
         └─────────────┘  lw/sw └─────────────┘
```

### Arquitetura Von Neumann

No modo Von Neumann (`--vn`), código e dados compartilham a mesma memória. O programa começa no endereço 0x0000 e os dados ficam em endereços mais altos (convencionalmente a partir de 0x1000). Isso é o que um PC real usa, mas mistura código e dados na mesma memória pode ser mais confuso para aprender.

```
         ┌─────────────┐
         │   0x0000    │ ← código (instruções)
         │      ...    │
         │   0x1000    │ ← dados (variáveis, arrays)
PC ───→  │      ...    │
         └─────────────┘
```

### No simulador

- `mem 0x0000 8` — mostra 8 words da **dmem** (memória de dados)
- `imem 0x0000` — mostra instruções da **imem** com desmontagem

```
riscv> mem 0x0000 5      ← mostra 5 words de dados
0x0000: 0x0000000a  (10)
0x0004: 0x00000014  (20)
0x0008: 0x0000001e  (30)
0x000c: 0x00000028  (40)
0x0010: 0x00000032  (50)
```

---

## 2. Instruções de Load e Store

### Endereçamento com deslocamento

Toda instrução de acesso à memória usa o formato:

```
instrução  rd, offset(rs1)
```

O endereço real é `rs1 + offset`. O offset é uma constante de 12 bits com sinal (-2048 a 2047).

Exemplos:
```asm
lw   x1, 0(x2)      # x1 = mem[x2 + 0]     (lê do endereço em x2)
lw   x1, 4(x2)      # x1 = mem[x2 + 4]     (4 bytes depois)
lw   x1, -4(x2)     # x1 = mem[x2 - 4]     (4 bytes antes)
sw   x3, 12(x2)     # mem[x2 + 12] = x3
```

Isso é muito útil para acessar campos de structs ou elementos de arrays quando você já tem o ponteiro base em um registrador.

---

### Store Word / Load Word: `sw` e `lw`

Operam com 4 bytes (32 bits). São as instruções mais comuns para trabalhar com `int`.

```asm
sw   rs2, offset(rs1)    # mem[rs1 + offset] = rs2   (32 bits)
lw   rd,  offset(rs1)    # rd = mem[rs1 + offset]    (32 bits)
```

O endereço deve ser **alinhado em 4 bytes** (múltiplo de 4). Acessar endereços não alinhados causa comportamento indefinido em hardware, embora o simulador seja mais permissivo.

```asm
addi  x1, x0, 0          # x1 = endereço base = 0x0000
addi  x2, x0, 42         # x2 = valor a guardar

sw    x2, 0(x1)          # mem[0x0000] = 42
sw    x2, 4(x1)          # mem[0x0004] = 42
sw    x2, 8(x1)          # mem[0x0008] = 42

lw    x3, 0(x1)          # x3 = mem[0x0000] = 42
lw    x4, 4(x1)          # x4 = mem[0x0004] = 42
```

---

### Store Halfword / Load Halfword: `sh`, `lh`, `lhu`

Operam com 2 bytes (16 bits). Úteis para `short int`.

```asm
sh   rs2, offset(rs1)    # mem[rs1+offset] = rs2[15:0]   (16 bits baixos)
lh   rd,  offset(rs1)    # rd = sign_extend(mem[rs1+offset][15:0])
lhu  rd,  offset(rs1)    # rd = zero_extend(mem[rs1+offset][15:0])
```

- `lh` estende o bit de sinal para 32 bits: valores de -32768 a 32767
- `lhu` preenche com zeros: valores de 0 a 65535

```asm
addi  x1, x0, 0
addi  x2, x0, 0x1234     # x2 = 0x00001234

sh    x2, 0(x1)           # mem[0x0000..0x0001] = 0x1234
lh    x3, 0(x1)           # x3 = 0x00001234  (sinal estendido, bit 15 = 0)

addi  x4, x0, -1          # x4 = 0xFFFFFFFF
sh    x4, 2(x1)           # mem[0x0002..0x0003] = 0xFFFF
lh    x5, 2(x1)           # x5 = 0xFFFFFFFF  (sinal estendido, bit 15 = 1 → negativo)
lhu   x6, 2(x1)           # x6 = 0x0000FFFF  (zero estendido → 65535)
```

---

### Store Byte / Load Byte: `sb`, `lb`, `lbu`

Operam com 1 byte (8 bits). Úteis para `char` ou dados compactados.

```asm
sb   rs2, offset(rs1)    # mem[rs1+offset] = rs2[7:0]   (8 bits baixos)
lb   rd,  offset(rs1)    # rd = sign_extend(mem[rs1+offset][7:0])
lbu  rd,  offset(rs1)    # rd = zero_extend(mem[rs1+offset][7:0])
```

```asm
addi  x1, x0, 0
addi  x2, x0, 65         # x2 = 65 = ASCII 'A'
sb    x2, 0(x1)           # mem[0x0000] = 0x41 = 65

lbu   x3, 0(x1)           # x3 = 65  (zero estendido, correto para chars)
lb    x3, 0(x1)           # x3 = 65  (bit 7 = 0, não estende sinal aqui)

addi  x4, x0, 200         # x4 = 200 = 0xC8 (bit 7 = 1)
sb    x4, 1(x1)           # mem[0x0001] = 0xC8
lb    x5, 1(x1)           # x5 = 0xFFFFFFC8 = -56  (extensão de sinal!)
lbu   x6, 1(x1)           # x6 = 0x000000C8 = 200  (zero estendido, correto)
```

> **Regra para strings e bytes não negativos:** use sempre `lbu`. Use `lb` apenas quando os bytes representam valores com sinal (como temperaturas em -128..127).

---

## 3. Arrays na memória

Um array de inteiros (words de 4 bytes) é armazenado em posições consecutivas de memória, cada uma separada por 4 bytes.

```
Endereço    Valor
0x0000      arr[0]
0x0004      arr[1]
0x0008      arr[2]
0x000C      arr[3]
0x0010      arr[4]
```

O endereço do elemento `i` é: `base + i * 4`

Como o RISC-V não tem multiplicação (RV32I puro), usamos shift: `i * 4 = i << 2`.

### Padrão de acesso indexado

```asm
# Acessa arr[i], onde:
#   x1 = base do array
#   x2 = índice i
#   x3 = registrador destino

slli  x4, x2, 2          # x4 = i * 4  (offset em bytes)
add   x5, x1, x4         # x5 = base + i*4  (endereço de arr[i])
lw    x3, 0(x5)          # x3 = arr[i]
```

Ou para escrever:
```asm
# arr[i] = valor   (valor em x6)
slli  x4, x2, 2          # x4 = i * 4
add   x5, x1, x4         # x5 = &arr[i]
sw    x6, 0(x5)          # arr[i] = valor
```

---

## 4. Programa completo — soma de array

```asm
# =============================================================================
# Soma de array — Tutorial 05
# =============================================================================
#
# Inicializa o array [10, 20, 30, 40, 50] na memória de dados e soma os elementos.
#
# Equivalente em C:
#   int arr[5] = {10, 20, 30, 40, 50};
#   int soma = 0;
#   for (int i = 0; i < 5; i++) soma += arr[i];
#
# Registradores:
#   x1 = endereço base do array
#   x2 = número de elementos N = 5
#   x3 = índice i
#   x4 = soma acumulada
#   x5 = endereço do elemento atual
#   x6 = elemento lido da memória (temporário)

.section .text
.global _start
_start:
    # ─── Inicializa o array na dmem ───────────────────────────────────
    addi  x1, x0, 0          # x1 = base = 0x0000

    addi  x10, x0, 10
    sw    x10, 0(x1)         # arr[0] = 10

    addi  x10, x0, 20
    sw    x10, 4(x1)         # arr[1] = 20

    addi  x10, x0, 30
    sw    x10, 8(x1)         # arr[2] = 30

    addi  x10, x0, 40
    sw    x10, 12(x1)        # arr[3] = 40

    addi  x10, x0, 50
    sw    x10, 16(x1)        # arr[4] = 50

    # ─── Loop de soma ─────────────────────────────────────────────────
    addi  x2, x0, 5          # x2 = N = 5
    addi  x3, x0, 0          # x3 = i = 0
    addi  x4, x0, 0          # x4 = soma = 0

loop:
    bge   x3, x2, fim        # se i >= N, termina

    slli  x5, x3, 2          # x5 = i * 4  (offset em bytes)
    add   x5, x1, x5         # x5 = base + i*4  (endereço de arr[i])
    lw    x6, 0(x5)          # x6 = arr[i]

    add   x4, x4, x6         # soma += arr[i]
    addi  x3, x3, 1          # i++

    jal   x0, loop

fim:
    # x4 = 150  (10 + 20 + 30 + 40 + 50)
    jal   x0, fim            # halt
```

```
riscv> run
riscv> reg          ← x4 deve ser 150
riscv> mem 0x0000 5 ← confirma o array na memória
```

---

## 5. Programa com ponteiro (alternativa ao índice)

Em vez de calcular `base + i*4` a cada iteração, você pode manter um **ponteiro** que avança diretamente de 4 em 4:

```asm
# Mesma soma de array, mas com ponteiro em vez de índice
#   x5 = ponteiro (começa em base, avança de 4 em 4)
#   x7 = ponteiro final = base + N*4

    addi  x1, x0, 0          # base = 0x0000
    addi  x2, x0, 5          # N = 5
    addi  x4, x0, 0          # soma = 0
    addi  x5, x1, 0          # ponteiro = base

    slli  x7, x2, 2          # x7 = N * 4 = 20
    add   x7, x1, x7         # x7 = base + N*4 = 0x0014  (ponteiro final)

loop_ptr:
    bge   x5, x7, fim        # se ponteiro >= fim, termina

    lw    x6, 0(x5)          # x6 = *ponteiro
    add   x4, x4, x6         # soma += *ponteiro
    addi  x5, x5, 4          # ponteiro++  (avança 4 bytes = 1 word)

    jal   x0, loop_ptr

fim:
    jal   x0, fim
```

O padrão de ponteiro é ligeiramente mais eficiente porque elimina o `slli` + `add` dentro do loop.

---

## 6. Harvard vs Von Neumann na prática

```bash
# Modo Harvard (padrão) — dmem e imem são memórias separadas
python3 simulator/riscv_sim.py programa.hex

# Modo Von Neumann — uma única memória
python3 simulator/riscv_sim.py programa.hex --vn
```

No modo Harvard:
- O comando `mem` mostra a **dmem** (seus dados, começa zerada)
- O comando `imem` mostra a **imem** (suas instruções)
- `sw` sempre acessa a dmem, independente do endereço

No modo Von Neumann:
- Há apenas uma memória; `mem` e `imem` mostram a mesma região
- Por convenção, use endereços altos para dados (ex: 0x1000+) para não sobrescrever as instruções

Para os tutoriais, usamos sempre o modo Harvard (padrão), que é mais seguro para iniciantes.

---

## 7. Pontos de atenção

**Alinhamento de word (`lw`/`sw`).**
O endereço para `lw` e `sw` deve ser múltiplo de 4. Se usar endereço ímpar ou não múltiplo de 4, o comportamento em hardware real é indefinido (misaligned access). O simulador aceita, mas o hardware não.

**`lh` vs `lhu` — extensão de sinal.**
Se você lê um byte ou halfword com `lb`/`lh` e o bit de sinal está em 1, o resultado em 32 bits será negativo. Use `lbu`/`lhu` para caracteres e valores sem sinal.

**A dmem começa zerada.**
No modo Harvard, a memória de dados começa toda em zero. Você não precisa inicializá-la para usar zeros. Mas se você precisar de valores específicos, deve usar `sw`/`sh`/`sb` para escrevê-los antes de usar.

**Cuidado com sobreposição de array e dados.**
Se você armazena dois arrays na mesma região de memória, garanta que os intervalos de endereços não se sobreponham. Por exemplo: array de 5 words ocupa 20 bytes (0x0000 a 0x0013); o próximo array pode começar em 0x0014.

**`slli` para índice × 4, não × 2.**
Um array de `int` (4 bytes cada) precisa de `slli x, idx, 2` (shift 2 = ×4). Um array de `short` (2 bytes cada) precisaria de `slli x, idx, 1` (shift 1 = ×2). Confundir isso é um erro comum que produz leituras em posições erradas.

---

## 8. Exercício prático

**Enunciado:** Escreva um programa que inicialize um array de 5 elementos onde `arr[i] = i * 2` (o dobro do índice), ou seja: `arr = [0, 2, 4, 6, 8]`. Em seguida, verifique que `arr[3] == 6` e guarde o resultado da verificação (0 ou 1) em `x10`.

**Dicas:**
- Para inicializar, use um loop com contador crescente de 0 a 4
- `arr[i] = i * 2` pode ser calculado com `slli x_val, x_i, 1` (shift 1 = ×2)
- Para o endereço de escrita, `addr = base + i*4`, use `slli x_off, x_i, 2`
- Para verificar `arr[3] == 6`: leia `arr[3]` com `lw` e compare com 6 usando `beq`

**Solução:**

```asm
# =============================================================================
# Inicializa arr[i] = i*2 e verifica arr[3] == 6  — Tutorial 05
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicializa o array ────────────────────────────────────────────
    addi  x1, x0, 0          # x1 = base do array = 0x0000
    addi  x2, x0, 5          # x2 = N = 5
    addi  x3, x0, 0          # x3 = i = 0

init_loop:
    bge   x3, x2, fim_init   # se i >= N, termina

    slli  x4, x3, 1          # x4 = i * 2  (valor = dobro do índice)
    slli  x5, x3, 2          # x5 = i * 4  (offset do endereço)
    add   x5, x1, x5         # x5 = base + i*4  (endereço de arr[i])
    sw    x4, 0(x5)          # arr[i] = i * 2

    addi  x3, x3, 1          # i++
    jal   x0, init_loop

fim_init:
    # ─── Verifica arr[3] == 6 ─────────────────────────────────────────
    lw    x6, 12(x1)         # x6 = arr[3]  (base + 3*4 = base + 12)
    addi  x7, x0, 6          # x7 = 6  (valor esperado)

    beq   x6, x7, verificado  # se arr[3] == 6, correto
    addi  x10, x0, 0          # x10 = 0  (falhou)
    jal   x0, fim

verificado:
    addi  x10, x0, 1          # x10 = 1  (confirmado!)

fim:
    # x10 = 1 (arr[3] == 6 é verdadeiro)
    # Memória: [0, 2, 4, 6, 8] nos endereços 0x00..0x10
    jal   x0, fim            # halt
```

Verifique:
```
riscv> run
riscv> mem 0x0000 5    ← deve mostrar: 0, 2, 4, 6, 8
riscv> reg             ← x10 deve ser 1
```

---

## Próximo tutorial

[Tutorial 06 — Funções e Convenção de Chamada](06_funcoes.md) — aprenda a criar funções reutilizáveis com `jal`/`jalr`, passar argumentos, retornar valores e gerenciar a pilha.

---

## Tutorial anterior

[Tutorial 04 — Laços](04_lacos.md)
