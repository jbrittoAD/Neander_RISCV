# =============================================================================
# Gabarito — Lista 4, Exercício 18: Busca Binária (função)
# =============================================================================
# Descrição:
#   Armazena o array ordenado [2,5,8,12,16,23,38,56,72,91] na memória de dados
#   e realiza busca binária pelo valor 38. O resultado é o índice 6.
#
#   A função busca_binaria é uma função folha (não chama outras funções),
#   portanto não precisa salvar ra na pilha.
#
# Mapa de registradores (main):
#   s0  (x8)  — resultado da busca (índice encontrado ou -1)
#
# Mapa de registradores (busca_binaria):
#   a0  (x10) — endereço base do array
#   a1  (x11) — número de elementos n
#   a2  (x12) — valor alvo (target)
#   t0  (x5)  — lo (índice inferior)
#   t1  (x6)  — hi (índice superior = n-1)
#   t2  (x7)  — mid (índice do meio)
#   t3  (x28) — endereço calculado do elemento mid
#   t4  (x29) — elemento lido da memória (array[mid])
#   Retorno: a0 = índice encontrado, ou -1 se não encontrado
#
# Memória de dados (endereços 0x00..0x27, 4 bytes cada):
#   [0x00]=2, [0x04]=5, [0x08]=8, [0x0C]=12, [0x10]=16,
#   [0x14]=23, [0x18]=38, [0x1C]=56, [0x20]=72, [0x24]=91
#
# Resultado esperado:
#   s0 (x8) = 6  (índice do valor 38 no array)
#
# Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex18.o ex18_busca_binaria.s
#   riscv64-unknown-elf-objcopy -O binary ex18.o ex18.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex18.bin ex18.hex
#   python3 ../../../../simulator/riscv_sim.py ex18.hex --run
#   # Verificar: s0 (x8) = 6
# =============================================================================

.section .text
.global _start

_start:
    # ── Inicializa o array ordenado na memória de dados ───────────────────────
    addi t0, x0, 0        # t0 = endereço base = 0

    addi t1, x0, 2        # valor 2  (índice 0)
    sw   t1, 0(t0)        # mem[0]  = 2

    addi t1, x0, 5        # valor 5  (índice 1)
    sw   t1, 4(t0)        # mem[4]  = 5

    addi t1, x0, 8        # valor 8  (índice 2)
    sw   t1, 8(t0)        # mem[8]  = 8

    addi t1, x0, 12       # valor 12 (índice 3)
    sw   t1, 12(t0)       # mem[12] = 12

    addi t1, x0, 16       # valor 16 (índice 4)
    sw   t1, 16(t0)       # mem[16] = 16

    addi t1, x0, 23       # valor 23 (índice 5)
    sw   t1, 20(t0)       # mem[20] = 23

    addi t1, x0, 38       # valor 38 (índice 6)
    sw   t1, 24(t0)       # mem[24] = 38

    addi t1, x0, 56       # valor 56 (índice 7)
    sw   t1, 28(t0)       # mem[28] = 56

    addi t1, x0, 72       # valor 72 (índice 8)
    sw   t1, 32(t0)       # mem[32] = 72

    addi t1, x0, 91       # valor 91 (índice 9)
    sw   t1, 36(t0)       # mem[36] = 91

    # ── Prepara argumentos e chama busca_binaria ──────────────────────────────
    addi a0, x0, 0        # a0 = endereço base do array = 0
    addi a1, x0, 10       # a1 = número de elementos = 10
    addi a2, x0, 38       # a2 = valor procurado = 38

    jal  ra, busca_binaria        # chama a função — retorno em a0

    addi s0, a0, 0        # s0 = índice encontrado (resultado final)

    jal  x0, fim          # halt

# =============================================================================
# Função: busca_binaria  (função folha — não precisa salvar ra)
# Entrada:
#   a0 = endereço base do array (inteiros de 32 bits, ordenados)
#   a1 = número de elementos n
#   a2 = valor alvo (target)
# Saída:
#   a0 = índice do elemento encontrado, ou -1 se não encontrado
# Registradores usados (temporários — não preservados):
#   t0=lo, t1=hi, t2=mid, t3=endereço do mid, t4=elemento lido
# =============================================================================
busca_binaria:
    addi t0, x0, 0        # t0 = lo = 0  (índice inferior)
    addi t1, a1, -1       # t1 = hi = n-1  (índice superior)

bb_loop:
    bgt  t0, t1, bb_nao_encontrado   # se lo > hi, não encontrou

    # Calcula mid = (lo + hi) >> 1  (divisão inteira por 2)
    add  t2, t0, t1       # t2 = lo + hi
    srli t2, t2, 1        # t2 = (lo + hi) / 2  (mid)

    # Calcula endereço do elemento mid: base + mid * 4
    slli t3, t2, 2        # t3 = mid * 4  (cada elemento ocupa 4 bytes)
    add  t3, a0, t3       # t3 = base + mid*4  (endereço de array[mid])
    lw   t4, 0(t3)        # t4 = array[mid]

    beq  t4, a2, bb_encontrado    # se array[mid] == target, achou!

    blt  t4, a2, bb_menor         # se array[mid] < target, busca à direita

    # array[mid] > target: busca à esquerda
    addi t1, t2, -1       # hi = mid - 1
    jal  x0, bb_loop      # continua

bb_menor:
    addi t0, t2, 1        # lo = mid + 1
    jal  x0, bb_loop      # continua

bb_encontrado:
    addi a0, t2, 0        # a0 = mid  (índice do elemento encontrado)
    jalr x0, ra, 0        # retorna para o chamador

bb_nao_encontrado:
    addi a0, x0, -1       # a0 = -1  (não encontrado)
    jalr x0, ra, 0        # retorna para o chamador

fim:
    jal x0, fim           # halt — loop infinito (equivalente ao HLT)
