// =============================================================================
// Banco de Registradores — RISC-V RV32I
// 32 registradores de 32 bits
// x0 é hardwired para zero (qualquer escrita é descartada)
// Leitura combinacional, escrita síncrona na borda de subida do clock
// =============================================================================
module register_file (
    input  logic        clk,
    input  logic        we,            // Write Enable
    input  logic [4:0]  rs1,           // Endereço de leitura 1
    input  logic [4:0]  rs2,           // Endereço de leitura 2
    input  logic [4:0]  rd,            // Endereço de escrita
    input  logic [31:0] wd,            // Dado a escrever

    output logic [31:0] rd1,           // Dado lido da porta 1
    output logic [31:0] rd2,           // Dado lido da porta 2

    // Porto de debug: permite ler qualquer registrador sem interferir
    // na execução normal (usado apenas pelo testbench)
    input  logic [4:0]  dbg_reg_sel,
    output logic [31:0] dbg_reg_val
);

    logic [31:0] regs [31:0];

    // Inicializa todos os registradores com zero
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'h0;
    end

    // Escrita síncrona — x0 nunca é alterado
    always_ff @(posedge clk) begin
        if (we && (rd != 5'b0))
            regs[rd] <= wd;
    end

    // Leitura combinacional — x0 sempre retorna zero
    assign rd1 = (rs1 == 5'b0) ? 32'h0 : regs[rs1];
    assign rd2 = (rs2 == 5'b0) ? 32'h0 : regs[rs2];

    // Leitura de debug — x0 sempre retorna zero
    assign dbg_reg_val = (dbg_reg_sel == 5'b0) ? 32'h0 : regs[dbg_reg_sel];

endmodule
