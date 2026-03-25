// =============================================================================
// Testbench da ALU — Verilator C++
// Testa todas as 10 operações do RV32I: ADD, SUB, AND, OR, XOR,
// SLL, SRL, SRA, SLT, SLTU
// =============================================================================
#include <verilated.h>
#include "Valu.h"
#include <cstdio>
#include <cstdint>

// Operation encoding — must match alu.sv
// Codificação das operações — deve casar com alu.sv
enum AluOp {
    ALU_ADD  = 0,
    ALU_SUB  = 1,
    ALU_AND  = 2,
    ALU_OR   = 3,
    ALU_XOR  = 4,
    ALU_SLL  = 5,
    ALU_SRL  = 6,
    ALU_SRA  = 7,
    ALU_SLT  = 8,
    ALU_SLTU = 9,
};

static int passed = 0;
static int failed = 0;

// Evaluates one test case and reports the result
// Avalia um caso de teste e reporta o resultado
void check(Valu* dut, uint32_t a, uint32_t b, AluOp op,
           uint32_t expected_result, bool expected_zero,
           const char* test_name)
{
    dut->a  = a;
    dut->b  = b;
    dut->op = (uint8_t)op;
    dut->eval();

    bool ok = (dut->result == expected_result) &&
              ((bool)dut->zero == expected_zero);

    if (ok) {
        printf("  [PASS] %s\n", test_name);
        passed++;
    } else {
        printf("  [FAIL] %s\n", test_name);
        printf("         a=0x%08X b=0x%08X op=%d\n", a, b, op);
        printf("         esperado: result=0x%08X zero=%d\n",
               expected_result, expected_zero);
        printf("         obtido:   result=0x%08X zero=%d\n",
               dut->result, (int)dut->zero);
        failed++;
    }
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);
    Valu* dut = new Valu{ctx};

    printf("=== Teste da ALU RISC-V RV32I ===\n\n");

    // ------------------------------------------------------------------
    // ADD
    // ------------------------------------------------------------------
    printf("[ ADD ]\n");
    check(dut, 5,          3,          ALU_ADD, 8,           false, "5 + 3 = 8");
    check(dut, 0,          0,          ALU_ADD, 0,           true,  "0 + 0 = 0 (zero flag)");
    check(dut, 0xFFFFFFFF, 1,          ALU_ADD, 0,           true,  "overflow wrap-around");
    check(dut, 0x7FFFFFFF, 1,          ALU_ADD, 0x80000000,  false, "INT_MAX + 1");

    // ------------------------------------------------------------------
    // SUB
    // ------------------------------------------------------------------
    printf("[ SUB ]\n");
    check(dut, 10,         3,          ALU_SUB, 7,           false, "10 - 3 = 7");
    check(dut, 5,          5,          ALU_SUB, 0,           true,  "5 - 5 = 0 (zero flag)");
    check(dut, 0,          1,          ALU_SUB, 0xFFFFFFFF,  false, "0 - 1 = -1 (underflow)");

    // ------------------------------------------------------------------
    // AND
    // ------------------------------------------------------------------
    printf("[ AND ]\n");
    check(dut, 0xFF00FF00, 0x0F0F0F0F, ALU_AND, 0x0F000F00, false, "mascara AND");
    check(dut, 0xAAAAAAAA, 0x55555555, ALU_AND, 0,           true,  "complemento AND = 0");

    // ------------------------------------------------------------------
    // OR
    // ------------------------------------------------------------------
    printf("[ OR ]\n");
    check(dut, 0xF0F0F0F0, 0x0F0F0F0F, ALU_OR,  0xFFFFFFFF, false, "OR completo");
    check(dut, 0,          0,          ALU_OR,  0,           true,  "OR zeros = 0");

    // ------------------------------------------------------------------
    // XOR
    // ------------------------------------------------------------------
    printf("[ XOR ]\n");
    check(dut, 0xFFFFFFFF, 0xFFFFFFFF, ALU_XOR, 0,           true,  "XOR consigo = 0");
    check(dut, 0xA5A5A5A5, 0x5A5A5A5A, ALU_XOR, 0xFFFFFFFF,  false, "XOR padrao xadrez");

    // ------------------------------------------------------------------
    // SLL (shift left logical) / deslocamento lógico à esquerda
    // ------------------------------------------------------------------
    printf("[ SLL ]\n");
    check(dut, 1,          4,          ALU_SLL, 16,          false, "1 << 4 = 16");
    check(dut, 1,          31,         ALU_SLL, 0x80000000,  false, "1 << 31");
    // Only lower 5 bits of shamt are used: 32 & 31 = 0
    // Apenas os 5 bits inferiores do shamt são usados: 32 & 31 = 0
    check(dut, 1,          32,         ALU_SLL, 1,           false, "shamt 5 bits: 32 & 31 = 0");

    // ------------------------------------------------------------------
    // SRL (shift right logical) / deslocamento lógico à direita
    // ------------------------------------------------------------------
    printf("[ SRL ]\n");
    // SRL fills upper bits with 0 (no sign extension)
    // SRL preenche bits superiores com 0 (sem extensão de sinal)
    check(dut, 0x80000000, 1,          ALU_SRL, 0x40000000,  false, "SRL sem extensao de sinal");
    check(dut, 16,         4,          ALU_SRL, 1,           false, "16 >> 4 = 1");

    // ------------------------------------------------------------------
    // SRA (shift right arithmetic) / deslocamento aritmético à direita
    // ------------------------------------------------------------------
    printf("[ SRA ]\n");
    // SRA replicates the sign bit into upper positions
    // SRA replica o bit de sinal nas posições superiores
    check(dut, 0x80000000, 1,          ALU_SRA, 0xC0000000,  false, "SRA com extensao de sinal");
    check(dut, (uint32_t)(-8), 2,      ALU_SRA, (uint32_t)(-2), false, "-8 >> 2 = -2");

    // ------------------------------------------------------------------
    // SLT (set less than, signed) / menor que, com sinal
    // ------------------------------------------------------------------
    printf("[ SLT ]\n");
    check(dut, (uint32_t)(-1), 0,      ALU_SLT, 1,           false, "-1 < 0 (com sinal) = 1");
    check(dut, 0, (uint32_t)(-1),      ALU_SLT, 0,           true,  "0 < -1 (com sinal) = 0");
    check(dut, 5,          5,          ALU_SLT, 0,           true,  "5 < 5 = 0");

    // ------------------------------------------------------------------
    // SLTU (set less than unsigned) / menor que, sem sinal
    // ------------------------------------------------------------------
    printf("[ SLTU ]\n");
    check(dut, 0,          0xFFFFFFFF, ALU_SLTU, 1,          false, "0 < 0xFFFFFFFF (sem sinal) = 1");
    check(dut, 0xFFFFFFFF, 0,          ALU_SLTU, 0,          true,  "0xFFFFFFFF < 0 (sem sinal) = 0");
    check(dut, 3,          3,          ALU_SLTU, 0,          true,  "3 < 3 = 0");

    // ------------------------------------------------------------------
    // Final results / Resultado final
    // ------------------------------------------------------------------
    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;

    return (failed == 0) ? 0 : 1;
}
