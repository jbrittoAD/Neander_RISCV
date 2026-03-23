# =============================================================================
# Makefile — Processador RISC-V Harvard (Verilator)
# =============================================================================

# Ferramentas
VERILATOR   := verilator
AS          := riscv64-unknown-elf-as
OBJCOPY     := riscv64-unknown-elf-objcopy
OBJDUMP     := riscv64-unknown-elf-objdump
PYTHON      := python3

# Diretórios
SRC_DIR     := src
TB_DIR      := tb
PROG_DIR    := programs
SIM_DIR     := sim
OBJ_DIR     := obj_dir

# Flags base do Verilator
VFLAGS_BASE := --cc --sv --exe --build \
               --Mdir $(OBJ_DIR) \
               -I$(SRC_DIR) \
               -Wall \
               -Wno-UNUSEDSIGNAL

# Flags do assembler RISC-V
AS_FLAGS    := -march=rv32i -mabi=ilp32

# =============================================================================
# Alvos principais
# =============================================================================
.PHONY: all programs alu regfile arith loadstore branch jump wave clean help

all: programs alu regfile arith loadstore branch jump
	@echo ""
	@echo "============================================"
	@echo "  Todos os testes concluidos!"
	@echo "============================================"

# =============================================================================
# Monta programas de teste
# =============================================================================
programs: $(PROG_DIR)/test_arith.hex \
          $(PROG_DIR)/test_load_store.hex \
          $(PROG_DIR)/test_branch.hex \
          $(PROG_DIR)/test_jump.hex
	@echo "[OK] Programas montados"

$(PROG_DIR)/test_arith.hex: $(PROG_DIR)/test_arith.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_arith.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_arith.o > $(PROG_DIR)/test_arith.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_arith.o $(PROG_DIR)/test_arith.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_arith.bin $@

$(PROG_DIR)/test_load_store.hex: $(PROG_DIR)/test_load_store.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_load_store.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_load_store.o > $(PROG_DIR)/test_load_store.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_load_store.o $(PROG_DIR)/test_load_store.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_load_store.bin $@

$(PROG_DIR)/test_branch.hex: $(PROG_DIR)/test_branch.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_branch.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_branch.o > $(PROG_DIR)/test_branch.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_branch.o $(PROG_DIR)/test_branch.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_branch.bin $@

$(PROG_DIR)/test_jump.hex: $(PROG_DIR)/test_jump.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_jump.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_jump.o > $(PROG_DIR)/test_jump.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_jump.o $(PROG_DIR)/test_jump.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_jump.bin $@

# =============================================================================
# Teste da ALU (unitário)
# =============================================================================
alu: $(OBJ_DIR)/Valu
	@echo ""
	@echo "=== Executando teste da ALU ==="
	$(OBJ_DIR)/Valu
	@echo ""

$(OBJ_DIR)/Valu: $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module alu \
	    $(SRC_DIR)/alu.sv \
	    $(TB_DIR)/tb_alu.cpp \
	    -o Valu

# =============================================================================
# Teste do Banco de Registradores (unitário)
# =============================================================================
regfile: $(OBJ_DIR)/Vregfile
	@echo ""
	@echo "=== Executando teste do Banco de Registradores ==="
	$(OBJ_DIR)/Vregfile
	@echo ""

$(OBJ_DIR)/Vregfile: $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module register_file \
	    $(SRC_DIR)/register_file.sv \
	    $(TB_DIR)/tb_regfile.cpp \
	    -o Vregfile

# =============================================================================
# Compilação única do simulador do processador completo
# (um único binário — o programa é selecionado pelo hex copiado para sim/)
# =============================================================================

# Binários de simulação por testbench
$(OBJ_DIR)/Varith: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv \
	    $(TB_DIR)/tb_arith.cpp \
	    -o Varith

$(OBJ_DIR)/Vloadstore: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv \
	    $(TB_DIR)/tb_loadstore.cpp \
	    -o Vloadstore

$(OBJ_DIR)/Vbranch: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv \
	    $(TB_DIR)/tb_branch.cpp \
	    -o Vbranch

$(OBJ_DIR)/Vjump: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv \
	    $(TB_DIR)/tb_jump.cpp \
	    -o Vjump

# =============================================================================
# Execução dos testes integrados
# (copia o hex correto para sim/program.hex e executa de lá)
# =============================================================================
arith: $(OBJ_DIR)/Varith $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Aritmético ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Varith
	@echo ""

loadstore: $(OBJ_DIR)/Vloadstore $(PROG_DIR)/test_load_store.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_load_store.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Load/Store ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vloadstore
	@echo ""

branch: $(OBJ_DIR)/Vbranch $(PROG_DIR)/test_branch.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_branch.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Branches ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vbranch
	@echo ""

jump: $(OBJ_DIR)/Vjump $(PROG_DIR)/test_jump.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_jump.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Jumps ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vjump
	@echo ""

# =============================================================================
# Waveform VCD — gera sim/waves.vcd para visualizar no GTKWave
# =============================================================================
wave: $(OBJ_DIR)/Vwave $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Gerando Waveform VCD ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vwave
	@echo ""

$(OBJ_DIR)/Vwave: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_wave.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --trace \
	    --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv \
	    $(TB_DIR)/tb_wave.cpp \
	    -o Vwave

# =============================================================================
# Limpeza
# =============================================================================
clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)
	rm -f $(PROG_DIR)/*.o $(PROG_DIR)/*.bin $(PROG_DIR)/*.dis $(PROG_DIR)/*.hex

help:
	@echo "Alvos disponíveis:"
	@echo "  make all        — monta programas + executa todos os testes"
	@echo "  make programs   — monta apenas os programas .hex"
	@echo "  make alu        — testa a ALU isoladamente"
	@echo "  make regfile    — testa o banco de registradores"
	@echo "  make arith      — executa teste aritmético no processador"
	@echo "  make loadstore  — executa teste de load/store"
	@echo "  make branch     — executa teste de branches"
	@echo "  make jump       — executa teste de jumps"
	@echo "  make wave       — gera sim/waves.vcd para GTKWave"
	@echo "  make clean      — remove arquivos gerados"
