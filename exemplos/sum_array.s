# =============================================================================
# Sum of an Array — RISC-V RV32I
# Soma de um array — RISC-V RV32I
# =============================================================================
#
# Sums all elements of an integer array stored in memory.
# Soma todos os elementos de um array de inteiros armazenado na memória.
# Demonstrates a loop with sequential memory access and an accumulator.
# Demonstra laço com acesso sequencial à memória e acumulador.
#
# Equivalent in C:
# Equivalente em C:
#   int arr[] = {10, 20, 30, 40, 50};
#   int soma = 0;
#   for (int i = 0; i < 5; i++) soma += arr[i];
#   // soma == 150
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = base address of array / endereço base do array
#   x2  = number of elements (N) / número de elementos (N)
#   x3  = remaining elements counter (countdown: N, N-1, ..., 1)
#         contador de elementos restantes (conta regressiva: N, N-1, ..., 1)
#   x4  = accumulated sum / soma acumulada
#   x5  = pointer to current element (advances by 4) / ponteiro para elemento atual (avança de 4 em 4)
#
# Array: [10, 20, 30, 40, 50] → sum = 150 / soma = 150
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/sum_array.hex
#   riscv> run
#   riscv> reg             ← x4 = 150
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialize the array in data memory / Inicializa o array na memória de dados ───
    addi  x1, x0, 0          # x1 = base address / endereço base

    addi  x10, x0, 10
    sw    x10, 0(x1)         # array[0] = 10

    addi  x10, x0, 20
    sw    x10, 4(x1)         # array[1] = 20

    addi  x10, x0, 30
    sw    x10, 8(x1)         # array[2] = 30

    addi  x10, x0, 40
    sw    x10, 12(x1)        # array[3] = 40

    addi  x10, x0, 50
    sw    x10, 16(x1)        # array[4] = 50

    # ─── Sum loop / Loop de soma ──────────────────────────────────────────
    addi  x2, x0, 5          # x2 = N = 5
    addi  x3, x0, 5          # x3 = counter = N (countdown / conta regressiva)
    addi  x4, x0, 0          # x4 = sum = 0 / soma = 0
    addi  x5, x1, 0          # x5 = pointer = base / ponteiro = base

loop:
    beq   x3, x0, fim        # if counter == 0, finish / se contador == 0, termina

    lw    x6, 0(x5)          # x6 = *x5  (current element / elemento atual)
    add   x4, x4, x6         # sum += element / soma += elemento

    addi  x5, x5, 4          # advance pointer to next element / avança ponteiro para próximo elemento
    addi  x3, x3, -1         # counter-- / contador--

    jal   x0, loop

fim:
    # x4 = 150 (10 + 20 + 30 + 40 + 50)
    jal   x0, fim            # halt
