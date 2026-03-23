# =============================================================================
# Contador com loop — RISC-V RV32I
# =============================================================================
#
# O programa mais simples possível com loop: conta de 0 até N-1 e armazena
# cada valor na memória. Bom ponto de partida para entender loops em assembly.
#
# Equivalente em C:
#   for (int i = 0; i < 10; i++) mem[i] = i;
#
# Mapeamento de registradores:
#   x1  = N (limite do contador)
#   x2  = i (contador atual, começa em 0)
#   x3  = ponteiro de escrita na memória
#
# Resultado esperado:
#   mem[0x00] = 0
#   mem[0x04] = 1
#   mem[0x08] = 2
#   ...
#   mem[0x24] = 9
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/counter.hex
#   riscv> run
#   riscv> mem 0x0000 10    ← deve mostrar 0, 1, 2, ..., 9
# =============================================================================

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = N = 10
    addi  x2, x0, 0          # x2 = i = 0  (contador)
    addi  x3, x0, 0          # x3 = ponteiro de escrita = 0x0000

loop:
    bge   x2, x1, fim        # se i >= 10, termina

    sw    x2, 0(x3)          # mem[x3] = i
    addi  x2, x2, 1          # i++
    addi  x3, x3, 4          # ponteiro += 4 (próxima posição de 4 bytes)

    jal   x0, loop

fim:
    # Registradores finais: x2 = 10, x3 = 40 (0x28)
    # Memória: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    jal   x0, fim            # halt
