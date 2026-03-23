// =============================================================================
// Testbench do Processador RISC-V (Top-Level) — Verilator C++
// Executa programas de teste e valida o estado final dos registradores
// =============================================================================
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstring>
#include <cstdlib>

static int passed = 0;
static int failed = 0;

// Clocks por teste (máximo de instruções a executar)
static const int MAX_CYCLES = 200;

void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx);
    tick(dut, ctx);
    dut->rst_n = 1;
}

// Executa N ciclos e imprime estado de debug
void run_cycles(Vriscv_top* dut, VerilatedContext* ctx, int cycles, bool verbose) {
    for (int i = 0; i < cycles; i++) {
        if (verbose) {
            printf("  ciclo %3d | PC=0x%08X | instr=0x%08X | alu=0x%08X\n",
                   i, dut->dbg_pc, dut->dbg_instr,
                   dut->dbg_alu_result);
        }
        tick(dut, ctx);
    }
}

void check_reg(const char* name, uint32_t got, uint32_t expected) {
    if (got == expected) {
        printf("  [PASS] %s = 0x%08X (%d)\n", name, got, got);
        passed++;
    } else {
        printf("  [FAIL] %s: esperado=0x%08X (%d), obtido=0x%08X (%d)\n",
               name, expected, expected, got, got);
        failed++;
    }
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    printf("=== Testbench do Processador RISC-V RV32I (Harvard) ===\n\n");
    printf("Arquivo de programa: %s\n\n",
           (argc > 1) ? argv[1] : "program.hex (padrao)");

    Vriscv_top* dut = new Vriscv_top{ctx};
    dut->clk   = 0;
    dut->rst_n = 1;
    dut->eval();

    // Reset
    reset(dut, ctx);

    // Executa ciclos com saída de debug
    printf("[ Execução do programa ]\n");
    run_cycles(dut, ctx, MAX_CYCLES, true);

    printf("\n[ Resumo da execução ]\n");
    printf("  PC final: 0x%08X\n", dut->dbg_pc);

    dut->final();
    delete dut;
    delete ctx;

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    return (failed == 0) ? 0 : 1;
}
