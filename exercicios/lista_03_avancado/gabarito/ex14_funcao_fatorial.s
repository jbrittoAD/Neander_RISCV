# =============================================================================
# Gabarito — Lista 3, Exercício 14: Função fatorial iterativa
# Answer key — List 3, Exercise 14: Iterative factorial function
# =============================================================================
# Convention: argument in a0 (x10), return in a0
# Convenção: argumento em a0 (x10), retorno em a0
# Expected results: x11 = 120 (5!), x10 = 6 (3!)
# Resultados esperados: x11 = 120 (5!), x10 = 6 (3!)

.section .text
.global _start

_start:
    # First call: fatorial(5) / Primeira chamada: fatorial(5)
    addi  x10, x0, 5         # a0 = N = 5
    jal   x1, fatorial       # call; ra = next instruction / chama; ra = próxima instrução
    addi  x11, x10, 0        # a1 = 120 (saves result of 5! / salva resultado de 5!)

    # Second call: fatorial(3) / Segunda chamada: fatorial(3)
    addi  x10, x0, 3         # a0 = N = 3
    jal   x1, fatorial
    # a0 = 6 (3! = 6)

fim:
    jal   x0, fim
    # x11 = 120, x10 = 6 ✓

# =============================================================================
# Function: fatorial (iterative) / Função: fatorial (iterativa)
# Input:  a0 = N (>= 0) / Entrada:  a0 = N (>= 0)
# Output: a0 = N! / Saída:    a0 = N!
# Temporaries used: t0 (x5) = counter, t1 (x6) = accumulator
# Temporários usados: t0 (x5) = contador, t1 (x6) = acumulador
# This is a LEAF function (calls no other functions) → ra need not be saved
# Esta é uma função FOLHA (não chama outras funções) → ra não precisa ser salvo
# =============================================================================
fatorial:
    addi  x6, x0, 1          # t1 = result = 1 (base case: 0! = 1! = 1) / resultado = 1 (caso base: 0! = 1! = 1)
    addi  x5, x10, 0         # t0 = i = N

fat_loop:
    addi  x12, x0, 2
    blt   x5, x12, fat_fim   # if i < 2, done (1*result = result) / se i < 2, fim (1*resultado = resultado)

    # Multiply result by i via repeated addition
    # Multiplica resultado por i via somas repetidas
    # x7 = sum accumulator, x8 = addition counter
    # x7 = acumulador de soma, x8 = contador de somas
    addi  x7, x0, 0          # x7 = 0
    addi  x8, x0, 0          # x8 = counter / contador

mult_loop:
    bge   x8, x5, mult_fim   # if we added i times, done / se somamos i vezes, acabou
    add   x7, x7, x6         # x7 += result / x7 += resultado
    addi  x8, x8, 1
    jal   x0, mult_loop

mult_fim:
    addi  x6, x7, 0          # result = x7 (new product / novo produto)
    addi  x5, x5, -1         # i--
    jal   x0, fat_loop

fat_fim:
    addi  x10, x6, 0         # a0 = result / resultado
    jalr  x0, x1, 0          # ret
