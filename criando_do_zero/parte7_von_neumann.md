# Parte 7 — Adaptando para Von Neumann (Memória Unificada)

> **Pré-requisito:** você completou a Parte 6 e tem o processador Harvard funcionando com todos os quatro testes de integração passando.

Esta parte mostra como transformar a arquitetura Harvard (duas memórias físicas separadas) em Von Neumann (uma única memória compartilhada) com o mínimo de alterações possível. O exercício revela que a distinção Harvard/Von Neumann existe apenas na organização da memória — o datapath, a unidade de controle e a ISA são idênticos.

---

## 7.1 A Diferença Fundamental

### Arquitetura Harvard

```
        ┌─────────────────────────────────────┐
        │  CPU Harvard                        │
        │                                     │
        │  ┌───┐  pc   ┌─────────────────┐   │
        │  │ PC│──────►│ instr_mem (ROM)  │   │
        │  └───┘        │ 4 KB, somente   │   │
        │               │ leitura         │   │
        │               └─────────────────┘   │
        │                                     │
        │  ┌──────┐ addr ┌─────────────────┐  │
        │  │ ALU  │─────►│ data_mem  (RAM)  │  │
        │  └──────┘       │ 4 KB, leitura/  │  │
        │                 │ escrita         │  │
        │                 └─────────────────┘  │
        └─────────────────────────────────────┘

Fetch de instrução e acesso a dado: SIMULTÂNEOS (barramentos independentes)
```

### Arquitetura Von Neumann

```
        ┌─────────────────────────────────────┐
        │  CPU Von Neumann                    │
        │                                     │
        │  ┌───┐  pc  ──────────────────┐    │
        │  │ PC│                        │    │
        │  └───┘                        ▼    │
        │                     ┌──────────────┐│
        │  ┌──────┐ addr ────►│ unified_mem  ││
        │  │ ALU  │            │  (uma única  ││
        │  └──────┘            │   memória)   ││
        │                      └──────────────┘│
        └─────────────────────────────────────┘

Fetch de instrução e acesso a dado: mesma memória física,
portas de leitura separadas (dual-port) nesta implementação educacional
```

### Por que Von Neumann é mais comum em processadores reais

Em microcontroladores simples (PIC, AVR), Harvard puro faz sentido: o programa fica em Flash separada dos dados em SRAM. Mas em processadores de propósito geral (x86, ARM, RISC-V Linux), o programa e os dados vivem no mesmo espaço de endereçamento virtual. Isso permite que o código de um processo carregue dados de outro, que o sistema operacional mapeie bibliotecas compartilhadas e que um debugger modifique instruções em tempo de execução (breakpoints de software).

O custo, em hardware real, é a necessidade de arbitragem de barramento. A solução adotada pela indústria é a hierarquia de cache: L1 separado (I-cache e D-cache, comportamento Harvard) sobre memória DRAM unificada (comportamento Von Neumann). Nossa implementação educational usa uma abordagem mais simples: uma única memória com duas portas de leitura independentes, o que elimina o conflito de acesso simultâneo sem precisar de cache ou arbitragem.

### Mapa de memória Von Neumann

Com uma única memória de 4096 words (16 KB), a convenção de divisão do espaço é:

```
Endereço (bytes)  | Endereço (words) | Conteúdo
------------------+------------------+--------------------------
0x00000000        | 0x000            | Início do programa
0x00002FFF        | 0xBFF            | Fim da área de código (~12 KB)
0x00003000        | 0xC00            | Início da área de dados (~4 KB)
0x00003FFF        | 0xFFF            | Fim do espaço endereçável
```

Esta separação é apenas **por convenção** — não há hardware que impeça código de acessar endereços de dados ou vice-versa. O processador trata todos os endereços da mesma forma: como índices na mesma memória física.

---

## 7.2 A Memória Unificada: `src/unified_mem.sv`

Esta é a única diferença real em relação à versão Harvard. O módulo `unified_mem` substitui a par `instr_mem + data_mem` por uma única memória com duas portas de leitura independentes.

```systemverilog
// =============================================================================
// Memória Unificada — Arquitetura Von Neumann
// 4096 palavras de 32 bits (16 KB)
//
// Diferença fundamental da Arquitetura Harvard:
//   - Harvard: memórias de instrução e dados SEPARADAS fisicamente
//   - Von Neumann: UMA memória compartilhada para instruções e dados
//
// Implementação para processador single-cycle educacional:
//   - Porta de instrução: leitura combinacional (simula busca de instrução)
//   - Porta de dados:     leitura combinacional + escrita síncrona
//
// Por que isso funciona sem conflito no single-cycle:
//   A busca de instrução (porta A) olha para o PC, que sempre aponta
//   para a área de código (baixo). O acesso a dados (porta B) olha para
//   alu_result, que aponta para a área de dados (alto). Em software, o
//   programador garante que código e dados não se sobreponham.
//   Em hardware, as duas portas de leitura são simplesmente dois fios
//   diferentes saindo do mesmo array de bits — sem conflito físico.
//
// Mapa de memória (convenção):
//   0x0000 – 0x2FFF  →  Área de código (instruções)
//   0x3000 – 0x3FFF  →  Área de dados
// =============================================================================
module unified_mem #(
    parameter DEPTH = 4096,   // Profundidade em palavras de 32 bits (= 16 KB)
    parameter AW    = 12      // log2(DEPTH): bits necessários para indexar
) (
    input  logic        clk,

    // -----------------------------------------------------------------------
    // Porta A: Busca de Instrução (leitura combinacional, sem clock)
    // O PC é apresentado e a instrução está disponível no mesmo ciclo.
    // -----------------------------------------------------------------------
    input  logic [31:0] instr_addr,   // Endereço de byte do PC
    output logic [31:0] instr_data,   // Instrução de 32 bits lida

    // -----------------------------------------------------------------------
    // Porta B: Acesso a Dados (leitura combinacional + escrita síncrona)
    // Leitura: disponível combinacionalmente (mesmo ciclo que o endereço)
    // Escrita: registrada na borda de subida do clock
    // -----------------------------------------------------------------------
    input  logic        mem_read,     // Habilita leitura de dados
    input  logic        mem_write,    // Habilita escrita de dados
    input  logic [2:0]  funct3,       // Controla largura e extensão de sinal
    input  logic [31:0] data_addr,    // Endereço de byte para acesso a dados
    input  logic [31:0] data_wd,      // Dado a escrever
    output logic [31:0] data_rd       // Dado lido
);

    // Array de palavras de 32 bits
    // Em simulação, ocupa 4096 × 4 bytes = 16 KB na memória do simulador.
    logic [31:0] mem [0:DEPTH-1];

    // Índice de palavra para cada porta
    // Dividimos o endereço de byte por 4 (shift right 2) para obter
    // o índice no array de words.
    // AW+1:2 extrai os bits [13:2] para DEPTH=4096 (endereços de 0 a 4095).
    wire [AW-1:0] iidx = instr_addr[AW+1:2];   // Porta A: instrução
    wire [AW-1:0] didx = data_addr[AW+1:2];     // Porta B: dado
    wire [1:0]    boff = data_addr[1:0];         // Byte offset para a porta B

    // -----------------------------------------------------------------------
    // Inicialização
    // Preenche com NOP (addi x0, x0, 0 = 0x00000013) antes de carregar
    // o programa. Assim, endereços não inicializados executam NOPs inofensivos
    // em vez de instrução undefined.
    // -----------------------------------------------------------------------
    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013; // NOP

        $display("[MEM] Carregando program.hex (Von Neumann) ...");
        $readmemh("program.hex", mem);
        $display("[MEM] Carregado. mem[0]=0x%08X", mem[0]);
    end

    // -----------------------------------------------------------------------
    // Porta A: Leitura combinacional de instrução
    // Simples atribuição de fio — sem clock, sem latência.
    // -----------------------------------------------------------------------
    assign instr_data = mem[iidx];

    // -----------------------------------------------------------------------
    // Porta B: Escrita síncrona de dados (posedge clk)
    // A granularidade (byte, half-word, word) é controlada por funct3[1:0].
    // -----------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3[1:0])
                2'b00: begin  // SB — escreve apenas 1 byte
                    case (boff)
                        2'b00: mem[didx][7:0]   <= data_wd[7:0];
                        2'b01: mem[didx][15:8]  <= data_wd[7:0];
                        2'b10: mem[didx][23:16] <= data_wd[7:0];
                        2'b11: mem[didx][31:24] <= data_wd[7:0];
                    endcase
                end
                2'b01: begin  // SH — escreve 2 bytes (half-word)
                    if (!boff[1])
                        mem[didx][15:0]  <= data_wd[15:0];
                    else
                        mem[didx][31:16] <= data_wd[15:0];
                end
                2'b10: mem[didx] <= data_wd;  // SW — escreve 4 bytes (word)
                default: ;  // Opcode inválido: não escreve nada
            endcase
        end
    end

    // -----------------------------------------------------------------------
    // Porta B: Leitura combinacional de dados
    // Suporta LB (extensão de sinal), LH (extensão de sinal),
    // LW (word completa), LBU (zero-extend), LHU (zero-extend).
    // -----------------------------------------------------------------------
    always_comb begin
        data_rd = 32'h0;
        if (mem_read) begin
            case (funct3)
                3'b000: begin  // LB — byte com extensão de sinal
                    case (boff)
                        2'b00: data_rd = {{24{mem[didx][7]}},  mem[didx][7:0]};
                        2'b01: data_rd = {{24{mem[didx][15]}}, mem[didx][15:8]};
                        2'b10: data_rd = {{24{mem[didx][23]}}, mem[didx][23:16]};
                        2'b11: data_rd = {{24{mem[didx][31]}}, mem[didx][31:24]};
                    endcase
                end
                3'b001: begin  // LH — half-word com extensão de sinal
                    if (!boff[1])
                        data_rd = {{16{mem[didx][15]}}, mem[didx][15:0]};
                    else
                        data_rd = {{16{mem[didx][31]}}, mem[didx][31:16]};
                end
                3'b010: data_rd = mem[didx];  // LW — word completa
                3'b100: begin  // LBU — byte sem extensão de sinal
                    case (boff)
                        2'b00: data_rd = {24'b0, mem[didx][7:0]};
                        2'b01: data_rd = {24'b0, mem[didx][15:8]};
                        2'b10: data_rd = {24'b0, mem[didx][23:16]};
                        2'b11: data_rd = {24'b0, mem[didx][31:24]};
                    endcase
                end
                3'b101: begin  // LHU — half-word sem extensão de sinal
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
```

### Por que isso funciona para single-cycle sem conflito

A pergunta natural é: "se instrução e dado estão na mesma memória, como o processador pode buscar uma instrução E acessar um dado no mesmo ciclo?"

A resposta está na implementação. O array `mem` é o mesmo para as duas portas, mas cada porta tem seu próprio fio de endereço e seu próprio fio de dados:

```
                    ┌──────────────────────────────┐
iidx ─────────────►│                              │─────► instr_data
                    │   mem[0:DEPTH-1]             │
didx ─────────────►│   (array de words)           │─────► data_rd (comb.)
                    │                              │
                    │        ▲ escrita             │
                    └────────┼─────────────────────┘
                             │ (posedge clk, via didx)
```

Em simulação (e em FPGA com BRAM dual-port), isso é exatamente uma memória com duas portas de leitura simultâneas e uma porta de escrita. Não há conflito físico porque os dois endereços (`iidx` e `didx`) podem ser lidos simultaneamente, da mesma forma que você pode ter dois `assign` lendo o mesmo array em SystemVerilog.

O conflito real em Von Neumann aparece quando instrução e dado estão **no mesmo ciclo**, no mesmo endereço, com um querendo escrever. Em nosso processador:
- O PC aponta para a área de código (endereços baixos)
- Stores apontam para a área de dados (endereços altos, por convenção de software)
- Logo, o conflito nunca ocorre na prática

Em hardware real com memória síncrona de uma porta, isso requereria dois ciclos ou cache. Nossa implementação educacional escolhe a clareza sobre o realismo.

---

## 7.3 O Core Von Neumann: `src/riscv_top_vn.sv`

Este módulo é quase idêntico ao `riscv_top.sv` da Parte 6. A diferença é exatamente uma: os dois `include` e as duas instâncias de memória são substituídas por um único `include` e uma única instância de `unified_mem`.

Para ficar absolutamente claro, veja o diff conceitual:

```diff
- `include "instr_mem.sv"
- `include "data_mem.sv"
+ `include "unified_mem.sv"

- // Memória de Instruções
- instr_mem #(.DEPTH(IMEM_DEPTH)) u_imem (
-     .addr  (pc),
-     .instr (instr)
- );
-
- // Memória de Dados
- data_mem #(.DEPTH(DMEM_DEPTH)) u_dmem (
-     .clk      (clk),
-     .mem_read (mem_read),
-     .mem_write(mem_write),
-     .funct3   (funct3),
-     .addr     (alu_result),
-     .wd       (rs2_data),
-     .rd       (mem_rd)
- );
+
+ // Memória Unificada (Von Neumann)
+ unified_mem #(.DEPTH(MEM_DEPTH), .AW(MEM_AW)) u_mem (
+     .clk       (clk),
+     .instr_addr(pc),
+     .instr_data(instr),
+     .mem_read  (mem_read),
+     .mem_write (mem_write),
+     .funct3    (funct3),
+     .data_addr (alu_result),
+     .data_wd   (rs2_data),
+     .data_rd   (mem_rd)
+ );
```

Todo o restante — PC, decodificação, controle, imm_gen, register_file, ALU, muxes, write-back, debug — permanece absolutamente igual.

Abaixo está o módulo completo. Compare com o `riscv_top.sv` da Parte 6 e identifique você mesmo o que mudou:

```systemverilog
// =============================================================================
// Processador RISC-V RV32I — Arquitetura Von Neumann (Single-Cycle)
// Módulo top-level: interliga todos os componentes
//
// Arquitetura Von Neumann:
//   - UMA memória unificada para instruções e dados
//   - Instruções e dados compartilham o mesmo espaço de endereçamento
//   - Em single-cycle, ambos são acessados no mesmo ciclo via portas
//     independentes da memória dual-port
//
// O que mudou em relação à versão Harvard (riscv_top.sv):
//   REMOVIDO: `include "instr_mem.sv"
//   REMOVIDO: `include "data_mem.sv"
//   REMOVIDO: instância u_imem (instr_mem)
//   REMOVIDO: instância u_dmem (data_mem)
//   ADICIONADO: `include "unified_mem.sv"
//   ADICIONADO: instância u_mem (unified_mem) com ambas as portas
//
// Todo o restante do datapath é IDÊNTICO à versão Harvard.
// =============================================================================
`include "alu.sv"
`include "alu_control.sv"
`include "register_file.sv"
`include "imm_gen.sv"
`include "control_unit.sv"
`include "unified_mem.sv"

module riscv_top #(
    parameter MEM_DEPTH = 4096,   // Profundidade da memória unificada (words)
    parameter MEM_AW    = 12      // log2(MEM_DEPTH)
) (
    input  logic        clk,
    input  logic        rst_n,    // Reset ativo baixo

    // ------------------------------------------------------------------
    // Portas de debug
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
    // Sinais internos — idênticos à versão Harvard
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

    logic [31:0] jalr_sum, jalr_target, branch_target;

    // =========================================================================
    // PC — idêntico à versão Harvard
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // =========================================================================
    // Lógica do próximo PC — idêntica à versão Harvard
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
    // Decodificação — idêntica à versão Harvard
    // =========================================================================
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rd_addr  = instr[11:7];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // =========================================================================
    // *** DIFERENÇA ÚNICA EM RELAÇÃO À VERSÃO HARVARD ***
    //
    // Harvard usava:
    //   instr_mem u_imem (pc → instr)
    //   data_mem  u_dmem (alu_result ↔ mem_rd, rs2_data → wd)
    //
    // Von Neumann usa:
    //   unified_mem u_mem (pc → instr E alu_result ↔ mem_rd, rs2_data → wd)
    //
    // Ambas as portas coexistem no mesmo módulo, mas são conectadas
    // exatamente da mesma forma que antes.
    // =========================================================================
    unified_mem #(
        .DEPTH(MEM_DEPTH),
        .AW   (MEM_AW)
    ) u_mem (
        .clk       (clk),
        .instr_addr(pc),           // Porta A: PC → instrução
        .instr_data(instr),
        .mem_read  (mem_read),     // Porta B: acesso a dados
        .mem_write (mem_write),
        .funct3    (funct3),
        .data_addr (alu_result),
        .data_wd   (rs2_data),
        .data_rd   (mem_rd)
    );

    // =========================================================================
    // Gerador de Imediatos — idêntico à versão Harvard
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
    // Unidade de Controle — idêntica à versão Harvard
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
    // Write-back — idêntico à versão Harvard
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
    // Banco de Registradores — idêntico à versão Harvard
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
    // Unidade de Controle da ALU — idêntica à versão Harvard
    // =========================================================================
    alu_control u_alu_ctrl (
        .alu_op    (alu_op),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_sel   (alu_sel),
        .branch_inv(branch_inv)
    );

    // =========================================================================
    // Seletor de imediato — idêntico à versão Harvard
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
    // Entradas da ALU — idênticas à versão Harvard
    // =========================================================================
    assign alu_a = alu_src_a ? pc      : rs1_data;
    assign alu_b = alu_src_b ? imm_sel : rs2_data;

    // =========================================================================
    // ALU — idêntica à versão Harvard
    // =========================================================================
    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_sel),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // =========================================================================
    // Debug — idêntico à versão Harvard
    // =========================================================================
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_reg_wd     = reg_wd;
    assign dbg_reg_we     = reg_write;

endmodule
```

---

## 7.4 Testbench Von Neumann: `tb/tb_vn_arith.cpp`

Os testbenches da versão Von Neumann são estruturalmente idênticos aos da versão Harvard. A única diferença visível é o nome do módulo instanciado pelo Verilator (`Vriscv_top` em ambas, pois o módulo se chama `riscv_top` em ambas as versões — a diferença está em qual `riscv_top.sv` o Verilator compilou).

Isso ilustra a separação de preocupações: o testbench não sabe nem precisa saber se a memória é Harvard ou Von Neumann. Ele apenas estimula o clock, aplica reset e lê registradores via portas de debug.

```cpp
// =============================================================================
// Testbench — Teste Aritmético Von Neumann (test_arith.hex)
// Valida: ADDI, ADD, SUB, AND, OR, XOR, SLTI, SLLI, SRLI, SRAI, SLT, SLTU
//
// Idêntico ao tb_arith.cpp da versão Harvard em comportamento.
// A única diferença técnica: este testbench é compilado com riscv_top.sv
// da versão Von Neumann (que inclui unified_mem em vez de instr_mem+data_mem).
// =============================================================================
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstdint>

static int passed = 0;
static int failed = 0;

void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx); tick(dut, ctx);
    dut->rst_n = 1;
}

uint32_t read_reg(Vriscv_top* dut, int reg_num) {
    dut->dbg_reg_sel = reg_num;
    dut->eval();
    return (uint32_t)dut->dbg_reg_val;
}

void check(Vriscv_top* dut, int reg_num,
           uint32_t expected, const char* descricao) {
    uint32_t got = read_reg(dut, reg_num);
    if (got == expected) {
        printf("  [PASS] x%-2d  %-22s = 0x%08X  (%d)\n",
               reg_num, descricao, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d  %-22s : esperado=0x%08X (%d),"
               " obtido=0x%08X (%d)\n",
               reg_num, descricao,
               expected, (int32_t)expected,
               got, (int32_t)got);
        failed++;
    }
}

int main(int argc, char** argv) {
    VerilatedContext* ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    Vriscv_top* dut = new Vriscv_top{ctx};
    dut->clk         = 0;
    dut->rst_n       = 1;
    dut->dbg_reg_sel = 0;
    dut->eval();

    // A mensagem identifica a versão Von Neumann para distinção nos logs
    printf("=== Teste Aritmetico Von Neumann (test_arith.hex) ===\n\n");

    reset(dut, ctx);

    // Mesmo número de ciclos que a versão Harvard — o timing é idêntico
    for (int i = 0; i < 20; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores apos execucao ]\n");
    // Mesmos valores esperados que a versão Harvard
    check(dut,  1,  5,             "addi x0,5");
    check(dut,  2,  3,             "addi x0,3");
    check(dut,  3,  8,             "add x1,x2");
    check(dut,  4,  2,             "sub x1,x2");
    check(dut,  5,  1,             "and x1,x2  (0101&0011)");
    check(dut,  6,  7,             "or x1,x2   (0101|0011)");
    check(dut,  7,  6,             "xor x1,x2  (0101^0011)");
    check(dut,  8,  10,            "addi x1,5");
    check(dut,  9,  1,             "slti x2,5  (3<5=1)");
    check(dut, 10,  12,            "slli x2,2  (3<<2=12)");
    check(dut, 11,  6,             "srli x10,1 (12>>1=6)");
    check(dut, 12,  6,             "srai x10,1 (12>>1=6)");
    check(dut, 13,  (uint32_t)(-7),"addi x0,-7");
    check(dut, 14,  1,             "slt x13,x0 (-7<0=1)");
    check(dut, 15,  1,             "sltu x0,x1 (0<5=1)");

    printf("\n===================================\n");
    printf("Resultados: %d aprovados, %d reprovados\n", passed, failed);
    printf("===================================\n");

    dut->final();
    delete dut;
    delete ctx;
    return (failed == 0) ? 0 : 1;
}
```

---

## 7.5 O Makefile da Versão Von Neumann

O Makefile da versão Von Neumann é quase idêntico ao da versão Harvard. As diferenças são apenas nas mensagens informativas que identificam qual versão está sendo testada.

```makefile
# =============================================================================
# Makefile — Processador RISC-V Von Neumann (Verilator)
# =============================================================================

VERILATOR   := verilator
AS          := riscv64-unknown-elf-as
OBJCOPY     := riscv64-unknown-elf-objcopy
OBJDUMP     := riscv64-unknown-elf-objdump
PYTHON      := python3

SRC_DIR     := src
TB_DIR      := tb
PROG_DIR    := programs
SIM_DIR     := sim
OBJ_DIR     := obj_dir

VFLAGS_BASE := --cc --sv --exe --build \
               --Mdir $(OBJ_DIR)       \
               -I$(SRC_DIR)            \
               -Wall                   \
               -Wno-UNUSEDSIGNAL

AS_FLAGS    := -march=rv32i -mabi=ilp32

# =============================================================================
.PHONY: all programs alu regfile arith loadstore branch jump clean help

all: programs alu regfile arith loadstore branch jump
	@echo ""
	@echo "============================================"
	@echo "  Todos os testes (Von Neumann) concluidos!"
	@echo "============================================"

# =============================================================================
# Montagem dos programas — mesmos programas que a versão Harvard
# Os programas .s são idênticos: a ISA não muda.
# =============================================================================
programs: $(PROG_DIR)/test_arith.hex       \
          $(PROG_DIR)/test_load_store.hex  \
          $(PROG_DIR)/test_branch.hex      \
          $(PROG_DIR)/test_jump.hex
	@echo "[OK] Programas montados"

$(PROG_DIR)/test_arith.hex: $(PROG_DIR)/test_arith.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_arith.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_arith.o > $(PROG_DIR)/test_arith.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_arith.o $(PROG_DIR)/test_arith.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_arith.bin $@

$(PROG_DIR)/test_load_store.hex: $(PROG_DIR)/test_load_store.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_load_store.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_load_store.o > $(PROG_DIR)/test_load_store.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_load_store.o $(PROG_DIR)/test_load_store.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_load_store.bin $@

$(PROG_DIR)/test_branch.hex: $(PROG_DIR)/test_branch.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_branch.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_branch.o > $(PROG_DIR)/test_branch.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_branch.o $(PROG_DIR)/test_branch.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_branch.bin $@

$(PROG_DIR)/test_jump.hex: $(PROG_DIR)/test_jump.s
	$(AS) $(AS_FLAGS) -o $(PROG_DIR)/test_jump.o $<
	$(OBJDUMP) -d -M no-aliases $(PROG_DIR)/test_jump.o > $(PROG_DIR)/test_jump.dis
	$(OBJCOPY) -O binary $(PROG_DIR)/test_jump.o $(PROG_DIR)/test_jump.bin
	$(PYTHON) scripts/bin2hex.py $(PROG_DIR)/test_jump.bin $@

# =============================================================================
# Testes unitários (ALU e register_file não mudam entre as versões)
# =============================================================================
alu: $(OBJ_DIR)/Valu
	@echo ""
	@echo "=== Executando teste da ALU ==="
	$(OBJ_DIR)/Valu
	@echo ""

$(OBJ_DIR)/Valu: $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module alu \
	    $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp -o Valu

regfile: $(OBJ_DIR)/Vregfile
	@echo ""
	@echo "=== Executando teste do Banco de Registradores ==="
	$(OBJ_DIR)/Vregfile
	@echo ""

$(OBJ_DIR)/Vregfile: $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module register_file \
	    $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp -o Vregfile

# =============================================================================
# Compilação dos binários de simulação do processador Von Neumann
# Nota: o riscv_top.sv neste diretório inclui unified_mem.sv (não instr_mem+data_mem)
# =============================================================================
$(OBJ_DIR)/Varith: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp -o Varith

$(OBJ_DIR)/Vloadstore: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp -o Vloadstore

$(OBJ_DIR)/Vbranch: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp -o Vbranch

$(OBJ_DIR)/Vjump: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp -o Vjump

# =============================================================================
# Execução dos testes de integração Von Neumann
# =============================================================================
arith: $(OBJ_DIR)/Varith $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Aritmetico (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Varith
	@echo ""

loadstore: $(OBJ_DIR)/Vloadstore $(PROG_DIR)/test_load_store.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_load_store.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Load/Store (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vloadstore
	@echo ""

branch: $(OBJ_DIR)/Vbranch $(PROG_DIR)/test_branch.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_branch.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Branches (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vbranch
	@echo ""

jump: $(OBJ_DIR)/Vjump $(PROG_DIR)/test_jump.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_jump.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Jumps (Von Neumann) ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vjump
	@echo ""

# =============================================================================
clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)
	rm -f $(PROG_DIR)/*.o $(PROG_DIR)/*.bin $(PROG_DIR)/*.dis $(PROG_DIR)/*.hex

help:
	@echo "Alvos: all | programs | alu | regfile | arith | loadstore | branch | jump | clean"
```

---

## 7.6 Comparação Final: Harvard vs Von Neumann

### Tabela comparativa

| Aspecto | Harvard | Von Neumann |
|---|---|---|
| Numero de modulos de memoria | 2 (instr_mem + data_mem) | 1 (unified_mem) |
| Linhas de SystemVerilog (total) | ~30 a mais | ~30 a menos |
| Espaco de enderecos de instrucoes | Separado (0..IMEM_DEPTH-1) | Compartilhado (0..MEM_DEPTH-1) |
| Espaco de enderecos de dados | Separado (0..DMEM_DEPTH-1) | Compartilhado (0..MEM_DEPTH-1) |
| Conflito de acesso simultaneo | Impossivel (fisicamente separado) | Impossivel nesta impl. (dual-port combinacional) |
| Conflito em hardware real | N/A | Requer cache ou arbitragem |
| Performance no single-cycle | Igual (1 instrucao por ciclo) | Igual (1 instrucao por ciclo) |
| Flexibilidade de enderecamento | Codigo e dados nunca colidem | Codigo e dados podem colidir (por erro de software) |
| Proximos de qual hardware real | Microcontroladores (PIC, AVR, STM32) | Servidores, desktops, Linux/RISC-V |
| Modificar instrucoes em execucao | Impossivel (ROM separada) | Possivel (mesmo espaco de enderecos) |
| Depuracao por software (breakpoints) | Requer hardware dedicado | Possivel via SW (escrever instrucao trap) |
| Shared libraries e mapeamento de memoria | Nao aplicavel | Natural (unico espaco de enderecamento) |

### Diagrama de arquitetura lado a lado

```
     HARVARD                          VON NEUMANN
  ┌────────────────────┐           ┌────────────────────┐
  │ PC ──► instr_mem   │           │ PC ──►             │
  │ (ROM: somente leit.)│          │      ┌────────────┐│
  │                    │           │      │ unified_mem││
  │ ALU ─► data_mem    │           │ ALU ►│  (R+W)     ││
  │ (RAM: leit+escrita)│           │      └────────────┘│
  └────────────────────┘           └────────────────────┘

  2 instancias de memoria            1 instancia de memoria
  2 barramentos independentes        2 portas na mesma mem.
  Sem possibilidade de colisao       Colisao evitada por conv.
```

### O que realmente importa: a ISA é a mesma

A razão pela qual os mesmos programas funcionam nas duas arquiteturas é que a **Instruction Set Architecture (ISA)** do RISC-V RV32I não faz distinção entre Harvard e Von Neumann. A ISA define apenas:

- Quais instruções existem e como são codificadas
- O que cada instrução faz com os registradores e a memória
- Como o PC é atualizado

A ISA não diz nada sobre se a memória de instruções e a memória de dados são fisicamente o mesmo hardware. Essa é uma decisão de **microarquitetura**, invisível para o programador (em assembly ou em C).

---

## 7.7 Verificação Final: os mesmos testes passam nas duas versões

Execute o seguinte para confirmar que as implementações são funcionalmente equivalentes:

```bash
# Versão Harvard
cd /Users/joaocarlosbrittofilho/Documents/neander_riscV/riscv_harvard
make all

# Versão Von Neumann
cd /Users/joaocarlosbrittofilho/Documents/neander_riscV/riscv_von_neumann
make all
```

Você verá saídas idênticas:

```
# Harvard — saída de make arith:
=== Teste Aritmetico (test_arith.hex) ===
[IMEM] Carregando program.hex ...
[IMEM] Carregado. mem[0]=0x00500093
[ Verificando registradores apos execucao ]
  [PASS] x1   addi x0,5    = 0x00000005  (5)
  [PASS] x2   addi x0,3    = 0x00000003  (3)
  ... (todos PASS)
Resultados: 15 aprovados, 0 reprovados

# Von Neumann — saída de make arith:
=== Teste Aritmetico Von Neumann (test_arith.hex) ===
[MEM] Carregando program.hex (Von Neumann) ...
[MEM] Carregado. mem[0]=0x00500093
[ Verificando registradores apos execucao ]
  [PASS] x1   addi x0,5    = 0x00000005  (5)
  [PASS] x2   addi x0,3    = 0x00000003  (3)
  ... (todos PASS)
Resultados: 15 aprovados, 0 reprovados
```

Os resultados são idênticos porque:

1. **O programa é o mesmo**: `test_arith.hex` foi gerado pelo mesmo assembler com as mesmas flags. As instruções são bits, e bits não sabem nem se importam com o tipo de memória onde ficam armazenados.

2. **A execução é a mesma**: em ambas as arquiteturas, cada instrução leva exatamente 1 ciclo de clock. O datapath percorre os mesmos caminhos combinacionais, e os resultados da ALU e do banco de registradores são idênticos bit a bit.

3. **Os valores esperados são os mesmos**: o que `addi x1, x0, 5` faz em Harvard é exatamente o que faz em Von Neumann. A instrução define o comportamento; a memória é apenas o meio de armazenamento.

A única diferença observável em simulação é a mensagem de log do `$display` dentro de `instr_mem` / `unified_mem`, que identifica qual módulo foi carregado.

---

## 7.8 Quando Escolher Cada Arquitetura

### Use Harvard quando:

- O tamanho do programa e dos dados é fixo e conhecido em design time (microcontroladores embarcados)
- Segurança é crítica: código imutável em Flash protegida, dados em SRAM separada
- Você quer a simplicidade de não precisar gerenciar um mapa de endereços unificado
- O projeto é educacional e você quer que a separação instrução/dado seja visível no hardware

**Exemplos reais:** AVR (Arduino), PIC, STM32 Cortex-M com MPU configurada para código somente leitura.

### Use Von Neumann quando:

- Você precisa carregar programas dinamicamente (sistema operacional, runtime)
- O programa precisa modificar seu próprio código (JIT compilers, dynamic linking)
- Você quer um modelo de memória uniforme (mais fácil para linguagens de alto nível)
- Você está construindo um processador que vai rodar Linux ou outro sistema operacional rico

**Exemplos reais:** x86, ARM Cortex-A (processors com Linux), RISC-V com SBI e Linux.

### A resposta prática para RISC-V

O RISC-V privileged specification define um modelo Von Neumann para sistemas com MMU (RISC-V Linux). Os processadores RISC-V de alto desempenho usam caches L1 separadas (I-cache e D-cache, comportamento Harvard externamente) mas mapeadas sobre uma hierarquia de memória unificada (comportamento Von Neumann no nível do sistema). Você implementou os dois extremos; o meio-termo (cache) é o próximo passo natural.

---

## 7.9 Resumo das Alterações: Harvard → Von Neumann

Para transformar seu processador Harvard em Von Neumann, você precisa de exatamente:

**1 arquivo novo:** `src/unified_mem.sv`

**1 arquivo modificado:** `src/riscv_top.sv`
- Trocar 2 includes por 1 include
- Trocar 2 instâncias de módulo por 1 instância

**0 arquivos de testbench modificados:** os testbenches funcionam sem alteração, porque a interface externa do processador (portas `clk`, `rst_n`, debug) não muda.

**0 programas de teste modificados:** os arquivos `.s`, `.hex` e `.bin` são compartilhados entre as duas versões.

Esta é a medida de um bom design: mudanças na implementação interna não vazam para as interfaces externas. O princípio de encapsulamento que você aprendeu em software se aplica igualmente ao design de hardware.
