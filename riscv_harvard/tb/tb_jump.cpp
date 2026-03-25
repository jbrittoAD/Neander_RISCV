// =============================================================================
// Testbench — Jumps (test_jump.hex)
// Validates: JAL (link and jump), JALR (indirect jump with return)
// Valida: JAL (link e salto), JALR (salto indireto com retorno)
//
// Expected layout (see test_jump.s):
// Layout esperado (ver test_jump.s):
//   PC 0x00: jal x1, func_a    → x1=0x04, jumps to 0x0C / salta para 0x0C
//   PC 0x04: addi x5,x0,77     → x5=77 (executed on return / executado ao retornar)
//   PC 0x0C: addi x2,x0,42     → x2=42 (in func_a / em func_a)
//   PC 0x10: jalr x0,x1,0      → returns to 0x04 / retorna para 0x04
//   PC 0x14: auipc x10,0       → x10=0x14
//   PC 0x18: addi x10,x10,16   → x10=0x24 (func_b)
//   PC 0x1C: jalr x3,x10,0     → x3=0x20, jumps to 0x24 / salta para 0x24
//   PC 0x24: addi x4,x0,99     → x4=99 (in func_b / em func_b)
//   PC 0x28: jalr x0,x3,0      → returns to 0x20 / retorna para 0x20
//   PC 0x2C: loop
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
        printf("  [PASS] x%-2d %-35s = 0x%08X (%d)\n",
               reg_num, name, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d %-35s : esperado=0x%08X (%d), obtido=0x%08X (%d)\n",
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

    printf("=== Teste de Jumps (test_jump.hex) ===\n\n");

    reset(dut, ctx);

    // Run enough cycles / Executa ciclos suficientes
    for (int i = 0; i < 30; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores após execução ]\n");

    // JAL saves PC+4 = 0x04 into x1 (ra)
    // JAL salva PC+4 = 0x04 em x1 (ra)
    check(dut, 1, 0x00000004, "JAL: ra = PC+4 = 0x04");

    // func_a: addi x2, x0, 42
    // In RISC-V ABI x2=sp, but in this test registers are used directly
    // No ABI RISC-V: x2=sp, mas em nosso teste usamos registradores diretamente
    check(dut, 2, 42,         "func_a: x2 = 42");

    // JALR saves PC+4 = 0x20 into x3 (gp)
    // JALR salva PC+4 = 0x20 em x3 (gp)
    check(dut, 3, 0x00000020, "JALR: x3 = PC+4 = 0x20");

    // func_b: addi x4, x0, 99
    check(dut, 4, 99,         "func_b: x4 = 99");

    // x5 = 77, executed after JAL return (PC=0x04)
    // x5 = 77, executado após retorno do JAL (PC=0x04)
    check(dut, 5, 77,         "retorno JAL: x5 = 77");

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
