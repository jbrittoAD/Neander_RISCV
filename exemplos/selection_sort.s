# =============================================================================
# Selection Sort — RISC-V RV32I
# =============================================================================
#
# Ordena um array de 6 inteiros em ordem crescente usando o algoritmo
# Selection Sort: para cada posição i, encontra o menor elemento em [i..n-1]
# e o coloca na posição i (trocando com arr[i]).
#
# Algoritmo:
#   para i de 0 até n-2:
#       min_idx = i
#       min_val = arr[i]
#       para j de i+1 até n-1:
#           se arr[j] < min_val:
#               min_idx = j
#               min_val = arr[j]
#       troca arr[min_idx] com arr[i]
#
# Este exemplo demonstra:
# - Loop duplo com índices relativos (j começa em i+1)
# - Rastreamento de índice e valor mínimo em registradores separados
# - Troca condicional (swap) apenas quando min_idx ≠ i
# - Acesso ao array por endereço calculado: base + índice * 4
#
# Mapeamento de registradores:
#   x1  = base (endereço 0 da dmem)
#   x2  = n = 6 (número de elementos)
#   x3  = i (loop externo: 0 .. n-2)
#   x4  = j (loop interno: i+1 .. n-1)
#   x5  = min_idx (índice do menor elemento encontrado)
#   x6  = min_val (valor do menor elemento encontrado)
#   x7  = elem    (arr[j] sendo comparado)
#   x8  = addr_i  (endereço de arr[i])
#   x9  = addr_j  (endereço de arr[j])
#   x10 = temp    (auxiliar para a troca)
#
# Antes:  [5, 2, 8, 1, 9, 3] em dmem[0..23]
# Depois: [1, 2, 3, 5, 8, 9]
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/selection_sort.hex
#   riscv> run
#   riscv> mem 0x0000 6   ← deve mostrar [1, 2, 3, 5, 8, 9]
# =============================================================================

.section .text
.global _start
_start:
    # ─── Armazena array [5, 2, 8, 1, 9, 3] na dmem ───────────────────
    addi  x1, x0, 0          # x1 = endereço base = 0

    addi  x10, x0, 5
    sw    x10,  0(x1)        # dmem[0]  = 5  (índice 0)

    addi  x10, x0, 2
    sw    x10,  4(x1)        # dmem[4]  = 2  (índice 1)

    addi  x10, x0, 8
    sw    x10,  8(x1)        # dmem[8]  = 8  (índice 2)

    addi  x10, x0, 1
    sw    x10, 12(x1)        # dmem[12] = 1  (índice 3)

    addi  x10, x0, 9
    sw    x10, 16(x1)        # dmem[16] = 9  (índice 4)

    addi  x10, x0, 3
    sw    x10, 20(x1)        # dmem[20] = 3  (índice 5)

    # ─── Inicializa loop externo ──────────────────────────────────────
    addi  x2, x0, 6          # x2 = n = 6 (número de elementos)
    addi  x3, x0, 0          # x3 = i = 0 (começa na primeira posição)

    # ─── Loop externo: i de 0 até n-2 ────────────────────────────────
loop_externo:
    addi  x10, x2, -1        # x10 = n - 1
    bge   x3, x10, fim       # se i >= n-1, ordenação concluída

    # Calcula endereço de arr[i]
    slli  x8, x3, 2          # x8 = i * 4
    add   x8, x1, x8         # x8 = base + i*4 = &arr[i]
    lw    x6, 0(x8)          # x6 = min_val = arr[i]  (mínimo inicial = arr[i])
    add   x5, x0, x3         # x5 = min_idx = i       (índice do mínimo = i)

    # ─── Loop interno: j de i+1 até n-1 (busca o mínimo) ─────────────
    addi  x4, x3, 1          # x4 = j = i + 1 (começa no elemento seguinte)

loop_interno:
    bge   x4, x2, faz_troca  # se j >= n, terminou varredura → vai trocar

    # Calcula endereço de arr[j] e carrega o valor
    slli  x9, x4, 2          # x9 = j * 4
    add   x9, x1, x9         # x9 = base + j*4 = &arr[j]
    lw    x7, 0(x9)          # x7 = elem = arr[j]

    # Compara arr[j] com o mínimo atual
    bge   x7, x6, prox_j     # se arr[j] >= min_val, não é novo mínimo

    # Novo mínimo encontrado: atualiza min_idx e min_val
    add   x5, x0, x4         # min_idx = j
    add   x6, x0, x7         # min_val = arr[j]

prox_j:
    addi  x4, x4, 1          # j++
    jal   x0, loop_interno   # próxima iteração do loop interno

faz_troca:
    # Verifica se é necessário trocar (só se min_idx ≠ i)
    beq   x5, x3, prox_i     # se min_idx == i, arr[i] já é o mínimo, pula troca

    # Troca arr[i] com arr[min_idx]
    slli  x9, x5, 2          # x9 = min_idx * 4
    add   x9, x1, x9         # x9 = base + min_idx*4 = &arr[min_idx]

    lw    x10, 0(x8)         # x10 = arr[i]  (lê valor atual de arr[i])
    lw    x7,  0(x9)         # x7  = arr[min_idx]

    sw    x7,  0(x8)         # arr[i]       = arr[min_idx]  (coloca mínimo em i)
    sw    x10, 0(x9)         # arr[min_idx] = arr[i]        (coloca antigo arr[i] em min_idx)

prox_i:
    addi  x3, x3, 1          # i++
    jal   x0, loop_externo   # próxima iteração do loop externo

fim:
    # dmem contém: [1, 2, 3, 5, 8, 9]
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT)
