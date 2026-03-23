# Programas de Exemplo — RISC-V RV32I

Programas clássicos de algoritmos implementados em assembly RISC-V,
com comentários detalhados em cada instrução.

Equivalem aos exemplos que acompanham o simulador Neander, mas usando a
ISA RISC-V com 32 registradores e 37 instruções.

---

## Compilar e rodar

```bash
# Pré-requisito: compilador RISC-V instalado
# macOS: brew install riscv-gnu-toolchain

cd exemplos/

# Compila todos os exemplos
make hex

# Verifica resultados com o simulador
make verify

# Ou tudo de uma vez
make all
```

---

## Programas disponíveis

### `counter.s` — Contador com loop ⭐ (comece aqui)

O programa mais simples com loop: conta de 0 a 9 e armazena cada valor.

```
Registradores: x2=10 (contador final), x3=40 (ponteiro final)
Memória:       [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
```

**Conceitos:** `bge` para condição de parada, `addi` para incrementar.

---

### `abs_value.s` — Valor absoluto e comparação

Calcula `|x|` e demonstra MIN/MAX de dois valores.

```
Entrada:  x1 = -15
Saída:    x2 = 15  (valor absoluto)
          x12 = 3  (mínimo de 7 e 3)
          x13 = 7  (máximo de 7 e 3)
```

**Conceitos:** `bge`/`blt` para desvio condicional (como JN/JZ do Neander).

---

### `sum_array.s` — Soma de array

Soma um array de 5 elementos usando um ponteiro que avança.

```
Array:  [10, 20, 30, 40, 50]
Saída:  x4 = 150
```

**Conceitos:** ponteiro, `lw` para carregar da memória, loop com contador.

---

### `max_array.s` — Máximo de array

Percorre um array e encontra o maior valor.

```
Array:  [3, 17, 8, 42, 11]
Saída:  x4 = 42
```

**Conceitos:** acesso indexado (`slli` para multiplicar índice por 4), comparação.

---

### `fibonacci.s` — Sequência de Fibonacci

Calcula os primeiros 8 termos da sequência e armazena na memória.

```
Saída em memória: [0, 1, 1, 2, 3, 5, 8, 13]
```

**Conceitos:** dois registradores "deslizantes" (F(i-2) e F(i-1)), `sw`.

---

### `factorial.s` — Fatorial iterativo

Calcula N! usando multiplicação implementada via somas repetidas
(RV32I não tem instrução `mul` — isso faz parte da extensão M).

```
Entrada:  x1 = 5
Saída:    x2 = 120  (5! = 120)
```

**Conceitos:** loop duplo (loop principal + sub-loop de multiplicação).

---

### `bubblesort.s` — Bubble Sort

Ordena 7 elementos em ordem crescente usando troca de adjacentes.

```
Antes:  [64, 34, 25, 12, 22, 11, 90]
Depois: [11, 12, 22, 25, 34, 64, 90]
```

**Conceitos:** loop duplo, `slli` para indexação, swap de valores em memória.

---

### `gcd.s` — MDC (Máximo Divisor Comum)

Calcula o MDC de dois números usando o algoritmo de Euclides por subtrações
repetidas (sem divisão — compatível com RV32I puro).

```
Entrada:  x1 = 48, x2 = 18
Saída:    x1 = 6,  x2 = 6  (MDC(48,18) = 6)
```

**Conceitos:** desvios condicionais aninhados (`beq`, `blt`), subtração
iterativa, dois valores que convergem para o mesmo resultado.

---

### `power.s` — Potência (base^expoente)

Calcula base^expoente usando multiplicação por somas repetidas.
Como RV32I não tem `mul`, o produto é feito com um sub-loop de adições.

```
Entrada:  x1 = 2, x2 = 10
Saída:    x3 = 1024  (2^10 = 1024)
```

**Conceitos:** loop duplo (externo para o expoente, interno para a
multiplicação manual), acumulador iniciado em 1.

---

### `strlen.s` — Comprimento de String

Armazena "RISC-V\0" byte a byte na dmem com `sb` e conta os caracteres
até encontrar o terminador nulo.

```
String: "RISC-V\0" em dmem[0]
Saída:  x2 = 6  (comprimento de "RISC-V")
```

**Conceitos:** `sb`/`lbu` para acesso a bytes individuais, laço com
condição de parada em byte nulo.

---

### `binary_search.s` — Busca Binária

Armazena um array de 10 inteiros ordenados e busca o valor 23
usando busca binária com divisão inteira via `srl`.

```
Array:  [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
Alvo:   23
Saída:  x3 = 5 (índice), x4 = 1 (encontrado)
```

**Conceitos:** busca binária, `srli` para divisão por 2, acesso indexado
`base + mid*4`, flag de resultado.

---

### `selection_sort.s` — Selection Sort

Ordena 6 elementos encontrando o mínimo de cada subarray e colocando-o
na posição correta.

```
Antes:  [5, 2, 8, 1, 9, 3]
Depois: [1, 2, 3, 5, 8, 9]
```

**Conceitos:** loop duplo com j iniciando em i+1, rastreamento de índice
e valor mínimo, troca condicional (só quando min_idx ≠ i).

---

## Inspecionando com o simulador

Cada programa pode ser executado passo a passo:

```bash
python3 ../simulator/riscv_sim.py counter.hex
```

```
riscv> step              # executa 1 instrução
riscv> step 5            # executa 5 instruções
riscv> run               # executa até o final
riscv> reg               # mostra todos os registradores
riscv> mem 0x0000 10     # mostra 10 words de dados
riscv> imem 0x0000       # mostra as instruções com desmontagem
riscv> reset             # volta ao início
```

---

## Entendendo o "halt"

Todo programa termina com:
```asm
fim:
    jal x0, fim    # halt — salta para si mesmo infinitamente
```

Isso é equivalente ao `HLT` do Neander. O simulador detecta automaticamente
quando o PC não avança (salta para o mesmo endereço) e para a execução.

---

## Memória de dados vs instruções

Em modo **Harvard** (padrão), instruções e dados ficam em memórias separadas:
- As instruções são carregadas na `imem`
- Os dados (`sw`/`lw`) acessam a `dmem` (começa zerada)

No simulador, o comando `mem` mostra a **dmem** e `imem` mostra as instruções.

---

## Dificuldade progressiva

| Programa | Conceitos novos | Linhas |
|---|---|---|
| `counter.s`         | loop, bge                            | ~20 |
| `abs_value.s`       | if/else, bge/blt                     | ~35 |
| `sum_array.s`       | array, lw/sw, ponteiro               | ~40 |
| `max_array.s`       | indexação, slli                      | ~45 |
| `fibonacci.s`       | dois acumuladores                    | ~35 |
| `factorial.s`       | loop duplo, mult manual              | ~45 |
| `gcd.s`             | convergência por subtração           | ~30 |
| `strlen.s`          | sb/lbu, terminador nulo              | ~50 |
| `power.s`           | loop duplo, mult via somas           | ~50 |
| `bubblesort.s`      | loop duplo, swap                     | ~65 |
| `binary_search.s`   | busca binária, srli, flag resultado  | ~75 |
| `selection_sort.s`  | seleção de mínimo, troca condicional | ~75 |

---

## De C para assembly

Se você conhece C e quer entender o que o compilador faz, o guia
[`c_para_riscv.md`](c_para_riscv.md) mostra como quatro padrões C comuns se
traduzem instrução a instrução para RISC-V:

- **Aritmética simples** — `+`, `-`, `*` via somas repetidas, `/` via subtrações repetidas
- **if/else** — inversão da condição, branch para else, label de junção
- **For loop com array** — `slli i, i, 2` para `i*4`, `lw` com endereço calculado
- **Chamada de função** — `jal ra, func`, passagem por `a0`, retorno com `jalr x0, ra, 0`

Também inclui uma tabela de referência rápida mapeando cada construção C para a
instrução (ou padrão de instruções) correspondente em RISC-V.
