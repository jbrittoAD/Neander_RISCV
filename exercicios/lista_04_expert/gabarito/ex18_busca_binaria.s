# =============================================================================
# Gabarito — Lista 4, Exercício 18: Busca Binária (função)
# Answer key — List 4, Exercise 18: Binary Search (function)
# =============================================================================
# Description / Descrição:
#   Stores the sorted array [2,5,8,12,16,23,38,56,72,91] in data memory
#   and performs binary search for the value 38. Result is index 6.
#
#   Armazena o array ordenado [2,5,8,12,16,23,38,56,72,91] na memória de dados
#   e realiza busca binária pelo valor 38. O resultado é o índice 6.
#
#   The busca_binaria function is a leaf function (calls no other functions),
#   so it does not need to save ra on the stack.
#
#   A função busca_binaria é uma função folha (não chama outras funções),
#   portanto não precisa salvar ra na pilha.
#
# Register map (main) / Mapa de registradores (main):
#   s0  (x8)  — search result (found index or -1) / resultado da busca (índice encontrado ou -1)
#
# Register map (busca_binaria) / Mapa de registradores (busca_binaria):
#   a0  (x10) — array base address / endereço base do array
#   a1  (x11) — number of elements n / número de elementos n
#   a2  (x12) — target value / valor alvo (target)
#   t0  (x5)  — lo (lower index / índice inferior)
#   t1  (x6)  — hi (upper index = n-1 / índice superior = n-1)
#   t2  (x7)  — mid (middle index / índice do meio)
#   t3  (x28) — calculated address of mid element / endereço calculado do elemento mid
#   t4  (x29) — element read from memory (array[mid]) / elemento lido da memória (array[mid])
#   Return: a0 = found index, or -1 if not found / Retorno: a0 = índice encontrado, ou -1 se não encontrado
#
# Data memory (addresses 0x00..0x27, 4 bytes each) / Memória de dados (endereços 0x00..0x27, 4 bytes cada):
#   [0x00]=2, [0x04]=5, [0x08]=8, [0x0C]=12, [0x10]=16,
#   [0x14]=23, [0x18]=38, [0x1C]=56, [0x20]=72, [0x24]=91
#
# Expected result / Resultado esperado:
#   s0 (x8) = 6  (index of value 38 in the array / índice do valor 38 no array)
#
# How to verify / Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex18.o ex18_busca_binaria.s
#   riscv64-unknown-elf-objcopy -O binary ex18.o ex18.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex18.bin ex18.hex
#   python3 ../../../../simulator/riscv_sim.py ex18.hex --run
#   # Verify: s0 (x8) = 6 / Verificar: s0 (x8) = 6
# =============================================================================

.section .text
.global _start

_start:
    # ── Initialize the sorted array in data memory / Inicializa o array ordenado na memória de dados ───────────────────────
    addi t0, x0, 0        # t0 = base address = 0 / endereço base = 0

    addi t1, x0, 2        # value 2  (index 0 / índice 0)
    sw   t1, 0(t0)        # mem[0]  = 2

    addi t1, x0, 5        # value 5  (index 1 / índice 1)
    sw   t1, 4(t0)        # mem[4]  = 5

    addi t1, x0, 8        # value 8  (index 2 / índice 2)
    sw   t1, 8(t0)        # mem[8]  = 8

    addi t1, x0, 12       # value 12 (index 3 / índice 3)
    sw   t1, 12(t0)       # mem[12] = 12

    addi t1, x0, 16       # value 16 (index 4 / índice 4)
    sw   t1, 16(t0)       # mem[16] = 16

    addi t1, x0, 23       # value 23 (index 5 / índice 5)
    sw   t1, 20(t0)       # mem[20] = 23

    addi t1, x0, 38       # value 38 (index 6 / índice 6)
    sw   t1, 24(t0)       # mem[24] = 38

    addi t1, x0, 56       # value 56 (index 7 / índice 7)
    sw   t1, 28(t0)       # mem[28] = 56

    addi t1, x0, 72       # value 72 (index 8 / índice 8)
    sw   t1, 32(t0)       # mem[32] = 72

    addi t1, x0, 91       # value 91 (index 9 / índice 9)
    sw   t1, 36(t0)       # mem[36] = 91

    # ── Prepare arguments and call busca_binaria / Prepara argumentos e chama busca_binaria ──────────────────────────────
    addi a0, x0, 0        # a0 = array base address = 0 / endereço base do array = 0
    addi a1, x0, 10       # a1 = number of elements = 10 / número de elementos = 10
    addi a2, x0, 38       # a2 = value to search for = 38 / valor procurado = 38

    jal  ra, busca_binaria        # call function — return in a0 / chama a função — retorno em a0

    addi s0, a0, 0        # s0 = found index (final result / resultado final)

    jal  x0, fim          # halt / parada

# =============================================================================
# Function: busca_binaria  (leaf function — no need to save ra)
# Função: busca_binaria    (função folha — não precisa salvar ra)
# Input / Entrada:
#   a0 = array base address (sorted 32-bit integers) / endereço base do array (inteiros de 32 bits, ordenados)
#   a1 = number of elements n / número de elementos n
#   a2 = target value / valor alvo (target)
# Output / Saída:
#   a0 = index of found element, or -1 if not found
#   a0 = índice do elemento encontrado, ou -1 se não encontrado
# Registers used (temporaries — not preserved):
# Registradores usados (temporários — não preservados):
#   t0=lo, t1=hi, t2=mid, t3=address of mid, t4=element read
#   t0=lo, t1=hi, t2=mid, t3=endereço do mid, t4=elemento lido
# =============================================================================
busca_binaria:
    addi t0, x0, 0        # t0 = lo = 0  (lower index / índice inferior)
    addi t1, a1, -1       # t1 = hi = n-1  (upper index / índice superior)

bb_loop:
    bgt  t0, t1, bb_nao_encontrado   # if lo > hi, not found / se lo > hi, não encontrou

    # Compute mid = (lo + hi) >> 1  (integer division by 2)
    # Calcula mid = (lo + hi) >> 1  (divisão inteira por 2)
    add  t2, t0, t1       # t2 = lo + hi
    srli t2, t2, 1        # t2 = (lo + hi) / 2  (mid)

    # Compute address of mid element: base + mid * 4
    # Calcula endereço do elemento mid: base + mid * 4
    slli t3, t2, 2        # t3 = mid * 4  (each element occupies 4 bytes / cada elemento ocupa 4 bytes)
    add  t3, a0, t3       # t3 = base + mid*4  (address of array[mid] / endereço de array[mid])
    lw   t4, 0(t3)        # t4 = array[mid]

    beq  t4, a2, bb_encontrado    # if array[mid] == target, found! / se array[mid] == target, achou!

    blt  t4, a2, bb_menor         # if array[mid] < target, search right / se array[mid] < target, busca à direita

    # array[mid] > target: search left / busca à esquerda
    addi t1, t2, -1       # hi = mid - 1
    jal  x0, bb_loop      # continue / continua

bb_menor:
    addi t0, t2, 1        # lo = mid + 1
    jal  x0, bb_loop      # continue / continua

bb_encontrado:
    addi a0, t2, 0        # a0 = mid  (index of found element / índice do elemento encontrado)
    jalr x0, ra, 0        # return to caller / retorna para o chamador

bb_nao_encontrado:
    addi a0, x0, -1       # a0 = -1  (not found / não encontrado)
    jalr x0, ra, 0        # return to caller / retorna para o chamador

fim:
    jal x0, fim           # halt — infinite loop (equivalent to HLT) / parada — loop infinito (equivalente ao HLT)
