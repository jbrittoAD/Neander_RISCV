// =============================================================================
// Processador RISC-V RV32I — Arquitetura Harvard (Single-Cycle)
// Módulo top-level: interliga todos os componentes
//
// Arquitetura Harvard:
//   - Memória de instruções separada da memória de dados
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
    input  logic        rst_n,         // Reset ativo baixo

    // ------------------------------------------------------------------
    // Portas de debug (acessíveis no testbench)
    // ------------------------------------------------------------------
    output logic [31:0] dbg_pc,        // Valor atual do PC
    output logic [31:0] dbg_instr,     // Instrução em execução
    output logic [31:0] dbg_alu_result,// Resultado da ALU
    output logic [31:0] dbg_reg_wd,    // Dado escrito no registrador
    output logic        dbg_reg_we,    // Write-enable do banco

    input  logic [4:0]  dbg_reg_sel,   // Seleciona registrador a inspecionar
    output logic [31:0] dbg_reg_val    // Valor do registrador selecionado
);

    // =========================================================================
    // Sinais internos
    // =========================================================================

    // PC
    logic [31:0] pc, pc_next, pc_plus4;

    // Instrução decodificada
    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    // Imediatos
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // Banco de registradores
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] reg_wd;

    // ALU
    logic [31:0] alu_a, alu_b, imm_sel;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic [3:0]  alu_sel;

    // Memória de dados
    logic [31:0] mem_rd;

    // Sinais de controle
    logic        reg_write;
    logic        alu_src_a, alu_src_b;
    logic        mem_read, mem_write;
    logic        branch, jump, jump_r;
    logic [1:0]  mem_to_reg;
    logic [1:0]  alu_op;
    logic        branch_inv;

    // Lógica de branch
    logic        take_branch;
    logic [31:0] branch_target, jalr_target;

    // =========================================================================
    // PC — Registrador de Programa
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // =========================================================================
    // Lógica de próximo PC
    // =========================================================================
    logic [31:0] jalr_sum;
    assign branch_target = pc + imm_b;
    // JALR: rs1 + imm_i, bit 0 forçado a zero (RISC-V spec)
    assign jalr_sum    = rs1_data + imm_i;
    assign jalr_target = {jalr_sum[31:1], 1'b0};

    // Decide se o branch é tomado com base na operação ALU e branch_inv
    always_comb begin
        if (branch) begin
            // alu_sel = SUB (0001): BEQ/BNE
            // alu_sel = SLT (1000) ou SLTU (1001): BLT/BGE/BLTU/BGEU
            if (alu_sel == 4'b0001) // SUB
                take_branch = branch_inv ? ~alu_zero : alu_zero;
            else                    // SLT / SLTU
                take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
        end else
            take_branch = 1'b0;
    end

    // Seletor do próximo PC
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
    // Decodificação da instrução
    // =========================================================================
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rd_addr  = instr[11:7];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // =========================================================================
    // Memória de Instruções (Harvard: ROM separada)
    // =========================================================================
    instr_mem #(
        .DEPTH   (IMEM_DEPTH)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // =========================================================================
    // Gerador de Imediatos
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
    // Unidade de Controle Principal
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
    // Seletor do dado a escrever no banco de registradores
    // =========================================================================
    always_comb begin
        case (mem_to_reg)
            2'b00: reg_wd = alu_result;  // Resultado da ALU (R, I, AUIPC)
            2'b01: reg_wd = mem_rd;       // Dado da memória (loads)
            2'b10: reg_wd = pc_plus4;     // Endereço de retorno (JAL, JALR)
            2'b11: reg_wd = imm_u;        // Imediato upper (LUI)
            default: reg_wd = alu_result;
        endcase
    end

    // =========================================================================
    // Banco de Registradores
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
    // Unidade de Controle da ALU
    // =========================================================================
    alu_control u_alu_ctrl (
        .alu_op    (alu_op),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_sel   (alu_sel),
        .branch_inv(branch_inv)
    );

    // =========================================================================
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
    // Multiplexadores de entrada da ALU
    // =========================================================================
    assign alu_a = alu_src_a ? pc       : rs1_data;  // A: rs1 ou PC
    assign alu_b = alu_src_b ? imm_sel  : rs2_data;  // B: rs2 ou imediato

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
    // Portas de debug
    // =========================================================================
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_reg_wd     = reg_wd;
    assign dbg_reg_we     = reg_write;

endmodule
