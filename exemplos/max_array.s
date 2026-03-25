# =============================================================================
# Maximum of an Array — RISC-V RV32I
# Máximo de um array — RISC-V RV32I
# =============================================================================
#
# Finds the largest element of an integer array stored in memory.
# Encontra o maior elemento de um array de inteiros armazenado na memória.
#
# The array is initialized by the program itself with SW (store word).
# O array é inicializado pelo próprio programa com SW (store word).
# This demonstrates: memory initialization, loop with indexed access, and
# Isso demonstra: inicialização de memória, laço com acesso indexado e
# comparison with conditional branch (equivalent to JN in Neander).
# comparação com desvio condicional (equivalente ao JN do Neander).
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = base address of array / endereço base do array
#   x2  = number of elements (N) / número de elementos (N)
#   x3  = index i (loop counter) / índice i (contador do loop)
#   x4  = maximum value found so far / valor máximo encontrado até agora
#   x5  = address of current element = x1 + i*4 / endereço do elemento atual = x1 + i*4
#   x6  = value of current element (read from memory / lido da memória)
#
# Test array (5 elements): [3, 17, 8, 42, 11]
# Array de teste (5 elementos): [3, 17, 8, 42, 11]
# Expected result: x4 = 42
#
# Memory mapping:
# Mapeamento de memória:
#   mem[0x0000] = 3
#   mem[0x0004] = 17
#   mem[0x0008] = 8
#   mem[0x000C] = 42
#   mem[0x0010] = 11
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/max_array.hex
#   riscv> run
#   riscv> reg             ← x4 = 42
#   riscv> mem 0x0000 5    ← confirms array in memory / confirma array na memória
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialize the array in data memory / Inicializa o array na memória de dados ───
    addi  x1, x0, 0          # x1 = base address = 0x0000 / endereço base = 0x0000

    addi  x10, x0, 3         # element 0 / elemento 0
    sw    x10, 0(x1)

    addi  x10, x0, 17        # element 1 / elemento 1
    sw    x10, 4(x1)

    addi  x10, x0, 8         # element 2 / elemento 2
    sw    x10, 8(x1)

    addi  x10, x0, 42        # element 3 / elemento 3
    sw    x10, 12(x1)

    addi  x10, x0, 11        # element 4 / elemento 4
    sw    x10, 16(x1)

    # ─── Configure loop parameters / Configura parâmetros do loop ─────────
    addi  x2, x0, 5          # x2 = N = 5 elements / 5 elementos
    addi  x3, x0, 0          # x3 = i = 0

    # Initialize maximum with the first element / Inicializa máximo com o primeiro elemento
    lw    x4, 0(x1)          # x4 = max = array[0] = 3
    addi  x3, x0, 1          # start comparing from index 1 / começa comparando do índice 1

loop:
    bge   x3, x2, fim        # if i >= N, done / se i >= N, acabou

    # Calculate address of element i: addr = base + i*4
    # Calcula endereço do elemento i: addr = base + i*4
    slli  x5, x3, 2          # x5 = i * 4  (shift left 2 = multiply by 4 / multiplica por 4)
    add   x5, x1, x5         # x5 = base + i*4

    lw    x6, 0(x5)          # x6 = array[i]

    # Update maximum if array[i] > max / Atualiza máximo se array[i] > max
    bge   x4, x6, nao_troca  # if max >= array[i], no update / se max >= array[i], não troca
    addi  x4, x6, 0          # max = array[i]  (new maximum / novo máximo)

nao_troca:
    addi  x3, x3, 1          # i++
    jal   x0, loop

fim:
    # x4 = maximum = 42 / máximo = 42
    jal   x0, fim            # halt
