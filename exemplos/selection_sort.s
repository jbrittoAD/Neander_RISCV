# =============================================================================
# Selection Sort — RISC-V RV32I
# =============================================================================
#
# Sorts an array of 6 integers in ascending order using the Selection Sort
# Ordena um array de 6 inteiros em ordem crescente usando o algoritmo
# algorithm: for each position i, finds the smallest element in [i..n-1]
# Selection Sort: para cada posição i, encontra o menor elemento em [i..n-1]
# and places it at position i (swapping with arr[i]).
# e o coloca na posição i (trocando com arr[i]).
#
# Algorithm:
# Algoritmo:
#   for i from 0 to n-2:
#   para i de 0 até n-2:
#       min_idx = i
#       min_val = arr[i]
#       for j from i+1 to n-1:
#       para j de i+1 até n-1:
#           if arr[j] < min_val:
#           se arr[j] < min_val:
#               min_idx = j
#               min_val = arr[j]
#       swap arr[min_idx] with arr[i]
#       troca arr[min_idx] com arr[i]
#
# This example demonstrates:
# Este exemplo demonstra:
# - Double loop with relative indices (j starts at i+1 / j começa em i+1)
# - Tracking minimum index and value in separate registers
#   Rastreamento de índice e valor mínimo em registradores separados
# - Conditional swap only when min_idx ≠ i
#   Troca condicional (swap) apenas quando min_idx ≠ i
# - Array access by computed address: base + index * 4
#   Acesso ao array por endereço calculado: base + índice * 4
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = base (address 0 of dmem / endereço 0 da dmem)
#   x2  = n = 6 (number of elements / número de elementos)
#   x3  = i (outer loop: 0 .. n-2 / loop externo: 0 .. n-2)
#   x4  = j (inner loop: i+1 .. n-1 / loop interno: i+1 .. n-1)
#   x5  = min_idx (index of the smallest element found / índice do menor elemento encontrado)
#   x6  = min_val (value of the smallest element found / valor do menor elemento encontrado)
#   x7  = elem    (arr[j] being compared / arr[j] sendo comparado)
#   x8  = addr_i  (address of arr[i] / endereço de arr[i])
#   x9  = addr_j  (address of arr[j] / endereço de arr[j])
#   x10 = temp    (auxiliary for the swap / auxiliar para a troca)
#
# Before: [5, 2, 8, 1, 9, 3] in dmem[0..23]
# Antes:  [5, 2, 8, 1, 9, 3] em dmem[0..23]
# After:  [1, 2, 3, 5, 8, 9]
# Depois: [1, 2, 3, 5, 8, 9]
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/selection_sort.hex
#   riscv> run
#   riscv> mem 0x0000 6   ← should show [1, 2, 3, 5, 8, 9] / deve mostrar [1, 2, 3, 5, 8, 9]
# =============================================================================

.section .text
.global _start
_start:
    # ─── Store array [5, 2, 8, 1, 9, 3] in dmem / Armazena array [5, 2, 8, 1, 9, 3] na dmem ───
    addi  x1, x0, 0          # x1 = base address = 0 / endereço base = 0

    addi  x10, x0, 5
    sw    x10,  0(x1)        # dmem[0]  = 5  (index 0 / índice 0)

    addi  x10, x0, 2
    sw    x10,  4(x1)        # dmem[4]  = 2  (index 1 / índice 1)

    addi  x10, x0, 8
    sw    x10,  8(x1)        # dmem[8]  = 8  (index 2 / índice 2)

    addi  x10, x0, 1
    sw    x10, 12(x1)        # dmem[12] = 1  (index 3 / índice 3)

    addi  x10, x0, 9
    sw    x10, 16(x1)        # dmem[16] = 9  (index 4 / índice 4)

    addi  x10, x0, 3
    sw    x10, 20(x1)        # dmem[20] = 3  (index 5 / índice 5)

    # ─── Initialize outer loop / Inicializa loop externo ──────────────────
    addi  x2, x0, 6          # x2 = n = 6 (number of elements / número de elementos)
    addi  x3, x0, 0          # x3 = i = 0 (starts at first position / começa na primeira posição)

    # ─── Outer loop: i from 0 to n-2 / Loop externo: i de 0 até n-2 ──────
loop_externo:
    addi  x10, x2, -1        # x10 = n - 1
    bge   x3, x10, fim       # if i >= n-1, sorting complete / se i >= n-1, ordenação concluída

    # Calculate address of arr[i] / Calcula endereço de arr[i]
    slli  x8, x3, 2          # x8 = i * 4
    add   x8, x1, x8         # x8 = base + i*4 = &arr[i]
    lw    x6, 0(x8)          # x6 = min_val = arr[i]  (initial minimum = arr[i] / mínimo inicial = arr[i])
    add   x5, x0, x3         # x5 = min_idx = i       (minimum index = i / índice do mínimo = i)

    # ─── Inner loop: j from i+1 to n-1 (find minimum) ────────────────────
    # ─── Loop interno: j de i+1 até n-1 (busca o mínimo) ─────────────────
    addi  x4, x3, 1          # x4 = j = i + 1 (starts at next element / começa no elemento seguinte)

loop_interno:
    bge   x4, x2, faz_troca  # if j >= n, scan done → go swap / se j >= n, terminou varredura → vai trocar

    # Calculate address of arr[j] and load value / Calcula endereço de arr[j] e carrega o valor
    slli  x9, x4, 2          # x9 = j * 4
    add   x9, x1, x9         # x9 = base + j*4 = &arr[j]
    lw    x7, 0(x9)          # x7 = elem = arr[j]

    # Compare arr[j] with current minimum / Compara arr[j] com o mínimo atual
    bge   x7, x6, prox_j     # if arr[j] >= min_val, not a new minimum / se arr[j] >= min_val, não é novo mínimo

    # New minimum found: update min_idx and min_val / Novo mínimo encontrado: atualiza min_idx e min_val
    add   x5, x0, x4         # min_idx = j
    add   x6, x0, x7         # min_val = arr[j]

prox_j:
    addi  x4, x4, 1          # j++
    jal   x0, loop_interno   # next inner loop iteration / próxima iteração do loop interno

faz_troca:
    # Check if swap is needed (only if min_idx ≠ i) / Verifica se é necessário trocar (só se min_idx ≠ i)
    beq   x5, x3, prox_i     # if min_idx == i, arr[i] is already minimum, skip swap / se min_idx == i, arr[i] já é o mínimo, pula troca

    # Swap arr[i] with arr[min_idx] / Troca arr[i] com arr[min_idx]
    slli  x9, x5, 2          # x9 = min_idx * 4
    add   x9, x1, x9         # x9 = base + min_idx*4 = &arr[min_idx]

    lw    x10, 0(x8)         # x10 = arr[i]  (read current value of arr[i] / lê valor atual de arr[i])
    lw    x7,  0(x9)         # x7  = arr[min_idx]

    sw    x7,  0(x8)         # arr[i]       = arr[min_idx]  (place minimum at i / coloca mínimo em i)
    sw    x10, 0(x9)         # arr[min_idx] = arr[i]        (place old arr[i] at min_idx / coloca antigo arr[i] em min_idx)

prox_i:
    addi  x3, x3, 1          # i++
    jal   x0, loop_externo   # next outer loop iteration / próxima iteração do loop externo

fim:
    # dmem contains: [1, 2, 3, 5, 8, 9]
    # dmem contém: [1, 2, 3, 5, 8, 9]
    jal   x0, fim            # halt — infinite loop (equivalent to HLT) / loop infinito (equivalente ao HLT)
