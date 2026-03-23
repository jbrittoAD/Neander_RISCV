# Tutorial 03 — Desvios Condicionais

**Nível:** ⭐⭐ (básico)
**Tempo estimado:** 45 minutos

---

## Objetivo

Implementar estruturas condicionais em assembly RISC-V. Ao final deste tutorial você será capaz de:

- Usar as seis instruções de branch: `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`
- Traduzir um `if/else` em C para assembly passo a passo
- Entender a diferença entre desvios com sinal e sem sinal
- Distinguir desvios para frente (pular código) de desvios para trás (repetir código)
- Comparar com as instruções `JN` e `JZ` do Neander

---

## 1. O que é um desvio condicional?

Em um processador, as instruções são executadas em sequência: endereço 0, 4, 8, 12... O **desvio condicional** altera o fluxo do programa: se uma condição for verdadeira, o PC (contador de programa) salta para outro endereço. Se for falsa, continua na próxima instrução.

```
instrução A
instrução B     ← se condição: salta para instrução E
instrução C     ← só executa se condição for falsa
instrução D
instrução E     ← ponto de destino do desvio
```

### Comparação com o Neander

O Neander tem dois desvios condicionais:
- `JN` (Jump if Negative) — desvia se o acumulador for negativo
- `JZ` (Jump if Zero) — desvia se o acumulador for zero

Ambos testam **o resultado da última operação** via flags de status.

O RISC-V é diferente: os desvios **comparam dois registradores explicitamente** na própria instrução. Não há flags de status. Isso torna o código mais legível e previsível.

---

## 2. As instruções de branch

Todas as instruções de branch têm o mesmo formato:

```
Bxx  rs1, rs2, label
```

Compara `rs1` com `rs2` usando a condição `xx`. Se for verdadeiro, salta para `label`. Se for falso, executa a próxima instrução.

### Tabela completa

| Instrução | Condição | Sinal? | Mnemônico |
|---|---|---|---|
| `beq rs1, rs2, L` | rs1 == rs2 | — | Branch if EQual |
| `bne rs1, rs2, L` | rs1 != rs2 | — | Branch if Not Equal |
| `blt rs1, rs2, L` | rs1 < rs2 | **sim** | Branch if Less Than |
| `bge rs1, rs2, L` | rs1 >= rs2 | **sim** | Branch if Greater or Equal |
| `bltu rs1, rs2, L` | rs1 < rs2 | **não** | Branch if Less Than Unsigned |
| `bgeu rs1, rs2, L` | rs1 >= rs2 | **não** | Branch if Greater or Equal Unsigned |

> **Atenção:** o RISC-V não tem `bgt` (branch if greater than) nem `ble` (branch if less or equal). Mas você pode simular facilmente invertendo os operandos: `bgt x1, x2, L` equivale a `blt x2, x1, L`.

### Por que seis instruções em vez de mais?

`bgt` pode ser simulado por `blt` com operandos trocados. `ble` pode ser simulado por `bge` com operandos trocados. O RISC-V segue o princípio de mínimo de instruções: você pode derivar as outras.

---

## 3. Translação de if/else para assembly

### Padrão geral

Em C:
```c
if (condição) {
    // bloco then
} else {
    // bloco else
}
// continua aqui
```

Em assembly, o padrão é **inverter a condição** para o desvio:

```asm
    # testa a NEGAÇÃO da condição
    Bxx  rs1, rs2, else_label    # se condição for FALSA, salta para else

    # bloco then (executa quando condição é verdadeira)
    ...
    jal  x0, fim_if              # pula o bloco else

else_label:
    # bloco else (executa quando condição é falsa)
    ...

fim_if:
    # continua aqui
```

A lógica parece contrária ao C mas é natural uma vez que você entende: o branch desvia para pular o bloco, então desvia quando a condição é **falsa**.

### Exemplo: if (a == b)

C:
```c
if (a == b) {
    resultado = 1;
} else {
    resultado = 0;
}
```

Assembly (x1=a, x2=b, x3=resultado):
```asm
    beq   x1, x2, sao_iguais    # se a == b, salta para then
    # else: a != b
    addi  x3, x0, 0             # resultado = 0
    jal   x0, fim_if            # pula o then

sao_iguais:
    addi  x3, x0, 1             # resultado = 1

fim_if:
    # x3 tem o resultado
```

---

## 4. Exemplos com cada instrução

### `beq` e `bne` — igualdade

```asm
# Testa se x1 == x2
addi  x1, x0, 42
addi  x2, x0, 42

beq   x1, x2, sao_iguais    # desvia se x1 == x2
# aqui: são diferentes
addi  x3, x0, 0
jal   x0, fim

sao_iguais:
addi  x3, x0, 1             # x3 = 1 (eram iguais)

fim:
jal   x0, fim
```

**Dica:** para testar se um registrador é zero, compare com `x0`:
```asm
beq   x1, x0, é_zero        # se x1 == 0
bne   x1, x0, nao_zero      # se x1 != 0
```

Isso é o equivalente ao `JZ` do Neander.

### `blt` — menor que (com sinal)

```asm
# if (x1 < x2) x3 = x1 else x3 = x2   (mínimo)
addi  x1, x0, 7
addi  x2, x0, 3

blt   x1, x2, x1_menor      # se x1 < x2, salta

# x1 >= x2: mínimo é x2
addi  x3, x2, 0
jal   x0, fim_min

x1_menor:
addi  x3, x1, 0             # mínimo é x1

fim_min:
# x3 = min(7, 3) = 3
```

### `bge` — maior ou igual (com sinal)

```asm
# Equivalente ao JN do Neander (jump if negative):
# se x1 < 0, vai para negativo
bge   x1, x0, nao_negativo  # se x1 >= 0, pula (não é negativo)

negativo:
    # x1 é negativo
    sub   x2, x0, x1         # x2 = |x1| = -x1
    jal   x0, fim

nao_negativo:
    addi  x2, x1, 0          # x2 = x1 (já é positivo)

fim:
    jal   x0, fim
```

---

## 5. Programa exemplo — if/else completo

```asm
# =============================================================================
# Valor absoluto e max/min — Tutorial 03
# =============================================================================
#
# Demonstra desvios condicionais:
# - Valor absoluto: if (x < 0) result = -x; else result = x
# - Máximo: if (a > b) max = a; else max = b
#
# Registradores:
#   x1 = valor de entrada = -15
#   x2 = valor absoluto de x1
#   x10 = A = 7
#   x11 = B = 3
#   x12 = max(A, B)

.section .text
.global _start
_start:

    # ─── Valor absoluto ────────────────────────────────────────────────
    addi  x1, x0, -15        # x1 = -15

    bge   x1, x0, pos        # se x1 >= 0, já é positivo (não precisa inverter)
    sub   x2, x0, x1         # x1 < 0: x2 = 0 - x1 = |-15| = 15
    jal   x0, pos_max

pos:
    addi  x2, x1, 0          # x2 = x1 (cópia)

pos_max:
    # ─── Máximo de dois valores ────────────────────────────────────────
    addi  x10, x0, 7         # A = 7
    addi  x11, x0, 3         # B = 3

    bge   x10, x11, a_maior  # se A >= B, A é o máximo
    addi  x12, x11, 0        # A < B: max = B
    jal   x0, fim

a_maior:
    addi  x12, x10, 0        # max = A

fim:
    # x2 = 15, x12 = 7
    jal   x0, fim            # halt
```

Execute e verifique:
```
riscv> run
riscv> reg
# x2  deve ser 15  (abs(-15))
# x12 deve ser 7   (max(7, 3))
```

---

## 6. Desvios para trás (loops)

Um desvio para **frente** pula código que não deve ser executado (como no if/else acima). Um desvio para **trás** cria um loop, fazendo o processador executar o mesmo bloco repetidamente.

```asm
loop:
    # corpo do loop
    addi  x1, x1, 1          # incrementa contador

    bne   x1, x2, loop       # se x1 != x2, volta para "loop"
    # continua quando x1 == x2
```

O desvio para trás é o tema central do Tutorial 04 (Laços). Por agora, entenda que a instrução `jal x0, label` (salto incondicional) também é um desvio para trás quando `label` é um endereço anterior.

---

## 7. Desvios sem sinal: `bltu` e `bgeu`

Considere o valor `0xFFFFFFFF`. Com sinal, é `-1`. Sem sinal, é `4294967295`.

```asm
addi  x1, x0, -1            # x1 = 0xFFFFFFFF

# Com sinal: -1 < 1 é verdadeiro
blt   x1, x0, negativo      # desvia! (-1 < 0 com sinal = verdadeiro)

# Sem sinal: 4294967295 > 0 é verdadeiro
bltu  x1, x0, menor         # NÃO desvia! (4294967295 < 0 sem sinal = falso)
```

Use `bltu`/`bgeu` quando trabalhar com:
- Endereços de memória (sempre positivos)
- Contadores que vão de 0 até um limite
- Qualquer valor declarado como `unsigned` em C

---

## 8. Pontos de atenção

**A condição do branch é a negação do `if` em C.**
Para implementar `if (a < b)`, use `bge a, b, else_label` (salta para o else quando a condição **não** é verdadeira). Esse padrão "invertido" confunde bastante no começo — escreva o fluxo em papel antes de codificar.

**Não existe `bgt` nem `ble`.**
Use `blt` com operandos trocados para simular `bgt`: `bgt a, b, L` vira `blt b, a, L`. Da mesma forma, `ble a, b, L` vira `bge b, a, L`.

**O offset de branch tem limite.**
O campo imediato de desvio é de 13 bits (com sinal), cobrindo ±4 KB a partir da instrução. Para programas pequenos isso nunca é problema. Em programas grandes, use `jal` para alcançar endereços distantes.

**`bge` inclui a igualdade.**
`bge rs1, rs2, L` desvia se `rs1 >= rs2`. Isso significa que desvia quando `rs1 == rs2` também. Se quiser "estritamente maior que", use `blt rs2, rs1, L` (operandos trocados com `blt`).

---

## 9. Exercício prático

**Enunciado:** Escreva um programa que compare dois valores `x` e `y` armazenados em `x1` e `x2`. Se `x > y`, coloque `x` em `x3`. Caso contrário (se `x <= y`), coloque `y` em `x3`. Use `x=10`, `y=7`. O resultado esperado é `x3 = 10`.

**Dicas:**
- "x > y" pode ser implementado com `blt y, x, label` (y < x é o mesmo que x > y)
- Não se esqueça do `jal x0, fim_if` para pular o bloco else

**Solução:**

```asm
.section .text
.global _start
_start:
    addi  x1, x0, 10         # x = 10
    addi  x2, x0, 7          # y = 7

    # if (x > y) → equivale a: if (y < x) → blt x2, x1, x_maior
    blt   x2, x1, x_maior    # se y < x (ou seja, x > y), salta

    # else: x <= y → resultado = y
    addi  x3, x2, 0          # x3 = y
    jal   x0, fim_if

x_maior:
    addi  x3, x1, 0          # x3 = x

fim_if:
    # x3 = max(x, y) = 10
fim:
    jal   x0, fim            # halt
```

**Teste adicional:** mude os valores para `x=3`, `y=9` e verifique se `x3 = 9`.

---

## Próximo tutorial

[Tutorial 04 — Laços](04_lacos.md) — use desvios para construir loops `for` e `while`, com contadores crescentes e decrescentes.

---

## Tutorial anterior

[Tutorial 02 — Aritmética e Operações Lógicas](02_aritmetica.md)
