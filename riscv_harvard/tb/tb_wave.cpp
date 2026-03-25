// =============================================================================
// VCD Testbench — Waveform Generator for GTKWave
// Testbench VCD — Gerador de Waveform para GTKWave
// =============================================================================
//
// Runs test_arith.hex for 30 cycles and produces sim/waves.vcd with all
// Executa test_arith.hex por 30 ciclos e gera sim/waves.vcd com todos os sinais
// internal processor signals. Open with GTKWave to inspect.
// internos do processador. Abra com GTKWave para visualizar.
//
// Usage / Uso:
//   make wave              (compiles and runs, produces sim/waves.vcd)
//   make wave              (compila e executa, gera sim/waves.vcd)
//   gtkwave sim/waves.vcd  (opens the waveform viewer / abre o visualizador)
//
// Signals available in GTKWave / Sinais disponíveis no GTKWave:
//   riscv_top.clk, rst_n, dbg_pc, dbg_instr, dbg_alu_result, dbg_reg_wd
//   riscv_top.branch, riscv_top.jump, riscv_top.reg_write, ...
//   riscv_top.u_alu.a, riscv_top.u_alu.b, riscv_top.u_alu.result
//   (any internal module signal, without needing to expose it as a port)
//   (qualquer sinal interno do módulo, sem precisar expor como porta)
// =============================================================================

#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstdint>
#include <cstring>

// Number of cycles to simulate (increase to observe more of the program)
// Número de ciclos a simular (aumente para ver mais do programa)
static const int NUM_CYCLES = 30;

static VerilatedVcdC* vcd = nullptr;

// Executes one clock cycle and records it in the VCD file
// Executa um ciclo de clock e registra no VCD
static void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    // Falling edge / Borda de descida
    dut->clk = 0;
    dut->eval();
    ctx->timeInc(1);
    if (vcd) vcd->dump(ctx->time());

    // Rising edge / Borda de subida
    dut->clk = 1;
    dut->eval();
    ctx->timeInc(1);
    if (vcd) vcd->dump(ctx->time());
}

static void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx);
    tick(dut, ctx);
    dut->rst_n = 1;
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    ctx->traceEverOn(true);   // enable capture of internal signals / habilita captura de sinais internos

    Vriscv_top* dut = new Vriscv_top{ctx};

    // Initialize VCD / Inicializa VCD
    vcd = new VerilatedVcdC;
    dut->trace(vcd, 99);      // 99 = hierarchy depth (capture all) / profundidade de hierarquia (capture all)
    vcd->open("waves.vcd");   // created in the directory where the binary runs / será criado no diretório onde o binário é executado

    // Initial state / Estado inicial
    dut->clk         = 0;
    dut->rst_n       = 1;
    dut->dbg_reg_sel = 0;
    dut->eval();

    printf("=== Gerador de Waveform RISC-V ===\n");
    printf("    Programa: sim/program.hex (test_arith)\n");
    printf("    Ciclos  : %d\n\n", NUM_CYCLES);
    printf("%-6s  %-10s  %-10s  %-10s  %-10s\n",
           "Ciclo", "PC", "INSTR", "ALU", "WB");
    printf("------  ----------  ----------  ----------  ----------\n");

    reset(dut, ctx);

    for (int i = 0; i < NUM_CYCLES; i++) {
        printf("  %3d   0x%08X  0x%08X  0x%08X  0x%08X\n",
               i,
               (unsigned)dut->dbg_pc,
               (unsigned)dut->dbg_instr,
               (unsigned)dut->dbg_alu_result,
               (unsigned)dut->dbg_reg_wd);
        tick(dut, ctx);
    }

    vcd->close();

    printf("\n[OK] Waveform salvo em: sim/waves.vcd\n");
    printf("\nPara visualizar:\n");
    printf("  gtkwave sim/waves.vcd\n\n");
    printf("Sinais recomendados para adicionar no GTKWave:\n");
    printf("  TOP.riscv_top → clk, rst_n\n");
    printf("  TOP.riscv_top → dbg_pc, dbg_instr, dbg_alu_result, dbg_reg_wd, dbg_reg_we\n");
    printf("  TOP.riscv_top → branch, take_branch, jump, jump_r\n");
    printf("  TOP.riscv_top.u_alu → a, b, op, result, zero\n");

    dut->final();
    delete vcd;
    delete dut;
    delete ctx;
    return 0;
}
