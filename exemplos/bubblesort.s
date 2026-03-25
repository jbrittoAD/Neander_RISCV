# =============================================================================
# Bubble Sort — RISC-V RV32I
# =============================================================================
#
# Sorts an array of integers in ascending order using the Bubble Sort algorithm.
# Ordena um array de inteiros em ordem crescente usando o algoritmo Bubble Sort.
#
# Algorithm:
# Algoritmo:
#   for i from N-1 down to 1:
#   para i de N-1 até 1:
#       for j from 0 to i-1:
#       para j de 0 até i-1:
#           if array[j] > array[j+1]:
#           se array[j] > array[j+1]:
#               swap array[j] with array[j+1]
#               troca array[j] com array[j+1]
#
# This example demonstrates:
# Este exemplo demonstra:
# - Double loop (outer loop + inner loop / loop externo + loop interno)
# - Access to adjacent elements of an array / Acesso a elementos adjacentes de um array
# - Value swap in memory / Troca de valores na memória (swap)
# - Use of registers as indices and pointers / Uso de registradores como índices e ponteiros
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = base address of array / endereço base do array
#   x2  = N (number of elements / número de elementos)
#   x3  = i (outer loop: N-1, N-2, ..., 1 / loop externo: N-1, N-2, ..., 1)
#   x4  = j (inner loop: 0, 1, ..., i-1 / loop interno: 0, 1, ..., i-1)
#   x5  = address of array[j] / endereço de array[j]
#   x6  = array[j]   (current element / elemento atual)
#   x7  = array[j+1] (next element / próximo elemento)
#
# Initial array: [64, 34, 25, 12, 22, 11, 90]
# Array inicial: [64, 34, 25, 12, 22, 11, 90]
# Final array:   [11, 12, 22, 25, 34, 64, 90]
# Array final:   [11, 12, 22, 25, 34, 64, 90]
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/bubblesort.hex
#   riscv> run
#   riscv> mem 0x0000 7     ← should show values in ascending order / deve mostrar os valores em ordem crescente
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialize the array in data memory / Inicializa o array na memória de dados ───
    addi  x1, x0, 0          # x1 = base address / endereço base

    addi  x10, x0, 64
    sw    x10, 0(x1)         # array[0] = 64

    addi  x10, x0, 34
    sw    x10, 4(x1)         # array[1] = 34

    addi  x10, x0, 25
    sw    x10, 8(x1)         # array[2] = 25

    addi  x10, x0, 12
    sw    x10, 12(x1)        # array[3] = 12

    addi  x10, x0, 22
    sw    x10, 16(x1)        # array[4] = 22

    addi  x10, x0, 11
    sw    x10, 20(x1)        # array[5] = 11

    addi  x10, x0, 90
    sw    x10, 24(x1)        # array[6] = 90

    # ─── Outer loop: i from N-1 down to 1 / Loop externo: i de N-1 até 1 ─
    addi  x2, x0, 7          # x2 = N = 7
    addi  x3, x2, -1         # x3 = i = N-1 = 6

loop_externo:
    addi  x11, x0, 1
    blt   x3, x11, fim       # if i < 1, finish / se i < 1, termina

    # ─── Inner loop: j from 0 to i-1 / Loop interno: j de 0 até i-1 ──────
    addi  x4, x0, 0          # x4 = j = 0

loop_interno:
    bge   x4, x3, prox_i     # if j >= i, next outer iteration / se j >= i, próxima iteração externa

    # Calculate address of array[j] and array[j+1] / Calcula endereço de array[j] e array[j+1]
    slli  x8, x4, 2          # x8 = j * 4
    add   x5, x1, x8         # x5 = base + j*4 = &array[j]

    lw    x6, 0(x5)          # x6 = array[j]
    lw    x7, 4(x5)          # x7 = array[j+1]

    # Swap if array[j] > array[j+1] / Troca se array[j] > array[j+1]
    ble   x6, x7, sem_troca  # if array[j] <= array[j+1], no swap / se array[j] <= array[j+1], não troca

    # Swap: array[j] ↔ array[j+1]
    sw    x7, 0(x5)          # array[j] = array[j+1]
    sw    x6, 4(x5)          # array[j+1] = array[j]

sem_troca:
    addi  x4, x4, 1          # j++
    jal   x0, loop_interno

prox_i:
    addi  x3, x3, -1         # i--
    jal   x0, loop_externo

fim:
    # Memory contains: [11, 12, 22, 25, 34, 64, 90]
    # Memória contém: [11, 12, 22, 25, 34, 64, 90]
    jal   x0, fim            # halt
