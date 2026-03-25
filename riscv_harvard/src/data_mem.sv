// =============================================================================
// Data Memory — Harvard Architecture
// Memória de Dados — Arquitetura Harvard
// RAM of 1024 32-bit words (4 KB)
// RAM de 1024 palavras de 32 bits (4 KB)
// Synchronous write (posedge clk), combinational read
// Escrita síncrona (posedge clk), leitura combinacional
// Supports byte (LB/SB), half-word (LH/SH) and word (LW/SW) accesses
// Suporta acessos de byte (LB/SB), meia-palavra (LH/SH) e palavra (LW/SW)
//
// funct3:
//   000 = signed byte    (LB / SB)  / byte com sinal    (LB / SB)
//   001 = signed half    (LH / SH)  / half com sinal    (LH / SH)
//   010 = word           (LW / SW)  / palavra            (LW / SW)
//   100 = unsigned byte  (LBU)      / byte sem sinal     (LBU)
//   101 = unsigned half  (LHU)      / half sem sinal     (LHU)
// =============================================================================
module data_mem #(
    parameter DEPTH    = 1024,
    parameter AW       = 10    // log2(DEPTH)
) (
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [2:0]  funct3,
    input  logic [31:0] addr,
    input  logic [31:0] wd,      // Data to write / Dado a escrever

    output logic [31:0] rd       // Data read / Dado lido
);

    logic [31:0] mem [0:DEPTH-1];

    // Initialize with zeros / Inicializa com zeros
    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0;
    end

    // Word index (10 bits for 1024 entries) and byte offset
    // Índice de palavra (10 bits para 1024 entradas) e byte offset
    wire [AW-1:0] widx     = addr[AW+1:2];
    wire [1:0]    byte_off = addr[1:0];

    // -----------------------------------------------------------------------
    // Synchronous write / Escrita síncrona
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: begin // Byte
                    case (byte_off)
                        2'b00: mem[widx][7:0]   <= wd[7:0];
                        2'b01: mem[widx][15:8]  <= wd[7:0];
                        2'b10: mem[widx][23:16] <= wd[7:0];
                        2'b11: mem[widx][31:24] <= wd[7:0];
                    endcase
                end
                2'b01: begin // Half-word (2-byte aligned) / Half-word (alinhado em 2 bytes)
                    if (!byte_off[1])
                        mem[widx][15:0]  <= wd[15:0];
                    else
                        mem[widx][31:16] <= wd[15:0];
                end
                2'b10: mem[widx] <= wd; // Word / Palavra
                default: ; // ignored / ignorado
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Combinational read / Leitura combinacional
    // -----------------------------------------------------------------------
    always_comb begin
        rd = 32'h0;
        if (mem_read) begin
            case (funct3)
                3'b000: begin // LB — sign extension / extensão de sinal
                    case (byte_off)
                        2'b00: rd = {{24{mem[widx][7]}},  mem[widx][7:0]};
                        2'b01: rd = {{24{mem[widx][15]}}, mem[widx][15:8]};
                        2'b10: rd = {{24{mem[widx][23]}}, mem[widx][23:16]};
                        2'b11: rd = {{24{mem[widx][31]}}, mem[widx][31:24]};
                    endcase
                end
                3'b001: begin // LH — sign extension / extensão de sinal
                    if (!byte_off[1])
                        rd = {{16{mem[widx][15]}}, mem[widx][15:0]};
                    else
                        rd = {{16{mem[widx][31]}}, mem[widx][31:16]};
                end
                3'b010: rd = mem[widx]; // LW
                3'b100: begin // LBU — no sign extension / sem extensão de sinal
                    case (byte_off)
                        2'b00: rd = {24'b0, mem[widx][7:0]};
                        2'b01: rd = {24'b0, mem[widx][15:8]};
                        2'b10: rd = {24'b0, mem[widx][23:16]};
                        2'b11: rd = {24'b0, mem[widx][31:24]};
                    endcase
                end
                3'b101: begin // LHU — no sign extension / sem extensão de sinal
                    if (!byte_off[1])
                        rd = {16'b0, mem[widx][15:0]};
                    else
                        rd = {16'b0, mem[widx][31:16]};
                end
                default: rd = 32'h0;
            endcase
        end
    end

endmodule
