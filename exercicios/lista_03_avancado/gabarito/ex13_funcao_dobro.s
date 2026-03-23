# =============================================================================
# Gabarito — Lista 3, Exercício 13: Função dobro
# =============================================================================
# Convenção: argumento em a0 (x10), retorno em a0, link em ra (x1)
# Resultados esperados: x11 = 14, x10 = 42

.section .text
.global _start

_start:
    # Primeira chamada: dobro(7)
    addi  x10, x0, 7         # a0 = 7
    jal   x1, dobro          # chama dobro; ra = PC+4
    addi  x11, x10, 0        # a1 = a0 = 14  (salva resultado)

    # Segunda chamada: dobro(21)
    addi  x10, x0, 21        # a0 = 21
    jal   x1, dobro          # chama dobro
    # a0 = 42

fim:
    jal   x0, fim            # halt
    # x11 = 14, x10 = 42 ✓

# =============================================================================
# Função: dobro
# Entrada:  a0 = valor
# Saída:    a0 = valor * 2
# Modifica: apenas a0
# =============================================================================
dobro:
    slli  x10, x10, 1        # a0 = a0 << 1  (equivale a a0 * 2)
    jalr  x0, x1, 0          # ret (retorna para ra)
