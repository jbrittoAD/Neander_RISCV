// =============================================================================
// Testbench do Banco de Registradores — Verilator C++
// Testa: escrita/leitura, x0 sempre zero, multi-porta
// =============================================================================
#include <verilated.h>
#include "Vregister_file.h"
#include <cstdio>

static int passed = 0;
static int failed = 0;

void tick(Vregister_file* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

void check_val(uint32_t got, uint32_t expected, const char* name) {
    if (got == expected) {
        printf("  [PASS] %s\n", name);
        passed++;
    } else {
        printf("  [FAIL] %s: esperado=0x%08X obtido=0x%08X\n",
               name, expected, got);
        failed++;
    }
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    Vregister_file* dut = new Vregister_file{ctx};

    // Inicializa entradas
    dut->clk = 0;
    dut->we  = 0;
    dut->rs1 = 0;
    dut->rs2 = 0;
    dut->rd  = 0;
    dut->wd  = 0;

    printf("=== Teste do Banco de Registradores ===\n\n");

    // ------------------------------------------------------------------
    // Escreve em x1 = 42
    // ------------------------------------------------------------------
    printf("[ Escrita e Leitura ]\n");
    dut->we  = 1;
    dut->rd  = 1;       // x1
    dut->wd  = 42;
    tick(dut, ctx);

    dut->we  = 0;
    dut->rs1 = 1;       // lê x1
    dut->eval();
    check_val(dut->rd1, 42, "x1 = 42 apos escrita");

    // ------------------------------------------------------------------
    // Escreve em x5 = 0xDEADBEEF
    // ------------------------------------------------------------------
    dut->we  = 1;
    dut->rd  = 5;
    dut->wd  = 0xDEADBEEF;
    tick(dut, ctx);

    dut->we  = 0;
    dut->rs1 = 5;
    dut->eval();
    check_val(dut->rd1, 0xDEADBEEF, "x5 = 0xDEADBEEF");

    // ------------------------------------------------------------------
    // x0 nunca é alterado (hardwired zero)
    // ------------------------------------------------------------------
    printf("[ x0 hardwired zero ]\n");
    dut->we  = 1;
    dut->rd  = 0;       // tenta escrever em x0
    dut->wd  = 0xCAFEBABE;
    tick(dut, ctx);

    dut->we  = 0;
    dut->rs1 = 0;
    dut->eval();
    check_val(dut->rd1, 0, "x0 permanece 0 apos tentativa de escrita");

    // ------------------------------------------------------------------
    // Leitura de dois registradores simultaneamente
    // ------------------------------------------------------------------
    printf("[ Leitura dupla ]\n");
    dut->we  = 1;
    dut->rd  = 10; dut->wd = 100; tick(dut, ctx);
    dut->we  = 1;
    dut->rd  = 11; dut->wd = 200; tick(dut, ctx);

    dut->we  = 0;
    dut->rs1 = 10;
    dut->rs2 = 11;
    dut->eval();
    check_val(dut->rd1, 100, "x10 = 100");
    check_val(dut->rd2, 200, "x11 = 200");

    // ------------------------------------------------------------------
    // Registradores anteriores não foram afetados
    // ------------------------------------------------------------------
    printf("[ Persistência de dados ]\n");
    dut->rs1 = 1;
    dut->rs2 = 5;
    dut->eval();
    check_val(dut->rd1, 42,         "x1 ainda = 42");
    check_val(dut->rd2, 0xDEADBEEF, "x5 ainda = 0xDEADBEEF");

    // ------------------------------------------------------------------
    // Escrita em todos os 31 registradores (x1-x31)
    // ------------------------------------------------------------------
    printf("[ Escrita em x1-x31 ]\n");
    for (int i = 1; i < 32; i++) {
        dut->we  = 1;
        dut->rd  = i;
        dut->wd  = i * 100;
        tick(dut, ctx);
    }
    bool all_ok = true;
    for (int i = 1; i < 32; i++) {
        dut->we  = 0;
        dut->rs1 = i;
        dut->eval();
        if (dut->rd1 != (uint32_t)(i * 100)) {
            printf("  [FAIL] x%d esperado=%d obtido=%d\n", i, i*100, dut->rd1);
            all_ok = false;
            failed++;
        }
    }
    if (all_ok) {
        printf("  [PASS] Todos os registradores x1-x31 corretos\n");
        passed++;
    }

    // ------------------------------------------------------------------
    // Resultado
    // ------------------------------------------------------------------
    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
