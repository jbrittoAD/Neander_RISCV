# =============================================================================
# Makefile — Processador RISC-V Von Neumann (Verilator)
# =============================================================================

VERILATOR   := verilator
AS          := riscv64-unknown-elf-as
OBJCOPY     := riscv64-unknown-elf-objcopy
OBJDUMP     := riscv64-unknown-elf-objdump
PYTHON      := python3

SRC_DIR     := src
TB_DIR      := tb
PROG_DIR    := programs
SIM_DIR     := sim
OBJ_DIR     := obj_dir

VFLAGS_BASE := --cc --sv --exe --build \
               --Mdir $(OBJ_DIR) \
               -I$(SRC_DIR) \
               -Wall \
               -Wno-UNUSEDSIGNAL

AS_FLAGS    := -march=rv32i -mabi=ilp32

# =============================================================================
.PHONY: all programs alu regfile arith loadstore branch jump clean help

all: programs alu regfile arith loadstore branch jump
	@echo ""
	@echo "============================================"
	@echo "  Todos os testes (Von Neumann) concluidos!"
	@echo "============================================"

# =============================================================================
programs: $(PROG_DIR)/test_arith.hex \
          $(PROG_DIR)/test_load_store.hex \
          $(PROG_DIR)/test_branch.hex \
          $(PROG_DIR)/test_jump.hex

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
alu: $(OBJ_DIR)/Valu
	@echo ""
	@echo "=== Executando teste da ALU ==="
	$(OBJ_DIR)/Valu
	@echo ""

$(OBJ_DIR)/Valu: $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module alu \
	    $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp -o Valu

# =============================================================================
regfile: $(OBJ_DIR)/Vregfile
	@echo ""
	@echo "=== Executando teste do Banco de Registradores ==="
	$(OBJ_DIR)/Vregfile
	@echo ""

$(OBJ_DIR)/Vregfile: $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module register_file \
	    $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp -o Vregfile

# =============================================================================
$(OBJ_DIR)/Varith: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp -o Varith

$(OBJ_DIR)/Vloadstore: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp -o Vloadstore

$(OBJ_DIR)/Vbranch: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp -o Vbranch

$(OBJ_DIR)/Vjump: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp -o Vjump

# =============================================================================
arith: $(OBJ_DIR)/Varith $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Aritmético (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Varith
	@echo ""

loadstore: $(OBJ_DIR)/Vloadstore $(PROG_DIR)/test_load_store.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_load_store.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Load/Store (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vloadstore
	@echo ""

branch: $(OBJ_DIR)/Vbranch $(PROG_DIR)/test_branch.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_branch.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Branches (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vbranch
	@echo ""

jump: $(OBJ_DIR)/Vjump $(PROG_DIR)/test_jump.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_jump.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Jumps (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vjump
	@echo ""

# =============================================================================
clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)
	rm -f $(PROG_DIR)/*.o $(PROG_DIR)/*.bin $(PROG_DIR)/*.dis $(PROG_DIR)/*.hex

help:
	@echo "Alvos: all | programs | alu | regfile | arith | loadstore | branch | jump | clean"
