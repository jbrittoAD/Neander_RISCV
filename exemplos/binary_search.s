# =============================================================================
# Binary Search — RISC-V RV32I
# Busca Binária — RISC-V RV32I
# =============================================================================
#
# Stores a sorted array of 10 integers in data memory and performs
# Armazena um array ordenado de 10 inteiros na memória de dados e realiza
# a binary search for the value 23. At the end, the found index is in x3
# uma busca binária pelo valor 23. Ao final, o índice encontrado fica em x3
# and the result flag (1=found, 0=not found) is in x4.
# e a flag de resultado (1=encontrado, 0=não encontrado) fica em x4.
#
# Array: [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
#        indices: 0  1  2   3   4   5   6   7   8   9
#        índices: 0  1  2   3   4   5   6   7   8   9
#
# Binary search algorithm:
# Algoritmo de busca binária:
#   lo = 0,  hi = n-1
#   while lo <= hi:
#   enquanto lo <= hi:
#       mid = (lo + hi) / 2      ← integer division via srl / divisão inteira via srl
#       if arr[mid] == target: found, index = mid / se arr[mid] == alvo: encontrado, índice = mid
#       if arr[mid] <  target: lo = mid + 1    / se arr[mid] <  alvo: lo = mid + 1
#       if arr[mid] >  target: hi = mid - 1    / se arr[mid] >  alvo: hi = mid - 1
#   if lo > hi: not found / se lo > hi: não encontrado
#
# This example demonstrates:
# Este exemplo demonstra:
# - Classic binary search on a sorted array / Busca binária clássica em array ordenado
# - Integer division by 2 via srl (logical right shift) / Divisão inteira por 2 via srl (shift lógico à direita)
# - Indexed access: addr = base + mid * 4 / Acesso indexado: addr = base + mid * 4
# - Use of result flag (found/not found) / Uso de flag de resultado (encontrado/não encontrado)
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = base dmem (address 0 / endereço 0)
#   x2  = target = 23 (value being searched / valor procurado)
#   x3  = result index / índice resultado
#   x4  = found (0 = no, 1 = yes / encontrado: 0 = não, 1 = sim)
#   x5  = lo (lower bound / limite inferior)
#   x6  = hi (upper bound / limite superior)
#   x7  = mid (midpoint / ponto médio)
#   x8  = arr[mid] (element at midpoint / elemento no ponto médio)
#   x9  = temp (address of arr[mid] / endereço de arr[mid])
#
# Array:              [2,5,8,12,16,23,38,56,72,91] in dmem[0..39] / em dmem[0..39]
# Target:             x2 = 23 / Alvo: x2 = 23
# Expected result:    x3 = 5 (index), x4 = 1 (found) / Resultado esperado: x3 = 5 (índice), x4 = 1 (encontrado)
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/binary_search.hex
#   riscv> run
#   riscv> reg        ← x3 should be 5, x4 should be 1 / x3 deve ser 5, x4 deve ser 1
#   riscv> mem 0x0000 10  ← shows the array in memory / mostra o array na memória
# =============================================================================

.section .text
.global _start
_start:
    # ─── Store array [2,5,8,12,16,23,38,56,72,91] in dmem ─────────────────
    # ─── Armazena array [2,5,8,12,16,23,38,56,72,91] na dmem ─────────────
    addi  x1, x0, 0          # x1 = base address = 0 / endereço base = 0

    addi  x9, x0, 2
    sw    x9,  0(x1)         # dmem[0]  = 2   (index 0 / índice 0)

    addi  x9, x0, 5
    sw    x9,  4(x1)         # dmem[4]  = 5   (index 1 / índice 1)

    addi  x9, x0, 8
    sw    x9,  8(x1)         # dmem[8]  = 8   (index 2 / índice 2)

    addi  x9, x0, 12
    sw    x9, 12(x1)         # dmem[12] = 12  (index 3 / índice 3)

    addi  x9, x0, 16
    sw    x9, 16(x1)         # dmem[16] = 16  (index 4 / índice 4)

    addi  x9, x0, 23
    sw    x9, 20(x1)         # dmem[20] = 23  (index 5 / índice 5)

    addi  x9, x0, 38
    sw    x9, 24(x1)         # dmem[24] = 38  (index 6 / índice 6)

    addi  x9, x0, 56
    sw    x9, 28(x1)         # dmem[28] = 56  (index 7 / índice 7)

    addi  x9, x0, 72
    sw    x9, 32(x1)         # dmem[32] = 72  (index 8 / índice 8)

    addi  x9, x0, 91
    sw    x9, 36(x1)         # dmem[36] = 91  (index 9 / índice 9)

    # ─── Initialize binary search / Inicializa busca binária ──────────────
    addi  x2, x0, 23         # x2 = target = 23 / alvo = 23
    addi  x3, x0, 0          # x3 = result index = 0 (undefined / indefinido)
    addi  x4, x0, 0          # x4 = found = 0 (not found by default / não encontrado por padrão)
    addi  x5, x0, 0          # x5 = lo = 0 (lower bound / limite inferior)
    addi  x6, x0, 9          # x6 = hi = 9 (upper bound, n-1 / limite superior, n-1)

    # ─── Binary search loop / Loop de busca binária ───────────────────────
busca:
    bgt   x5, x6, nao_encontrado  # if lo > hi, not in array / se lo > hi, não existe no array

    # Calculate mid = (lo + hi) / 2 via logical right shift / Calcula mid = (lo + hi) / 2 via shift lógico à direita
    add   x7, x5, x6         # x7 = lo + hi
    srli  x7, x7, 1          # x7 = (lo + hi) / 2  (integer division by 2 / divisão inteira por 2)

    # Calculate address of arr[mid] = base + mid * 4 / Calcula endereço de arr[mid] = base + mid * 4
    slli  x9, x7, 2          # x9 = mid * 4  (each element occupies 4 bytes / cada elemento ocupa 4 bytes)
    add   x9, x1, x9         # x9 = base + mid*4  (address of arr[mid] / endereço de arr[mid])
    lw    x8, 0(x9)          # x8 = arr[mid]

    beq   x8, x2, encontrado # if arr[mid] == target, found! / se arr[mid] == alvo, encontrou!

    blt   x8, x2, metade_dir # if arr[mid] < target, search right half / se arr[mid] < alvo, busca na metade direita

    # arr[mid] > target → search left half: hi = mid - 1
    # arr[mid] > alvo → busca na metade esquerda: hi = mid - 1
    addi  x6, x7, -1         # hi = mid - 1
    jal   x0, busca          # repeat the search / repete a busca

metade_dir:
    # arr[mid] < target → search right half: lo = mid + 1
    # arr[mid] < alvo → busca na metade direita: lo = mid + 1
    addi  x5, x7, 1          # lo = mid + 1
    jal   x0, busca          # repeat the search / repete a busca

encontrado:
    add   x3, x0, x7         # x3 = index = mid / índice = mid
    addi  x4, x0, 1          # x4 = found = 1 / encontrado = 1
    jal   x0, fim            # go to halt / vai para o halt

nao_encontrado:
    addi  x3, x0, -1         # x3 = -1 (invalid index / índice inválido)
    addi  x4, x0, 0          # x4 = found = 0 (not found / não encontrado)

fim:
    # x3 = 5 (index of 23 / índice de 23), x4 = 1 (found / encontrado)
    jal   x0, fim            # halt — infinite loop (equivalent to HLT) / loop infinito (equivalente ao HLT)
