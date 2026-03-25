// =============================================================================
// Register File — RISC-V RV32I
// Banco de Registradores — RISC-V RV32I
// 32 registers of 32 bits
// 32 registradores de 32 bits
// x0 is hardwired to zero (any write is discarded)
// x0 é hardwired para zero (qualquer escrita é descartada)
// Combinational read, synchronous write on the rising clock edge
// Leitura combinacional, escrita síncrona na borda de subida do clock
// =============================================================================
module register_file (
    input  logic        clk,
    input  logic        we,            // Write Enable / Habilitação de escrita
    input  logic [4:0]  rs1,           // Read address 1 / Endereço de leitura 1
    input  logic [4:0]  rs2,           // Read address 2 / Endereço de leitura 2
    input  logic [4:0]  rd,            // Write address / Endereço de escrita
    input  logic [31:0] wd,            // Data to write / Dado a escrever

    output logic [31:0] rd1,           // Data read from port 1 / Dado lido da porta 1
    output logic [31:0] rd2,           // Data read from port 2 / Dado lido da porta 2

    // Debug port: allows reading any register without interfering
    // Porto de debug: permite ler qualquer registrador sem interferir
    // with normal execution (used only by the testbench)
    // na execução normal (usado apenas pelo testbench)
    input  logic [4:0]  dbg_reg_sel,
    output logic [31:0] dbg_reg_val
);

    logic [31:0] regs [31:0];

    // Initialize all registers to zero / Inicializa todos os registradores com zero
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'h0;
    end

    // Synchronous write — x0 is never modified / Escrita síncrona — x0 nunca é alterado
    always_ff @(posedge clk) begin
        if (we && (rd != 5'b0))
            regs[rd] <= wd;
    end

    // Combinational read — x0 always returns zero / Leitura combinacional — x0 sempre retorna zero
    assign rd1 = (rs1 == 5'b0) ? 32'h0 : regs[rs1];
    assign rd2 = (rs2 == 5'b0) ? 32'h0 : regs[rs2];

    // Debug read — x0 always returns zero / Leitura de debug — x0 sempre retorna zero
    assign dbg_reg_val = (dbg_reg_sel == 5'b0) ? 32'h0 : regs[dbg_reg_sel];

endmodule
