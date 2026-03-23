# Tutorial 04 — Laços (Loops)

**Nível:** ⭐⭐ (básico)
**Tempo estimado:** 50 minutos

---

## Objetivo

Construir estruturas de repetição em assembly RISC-V. Ao final deste tutorial você será capaz de:

- Implementar loops `for` com contador crescente e decrescente
- Implementar loops `while` com condição testada no início
- Implementar loops `do-while` com condição testada no fim
- Escolher entre contador crescente e decrescente dependendo do problema
- Acumular resultados em um loop (somas, produtos, etc.)
- Detectar e evitar os erros mais comuns (loops infinitos, off-by-one)

---

## 1. A anatomia de um loop

Todo loop tem três partes:

1. **Inicialização:** configura as variáveis de controle antes do loop
2. **Condição:** testa se o loop deve continuar ou parar
3. **Corpo:** o que é executado a cada iteração
4. **Atualização:** modifica a variável de controle para a próxima iteração

Em assembly, a condição é sempre implementada por um desvio condicional (branch). O desvio para frente termina o loop, enquanto o `jal` no final do corpo retorna ao início.

```
inicialização

início_do_loop:
    verifica condição → se falsa, salta para fim_do_loop
    corpo do loop
    atualização da variável de controle
    jal x0, início_do_loop    ← volta para início

fim_do_loop:
```

---

## 2. Loop for com contador decrescente

O loop com **contador decrescente** (de N até 1) é geralmente mais simples em assembly porque a condição de parada — "o contador chegou a zero" — é testada com `beq xN, x0, fim`, sem precisar de um segundo registrador de limite.

### C:
```c
for (int i = N; i > 0; i--) {
    // corpo
}
```

### Assembly (padrão contador decrescente):
```asm
    addi  x1, x0, N          # x1 = contador = N

loop:
    beq   x1, x0, fim        # se contador == 0, termina

    # corpo do loop aqui

    addi  x1, x1, -1         # contador--
    jal   x0, loop

fim:
    jal   x0, fim            # halt
```

**Exemplo prático — soma de 1 a 5 com contador decrescente:**

```asm
# Calcula 5 + 4 + 3 + 2 + 1 = 15
# Registradores: x1=contador (5 até 1), x2=soma acumulada

    addi  x1, x0, 5          # x1 = N = 5
    addi  x2, x0, 0          # x2 = soma = 0

loop:
    beq   x1, x0, fim        # se i == 0, termina

    add   x2, x2, x1         # soma += i
    addi  x1, x1, -1         # i--

    jal   x0, loop

fim:
    # x2 = 15
    jal   x0, fim
```

Note que `5 + 4 + 3 + 2 + 1 = 1 + 2 + 3 + 4 + 5 = 15`. O contador decrescente soma em ordem inversa, mas o resultado é o mesmo.

---

## 3. Loop for com contador crescente

O contador crescente é necessário quando a ordem das iterações importa (por exemplo, ao percorrer um array) ou quando você quer somar os índices de 1 a N em ordem natural.

### C:
```c
for (int i = 0; i < N; i++) {
    // corpo
}
```

### Assembly (padrão contador crescente):
```asm
    addi  x1, x0, 0          # x1 = i = 0  (início)
    addi  x2, x0, N          # x2 = N      (limite)

loop:
    bge   x1, x2, fim        # se i >= N, termina

    # corpo do loop aqui

    addi  x1, x1, 1          # i++
    jal   x0, loop

fim:
    jal   x0, fim
```

**Exemplo — contador que armazena cada valor na memória (como counter.s):**

```asm
# Equivalente a: for (int i = 0; i < 5; i++) mem[i] = i;
# Registradores: x1=i, x2=N=5, x3=ponteiro de escrita

    addi  x1, x0, 0          # x1 = i = 0
    addi  x2, x0, 5          # x2 = N = 5
    addi  x3, x0, 0          # x3 = ponteiro = 0x0000

loop:
    bge   x1, x2, fim        # se i >= 5, termina

    sw    x1, 0(x3)          # mem[x3] = i
    addi  x1, x1, 1          # i++
    addi  x3, x3, 4          # ponteiro += 4 bytes

    jal   x0, loop

fim:
    # mem[0..16] contém: 0, 1, 2, 3, 4
    jal   x0, fim
```

---

## 4. Loop while

O loop `while` testa a condição antes de executar o corpo. Se a condição for falsa desde o início, o corpo nunca executa.

### C:
```c
while (condição) {
    // corpo
}
```

### Assembly — mesma estrutura do for:

```asm
início_while:
    # testa condição — salta para fim se falsa
    Bxx  rs1, rs2, fim_while

    # corpo

    jal  x0, início_while    # volta para testar a condição

fim_while:
```

**Exemplo — contar bits 1 em um número (population count):**

```asm
# =============================================================================
# Conta quantos bits 1 existem em x1 (population count)
# Equivalente em C:
#   int conta = 0;
#   while (x != 0) { conta += (x & 1); x >>= 1; }
#
# Registradores:
#   x1 = número (vai sendo deslocado)
#   x2 = contador de bits 1
#   x3 = bit isolado (temporário)

.section .text
.global _start
_start:
    addi  x1, x0, 0b10110101  # x1 = 181 = 0b10110101 (5 bits 1)
    addi  x2, x0, 0           # x2 = conta = 0

while_bits:
    beq   x1, x0, fim_while   # enquanto x1 != 0

    andi  x3, x1, 1           # x3 = bit menos significativo de x1
    add   x2, x2, x3          # conta += bit
    srli  x1, x1, 1           # x1 >>= 1  (descarta o bit lido)

    jal   x0, while_bits

fim_while:
    # x2 = 5  (0b10110101 tem 5 bits 1: posições 0, 2, 4, 5, 7)

fim:
    jal   x0, fim
```

---

## 5. Loop do-while

O loop `do-while` executa o corpo **pelo menos uma vez** e testa a condição no final.

### C:
```c
do {
    // corpo
} while (condição);
```

### Assembly — condição no final:

```asm
início_dowhile:
    # corpo (sempre executa pelo menos uma vez)

    # testa condição — se verdadeira, volta
    Bxx  rs1, rs2, início_dowhile

# continua após o loop
```

**Exemplo — dividir por 2 até chegar a 0 ou 1:**

```asm
# Quantas vezes podemos dividir x1 por 2 antes de chegar a 0?
# Registradores: x1 = valor, x2 = contador de divisões

    addi  x1, x0, 64         # x1 = 64 = 2^6  (esperamos 6 iterações)
    addi  x2, x0, 0          # x2 = contador = 0

inicio_loop:
    srli  x1, x1, 1          # x1 = x1 / 2   (shift right 1)
    addi  x2, x2, 1          # contador++

    bne   x1, x0, inicio_loop  # enquanto x1 != 0, repete

# x2 = 6   (64 → 32 → 16 → 8 → 4 → 2 → 1 → 0, contou 6 shifts até zerar)
fim:
    jal   x0, fim
```

---

## 6. Programa completo — somar de 1 a N

```asm
# =============================================================================
# Soma de 1 a N — Tutorial 04
# =============================================================================
#
# Calcula S = 1 + 2 + 3 + ... + N
#
# Equivalente em C:
#   int soma = 0;
#   for (int i = 1; i <= N; i++) soma += i;
#
# Mapeamento de registradores:
#   x1 = N = 10
#   x2 = i (começa em 1, vai até N)
#   x3 = soma acumulada
#
# Resultado esperado: 1+2+...+10 = 55

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = N = 10
    addi  x2, x0, 1          # x2 = i = 1  (começa em 1, não em 0!)
    addi  x3, x0, 0          # x3 = soma = 0

loop:
    # condição: continua enquanto i <= N  → para quando i > N
    # i > N é equivalente a N < i, ou seja: blt x1, x2, fim
    blt   x1, x2, fim        # se N < i (ou seja, i > N), termina

    add   x3, x3, x2         # soma += i
    addi  x2, x2, 1          # i++

    jal   x0, loop

fim:
    # x3 = 55  (soma de 1 a 10)
    jal   x0, fim            # halt
```

Verifique no simulador:
```
riscv> run
riscv> reg
# x3 deve ser 55
```

A fórmula de Gauss confirma: N*(N+1)/2 = 10*11/2 = 55.

---

## 7. Comparando padrões de loop

| Padrão | Quando usar | Condição de parada |
|---|---|---|
| Decrescente (N até 1) | Quando a ordem não importa | `beq x_cont, x0, fim` |
| Crescente (0 até N-1) | Quando a ordem importa, indexação | `bge x_i, x_N, fim` |
| `while` | Condição avaliada antes; pode executar 0 vezes | branch no início |
| `do-while` | Executa pelo menos 1 vez | branch no fim |

**O loop decrescente é preferível quando possível** porque a condição de parada — comparar com zero — não exige um segundo registrador de limite. Isso poupa um registrador e produz código ligeiramente mais curto.

---

## 8. Pontos de atenção

**Off-by-one (erro de um).**
O erro mais comum em loops. Certifique-se se o loop vai de 0 a N-1 (N iterações) ou de 1 a N (N iterações também, mas diferentes). Se usar `bge x_i, x_N, fim`, o loop roda enquanto `i < N`, ou seja, os valores 0, 1, 2, ..., N-1. Se quiser incluir N, use `blt x_N, x_i, fim` (N < i, ou seja, i > N).

**Loop infinito acidental.**
Se você esquecer de atualizar a variável de controle (ex: esquecer o `addi x1, x1, 1`), o loop nunca termina. O simulador ficará preso; use `Ctrl+C` para interromper. O comando `trace on` seguido de `run` mostra cada instrução executada, facilitando a depuração.

**`jal x0, label` é o goto.**
O `jal x0, label` não salva o endereço de retorno (escreve em x0, que é sempre zero). É um salto incondicional sem retorno — um `goto` puro. Isso é diferente de `jal x1, label` que salva o endereço de retorno para uma chamada de função.

**Breakpoints para depurar loops.**
Se um loop tiver muitas iterações, use o comando `bp` para definir um breakpoint no início do loop e `run` para parar ali. A cada `run` subsequente o simulador para na próxima chegada ao breakpoint.

```
riscv> bp 0x0008          ← coloca breakpoint no início do loop
riscv> run                ← executa até o breakpoint
riscv> reg                ← inspeciona registradores
riscv> run                ← continua para a próxima iteração
```

---

## 9. Exercício prático

**Enunciado:** Escreva um programa que calcule a soma de todos os números pares de 2 a 20, ou seja, `2 + 4 + 6 + ... + 20 = 110`.

**Dicas:**
- Inicie `i = 2` e incremente `i` de 2 em 2 a cada iteração: `addi x_i, x_i, 2`
- A condição de parada é `i > 20`, ou seja, `blt x20, x_i, fim` onde `x20` contém 20
- Alternativamente, use contador de 1 a 10 e multiplique por 2 com `slli`: `slli x_par, x_i, 1`

**Solução (versão direta, iterando sobre pares):**

```asm
.section .text
.global _start
_start:
    addi  x1, x0, 20         # x1 = limite = 20
    addi  x2, x0, 2          # x2 = i = 2  (primeiro par)
    addi  x3, x0, 0          # x3 = soma = 0

loop:
    blt   x1, x2, fim        # se limite < i (i > 20), termina

    add   x3, x3, x2         # soma += i
    addi  x2, x2, 2          # i += 2  (próximo par)

    jal   x0, loop

fim:
    # x3 = 110
    jal   x0, fim
```

**Verificação:** use `--run` para ver o resultado rapidamente:
```bash
python3 riscv_sim.py exercicio.hex --run
# procure x3 = 110
```

**Desafio extra:** modifique o programa para somar os ímpares de 1 a 19. O resultado deve ser 100.

---

## Próximo tutorial

[Tutorial 05 — Memória: Arrays e Acesso a Dados](05_memoria.md) — aprenda a usar a memória de dados para armazenar e recuperar valores, trabalhar com arrays e entender a diferença entre Harvard e Von Neumann.

---

## Tutorial anterior

[Tutorial 03 — Desvios Condicionais](03_desvios.md)
