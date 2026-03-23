# Lista 3 — Exercícios Avançados de Assembly RISC-V

**Nível:** ⭐⭐⭐ Avançado
**Pré-requisito:** Listas 1 e 2 + Tutorial 05 (Memória) + Tutorial 06 (Funções)

---

## Exercício 11 — Soma de array com ponteiro

Escreva um programa que:
1. Inicialize um array de 6 elementos na memória de dados: `[5, 10, 15, 20, 25, 30]`
2. Calcule a soma **usando um ponteiro** que avança pela memória (sem usar índice)
3. Armazene a soma em `x2`

**Resultado esperado:** `x2 = 105`

**Diferença da Lista 2 Ex. 8:** lá somamos 1..N. Aqui lemos da memória com ponteiro.

**Estrutura esperada:**
```asm
x1 = endereço atual (ponteiro)
x5 = endereço do fim do array (base + N*4)
loop: lw x3, 0(x1); add x2, x2, x3; addi x1, x1, 4; blt x1, x5, loop
```

---

## Exercício 12 — Inversão de array in-place

Inverta os elementos de um array **sem usar memória extra** (in-place).

**Array inicial:** `[1, 2, 3, 4, 5]`
**Array final:**   `[5, 4, 3, 2, 1]`

**Algoritmo:** dois ponteiros — um no início, um no fim — avançando em direções opostas:
```
i = 0; j = N-1
while i < j:
    troca array[i] com array[j]
    i++; j--
```

**Dica:** Para trocar array[i] e array[j], você **precisa** de um registrador temporário.

---

## Exercício 13 — Função: dobro de um número

Implemente uma **função** chamada `dobro` que:
- Recebe um argumento em `a0` (x10)
- Retorna o dobro do argumento em `a0`
- Usa a convenção de chamada RISC-V (JAL/JALR)

**Programa principal:**
```
a0 = 7
call dobro   → a0 = 14
a1 = a0      → a1 = 14 (salva para comparar)
a0 = 21
call dobro   → a0 = 42
```

**Resultados esperados:** `x11 = 14`, `x10 = 42`

**Dica:** A função usa `jalr x0, ra, 0` para retornar (ou pseudoinstrução `ret`).

---

## Exercício 14 — Função com múltiplas chamadas: fatorial

Escreva uma função iterativa `fatorial` (usando loop, não recursão) que:
- Recebe N em `a0`
- Retorna N! em `a0`
- Usa JAL para chamar e JALR para retornar

**Teste no main:**
```
a0 = 5; call fatorial → a0 = 120
a1 = a0               → a1 = 120 (salva)
a0 = 3; call fatorial → a0 = 6
```

**Resultados:** `x10 = 6`, `x11 = 120`

**Atenção:** A função modifica `ra` (link register)? Se houver uma chamada aninhada,
`ra` precisa ser salvo na pilha antes de chamar outra função.
Para este exercício, a função é **folha** (não chama outras funções) — salvar ra é opcional.

---

## Exercício 15 — Fibonacci com dois acumuladores e verificação

Escreva um programa completo que:
1. Calcule os primeiros 10 termos de Fibonacci
2. Armazene em memória
3. Verifique se o 7º termo (F(6) = 8) está correto
4. Armazene `x20 = 1` se correto, `x20 = 0` se incorreto

**Array esperado em memória:**
```
F(0)=0, F(1)=1, F(2)=1, F(3)=2, F(4)=3, F(5)=5, F(6)=8, F(7)=13, F(8)=21, F(9)=34
```

**Verificação:** `mem[6*4] == 8` → `x20 = 1`

**Resultado esperado:** `x20 = 1`, `x3 = 34` (último termo calculado)

---

## Verificação dos gabaritos

```bash
# Compilar um gabarito
cd exercicios/lista_03_avancado/gabarito
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex11.o ex11.s
riscv64-unknown-elf-objcopy -O binary ex11.o ex11.bin
python3 ../../../riscv_harvard/scripts/bin2hex.py ex11.bin ex11.hex

# Verificar no simulador
python3 ../../../simulator/riscv_sim.py ex11.hex --run
```

---

**Lista anterior:** [Lista 2 — Intermediário](../lista_02_intermediario/enunciado.md)
