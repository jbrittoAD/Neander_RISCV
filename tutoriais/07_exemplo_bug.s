# =============================================================================
# 07_exemplo_bug.s — Programas com bug para o Tutorial 07
# =============================================================================
#
# Este arquivo contém dois programas:
#   PARTE 1 — bug_fatorial: calcula 5! = 120 mas tem um bug de multiplicação
#   PARTE 2 — soma_array (exercício): soma array [5,10,15,20] mas pula elementos
#
# Para compilar o PARTE 1 (bug_fatorial):
#   Copie as linhas da seção BUGADA para um arquivo separado,
#   ou use os blocos .if 0 / .endif abaixo para selecionar a versão.
#
# =============================================================================


# =============================================================================
# PARTE 1A — bug_fatorial.s — VERSÃO COM BUG
# =============================================================================
# Objetivo: calcular 5! = 120
# Resultado com o bug: 1 (errado)
#
# Bug: "add x3, x3, x1" deveria ser "add x3, x3, x2"
#      O loop de multiplicação soma x1 (N atual) em vez de x2 (resultado acumulado)
#      Isso calcula N*N em vez de resultado*N em cada iteração.
#
# Registradores:
#   x1 = N (contador regressivo: 5, 4, 3, 2, 1)
#   x2 = resultado acumulado (deveria terminar em 120)
#   x3 = produto da multiplicação atual
#   x4 = contador interno do loop de multiplicação
# =============================================================================

# DESCOMENTE O BLOCO ABAIXO PARA USAR A VERSÃO COM BUG
# (remova os '#' das linhas entre os marcadores)

#.section .text
#.global _start
#_start:
#    addi x1, x0, 5     # x1 = N = 5
#    addi x2, x0, 1     # x2 = resultado = 1
#
#loop:
#    beq  x1, x0, fim   # se N == 0, termina
#
#    addi x3, x0, 0     # x3 = produto = 0
#    addi x4, x0, 0     # x4 = contador = 0
#mul:
#    beq  x4, x1, mul_fim
#    add  x3, x3, x1    # BUG: deveria ser "add x3, x3, x2"
#    addi x4, x4, 1
#    jal  x0, mul
#mul_fim:
#    addi x2, x3, 0
#    addi x1, x1, -1
#    jal  x0, loop
#
#fim:
#    jal x0, fim


# =============================================================================
# PARTE 1B — bug_fatorial.s — VERSÃO CORRIGIDA
# =============================================================================
# Correção: "add x3, x3, x1"  →  "add x3, x3, x2"
# Resultado correto: x2 = 120
# =============================================================================

.section .text
.global _start
_start:
    addi x1, x0, 5     # x1 = N = 5
    addi x2, x0, 1     # x2 = resultado = 1

loop:
    beq  x1, x0, fim   # se N == 0, termina

    # Multiplica x2 * x1 via somas repetidas
    addi x3, x0, 0     # x3 = produto = 0
    addi x4, x0, 0     # x4 = contador = 0
mul:
    beq  x4, x1, mul_fim       # se contador == N, termina multiplicação
    add  x3, x3, x2            # CORRETO: soma x2 (resultado acumulado)
    addi x4, x4, 1
    jal  x0, mul
mul_fim:
    addi x2, x3, 0     # x2 = novo resultado
    addi x1, x1, -1    # N--
    jal  x0, loop

fim:
    # Resultado esperado: x2 = 120 (= 5 * 4 * 3 * 2 * 1)
    jal x0, fim        # halt


# =============================================================================
# PARTE 2A — soma_array.s — VERSÃO COM BUG (exercício)
# =============================================================================
# Objetivo: somar array [5, 10, 15, 20] → x2 = 50
# Resultado com o bug: x2 = 20 (errado — o ponteiro pula elementos)
#
# Bug: "addi x6, x6, 8"  deveria ser  "addi x6, x6, 4"
#      Avança o ponteiro 8 bytes (2 inteiros) em vez de 4 bytes (1 inteiro),
#      pulando um elemento a cada iteração.
# =============================================================================

# VERSÃO COM BUG — copie para soma_array_bug.s para testar:

#.section .text
#.global _start
#_start:
#    addi x6, x0, 0
#    addi x1, x0, 5
#    sw   x1, 0(x6)
#    addi x1, x0, 10
#    sw   x1, 4(x6)
#    addi x1, x0, 15
#    sw   x1, 8(x6)
#    addi x1, x0, 20
#    sw   x1, 12(x6)
#
#    addi x2, x0, 0     # x2 = soma = 0
#    addi x3, x0, 0     # x3 = i = 0
#    addi x4, x0, 4     # x4 = N = 4
#
#loop:
#    bge  x3, x4, fim
#    lw   x5, 0(x6)
#    add  x2, x2, x5
#    addi x6, x6, 8     # BUG: deveria ser addi x6, x6, 4
#    addi x3, x3, 1
#    jal  x0, loop
#
#fim:
#    jal x0, fim


# =============================================================================
# PARTE 2B — soma_array.s — VERSÃO CORRIGIDA
# =============================================================================
# Correção: "addi x6, x6, 8"  →  "addi x6, x6, 4"
# Resultado correto: x2 = 50
# =============================================================================

# (descomente para usar — conflito com _start da PARTE 1B acima)

#.section .text
#.global _start
#_start:
#    addi x6, x0, 0
#    addi x1, x0, 5
#    sw   x1, 0(x6)
#    addi x1, x0, 10
#    sw   x1, 4(x6)
#    addi x1, x0, 15
#    sw   x1, 8(x6)
#    addi x1, x0, 20
#    sw   x1, 12(x6)
#
#    addi x2, x0, 0     # x2 = soma = 0
#    addi x3, x0, 0     # x3 = i = 0
#    addi x4, x0, 4     # x4 = N = 4
#
#loop:
#    bge  x3, x4, fim
#    lw   x5, 0(x6)
#    add  x2, x2, x5
#    addi x6, x6, 4     # CORRETO: avança 4 bytes (um inteiro de 32 bits)
#    addi x3, x3, 1
#    jal  x0, loop
#
#fim:
#    # Resultado esperado: x2 = 50
#    jal x0, fim
