# =============================================================================
# Gabarito — Lista 4, Exercício 20: MMC (Mínimo Múltiplo Comum)
# =============================================================================
# Descrição:
#   Calcula o MMC(12, 18) usando a identidade mmc(a,b) = (a/mdc(a,b)) * b,
#   implementada inteiramente com subtrações e somas repetidas, sem usar
#   as instruções mul, div ou rem (que não existem em RV32I puro).
#
# Algoritmo:
#   Passo 1 — MDC via subtração de Euclides:
#     enquanto a != b: se a > b então a -= b; senão b -= a
#     resultado: a == b == mdc
#
#   Passo 2 — Divisão a_original / mdc via subtração repetida:
#     q = 0; tmp = a_original
#     enquanto tmp >= mdc: tmp -= mdc; q++
#     resultado: q = a_original / mdc
#
#   Passo 3 — Multiplicação q * b_original via soma repetida:
#     produto = 0
#     repete q vezes: produto += b_original
#     resultado: produto = mmc(a, b)
#
# Mapa de registradores:
#   x1  (ra)  — reutilizado como cópia de a (preservado para passo 1)
#               ATENÇÃO: aqui x1 guarda o valor original de a (= 12),
#               pois não há chamadas de função neste programa.
#   x2        — valor original de b (= 18)
#               ATENÇÃO: x2 normalmente é sp; aqui reutilizado como b
#               conforme especificação do exercício (programa sem pilha).
#   x10 (a0)  — cópia de a para calcular o MDC (será consumida)
#   x11       — cópia de b para calcular o MDC (será consumida)
#   x12       — MDC(a, b) após o passo 1
#   x13       — quociente a/mdc  (após o passo 2)
#   x3        — resultado final MMC(a, b)
#   t0  (x5)  — temporário auxiliar
#
# Entrada:
#   x1 = 12  (a)
#   x2 = 18  (b)
#
# Resultado esperado:
#   x3 = 36  (MMC(12, 18) = 36)
#   Verificação: mdc(12,18)=6; 12/6=2; 2*18=36
#
# Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex20.o ex20_mmc.s
#   riscv64-unknown-elf-objcopy -O binary ex20.o ex20.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex20.bin ex20.hex
#   python3 ../../../../simulator/riscv_sim.py ex20.hex --run
#   # Verificar: x3 = 36
# =============================================================================

.section .text
.global _start

_start:
    # ── Inicialização dos operandos ───────────────────────────────────────────
    addi x1, x0, 12       # x1 = a = 12  (valor original preservado)
    addi x2, x0, 18       # x2 = b = 18  (valor original preservado)

    # ── Passo 1: calcula MDC(a, b) via subtração de Euclides ─────────────────
    addi x10, x1, 0       # x10 = cópia de a (será modificada)
    addi x11, x2, 0       # x11 = cópia de b (será modificada)

mdc_loop:
    beq  x10, x11, mdc_fim        # se a == b, o MDC é a (ou b)

    blt  x10, x11, mdc_b_maior    # se a < b, subtrai a de b

    # a > b: a = a - b
    sub  x10, x10, x11    # a -= b
    jal  x0, mdc_loop     # continua

mdc_b_maior:
    # b > a: b = b - a
    sub  x11, x11, x10    # b -= a
    jal  x0, mdc_loop     # continua

mdc_fim:
    addi x12, x10, 0      # x12 = MDC(a, b) = 6

    # ── Passo 2: calcula a / mdc via subtração repetida ───────────────────────
    addi x13, x0, 0       # x13 = quociente = 0
    addi t0, x1, 0        # t0  = a_original = 12 (será consumido)

div_loop:
    blt  t0, x12, div_fim         # se resto < mdc, terminamos
    sub  t0, t0, x12      # resto -= mdc
    addi x13, x13, 1      # quociente++
    jal  x0, div_loop     # continua

div_fim:
    # x13 = a / mdc = 12 / 6 = 2

    # ── Passo 3: calcula (a/mdc) * b via soma repetida ────────────────────────
    addi x3, x0, 0        # x3 = produto = 0
    addi t0, x0, 0        # t0 = contador = 0

mul_loop:
    bge  t0, x13, mul_fim         # se contador >= quociente, terminamos
    add  x3, x3, x2       # produto += b_original (= 18)
    addi t0, t0, 1        # contador++
    jal  x0, mul_loop     # continua

mul_fim:
    # x3 = MMC(12, 18) = 36

fim:
    jal x0, fim           # halt — loop infinito (equivalente ao HLT)
