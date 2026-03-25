// =============================================================================
// Testbench — Load/Store (test_load_store.hex)
// Valida: LW/SW (word), LBU/SB (byte sem sinal), LB/SB (byte com sinal),
//         LHU/SH (half-word sem sinal)
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
        printf("  [PASS] x%-2d %-20s = 0x%08X (%d)\n",
               reg_num, name, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d %-20s : esperado=0x%08X (%d), obtido=0x%08X (%d)\n",
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

    printf("=== Teste Load/Store (test_load_store.hex) ===\n\n");

    reset(dut, ctx);

    // 14 instructions + loop — 20 cycles is enough
    // 14 instruções + loop = 20 ciclos é suficiente
    for (int i = 0; i < 25; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores após execução ]\n");
    // x1 = 100 (original value / valor original)
    check(dut, 1, 100,        "addi x0,100");
    // x2 = 100 (read back via LW / lido via LW)
    check(dut, 2, 100,        "lw mem[0]");
    // x3 = 0x55 (unsigned byte stored / byte sem sinal armazenado)
    check(dut, 3, 0x55,       "addi x0,0x55");
    // x4 = 0x55 (read via LBU / lido via LBU)
    check(dut, 4, 0x55,       "lbu mem[4]");
    // x5 = -85 (0xFFFFFFAB)
    check(dut, 5, (uint32_t)(-85), "addi x0,-85");
    // x6 = -85 (read via LB with sign extension / lido via LB com extensão de sinal)
    check(dut, 6, (uint32_t)(-85), "lb mem[8] sext");
    // x7 = 0x1234 (half-word)
    check(dut, 7, 0x1234,     "half-word 0x1234");
    // x8 = 0x1234 (read via LHU / lido via LHU)
    check(dut, 8, 0x1234,     "lhu mem[12]");

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
