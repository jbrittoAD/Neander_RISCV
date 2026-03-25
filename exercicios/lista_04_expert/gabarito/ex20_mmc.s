# =============================================================================
# Gabarito — Lista 4, Exercício 20: MMC (Mínimo Múltiplo Comum)
# Answer key — List 4, Exercise 20: LCM (Least Common Multiple)
# =============================================================================
# Description / Descrição:
#   Computes LCM(12, 18) using the identity lcm(a,b) = (a/gcd(a,b)) * b,
#   implemented entirely with subtractions and repeated additions, without
#   the mul, div, or rem instructions (which do not exist in pure RV32I).
#
#   Calcula o MMC(12, 18) usando a identidade mmc(a,b) = (a/mdc(a,b)) * b,
#   implementada inteiramente com subtrações e somas repetidas, sem usar
#   as instruções mul, div ou rem (que não existem em RV32I puro).
#
# Algorithm / Algoritmo:
#   Step 1 — GCD via Euclidean subtraction / Passo 1 — MDC via subtração de Euclides:
#     while a != b: if a > b then a -= b; else b -= a
#     enquanto a != b: se a > b então a -= b; senão b -= a
#     result: a == b == gcd / resultado: a == b == mdc
#
#   Step 2 — Division a_original / gcd via repeated subtraction:
#   Passo 2 — Divisão a_original / mdc via subtração repetida:
#     q = 0; tmp = a_original
#     while tmp >= gcd: tmp -= gcd; q++
#     enquanto tmp >= mdc: tmp -= mdc; q++
#     result: q = a_original / gcd / resultado: q = a_original / mdc
#
#   Step 3 — Multiplication q * b_original via repeated addition:
#   Passo 3 — Multiplicação q * b_original via soma repetida:
#     product = 0 / produto = 0
#     repeat q times: product += b_original / repete q vezes: produto += b_original
#     result: product = lcm(a, b) / resultado: produto = mmc(a, b)
#
# Register map / Mapa de registradores:
#   x1  (ra)  — reused as copy of a (preserved for step 1) / reutilizado como cópia de a (preservado para passo 1)
#               ATTENTION: here x1 stores the original value of a (= 12),
#               since there are no function calls in this program.
#               ATENÇÃO: aqui x1 guarda o valor original de a (= 12),
#               pois não há chamadas de função neste programa.
#   x2        — original value of b (= 18) / valor original de b (= 18)
#               ATTENTION: x2 is normally sp; reused as b here per exercise
#               specification (program without stack).
#               ATENÇÃO: x2 normalmente é sp; aqui reutilizado como b
#               conforme especificação do exercício (programa sem pilha).
#   x10 (a0)  — copy of a for GCD computation (will be consumed) / cópia de a para calcular o MDC (será consumida)
#   x11       — copy of b for GCD computation (will be consumed) / cópia de b para calcular o MDC (será consumida)
#   x12       — GCD(a, b) after step 1 / MDC(a, b) após o passo 1
#   x13       — quotient a/gcd  (after step 2) / quociente a/mdc  (após o passo 2)
#   x3        — final result LCM(a, b) / resultado final MMC(a, b)
#   t0  (x5)  — auxiliary temporary / temporário auxiliar
#
# Input / Entrada:
#   x1 = 12  (a)
#   x2 = 18  (b)
#
# Expected result / Resultado esperado:
#   x3 = 36  (LCM(12, 18) = 36 / MMC(12, 18) = 36)
#   Verification: gcd(12,18)=6; 12/6=2; 2*18=36
#   Verificação: mdc(12,18)=6; 12/6=2; 2*18=36
#
# How to verify / Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex20.o ex20_mmc.s
#   riscv64-unknown-elf-objcopy -O binary ex20.o ex20.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex20.bin ex20.hex
#   python3 ../../../../simulator/riscv_sim.py ex20.hex --run
#   # Verify: x3 = 36 / Verificar: x3 = 36
# =============================================================================

.section .text
.global _start

_start:
    # ── Initialize operands / Inicialização dos operandos ───────────────────────────────────────────────
    addi x1, x0, 12       # x1 = a = 12  (original value preserved / valor original preservado)
    addi x2, x0, 18       # x2 = b = 18  (original value preserved / valor original preservado)

    # ── Step 1: compute GCD(a, b) via Euclidean subtraction / Passo 1: calcula MDC(a, b) via subtração de Euclides ─────────────────────
    addi x10, x1, 0       # x10 = copy of a (will be modified / será modificada)
    addi x11, x2, 0       # x11 = copy of b (will be modified / será modificada)

mdc_loop:
    beq  x10, x11, mdc_fim        # if a == b, GCD is a (or b) / se a == b, o MDC é a (ou b)

    blt  x10, x11, mdc_b_maior    # if a < b, subtract a from b / se a < b, subtrai a de b

    # a > b: a = a - b
    sub  x10, x10, x11    # a -= b
    jal  x0, mdc_loop     # continue / continua

mdc_b_maior:
    # b > a: b = b - a / b > a: b = b - a
    sub  x11, x11, x10    # b -= a
    jal  x0, mdc_loop     # continue / continua

mdc_fim:
    addi x12, x10, 0      # x12 = GCD(a, b) = 6 / MDC(a, b) = 6

    # ── Step 2: compute a / gcd via repeated subtraction / Passo 2: calcula a / mdc via subtração repetida ───────────────────────
    addi x13, x0, 0       # x13 = quotient = 0 / quociente = 0
    addi t0, x1, 0        # t0  = a_original = 12 (will be consumed / será consumido)

div_loop:
    blt  t0, x12, div_fim         # if remainder < gcd, done / se resto < mdc, terminamos
    sub  t0, t0, x12      # remainder -= gcd / resto -= mdc
    addi x13, x13, 1      # quotient++ / quociente++
    jal  x0, div_loop     # continue / continua

div_fim:
    # x13 = a / gcd = 12 / 6 = 2 / a / mdc = 12 / 6 = 2

    # ── Step 3: compute (a/gcd) * b via repeated addition / Passo 3: calcula (a/mdc) * b via soma repetida ────────────────────────
    addi x3, x0, 0        # x3 = product = 0 / produto = 0
    addi t0, x0, 0        # t0 = counter = 0 / contador = 0

mul_loop:
    bge  t0, x13, mul_fim         # if counter >= quotient, done / se contador >= quociente, terminamos
    add  x3, x3, x2       # product += b_original (= 18) / produto += b_original (= 18)
    addi t0, t0, 1        # counter++ / contador++
    jal  x0, mul_loop     # continue / continua

mul_fim:
    # x3 = LCM(12, 18) = 36 / MMC(12, 18) = 36

fim:
    jal x0, fim           # halt — infinite loop (equivalent to HLT) / parada — loop infinito (equivalente ao HLT)
