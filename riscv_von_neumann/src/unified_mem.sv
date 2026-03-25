// =============================================================================
// Unified Memory — Von Neumann Architecture
// Memória Unificada — Arquitetura Von Neumann
// 4096 words of 32 bits (16 KB)
// 4096 palavras de 32 bits (16 KB)
//
// Fundamental difference from Harvard Architecture:
// Diferença fundamental da Arquitetura Harvard:
//   • Harvard: physically SEPARATE instruction and data memories
//   • Harvard: memórias de instrução e dados SEPARADAS fisicamente
//   • Von Neumann: ONE shared memory for instructions and data
//   • Von Neumann: UMA memória compartilhada para instruções e dados
//
// Implementation for single-cycle processor:
// Implementação para processador single-cycle:
//   - Instruction port: combinational read (simulates instruction fetch)
//   - Porta de instrução: leitura combinacional (simula busca de instrução)
//   - Data port:         combinational read + synchronous write
//   - Porta de dados:    leitura combinacional + escrita síncrona
//
// This implementation uses two simultaneous read ports (port A for
// Esta implementação usa duas portas de leitura simultâneas (porta A para
// instructions, port B for data) and one write port. In real hardware,
// instruções, porta B para dados) e uma porta de escrita. Em hardware real,
// Von Neumann requires bus arbitration; here we simplify for educational
// Von Neumann requer arbitragem de barramento; aqui, simplificamos para fins
// purposes while maintaining Von Neumann semantics (code and data in the same space).
// educacionais mantendo a semântica Von Neumann (código e dados no mesmo espaço).
//
// Memory map / Mapa de memória:
//   0x0000 – 0x2FFF  →  Code area (instructions) / Área de código (instruções)
//   0x3000 – 0x3FFF  →  Data area / Área de dados
//   (separation by convention only — physically the same memory)
//   (separação apenas por convenção — fisicamente são a mesma memória)
// =============================================================================
module unified_mem #(
    parameter DEPTH = 4096,   // 32-bit words / Palavras de 32 bits
    parameter AW    = 12      // log2(DEPTH)
) (
    input  logic        clk,

    // -----------------------------------------------------------------------
    // Port A: Instruction Fetch (combinational read)
    // Porta A: Busca de Instrução (leitura combinacional)
    // -----------------------------------------------------------------------
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,

    // -----------------------------------------------------------------------
    // Port B: Data Access (combinational read + synchronous write)
    // Porta B: Acesso a Dados (leitura combinacional + escrita síncrona)
    // -----------------------------------------------------------------------
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [2:0]  funct3,
    input  logic [31:0] data_addr,
    input  logic [31:0] data_wd,    // Data to write / Dado a escrever
    output logic [31:0] data_rd     // Data read / Dado lido
);

    logic [31:0] mem [0:DEPTH-1];

    // Word indices (12 bits for DEPTH=4096) / Índices de palavra (12 bits para DEPTH=4096)
    wire [AW-1:0] iidx = instr_addr[AW+1:2];  // Instruction / Instrução
    wire [AW-1:0] didx = data_addr[AW+1:2];    // Data / Dado
    wire [1:0]    boff = data_addr[1:0];        // Data byte offset / Byte offset do dado

    // -----------------------------------------------------------------------
    // Initialization / Inicialização
    // -----------------------------------------------------------------------
    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013; // NOP

        $display("[MEM] Loading program.hex (Von Neumann) ... / Carregando program.hex (Von Neumann) ...");
        $readmemh("program.hex", mem);
        $display("[MEM] Loaded. mem[0]=0x%08X / Carregado. mem[0]=0x%08X", mem[0]);
    end

    // -----------------------------------------------------------------------
    // Port A: Combinational instruction read
    // Porta A: Leitura combinacional de instrução
    // -----------------------------------------------------------------------
    assign instr_data = mem[iidx];

    // -----------------------------------------------------------------------
    // Port B: Synchronous data write
    // Porta B: Escrita síncrona de dados
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: begin // SB
                    case (boff)
                        2'b00: mem[didx][7:0]   <= data_wd[7:0];
                        2'b01: mem[didx][15:8]  <= data_wd[7:0];
                        2'b10: mem[didx][23:16] <= data_wd[7:0];
                        2'b11: mem[didx][31:24] <= data_wd[7:0];
                    endcase
                end
                2'b01: begin // SH
                    if (!boff[1])
                        mem[didx][15:0]  <= data_wd[15:0];
                    else
                        mem[didx][31:16] <= data_wd[15:0];
                end
                2'b10: mem[didx] <= data_wd; // SW
                default: ;
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Port B: Combinational data read
    // Porta B: Leitura combinacional de dados
    // -----------------------------------------------------------------------
    always_comb begin
        data_rd = 32'h0;
        if (mem_read) begin
            case (funct3)
                3'b000: begin // LB
                    case (boff)
                        2'b00: data_rd = {{24{mem[didx][7]}},  mem[didx][7:0]};
                        2'b01: data_rd = {{24{mem[didx][15]}}, mem[didx][15:8]};
                        2'b10: data_rd = {{24{mem[didx][23]}}, mem[didx][23:16]};
                        2'b11: data_rd = {{24{mem[didx][31]}}, mem[didx][31:24]};
                    endcase
                end
                3'b001: begin // LH
                    if (!boff[1])
                        data_rd = {{16{mem[didx][15]}}, mem[didx][15:0]};
                    else
                        data_rd = {{16{mem[didx][31]}}, mem[didx][31:16]};
                end
                3'b010: data_rd = mem[didx]; // LW
                3'b100: begin // LBU
                    case (boff)
                        2'b00: data_rd = {24'b0, mem[didx][7:0]};
                        2'b01: data_rd = {24'b0, mem[didx][15:8]};
                        2'b10: data_rd = {24'b0, mem[didx][23:16]};
                        2'b11: data_rd = {24'b0, mem[didx][31:24]};
                    endcase
                end
                3'b101: begin // LHU
                    if (!boff[1])
                        data_rd = {16'b0, mem[didx][15:0]};
                    else
                        data_rd = {16'b0, mem[didx][31:16]};
                end
                default: data_rd = 32'h0;
            endcase
        end
    end

endmodule
