# =============================================================================
# Busca Binária — RISC-V RV32I
# =============================================================================
#
# Armazena um array ordenado de 10 inteiros na memória de dados e realiza
# uma busca binária pelo valor 23. Ao final, o índice encontrado fica em x3
# e a flag de resultado (1=encontrado, 0=não encontrado) fica em x4.
#
# Array: [2, 5, 8, 12, 16, 23, 38, 56, 72, 91]
#        índices: 0  1  2   3   4   5   6   7   8   9
#
# Algoritmo de busca binária:
#   lo = 0,  hi = n-1
#   enquanto lo <= hi:
#       mid = (lo + hi) / 2      ← divisão inteira via srl
#       se arr[mid] == alvo: encontrado, índice = mid
#       se arr[mid] <  alvo: lo = mid + 1
#       se arr[mid] >  alvo: hi = mid - 1
#   se lo > hi: não encontrado
#
# Este exemplo demonstra:
# - Busca binária clássica em array ordenado
# - Divisão inteira por 2 via srl (shift lógico à direita)
# - Acesso indexado: addr = base + mid * 4
# - Uso de flag de resultado (encontrado/não encontrado)
#
# Mapeamento de registradores:
#   x1  = base dmem (endereço 0)
#   x2  = alvo = 23 (valor procurado)
#   x3  = índice resultado
#   x4  = encontrado (0 = não, 1 = sim)
#   x5  = lo (limite inferior)
#   x6  = hi (limite superior)
#   x7  = mid (ponto médio)
#   x8  = arr[mid] (elemento no ponto médio)
#   x9  = temp (endereço de arr[mid])
#
# Array:              [2,5,8,12,16,23,38,56,72,91] em dmem[0..39]
# Alvo:               x2 = 23
# Resultado esperado: x3 = 5 (índice), x4 = 1 (encontrado)
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/binary_search.hex
#   riscv> run
#   riscv> reg        ← x3 deve ser 5, x4 deve ser 1
#   riscv> mem 0x0000 10  ← mostra o array na memória
# =============================================================================

.section .text
.global _start
_start:
    # ─── Armazena array [2,5,8,12,16,23,38,56,72,91] na dmem ─────────
    addi  x1, x0, 0          # x1 = endereço base = 0

    addi  x9, x0, 2
    sw    x9,  0(x1)         # dmem[0]  = 2   (índice 0)

    addi  x9, x0, 5
    sw    x9,  4(x1)         # dmem[4]  = 5   (índice 1)

    addi  x9, x0, 8
    sw    x9,  8(x1)         # dmem[8]  = 8   (índice 2)

    addi  x9, x0, 12
    sw    x9, 12(x1)         # dmem[12] = 12  (índice 3)

    addi  x9, x0, 16
    sw    x9, 16(x1)         # dmem[16] = 16  (índice 4)

    addi  x9, x0, 23
    sw    x9, 20(x1)         # dmem[20] = 23  (índice 5)

    addi  x9, x0, 38
    sw    x9, 24(x1)         # dmem[24] = 38  (índice 6)

    addi  x9, x0, 56
    sw    x9, 28(x1)         # dmem[28] = 56  (índice 7)

    addi  x9, x0, 72
    sw    x9, 32(x1)         # dmem[32] = 72  (índice 8)

    addi  x9, x0, 91
    sw    x9, 36(x1)         # dmem[36] = 91  (índice 9)

    # ─── Inicializa busca binária ─────────────────────────────────────
    addi  x2, x0, 23         # x2 = alvo = 23
    addi  x3, x0, 0          # x3 = índice resultado = 0 (indefinido)
    addi  x4, x0, 0          # x4 = encontrado = 0 (não encontrado por padrão)
    addi  x5, x0, 0          # x5 = lo = 0 (limite inferior)
    addi  x6, x0, 9          # x6 = hi = 9 (limite superior, n-1)

    # ─── Loop de busca binária ────────────────────────────────────────
busca:
    bgt   x5, x6, nao_encontrado  # se lo > hi, não existe no array

    # Calcula mid = (lo + hi) / 2 via shift lógico à direita
    add   x7, x5, x6         # x7 = lo + hi
    srli  x7, x7, 1          # x7 = (lo + hi) / 2  (divisão inteira por 2)

    # Calcula endereço de arr[mid] = base + mid * 4
    slli  x9, x7, 2          # x9 = mid * 4  (cada elemento ocupa 4 bytes)
    add   x9, x1, x9         # x9 = base + mid*4  (endereço de arr[mid])
    lw    x8, 0(x9)          # x8 = arr[mid]

    beq   x8, x2, encontrado # se arr[mid] == alvo, encontrou!

    blt   x8, x2, metade_dir # se arr[mid] < alvo, busca na metade direita

    # arr[mid] > alvo → busca na metade esquerda: hi = mid - 1
    addi  x6, x7, -1         # hi = mid - 1
    jal   x0, busca          # repete a busca

metade_dir:
    # arr[mid] < alvo → busca na metade direita: lo = mid + 1
    addi  x5, x7, 1          # lo = mid + 1
    jal   x0, busca          # repete a busca

encontrado:
    add   x3, x0, x7         # x3 = índice = mid
    addi  x4, x0, 1          # x4 = encontrado = 1
    jal   x0, fim            # vai para o halt

nao_encontrado:
    addi  x3, x0, -1         # x3 = -1 (índice inválido)
    addi  x4, x0, 0          # x4 = encontrado = 0 (não encontrado)

fim:
    # x3 = 5 (índice de 23), x4 = 1 (encontrado)
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT)
