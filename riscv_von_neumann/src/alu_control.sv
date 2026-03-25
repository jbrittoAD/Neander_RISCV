// =============================================================================
// ALU Control Unit
// Unidade de Controle da ALU
// Decodes funct3/funct7 and ALUOp to generate the ALU opcode
// Decodifica funct3/funct7 e ALUOp para gerar o opcode da ALU
//
// ALUOp:
//   00 → ADD (load/store: address calculation / calcula endereço)
//   01 → Branch comparison (decodes funct3 / decodifica funct3)
//   10 → R-type (decodes funct3 + funct7 / decodifica funct3 + funct7)
//   11 → Arithmetic I-type (decodes funct3 / decodifica funct3)
// =============================================================================
module alu_control (
    input  logic [1:0] alu_op,     // Comes from the main control unit / Vem da unidade de controle principal
    input  logic [2:0] funct3,     // funct3 field of the instruction / Campo funct3 da instrução
    input  logic [6:0] funct7,     // funct7 field of the instruction / Campo funct7 da instrução

    output logic [3:0] alu_sel,    // Operation for the ALU / Operação para a ALU
    output logic       branch_inv  // 1 = invert branch comparison result / 1 = inverter resultado da comparação de branch
);

    // ALU encodings (must match alu.sv) / Codificações ALU (deve casar com alu.sv)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    always_comb begin
        branch_inv = 1'b0;
        case (alu_op)
            // Load / Store: always ADD to calculate address / sempre ADD para calcular endereço
            2'b00: alu_sel = ALU_ADD;

            // Branch: compare rs1 and rs2 according to funct3 / compara rs1 e rs2 de acordo com funct3
            2'b01: begin
                case (funct3)
                    3'b000: begin alu_sel = ALU_SUB;  branch_inv = 1'b0; end // BEQ
                    3'b001: begin alu_sel = ALU_SUB;  branch_inv = 1'b1; end // BNE
                    3'b100: begin alu_sel = ALU_SLT;  branch_inv = 1'b0; end // BLT
                    3'b101: begin alu_sel = ALU_SLT;  branch_inv = 1'b1; end // BGE
                    3'b110: begin alu_sel = ALU_SLTU; branch_inv = 1'b0; end // BLTU
                    3'b111: begin alu_sel = ALU_SLTU; branch_inv = 1'b1; end // BGEU
                    default: alu_sel = ALU_SUB;
                endcase
            end

            // R-type: decode funct3 and funct7 / decodifica funct3 e funct7
            2'b10: begin
                case (funct3)
                    3'b000: alu_sel = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_sel = ALU_SLL;
                    3'b010: alu_sel = ALU_SLT;
                    3'b011: alu_sel = ALU_SLTU;
                    3'b100: alu_sel = ALU_XOR;
                    3'b101: alu_sel = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_sel = ALU_OR;
                    3'b111: alu_sel = ALU_AND;
                    default: alu_sel = ALU_ADD;
                endcase
            end

            // Arithmetic I-type: decode funct3 (no funct7, except SRAI)
            // I-type aritmético: decodifica funct3 (sem funct7, exceto SRAI)
            2'b11: begin
                case (funct3)
                    3'b000: alu_sel = ALU_ADD;   // ADDI
                    3'b001: alu_sel = ALU_SLL;   // SLLI
                    3'b010: alu_sel = ALU_SLT;   // SLTI
                    3'b011: alu_sel = ALU_SLTU;  // SLTIU
                    3'b100: alu_sel = ALU_XOR;   // XORI
                    3'b101: alu_sel = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRLI/SRAI
                    3'b110: alu_sel = ALU_OR;    // ORI
                    3'b111: alu_sel = ALU_AND;   // ANDI
                    default: alu_sel = ALU_ADD;
                endcase
            end

            default: alu_sel = ALU_ADD;
        endcase
    end

endmodule
