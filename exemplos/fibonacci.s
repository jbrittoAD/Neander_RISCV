# =============================================================================
# Iterative Fibonacci — RISC-V RV32I
# Fibonacci iterativo — RISC-V RV32I
# =============================================================================
#
# Calculates the first N terms of the Fibonacci sequence and stores them in memory.
# Calcula os primeiros N termos da sequência de Fibonacci e armazena em memória.
#
# Sequence: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...
# Sequência: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...
# Formula:   F(0)=0, F(1)=1, F(n) = F(n-1) + F(n-2)
# Fórmula:   F(0)=0, F(1)=1, F(n) = F(n-1) + F(n-2)
#
# Register mapping:
# Mapeamento de registradores:
#   x1  (t0) = index i (counts from 2 to N-1 / índice i, conta de 2 até N-1)
#   x2  (t1) = F(i-2)  — second-to-last term / penúltimo termo
#   x3  (t2) = F(i-1)  — last term / último termo
#   x4  (t3) = F(i)    — current term (temporary / termo atual, temporário)
#   x5  (t4) = N       — number of terms to calculate / número de termos a calcular
#   x6  (t5) = base address of the array in data memory / endereço base do array na memória de dados
#   x7  (t6) = current write address / endereço atual de escrita
#
# Expected result (N=8, array from address 0x0000):
# Resultado esperado (N=8, array a partir do endereço 0x0000):
#   mem[0x00] = 0
#   mem[0x04] = 1
#   mem[0x08] = 1
#   mem[0x0C] = 2
#   mem[0x10] = 3
#   mem[0x14] = 5
#   mem[0x18] = 8
#   mem[0x1C] = 13
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/fibonacci.hex
#   riscv> run
#   riscv> mem 0x0000 8     ← shows the 8 terms in data memory / mostra os 8 termos na memória de dados
# =============================================================================

.section .text
.global _start
_start:
    # ─── Initialization / Inicialização ───────────────────────────────────
    addi  x5, x0, 8          # x5 = N = 8 (how many terms to calculate / quantos termos calcular)
    addi  x6, x0, 0          # x6 = base address = 0x0000 / endereço base = 0x0000

    # ─── Write F(0) = 0 and F(1) = 1 to memory ────────────────────────────
    # ─── Escreve F(0) = 0 e F(1) = 1 na memória ──────────────────────────
    addi  x2, x0, 0          # x2 = F(0) = 0
    addi  x3, x0, 1          # x3 = F(1) = 1

    sw    x2, 0(x6)          # mem[0x00] = 0
    sw    x3, 4(x6)          # mem[0x04] = 1

    # ─── Loop: calculates F(2) through F(N-1) ─────────────────────────────
    # ─── Loop: calcula F(2) até F(N-1) ────────────────────────────────────
    addi  x1, x0, 2          # x1 = i = 2 (starts from the third term / começa do terceiro termo)
    addi  x7, x6, 8          # x7 = current address = base + 8 (position of F(2) / posição de F(2))

loop:
    bge   x1, x5, fim        # if i >= N, finish / se i >= N, termina

    add   x4, x2, x3         # x4 = F(i) = F(i-2) + F(i-1)
    sw    x4, 0(x7)          # mem[x7] = F(i)

    add   x2, x0, x3         # x2 = F(i-1)  (advance second-to-last / avança o penúltimo)
    add   x3, x0, x4         # x3 = F(i)    (advance last / avança o último)

    addi  x1, x1, 1          # i++
    addi  x7, x7, 4          # advance write address by 4 bytes (1 word) / avança endereço de escrita em 4 bytes (1 word)

    jal   x0, loop           # go back to loop start / volta ao início do loop

fim:
    jal   x0, fim            # halt — infinite loop (equivalent to HLT in Neander) / loop infinito (equivalente ao HLT do Neander)
