# =============================================================================
# Comprimento de String (strlen) — RISC-V RV32I
# =============================================================================
#
# Armazena a string "RISC-V\0" byte a byte na memória de dados usando sb,
# depois percorre os bytes até encontrar o terminador nulo (\0) e conta
# quantos caracteres há antes dele.
#
# String "RISC-V\0" em ASCII:
#   'R' = 0x52,  'I' = 0x49,  'S' = 0x53,  'C' = 0x43
#   '-' = 0x2D,  'V' = 0x56,  '\0'= 0x00
#
# Algoritmo:
#   armazena cada byte em dmem[0..6] com sb
#   ponteiro = endereço base
#   comprimento = 0
#   enquanto mem[ponteiro] != 0:
#       comprimento++
#       ponteiro++
#
# Este exemplo demonstra:
# - Armazenamento de bytes individuais com sb
# - Leitura de bytes individuais com lbu (load byte sem extensão de sinal)
# - Laço com condição de parada em byte nulo (terminador de string)
# - Diferença entre sb/lbu (byte) e sw/lw (word)
#
# Mapeamento de registradores:
#   x1 = ponteiro atual (endereço do byte em leitura)
#   x2 = comprimento   (número de bytes contados, sem contar o '\0')
#   x3 = byte lido     (valor do byte atual)
#   x6 = endereço base (fixo em 0, para escrita da string)
#
# String:             "RISC-V\0" em dmem[0]
# Resultado esperado: x2 = 6  (tamanho de "RISC-V")
#
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/strlen.hex
#   riscv> run
#   riscv> reg        ← x2 deve ser 6
#   riscv> mem 0x0000 2  ← mostra os 2 words (8 bytes) com a string
# =============================================================================

.section .text
.global _start
_start:
    # ─── Armazena "RISC-V\0" na memória de dados ──────────────────────
    addi  x6, x0, 0          # x6 = endereço base = 0

    addi  x3, x0, 0x52       # x3 = 'R' (0x52)
    sb    x3, 0(x6)          # dmem[0] = 'R'

    addi  x3, x0, 0x49       # x3 = 'I' (0x49)
    sb    x3, 1(x6)          # dmem[1] = 'I'

    addi  x3, x0, 0x53       # x3 = 'S' (0x53)
    sb    x3, 2(x6)          # dmem[2] = 'S'

    addi  x3, x0, 0x43       # x3 = 'C' (0x43)
    sb    x3, 3(x6)          # dmem[3] = 'C'

    addi  x3, x0, 0x2D       # x3 = '-' (0x2D)
    sb    x3, 4(x6)          # dmem[4] = '-'

    addi  x3, x0, 0x56       # x3 = 'V' (0x56)
    sb    x3, 5(x6)          # dmem[5] = 'V'

    addi  x3, x0, 0x00       # x3 = '\0' (terminador nulo)
    sb    x3, 6(x6)          # dmem[6] = '\0'

    # ─── Inicializa ponteiro e contador ───────────────────────────────
    addi  x1, x0, 0          # x1 = ponteiro = endereço base (inicio da string)
    addi  x2, x0, 0          # x2 = comprimento = 0

    # ─── Loop: conta bytes até encontrar '\0' ─────────────────────────
conta:
    lbu   x3, 0(x1)          # x3 = byte na posição atual (sem extensão de sinal)
    beq   x3, x0, fim        # se byte == 0 ('\0'), termina contagem

    addi  x2, x2, 1          # comprimento++
    addi  x1, x1, 1          # avança ponteiro para o próximo byte
    jal   x0, conta          # repete o loop

fim:
    # x2 = 6  (comprimento de "RISC-V", sem contar o '\0')
    jal   x0, fim            # halt — loop infinito (equivalente ao HLT)
