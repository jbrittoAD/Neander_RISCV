# =============================================================================
# Counter with loop — RISC-V RV32I
# Contador com loop — RISC-V RV32I
# =============================================================================
#
# The simplest possible program with a loop: counts from 0 to N-1 and stores
# O programa mais simples possível com loop: conta de 0 até N-1 e armazena
# each value in memory. Good starting point for understanding loops in assembly.
# cada valor na memória. Bom ponto de partida para entender loops em assembly.
#
# Equivalent in C:
# Equivalente em C:
#   for (int i = 0; i < 10; i++) mem[i] = i;
#
# Register mapping:
# Mapeamento de registradores:
#   x1  = N (counter limit / limite do contador)
#   x2  = i (current counter value, starts at 0 / contador atual, começa em 0)
#   x3  = write pointer in memory / ponteiro de escrita na memória
#
# Expected result:
# Resultado esperado:
#   mem[0x00] = 0
#   mem[0x04] = 1
#   mem[0x08] = 2
#   ...
#   mem[0x24] = 9
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/counter.hex
#   riscv> run
#   riscv> mem 0x0000 10    ← should show 0, 1, 2, ..., 9 / deve mostrar 0, 1, 2, ..., 9
# =============================================================================

.section .text
.global _start
_start:
    addi  x1, x0, 10         # x1 = N = 10
    addi  x2, x0, 0          # x2 = i = 0  (counter / contador)
    addi  x3, x0, 0          # x3 = write pointer = 0x0000 / ponteiro de escrita = 0x0000

loop:
    bge   x2, x1, fim        # if i >= 10, finish / se i >= 10, termina

    sw    x2, 0(x3)          # mem[x3] = i
    addi  x2, x2, 1          # i++
    addi  x3, x3, 4          # pointer += 4 (next 4-byte position / próxima posição de 4 bytes)

    jal   x0, loop

fim:
    # Final registers: x2 = 10, x3 = 40 (0x28)
    # Registradores finais: x2 = 10, x3 = 40 (0x28)
    # Memory: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    # Memória: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
    jal   x0, fim            # halt
