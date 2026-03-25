// =============================================================================
// RISC-V RV32I Processor — Harvard Architecture (Single-Cycle)
// Processador RISC-V RV32I — Arquitetura Harvard (Single-Cycle)
// Top-level module: interconnects all components
// Módulo top-level: interliga todos os componentes
//
// Harvard Architecture:
// Arquitetura Harvard:
//   - Instruction memory is separate from data memory
//   - Memória de instruções separada da memória de dados
//   - Instruction fetch and data access occur in parallel in the same cycle
//   - Busca de instrução e acesso a dados ocorrem em paralelo no mesmo ciclo
// =============================================================================
`include "alu.sv"
`include "alu_control.sv"
`include "register_file.sv"
`include "imm_gen.sv"
`include "control_unit.sv"
`include "instr_mem.sv"
`include "data_mem.sv"

module riscv_top #(
    parameter IMEM_DEPTH = 1024,
    parameter DMEM_DEPTH = 1024
) (
    input  logic        clk,
    input  logic        rst_n,         // Active-low reset / Reset ativo baixo

    // ------------------------------------------------------------------
    // Debug ports (accessible from the testbench)
    // Portas de debug (acessíveis no testbench)
    // ------------------------------------------------------------------
    output logic [31:0] dbg_pc,        // Current PC value / Valor atual do PC
    output logic [31:0] dbg_instr,     // Instruction being executed / Instrução em execução
    output logic [31:0] dbg_alu_result,// ALU result / Resultado da ALU
    output logic [31:0] dbg_reg_wd,    // Data written to register / Dado escrito no registrador
    output logic        dbg_reg_we,    // Register file write-enable / Write-enable do banco

    input  logic [4:0]  dbg_reg_sel,   // Selects register to inspect / Seleciona registrador a inspecionar
    output logic [31:0] dbg_reg_val    // Value of the selected register / Valor do registrador selecionado
);

    // =========================================================================
    // Internal signals / Sinais internos
    // =========================================================================

    // PC
    logic [31:0] pc, pc_next, pc_plus4;

    // Decoded instruction / Instrução decodificada
    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    // Immediates / Imediatos
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // Register file / Banco de registradores
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] reg_wd;

    // ALU
    logic [31:0] alu_a, alu_b, imm_sel;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic [3:0]  alu_sel;

    // Data memory / Memória de dados
    logic [31:0] mem_rd;

    // Control signals / Sinais de controle
    logic        reg_write;
    logic        alu_src_a, alu_src_b;
    logic        mem_read, mem_write;
    logic        branch, jump, jump_r;
    logic [1:0]  mem_to_reg;
    logic [1:0]  alu_op;
    logic        branch_inv;

    // Branch logic / Lógica de branch
    logic        take_branch;
    logic [31:0] branch_target, jalr_target;

    // =========================================================================
    // PC — Program Counter Register / Registrador de Programa
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // =========================================================================
    // Next PC logic / Lógica de próximo PC
    // =========================================================================
    logic [31:0] jalr_sum;
    assign branch_target = pc + imm_b;
    // JALR: rs1 + imm_i, bit 0 forced to zero (RISC-V spec)
    // JALR: rs1 + imm_i, bit 0 forçado a zero (RISC-V spec)
    assign jalr_sum    = rs1_data + imm_i;
    assign jalr_target = {jalr_sum[31:1], 1'b0};

    // Decide whether the branch is taken based on the ALU operation and branch_inv
    // Decide se o branch é tomado com base na operação ALU e branch_inv
    always_comb begin
        if (branch) begin
            // alu_sel = SUB (0001): BEQ/BNE
            // alu_sel = SLT (1000) or SLTU (1001): BLT/BGE/BLTU/BGEU
            // alu_sel = SLT (1000) ou SLTU (1001): BLT/BGE/BLTU/BGEU
            if (alu_sel == 4'b0001) // SUB
                take_branch = branch_inv ? ~alu_zero : alu_zero;
            else                    // SLT / SLTU
                take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
        end else
            take_branch = 1'b0;
    end

    // Next PC selector / Seletor do próximo PC
    always_comb begin
        if (jump)
            pc_next = pc + imm_j;
        else if (jump_r)
            pc_next = jalr_target;
        else if (take_branch)
            pc_next = branch_target;
        else
            pc_next = pc_plus4;
    end

    // =========================================================================
    // Instruction decoding / Decodificação da instrução
    // =========================================================================
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rd_addr  = instr[11:7];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // =========================================================================
    // Instruction Memory (Harvard: separate ROM)
    // Memória de Instruções (Harvard: ROM separada)
    // =========================================================================
    instr_mem #(
        .DEPTH   (IMEM_DEPTH)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // =========================================================================
    // Immediate Generator / Gerador de Imediatos
    // =========================================================================
    imm_gen u_immgen (
        .instr (instr),
        .imm_i (imm_i),
        .imm_s (imm_s),
        .imm_b (imm_b),
        .imm_u (imm_u),
        .imm_j (imm_j)
    );

    // =========================================================================
    // Main Control Unit / Unidade de Controle Principal
    // =========================================================================
    control_unit u_ctrl (
        .opcode    (opcode),
        .reg_write (reg_write),
        .alu_src_a (alu_src_a),
        .alu_src_b (alu_src_b),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .branch    (branch),
        .jump      (jump),
        .jump_r    (jump_r),
        .mem_to_reg(mem_to_reg),
        .alu_op    (alu_op)
    );

    // =========================================================================
    // Selector for data to write to the register file
    // Seletor do dado a escrever no banco de registradores
    // =========================================================================
    always_comb begin
        case (mem_to_reg)
            2'b00: reg_wd = alu_result;  // ALU result (R, I, AUIPC) / Resultado da ALU (R, I, AUIPC)
            2'b01: reg_wd = mem_rd;       // Memory data (loads) / Dado da memória (loads)
            2'b10: reg_wd = pc_plus4;     // Return address (JAL, JALR) / Endereço de retorno (JAL, JALR)
            2'b11: reg_wd = imm_u;        // Upper immediate (LUI) / Imediato upper (LUI)
            default: reg_wd = alu_result;
        endcase
    end

    // =========================================================================
    // Register File / Banco de Registradores
    // =========================================================================
    register_file u_regfile (
        .clk        (clk),
        .we         (reg_write),
        .rs1        (rs1_addr),
        .rs2        (rs2_addr),
        .rd         (rd_addr),
        .wd         (reg_wd),
        .rd1        (rs1_data),
        .rd2        (rs2_data),
        .dbg_reg_sel(dbg_reg_sel),
        .dbg_reg_val(dbg_reg_val)
    );

    // =========================================================================
    // ALU Control Unit / Unidade de Controle da ALU
    // =========================================================================
    alu_control u_alu_ctrl (
        .alu_op    (alu_op),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_sel   (alu_sel),
        .branch_inv(branch_inv)
    );

    // =========================================================================
    // Immediate selector according to instruction type
    // Seletor do imediato conforme tipo da instrução
    // =========================================================================
    always_comb begin
        case (opcode)
            7'b0100011: imm_sel = imm_s;  // S-type: Store
            7'b1100011: imm_sel = imm_b;  // B-type: Branch
            7'b1101111: imm_sel = imm_j;  // J-type: JAL
            7'b0110111: imm_sel = imm_u;  // U-type: LUI
            7'b0010111: imm_sel = imm_u;  // U-type: AUIPC
            default:    imm_sel = imm_i;  // I-type (default)
        endcase
    end

    // =========================================================================
    // ALU input multiplexers / Multiplexadores de entrada da ALU
    // =========================================================================
    assign alu_a = alu_src_a ? pc       : rs1_data;  // A: rs1 or PC / A: rs1 ou PC
    assign alu_b = alu_src_b ? imm_sel  : rs2_data;  // B: rs2 or immediate / B: rs2 ou imediato

    // =========================================================================
    // ALU
    // =========================================================================
    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_sel),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // =========================================================================
    // Data Memory (Harvard: separate RAM)
    // Memória de Dados (Harvard: RAM separada)
    // =========================================================================
    data_mem #(
        .DEPTH(DMEM_DEPTH)
    ) u_dmem (
        .clk      (clk),
        .mem_read (mem_read),
        .mem_write(mem_write),
        .funct3   (funct3),
        .addr     (alu_result),
        .wd       (rs2_data),
        .rd       (mem_rd)
    );

    // =========================================================================
    // Debug ports / Portas de debug
    // =========================================================================
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_reg_wd     = reg_wd;
    assign dbg_reg_we     = reg_write;

endmodule
