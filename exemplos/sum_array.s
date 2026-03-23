# =============================================================================
# Soma de um array — RISC-V RV32I
# =============================================================================
#
# Soma todos os elementos de um array de inteiros armazenado na memória.
# Demonstra laço com acesso sequencial à memória e acumulador.
#
# Equivalente em C:
#   int arr[] = {10, 20, 30, 40, 50};
#   int soma = 0;
#   for (int i = 0; i < 5; i++) soma += arr[i];
#   // soma == 150
#
# Mapeamento de registradores:
#   x1  = endereço base do array
#   x2  = número de elementos (N)
#   x3  = contador de elementos restantes (conta regressiva: N, N-1, ..., 1)
#   x4  = soma acumulada
#   x5  = ponteiro para elemento atual (avança de 4 em 4)
#
# Array: [10, 20, 30, 40, 50] → soma = 150
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/sum_array.hex
#   riscv> run
#   riscv> reg             ← x4 = 150
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicializa o array na memória de dados ───────────────────────
    addi  x1, x0, 0          # x1 = endereço base

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

    # ─── Loop de soma ────────────────────────────────────────────────
    addi  x2, x0, 5          # x2 = N = 5
    addi  x3, x0, 5          # x3 = contador = N (conta regressiva)
    addi  x4, x0, 0          # x4 = soma = 0
    addi  x5, x1, 0          # x5 = ponteiro = base

loop:
    beq   x3, x0, fim        # se contador == 0, termina

    lw    x6, 0(x5)          # x6 = *x5  (elemento atual)
    add   x4, x4, x6         # soma += elemento

    addi  x5, x5, 4          # avança ponteiro para próximo elemento
    addi  x3, x3, -1         # contador--

    jal   x0, loop

fim:
    # x4 = 150 (10 + 20 + 30 + 40 + 50)
    jal   x0, fim            # halt
