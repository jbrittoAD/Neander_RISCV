# De C para RISC-V — Tradução de Padrões Comuns

**Tipo:** Referência de mapeamento C → Assembly
**Público:** Alunos que conhecem C e querem entender o que o compilador faz
**Objetivo:** Ver como construções C conhecidas viram sequências de instruções RISC-V

---

Compiladores como GCC com `-O0` (sem otimizações) produzem código muito próximo
do que é mostrado aqui. Entender essa tradução é a chave para ler código
desmontado, escrever assembly mais confiante, e depurar comportamentos inesperados.

---

## Padrão 1: Aritmética simples

### Código em C

```c
int a = 10, b = 7;
int c = a + b;        // 17
int d = a - b;        // 3
int e = a * b;        // 70  — multiplicação via soma repetida (RV32I não tem mul)
int f = a / b;        // 1   — divisão inteira via subtração repetida (RV32I não tem div)
```

### Código em RISC-V

```asm
.section .text
.global _start
_start:
    # ─── Declarações: int a = 10, b = 7 ──────────────────────────────────
    addi  x1, x0, 10         # x1 = a = 10
    addi  x2, x0, 7          # x2 = b = 7

    # ─── int c = a + b ───────────────────────────────────────────────────
    add   x3, x1, x2         # x3 = c = a + b = 17

    # ─── int d = a - b ───────────────────────────────────────────────────
    sub   x4, x1, x2         # x4 = d = a - b = 3

    # ─── int e = a * b — multiplicação via soma repetida ─────────────────
    # RV32I não tem instrução mul (pertence à extensão M).
    # Compilamos: e = a + a + a + ... (b vezes)
    addi  x5, x0, 0          # x5 = e = 0 (acumulador)
    addi  x6, x0, 0          # x6 = contador = 0

loop_mul:
    bge   x6, x2, fim_mul    # se contador >= b, termina
    add   x5, x5, x1         # e += a
    addi  x6, x6, 1          # contador++
    jal   x0, loop_mul

fim_mul:
    # x5 = e = 70

    # ─── int f = a / b — divisão inteira via subtração repetida ──────────
    # RV32I não tem instrução div (também extensão M).
    # Compilamos: conta quantas vezes b cabe em a
    addi  x7, x1, 0          # x7 = cópia de a (para não destruir x1)
    addi  x8, x0, 0          # x8 = f = 0 (quociente)

loop_div:
    blt   x7, x2, fim_div    # se restante < b, termina
    sub   x7, x7, x2         # restante -= b
    addi  x8, x8, 1          # quociente++
    jal   x0, loop_div

fim_div:
    # x8 = f = 1  (10 / 7 = 1, restante = 3)

fim:
    jal   x0, fim            # halt
```

### O que o compilador faz

| Operação C | Instrução RISC-V | Notas |
|---|---|---|
| `a + b` | `add rd, rs1, rs2` | direto |
| `a - b` | `sub rd, rs1, rs2` | direto |
| `a * b` | loop de somas | RV32I não tem `mul` |
| `a / b` | loop de subtrações | RV32I não tem `div` |
| `int a = 10` | `addi x1, x0, 10` | constante pequena cabe no imediato de 12 bits |

**Nota importante:** compiladores reais com a extensão M (`-march=rv32im`) emitem
`mul x3, x1, x2` e `div x3, x1, x2` diretamente. Este projeto usa RV32I puro,
portanto multiplicação e divisão precisam de loops. O exemplo `factorial.s` e
`power.s` nos exemplos demonstram isso.

---

## Padrão 2: if/else

### Código em C

```c
int x = 15;
int abs_x;

if (x >= 0) {
    abs_x = x;
} else {
    abs_x = -x;   // sub abs_x, zero, x
}
```

### Código em RISC-V

```asm
.section .text
.global _start
_start:
    addi  x1, x0, 15         # x1 = x = 15
                              # (troque por -15 para testar o else)

    # ─── if (x >= 0) ─────────────────────────────────────────────────────
    # Estratégia: teste a condição INVERSA para pular para o else.
    # "Se x < 0, vá para else_branch"
    blt   x1, x0, else_branch # se x < 0 → vai para else

then_branch:                  # bloco then (x >= 0)
    addi  x2, x1, 0          # x2 = abs_x = x
    jal   x0, fim_if          # pula sobre o else

else_branch:                  # bloco else (x < 0)
    sub   x2, x0, x1         # x2 = abs_x = 0 - x = -x

fim_if:                       # ponto de junção — execução continua aqui
    # x2 = abs_x = 15

fim:
    jal   x0, fim
```

### O que o compilador faz

O padrão é sempre o mesmo para `if/else`:

```
1. Avalie a condição do if
2. Emita um branch com a condição INVERTIDA → salta para else_branch
3. Corpo do then
4. jal x0, fim_if  (pula o else)
5. else_branch: corpo do else
6. fim_if: continuação
```

A inversão acontece porque o branch em assembly é "se verdade, pula". O compilador
pensa: "se a condição do if NÃO for verdadeira, pulo para o else".

**Tabela de inversão de condições:**

| Condição C | Branch em assembly (para pular para else) |
|---|---|
| `x >= 0` | `blt x, zero, else` |
| `x < 0` | `bge x, zero, else` |
| `a == b` | `bne a, b, else` |
| `a != b` | `beq a, b, else` |
| `a < b` | `bge a, b, else` |
| `a >= b` | `blt a, b, else` |

Para um `if` sem `else`, o mesmo vale — só não há bloco else, e o `jal x0, fim_if`
logo após o then é desnecessário (a execução cai diretamente em `fim_if`).

```asm
    # if (a == b) { x = 1; }  ← sem else
    bne   x1, x2, fim_if     # condição invertida: se a != b, pula tudo
    addi  x3, x0, 1          # x = 1
fim_if:
    # continua
```

O exemplo `abs_value.s` nos exemplos demonstra este padrão de forma completa.

---

## Padrão 3: For loop com array

### Código em C

```c
int arr[5] = {10, 20, 30, 40, 50};
int sum = 0;

for (int i = 0; i < 5; i++) {
    sum += arr[i];
}
// sum == 150
```

### Código em RISC-V

```asm
.section .text
.global _start
_start:
    # ─── int arr[5] = {10, 20, 30, 40, 50} ──────────────────────────────
    # Em C, o compilador coloca arrays inicializados em .data.
    # Em assembly bare-metal (sem SO), inicializamos com sw na dmem.
    # arr[i] está em dmem[base + i*4].
    # Usamos base = 0 (dmem começa no endereço 0).

    addi  x1, x0, 0           # x1 = base do array (endereço 0 da dmem)

    addi  x10, x0, 10
    sw    x10, 0(x1)          # arr[0] = 10  (endereço 0x0000)

    addi  x10, x0, 20
    sw    x10, 4(x1)          # arr[1] = 20  (endereço 0x0004)

    addi  x10, x0, 30
    sw    x10, 8(x1)          # arr[2] = 30  (endereço 0x0008)

    addi  x10, x0, 40
    sw    x10, 12(x1)         # arr[3] = 40  (endereço 0x000C)

    addi  x10, x0, 50
    sw    x10, 16(x1)         # arr[4] = 50  (endereço 0x0010)
    # 5 elementos × 4 bytes = 20 bytes usados (0x0000–0x0013)

    # ─── int sum = 0; int i = 0 ──────────────────────────────────────────
    addi  x2, x0, 0           # x2 = sum = 0
    addi  x3, x0, 0           # x3 = i = 0
    addi  x4, x0, 5           # x4 = N = 5 (limite do loop)

    # ─── for (int i = 0; i < 5; i++) ─────────────────────────────────────
    # Estrutura:
    #   1. Testa condição de saída (i >= N → sai)
    #   2. Calcula arr[i]: endereço = base + i*4
    #   3. Carrega arr[i] com lw
    #   4. sum += arr[i]
    #   5. i++
    #   6. volta ao passo 1

loop:
    bge   x3, x4, fim         # se i >= N (i >= 5), sai do loop
                              # equivale a: if !(i < 5) goto fim

    # ─── arr[i]: calcula endereço = base + i * 4 ─────────────────────────
    slli  x5, x3, 2           # x5 = i * 4  (slli por 2 = × 4)
                              # i=0 → x5=0, i=1 → x5=4, i=2 → x5=8 ...
    add   x5, x1, x5          # x5 = base + i*4 = endereço de arr[i]
    lw    x6, 0(x5)           # x6 = arr[i]

    # ─── sum += arr[i] ───────────────────────────────────────────────────
    add   x2, x2, x6          # sum = sum + arr[i]

    # ─── i++ ─────────────────────────────────────────────────────────────
    addi  x3, x3, 1           # i++

    jal   x0, loop            # volta ao início do for

fim:
    # x2 = sum = 150
    jal   x0, fim
```

### O que o compilador faz

**Inicialização do array:** em C, `int arr[5] = {10, 20, 30, 40, 50}` faz o
compilador emitir os valores no segmento `.data`. Em bare-metal, fazemos
isso manualmente com `sw`. Os 5 inteiros ocupam 5 × 4 = **20 bytes** de dmem,
nos endereços `base + 0` até `base + 16`.

**O loop for:** o compilador traduz `for (init; cond; incr) { corpo }` para:

```
init
topo:
    if !cond → goto fim
    corpo
    incr
    goto topo
fim:
```

**A linha `slli x5, x3, 2`:** esta é *exatamente* a instrução que GCC emite para
indexação de array `int`. Deslocar um índice 2 bits à esquerda multiplica por 4
(tamanho de um `int`). Para `short` (2 bytes) seria `slli x5, x3, 1`; para
`long long` (8 bytes) seria `slli x5, x3, 3`.

O exemplo `sum_array.s` nos exemplos mostra uma variação deste padrão usando um
ponteiro que avança em vez de índice + `slli`.

---

## Padrão 4: Chamada de função

### Código em C

```c
int dobra(int n) {
    return n + n;
}

int main() {
    int r = dobra(21);   // r = 42
    return r;
}
```

### Código em RISC-V

```asm
.section .text
.global _start
_start:
    # ─── Prologue: inicializa o stack pointer ────────────────────────────
    addi  sp, x0, 0x400       # sp = 0x400 = topo da pilha
                              # (necessário se a função chamada usar a pilha)

    # ─── int r = dobra(21) ───────────────────────────────────────────────
    # Convenção de chamada RISC-V:
    #   Argumentos: a0 (x10), a1 (x11), ..., a7 (x17)
    #   Retorno:    a0 (x10)

    addi  a0, x0, 21          # a0 = primeiro argumento = 21
                              # equivale a: n = 21

    jal   ra, dobra           # chama dobra(21)
                              # ra = endereço da instrução seguinte (o jal abaixo)
                              # PC = endereço de dobra

    # ─── após retorno: a0 contém o valor retornado ───────────────────────
    # a0 = 42  (valor retornado por dobra)
    # Em C: r = a0

    jal   x0, fim             # equivale a: return r (sai do main)

    # ─── função dobra ────────────────────────────────────────────────────
    # int dobra(int n) { return n + n; }
    #
    # Recebe: a0 = n
    # Retorna: a0 = n + n
dobra:
    add   a0, a0, a0          # a0 = n + n = 42
                              # equivale a: return n + n

    jalr  x0, ra, 0           # retorna para quem chamou
                              # PC = ra (endereço salvo pelo jal ra, dobra)
                              # equivale a: }  (fim da função)

fim:
    # a0 = 42
    jal   x0, fim             # halt
```

### O que o compilador faz

**`jal ra, dobra`** faz duas coisas: salva `PC+4` em `ra` (o endereço da instrução
seguinte — o endereço de retorno) e pula para `dobra`. Quando a função terminar e
executar `jalr x0, ra, 0`, o PC voltará exatamente para a instrução que estava
após o `jal`.

**Passagem de argumentos:** a convenção RISC-V usa os registradores `a0`–`a7`
(x10–x17) para até 8 argumentos. O primeiro argumento vai em `a0`, o segundo em
`a1`, e assim por diante.

**Valor de retorno:** sempre em `a0`. A linha `add a0, a0, a0` faz o dobro e já
coloca o resultado onde o chamador vai procurar.

**`jalr x0, ra, 0`:** o pseudo-código `ret` expande para isso. Salta para o
endereço em `ra`, descartando o endereço de retorno desta instrução (em `x0`).

**Funções que chamam outras funções:** se `dobra` precisasse chamar outra função,
ela precisaria salvar `ra` na pilha antes (veja o Erro 1 em `erros_comuns.md`):

```asm
dobra:
    addi  sp, sp, -4
    sw    ra, 0(sp)       # salva ra antes de chamar outra função
    jal   ra, outra_func
    lw    ra, 0(sp)       # restaura ra
    addi  sp, sp, 4
    jalr  x0, ra, 0       # agora retorna corretamente
```

Funções simples como `dobra` acima — que não chamam nenhuma outra função — são
chamadas de **funções folha** (leaf functions) e não precisam salvar `ra`.

O exemplo `factorial.s` nos exemplos demonstra loop duplo; o tutorial
`06_funcoes.md` cobre a pilha com profundidade.

---

## Resumo: mapeamento de construções C para RISC-V

| Construção C | Padrão RISC-V |
|---|---|
| `int a = 10` | `addi x1, x0, 10` |
| `int a = 5000` | `lui x1, 1` + `addi x1, x1, 904` (>2047 precisa de lui) |
| `c = a + b` | `add x3, x1, x2` |
| `d = a - b` | `sub x4, x1, x2` |
| `e = a & b` | `and x5, x1, x2` |
| `f = a \| b` | `or x6, x1, x2` |
| `g = a ^ b` | `xor x7, x1, x2` |
| `h = ~a` | `xori x8, x1, -1` (NOT via XOR com -1) |
| `i = a << 3` | `slli x9, x1, 3` |
| `j = a >> 3` (signed) | `srai x10, x1, 3` |
| `j = a >> 3` (unsigned) | `srli x10, x1, 3` |
| `if (a < b)` | `bge a, b, else` + corpo + `jal fim` + `else:` |
| `for (i=0; i<N; i++)` | init + `loop: bge i,N,fim` + corpo + `addi i,i,1` + `jal loop` |
| `arr[i]` (int) | `slli t, i, 2` + `add t, base, t` + `lw val, 0(t)` |
| `func(arg)` | `addi a0, x0, arg` + `jal ra, func` |
| `return val` | `addi a0, x0, val` + `jalr x0, ra, 0` |

---

## Compilando C real com GCC para inspecionar

Se você tiver o cross-compiler instalado (`riscv64-unknown-elf-gcc`), pode
compilar C e ver o assembly que GCC produz:

```bash
# Escreva seu programa em exemplo.c, depois:
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -O0 -S exemplo.c -o exemplo.s

# O arquivo exemplo.s contém o assembly gerado pelo compilador
# Procure por padrões como slli, bge, jal ra, que são exatamente os vistos aqui
```

A flag `-O0` desativa otimizações, produzindo código mais verboso e próximo do
que escrevemos manualmente. Com `-O2`, o compilador otimizaria os loops e
eliminaria loads/stores desnecessários, tornando mais difícil ver a correspondência
um-a-um com o C.

---

## Recursos relacionados

- **Exemplos** [`./`](./) — `sum_array.s`, `abs_value.s`, `factorial.s` mostram todos esses padrões em programas completos
- **Tutorial 03** [`../tutoriais/03_desvios.md`](../tutoriais/03_desvios.md) — if/else e desvios condicionais em detalhe
- **Tutorial 04** [`../tutoriais/04_lacos.md`](../tutoriais/04_lacos.md) — loops for/while
- **Tutorial 05** [`../tutoriais/05_memoria.md`](../tutoriais/05_memoria.md) — arrays, `lw`/`sw`, `slli` para indexação
- **Tutorial 06** [`../tutoriais/06_funcoes.md`](../tutoriais/06_funcoes.md) — chamadas de função, `jal`/`jalr`, pilha
- **Erros comuns** [`../tutoriais/erros_comuns.md`](../tutoriais/erros_comuns.md) — armadilhas frequentes na tradução C → assembly
