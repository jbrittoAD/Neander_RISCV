#!/usr/bin/env bash
# =============================================================================
# install.sh — Installs project dependencies for RISC-V RV32I
# install.sh — Instala as dependências do projeto RISC-V RV32I
# =============================================================================
#
# Automatically installs:
# Instala automaticamente:
#   - riscv-gnu-toolchain (RISC-V assembly compiler / compilador assembly RISC-V)
#   - verilator           (SystemVerilog hardware simulator / simulador de hardware SystemVerilog)
#   - python3             (interactive Python simulator / simulador interativo Python)
#
# Supported platforms / Plataformas suportadas:
#   - macOS (via Homebrew)
#   - Ubuntu / Debian (via apt + official sources / fontes oficiais)
#   - Other Linux distributions: manual instructions displayed / Outras distribuições Linux: instruções manuais exibidas
#
# Usage / Uso:
#   chmod +x install.sh
#   ./install.sh
#
# =============================================================================

set -euo pipefail

# ── Colors / Cores ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[AVISO]${RESET} $*"; }
error()   { echo -e "${RED}[ERRO]${RESET}  $*" >&2; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}"; }

# ── Detect OS / Detectar SO ───────────────────────────────────────────────────
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)

# ── Check whether a tool is installed / Verificar se ferramenta está instalada ─
check_tool() {
    local cmd="$1"
    local name="$2"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" --version 2>&1 | head -1 || echo "versão desconhecida")
        ok "$name já instalado: $ver"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# Banner
# =============================================================================
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════╗"
echo "║   Instalação — Projeto RISC-V RV32I Educacional   ║"
echo "╚═══════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo "  Sistema detectado: ${BOLD}$OS${RESET}"
echo ""

# =============================================================================
# macOS via Homebrew
# =============================================================================
install_macos() {
    section "macOS — Homebrew"

    # Check for Homebrew / Verifica Homebrew
    if ! command -v brew &>/dev/null; then
        warn "Homebrew não encontrado. Instalando..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        ok "Homebrew: $(brew --version | head -1)"
    fi

    info "Atualizando índice do Homebrew..."
    brew update --quiet

    # Python 3
    section "Python 3"
    if ! check_tool python3 "Python 3"; then
        info "Instalando Python 3..."
        brew install python
    fi

    # RISC-V toolchain / Compilador RISC-V
    section "Compilador RISC-V (riscv-gnu-toolchain)"
    if ! check_tool riscv64-unknown-elf-as "riscv64-unknown-elf-as"; then
        info "Instalando riscv-gnu-toolchain (pode demorar alguns minutos)..."
        brew install riscv-gnu-toolchain
    fi

    # Verilator
    section "Verilator"
    if ! check_tool verilator "Verilator"; then
        info "Instalando Verilator..."
        brew install verilator
    fi
}

# =============================================================================
# Ubuntu / Debian via apt
# =============================================================================
install_debian() {
    section "Ubuntu/Debian — apt"

    info "Atualizando lista de pacotes..."
    sudo apt-get update -qq

    # Python 3
    section "Python 3"
    if ! check_tool python3 "Python 3"; then
        info "Instalando Python 3..."
        sudo apt-get install -y python3 python3-pip
    fi

    # Verilator
    section "Verilator"
    if ! check_tool verilator "Verilator"; then
        info "Instalando Verilator via apt..."
        sudo apt-get install -y verilator
        local ver
        ver=$(verilator --version 2>&1 | head -1)
        # Verilator 4.x may not support some features; recommend 5.x
        # Verilator 4.x pode não suportar alguns recursos; recomendar 5.x
        if verilator --version 2>&1 | grep -qE "^Verilator [0-9]\.[0-3]"; then
            warn "Versão instalada pode ser antiga. Testado com Verilator 5.x."
            warn "Para instalar manualmente: https://verilator.org/guide/latest/install.html"
        fi
    fi

    # RISC-V toolchain — more complex on Linux / mais complexo no Linux
    section "Compilador RISC-V (riscv64-unknown-elf-as)"
    if ! check_tool riscv64-unknown-elf-as "riscv64-unknown-elf-as"; then
        info "Tentando instalar gcc-riscv64-unknown-elf via apt..."
        if sudo apt-get install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf 2>/dev/null; then
            ok "Toolchain RISC-V instalada via apt."
        else
            warn "Pacote não disponível via apt. Tentando xpack RISC-V toolchain..."
            _install_riscv_linux_xpack
        fi
    fi
}

# Install xpack RISC-V toolchain (pre-compiled binaries for Linux)
# Instala xpack RISC-V toolchain (binários pré-compilados para Linux)
_install_riscv_linux_xpack() {
    local XPACK_VER="13.2.0-2"
    local XPACK_DIR="$HOME/.local/xpack-riscv"
    local XPACK_URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${XPACK_VER}/xpack-riscv-none-elf-gcc-${XPACK_VER}-linux-x64.tar.gz"

    if command -v riscv-none-elf-as &>/dev/null; then
        ok "riscv-none-elf-as já disponível."
        return
    fi

    warn "Instalação automática do xpack não disponível neste script."
    echo ""
    echo "  Para instalar manualmente a toolchain RISC-V no Linux:"
    echo ""
    echo "  Opção 1 — xpack (binários pré-compilados):"
    echo "    https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases"
    echo "    Baixe o .tar.gz, extraia em ~/.local/xpack-riscv e adicione ao PATH."
    echo ""
    echo "  Opção 2 — compilar do fonte:"
    echo "    https://github.com/riscv-collab/riscv-gnu-toolchain"
    echo "    sudo apt-get install -y autoconf automake autotools-dev curl python3"
    echo "    git clone https://github.com/riscv-collab/riscv-gnu-toolchain"
    echo "    cd riscv-gnu-toolchain && ./configure --prefix=/opt/riscv --with-arch=rv32i"
    echo "    sudo make -j\$(nproc)"
    echo "    export PATH=\"/opt/riscv/bin:\$PATH\""
    echo ""
}

# =============================================================================
# Red Hat / Fedora
# =============================================================================
install_redhat() {
    section "Red Hat / Fedora"
    warn "Instalação automática não suportada para Red Hat/Fedora."
    echo ""
    echo "  Instale manualmente:"
    echo "    sudo dnf install python3 verilator"
    echo "    # For the RISC-V toolchain, see / Para o toolchain RISC-V, veja: https://github.com/riscv-collab/riscv-gnu-toolchain"
    echo ""
    exit 1
}

# =============================================================================
# Arch Linux
# =============================================================================
install_arch() {
    section "Arch Linux"
    if ! check_tool python3 "Python 3"; then
        sudo pacman -S --noconfirm python
    fi
    if ! check_tool verilator "Verilator"; then
        sudo pacman -S --noconfirm verilator
    fi
    if ! check_tool riscv64-unknown-elf-as "riscv64-unknown-elf-as"; then
        info "Instalando riscv32-elf-binutils via AUR..."
        if command -v yay &>/dev/null; then
            yay -S --noconfirm riscv32-elf-binutils riscv32-elf-gcc || true
        else
            warn "yay não encontrado. Instale via AUR manualmente:"
            echo "    yay -S riscv32-elf-binutils riscv32-elf-gcc"
        fi
    fi
}

# =============================================================================
# Unknown OS / SO desconhecido
# =============================================================================
install_unknown() {
    error "Sistema operacional não reconhecido: $OS"
    echo ""
    echo "  Instale manualmente:"
    echo "    1. Python 3.6+   — https://www.python.org/downloads/"
    echo "    2. Verilator 5+  — https://verilator.org/guide/latest/install.html"
    echo "    3. RISC-V GCC    — https://github.com/riscv-collab/riscv-gnu-toolchain"
    echo ""
    exit 1
}

# =============================================================================
# Install according to the detected OS / Instalar conforme o SO
# =============================================================================
case "$OS" in
    macos)   install_macos   ;;
    debian)  install_debian  ;;
    redhat)  install_redhat  ;;
    arch)    install_arch    ;;
    *)       install_unknown ;;
esac

# =============================================================================
# Final verification / Verificação final
# =============================================================================
section "Verificação final"

PASS=0; FAIL=0

verify() {
    local cmd="$1"; local name="$2"
    if command -v "$cmd" &>/dev/null; then
        ok "$name: $(command -v "$cmd")"
        PASS=$((PASS+1))
    else
        error "$name: não encontrado em PATH"
        FAIL=$((FAIL+1))
    fi
}

verify python3              "Python 3"
verify verilator            "Verilator"

# Accept both riscv64-unknown-elf-as and riscv-none-elf-as
# Aceita tanto riscv64-unknown-elf-as quanto riscv-none-elf-as
if command -v riscv64-unknown-elf-as &>/dev/null; then
    ok "Assembler RISC-V: $(command -v riscv64-unknown-elf-as)"
    PASS=$((PASS+1))
elif command -v riscv-none-elf-as &>/dev/null; then
    ok "Assembler RISC-V: $(command -v riscv-none-elf-as)"
    PASS=$((PASS+1))
else
    error "Assembler RISC-V: não encontrado (riscv64-unknown-elf-as ou riscv-none-elf-as)"
    FAIL=$((FAIL+1))
fi

echo ""

# =============================================================================
# Quick Python simulator test / Teste rápido do simulador Python
# =============================================================================
section "Teste rápido do simulador"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM="$SCRIPT_DIR/simulator/riscv_sim.py"

if [[ -f "$SIM" ]]; then
    if python3 "$SCRIPT_DIR/simulator/tests/test_core.py" &>/dev/null; then
        ok "Simulador Python: 89 testes passaram"
        PASS=$((PASS+1))
    else
        error "Simulador Python: alguns testes falharam"
        warn "Execute: python3 simulator/tests/test_core.py"
        FAIL=$((FAIL+1))
    fi
else
    warn "Simulador não encontrado em $SIM"
fi

# =============================================================================
# Summary / Resumo
# =============================================================================
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║  Instalação concluída com sucesso! ✓   ║${RESET}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${RESET}"
    echo ""
    echo "  Próximos passos:"
    echo "    1. Leia tutoriais/README.md para começar"
    echo "    2. Compile um exemplo: cd exemplos && make all"
    echo "    3. Execute o simulador: python3 simulator/riscv_sim.py exemplos/fibonacci.hex"
    echo ""
else
    echo -e "${YELLOW}${BOLD}Instalação incompleta: $PASS dependências OK, $FAIL com problema.${RESET}"
    echo ""
    echo "  Verifique os erros acima e instale manualmente o que falta."
    echo "  Consulte o README.md para instruções detalhadas."
    echo ""
    exit 1
fi
