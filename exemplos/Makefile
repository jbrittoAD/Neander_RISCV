# =============================================================================
# Makefile — Programas de Exemplo RISC-V RV32I
# =============================================================================
#
# Compila todos os programas de exemplo para .hex e verifica com o simulador.
#
# Uso:
#   make all        — compila e verifica todos
#   make hex        — compila para .hex (sem verificar)
#   make verify     — verifica resultados com o simulador
#   make clean      — remove arquivos gerados
#   make help       — mostra esta ajuda

AS       := riscv64-unknown-elf-as
OBJCOPY  := riscv64-unknown-elf-objcopy
OBJDUMP  := riscv64-unknown-elf-objdump
PYTHON   := python3

AS_FLAGS := -march=rv32i -mabi=ilp32

SIM      := $(CURDIR)/../simulator/riscv_sim.py

# Programas de exemplo
PROGS := fibonacci factorial max_array sum_array bubblesort counter abs_value gcd power strlen binary_search selection_sort

HEX_FILES := $(addsuffix .hex, $(PROGS))
DIS_FILES := $(addsuffix .dis, $(PROGS))

.PHONY: all hex verify clean help $(PROGS)

# =============================================================================
all: hex verify
	@echo ""
	@echo "============================================"
	@echo "  Todos os exemplos compilados e verificados!"
	@echo "============================================"

# =============================================================================
# Compilação: .s → .o → .bin → .hex + .dis
# =============================================================================
hex: $(HEX_FILES)
	@echo "[OK] Programas de exemplo compilados"

%.hex: %.s
	@echo "  Montando $<..."
	$(AS) $(AS_FLAGS) -o $*.o $<
	$(OBJCOPY) -O binary $*.o $*.bin
	$(PYTHON) ../riscv_harvard/scripts/bin2hex.py $*.bin $*.hex
	$(OBJDUMP) -d $*.o > $*.dis
	@echo "  → $*.hex gerado"

# =============================================================================
# Verificação: roda cada programa e mostra resultado
# =============================================================================
verify: hex
	@echo ""
	@echo "--- Verificando programas de exemplo ---"
	@for prog in $(PROGS); do \
		echo ""; \
		echo "  $${prog}:"; \
		$(PYTHON) $(SIM) $${prog}.hex --run 2>&1 | sed 's/^/    /'; \
	done

# =============================================================================
# Limpeza
# =============================================================================
clean:
	rm -f *.o *.bin *.hex *.dis

# =============================================================================
help:
	@echo "Makefile — Exemplos RISC-V"
	@echo ""
	@echo "  make all      Compila e verifica todos os programas"
	@echo "  make hex      Compila para .hex"
	@echo "  make verify   Verifica resultados com simulador"
	@echo "  make clean    Remove arquivos gerados"
	@echo ""
	@echo "Programas disponíveis:"
	@for p in $(PROGS); do echo "  $$p.s"; done
