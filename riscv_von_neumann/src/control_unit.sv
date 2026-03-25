// =============================================================================
// Main Control Unit — RISC-V RV32I (Single-Cycle)
// Unidade de Controle Principal — RISC-V RV32I (Single-Cycle)
// Decodes the opcode and generates all control signals
// Decodifica o opcode e gera todos os sinais de controle
//
// Control signals / Sinais de controle:
//   reg_write  : enables write to the register file / habilita escrita no banco de registradores
//   alu_src_a  : selects ALU operand A (0=rs1, 1=PC) / seleciona operando A da ALU (0=rs1, 1=PC)
//   alu_src_b  : selects ALU operand B (0=rs2, 1=immediate) / seleciona operando B da ALU (0=rs2, 1=imediato)
//   mem_read   : enables data memory read / habilita leitura da memória de dados
//   mem_write  : enables data memory write / habilita escrita na memória de dados
//   branch     : branch instruction / instrução de branch
//   jump       : JAL instruction / instrução JAL
//   jump_r     : JALR instruction / instrução JALR
//   mem_to_reg : selects data to write to register / seleciona dado a escrever no registrador
//                  00=ALU result, 01=memory data, 10=PC+4, 11=immediate (LUI)
//                  00=resultado ALU, 01=dado memória, 10=PC+4, 11=imediato (LUI)
//   alu_op     : code for the ALU control unit / código para a unidade de controle da ALU
//                  00=ADD, 01=branch, 10=R-type, 11=I-arith
// =============================================================================
module control_unit (
    input  logic [6:0] opcode,

    output logic       reg_write,
    output logic       alu_src_a,
    output logic       alu_src_b,
    output logic       mem_read,
    output logic       mem_write,
    output logic       branch,
    output logic       jump,
    output logic       jump_r,
    output logic [1:0] mem_to_reg,
    output logic [1:0] alu_op
);

    // RV32I opcodes / Opcodes RV32I
    localparam OP_R      = 7'b0110011; // R-type
    localparam OP_I_ARITH= 7'b0010011; // Arithmetic I-type / I-type aritmético
    localparam OP_LOAD   = 7'b0000011; // Load
    localparam OP_STORE  = 7'b0100011; // Store
    localparam OP_BRANCH = 7'b1100011; // Branch
    localparam OP_JAL    = 7'b1101111; // JAL
    localparam OP_JALR   = 7'b1100111; // JALR
    localparam OP_LUI    = 7'b0110111; // LUI
    localparam OP_AUIPC  = 7'b0010111; // AUIPC

    always_comb begin
        // Default values (safe: no action) / Valores padrão (seguro: nenhuma ação)
        reg_write  = 1'b0;
        alu_src_a  = 1'b0;
        alu_src_b  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jump_r     = 1'b0;
        mem_to_reg = 2'b00;
        alu_op     = 2'b00;

        case (opcode)
            OP_R: begin
                reg_write  = 1'b1;
                alu_op     = 2'b10;  // R-type
            end

            OP_I_ARITH: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;   // use immediate / usa imediato
                alu_op     = 2'b11;  // I-arith
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;   // address = rs1 + imm / endereço = rs1 + imm
                mem_read   = 1'b1;
                mem_to_reg = 2'b01;  // data from memory / dado da memória
                alu_op     = 2'b00;  // ADD
            end

            OP_STORE: begin
                alu_src_b  = 1'b1;   // address = rs1 + imm / endereço = rs1 + imm
                mem_write  = 1'b1;
                alu_op     = 2'b00;  // ADD
            end

            OP_BRANCH: begin
                branch     = 1'b1;
                alu_op     = 2'b01;  // branch comparison / comparação de branch
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                mem_to_reg = 2'b10;  // PC+4 → rd
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;   // rs1 + imm
                jump_r     = 1'b1;
                mem_to_reg = 2'b10;  // PC+4 → rd
                alu_op     = 2'b00;  // ADD
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                mem_to_reg = 2'b11;  // immediate directly → rd / imediato direto → rd
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                alu_src_a  = 1'b1;   // PC as operand A / PC como operando A
                alu_src_b  = 1'b1;   // U-immediate as operand B / imediato U como operando B
                alu_op     = 2'b00;  // ADD → PC + upper_imm
            end

            default: begin
                // NOP / unknown instruction / NOP / instrução desconhecida
            end
        endcase
    end

endmodule
