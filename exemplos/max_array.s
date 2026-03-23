# =============================================================================
# Máximo de um array — RISC-V RV32I
# =============================================================================
#
# Encontra o maior elemento de um array de inteiros armazenado na memória.
#
# O array é inicializado pelo próprio programa com SW (store word).
# Isso demonstra: inicialização de memória, laço com acesso indexado e
# comparação com desvio condicional (equivalente ao JN do Neander).
#
# Mapeamento de registradores:
#   x1  = endereço base do array
#   x2  = número de elementos (N)
#   x3  = índice i (contador do loop)
#   x4  = valor máximo encontrado até agora
#   x5  = endereço do elemento atual = x1 + i*4
#   x6  = valor do elemento atual (lido da memória)
#
# Array de teste (5 elementos): [3, 17, 8, 42, 11]
# Resultado esperado: x4 = 42
#
# Mapeamento de memória:
#   mem[0x0000] = 3
#   mem[0x0004] = 17
#   mem[0x0008] = 8
#   mem[0x000C] = 42
#   mem[0x0010] = 11
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/max_array.hex
#   riscv> run
#   riscv> reg             ← x4 = 42
#   riscv> mem 0x0000 5    ← confirma array na memória
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicializa o array na memória de dados ───────────────────────
    addi  x1, x0, 0          # x1 = endereço base = 0x0000

    addi  x10, x0, 3         # elemento 0
    sw    x10, 0(x1)

    addi  x10, x0, 17        # elemento 1
    sw    x10, 4(x1)

    addi  x10, x0, 8         # elemento 2
    sw    x10, 8(x1)

    addi  x10, x0, 42        # elemento 3
    sw    x10, 12(x1)

    addi  x10, x0, 11        # elemento 4
    sw    x10, 16(x1)

    # ─── Configura parâmetros do loop ─────────────────────────────────
    addi  x2, x0, 5          # x2 = N = 5 elementos
    addi  x3, x0, 0          # x3 = i = 0

    # Inicializa máximo com o primeiro elemento
    lw    x4, 0(x1)          # x4 = max = array[0] = 3
    addi  x3, x0, 1          # começa comparando do índice 1

loop:
    bge   x3, x2, fim        # se i >= N, acabou

    # Calcula endereço do elemento i: addr = base + i*4
    slli  x5, x3, 2          # x5 = i * 4  (shift left 2 = multiplica por 4)
    add   x5, x1, x5         # x5 = base + i*4

    lw    x6, 0(x5)          # x6 = array[i]

    # Atualiza máximo se array[i] > max
    bge   x4, x6, nao_troca  # se max >= array[i], não troca
    addi  x4, x6, 0          # max = array[i]  (novo máximo)

nao_troca:
    addi  x3, x3, 1          # i++
    jal   x0, loop

fim:
    # x4 = máximo = 42
    jal   x0, fim            # halt
