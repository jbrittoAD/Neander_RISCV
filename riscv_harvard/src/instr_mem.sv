// =============================================================================
// Instruction Memory — Harvard Architecture
// Memória de Instruções — Arquitetura Harvard
// ROM of 1024 32-bit words (4 KB)
// ROM de 1024 palavras de 32 bits (4 KB)
// Purely combinational read (no clock)
// Leitura puramente combinacional (sem clock)
//
// The program is loaded from the file "program.hex" located in the
// O programa é carregado do arquivo "program.hex" localizado no
// directory from which the simulation binary is executed.
// diretório de onde o binário de simulação é executado.
// The Makefile copies the correct hex to sim/program.hex before each test.
// O Makefile copia o hex correto para sim/program.hex antes de cada teste.
// =============================================================================
module instr_mem #(
    parameter DEPTH = 1024
) (
    input  logic [31:0] addr,    // Byte address (4-byte aligned) / Endereço byte (alinhado em 4)
    output logic [31:0] instr    // Fetched instruction / Instrução lida
);

    logic [31:0] mem [0:DEPTH-1];

    // Word index: addr[11:2] for depth 1024
    // Índice de palavra: addr[11:2] para profundidade 1024
    // addr[1:0] are byte-offset bits (always 00 for aligned instructions)
    // addr[1:0] são bits de byte-offset (sempre 00 para instruções alinhadas)
    wire [9:0] iidx = addr[11:2];

    initial begin
        integer i;
        // Fill with NOP before loading / Preenche com NOP antes de carregar
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013; // addi x0, x0, 0

        $display("[IMEM] Carregando program.hex ...");
        $readmemh("program.hex", mem);
        $display("[IMEM] Carregado. mem[0]=0x%08X", mem[0]);
    end

    assign instr = mem[iidx];

endmodule
