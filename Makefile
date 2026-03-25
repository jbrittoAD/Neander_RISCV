# =============================================================================
# Root Makefile — RISC-V RV32I Processor (Harvard + Von Neumann)
# Makefile raiz — Processador RISC-V RV32I (Harvard + Von Neumann)
# =============================================================================
#
# Runs all project stages: Verilator hardware, Python simulator,
# examples and exercise answer keys.
# Executa todas as etapas do projeto: hardware Verilator, simulador Python,
# exemplos e gabaritos de exercícios.
#
# Quick usage / Uso rápido:
#   make all           — test hardware + simulator + examples + keys / testa hardware + simulador + exemplos + gabaritos
#   make test          — tests only (hardware + simulator + keys) / apenas os testes (hardware + simulador + gabaritos)
#   make sim-test      — Python simulator tests only / apenas os testes do simulador Python
#   make hw-test       — Verilator tests only (Harvard + Von Neumann) / apenas os testes Verilator (Harvard + Von Neumann)
#   make exemplos      — compile and verify example programs / compila e verifica os programas de exemplo
#   make gabaritos     — automatically verify all 20 answer keys / verifica automaticamente todos os 20 gabaritos
#   make clean         — remove all generated files / remove todos os arquivos gerados
#   make help          — this help / esta ajuda

PYTHON := python3
MAKE   := make --no-print-directory

.PHONY: all test hw-test sim-test exemplos gabaritos clean help \
        harvard vonneumann \
        docker-build docker-run docker-test docker-compose-run

# =============================================================================
# Default target / Alvo padrão
# =============================================================================
all: hw-test sim-test exemplos gabaritos
	@echo ""
	@echo "╔══════════════════════════════════════════════════════╗"
	@echo "║  Todos os testes e verificações passaram!            ║"
	@echo "╚══════════════════════════════════════════════════════╝"

# =============================================================================
# Tests (without recompiling examples) / Testes (sem compilar exemplos novamente)
# =============================================================================
test: hw-test sim-test gabaritos
	@echo ""
	@echo "  [OK] Todos os testes passaram."

# =============================================================================
# Verilator Hardware / Hardware Verilator
# =============================================================================
hw-test: harvard vonneumann

harvard:
	@echo "--- Hardware Harvard (Verilator) ---"
	$(MAKE) -C riscv_harvard all

vonneumann:
	@echo "--- Hardware Von Neumann (Verilator) ---"
	$(MAKE) -C riscv_von_neumann all

# =============================================================================
# Python Simulator / Simulador Python
# =============================================================================
sim-test:
	@echo "--- Testes do simulador Python (89 verificações) ---"
	$(PYTHON) simulator/tests/test_core.py 2>&1 | tail -4

# =============================================================================
# Examples / Exemplos
# =============================================================================
exemplos:
	@echo "--- Compilando e verificando exemplos ---"
	$(MAKE) -C exemplos all

# =============================================================================
# Answer keys: automatically verify all 20 exercises
# Gabaritos: verifica todos os 20 exercícios automaticamente
# =============================================================================
gabaritos:
	@echo "--- Verificando gabaritos (Listas 1–4) ---"
	$(PYTHON) exercicios/verifica_gabaritos.py

# =============================================================================
# Cleanup / Limpeza
# =============================================================================
clean:
	$(MAKE) -C riscv_harvard clean      2>/dev/null || true
	$(MAKE) -C riscv_von_neumann clean  2>/dev/null || true
	$(MAKE) -C exemplos clean           2>/dev/null || true
	find exercicios -name "*.o" -o -name "*.bin" -o -name "*.hex" | xargs rm -f 2>/dev/null || true
	@echo "  [OK] Limpeza concluída."

# =============================================================================
# Docker
# =============================================================================
docker-build:
	docker build -t neander-riscv .

docker-run:
	docker run --rm -it -v $(CURDIR):/project neander-riscv bash

docker-test:
	docker run --rm -v $(CURDIR):/project neander-riscv \
		bash -c "cd /project && python3 simulator/tests/test_core.py && python3 exercicios/verifica_gabaritos.py"

docker-compose-run:
	docker-compose run --rm riscv

# =============================================================================
help:
	@echo ""
	@echo "Makefile raiz — RISC-V RV32I"
	@echo ""
	@echo "  make all          Tudo: hardware, simulador, exemplos, gabaritos"
	@echo "  make test         Apenas testes (hardware + sim + gabaritos)"
	@echo "  make hw-test      Testes Verilator (Harvard + Von Neumann)"
	@echo "  make sim-test     Testes do simulador Python"
	@echo "  make exemplos     Compila e verifica programas de exemplo"
	@echo "  make gabaritos    Verifica os 20 gabaritos de exercícios"
	@echo "  make clean        Remove arquivos gerados"
	@echo ""
