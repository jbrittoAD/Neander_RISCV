# =============================================================================
# Gabarito — Lista 4, Exercício 16: Fibonacci Recursivo
# =============================================================================
# Descrição:
#   Calcula fib(8) usando recursão e pilha, seguindo a convenção de chamada
#   RISC-V (argumentos em a0, retorno em a0, ra e s-regs salvos na pilha).
#
# Mapa de registradores:
#   a0  (x10) — argumento n / valor de retorno fib(n)
#   ra  (x1)  — endereço de retorno (salvo na pilha)
#   s0  (x8)  — cópia de n dentro da função (salvo na pilha)
#   s1  (x9)  — resultado parcial fib(n-1) (salvo na pilha, pois é callee-saved)
#   t0  (x5)  — constante 1 (para comparação do caso base)
#   sp  (x2)  — ponteiro de pilha (inicializado em 0x400)
#
# Mapa da pilha (frame de 12 bytes por chamada):
#   sp+8 → ra  (endereço de retorno)
#   sp+4 → s0  (valor de n)
#   sp+0 → s1  (resultado parcial fib(n-1))
#
# Por que salvar s1?
#   s1 é um registrador callee-saved: a função deve preservá-lo para o
#   chamador. Como usamos s1 para armazenar fib(n-1) entre as duas chamadas
#   recursivas, precisamos salvá-lo na pilha e restaurá-lo no epílogo.
#
# Resultado esperado:
#   x10 = 21  (fib(8) = 21)
#
# Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex16.o ex16_fib_recursivo.s
#   riscv64-unknown-elf-objcopy -O binary ex16.o ex16.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex16.bin ex16.hex
#   python3 ../../../../simulator/riscv_sim.py ex16.hex --run
#   # Verificar: a0 (x10) = 21
# =============================================================================

.section .text
.global _start

_start:
    addi sp, x0, 0x400    # sp = 1024 (topo da pilha, cresce para baixo)
    addi a0, x0, 8        # argumento: n = 8
    jal  ra, fib          # chama fib(8) — ra recebe endereço de retorno
    jal  x0, fim          # halt (a0 = fib(8) = 21)

# =============================================================================
# Função: fib
# Entrada:  a0 = n
# Saída:    a0 = fib(n)
# Salva na pilha: ra (x1), s0 (x8), s1 (x9)
# Frame de 12 bytes: sp-=12; [sp+8]=ra; [sp+4]=s0; [sp+0]=s1
# =============================================================================
fib:
    addi sp, sp, -12      # abre frame de 12 bytes na pilha
    sw   ra, 8(sp)        # salva endereço de retorno
    sw   s0, 4(sp)        # salva s0 (registrador callee-saved)
    sw   s1, 0(sp)        # salva s1 (registrador callee-saved)

    addi s0, a0, 0        # s0 = n  (guarda n para uso posterior)

    addi t0, x0, 1        # t0 = 1  (limiar do caso base)
    bgt  s0, t0, fib_recursivo   # se n > 1, vai para parte recursiva

    # Caso base: fib(0)=0 ou fib(1)=1  — retorna n (já está em a0)
    addi a0, s0, 0        # a0 = n  (0 ou 1)
    jal  x0, fib_retorna  # pula para o epílogo

fib_recursivo:
    addi a0, s0, -1       # a0 = n-1  (argumento para fib(n-1))
    jal  ra, fib          # chama fib(n-1) — resultado em a0

    addi s1, a0, 0        # s1 = fib(n-1)  (s1 é callee-saved: não será corrompido)

    addi a0, s0, -2       # a0 = n-2  (argumento para fib(n-2))
    jal  ra, fib          # chama fib(n-2) — resultado em a0

    add  a0, a0, s1       # a0 = fib(n-2) + fib(n-1) = fib(n)

fib_retorna:
    lw   ra, 8(sp)        # restaura endereço de retorno
    lw   s0, 4(sp)        # restaura s0
    lw   s1, 0(sp)        # restaura s1
    addi sp, sp, 12       # fecha frame da pilha
    jalr x0, ra, 0        # retorna para o chamador

fim:
    jal x0, fim           # halt — loop infinito (equivalente ao HLT)
