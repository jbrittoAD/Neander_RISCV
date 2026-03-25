# =============================================================================
# String Length (strlen) — RISC-V RV32I
# Comprimento de String (strlen) — RISC-V RV32I
# =============================================================================
#
# Stores the string "RISC-V\0" byte by byte in data memory using sb,
# Armazena a string "RISC-V\0" byte a byte na memória de dados usando sb,
# then walks through the bytes until the null terminator (\0) is found and
# depois percorre os bytes até encontrar o terminador nulo (\0) e conta
# counts how many characters precede it.
# quantos caracteres há antes dele.
#
# String "RISC-V\0" in ASCII:
# String "RISC-V\0" em ASCII:
#   'R' = 0x52,  'I' = 0x49,  'S' = 0x53,  'C' = 0x43
#   '-' = 0x2D,  'V' = 0x56,  '\0'= 0x00
#
# Algorithm:
# Algoritmo:
#   store each byte in dmem[0..6] with sb / armazena cada byte em dmem[0..6] com sb
#   pointer = base address / ponteiro = endereço base
#   length = 0 / comprimento = 0
#   while mem[pointer] != 0:
#   enquanto mem[ponteiro] != 0:
#       length++ / comprimento++
#       pointer++ / ponteiro++
#
# This example demonstrates:
# Este exemplo demonstra:
# - Individual byte storage with sb / Armazenamento de bytes individuais com sb
# - Individual byte reading with lbu (load byte without sign extension)
#   Leitura de bytes individuais com lbu (load byte sem extensão de sinal)
# - Loop with null-byte stop condition (string terminator)
#   Laço com condição de parada em byte nulo (terminador de string)
# - Difference between sb/lbu (byte) and sw/lw (word) / Diferença entre sb/lbu (byte) e sw/lw (word)
#
# Register mapping:
# Mapeamento de registradores:
#   x1 = current pointer (address of byte being read / endereço do byte em leitura)
#   x2 = length   (number of bytes counted, not counting '\0' / número de bytes contados, sem contar o '\0')
#   x3 = byte read (value of current byte / valor do byte atual)
#   x6 = base address (fixed at 0, for writing the string / fixo em 0, para escrita da string)
#
# String:             "RISC-V\0" in dmem[0] / em dmem[0]
# Expected result:    x2 = 6  (length of "RISC-V" / tamanho de "RISC-V")
#
# How to verify with the simulator:
# Como verificar com o simulador:
#   python3 simulator/riscv_sim.py exemplos/strlen.hex
#   riscv> run
#   riscv> reg        ← x2 should be 6 / x2 deve ser 6
#   riscv> mem 0x0000 2  ← shows the 2 words (8 bytes) with the string / mostra os 2 words (8 bytes) com a string
# =============================================================================

.section .text
.global _start
_start:
    # ─── Store "RISC-V\0" in data memory / Armazena "RISC-V\0" na memória de dados ───
    addi  x6, x0, 0          # x6 = base address = 0 / endereço base = 0

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

    addi  x3, x0, 0x00       # x3 = '\0' (null terminator / terminador nulo)
    sb    x3, 6(x6)          # dmem[6] = '\0'

    # ─── Initialize pointer and counter / Inicializa ponteiro e contador ──
    addi  x1, x0, 0          # x1 = pointer = base address (start of string / inicio da string)
    addi  x2, x0, 0          # x2 = length = 0 / comprimento = 0

    # ─── Loop: count bytes until '\0' is found / Loop: conta bytes até encontrar '\0' ───
conta:
    lbu   x3, 0(x1)          # x3 = byte at current position (no sign extension / sem extensão de sinal)
    beq   x3, x0, fim        # if byte == 0 ('\0'), end counting / se byte == 0 ('\0'), termina contagem

    addi  x2, x2, 1          # length++ / comprimento++
    addi  x1, x1, 1          # advance pointer to next byte / avança ponteiro para o próximo byte
    jal   x0, conta          # repeat the loop / repete o loop

fim:
    # x2 = 6  (length of "RISC-V", not counting '\0' / comprimento de "RISC-V", sem contar o '\0')
    jal   x0, fim            # halt — infinite loop (equivalent to HLT) / loop infinito (equivalente ao HLT)
