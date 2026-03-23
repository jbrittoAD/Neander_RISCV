# =============================================================================
# Fibonacci iterativo — RISC-V RV32I
# =============================================================================
#
# Calcula os primeiros N termos da sequência de Fibonacci e armazena em memória.
#
# Sequência: 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...
# Fórmula:   F(0)=0, F(1)=1, F(n) = F(n-1) + F(n-2)
#
# Mapeamento de registradores:
#   x1  (t0) = índice i (conta de 2 até N-1)
#   x2  (t1) = F(i-2)  — penúltimo termo
#   x3  (t2) = F(i-1)  — último termo
#   x4  (t3) = F(i)    — termo atual (temporário)
#   x5  (t4) = N       — número de termos a calcular
#   x6  (t5) = endereço base do array na memória de dados
#   x7  (t6) = endereço atual de escrita
#
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
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/fibonacci.hex
#   riscv> run
#   riscv> mem 0x0000 8     ← mostra os 8 termos na memória de dados
# =============================================================================

.section .text
.global _start
_start:
    # ─── Inicialização ────────────────────────────────────────────────
    addi  x5, x0, 8          # x5 = N = 8 (quantos termos calcular)
    addi  x6, x0, 0          # x6 = endereço base = 0x0000

    # ─── Escreve F(0) = 0 e F(1) = 1 na memória ──────────────────────
    addi  x2, x0, 0          # x2 = F(0) = 0
    addi  x3, x0, 1          # x3 = F(1) = 1

    sw    x2, 0(x6)          # mem[0x00] = 0
    sw    x3, 4(x6)          # mem[0x04] = 1

    # ─── Loop: calcula F(2) até F(N-1) ────────────────────────────────
    addi  x1, x0, 2          # x1 = i = 2 (começa do terceiro termo)
    addi  x7, x6, 8          # x7 = endereço atual = base + 8 (posição de F(2))

loop:
    bge   x1, x5, fim        # se i >= N, termina

    add   x4, x2, x3         # x4 = F(i) = F(i-2) + F(i-1)
    sw    x4, 0(x7)          # mem[x7] = F(i)

    add   x2, x0, x3         # x2 = F(i-1)  (avança o penúltimo)
    add   x3, x0, x4         # x3 = F(i)    (avança o último)

    addi  x1, x1, 1          # i++
    addi  x7, x7, 4          # avança endereço de escrita em 4 bytes (1 word)

    jal   x0, loop           # volta ao início do loop

fim:
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT do Neander)
