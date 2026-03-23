// =============================================================================
// Memória de Instruções — Arquitetura Harvard
// ROM de 1024 palavras de 32 bits (4 KB)
// Leitura puramente combinacional (sem clock)
//
// O programa é carregado do arquivo "program.hex" localizado no
// diretório de onde o binário de simulação é executado.
// O Makefile copia o hex correto para sim/program.hex antes de cada teste.
// =============================================================================
module instr_mem #(
    parameter DEPTH = 1024
) (
    input  logic [31:0] addr,    // Endereço byte (alinhado em 4)
    output logic [31:0] instr    // Instrução lida
);

    logic [31:0] mem [0:DEPTH-1];

    // Índice de palavra: addr[11:2] para profundidade 1024
    // addr[1:0] são bits de byte-offset (sempre 00 para instruções alinhadas)
    wire [9:0] iidx = addr[11:2];

    initial begin
        integer i;
        // Preenche com NOP antes de carregar
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013; // addi x0, x0, 0

        $display("[IMEM] Carregando program.hex ...");
        $readmemh("program.hex", mem);
        $display("[IMEM] Carregado. mem[0]=0x%08X", mem[0]);
    end

    assign instr = mem[iidx];

endmodule
