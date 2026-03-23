# =============================================================================
# Makefile raiz — Processador RISC-V RV32I (Harvard + Von Neumann)
# =============================================================================
#
# Executa todas as etapas do projeto: hardware Verilator, simulador Python,
# exemplos e gabaritos de exercícios.
#
# Uso rápido:
#   make all           — testa hardware + simulador + exemplos + gabaritos
#   make test          — apenas os testes (hardware + simulador + gabaritos)
#   make sim-test      — apenas os testes do simulador Python
#   make hw-test       — apenas os testes Verilator (Harvard + Von Neumann)
#   make exemplos      — compila e verifica os programas de exemplo
#   make gabaritos     — verifica automaticamente todos os 20 gabaritos
#   make clean         — remove todos os arquivos gerados
#   make help          — esta ajuda

PYTHON := python3
MAKE   := make --no-print-directory

.PHONY: all test hw-test sim-test exemplos gabaritos clean help \
        harvard vonneumann \
        docker-build docker-run docker-test docker-compose-run

# =============================================================================
# Alvo padrão
# =============================================================================
all: hw-test sim-test exemplos gabaritos
	@echo ""
	@echo "╔══════════════════════════════════════════════════════╗"
	@echo "║  Todos os testes e verificações passaram!            ║"
	@echo "╚══════════════════════════════════════════════════════╝"

# =============================================================================
# Testes (sem compilar exemplos novamente)
# =============================================================================
test: hw-test sim-test gabaritos
	@echo ""
	@echo "  [OK] Todos os testes passaram."

# =============================================================================
# Hardware Verilator
# =============================================================================
hw-test: harvard vonneumann

harvard:
	@echo "--- Hardware Harvard (Verilator) ---"
	$(MAKE) -C riscv_harvard all

vonneumann:
	@echo "--- Hardware Von Neumann (Verilator) ---"
	$(MAKE) -C riscv_von_neumann all

# =============================================================================
# Simulador Python
# =============================================================================
sim-test:
	@echo "--- Testes do simulador Python (89 verificações) ---"
	$(PYTHON) simulator/tests/test_core.py 2>&1 | tail -4

# =============================================================================
# Exemplos
# =============================================================================
exemplos:
	@echo "--- Compilando e verificando exemplos ---"
	$(MAKE) -C exemplos all

# =============================================================================
# Gabaritos: verifica todos os 20 exercícios automaticamente
# =============================================================================
gabaritos:
	@echo "--- Verificando gabaritos (Listas 1–4) ---"
	$(PYTHON) exercicios/verifica_gabaritos.py

# =============================================================================
# Limpeza
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
