# =============================================================================
# Gabarito — Lista 3, Exercício 14: Função fatorial iterativa
# =============================================================================
# Convenção: argumento em a0 (x10), retorno em a0
# Resultados esperados: x11 = 120 (5!), x10 = 6 (3!)

.section .text
.global _start

_start:
    # Primeira chamada: fatorial(5)
    addi  x10, x0, 5         # a0 = N = 5
    jal   x1, fatorial       # chama; ra = próxima instrução
    addi  x11, x10, 0        # a1 = 120 (salva resultado de 5!)

    # Segunda chamada: fatorial(3)
    addi  x10, x0, 3         # a0 = N = 3
    jal   x1, fatorial
    # a0 = 6 (3! = 6)

fim:
    jal   x0, fim
    # x11 = 120, x10 = 6 ✓

# =============================================================================
# Função: fatorial (iterativa)
# Entrada:  a0 = N (>= 0)
# Saída:    a0 = N!
# Temporários usados: t0 (x5) = contador, t1 (x6) = acumulador
# Esta é uma função FOLHA (não chama outras funções) → ra não precisa ser salvo
# =============================================================================
fatorial:
    addi  x6, x0, 1          # t1 = resultado = 1 (caso base: 0! = 1! = 1)
    addi  x5, x10, 0         # t0 = i = N

fat_loop:
    addi  x12, x0, 2
    blt   x5, x12, fat_fim   # se i < 2, fim (1*resultado = resultado)

    # Multiplica resultado por i via somas repetidas
    # x7 = acumulador de soma, x8 = contador de somas
    addi  x7, x0, 0          # x7 = 0
    addi  x8, x0, 0          # x8 = contador

mult_loop:
    bge   x8, x5, mult_fim   # se somamos i vezes, acabou
    add   x7, x7, x6         # x7 += resultado
    addi  x8, x8, 1
    jal   x0, mult_loop

mult_fim:
    addi  x6, x7, 0          # resultado = x7 (novo produto)
    addi  x5, x5, -1         # i--
    jal   x0, fat_loop

fat_fim:
    addi  x10, x6, 0         # a0 = resultado
    jalr  x0, x1, 0          # ret
