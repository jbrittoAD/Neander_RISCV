# =============================================================================
# Capstone: Insertion Sort + Binary Search + Soma de Array
# =============================================================================
# Algoritmo:
#   1. Inicializa array [23,5,42,8,16,4,37,11] na memória de dados (endereço 0)
#   2. Chama insertion_sort  → ordena in-place: [4,5,8,11,16,23,37,42]
#   3. Chama binary_search   → encontra 23 → retorna índice 5
#   4. Chama array_sum       → soma = 146
#
# Resultados finais:
#   x10 = 5   (índice de 23 no array ordenado)
#   x11 = 146 (soma de todos os elementos)
#   dmem[0..28] = [4,5,8,11,16,23,37,42]
# =============================================================================

.text
.globl _start

_start:
    # Inicializa pilha em 0xF00
    lui  sp, 1
    addi sp, sp, -256

    # Preenche array na memória de dados a partir do endereço 0
    addi t0, x0, 0

    addi t1, x0, 23
    sw   t1,  0(t0)
    addi t1, x0, 5
    sw   t1,  4(t0)
    addi t1, x0, 42
    sw   t1,  8(t0)
    addi t1, x0, 8
    sw   t1, 12(t0)
    addi t1, x0, 16
    sw   t1, 16(t0)
    addi t1, x0, 4
    sw   t1, 20(t0)
    addi t1, x0, 37
    sw   t1, 24(t0)
    addi t1, x0, 11
    sw   t1, 28(t0)

    # --- Etapa 1: ordena o array ---
    addi a0, x0, 0          # base = 0
    addi a1, x0, 8          # n = 8
    jal  ra, insertion_sort

    # --- Etapa 2: busca binária por 23 ---
    addi a0, x0, 0          # base = 0
    addi a1, x0, 8          # n = 8
    addi a2, x0, 23         # alvo = 23
    jal  ra, binary_search
    addi s0, a0, 0          # salva índice (s0 é callee-saved)

    # --- Etapa 3: soma de todos os elementos ---
    addi a0, x0, 0          # base = 0
    addi a1, x0, 8          # n = 8
    jal  ra, array_sum

    addi x11, a0, 0         # x11 = soma = 146  (a0 antes de sobrescrever)
    addi x10, s0, 0         # x10 = índice de 23 = 5

halt:
    jal  x0, halt

# =============================================================================
# insertion_sort(a0=base, a1=n)
# Ordena array de n words a partir de base em ordem crescente (in-place).
# Registradores salvos: ra, s0-s4 (frame de 24 bytes)
# =============================================================================
insertion_sort:
    addi sp, sp, -24
    sw   ra, 20(sp)
    sw   s0, 16(sp)
    sw   s1, 12(sp)
    sw   s2,  8(sp)
    sw   s3,  4(sp)
    sw   s4,  0(sp)

    addi s0, a0, 0          # s0 = base
    addi s1, a1, 0          # s1 = n
    addi s2, x0, 1          # i = 1

is_outer:
    bge  s2, s1, is_done    # se i >= n, termina

    # key = arr[i]
    slli t0, s2, 2          # offset = i * 4
    add  t0, s0, t0         # &arr[i]
    lw   s3, 0(t0)          # s3 = key

    addi s4, s2, -1         # j = i - 1

is_inner:
    blt  s4, x0, is_insert  # se j < 0, insere

    slli t0, s4, 2          # offset = j * 4
    add  t0, s0, t0         # &arr[j]
    lw   t1, 0(t0)          # t1 = arr[j]

    bge  s3, t1, is_insert  # se key >= arr[j], ponto de inserção

    # arr[j+1] = arr[j]  (desloca um passo para a direita)
    sw   t1, 4(t0)
    addi s4, s4, -1         # j--
    jal  x0, is_inner

is_insert:
    addi t0, s4, 1          # índice de inserção = j + 1
    slli t0, t0, 2
    add  t0, s0, t0
    sw   s3, 0(t0)          # arr[j+1] = key

    addi s2, s2, 1          # i++
    jal  x0, is_outer

is_done:
    lw   ra, 20(sp)
    lw   s0, 16(sp)
    lw   s1, 12(sp)
    lw   s2,  8(sp)
    lw   s3,  4(sp)
    lw   s4,  0(sp)
    addi sp, sp, 24
    jalr x0, ra, 0

# =============================================================================
# binary_search(a0=base, a1=n, a2=target) → a0 = índice  (-1 se não encontrado)
# Leaf function — usa apenas t-regs.
# =============================================================================
binary_search:
    addi t0, x0, 0          # lo = 0
    addi t1, a1, -1         # hi = n - 1

bs_loop:
    blt  t1, t0, bs_notfound  # se hi < lo, não encontrado

    add  t2, t0, t1
    srli t2, t2, 1          # mid = (lo + hi) / 2

    slli t3, t2, 2
    add  t3, a0, t3
    lw   t4, 0(t3)          # t4 = arr[mid]

    beq  t4, a2, bs_found
    blt  t4, a2, bs_right   # arr[mid] < target → busca à direita

    # arr[mid] > target → hi = mid - 1
    addi t1, t2, -1
    jal  x0, bs_loop

bs_right:
    addi t0, t2, 1          # lo = mid + 1
    jal  x0, bs_loop

bs_found:
    addi a0, t2, 0          # retorna mid
    jalr x0, ra, 0

bs_notfound:
    addi a0, x0, -1         # retorna -1
    jalr x0, ra, 0

# =============================================================================
# array_sum(a0=base, a1=n) → a0 = soma de todos os elementos
# Leaf function — usa apenas t-regs.
# =============================================================================
array_sum:
    addi t0, x0, 0          # soma = 0
    addi t1, x0, 0          # i = 0

as_loop:
    bge  t1, a1, as_done

    slli t2, t1, 2
    add  t2, a0, t2
    lw   t3, 0(t2)          # t3 = arr[i]
    add  t0, t0, t3         # soma += arr[i]
    addi t1, t1, 1          # i++
    jal  x0, as_loop

as_done:
    addi a0, t0, 0          # retorna soma
    jalr x0, ra, 0
