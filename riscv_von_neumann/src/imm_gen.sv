// =============================================================================
// Gerador de Imediatos — RISC-V RV32I
// Extrai e estende com sinal o imediato de acordo com o tipo de instrução
//
// Formatos suportados:
//   I-type: loads, operações aritméticas imediatas, JALR
//   S-type: stores
//   B-type: branches
//   U-type: LUI, AUIPC
//   J-type: JAL
// =============================================================================
module imm_gen (
    input  logic [31:0] instr,    // Instrução completa
    output logic [31:0] imm_i,    // Imediato I-type
    output logic [31:0] imm_s,    // Imediato S-type
    output logic [31:0] imm_b,    // Imediato B-type (offset de branch)
    output logic [31:0] imm_u,    // Imediato U-type
    output logic [31:0] imm_j     // Imediato J-type (offset de JAL)
);

    // I-type: sign_extend(inst[31:20])
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // S-type: sign_extend({inst[31:25], inst[11:7]})
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type: sign_extend({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    // U-type: {inst[31:12], 12'b0}
    assign imm_u = {instr[31:12], 12'b0};

    // J-type: sign_extend({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

endmodule
