# Exercício Capstone — Ordenação + Busca + Soma ⭐⭐⭐⭐⭐

> **Pré-requisito:** Completar as Listas 1–4 (especialmente Ex. 12, 14, 16 e 18)

---

## Descrição

Implemente três funções em assembly RISC-V e um programa principal que as encadeia:

1. **`insertion_sort`** — ordena um array de inteiros em ordem crescente (in-place)
2. **`binary_search`** — busca um valor em array ordenado e retorna o índice
3. **`array_sum`** — soma todos os elementos de um array

---

## Array de entrada

Inicialize na memória de dados a partir do endereço `0` o array:

```
[23, 5, 42, 8, 16, 4, 37, 11]   ← 8 elementos, cada um numa word (4 bytes)
```

---

## Sequência de execução

```
main:
  dmem[0..28] ← [23, 5, 42, 8, 16, 4, 37, 11]
  insertion_sort(base=0, n=8)
  x10 ← binary_search(base=0, n=8, target=23)
  x11 ← array_sum(base=0, n=8)
  halt
```

---

## Resultados esperados

| Registrador / Memória | Valor esperado |
|---|---|
| `x10` | `5` — índice de 23 no array ordenado |
| `x11` | `146` — soma: 4+5+8+11+16+23+37+42 |
| `dmem[0]`…`dmem[28]` | `4, 5, 8, 11, 16, 23, 37, 42` |

---

## Assinatura das funções

### `insertion_sort(a0=base, a1=n)`
- Parâmetros: `a0` = endereço base do array, `a1` = número de elementos
- Retorno: nenhum (modifica memória in-place)
- Deve salvar registradores `s*` usados (callee-saved convention)

### `binary_search(a0=base, a1=n, a2=target) → a0`
- Parâmetros: endereço base, número de elementos, valor a buscar
- Retorno em `a0`: índice do elemento (0-based), ou `-1` se não encontrado
- Pode ser leaf function (usa apenas `t*`)

### `array_sum(a0=base, a1=n) → a0`
- Parâmetros: endereço base, número de elementos
- Retorno em `a0`: soma de todos os elementos
- Pode ser leaf function (usa apenas `t*`)

---

## Dicas

### Insertion Sort

O algoritmo insere cada elemento na posição correta dentro do trecho já ordenado:

```
para i de 1 até n-1:
    key = arr[i]
    j = i - 1
    enquanto j >= 0 e arr[j] > key:
        arr[j+1] = arr[j]
        j--
    arr[j+1] = key
```

### Binary Search

```
lo = 0,  hi = n - 1
enquanto lo <= hi:
    mid = (lo + hi) / 2
    se arr[mid] == target: retorna mid
    se arr[mid] < target:  lo = mid + 1
    senão:                 hi = mid - 1
retorna -1
```

### Convenção de chamada (lembrete)

| Registradores | Papel | Quem salva? |
|---|---|---|
| `a0`–`a7` (x10–x17) | argumentos / retorno | caller |
| `t0`–`t6` (x5–x7, x28–x31) | temporários | caller |
| `s0`–`s11` (x8–x9, x18–x27) | salvos | **callee** |
| `ra` (x1) | endereço de retorno | **callee** (se chamar outra função) |
| `sp` (x2) | ponteiro de pilha | callee |

### Inicializando a pilha

```asm
lui  sp, 1          # sp = 0x1000
addi sp, sp, -256   # sp = 0x0F00  ← longe do array (que começa em 0)
```

### Multiplicação por 4 (índice → endereço)

Como cada word ocupa 4 bytes, converta índice em offset com `slli`:

```asm
slli t0, s2, 2      # t0 = índice × 4
add  t0, base, t0   # t0 = endereço de arr[índice]
```

---

## Verificação automática

```bash
# Compila e executa:
cd exercicios/capstone/gabarito
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o capstone.o capstone.s
riscv64-unknown-elf-objcopy -O binary capstone.o capstone.bin
python3 ../../../riscv_harvard/scripts/bin2hex.py capstone.bin capstone.hex
python3 ../../../simulator/riscv_sim.py capstone.hex --run

# Ou pelo verificador automático (do diretório raiz):
python3 exercicios/verifica_gabaritos.py -v
```

Saída esperada do simulador após `--run`:
```
x10 = 5
x11 = 146
mem[0x0000] = 4
mem[0x0004] = 5
...
mem[0x001C] = 42
```

---

## Por onde depurar

```
riscv> bp 0x??       ← coloque breakpoint no início de insertion_sort
riscv> run           ← executa até o breakpoint
riscv> watch a0      ← monitora argumento/retorno
riscv> step 10       ← avança instrução por instrução
riscv> mem 0x0000 8  ← verifica estado do array a cada etapa
```
