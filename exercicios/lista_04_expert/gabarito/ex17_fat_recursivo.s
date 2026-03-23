# =============================================================================
# Gabarito — Lista 4, Exercício 17: Fatorial Recursivo
# =============================================================================
# Descrição:
#   Calcula fat(6) usando recursão e pilha, seguindo a convenção de chamada
#   RISC-V. A multiplicação n * fat(n-1) é feita por soma repetida, pois
#   RV32I não possui a instrução mul.
#
# Mapa de registradores:
#   a0  (x10) — argumento n / valor de retorno fat(n)
#   ra  (x1)  — endereço de retorno (salvo na pilha)
#   s0  (x8)  — cópia de n dentro da função (salvo na pilha)
#   t0  (x5)  — constante 1 (para comparação do caso base)
#   t1  (x6)  — acumulador da multiplicação (produto parcial)
#   t2  (x7)  — contador da multiplicação
#   sp  (x2)  — ponteiro de pilha (inicializado em 0x400)
#
# Mapa da pilha (frame de 8 bytes por chamada):
#   sp+4 → ra  (endereço de retorno)
#   sp+0 → s0  (valor de n)
#
# Resultado esperado:
#   x10 = 720  (6! = 6×5×4×3×2×1 = 720)
#
# Como verificar:
#   riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex17.o ex17_fat_recursivo.s
#   riscv64-unknown-elf-objcopy -O binary ex17.o ex17.bin
#   python3 ../../../../riscv_harvard/scripts/bin2hex.py ex17.bin ex17.hex
#   python3 ../../../../simulator/riscv_sim.py ex17.hex --run
#   # Verificar: a0 (x10) = 720
# =============================================================================

.section .text
.global _start

_start:
    addi sp, x0, 0x400    # sp = 1024 (topo da pilha, cresce para baixo)
    addi a0, x0, 6        # argumento: n = 6
    jal  ra, fat          # chama fat(6) — ra recebe endereço de retorno
    jal  x0, fim          # halt (a0 = 6! = 720)

# =============================================================================
# Função: fat
# Entrada:  a0 = n
# Saída:    a0 = n! (calculado com soma repetida para a multiplicação)
# Salva na pilha: ra (x1), s0 (x8)
# Frame: sp-=8; [sp+4]=ra; [sp+0]=s0
# =============================================================================
fat:
    addi sp, sp, -8       # abre frame de 8 bytes na pilha
    sw   ra, 4(sp)        # salva endereço de retorno
    sw   s0, 0(sp)        # salva s0 (registrador salvo pelo chamado)

    addi s0, a0, 0        # s0 = n  (guarda n para uso posterior)

    addi t0, x0, 1        # t0 = 1  (limiar do caso base)
    bgt  s0, t0, fat_rec  # se n > 1, parte recursiva

    # Caso base: fat(0)=1 ou fat(1)=1 → retorna 1
    addi a0, x0, 1        # a0 = 1
    jal  x0, fat_retorna  # pula para o epílogo

fat_rec:
    addi a0, s0, -1       # a0 = n-1  (argumento para fat(n-1))
    jal  ra, fat          # chama fat(n-1) — resultado em a0

    # Neste ponto: a0 = fat(n-1), s0 = n
    # Calcula s0 * a0 por soma repetida: produto = 0; repete n vezes: produto += fat(n-1)
    addi t1, x0, 0        # t1 = produto = 0 (acumulador)
    addi t2, x0, 0        # t2 = contador = 0

fat_mul:
    bge  t2, s0, fat_mul_done   # se contador >= n, fim da multiplicação
    add  t1, t1, a0             # produto += fat(n-1)
    addi t2, t2, 1              # contador++
    jal  x0, fat_mul            # continua o loop de multiplicação

fat_mul_done:
    addi a0, t1, 0        # a0 = n * fat(n-1)  (resultado final)

fat_retorna:
    lw   ra, 4(sp)        # restaura endereço de retorno
    lw   s0, 0(sp)        # restaura s0
    addi sp, sp, 8        # fecha frame da pilha
    jalr x0, ra, 0        # retorna para o chamador

fim:
    jal x0, fim           # halt — loop infinito (equivalente ao HLT)
