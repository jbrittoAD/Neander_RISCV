// =============================================================================
// Testbench — Branches (test_branch.hex)
// Valida: BEQ, BNE, BLT, BGE, BLTU
// Verifica que branches corretos são/não são tomados
// =============================================================================
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstdint>

static int passed = 0;
static int failed = 0;

void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx); tick(dut, ctx);
    dut->rst_n = 1;
}

uint32_t read_reg(Vriscv_top* dut, int reg_num) {
    dut->dbg_reg_sel = reg_num;
    dut->eval();
    return dut->dbg_reg_val;
}

void check(Vriscv_top* dut, int reg_num, uint32_t expected, const char* name) {
    uint32_t got = read_reg(dut, reg_num);
    if (got == expected) {
        printf("  [PASS] x%-2d %-30s = 0x%08X (%d)\n",
               reg_num, name, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d %-30s : esperado=0x%08X (%d), obtido=0x%08X (%d)\n",
               reg_num, name, expected, (int32_t)expected, got, (int32_t)got);
        failed++;
    }
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    Vriscv_top* dut = new Vriscv_top{ctx};
    dut->clk        = 0;
    dut->rst_n      = 1;
    dut->dbg_reg_sel= 0;
    dut->eval();

    printf("=== Teste de Branches (test_branch.hex) ===\n\n");

    reset(dut, ctx);

    // Suficiente para executar todo o programa
    for (int i = 0; i < 40; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores após execução ]\n");

    // x1=5, x2=5 (valores iniciais)
    check(dut,  1, 5,   "addi: x1=5");
    check(dut,  2, 5,   "addi: x2=5");

    // BEQ x1,x2 → tomado → x3 deve ser 99 (NÃO 1)
    check(dut,  3, 99,  "BEQ tomado: x3 deve ser 99");

    // BNE x1,x2 → não tomado (x1==x2) → x4=0
    check(dut,  4, 0,   "BNE nao tomado: x4=0");

    // BLT: 3 < 5 → tomado → x5=1
    check(dut,  5, 1,   "BLT tomado: x5=1");

    // BGE: 5 >= 5 → tomado → x6=1
    check(dut,  6, 1,   "BGE tomado: x6=1");

    // BLTU: 0 < 0xFFFFFFFF → tomado → x7=1
    check(dut,  7, 1,   "BLTU tomado: x7=1");

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
