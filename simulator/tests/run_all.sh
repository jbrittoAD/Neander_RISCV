#!/usr/bin/env bash
# =============================================================================
# Executa toda a suíte de testes do simulador RISC-V
# =============================================================================
#
# Uso: ./tests/run_all.sh
# Ou com pytest: python3 -m pytest tests/ -v
#
# Testes unitários (test_core.py) não precisam de pré-requisitos externos.
# Testes de integração (test_programs.py) precisam de 'make programs' nas
# versões harvard e von_neumann.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$SIM_DIR")"

echo "======================================================================="
echo "  Suíte de Testes — Simulador RISC-V RV32I"
echo "======================================================================="
echo ""

# Verifica se Python 3 está disponível
if ! command -v python3 &>/dev/null; then
    echo "ERRO: python3 não encontrado."
    exit 1
fi

# Compila os programas de teste, se possível
for version in harvard von_neumann; do
    dir="$ROOT_DIR/riscv_$version"
    if [ -f "$dir/Makefile" ]; then
        echo ">>> Compilando programas: riscv_$version/"
        (cd "$dir" && make programs -s 2>/dev/null) && echo "    OK" || echo "    AVISO: falha ao compilar (testes de integração serão ignorados)"
    fi
done

echo ""
echo "--- Testes unitários (test_core.py) ---"
python3 -m pytest "$SCRIPT_DIR/test_core.py" -v 2>/dev/null || \
    python3 "$SCRIPT_DIR/test_core.py"

echo ""
echo "--- Testes de integração (test_programs.py) ---"
python3 -m pytest "$SCRIPT_DIR/test_programs.py" -v 2>/dev/null || \
    python3 "$SCRIPT_DIR/test_programs.py"

echo ""
echo "======================================================================="
echo "  Todos os testes concluídos."
echo "======================================================================="
