# Lista 4 — Exercícios Expert de Assembly RISC-V

**Nível:** ⭐⭐⭐⭐ Expert
**Pré-requisito:** Listas 1, 2 e 3 + conhecimento de pilha e convenção de chamada RISC-V

---

## Exercício 16 — Fibonacci recursivo com pilha

Implemente Fibonacci recursivo usando a pilha e a convenção de chamada RISC-V:

```
fib(n):
    se n <= 1: retorna n
    retorna fib(n-1) + fib(n-2)
```

**Convenção de chamada:**
- Argumento em `a0` (x10); retorno em `a0`
- `ra` (x1) e todos os registradores `s0–s11` que a função modificar **devem ser salvos e restaurados na pilha**
- `sp` (x2) deve ser mantido consistente (frame de tamanho fixo por chamada)

**Estrutura do frame (12 bytes):**
```
sp+8 → ra   (endereço de retorno)
sp+4 → s0   (guarda n)
sp+0 → s1   (guarda fib(n-1) entre as duas chamadas recursivas)
```

**Por que s1 e não t1?** Registradores `t0–t6` são caller-saved (o chamador não pode
confiar que eles sobrevivem a uma chamada de função). `s0–s11` são callee-saved:
a função chamada os preserva. Portanto, para guardar `fib(n-1)` entre as duas
chamadas recursivas, é obrigatório usar um registrador `s` (e salvá-lo na pilha).

**Inicialização:**
```asm
addi sp, x0, 0x400   # sp = 1024 (topo da pilha)
addi a0, x0, 8       # n = 8
jal  ra, fib         # chama fib(8)
```

**Resultado esperado:** `x10 = 21`  (fib(8) = 21)

---

## Exercício 17 — Fatorial recursivo (com multiplicação por somas)

Implemente fatorial recursivo. Como RV32I **não possui instrução `mul`**, a
multiplicação `n × fat(n-1)` deve ser feita por **soma repetida**:

```
fat(n):
    se n <= 1: retorna 1
    retorna n * fat(n-1)   # calcule n×x via: acc=0; repita n vezes: acc+=x
```

**Frame (8 bytes):**
```
sp+4 → ra  (endereço de retorno)
sp+0 → s0  (guarda n)
```

**Inicialização:**
```asm
addi sp, x0, 0x400   # sp = 1024
addi a0, x0, 6       # n = 6
jal  ra, fat
```

**Resultado esperado:** `x10 = 720`  (6! = 720)

---

## Exercício 18 — Busca binária (função folha)

Implemente busca binária como uma **função folha** (sem chamadas internas,
portanto sem necessidade de salvar `ra` na pilha).

**Array na memória de dados:** `[2, 5, 8, 12, 16, 23, 38, 56, 72, 91]`
(10 inteiros de 32 bits, nos endereços 0x00..0x27)

**Assinatura da função:**
```
busca_binaria(base, n, target) → índice  (ou -1 se não encontrado)
  a0 = endereço base do array
  a1 = número de elementos (10)
  a2 = valor procurado (38)
  retorno: a0 = índice encontrado
```

**Algoritmo:**
```
lo = 0;  hi = n-1
enquanto lo <= hi:
    mid = (lo + hi) >> 1
    se array[mid] == target: retorna mid
    se array[mid] < target:  lo = mid+1
    senão:                   hi = mid-1
retorna -1
```

**Dica:** `endereço de array[mid] = base + mid * 4`  (use `slli mid, mid, 2`)

**Resultado esperado:** `s0 (x8) = 6`  (índice do valor 38 no array)

---

## Exercício 19 — Inversão de string in-place

Armazene a string `"ABCDE\0"` na memória de dados byte a byte (usando `sb`),
calcule seu comprimento e inverta os caracteres **in-place**, sem buffer auxiliar.

**Algoritmo:**
1. Grava `"ABCDE\0"` byte a byte em dmem[0..5]
2. Calcula comprimento: percorre até byte nulo → comprimento = 5
3. Inversão com dois ponteiros:
   ```
   esquerda = 0;  direita = comprimento - 1
   enquanto esquerda < direita:
       troca dmem[esquerda] com dmem[direita]
       esquerda++;  direita--
   ```

**Resultado esperado:**
- `x2 = 5`  (comprimento da string)
- `dmem[0..5] = {0x45, 0x44, 0x43, 0x42, 0x41, 0x00}`  → `"EDCBA\0"`

**Verificação da memória no simulador:**
```
riscv> run
riscv> mem 0x0000 2
```

---

## Exercício 20 — MMC (Mínimo Múltiplo Comum)

Calcule `MMC(12, 18)` usando apenas subtrações e somas (sem `mul`, `div` ou `rem`).

**Identidade matemática:** `mmc(a, b) = (a / mdc(a, b)) × b`

**Três passos, todos sem divisão ou multiplicação:**

**Passo 1 — MDC via subtração de Euclides:**
```
enquanto a != b:
    se a > b: a = a - b
    senão:    b = b - a
→ mdc = a (= b)
```

**Passo 2 — Divisão a/mdc via subtração repetida:**
```
q = 0;  tmp = a_original
enquanto tmp >= mdc:  tmp -= mdc;  q++
→ q = a / mdc
```

**Passo 3 — Multiplicação q×b via soma repetida:**
```
produto = 0
repita q vezes:  produto += b_original
→ mmc = produto
```

**Entrada:** `x1 = 12`, `x2 = 18`

**Resultado esperado:** `x3 = 36`  (MMC(12, 18) = 36)

---

## Verificação dos gabaritos

```bash
# Compila e testa um gabarito
cd exercicios/lista_04_expert/gabarito
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex16.o ex16_fib_recursivo.s
riscv64-unknown-elf-objcopy -O binary ex16.o ex16.bin
python3 ../../../riscv_harvard/scripts/bin2hex.py ex16.bin ex16.hex
python3 ../../../simulator/riscv_sim.py ex16.hex --run

# Ou compila todos de uma vez
for f in ex16_fib_recursivo ex17_fat_recursivo ex18_busca_binaria ex19_string_reversa ex20_mmc; do
  riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ${f}.o ${f}.s
  riscv64-unknown-elf-objcopy -O binary ${f}.o ${f}.bin
  python3 ../../../riscv_harvard/scripts/bin2hex.py ${f}.bin ${f}.hex
  echo "=== $f ===" && python3 ../../../simulator/riscv_sim.py ${f}.hex --run
done
```

---

**Lista anterior:** [Lista 3 — Avançado](../lista_03_avancado/enunciado.md)
