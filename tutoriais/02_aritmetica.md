# Tutorial 02 — Aritmética e Operações Lógicas

**Nível:** ⭐⭐ (básico)
**Tempo estimado:** 45 minutos

---

## Objetivo

Dominar todas as operações aritméticas e lógicas do RISC-V RV32I. Ao final deste tutorial você será capaz de:

- Usar todas as instruções R-type e I-type: `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` e suas variantes com imediato
- Entender a diferença entre operações com sinal (`slt`) e sem sinal (`sltu`)
- Representar qualquer constante de 32 bits usando `lui` + `addi`
- Implementar expressões aritméticas complexas com os registradores como variáveis

---

## 1. Tipos de instruções aritméticas

O RISC-V separa as operações em dois grupos:

- **R-type** (Register): operação entre dois registradores. Exemplo: `add x3, x1, x2`
- **I-type** (Immediate): operação entre um registrador e uma constante. Exemplo: `addi x1, x0, 5`

Para cada operação R-type existe geralmente uma variante I-type com sufixo `i`.

---

## 2. Soma e subtração

### `add` / `addi`

```asm
add   rd, rs1, rs2       # rd = rs1 + rs2
addi  rd, rs1, imm       # rd = rs1 + imm    (imm: -2048 a 2047)
```

Exemplos:
```asm
addi  x1, x0, 20         # x1 = 20
addi  x2, x0, 7          # x2 = 7
add   x3, x1, x2         # x3 = 27
addi  x4, x3, -5         # x4 = 22
```

### `sub`

Subtração existe apenas na forma R-type (sem `subi`). Para subtrair uma constante, use `addi` com valor negativo:

```asm
sub   rd, rs1, rs2       # rd = rs1 - rs2

# Para "subtrai 5 de x1":
addi  x1, x1, -5         # x1 = x1 - 5  (addi com imediato negativo)
```

---

## 3. Operações lógicas bit a bit

O RISC-V implementa AND, OR e XOR bit a bit, tanto entre registradores quanto com imediato.

### `and` / `andi`

```asm
and   rd, rs1, rs2       # rd = rs1 & rs2   (AND bit a bit)
andi  rd, rs1, imm       # rd = rs1 & imm
```

Uso típico: **mascarar bits** (zerar certos bits preservando outros).

```asm
addi  x1, x0, 0xFF       # x1 = 0b11111111 = 255
addi  x2, x0, 0x0F       # x2 = 0b00001111 = 15
and   x3, x1, x2         # x3 = 0b00001111 = 15  (mantém só os 4 bits baixos)
```

### `or` / `ori`

```asm
or    rd, rs1, rs2       # rd = rs1 | rs2   (OR bit a bit)
ori   rd, rs1, imm       # rd = rs1 | imm
```

Uso típico: **ligar bits** sem afetar os outros.

```asm
addi  x1, x0, 0b1010     # x1 = 10
addi  x2, x0, 0b0101     # x2 = 5
or    x3, x1, x2         # x3 = 0b1111 = 15
```

### `xor` / `xori`

```asm
xor   rd, rs1, rs2       # rd = rs1 ^ rs2   (XOR bit a bit)
xori  rd, rs1, imm       # rd = rs1 ^ imm
```

Uso típico: **inverter bits** específicos ou verificar se dois valores são iguais (se `xor` der 0, são iguais).

```asm
addi  x1, x0, 0b1100     # x1 = 12
addi  x2, x0, 0b1010     # x2 = 10
xor   x3, x1, x2         # x3 = 0b0110 = 6  (bits que diferem ficam 1)

# Truque: xori com -1 inverte todos os bits (NOT)
xori  x4, x1, -1         # x4 = ~x1 = NOT x1
```

---

## 4. Deslocamentos (shifts)

Deslocar bits é equivalente a multiplicar ou dividir por potências de 2 — e é muito mais rápido.

### `sll` / `slli` — deslocamento lógico à esquerda

```asm
sll   rd, rs1, rs2       # rd = rs1 << rs2   (preenche com 0s à direita)
slli  rd, rs1, shamt     # rd = rs1 << shamt
```

Deslocar 1 bit à esquerda = multiplicar por 2. Deslocar N bits = multiplicar por 2^N.

```asm
addi  x1, x0, 1          # x1 = 1
slli  x2, x1, 3          # x2 = 1 << 3 = 8   (1 * 2^3)
slli  x3, x1, 5          # x3 = 32
addi  x4, x0, 5
slli  x5, x4, 2          # x5 = 5 * 4 = 20
```

Este é o truque usado em todos os exemplos para converter um índice de array em um offset de bytes: `slli x, idx, 2` equivale a `idx * 4`.

### `srl` / `srli` — deslocamento lógico à direita

```asm
srl   rd, rs1, rs2       # rd = rs1 >> rs2   (preenche com 0s à esquerda)
srli  rd, rs1, shamt     # rd = rs1 >> shamt
```

Deslocar 1 bit à direita = divisão inteira por 2 (para números sem sinal).

```asm
addi  x1, x0, 32         # x1 = 32
srli  x2, x1, 2          # x2 = 32 >> 2 = 8   (32 / 4)
```

### `sra` / `srai` — deslocamento aritmético à direita

```asm
sra   rd, rs1, rs2       # rd = rs1 >> rs2   (preserva o bit de sinal)
srai  rd, rs1, shamt     # rd = rs1 >> shamt  (com extensão de sinal)
```

A diferença crucial: `srl` preenche com **0s** à esquerda, enquanto `sra` preenche com o **bit de sinal** (o bit mais significativo). Para números negativos (complemento de 2), `sra` implementa divisão por 2 com truncamento correto.

```asm
addi  x1, x0, -8         # x1 = -8  (0xFFFFFFF8 em complemento de 2)
srai  x2, x1, 1          # x2 = -4  (divisão por 2, sinal preservado)
srli  x3, x1, 1          # x3 = 0x7FFFFFFC = 2147483644  (ERRADO para números negativos!)
```

> **Regra prática:** use `sra`/`srai` para números com sinal (int), use `srl`/`srli` para números sem sinal (unsigned int).

---

## 5. Comparações — `slt` e `sltu`

O RISC-V não tem instrução de subtração que atualize flags como no x86. A forma de comparar é usando `slt` (Set Less Than), que escreve 1 ou 0 no registrador destino.

### `slt` / `slti` — comparação com sinal

```asm
slt   rd, rs1, rs2       # rd = (rs1 < rs2) ? 1 : 0  (comparação com sinal)
slti  rd, rs1, imm       # rd = (rs1 < imm) ? 1 : 0
```

```asm
addi  x1, x0, 5
addi  x2, x0, 10
slt   x3, x1, x2         # x3 = 1  (5 < 10 é verdadeiro)
slt   x4, x2, x1         # x4 = 0  (10 < 5 é falso)

addi  x5, x0, -3
slt   x6, x5, x1         # x6 = 1  (-3 < 5 com sinal: correto)
```

### `sltu` / `sltiu` — comparação sem sinal

```asm
sltu  rd, rs1, rs2       # rd = (rs1 < rs2) ? 1 : 0  (comparação sem sinal)
sltiu rd, rs1, imm       # rd = (rs1 < imm) ? 1 : 0
```

A diferença aparece com números negativos, pois em complemento de 2 `-1` é `0xFFFFFFFF` — o maior número sem sinal possível:

```asm
addi  x1, x0, -1         # x1 = 0xFFFFFFFF (-1 com sinal, 4294967295 sem sinal)
addi  x2, x0, 1          # x2 = 1
slt   x3, x2, x1         # x3 = 1  (com sinal: 1 < -1? Não! Mas slt diz sim? ERRADO)
# Veja: slt x3, x2, x1 = (1 < -1 com sinal?) = 0
sltu  x4, x2, x1         # x4 = 1  (sem sinal: 1 < 4294967295? Sim!)
```

> **Regra:** use `slt` para `int` (com sinal), use `sltu` para `unsigned int`.

---

## 6. Constantes grandes com `lui` + `addi`

O campo imediato de `addi` tem apenas 12 bits: aceita valores de -2048 a 2047. Como carregar um valor maior, como `0x12345678`?

A solução usa duas instruções:

1. **`lui`** (Load Upper Immediate) — carrega os 20 bits superiores de uma constante
2. **`addi`** — soma os 12 bits inferiores

```
lui   rd, imm20          # rd = imm20 << 12   (shift left 12)
addi  rd, rd, imm12      # rd = rd + imm12
```

Exemplo — carregar `0x12345678`:

```asm
lui   x1, 0x12345        # x1 = 0x12345000   (bits [31:12] = 0x12345)
addi  x1, x1, 0x678      # x1 = 0x12345000 + 0x678 = 0x12345678
```

**Cuidado com extensão de sinal!** O imediato de 12 bits é estendido com sinal. Se o 12° bit for 1 (ou seja, se `imm12 >= 0x800`), o valor adicionado é negativo, e você precisa compensar incrementando o `lui` em 1.

Exemplo — carregar `0x00001ABC` onde `0xABC = 2748 > 2047`:

```asm
# 0x00001ABC = 0x00001000 + 0xABC
# Mas 0xABC como 12 bits com sinal = -1348 (bit 11 é 1)
# Então: lui com 0x2 (compensado), addi com 0xABC
lui   x1, 0x2            # x1 = 0x00002000
addi  x1, x1, 0xABC      # addi interpreta 0xABC como -1348  →  0x00002000 - 1348 = 0x1ABC ✓

# Ou, mais simplesmente: o assembler calcula isso para você com %hi/%lo
lui   x1, %hi(0x00001ABC)
addi  x1, x1, %lo(0x00001ABC)
```

Na prática, quando você escreve uma constante grande em um programa, o assembler GNU calcula `%hi` e `%lo` automaticamente.

### `auipc` — Add Upper Immediate to PC

```asm
auipc  rd, imm20         # rd = PC + (imm20 << 12)
```

Usada para construir endereços relativos ao PC (posição do programa na memória). Por enquanto, não se preocupe com ela — é mais relevante em programas grandes ou relocáveis.

---

## 7. Programa exemplo — calculadora

Este programa demonstra várias operações juntas:

```asm
# =============================================================================
# Calculadora — Operações Aritméticas e Lógicas — Tutorial 02
# =============================================================================
#
# Demonstra: add, sub, and, or, xor, slli, srli, slt
#
# Mapeamento:
#   x1 = A = 60  (0b00111100)
#   x2 = B = 13  (0b00001101)
#   x3 = A + B
#   x4 = A - B
#   x5 = A & B   (AND)
#   x6 = A | B   (OR)
#   x7 = A ^ B   (XOR)
#   x8 = A << 2  (A * 4)
#   x9 = A >> 2  (A / 4)
#   x10 = (A < B) ? 1 : 0

.section .text
.global _start
_start:
    addi  x1, x0, 60         # x1 = A = 60  (0b00111100)
    addi  x2, x0, 13         # x2 = B = 13  (0b00001101)

    add   x3, x1, x2         # x3 = 60 + 13 = 73
    sub   x4, x1, x2         # x4 = 60 - 13 = 47
    and   x5, x1, x2         # x5 = 0b00001100 = 12   (bits comuns)
    or    x6, x1, x2         # x6 = 0b00111101 = 61   (união)
    xor   x7, x1, x2         # x7 = 0b00110001 = 49   (bits diferentes)
    slli  x8, x1, 2          # x8 = 60 * 4 = 240
    srli  x9, x1, 2          # x9 = 60 / 4 = 15
    slt   x10, x1, x2        # x10 = (60 < 13)? = 0

fim:
    jal   x0, fim            # halt
```

Para verificar:
```
riscv> run
riscv> reg
# Esperado:
#   x1 = 60, x2 = 13
#   x3 = 73, x4 = 47
#   x5 = 12, x6 = 61, x7 = 49
#   x8 = 240, x9 = 15
#   x10 = 0
```

---

## 8. Pontos de atenção

**Não existe `subi`.**
Para subtrair uma constante, use `addi` com valor negativo: `addi x1, x1, -5` subtrai 5 de x1.

**`xori x, x, -1` é o NOT.**
O RISC-V não tem instrução NOT. O truque é fazer XOR com -1 (todos os bits 1): inverte todos os bits.

**`sra` vs `srl` — cuidado com negativos.**
Deslocar um número negativo para a direita com `srl` produz um resultado sem sentido para aritmética com sinal. Sempre use `sra` quando trabalhar com `int`.

**Overflow é silencioso.**
O RISC-V não tem flag de overflow como o x86. Se você somar dois números grandes e o resultado ultrapassar 32 bits, o excesso é simplesmente descartado — nenhuma exceção é lançada. Em programas reais, você precisa verificar overflow manualmente se necessário.

**O campo `shamt` tem 5 bits.**
O deslocamento em `slli`/`srli`/`srai` vai de 0 a 31. Não faz sentido deslocar 32 bits ou mais em um registrador de 32 bits.

---

## 9. Exercício prático

**Enunciado:** Dados os valores `a`, `b` e `c`, calcule a expressão `(a + b) * 2 - c` usando apenas as instruções `add`, `sub` e `slli`. Use `a=7`, `b=3`, `c=5`. O resultado esperado é `(7+3)*2-5 = 15`.

**Dicas:**
- Multiplicar por 2 é equivalente a deslocar 1 bit para a esquerda: `slli rd, rs, 1`
- Você não pode fazer as operações em uma única instrução — use registradores intermediários
- Pense como um compilador: quebre a expressão em passos simples

**Solução:**

```asm
.section .text
.global _start
_start:
    addi  x1, x0, 7          # x1 = a = 7
    addi  x2, x0, 3          # x2 = b = 3
    addi  x3, x0, 5          # x3 = c = 5

    add   x4, x1, x2         # x4 = a + b = 10
    slli  x5, x4, 1          # x5 = (a + b) * 2 = 20    (shift left 1 = x2)
    sub   x6, x5, x3         # x6 = (a+b)*2 - c = 15

fim:
    jal   x0, fim            # halt
# Verificar: x6 deve ser 15
```

**Variação:** tente calcular `(a + b) * 4` usando um único `slli` com `shamt=2`.

---

## Próximo tutorial

[Tutorial 03 — Desvios Condicionais](03_desvios.md) — aprenda a implementar `if/else` em assembly com as instruções de branch: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`.

---

## Tutorial anterior

[Tutorial 01 — Olá, Mundo em Assembly RISC-V](01_ola_mundo.md)
