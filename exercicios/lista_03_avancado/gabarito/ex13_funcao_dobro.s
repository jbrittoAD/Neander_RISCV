# =============================================================================
# Gabarito — Lista 3, Exercício 13: Função dobro
# Answer key — List 3, Exercise 13: Double function
# =============================================================================
# Convention: argument in a0 (x10), return in a0, link in ra (x1)
# Convenção: argumento em a0 (x10), retorno em a0, link em ra (x1)
# Expected results: x11 = 14, x10 = 42
# Resultados esperados: x11 = 14, x10 = 42

.section .text
.global _start

_start:
    # First call: dobro(7) / Primeira chamada: dobro(7)
    addi  x10, x0, 7         # a0 = 7
    jal   x1, dobro          # call dobro; ra = PC+4 / chama dobro; ra = PC+4
    addi  x11, x10, 0        # a1 = a0 = 14  (saves result / salva resultado)

    # Second call: dobro(21) / Segunda chamada: dobro(21)
    addi  x10, x0, 21        # a0 = 21
    jal   x1, dobro          # call dobro / chama dobro
    # a0 = 42

fim:
    jal   x0, fim            # halt / parada
    # x11 = 14, x10 = 42 ✓

# =============================================================================
# Function: dobro / Função: dobro
# Input:  a0 = value / Entrada:  a0 = valor
# Output: a0 = value * 2 / Saída:    a0 = valor * 2
# Modifies: only a0 / Modifica: apenas a0
# =============================================================================
dobro:
    slli  x10, x10, 1        # a0 = a0 << 1  (equivalent to a0 * 2 / equivale a a0 * 2)
    jalr  x0, x1, 0          # ret (returns to ra / retorna para ra)
