// =============================================================================
// RISC-V RV32I Processor — Von Neumann Architecture (Single-Cycle)
// Processador RISC-V RV32I — Arquitetura Von Neumann (Single-Cycle)
// Top-level module: connects all components
// Módulo top-level: interliga todos os componentes
//
// Von Neumann Architecture:
// Arquitetura Von Neumann:
//   - ONE unified memory for instructions and data
//   - UMA memória unificada para instruções e dados
//   - Instructions and data share the same address space
//   - Instruções e dados compartilham o mesmo espaço de endereçamento
//   - In single-cycle, both are accessed in the same cycle via different memory ports
//   - Em single-cycle, ambos são acessados no mesmo ciclo via portas diferentes
//     (simplified implementation for educational purposes)
//     da memória (implementação simplificada para fins educacionais)
//
// Difference from the Harvard version:
// Diferença em relação à versão Harvard:
//   instr_mem.sv + data_mem.sv → unified_mem.sv
// The rest of the datapath is identical.
// O restante do datapath é idêntico.
// =============================================================================
`include "alu.sv"
`include "alu_control.sv"
`include "register_file.sv"
`include "imm_gen.sv"
`include "control_unit.sv"
`include "unified_mem.sv"

module riscv_top #(
    parameter MEM_DEPTH = 4096,
    parameter MEM_AW    = 12
) (
    input  logic        clk,
    input  logic        rst_n,

    // ------------------------------------------------------------------
    // Debug ports / Portas de debug
    // ------------------------------------------------------------------
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_instr,
    output logic [31:0] dbg_alu_result,
    output logic [31:0] dbg_reg_wd,
    output logic        dbg_reg_we,

    input  logic [4:0]  dbg_reg_sel,
    output logic [31:0] dbg_reg_val
);

    // =========================================================================
    // Internal signals / Sinais internos
    // =========================================================================
    logic [31:0] pc, pc_next, pc_plus4;

    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    logic [31:0] rs1_data, rs2_data;
    logic [31:0] reg_wd;

    logic [31:0] alu_a, alu_b, imm_sel;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic [3:0]  alu_sel;

    logic [31:0] mem_rd;

    logic        reg_write;
    logic        alu_src_a, alu_src_b;
    logic        mem_read, mem_write;
    logic        branch, jump, jump_r;
    logic [1:0]  mem_to_reg;
    logic [1:0]  alu_op;
    logic        branch_inv;
    logic        take_branch;

    logic [31:0] branch_target, jalr_sum, jalr_target;

    // =========================================================================
    // PC
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // =========================================================================
    // Next PC / Próximo PC
    // =========================================================================
    assign branch_target = pc + imm_b;
    assign jalr_sum      = rs1_data + imm_i;
    assign jalr_target   = {jalr_sum[31:1], 1'b0};

    always_comb begin
        if (branch) begin
            if (alu_sel == 4'b0001)
                take_branch = branch_inv ? ~alu_zero : alu_zero;
            else
                take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
        end else
            take_branch = 1'b0;
    end

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
    // Decode / Decodificação
    // =========================================================================
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rd_addr  = instr[11:7];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // =========================================================================
    // Unified Memory — Von Neumann / Memória Unificada — Von Neumann
    // =========================================================================
    unified_mem #(
        .DEPTH(MEM_DEPTH),
        .AW   (MEM_AW)
    ) u_mem (
        .clk       (clk),
        .instr_addr(pc),
        .instr_data(instr),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .funct3    (funct3),
        .data_addr (alu_result),
        .data_wd   (rs2_data),
        .data_rd   (mem_rd)
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
    // Control Unit / Unidade de Controle
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
    // Write-back
    // =========================================================================
    always_comb begin
        case (mem_to_reg)
            2'b00: reg_wd = alu_result;
            2'b01: reg_wd = mem_rd;
            2'b10: reg_wd = pc_plus4;
            2'b11: reg_wd = imm_u;
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
    // Immediate selector / Seletor de imediato
    // =========================================================================
    always_comb begin
        case (opcode)
            7'b0100011: imm_sel = imm_s;
            7'b1100011: imm_sel = imm_b;
            7'b1101111: imm_sel = imm_j;
            7'b0110111: imm_sel = imm_u;
            7'b0010111: imm_sel = imm_u;
            default:    imm_sel = imm_i;
        endcase
    end

    // =========================================================================
    // ALU inputs / Entradas da ALU
    // =========================================================================
    assign alu_a = alu_src_a ? pc      : rs1_data;
    assign alu_b = alu_src_b ? imm_sel : rs2_data;

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
    // Debug
    // =========================================================================
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_reg_wd     = reg_wd;
    assign dbg_reg_we     = reg_write;

endmodule
