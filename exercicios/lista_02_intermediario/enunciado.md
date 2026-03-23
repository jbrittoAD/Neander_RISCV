# Lista 2 — Exercícios Intermediários de Assembly RISC-V

**Nível:** ⭐⭐ Intermediário
**Pré-requisito:** Lista 1 + Tutorial 03 (Desvios) + Tutorial 04 (Laços)

---

## Exercício 6 — Valor absoluto

Escreva um programa que calcule o valor absoluto de um número inteiro.

**Entrada:** `x1 = -42` (carregue com `addi x1, x0, -42`)
**Saída:** `x2 = 42`

**Dica:** Use `bge x1, x0, positivo` para verificar se x1 >= 0.
Para negar: `sub x2, x0, x1` (0 - x1 = -x1).

---

## Exercício 7 — Máximo de dois números (com sinal)

Dados dois valores, armazene o maior em `x3`.

**Entrada:** `x1 = -5`, `x2 = 3`
**Saída:** `x3 = 3`

**Dica:** `blt x1, x2, x1_menor` — se x1 < x2 (com sinal), o maior é x2.

---

## Exercício 8 — Soma de 1 até N

Calcule a soma 1 + 2 + 3 + ... + N usando um loop.

**Entrada:** `x1 = 10` (N = 10)
**Saída:** `x2 = 55` (1+2+...+10 = 55)

**Dica:** Loop com `x3` como contador de 1 até N. Acumula em `x2`.

**Fórmula de verificação:** N*(N+1)/2 = 10*11/2 = 55

---

## Exercício 9 — Contagem de bits 1

Conte quantos bits são 1 no valor `x1 = 0b10110101` (= 181).

**Saída:** `x2 = 5` (os bits 1 estão nas posições 0, 2, 4, 5, 7)

**Algoritmo:**
```
count = 0
while x1 != 0:
    if x1 & 1 == 1:   ← verifica o bit menos significativo
        count++
    x1 >>= 1          ← desloca para verificar o próximo bit
```

**Dica:** `andi x3, x1, 1` isola o bit 0. `srli x1, x1, 1` desloca um bit.

---

## Exercício 10 — Busca linear em array

Dado um array de 5 elementos armazenado na memória de dados, encontre a
posição (índice) do valor 42 no array. Se não encontrar, armazene -1.

**Array em memória (inicialize você mesmo com SW):**
```
mem[0x00] = 10
mem[0x04] = 25
mem[0x08] = 42    ← está aqui! índice = 2
mem[0x0C] = 7
mem[0x10] = 99
```

**Saída:** `x2 = 2` (índice do elemento 42)

**Dica:**
- Use um loop com índice `x3` de 0 a 4
- Calcule endereço: `slli x5, x3, 2` (i*4) depois `add x5, x1, x5`
- Carregue: `lw x6, 0(x5)`
- Compare: `beq x6, x4, achou` onde x4 = 42

---

## Verificação

Compile e teste com o simulador:
```bash
python3 simulator/riscv_sim.py meu_exercicio.hex --run
```

Cada gabarito está em `gabarito/ex06.s` a `gabarito/ex10.s`.

---

**Lista anterior:** [Lista 1 — Básico](../lista_01_basico/enunciado.md)
**Próxima lista:** [Lista 3 — Avançado](../lista_03_avancado/enunciado.md)
