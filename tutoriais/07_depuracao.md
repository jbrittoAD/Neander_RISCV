# Tutorial 07 — Depuração de Programas Assembly

**Nível:** ⭐⭐⭐ (intermediário-avançado)
**Tempo estimado:** 45 minutos
**Pré-requisito:** Tutoriais 01–06

---

## Objetivo

Depurar programas assembly exige ferramentas diferentes das que você usa em C ou Python. Ao final deste tutorial você será capaz de:

- Usar `step`, `imem`, `reg` e `mem` para inspecionar a execução instrução por instrução
- Usar `bp` (breakpoint) para pausar o programa em pontos estratégicos
- Usar `watch <reg>` para detectar quando um registrador muda inesperadamente
- Usar `history [n]` para ver quais instruções foram executadas recentemente
- Usar `set <reg> <val>` para testar hipóteses sem recompilar
- Aplicar uma estratégia sistemática de depuração em quatro etapas

---

## 1. Por que depurar assembly é diferente?

Em C, um debugger como o GDB mostra variáveis com nomes como `resultado`, `contador`, `i`. Em assembly, não existem nomes — só há registradores (`x1`, `x2`, `x3`...) e endereços de memória em hexadecimal. É você quem precisa lembrar que `x2` contém o resultado parcial e `x3` é o contador interno.

**Analogia:** é como diagnosticar uma falha num motor antigo sem computador de bordo. Você não tem um painel dizendo "temperatura do cilindro 3 = 180°C". Você pega o multímetro, o osciloscópio e vai testando pino a pino, componente a componente. O simulador interativo é o seu osciloscópio — ele deixa você pausar o motor em qualquer ponto e medir tudo.

### Comparação com o Neander

No simulador do Neander você também pode executar passo a passo e ver o AC (acumulador) e os flags N e Z. No RISC-V a situação é parecida, mas há 32 registradores, dois bancos de memória (imem e dmem) e a pilha para inspecionar. O processo é o mesmo; a escala é maior.

---

## 2. O programa com bug

Para aprender a depurar, precisamos de um programa defeituoso. Vamos usar um programa que calcula o fatorial de 5 (5! = 120) usando multiplicação implementada como soma repetida. O programa compila e executa sem travar — mas produz um resultado errado.

### O algoritmo esperado

```
resultado = 1
N = 5
enquanto N > 0:
    resultado = resultado * N     (implementado como soma repetida)
    N = N - 1
# ao final: resultado = 1 * 5 * 4 * 3 * 2 * 1 = 120
```

A multiplicação `resultado * N` é feita somando `resultado` exatamente `N` vezes:

```
produto = 0
contador = 0
enquanto contador < N:
    produto = produto + resultado
    contador = contador + 1
resultado = produto
```

### O programa com bug

Salve o arquivo abaixo como `bug_fatorial.s` (ou use o arquivo `07_exemplo_bug.s` já disponível nesta pasta):

```asm
# =============================================================================
# bug_fatorial.s — PROGRAMA COM BUG — Tutorial 07
# =============================================================================
#
# Objetivo: calcular 5! = 120
# Resultado obtido com o bug: ERRADO (não é 120)
#
# Registradores:
#   x1 = N (contador regressivo: 5, 4, 3, 2, 1)
#   x2 = resultado acumulado
#   x3 = produto da multiplicação atual
#   x4 = contador interno do loop de multiplicação

.section .text
.global _start
_start:
    addi x1, x0, 5     # x1 = N = 5
    addi x2, x0, 1     # x2 = resultado = 1

loop:
    beq  x1, x0, fim   # se N == 0, termina

    # Multiplica x2 * x1 via somas repetidas
    addi x3, x0, 0     # x3 = produto = 0
    addi x4, x0, 0     # x4 = contador = 0
mul:
    beq  x4, x1, mul_fim       # se contador == N, termina multiplicação
    add  x3, x3, x1            # BUG: soma x1 (N) em vez de x2 (resultado)
    addi x4, x4, 1
    jal  x0, mul
mul_fim:
    addi x2, x3, 0     # x2 = produto calculado
    addi x1, x1, -1    # N--
    jal  x0, loop

fim:
    jal x0, fim        # halt
```

### Qual é o bug?

A linha marcada com `# BUG` soma `x1` (o valor de N) em vez de `x2` (o resultado acumulado). Em vez de calcular `resultado × N`, o loop interno calcula `N × N` (soma N consigo mesmo, N vezes).

Veja o que acontece com o bug ativo:
- Iteração 1 (N=5): produto = 5+5+5+5+5 = **25**; resultado = 25
- Iteração 2 (N=4): produto = 4+4+4+4 = **16**; resultado = 16
- Iteração 3 (N=3): produto = 3+3+3 = **9**; resultado = 9
- Iteração 4 (N=2): produto = 2+2 = **4**; resultado = 4
- Iteração 5 (N=1): produto = 1; resultado = **1**

O resultado final é 1 — bem longe de 120.

> **Nota:** este é um bug clássico de iniciante. Você está usando um registrador que ainda está "na mão" do loop externo no lugar de outro. Sem os nomes de variáveis do C, fica fácil perder o fio. A depuração vai mostrar exatamente onde o valor vai errado.

---

## 3. Sessão de depuração passo a passo

### Etapa A — Compilar e carregar

```bash
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o bug_fatorial.o bug_fatorial.s
riscv64-unknown-elf-objcopy -O binary bug_fatorial.o bug_fatorial.bin
python3 ../riscv_harvard/scripts/bin2hex.py bug_fatorial.bin bug_fatorial.hex
python3 ../simulator/riscv_sim.py bug_fatorial.hex
```

### Etapa B — Reproduzir o erro

Primeiro, execute o programa do início ao fim e confirme que o resultado está errado:

```
riscv> run
[halt] PC=0x0044  ciclos=91

riscv> reg
 x0  zero =          0   x1    ra =          0   x2    sp =          1
 x3    gp =          1   x4    tp =          0   ...
```

`x2` vale 1 — deveria ser 120. O bug está confirmado.

> **Dica:** após `run`, o simulador para no `jal x0, fim` (halt). Use `reg` imediatamente para ver o estado final dos registradores antes de fazer qualquer outra coisa.

### Etapa C — Ver o mapa do programa

Antes de sair colocando breakpoints, use `imem` para visualizar as instruções e seus endereços:

```
riscv> imem 0x0000 16
0x0000:  addi x1, x0, 5         # _start
0x0004:  addi x2, x0, 1
0x0008:  beq  x1, x0, 0x0044   # loop: (salta para fim)
0x000C:  addi x3, x0, 0
0x0010:  addi x4, x0, 0         # mul:
0x0014:  beq  x4, x1, 0x0028   # (salta para mul_fim)
0x0018:  add  x3, x3, x1        # ← linha suspeita
0x001C:  addi x4, x4, 1
0x0020:  jal  x0, 0x0014        # volta para mul
0x0024:  ...
0x0028:  addi x2, x3, 0         # mul_fim:
0x002C:  addi x1, x1, -1
0x0030:  jal  x0, 0x0008        # volta para loop
0x0034:  ...
0x0044:  jal  x0, 0x0044        # fim: (halt)
```

Agora você tem um mapa dos endereços. Anote:
- `0x0008` — início do `loop`
- `0x0014` — início do `mul`
- `0x0028` — `mul_fim`

### Etapa D — Colocar breakpoint na entrada do loop de multiplicação

Vamos parar toda vez que o programa entra em `mul` para inspecionar os valores **antes** de cada multiplicação:

```
riscv> reset
riscv> bp 0x0014
Breakpoint definido em 0x0014

riscv> run
[breakpoint] PC=0x0014  ciclos=5

riscv> reg
 x1  ra  =  5    x2  sp  =  1    x3  gp  =  0    x4  tp  =  0
```

Primeira entrada em `mul`: N=5, resultado=1, produto=0, contador=0. Está correto até aqui.

```
riscv> step
0x0018:  add  x3, x3, x1

riscv> reg
 x1  ra  =  5    x2  sp  =  1    x3  gp  =  5    x4  tp  =  0
```

Após executar `add x3, x3, x1`: `x3` passou de 0 para 5. Deveria ter ido para `x2=1`, mas foi para `x1=5`. O bug está exatamente nessa instrução.

> **Dica:** sempre que um valor "pula" para algo inesperado, olhe a instrução que acabou de executar com `history 1`. O culpado está ali.

### Etapa E — Confirmar com `watch`

Reinicie e coloque um watch em `x2` para ver quando e como ele muda:

```
riscv> reset
riscv> watch x2
Monitorando x2

riscv> run
[watch] x2: 1 -> 25   PC=0x0028  (mul_fim: addi x2, x3, 0)
[watch] x2: 25 -> 16  PC=0x0028
[watch] x2: 16 -> 9   PC=0x0028
[watch] x2: 9  -> 4   PC=0x0028
[watch] x2: 4  -> 1   PC=0x0028
[halt] PC=0x0044
```

Perfeito — o `watch` mostra cada valor que `x2` assume ao longo do programa. A sequência 25, 16, 9, 4, 1 confirma que cada iteração calcula N² e não `resultado × N`.

### Etapa F — Usar `history` para ver o contexto da mudança

Depois de um halt ou breakpoint, `history` mostra as últimas instruções executadas:

```
riscv> history 6
[86]  0x0018:  add  x3, x3, x1
[87]  0x001C:  addi x4, x4, 1
[88]  0x0020:  jal  x0, 0x0014
[89]  0x0014:  beq  x4, x1, 0x0028
[90]  0x0028:  addi x2, x3, 0
[91]  0x002C:  addi x1, x1, -1
```

Veja a instrução `[86]`: `add x3, x3, x1`. É ela que está acumulando `x1` em vez de `x2`.

### Etapa G — Testar a hipótese com `set`

Sem recompilar, você pode modificar registradores para testar se a sua hipótese de correção está certa. Digamos que você quer verificar: "se eu forçar x2=120 no final, o programa está correto exceto por esse cálculo?"

```
riscv> reset
riscv> run
riscv> set x2 120
x2 = 120

riscv> reg
 x2  sp  = 120
```

Isso confirma que o resto do programa não tem outros bugs — a única coisa errada era a multiplicação. Na prática, `set` é mais útil para simular entradas específicas:

```
riscv> reset
riscv> step 2          # executa addi x1,x0,5 e addi x2,x0,1
riscv> set x2 10       # simula: "e se resultado começasse em 10?"
riscv> run
```

> **Analogia:** `set` é como injetar uma tensão numa placa de circuito para testar se o resto do circuito funciona. Você isola o componente suspeito.

---

## 4. Estratégia sistemática de depuração

Depois de ver o processo em ação, aqui está o método em quatro etapas que funciona para qualquer programa assembly:

### Etapa 1 — Reproduz

Execute o programa com `run` e confirme que o resultado está errado. Anote:
- Quais registradores têm valores incorretos?
- O programa termina (halt) ou entra em loop infinito?
- O comportamento é sempre igual ou muda com entradas diferentes?

### Etapa 2 — Isola

Divida o programa em regiões usando `bp`. A ideia é responder: "o erro acontece na primeira metade ou na segunda?"

```
riscv> reset
riscv> bp 0x0028      # ponto no meio do programa
riscv> run
riscv> reg            # resultado parcial está correto aqui?
```

Se o estado estiver correto no breakpoint do meio, o bug está na segunda metade. Senão, está na primeira. Repita subdividindo até isolar a instrução culpada.

> **Analogia com o Neander:** é exatamente como a busca binária que você talvez tenha aprendido com o Neander — divida ao meio, veja de que lado está o erro, divida novamente.

### Etapa 3 — Inspeciona

Dentro da região suspeita, use `step` instrução por instrução e `watch` nos registradores que importam. A pergunta a responder em cada `step`:

- Este registrador tem o valor que eu esperava?
- A instrução que acabou de executar produziu o resultado certo?

Quando encontrar uma instrução que produziu o resultado errado, você encontrou o bug.

### Etapa 4 — Verifica

Corrija o bug no arquivo `.s`, recompile e execute novamente:

```
riscv> quit
# edita bug_fatorial.s: troca "add x3, x3, x1" por "add x3, x3, x2"
# recompila...
python3 ../simulator/riscv_sim.py bug_fatorial.hex
riscv> run
riscv> reg
 x2  sp  = 120   ← correto!
```

---

## 5. Três erros comuns e como detectá-los

### 5.1 Loop infinito

**Sintoma:** `run` não termina. O terminal fica parado.

**O que fazer:**
1. Pressione `Ctrl+C` para interromper
2. Use `reg` para ver o PC e os registradores no momento da interrupção
3. Coloque um `bp` no início do loop suspeito e execute `step` algumas vezes

```
^C
[interrompido] PC=0x0008  ciclos=12847

riscv> reg
 x1  ra  = 5    x4  tp  = 5    # contador e limite iguais — beq deveria ter saído!

riscv> imem 0x0008 4
0x0008:  beq x1, x0, 0x0044    # condição errada! compara com 0, mas x1 nunca chega a 0
```

**Causa típica:** a condição de saída do loop está errada — compara com o registrador errado, usa `blt` onde deveria usar `bge`, ou o incremento/decremento não converge.

### 5.2 Função retorna lixo

**Sintoma:** uma função é chamada, mas o valor de retorno em `x10` não faz sentido.

**O que fazer:**
1. Use `imem` para achar o endereço de entrada da função
2. Coloque `bp` nesse endereço e execute até chegar
3. Verifique o argumento de entrada (`x10`) e o link register (`x1`)
4. Use `step` dentro da função e acompanhe `x10`
5. Se houver pilha, use `mem` para inspecioná-la

```
riscv> bp 0x001C      # endereço de entrada da função
riscv> run
riscv> reg
 x1  ra = 0x0010    x10  a0 = 7     # argumento correto, ra correto

riscv> watch x10
riscv> run            # continua até o próximo bp ou halt
[watch] x10: 7 -> 0   PC=0x0020    # x10 zerou aqui!

riscv> imem 0x001C 4
0x001C:  ...
0x0020:  addi x10, x0, 0            # BUG: inicializou x10 dentro da função
```

**Causa típica:** a função sobrescreve `x10` acidentalmente com uma inicialização que deveria usar outro registrador.

### 5.3 Acesso a array fora dos limites

**Sintoma:** `lw` carrega um valor inesperado (zero ou lixo).

**O que fazer:**
1. Use `step` até a instrução `lw` suspeita
2. Antes de executar `lw`, verifique o endereço base e o índice calculado
3. Use `mem` para ver o que está naquele endereço

```
riscv> bp 0x0018      # endereço da instrução lw
riscv> run
riscv> reg
 x6  t1 = 0x0020    # base do array
 x3  gp = 4         # índice

riscv> mem 0x0020 6  # inspeciona o array a partir da base
0x0020:  5   10   15   20   0   0    # array [5,10,15,20], depois zeros

riscv> step          # executa o lw
riscv> reg
 x5  t0 = 15        # buscou o índice 2 (offset 8), não o índice 1 (offset 4)
```

**Causa típica:** incremento de ponteiro dobrado (`addi x6, x6, 8` em vez de `addi x6, x6, 4`) ou índice não multiplicado por 4.

---

## 6. Referência rápida dos comandos de depuração

| Comando | Quando usar | Exemplo |
|---|---|---|
| `step [n]` | Avançar instrução por instrução para acompanhar o fluxo | `step 3` |
| `run` | Executar até o halt ou um breakpoint | `run` |
| `reg` | Ver o estado de todos os registradores após cada passo | `reg` |
| `imem [addr] [n]` | Ver o mapa de instruções com endereços (para planejar breakpoints) | `imem 0x0000 20` |
| `mem <addr> [n]` | Inspecionar dados na memória (arrays, pilha) | `mem 0x0000 8` |
| `bp <addr>` | Pausar em um endereço específico | `bp 0x0014` |
| `bps` | Listar todos os breakpoints ativos | `bps` |
| `watch [<reg>]` | Parar toda vez que um registrador mudar | `watch x2` |
| `watch` | Listar watches ativos | `watch` |
| `history [n]` | Ver as últimas n instruções executadas | `history 10` |
| `set <reg> <val>` | Forçar um valor num registrador para testar hipótese | `set x2 120` |
| `reset` | Voltar ao início (mantém breakpoints e watches) | `reset` |
| `trace on` | Imprimir cada instrução executada automaticamente | `trace on` |

> **Dica:** use `bp` + `run` para ir rápido até a região suspeita, depois `step` + `reg` para analisar devagar. Nunca saia stepando do início ao fim — você vai se perder.

---

## 7. Exercício prático

### Enunciado

O programa abaixo deveria somar os elementos de um array `[5, 10, 15, 20]` e guardar o resultado em `x2`. O resultado esperado é **50**.

Compile, execute e use as ferramentas de depuração para encontrar e corrigir o bug.

```asm
# =============================================================================
# soma_array.s — PROGRAMA COM BUG — Exercício Tutorial 07
# =============================================================================
#
# Objetivo: somar array [5, 10, 15, 20] → esperado x2 = 50
# Bug: o programa produz um resultado errado

.section .text
.global _start
_start:
    addi x6, x0, 0     # x6 = ponteiro base do array (endereço 0)
    addi x1, x0, 5     # armazena elementos do array na memória
    sw   x1, 0(x6)
    addi x1, x0, 10
    sw   x1, 4(x6)
    addi x1, x0, 15
    sw   x1, 8(x6)
    addi x1, x0, 20
    sw   x1, 12(x6)

    addi x2, x0, 0     # x2 = soma = 0
    addi x3, x0, 0     # x3 = i (contador de iterações)
    addi x4, x0, 4     # x4 = N = 4 (número de elementos)

loop:
    bge  x3, x4, fim   # se i >= N, termina
    lw   x5, 0(x6)     # x5 = array[i]
    add  x2, x2, x5    # soma += array[i]
    addi x6, x6, 8     # BUG: avança o ponteiro 8 bytes em vez de 4
    addi x3, x3, 1     # i++
    jal  x0, loop

fim:
    jal x0, fim        # halt
```

**Dicas para depurar:**
1. Execute com `run` e veja que `x2` não vale 50
2. Use `imem` para mapear os endereços das instruções
3. Coloque `bp` na instrução `lw` e use `reg` para inspecionar `x6` a cada iteração
4. Use `mem 0x0000 6` para ver o array na memória e comparar com o endereço sendo lido
5. O erro está numa única instrução — qual é ela?

---

## Solução

### Identificando o bug

Após `run`, `x2` vale 20 em vez de 50. Alguma coisa está errada no loop.

```
riscv> run
[halt] PC=0x0050  ciclos=38

riscv> reg
 x2  sp = 20    x3  gp = 4    x6  t1 = 32
```

`x3=4` significa que o loop rodou 4 vezes — a contagem está certa. Mas `x6=32` (0x20) significa que o ponteiro avançou 32 bytes a partir de 0, e o array só tem 16 bytes (4 elementos × 4 bytes). O ponteiro foi longe demais.

```
riscv> reset
riscv> imem 0x0020 8
0x0020:  bge  x3, x4, 0x0050   # loop:
0x0024:  lw   x5, 0(x6)
0x0028:  add  x2, x2, x5
0x002C:  addi x6, x6, 8         # ← suspeito: avança 8 bytes
0x0030:  addi x3, x3, 1
0x0034:  jal  x0, 0x0020

riscv> bp 0x0024      # breakpoint na instrução lw
riscv> run
[breakpoint] PC=0x0024  ciclos=14

riscv> reg
 x6  t1 = 0    # primeira iteração: base = 0 → correto
riscv> mem 0x0000 6
0x0000:  5   10   15   20   0   0    # array na memória

riscv> step           # executa lw x5, 0(x6)
riscv> reg
 x5  t0 = 5          # leu array[0] = 5 → correto

riscv> run            # continua até o próximo breakpoint
[breakpoint] PC=0x0024

riscv> reg
 x6  t1 = 8          # segunda iteração: x6=8 → leu posição byte 8 → array[2]=15!
                     # deveria ser x6=4 → array[1]=10
```

O ponteiro pulou do endereço 0 para o endereço 8, ignorando o elemento `array[1]=10`. A instrução `addi x6, x6, 8` avança 8 bytes (dois inteiros de 4 bytes) quando deveria avançar 4 bytes.

### O que o programa está somando (com o bug)

| Iteração | Endereço lido | Valor lido |
|---|---|---|
| 0 | 0x0000 | 5 |
| 1 | 0x0008 | 15 |
| 2 | 0x0010 | 0 (fora do array) |
| 3 | 0x0018 | 0 (fora do array) |
| **Total** | | **20** |

### A correção

Troque `addi x6, x6, 8` por `addi x6, x6, 4`.

Com a correção, o programa soma `5 + 10 + 15 + 20 = 50` e `x2 = 50` ao final.

```
riscv> quit
# edita soma_array.s: troca "addi x6, x6, 8" por "addi x6, x6, 4"
# recompila e carrega...

riscv> run
[halt] PC=0x0050  ciclos=38

riscv> reg
 x2  sp = 50    ← correto!
```

> **Lição:** erros de stride (passo de ponteiro) são muito comuns em loops sobre arrays. O elemento sendo lido é sempre `*base`, então qualquer erro no incremento de `base` salta elementos ou acessa memória fora do array. O comando `mem` é a ferramenta mais rápida para confirmar que os dados estão onde você espera.

---

## Resumo

Depurar assembly é um processo metódico. O simulador dá todas as ferramentas necessárias; o que faz a diferença é a estratégia:

1. **Reproduz** — confirme o erro com `run` + `reg`
2. **Isola** — use `bp` para dividir o programa e localizar a região com problema
3. **Inspeciona** — use `step`, `watch` e `mem` dentro da região suspeita
4. **Verifica** — corrija, recompile e confirme que o resultado ficou certo

Com `watch` você sabe *quando* um valor muda. Com `history` você sabe *quais instruções* produziram esse valor. Com `set` você testa *hipóteses* sem recompilar. Juntos, esses três comandos cobrem a grande maioria dos bugs de assembly.

---

## Tabela final — comandos de depuração

| Comando | Atalho | Descrição |
|---|---|---|
| `step [n]` | `s` | Executa n instruções (padrão: 1) |
| `run` | `r` | Executa até halt ou breakpoint |
| `reg` | `regs` | Mostra todos os registradores |
| `imem [addr] [n]` | `i` | Mostra n instruções desmontadas a partir de addr |
| `mem <addr> [n]` | `m` | Mostra n words de dados a partir de addr |
| `bp <addr>` | — | Ativa/desativa breakpoint no endereço |
| `bps` | — | Lista todos os breakpoints ativos |
| `watch [<reg>]` | `w` | Monitora mudanças no registrador (sem argumento: lista watches) |
| `history [n]` | `hist` | Mostra as últimas n instruções executadas (padrão: 10) |
| `set <reg> <val>` | — | Define valor de registrador manualmente |
| `reset` | — | Reinicia CPU mantendo breakpoints e watches |
| `trace [on\|off]` | — | Ativa/desativa impressão automática de cada instrução |
| `help` | `h` | Mostra ajuda |
| `quit` | `q` | Sai do simulador |
