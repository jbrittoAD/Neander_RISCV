# =============================================================================
# Gabarito — Lista 4, Exercício 17: Fatorial Recursivo
# Answer key — List 4, Exercise 17: Recursive Factorial
# =============================================================================
# Description / Descrição:
#   Computes fat(6) using recursion and the stack, following the RISC-V
#   calling convention. The multiplication n * fat(n-1) is performed by
#   repeated addition, since RV32I does not have a mul instruction.
#
#   Calcula fat(6) usando recursão e pilha, seguindo a convenção de chamada
#   RISC-V. A multiplicação n * fat(n-1) é feita por soma repetida, pois
#   RV32I não possui a instrução mul.
#
# Register map / Mapa de registradores:
#   a0  (x10) — argument n / return value fat(n) / argumento n / valor de retorno fat(n)
#   ra  (x1)  — return address (saved on stack) / endereço de retorno (salvo na pilha)
#   s0  (x8)  — copy of n inside function (saved on stack) / cópia de n dentro da função (salvo na pilha)
#   t0  (x5)  — constant 1 (for base-case comparison) / constante 1 (para comparação do caso base)
#   t1  (x6)  — multiplication accumulator (partial product) / acumulador da multiplicação (produto parcial)
#   t2  (x7)  — multiplication counter / contador da multiplicação
#   sp  (x2)  — stack pointer (initialized at 0x400) / ponteiro de pilha (inicializado em 0x400)
#
# Stack frame (8 bytes per call) / Mapa da pilha (frame de 8 bytes por chamada):
#   sp+4 → ra  (return address / endereço de retorno)
#   sp+0 → s0  (value of n / valor de n)
#
# Expected result / Resultado esperado:
#   x10 = 720  (6! = 6×5×4×3×2×1 = 720)
#
# How to verify / Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex17.o ex17_fat_recursivo.s
#   riscv64-unknown-elf-objcopy -O binary ex17.o ex17.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex17.bin ex17.hex
#   python3 ../../../../simulator/riscv_sim.py ex17.hex --run
#   # Verify: a0 (x10) = 720 / Verificar: a0 (x10) = 720
# =============================================================================

.section .text
.global _start

_start:
    addi sp, x0, 0x400    # sp = 1024 (stack top, grows downward / topo da pilha, cresce para baixo)
    addi a0, x0, 6        # argument: n = 6 / argumento: n = 6
    jal  ra, fat          # call fat(6) — ra gets return address / chama fat(6) — ra recebe endereço de retorno
    jal  x0, fim          # halt (a0 = 6! = 720) / parada (a0 = 6! = 720)

# =============================================================================
# Function: fat / Função: fat
# Input:  a0 = n / Entrada:  a0 = n
# Output: a0 = n! (computed with repeated addition for multiplication)
# Saída:    a0 = n! (calculado com soma repetida para a multiplicação)
# Saved on stack: ra (x1), s0 (x8) / Salvos na pilha: ra (x1), s0 (x8)
# Frame: sp-=8; [sp+4]=ra; [sp+0]=s0
# =============================================================================
fat:
    addi sp, sp, -8       # open 8-byte frame on stack / abre frame de 8 bytes na pilha
    sw   ra, 4(sp)        # save return address / salva endereço de retorno
    sw   s0, 0(sp)        # save s0 (callee-saved register / registrador salvo pelo chamado)

    addi s0, a0, 0        # s0 = n  (stores n for later use / guarda n para uso posterior)

    addi t0, x0, 1        # t0 = 1  (base-case threshold / limiar do caso base)
    bgt  s0, t0, fat_rec  # if n > 1, recursive part / se n > 1, parte recursiva

    # Base case: fat(0)=1 or fat(1)=1 → returns 1
    # Caso base: fat(0)=1 ou fat(1)=1 → retorna 1
    addi a0, x0, 1        # a0 = 1
    jal  x0, fat_retorna  # jump to epilogue / pula para o epílogo

fat_rec:
    addi a0, s0, -1       # a0 = n-1  (argument for fat(n-1) / argumento para fat(n-1))
    jal  ra, fat          # call fat(n-1) — result in a0 / chama fat(n-1) — resultado em a0

    # At this point: a0 = fat(n-1), s0 = n
    # Neste ponto: a0 = fat(n-1), s0 = n
    # Compute s0 * a0 by repeated addition: product = 0; repeat n times: product += fat(n-1)
    # Calcula s0 * a0 por soma repetida: produto = 0; repete n vezes: produto += fat(n-1)
    addi t1, x0, 0        # t1 = product = 0 (accumulator / acumulador)
    addi t2, x0, 0        # t2 = counter = 0 / contador = 0

fat_mul:
    bge  t2, s0, fat_mul_done   # if counter >= n, multiplication done / se contador >= n, fim da multiplicação
    add  t1, t1, a0             # product += fat(n-1) / produto += fat(n-1)
    addi t2, t2, 1              # counter++ / contador++
    jal  x0, fat_mul            # continue multiplication loop / continua o loop de multiplicação

fat_mul_done:
    addi a0, t1, 0        # a0 = n * fat(n-1)  (final result / resultado final)

fat_retorna:
    lw   ra, 4(sp)        # restore return address / restaura endereço de retorno
    lw   s0, 0(sp)        # restore s0 / restaura s0
    addi sp, sp, 8        # close stack frame / fecha frame da pilha
    jalr x0, ra, 0        # return to caller / retorna para o chamador

fim:
    jal x0, fim           # halt — infinite loop (equivalent to HLT) / parada — loop infinito (equivalente ao HLT)
