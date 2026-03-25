// =============================================================================
// Testbench — Teste Aritmético (test_arith.hex)
// Valida: ADDI, ADD, SUB, AND, OR, XOR, SLTI, SLLI, SRLI, SRAI, SLT, SLTU
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

    printf("=== Teste Aritmético (test_arith.hex) ===\n\n");

    reset(dut, ctx);

    // Run enough cycles for all instructions (15 instructions + loop)
    // Executa instruções suficientes (15 instruções + loop)
    for (int i = 0; i < 20; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores após execução ]\n");
    check(dut,  1, 5,           "addi x0,5");
    check(dut,  2, 3,           "addi x0,3");
    check(dut,  3, 8,           "add x1,x2");
    check(dut,  4, 2,           "sub x1,x2");
    check(dut,  5, 1,           "and x1,x2");
    check(dut,  6, 7,           "or x1,x2");
    check(dut,  7, 6,           "xor x1,x2");
    check(dut,  8, 10,          "addi x1,5");
    check(dut,  9, 1,           "slti x2,5");
    check(dut, 10, 12,          "slli x2,2");
    check(dut, 11, 6,           "srli x10,1");
    check(dut, 12, 6,           "srai x10,1");
    check(dut, 13, (uint32_t)(-7), "addi x0,-7");
    check(dut, 14, 1,           "slt x13,x0");
    check(dut, 15, 1,           "sltu x0,x1");

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
