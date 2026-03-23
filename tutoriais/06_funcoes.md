# Tutorial 06 — Funções e Convenção de Chamada

**Nível:** ⭐⭐⭐⭐ (avançado)
**Tempo estimado:** 75 minutos
**Pré-requisito:** Tutoriais 01–05

---

## Objetivo

Implementar funções reutilizáveis em assembly RISC-V. Ao final deste tutorial você será capaz de:

- Usar `jal` para chamar uma função e `jalr` para retornar
- Entender o papel do link register (`ra` / `x1`) no mecanismo de chamada e retorno
- Passar argumentos via `a0`–`a7` e receber valores de retorno via `a0`
- Fazer múltiplas chamadas à mesma função
- Explicar por que funções que chamam outras funções precisam salvar `ra` na pilha
- Usar o stack pointer (`sp` / `x2`) para salvar e restaurar registradores na pilha

---

## 1. O problema da reutilização

Nos tutoriais anteriores, todo código era escrito em linha — nada era reutilizado. Se você precisasse calcular um valor absoluto em dois lugares diferentes do programa, teria que duplicar o código.

**Funções** resolvem isso: você escreve o código uma vez, com um label marcando a entrada, e qualquer parte do programa pode chamar esse código. Após a execução, o controle retorna para quem chamou.

O desafio é: como o código chamado sabe para onde retornar? Em C, o compilador cuida disso. Em assembly, você precisa gerenciar isso explicitamente.

### Comparação com o Neander

No Neander, não existe chamada de função — tudo é código linear com loops e saltos condicionais. O RISC-V adiciona o mecanismo de chamada e retorno com `jal`/`jalr`, que é o que permite construir programas modulares.

---

## 2. `jal` e `jalr`: a base das funções

### `jal` — Jump and Link

```
jal  rd, label
```

Faz duas coisas ao mesmo tempo:
1. Salva o endereço da **próxima instrução** (PC + 4) em `rd`
2. Salta para `label`

Quando você chama uma função, `rd` normalmente é `x1` (também chamado de `ra`, Return Address):

```asm
jal  x1, minha_funcao     # salva endereço de retorno em x1, salta para minha_funcao
```

Quando você quer apenas um salto incondicional sem retorno, usa `x0`:

```asm
jal  x0, label            # salta para label, descarta o endereço (goto)
```

### `jalr` — Jump and Link Register

```
jalr  rd, rs1, offset
```

Salta para o endereço `rs1 + offset` e salva `PC + 4` em `rd`. Usado para retornar de uma função:

```asm
jalr  x0, x1, 0           # salta para o endereço em x1 (retorna para o chamador)
```

Como `x1` contém o endereço de retorno salvo pelo `jal`, isso nos leva de volta para a instrução após o `jal` original.

**Forma canônica de retorno:** o assembler aceita a pseudo-instrução `ret`, que se expande para `jalr x0, x1, 0`:

```asm
ret                        # equivalente a: jalr x0, x1, 0
```

### Visualizando o mecanismo

```
_start:                        dobrar:
  addi x10, x0, 7                slli x10, x10, 1   # a0 *= 2
  jal  x1, dobrar  ──────►       jalr x0, x1, 0     # salta para ra
◄──────────────────
  # continua aqui (PC = PC+4 antes do jal)
  # x10 = 14
```

O `ra` (x1) funciona como um "bilhete de volta": quem chama escreve o endereço, a função o lê ao retornar.

---

## 3. Convenção de chamada RISC-V (ABI)

A convenção ABI define quais registradores têm qual papel para que funções escritas por pessoas diferentes possam se comunicar:

| Registrador | Nome ABI | Papel |
|---|---|---|
| x0  | zero  | Sempre zero |
| x1  | ra    | Return address (endereço de retorno) |
| x2  | sp    | Stack pointer (ponteiro de pilha) |
| x10–x11 | a0–a1 | Argumentos 1–2 e valor de retorno |
| x12–x17 | a2–a7 | Argumentos 3–8 |
| x5–x7   | t0–t2 | Temporários (caller-saved) |
| x28–x31 | t3–t6 | Temporários (caller-saved) |
| x8–x9   | s0–s1 | Preservados pela função (callee-saved) |
| x18–x27 | s2–s11| Preservados pela função (callee-saved) |

**Regras essenciais:**
- Argumentos vão em `a0`–`a7` (x10–x17), valor de retorno vem em `a0`
- A função pode usar livremente `t0`–`t6` (temporários) e `a0`–`a7`
- A função DEVE preservar `s0`–`s11` e `sp` se os modificar

Para os programas deste tutorial, usamos registradores por nome (`x5`, `x6`...) sem nos preocupar tanto com a convenção completa — o importante é entender `ra`, `sp`, `a0` e `a1`.

---

## 4. Função mais simples: dobrar um valor

Vamos escrever uma função que recebe um número, dobra-o e retorna o resultado:

```asm
# =============================================================================
# Função dobrar — Tutorial 06
# =============================================================================
#
# Função: dobrar(n)  →  retorna n * 2
#   Entrada:  a0 (x10) = n
#   Saída:    a0 (x10) = n * 2
#
# Esta é uma função "folha" — não chama nenhuma outra função.
# Por isso, não precisa salvar ra na pilha.

.section .text
.global _start
_start:
    addi  x10, x0, 7         # a0 = argumento = 7
    jal   x1, dobrar          # chama dobrar(7), salva retorno em ra (x1)
    # aqui: x10 = 14  (resultado da função)

fim:
    jal   x0, fim            # halt

# ─── Função dobrar ────────────────────────────────────────────────────
dobrar:
    slli  x10, x10, 1        # a0 = a0 * 2  (shift left 1 = dobra)
    jalr  x0, x1, 0          # retorna para o chamador (ra contém o endereço de volta)
```

Execução passo a passo:

1. `addi x10, x0, 7` — carrega 7 em a0 (argumento)
2. `jal x1, dobrar` — PC aponta para `dobrar`, e x1 recebe o endereço da próxima instrução (`fim:`)
3. `slli x10, x10, 1` — a0 = 7 * 2 = 14
4. `jalr x0, x1, 0` — PC recebe o valor de x1 (volta para `fim:`)
5. `jal x0, fim` — halt

---

## 5. Múltiplas chamadas à mesma função

A vantagem de funções é poder chamá-las várias vezes:

```asm
# =============================================================================
# Chamando dobrar três vezes — Tutorial 06
# =============================================================================

.section .text
.global _start
_start:
    # Primeira chamada: dobrar(3)
    addi  x10, x0, 3         # a0 = 3
    jal   x1, dobrar          # chama dobrar; x10 = 6

    addi  x11, x10, 0        # x11 = resultado1 = 6

    # Segunda chamada: dobrar(10)
    addi  x10, x0, 10        # a0 = 10
    jal   x1, dobrar          # chama dobrar; x10 = 20

    addi  x12, x10, 0        # x12 = resultado2 = 20

    # Terceira chamada: dobrar(resultado1 + resultado2) = dobrar(26)
    add   x10, x11, x12      # a0 = 6 + 20 = 26
    jal   x1, dobrar          # chama dobrar; x10 = 52

    addi  x13, x10, 0        # x13 = resultado3 = 52

fim:
    jal   x0, fim            # halt
    # x11 = 6, x12 = 20, x13 = 52

# ─── Função dobrar ────────────────────────────────────────────────────
dobrar:
    slli  x10, x10, 1        # a0 *= 2
    jalr  x0, x1, 0          # retorna
```

Cada vez que `jal x1, dobrar` executa, `x1` recebe o endereço correto de retorno para aquela chamada específica.

---

## 6. Função com dois argumentos

Implementar `maximo(a, b)` demonstra como passar múltiplos argumentos:

```asm
# maximo(a, b): retorna o maior de a e b
# Argumentos: a0 = a, a1 (x11) = b
# Retorno:    a0 = max(a, b)

maximo:
    bge   x10, x11, a_maior  # se a >= b, a é o máximo
    addi  x10, x11, 0        # a < b: retorno = b
    jalr  x0, x1, 0          # retorna

a_maior:
    # a0 já tem 'a', que é o maior
    jalr  x0, x1, 0          # retorna
```

Chamada com `maximo(7, 3)`:
```asm
addi  x10, x0, 7         # a0 = a = 7
addi  x11, x0, 3         # a1 = b = 3
jal   x1, maximo          # chama maximo(7, 3), x10 = 7
```

---

## 7. O problema das chamadas aninhadas

Suponha que você quer uma função `quadruplicar` que usa `dobrar`:

```asm
# CÓDIGO COM BUG — NÃO FAÇA ASSIM!
quadruplicar:
    jal   x1, dobrar          # PROBLEMA: sobrescreve x1 com endereço interno!
    jal   x1, dobrar          # segunda chamada
    jalr  x0, x1, 0           # retorna... mas x1 aponta para dentro de quadruplicar!
```

O problema: quando `quadruplicar` foi chamada pelo `_start`, `x1` continha o endereço de retorno para `_start`. Ao executar `jal x1, dobrar`, esse valor foi **sobrescrito** com o endereço da próxima instrução dentro de `quadruplicar`. O endereço de retorno original foi perdido!

**Solução: salvar `ra` na pilha antes de chamar outra função.**

---

## 8. A pilha (stack)

A **pilha** é uma região da memória de dados usada para salvar valores temporariamente. Ela cresce para **baixo** (endereços decrescentes). O registrador `sp` (stack pointer, `x2`) aponta para o topo da pilha.

```
Memória de dados (dmem):
Endereço alto  │                │  ← sp inicial (0x0FF8 ou similar)
               │                │
               │  valor salvo   │  ← sp após "push" (sp = 0x0FF4)
               │                │
Endereço baixo │  ...dados...   │
```

### Push — salvar na pilha

```asm
addi  sp, sp, -4         # abre espaço de 4 bytes (sp diminui)
sw    x1, 0(sp)          # guarda ra na posição recém-reservada
```

### Pop — restaurar da pilha

```asm
lw    x1, 0(sp)          # lê ra da pilha
addi  sp, sp, 4          # fecha o espaço (sp volta ao estado anterior)
```

### Inicializando o stack pointer

O `sp` deve apontar para um endereço alto na dmem, longe dos dados do programa. Para a dmem de 4 KB (4096 bytes):

```asm
addi  sp, x0, 4088       # sp = 4088 = 0xFF8  (8 bytes antes do fim)
```

Ou usando `lui`:
```asm
lui   sp, 1              # sp = 0x1000 = 4096 (logo após o fim da dmem de 4KB)
```

---

## 9. Função que chama função: versão correta

Agora `quadruplicar(n)` = `dobrar(dobrar(n))` implementada corretamente:

```asm
# =============================================================================
# Quadruplicar usando dobrar — Tutorial 06
# =============================================================================
#
# quadruplicar(n): retorna n * 4, chamando dobrar duas vezes.
# Demonstra como salvar e restaurar ra na pilha.

.section .text
.global _start
_start:
    addi  sp, x0, 4088       # inicializa a pilha

    addi  x10, x0, 5         # a0 = 5
    jal   x1, quadruplicar   # chama quadruplicar(5), espera x10 = 20

fim:
    # x10 = 20
    jal   x0, fim            # halt

# ─── Função quadruplicar ──────────────────────────────────────────────
# Recebe: a0 = n
# Retorna: a0 = n * 4
# É uma função NÃO-FOLHA — chama dobrar, então precisa salvar ra
quadruplicar:
    addi  sp, sp, -4         # abre espaço na pilha
    sw    x1, 0(sp)          # salva ra do chamador (_start)

    jal   x1, dobrar          # dobrar(n): a0 = n*2   (x1 é sobrescrito aqui)
    jal   x1, dobrar          # dobrar(n*2): a0 = n*4

    lw    x1, 0(sp)          # restaura ra do chamador da pilha
    addi  sp, sp, 4          # fecha o espaço da pilha

    jalr  x0, x1, 0          # retorna para _start

# ─── Função dobrar ────────────────────────────────────────────────────
# Recebe: a0 = n
# Retorna: a0 = n * 2
# Função FOLHA — não chama nenhuma outra, não precisa salvar ra
dobrar:
    slli  x10, x10, 1        # a0 *= 2
    jalr  x0, x1, 0          # retorna
```

Trace de execução com `n=5`:
1. `_start` chama `quadruplicar(5)`, `x1` = endereço em `_start` (label `fim:`)
2. `quadruplicar` salva esse `x1` na pilha, chama `dobrar(5)`
3. `dobrar` retorna 10 para `quadruplicar` (x1 agora aponta para dentro de `quadruplicar`)
4. `quadruplicar` chama `dobrar(10)`, `dobrar` retorna 20
5. `quadruplicar` restaura o `x1` original da pilha, retorna para `_start`
6. `_start` continua com `x10 = 20`

---

## 10. Programa completo — função soma1n

Função `soma1n(n)` que calcula `1 + 2 + ... + n` com múltiplas chamadas:

```asm
# =============================================================================
# Função soma1n(n) = 1 + 2 + ... + n — Tutorial 06
# =============================================================================
#
# Demonstra: função com loop interno, múltiplas chamadas do mesmo código.
#
# Convenção ABI usada:
#   a0 (x10) = argumento n / valor de retorno
#   ra (x1)  = endereço de retorno
#   sp (x2)  = stack pointer
#   x5, x6   = variáveis locais (temporários)

.section .text
.global _start
_start:
    addi  sp, x0, 4088       # inicializa pilha

    # Primeira chamada: soma1n(5) = 15
    addi  x10, x0, 5         # a0 = n = 5
    jal   x1, soma1n
    addi  x11, x10, 0        # x11 = resultado = 15

    # Segunda chamada: soma1n(10) = 55
    addi  x10, x0, 10        # a0 = n = 10
    jal   x1, soma1n
    addi  x12, x10, 0        # x12 = resultado = 55

fim:
    # x11 = 15, x12 = 55
    jal   x0, fim            # halt

# =============================================================================
# Função soma1n(n): retorna 1 + 2 + ... + n
# Recebe: a0 (x10) = n
# Retorna: a0 (x10) = soma
# Função FOLHA — não chama outras funções, não salva ra
# =============================================================================
soma1n:
    addi  x5, x0, 1          # x5 = i = 1
    addi  x6, x0, 0          # x6 = soma = 0

soma_loop:
    blt   x10, x5, soma_fim  # se n < i (i > n), termina

    add   x6, x6, x5         # soma += i
    addi  x5, x5, 1          # i++

    jal   x0, soma_loop

soma_fim:
    addi  x10, x6, 0         # a0 = soma (valor de retorno)
    jalr  x0, x1, 0          # retorna
```

Verifique:
```
riscv> run
riscv> reg
# x11 deve ser 15   (soma1n(5)  = 1+2+3+4+5)
# x12 deve ser 55   (soma1n(10) = 1+2+...+10)
```

---

## 11. Depurando funções no simulador

```bash
python3 simulator/riscv_sim.py programa.hex
```

**Ver onde as funções estão na memória:**
```
riscv> imem 0x0000 20        ← mostra instruções com endereços e desmontagem
```

**Colocar breakpoint na entrada de uma função:**
```
riscv> imem 0x0000 20        ← identifica o endereço do label 'soma1n'
riscv> bp 0x001C             ← coloca breakpoint nesse endereço
riscv> run                   ← executa até chegar em soma1n
riscv> reg                   ← inspeciona: x10 (argumento), x1 (ra), x2 (sp)
```

**Ver a pilha durante execução:**
```
riscv> mem 0x0FF0 4          ← mostra 4 words próximos ao sp (0x0FF8)
# o valor salvo de ra aparece em 0x0FF4 após o push
```

**Executar passo a passo dentro da função:**
```
riscv> step                  ← uma instrução por vez
riscv> reg                   ← vê o estado após cada passo
```

---

## 12. Pontos de atenção

**Funções folha não precisam salvar `ra`.**
Se sua função não chama nenhuma outra com `jal x1, ...`, o `ra` não é sobrescrito e não precisa ser salvo. Salvar desnecessariamente não causa bugs, mas desperdiça instruções.

**Funções não-folha DEVEM salvar `ra`.**
Toda função que chama outra com `jal x1, ...` deve salvar `ra` na pilha antes e restaurar depois. Esquecer isso é a fonte de bugs muito difíceis de encontrar — o programa parece executar mas retorna para o lugar errado.

**Inicialize `sp` antes de usar a pilha.**
`sp` começa em 0 por padrão. Se você fizer `sw x1, 0(sp)` sem inicializar, estará escrevendo no endereço 0 — que contém os seus dados de programa! Sempre inicialize: `addi sp, x0, 4088`.

**O `sp` deve terminar igual ao que começou.**
Cada `addi sp, sp, -4` (push) deve ter um `addi sp, sp, 4` (pop) correspondente. Se não estiverem balanceados, a pilha fica "corrompida" e as próximas chamadas vão para lugares errados.

**`jal x0, label` não é uma chamada de função.**
Escrever em `x0` descarta o endereço de retorno. `jal x0, label` é um `goto` puro, não uma chamada. Para chamadas, use `jal x1, label`.

**`ret` é uma pseudo-instrução.**
O assembler converte `ret` para `jalr x0, x1, 0`. Ambas as formas produzem o mesmo código de máquina; `ret` é mais legível.

---

## 13. Exercício prático

**Enunciado:** Escreva uma função `soma_pares(n)` que retorna a soma de todos os números pares de 2 até `n` (inclusive se `n` for par). Chame a função com `n=10` (resultado esperado: `2+4+6+8+10 = 30`) e `n=8` (resultado esperado: `2+4+6+8 = 20`).

**Dicas:**
- A função não chama outras funções, então não precisa salvar `ra`
- Use loop com `i = 2`, incrementando de 2 em 2: `addi x5, x5, 2`
- Condição de parada: `i > n`, ou seja: `blt x10, x5, fim`

**Solução:**

```asm
# =============================================================================
# Função soma_pares(n) — Tutorial 06 — Exercício
# =============================================================================

.section .text
.global _start
_start:
    addi  sp, x0, 4088       # inicializa stack pointer

    # Primeira chamada: soma_pares(10) = 30
    addi  x10, x0, 10
    jal   x1, soma_pares
    addi  x11, x10, 0        # x11 = 30

    # Segunda chamada: soma_pares(8) = 20
    addi  x10, x0, 8
    jal   x1, soma_pares
    addi  x12, x10, 0        # x12 = 20

fim:
    # x11 = 30, x12 = 20
    jal   x0, fim

# =============================================================================
# soma_pares(n): retorna 2 + 4 + 6 + ... + (maior par <= n)
# Recebe: a0 (x10) = n
# Retorna: a0 (x10) = soma dos pares de 2 até n
# Função FOLHA — não chama outras, não salva ra
# =============================================================================
soma_pares:
    addi  x5, x0, 2          # x5 = i = 2  (primeiro par)
    addi  x6, x0, 0          # x6 = soma = 0

pares_loop:
    blt   x10, x5, pares_fim # se n < i (i > n), termina

    add   x6, x6, x5         # soma += i
    addi  x5, x5, 2          # i += 2  (próximo par)

    jal   x0, pares_loop

pares_fim:
    addi  x10, x6, 0         # a0 = soma (retorno)
    jalr  x0, x1, 0          # ret
```

**Desafio extra:** escreva uma função `quadruplicar_soma(n)` que chama `soma_pares(n)` e depois dobra o resultado chamando uma função `dobrar`. Como `quadruplicar_soma` chama outras funções, ela precisa salvar e restaurar `ra` na pilha.

---

## Resumo: checklist de funções

```
Antes de chamar uma função:
  - Carregue os argumentos em a0, a1, ... (x10, x11, ...)
  - Se precisar preservar t0-t6 após a chamada, salve-os antes

Ao iniciar uma função NÃO-FOLHA (que chama outras):
  - addi sp, sp, -4    (reserva 4 bytes na pilha)
  - sw   x1, 0(sp)     (salva ra)

Ao terminar uma função NÃO-FOLHA:
  - lw   x1, 0(sp)     (restaura ra)
  - addi sp, sp, 4     (libera o frame)
  - jalr x0, x1, 0     (ret)

Ao terminar uma função FOLHA:
  - jalr x0, x1, 0     (ret — sem necessidade de pilha)
```

---

## Parabéns!

Você concluiu todos os seis tutoriais desta série. Agora você sabe:

- Escrever programas em assembly RISC-V do zero
- Realizar operações aritméticas e lógicas completas
- Implementar `if/else` com desvios condicionais
- Construir loops `for`, `while` e `do-while`
- Trabalhar com arrays e memória de dados
- Criar funções reutilizáveis com a convenção de chamada padrão

### Próximos passos

1. Estude os exemplos em `exemplos/` — `bubblesort.s` e `fibonacci.s` combinam tudo que você aprendeu
2. Tente implementar a sequência de Fibonacci recursiva (exige múltiplos saves na pilha)
3. Explore o hardware em `riscv_harvard/` — agora você entende o que cada módulo SystemVerilog implementa

---

## Tutorial anterior

[Tutorial 05 — Memória: Arrays e Acesso a Dados](05_memoria.md)
