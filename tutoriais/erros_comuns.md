# Erros Comuns em Assembly RISC-V — Guia de Referência

**Tipo:** Referência rápida (não é um tutorial numerado)
**Público:** Alunos que já leram os tutoriais 01–06 e estão escrevendo seus próprios programas
**Objetivo:** Identificar e corrigir os erros mais frequentes antes de pedir ajuda

---

Este documento cataloga os erros que aparecem com mais frequência quando alunos
escrevem seus primeiros programas em assembly RISC-V. Para cada erro: o que você
vê, por que acontece e como corrigir.

---

## Índice rápido

| # | Erro | Symptoma principal |
|---|------|-------------------|
| 1 | [Esquecer de salvar `ra` antes de chamar outra função](#erro-1-esquecer-de-salvar-ra-antes-de-chamar-outra-função) | Programa retorna para 0x0 ou salta para lugar errado |
| 2 | [Usar `t`-registers como `s`-registers](#erro-2-usar-t-registers-como-se-fossem-s-registers) | Valor "some" depois de chamar uma função |
| 3 | [Indexação de array sem multiplicar por 4](#erro-3-indexação-de-array-sem-multiplicar-por-4) | `lw` carrega valor errado do array |
| 4 | [Acesso a memória não alinhado](#erro-4-acesso-a-memória-não-alinhado) | `lw` retorna lixo ou erro de memória |
| 5 | [Padrão de halt errado](#erro-5-padrão-de-halt-errado) | Programa roda "para sempre" e atinge HALT_LIMIT |
| 6 | [Constante fora do alcance do imediato de 12 bits](#erro-6-constante-fora-do-alcance-do-imediato-de-12-bits) | Erro do assembler ou valor inesperado no registrador |
| 7 | [Stack pointer não inicializado ou inicializado errado](#erro-7-stack-pointer-não-inicializado-ou-inicializado-errado) | `sw ra` sobrescreve instruções ou programa trava |
| 8 | [Condição de branch invertida no loop](#erro-8-condição-de-branch-invertida-no-loop) | Loop executa 0 vezes ou roda indefinidamente |
| 9 | [Fall-through após o corpo principal — falta `jal x0, fim`](#erro-9-fall-through-após-o-corpo-principal) | Programa "cai dentro" do código de uma função |
| 10 | [XOR como NOT de 32 bits — `xori` com máscara errada](#erro-10-xori-com-máscara-errada-para-not-de-32-bits) | NOT bit a bit flipa só 8 bits, não 32 |
| B1 | [Usar `srl` quando precisava de `sra` (shift aritmético)](#bônus-1-usar-srl-quando-precisava-de-sra) | Divisão de número negativo dá resultado absurdo |
| B2 | [Off-by-one nos limites do array](#bônus-2-off-by-one-nos-limites-do-array) | Última iteração acessa memória fora do array |
| B3 | [Confundir `lb` (signed) com `lbu` (unsigned)](#bônus-3-confundir-lb-com-lbu) | Byte com bit 7 em 1 vira número enorme em 32 bits |

---

## Erros detalhados

---

### Erro 1: Esquecer de salvar `ra` antes de chamar outra função

**Sintoma:** a função parece retornar para o lugar errado — o programa pula para
o endereço 0x0 (início do programa) ou para algum ponto aleatório e faz coisas
que não deveria.

**Causa:** `jal ra, funcao` **sobrescreve** o registrador `ra` com o endereço de
retorno atual. Se você está dentro de uma função e chama outra função, o `ra`
original (que aponta de volta para quem te chamou) é destruído. Quando sua função
tentar retornar com `jalr x0, ra, 0`, vai usar o endereço *novo* — o da última
chamada — e não o endereço correto.

**Exemplo errado:**

```asm
.section .text
.global _start
_start:
    jal   ra, calcula_dobro  # ra = endereço após esta instrução
    jal   x0, fim

calcula_dobro:
    # ERRO: esta função chama outra, mas não salva ra primeiro!
    jal   ra, valida          # ra é SOBRESCRITO aqui
    add   a0, a0, a0          # dobra o argumento
    jalr  x0, ra, 0           # PROBLEMA: ra agora aponta para dentro de calcula_dobro,
                              # não para _start. Retorna para lugar errado!
valida:
    # faz alguma verificação...
    jalr  x0, ra, 0

fim:
    jal   x0, fim
```

**Exemplo correto:**

```asm
.section .text
.global _start
_start:
    addi  sp, x0, 0x400       # inicializa sp (veja Erro 7)
    addi  a0, x0, 21          # argumento: a0 = 21
    jal   ra, calcula_dobro   # chama função
    jal   x0, fim             # a0 = 42 aqui

calcula_dobro:
    # salva ra na pilha ANTES de chamar outra função
    addi  sp, sp, -4
    sw    ra, 0(sp)           # empilha ra

    jal   ra, valida          # agora pode sobrescrever ra
    add   a0, a0, a0          # dobra o argumento

    lw    ra, 0(sp)           # restaura ra original
    addi  sp, sp, 4           # desempilha
    jalr  x0, ra, 0           # retorna para o chamador correto

valida:
    jalr  x0, ra, 0

fim:
    jal   x0, fim
```

**Como detectar no simulador:**

```
riscv> step              # execute instrução por instrução
riscv> reg               # observe o valor de ra (x1) a cada passo
```

Se `ra` mudar de valor inesperadamente durante uma chamada aninhada, é este erro.
Também útil: `imem 0x0000` — veja se o PC está em um endereço que não faz sentido
para o ponto em que você acha que está no programa.

---

### Erro 2: Usar `t`-registers como se fossem `s`-registers

**Sintoma:** um valor que você colocou em `t0`–`t6` antes de chamar uma função
tem um valor diferente (ou zero) depois que a função retorna.

**Causa:** pela convenção de chamada RISC-V, os registradores `t0`–`t6` são
**caller-saved** — qualquer função que você chamar tem o direito de usá-los e
destruí-los sem restaurar. Se uma função usa `t0` internamente, ela não é
obrigada a salvar e restaurar esse valor.

Os registradores `s0`–`s11` são **callee-saved**: se uma função precisar usá-los,
ela *deve* salvá-los na pilha e restaurá-los antes de retornar.

```
Caller-saved (temporários — podem ser destruídos por qualquer chamada):
    t0–t6   (x5–x7, x28–x31)

Callee-saved (salvos — a função chamada preserva esses valores):
    s0–s11  (x8–x9, x18–x27)
    ra, sp  (x1, x2)
```

**Exemplo errado:**

```asm
    addi  t0, x0, 100     # t0 = 100 (quero preservar esse valor)
    jal   ra, alguma_func # chama função
    # ERRO: t0 pode ter qualquer valor agora — a função pode ter usado t0
    add   t1, t0, x0      # t1 provavelmente NÃO é 100
```

**Exemplo correto:**

```asm
    # Opção 1: usar s-register para valor que deve sobreviver a chamadas
    addi  s0, x0, 100     # s0 = 100 (alguma_func é obrigada a preservar s0)
    jal   ra, alguma_func
    add   t1, s0, x0      # s0 ainda é 100, garantido

    # Opção 2: salvar t0 na pilha você mesmo antes da chamada
    addi  sp, sp, -4
    sw    t0, 0(sp)       # salva t0
    jal   ra, alguma_func
    lw    t0, 0(sp)       # restaura t0
    addi  sp, sp, 4
```

**Como detectar no simulador:**

```
riscv> reg               # anote os valores de t0-t6 antes da chamada
riscv> step              # execute a chamada
riscv> reg               # compare: t0-t6 mudaram? Era esperado?
```

---

### Erro 3: Indexação de array sem multiplicar por 4

**Sintoma:** ao acessar `array[i]` com `lw`, o valor carregado não corresponde
ao i-ésimo elemento — parece estar deslocado.

**Causa:** cada elemento `int` (word) ocupa **4 bytes** na memória. O endereço
do elemento `i` é `base + i*4`, não `base + i`. Se você adicionar `i` diretamente
ao endereço base, estará acessando o byte errado (e provavelmente não alinhado).

```
Endereços:
  array[0]  →  base + 0   = base + 0×4
  array[1]  →  base + 4   = base + 1×4
  array[2]  →  base + 8   = base + 2×4
  array[i]  →  base + i*4
```

**Exemplo errado:**

```asm
    addi  x1, x0, 0           # x1 = base do array
    addi  x2, x0, 3           # x2 = índice i = 3

    # ERRO: soma i sem multiplicar por 4
    add   x3, x1, x2          # x3 = base + 3  (endereço errado!)
    lw    x4, 0(x3)           # carrega bytes 3-6, não array[3]!
```

**Exemplo correto:**

```asm
    addi  x1, x0, 0           # x1 = base do array
    addi  x2, x0, 3           # x2 = índice i = 3

    slli  x5, x2, 2           # x5 = i * 4  (shift left por 2 = multiplica por 4)
    add   x3, x1, x5          # x3 = base + i*4
    lw    x4, 0(x3)           # carrega array[3] corretamente
```

A instrução `slli x5, x2, 2` desloca `x2` dois bits para a esquerda, o que
equivale a multiplicar por 4. Esta é a mesma instrução que compiladores GCC
emitem para indexação de arrays `int`.

**Como detectar no simulador:**

```
riscv> mem 0x0000 8      # veja os valores no array
riscv> reg               # veja o endereço calculado (x3 no exemplo)
```

Se o endereço em x3 não for múltiplo de 4, este é o erro.

---

### Erro 4: Acesso a memória não alinhado

**Sintoma:** `lw` carrega lixo (valor completamente diferente do esperado) ou o
simulador reporta um erro do tipo `MemoryError: unaligned access`.

**Causa:** o RISC-V impõe requisitos de alinhamento para acessos à memória:
- `lw`/`sw` (4 bytes) → endereço deve ser múltiplo de **4**
- `lh`/`sh`/`lhu` (2 bytes) → endereço deve ser múltiplo de **2**
- `lb`/`sb`/`lbu` (1 byte) → sem restrição de alinhamento

Se o endereço não satisfaz essa condição, o comportamento é indefinido (ou o
simulador gera erro).

**Exemplo errado:**

```asm
    addi  x1, x0, 0           # x1 = base
    addi  x2, x0, 1           # x2 = índice = 1

    # ERRO: faltou slli — x2 não foi multiplicado por 4
    add   x3, x1, x2          # x3 = 0 + 1 = 0x0001 (não alinhado!)
    lw    x4, 0(x3)           # acesso não alinhado — comportamento indefinido
```

**Exemplo correto:**

```asm
    addi  x1, x0, 0
    addi  x2, x0, 1

    slli  x2, x2, 2           # x2 = 1 * 4 = 4 (agora alinhado)
    add   x3, x1, x2          # x3 = 0x0004 (múltiplo de 4)
    lw    x4, 0(x3)           # acesso alinhado
```

Também ocorre ao construir endereços manualmente sem garantir múltiplo de 4:

```asm
    # ERRADO: carregar da posição 2 com lw
    lw    x1, 2(x0)           # 0x0002 não é múltiplo de 4

    # CORRETO: use lb/lbu para acesso a bytes individuais sem restrição
    lbu   x1, 2(x0)           # lê 1 byte, sem restrição de alinhamento
```

**Como detectar no simulador:**

```
riscv> reg               # veja o endereço que será usado (antes do lw/sw)
```

Se o endereço (em decimal ou hex) não for múltiplo de 4 e você for usar `lw`/`sw`,
é este erro.

---

### Erro 5: Padrão de halt errado — loop infinito não detectado

**Sintoma:** o simulador reporta "HALT_LIMIT atingido" (programa rodou por mais
instruções do que o limite configurado) mas nunca detectou o halt.

**Causa:** o simulador detecta o halt quando o PC **não avança** — ou seja, quando
`jal x0, fim` pula exatamente para si mesmo (a instrução no mesmo endereço). Se
o label `fim` apontar para uma instrução *diferente* (por exemplo, a instrução
*acima* do halt), o PC fica oscilando entre dois endereços e o simulador não
reconhece como halt.

**Exemplo errado:**

```asm
    # ...corpo do programa...

fim:                          # fim aponta para o jal da linha anterior
    jal   x0, outro_label     # ERRO: não pula para si mesmo

outro_label:
    # mais código aqui
```

Outro erro comum:

```asm
    add   x1, x2, x3
fim:                          # label fica aqui
    # sem instrução de halt!
    jal   x0, loop            # cai de volta no loop (ou pula para algum lugar)
```

**Exemplo correto:**

```asm
    # ...corpo do programa...
    jal   x0, fim             # pula para fim (ou simplesmente cai no label abaixo)

fim:
    jal   x0, fim             # HALT: pula para si mesmo
                              # o simulador detecta PC não avançou → para
```

A regra: o label `fim:` deve estar na **mesma linha** do `jal x0, fim`. Assim o
PC nunca avança além desse endereço.

**Como detectar no simulador:**

```
riscv> run               # se atingir HALT_LIMIT, não detectou o halt
riscv> reset
riscv> step              # avance manualmente até o final do programa
riscv> reg               # veja o PC — ele está pulando para si mesmo?
```

---

### Erro 6: Constante fora do alcance do imediato de 12 bits

**Sintoma (a):** o assembler reporta erro como `"value of 4096 is too large for
field of 12 bits"` ao tentar montar o programa.

**Sintoma (b):** o programa monta, mas o valor no registrador é diferente do
esperado (geralmente negativo ou menor do que deveria).

**Causa:** o imediato de `addi` é um campo de **12 bits com sinal**, cobrindo o
intervalo de **-2048 a +2047**. Valores fora desse intervalo precisam de `lui`
seguido de `addi`.

```
addi x1, x0, 2048     ← ERRO: 2048 > 2047, fora do alcance
addi x1, x0, -2049    ← ERRO: -2049 < -2048, fora do alcance
addi x1, x0, 2047     ← ok
addi x1, x0, -2048    ← ok
```

**Exemplo errado:**

```asm
    addi  x1, x0, 4096    # ERRO: 4096 = 0x1000, não cabe em 12 bits com sinal
```

**Exemplo correto — `lui` + `addi`:**

```asm
    lui   x1, 1           # x1 = 1 << 12 = 0x00001000 = 4096
    addi  x1, x1, 0       # x1 = 4096 + 0 = 4096   (addi com 0 pode ser omitido)

    # Para o valor 5000 = 0x1388:
    lui   x1, 1           # x1 = 0x00001000 = 4096
    addi  x1, x1, 904     # x1 = 4096 + 904 = 5000
```

**Armadilha do LUI+ADDI com bit 11 em 1:**

`addi` faz extensão de sinal do imediato de 12 bits. Se o bit 11 do valor baixo
estiver em 1 (ou seja, a parte baixa >= 0x800 = 2048), o `addi` vai **subtrair**
em vez de somar, porque o imediato é interpretado como negativo.

```asm
    # Objetivo: carregar 0x12345 em x1
    lui   x1, 0x12        # x1 = 0x00012000
    addi  x1, x1, 0x345   # x1 = 0x00012000 + 0x345 = 0x00012345  ← correto aqui

    # Objetivo: carregar 0x12800 em x1
    lui   x1, 0x12        # x1 = 0x00012000
    addi  x1, x1, 0x800   # 0x800 = 2048 → bit 11 está em 1 → sign-extend = -2048
                          # x1 = 0x00012000 + (-2048) = 0x00011800  ← ERRADO!

    # Correção: some 1 ao argumento do lui para compensar
    lui   x1, 0x13        # x1 = 0x00013000  (0x12 + 1 para compensar o sinal)
    addi  x1, x1, 0x800   # 0x800 com sinal = -2048
                          # x1 = 0x00013000 - 2048 = 0x00012800  ← correto
```

**Como detectar no simulador:**

```
riscv> step              # execute a instrução addi/lui
riscv> reg               # compare o valor obtido com o esperado
```

---

### Erro 7: Stack pointer não inicializado ou inicializado errado

**Sintoma:** ao executar `sw ra, 0(sp)`, o programa escreve sobre a memória de
instruções (no modo Von Neumann) ou o simulador reporta erro. Em modo Harvard,
a dmem é separada, mas `sp = 0` faz com que o topo da pilha conflite com o início
dos dados do programa.

**Causa:** o registrador `sp` (x2) começa em **0** por padrão. Se você usar
`addi sp, sp, -4` e depois `sw ra, 0(sp)`, estará escrevendo no endereço 0xFFFC
(em aritmética de 32 bits sem sinal) — que em Von Neumann sobrescreve instruções,
e em Harvard pula para um endereço inválido da dmem.

A pilha cresce para *baixo* (endereços decrescentes). O `sp` deve começar em um
endereço *alto* e ir diminuindo conforme você empilha valores.

**Exemplo errado:**

```asm
_start:
    # ERRO: sp = 0, nunca foi inicializado
    jal   ra, minha_func   # ra = endereço de retorno
    jal   x0, fim

minha_func:
    addi  sp, sp, -4       # sp = 0 - 4 = 0xFFFFFFFC (wrap-around!)
    sw    ra, 0(sp)        # escreve em 0xFFFFFFFC — fora da memória
    jalr  x0, ra, 0
```

**Exemplo correto:**

```asm
_start:
    addi  sp, x0, 0x400    # sp = 0x400 = 1024 — base da pilha
                           # (ajuste conforme o tamanho da memória do projeto)
    jal   ra, minha_func
    jal   x0, fim

minha_func:
    addi  sp, sp, -4       # sp = 0x400 - 4 = 0x3FC
    sw    ra, 0(sp)        # salva ra em dmem[0x3FC] — seguro
    # ...
    lw    ra, 0(sp)        # restaura ra
    addi  sp, sp, 4        # restaura sp
    jalr  x0, ra, 0
```

Neste projeto, a dmem tem 1 KB (0x0000–0x03FF). Uma boa convenção é inicializar
`sp = 0x400` — o stack começa logo acima do espaço de dados e cresce para baixo.

**Como detectar no simulador:**

```
riscv> reg               # observe sp (x2) — é 0? Precisa ser inicializado
riscv> mem 0x03F0 4      # veja se os dados da pilha foram escritos no lugar certo
```

---

### Erro 8: Condição de branch invertida no loop

**Sintoma (a):** o loop executa **zero vezes** — o corpo do loop é ignorado
completamente.

**Sintoma (b):** o loop roda **para sempre** — a condição de saída nunca é
satisfeita.

**Causa:** confundir qual condição de branch significa "sair do loop" vs "continuar
o loop". O erro mais comum é usar `bge` quando o correto é `blt`, ou vice-versa.

A forma correta é pensar: **"qual é a condição para SAIR do loop?"** e escrever
o branch para o label `fim` com essa condição. O corpo do loop fica logo abaixo,
e no final do corpo há um `jal x0, loop` que volta ao topo.

**Exemplo errado:**

```asm
    addi  x1, x0, 0           # x1 = i = 0
    addi  x2, x0, 10          # x2 = N = 10

loop:
    bge   x2, x1, corpo       # ERRO: "se N >= i, vá para corpo"
                              # com i=0, N=10: 10 >= 0 → true → vai para corpo
                              # Parece certo, mas a lógica está frágil e invertida

    # ...na verdade o erro clássico é esse:
    blt   x2, x1, fim         # "se N < i, sai" — com i=0, N=10: 10 < 0? não → continua
    # isso está CERTO. O erro é quando o aluno escreve a condição de corpo, não de saída:

loop2:
    bge   x1, x2, corpo2      # "se i >= N, vai para corpo" — i=0 >= 10? não → SALTA PARA FIM
                              # corpo2 nunca executa com i=0!

    jal   x0, fim2
corpo2:
    addi  x1, x1, 1
    jal   x0, loop2

fim2:
    jal   x0, fim2
```

**Exemplo correto:**

```asm
    addi  x1, x0, 0           # x1 = i = 0
    addi  x2, x0, 10          # x2 = N = 10

loop:
    bge   x1, x2, fim         # SE i >= N → saiu do range → sair do loop
                              # com i=0, N=10: 0 >= 10? não → continua
    # corpo do loop
    addi  x1, x1, 1           # i++
    jal   x0, loop            # volta ao topo

fim:
    jal   x0, fim
```

**Tabela de referência — condições de saída para loops "i de 0 a N-1":**

| Condição de saída | Branch correto | Leitura |
|---|---|---|
| i >= N | `bge x1, x2, fim` | "se i atingiu ou passou de N, sai" |
| i == N | `beq x1, x2, fim` | "se i chegou exatamente em N, sai" |
| i > N-1 | equivale a `bge` | mesma coisa com N-1 em x2 |

**Como detectar no simulador:**

```
riscv> reg               # veja i e N antes do branch
riscv> step              # veja para onde o branch foi
```

Se no primeiro passo do loop o branch foi para `fim` com `i=0` e `N=10`, a
condição está invertida.

---

### Erro 9: Fall-through após o corpo principal

**Sintoma:** depois que o programa termina sua lógica principal, ele "cai" no
código de alguma função abaixo, executando instruções que não deveriam ser
executadas.

**Causa:** ausência de um salto incondicional para o label `fim` após o bloco
principal do programa. O processador não sabe que o código acabou — ele continua
executando o que vem depois linearmente na memória.

**Exemplo errado:**

```asm
_start:
    addi  sp, x0, 0x400
    addi  a0, x0, 21
    jal   ra, dobra           # chama dobra, a0 = 42

    # ERRO: sem jal x0, fim aqui!
    # O processador continua para a próxima instrução, que é o início de dobra:

dobra:
    add   a0, a0, a0          # executa de novo sem querer! a0 = 84, 168...
    jalr  x0, ra, 0           # ra pode ser lixo agora → pula para lugar aleatório

fim:
    jal   x0, fim
```

**Exemplo correto:**

```asm
_start:
    addi  sp, x0, 0x400
    addi  a0, x0, 21
    jal   ra, dobra           # a0 = 42

    jal   x0, fim             # ESSENCIAL: pula sobre o código das funções

dobra:
    add   a0, a0, a0
    jalr  x0, ra, 0

fim:
    jal   x0, fim
```

**Como detectar no simulador:**

```
riscv> imem 0x0000       # veja todas as instruções e seus endereços
riscv> step              # avance instrução por instrução após a última chamada
riscv> reg               # o PC entrou em uma função sem ter sido chamada?
```

---

### Erro 10: `xori` com máscara errada para NOT de 32 bits

**Sintoma:** ao tentar fazer NOT bit a bit de um valor de 32 bits, apenas os
8 bits menos significativos são invertidos; os outros 24 bits ficam inalterados.

**Causa:** o RISC-V RV32I não tem uma instrução `NOT` dedicada. O NOT é
implementado com XOR com todos os bits em 1. O erro é usar `xori x1, x1, 0xFF`
— isso cria um imediato de 12 bits que vale `0x0FF` (255), que faz XOR apenas
com os 8 bits baixos.

Para inverter todos os 32 bits, o XOR deve ser com `0xFFFFFFFF`. Como o imediato
de 12 bits com valor `-1` é representado como `0xFFF` (todos os 12 bits em 1), e
o RISC-V faz extensão de sinal para 32 bits, `xori x1, x1, -1` expande para
`0xFFFFFFFF` — exatamente o que precisamos.

**Exemplo errado:**

```asm
    addi  x1, x0, 0b11001100  # x1 = 0x000000CC = 0...011001100
    xori  x1, x1, 0xFF        # ERRO: inverte só os 8 bits baixos
                              # x1 = 0x00000033 = 0...000110011
                              # Os bits altos (bits 8-31) não foram tocados!
```

**Exemplo correto:**

```asm
    addi  x1, x0, 0b11001100  # x1 = 0x000000CC
    xori  x1, x1, -1          # NOT 32 bits: -1 expande para 0xFFFFFFFF
                              # x1 = 0xFFFFFF33  (todos os 32 bits invertidos)
```

O assembler também aceita `xori x1, x1, 0xFFF` — mas apenas no contexto de 12
bits. O valor `-1` é mais idiomático e deixa a intenção clara.

**Como detectar no simulador:**

```
riscv> step              # execute o xori
riscv> reg               # observe x1 em hexadecimal — os bits altos foram invertidos?
```

---

## Erros bônus

---

### Bônus 1: Usar `srl` quando precisava de `sra`

**Sintoma:** ao dividir um número negativo por 2 com shift right, o resultado é
um número positivo enorme em vez de um número negativo menor.

**Causa:** `srl` (Shift Right Logical) preenche os bits que entram pela esquerda
com **0**. Para números positivos isso funciona como divisão por 2^n. Mas para
números negativos em complemento de 2, os bits mais significativos devem ser
preenchidos com **1** para manter o sinal — isso é o que `sra` (Shift Right
Arithmetic) faz.

**Exemplo errado:**

```asm
    addi  x1, x0, -8          # x1 = 0xFFFFFFF8 = -8
    srli  x1, x1, 1           # ERRO: preenche com 0
                              # x1 = 0x7FFFFFFC = 2147483644  (resultado absurdo!)
```

**Exemplo correto:**

```asm
    addi  x1, x0, -8          # x1 = 0xFFFFFFF8 = -8
    srai  x1, x1, 1           # shift aritmético: preenche com 1 (mantém sinal)
                              # x1 = 0xFFFFFFFC = -4  (correto: -8 / 2 = -4)
```

---

### Bônus 2: Off-by-one nos limites do array

**Sintoma:** o programa acessa um elemento além do final do array na última
iteração, lendo lixo da memória ou corrompendo outra variável.

**Causa:** um array de N elementos ocupa os índices 0 a N-1. Os endereços vão de
`base + 0` até `base + (N-1)*4`. Usar `i <= N` como condição de continuação
(em vez de `i < N`) faz o loop executar N+1 vezes.

**Exemplo errado:**

```asm
    addi  x2, x0, 5           # N = 5
    addi  x3, x0, 0           # i = 0

loop:
    bgt   x2, x3, corpo       # ERRO: "se N > i, continua" — executa para i=0,1,2,3,4,5
                              # i=5 acessa array[5], que está fora do array!
```

Observação: `bgt` não existe em RV32I; usa-se `blt x3, x2` (i < N). Mas o mesmo
raciocínio vale: a condição deve ser `i < N` (estrito), não `i <= N`.

**Exemplo correto:**

```asm
    addi  x2, x0, 5           # N = 5
    addi  x3, x0, 0           # i = 0

loop:
    bge   x3, x2, fim         # sai quando i >= N (i=5 → sai antes de acessar array[5])
    # corpo do loop
    addi  x3, x3, 1
    jal   x0, loop

fim:
    jal   x0, fim
```

---

### Bônus 3: Confundir `lb` com `lbu`

**Sintoma:** ao carregar um byte com valor >= 128 (por exemplo, o caractere `0xFF`
ou um valor de pixel), o registrador destino fica com um número enorme como
`0xFFFFFF81` em vez de `0x81`.

**Causa:** `lb` (Load Byte) faz **extensão de sinal** — se o bit 7 do byte for 1,
os bits 8–31 do registrador de 32 bits são preenchidos com 1. O resultado parece
um número negativo grande.

`lbu` (Load Byte Unsigned) preenche os bits superiores com **0**, preservando o
valor numérico do byte (0 a 255).

**Exemplo errado:**

```asm
    # dmem[0] contém o byte 0x81 (129)
    lb    x1, 0(x0)           # ERRO para dado sem sinal
                              # x1 = 0xFFFFFF81 = -127 em complemento de 2
```

**Exemplo correto:**

```asm
    # dmem[0] contém o byte 0x81 (129)
    lbu   x1, 0(x0)           # carrega sem extensão de sinal
                              # x1 = 0x00000081 = 129  (correto para dado sem sinal)

    # Use lb apenas quando o dado é genuinamente com sinal (-128 a +127)
    lb    x2, 0(x0)           # adequado se o byte representa um número signed
                              # x2 = -127  (correto se era esse o tipo)
```

---

## Checklist de depuração

Antes de pedir ajuda, percorra este checklist de 5 pontos:

```
[ ] 1. O halt está correto?
        fim: jal x0, fim    ← label e instrução na mesma linha
        (se há jal x0, fim sem este label ser o próprio halt, é erro)

[ ] 2. O stack pointer foi inicializado?
        addi sp, x0, 0x400  ← deve ser a primeira ou segunda instrução
        (se sp = 0 e você usa sw/lw com sp, é erro)

[ ] 3. Todo índice de array foi multiplicado por 4?
        slli xi, xi, 2      ← antes de add com o endereço base
        (para cada lw/sw arr[i], pergunte: xi foi escalado?)

[ ] 4. Todo ra foi salvo antes de chamar outra função?
        se sua função chama outra com jal ra, ..., então:
        addi sp, sp, -4 / sw ra, 0(sp) devem aparecer antes
        lw ra, 0(sp) / addi sp, sp, 4 devem aparecer antes do jalr

[ ] 5. Os valores que cruzam chamadas de função estão em s-registers?
        t0–t6 podem ser destruídos por qualquer chamada
        s0–s11 são preservados pela função chamada
        (se um valor some depois de jal ra, func, verifique qual registrador usa)
```

Se passar neste checklist e o bug continuar: use `step` linha a linha no
simulador, registrando o valor dos registradores relevantes a cada passo.
O simulador não mente — acompanhe o PC e os registradores instrução a instrução
até encontrar o ponto onde o valor diverge do esperado.

---

## Recursos relacionados

- **Tutorial 05** [`05_memoria.md`](05_memoria.md) — acesso a arrays, alinhamento, `slli` para indexação
- **Tutorial 06** [`06_funcoes.md`](06_funcoes.md) — convenção de chamada, pilha, `ra`, caller/callee-saved
- **Exemplos** [`../exemplos/`](../exemplos/) — programas completos e comentados que evitam todos esses erros
- **Simulador** [`../simulator/README.md`](../simulator/README.md) — referência completa dos comandos de depuração
