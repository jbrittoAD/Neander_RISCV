# Parte 6 — Datapath Completo: Arquitetura Harvard

> **Pré-requisito:** você completou as Partes 1 a 5 — ALU, banco de registradores, memórias e unidade de controle funcionam corretamente e passam em todos os testes unitários.

Esta parte integra todos os blocos que construímos até agora em um processador funcional. Ao final, você terá um RISC-V RV32I single-cycle completo rodando programas reais em simulação.

---

## 6.1 O que é o Datapath?

Pense no processador como um organismo vivo. Se a unidade de controle é o **cérebro** — ela lê a instrução e decide o que fazer —, o **datapath** é a musculatura: os fios, multiplexadores, registradores e conexões que realmente movem os dados de um componente para outro.

Mais formalmente, o datapath é o conjunto de:

- **Elementos de estado**: registradores que guardam valores entre ciclos de clock (PC, banco de registradores, memórias síncronas).
- **Lógica combinacional**: circuitos que transformam valores instantaneamente sem clock (ALU, decodificadores, somadores de endereço).
- **Multiplexadores (muxes)**: chaves controladas por sinais da unidade de controle que selecionam de qual fonte um dado flui.

A unidade de controle **não toca nos dados**. Ela apenas lê o opcode da instrução e gera sinais de seleção (0 ou 1 por mux) que determinam o caminho que os dados percorrem no datapath. É essa separação entre fluxo de controle e fluxo de dados que torna o design modular e verificável.

### Anatomia de um ciclo single-cycle

Em cada ciclo de clock, o processador realiza exatamente estas etapas em paralelo (porque toda a lógica combinacional é simultânea):

```
1. Fetch       PC → instr_mem → instr[31:0]
2. Decode      instr → control_unit → sinais de controle
               instr → imm_gen → imediatos expandidos
               instr[19:15], [24:20] → register_file → rs1_data, rs2_data
3. Execute     alu_a (rs1 ou PC) + alu_b (rs2 ou imediato) → alu_result
4. Memory      alu_result → data_mem → mem_rd  (apenas loads/stores)
5. Write-back  mux(alu_result | mem_rd | PC+4 | imm_u) → register_file[rd]
6. PC update   mux(PC+4 | branch_target | jalr_target) → PC
```

Todas as etapas acontecem dentro do mesmo ciclo de clock. A borda de subida do clock é o momento em que o estado muda: os flip-flops do banco de registradores e da memória de dados capturam seus novos valores, e o PC avança para a próxima instrução.

---

## 6.2 O Registrador do Program Counter (PC)

### Por que o PC é especial

O PC é o registrador mais fundamental do processador. Diferente dos 32 registradores de propósito geral (x0–x31), o PC não tem "endereço" no banco de registradores e não precisa de um sinal write-enable explícito: **ele sempre atualiza a cada ciclo**. O que muda é apenas o valor para o qual ele atualiza.

Três propriedades distinguem o PC:

1. **Incremento automático**: na ausência de desvios, o PC avança 4 bytes a cada ciclo (instruções RV32I têm 4 bytes; a extensão C usa instruções de 2 bytes, mas não a implementamos aqui).

2. **Redirecionamento por branch**: instruções de branch computam um deslocamento relativo ao PC atual: `PC_próximo = PC + imm_b`. O imediato B-type já incorpora o bit 0 como zero (alinhamento mínimo de 2 bytes para extensão C; como não usamos C, na prática 4 bytes).

3. **Redirecionamento por jump**: JAL usa `PC_próximo = PC + imm_j` (relativo ao PC). JALR usa `PC_próximo = (rs1 + imm_i) & ~1` (absoluto via registrador, bit 0 forçado a zero pela spec).

### `src/pc_reg.sv`

O PC é simplesmente um flip-flop de 32 bits com reset síncrono:

```systemverilog
// pc_reg.sv
// Registrador do Program Counter (PC).
// Atualiza a cada borda de subida do clock.
// Em reset, volta ao endereço 0x00000000 (início da memória de instruções).

module pc_reg (
    input  logic        clk,
    input  logic        rst,      // reset ativo alto
    input  logic [31:0] pc_next,  // próximo valor do PC
    output logic [31:0] pc        // valor atual do PC
);
    always_ff @(posedge clk or posedge rst)
        if (rst) pc <= 32'b0;
        else     pc <= pc_next;
endmodule
```

Observação: no módulo `riscv_top.sv` do projeto real usamos reset ativo baixo (`rst_n`) para compatibilidade com convenções de FPGA. O módulo `pc_reg.sv` acima usa reset ativo alto para simplicidade didática; em `riscv_top.sv` a lógica de reset é incorporada diretamente no `always_ff`.

### Lógica de pc_next

O valor de `pc_next` é determinado por um multiplexador de quatro entradas controlado pelos sinais `jump`, `jump_r` e `take_branch`:

```systemverilog
// Lógica combinacional de seleção do próximo PC
always_comb begin
    if (jump)             // JAL: deslocamento relativo ao PC
        pc_next = pc + imm_j;
    else if (jump_r)      // JALR: endereço absoluto via registrador
        pc_next = jalr_target;          // jalr_target = (rs1 + imm_i) & ~1
    else if (take_branch) // Branch tomado: deslocamento relativo ao PC
        pc_next = pc + imm_b;
    else                  // Fluxo normal: próxima instrução
        pc_next = pc + 32'd4;
end
```

A prioridade importa: jumps têm precedência sobre branches (embora na prática uma instrução não pode ser JAL e branch ao mesmo tempo — os opcodes são distintos). A ordem garante comportamento determinístico mesmo em casos extremos.

### Cálculo do alvo JALR

A especificação RISC-V exige que o bit 0 do endereço alvo do JALR seja forçado a zero. Isso permite que futuras extensões usem endereços ímpares para indicar modos de instrução de 16 bits (extensão C). Na nossa implementação single-cycle:

```systemverilog
logic [31:0] jalr_sum;
assign jalr_sum    = rs1_data + imm_i;
assign jalr_target = {jalr_sum[31:1], 1'b0};  // força bit 0 = 0
```

### Lógica de branch tomado (`take_branch`)

Cada instrução de branch usa a ALU para comparar rs1 e rs2. O sinal `take_branch` combina o sinal `branch` da unidade de controle com o resultado da ALU:

```systemverilog
always_comb begin
    if (branch) begin
        // BEQ/BNE: ALU faz subtração; branch_inv=0 → BEQ (zero=1), branch_inv=1 → BNE
        if (alu_sel == 4'b0001)   // ALU_SUB
            take_branch = branch_inv ? ~alu_zero : alu_zero;
        else
            // BLT/BGE: ALU faz SLT; BLT: result[0]=1, BGE: result[0]=0
            // BLTU/BGEU: ALU faz SLTU; mesma lógica, sem sinal
            take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
    end else
        take_branch = 1'b0;
end
```

A tabela completa de como cada branch usa os sinais da ALU:

| Instrução | funct3 | Operação ALU | Sinal usado   | branch_inv | Condição de tomada          |
|-----------|--------|-------------|----------------|------------|-----------------------------|
| BEQ       | 000    | SUB         | `alu_zero`     | 0          | `alu_zero == 1` (rs1 == rs2) |
| BNE       | 001    | SUB         | `alu_zero`     | 1          | `alu_zero == 0` (rs1 != rs2) |
| BLT       | 100    | SLT         | `alu_result[0]`| 0          | `result[0] == 1` (rs1 < rs2 com sinal) |
| BGE       | 101    | SLT         | `alu_result[0]`| 1          | `result[0] == 0` (rs1 >= rs2 com sinal) |
| BLTU      | 110    | SLTU        | `alu_result[0]`| 0          | `result[0] == 1` (rs1 < rs2 sem sinal) |
| BGEU      | 111    | SLTU        | `alu_result[0]`| 1          | `result[0] == 0` (rs1 >= rs2 sem sinal) |

O sinal `branch_inv` vem do módulo `alu_control` e é gerado junto com `alu_sel`. A unidade de controle da ALU lê o `funct3` e produz o par `(alu_sel, branch_inv)` apropriado para cada instrução de branch.

---

## 6.3 Os Multiplexadores do Datapath

O datapath inteiro pode ser entendido como uma rede de blocos funcionais conectados por três grandes multiplexadores. Compreender esses três muxes é compreender como o datapath funciona.

### Mux 1 — Seleção da entrada A da ALU (`alu_src_a`)

```
0 → rs1_data   (operações R-type, I-type, branches, loads, stores)
1 → pc         (AUIPC: PC + upper_immediate)
```

Apenas AUIPC usa PC como operando A. Para todas as outras instruções, o operando A é o valor lido do registrador rs1.

### Mux 2 — Seleção da entrada B da ALU (`alu_src_b`)

```
0 → rs2_data   (operações R-type, branches)
1 → imm_sel    (I-type, S-type, U-type, J-type loads/stores/jumps)
```

O sinal `imm_sel` é ele próprio a saída de um multiplexador interno que escolhe qual imediato (imm_i, imm_s, imm_b, imm_u, imm_j) usar com base no opcode.

### Mux 3 — Seleção do dado de write-back (`mem_to_reg`)

Este mux decide o que é escrito no registrador de destino `rd`:

```
2'b00 → alu_result   (R-type, I-type, AUIPC: escreve resultado da ALU)
2'b01 → mem_rd       (loads: escreve dado lido da memória)
2'b10 → pc_plus4     (JAL, JALR: escreve endereço de retorno)
2'b11 → imm_u        (LUI: escreve o imediato upper diretamente)
```

Note que LUI não passa pela ALU. O imediato U-type já está na forma final desejada (20 bits nos bits altos, 12 zeros nos bits baixos) e é escrito diretamente em `rd`.

### Mux interno — Seleção do imediato (`imm_sel`)

Antes de chegar ao mux da entrada B da ALU, o imediato correto é selecionado baseado no opcode:

```systemverilog
always_comb begin
    case (opcode)
        7'b0100011: imm_sel = imm_s;   // S-type: Store
        7'b1100011: imm_sel = imm_b;   // B-type: Branch
        7'b1101111: imm_sel = imm_j;   // J-type: JAL
        7'b0110111: imm_sel = imm_u;   // U-type: LUI
        7'b0010111: imm_sel = imm_u;   // U-type: AUIPC
        default:    imm_sel = imm_i;   // I-type (default para loads, ADDI, JALR, etc.)
    endcase
end
```

---

## 6.4 O Módulo Top-Level: `src/riscv_top.sv`

Este é o arquivo central da Parte 6. Ele não contém nenhuma lógica nova — apenas conecta todos os módulos que construímos anteriormente usando os muxes e fios descritos acima. Cada seção está comentada explicando sua função.

```systemverilog
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
    parameter IMEM_DEPTH = 1024,   // Profundidade da ROM de instruções (words)
    parameter DMEM_DEPTH = 1024    // Profundidade da RAM de dados (words)
) (
    input  logic        clk,
    input  logic        rst_n,     // Reset ativo baixo

    // ------------------------------------------------------------------
    // Portas de debug (acessíveis no testbench sem interferir na execução)
    // ------------------------------------------------------------------
    output logic [31:0] dbg_pc,         // Valor atual do PC
    output logic [31:0] dbg_instr,      // Instrução em execução
    output logic [31:0] dbg_alu_result, // Resultado da ALU
    output logic [31:0] dbg_reg_wd,     // Dado escrito no registrador
    output logic        dbg_reg_we,     // Write-enable do banco

    input  logic [4:0]  dbg_reg_sel,    // Seleciona registrador a inspecionar
    output logic [31:0] dbg_reg_val     // Valor do registrador selecionado
);

    // =========================================================================
    // Declaração de todos os sinais internos
    // =========================================================================

    // PC e suas variações
    logic [31:0] pc, pc_next, pc_plus4;

    // Campos decodificados da instrução
    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;
    logic [2:0]  funct3;
    logic [6:0]  funct7;

    // Imediatos expandidos (um por formato de instrução)
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // Banco de registradores
    logic [31:0] rs1_data, rs2_data;
    logic [31:0] reg_wd;           // dado selecionado para write-back

    // ALU
    logic [31:0] alu_a, alu_b, imm_sel;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic [3:0]  alu_sel;

    // Memória de dados
    logic [31:0] mem_rd;

    // Sinais de controle vindos de control_unit
    logic        reg_write;
    logic        alu_src_a, alu_src_b;
    logic        mem_read, mem_write;
    logic        branch, jump, jump_r;
    logic [1:0]  mem_to_reg;
    logic [1:0]  alu_op;

    // Sinal de controle vindo de alu_control
    logic        branch_inv;

    // Lógica de branch e jump
    logic        take_branch;
    logic [31:0] jalr_sum, jalr_target, branch_target;

    // =========================================================================
    // PC — Registrador de Programa
    // Reset ativo baixo; avança no posedge clk
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    assign pc_plus4 = pc + 32'd4;

    // =========================================================================
    // Lógica do próximo PC
    // =========================================================================

    // Alvo de branch: PC-relativo usando imediato B-type
    assign branch_target = pc + imm_b;

    // Alvo de JALR: rs1 + imm_i, bit 0 forçado a 0 (RISC-V spec §2.5)
    assign jalr_sum    = rs1_data + imm_i;
    assign jalr_target = {jalr_sum[31:1], 1'b0};

    // Condição de tomada de branch
    always_comb begin
        if (branch) begin
            if (alu_sel == 4'b0001)   // SUB → BEQ / BNE
                take_branch = branch_inv ? ~alu_zero : alu_zero;
            else                      // SLT / SLTU → BLT, BGE, BLTU, BGEU
                take_branch = branch_inv ? ~alu_result[0] : alu_result[0];
        end else
            take_branch = 1'b0;
    end

    // Seletor do próximo PC (prioridade: jump > jump_r > branch > sequencial)
    always_comb begin
        if (jump)             // JAL
            pc_next = pc + imm_j;
        else if (jump_r)      // JALR
            pc_next = jalr_target;
        else if (take_branch) // Branch tomado
            pc_next = branch_target;
        else                  // Fluxo normal
            pc_next = pc_plus4;
    end

    // =========================================================================
    // Decodificação dos campos da instrução (apenas fios, zero custo em hardware)
    // =========================================================================
    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7   = instr[31:25];
    assign rd_addr  = instr[11:7];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];

    // =========================================================================
    // Memória de Instruções (Harvard: ROM separada, leitura combinacional)
    // =========================================================================
    instr_mem #(
        .DEPTH(IMEM_DEPTH)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // =========================================================================
    // Gerador de Imediatos
    // Produz todos os cinco formatos de imediato em paralelo
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
    // Lê apenas o opcode e gera todos os sinais de controle
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
    // Unidade de Controle da ALU
    // Lê alu_op + funct3 + funct7 e gera alu_sel e branch_inv
    // =========================================================================
    alu_control u_alu_ctrl (
        .alu_op    (alu_op),
        .funct3    (funct3),
        .funct7    (funct7),
        .alu_sel   (alu_sel),
        .branch_inv(branch_inv)
    );

    // =========================================================================
    // Mux interno: seleciona o imediato correto conforme o tipo da instrução
    // =========================================================================
    always_comb begin
        case (opcode)
            7'b0100011: imm_sel = imm_s;  // S-type: Store
            7'b1100011: imm_sel = imm_b;  // B-type: Branch
            7'b1101111: imm_sel = imm_j;  // J-type: JAL
            7'b0110111: imm_sel = imm_u;  // U-type: LUI
            7'b0010111: imm_sel = imm_u;  // U-type: AUIPC
            default:    imm_sel = imm_i;  // I-type (ADDI, loads, JALR, etc.)
        endcase
    end

    // =========================================================================
    // Mux 1 e 2: entradas da ALU
    // alu_src_a: 0=rs1, 1=PC (AUIPC)
    // alu_src_b: 0=rs2, 1=imediato
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
    // Mux 3: seleção de write-back
    // O que é escrito no registrador rd?
    // =========================================================================
    always_comb begin
        case (mem_to_reg)
            2'b00: reg_wd = alu_result;  // R-type, I-type, AUIPC
            2'b01: reg_wd = mem_rd;       // Loads: dado da memória
            2'b10: reg_wd = pc_plus4;     // JAL, JALR: endereço de retorno
            2'b11: reg_wd = imm_u;        // LUI: imediato upper direto
            default: reg_wd = alu_result;
        endcase
    end

    // =========================================================================
    // Banco de Registradores
    // Escrita síncrona, leitura combinacional
    // x0 é sempre zero (hardwired)
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
    // Memória de Dados (Harvard: RAM separada)
    // Escrita síncrona, leitura combinacional
    // funct3 controla largura e extensão de sinal (LB, LH, LW, LBU, LHU)
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
    // Portas de debug (apenas atribuições de fio, sem lógica extra)
    // =========================================================================
    assign dbg_pc         = pc;
    assign dbg_instr      = instr;
    assign dbg_alu_result = alu_result;
    assign dbg_reg_wd     = reg_wd;
    assign dbg_reg_we     = reg_write;

endmodule
```

---

## 6.5 Diagrama do Datapath

O diagrama abaixo mostra o fluxo completo de dados em texto ASCII. Leia de cima para baixo seguindo os sinais.

```
                                ┌──────────────────────────────────────────────┐
                                │            riscv_top (Harvard)               │
                                │                                              │
  ┌───────┐   pc_next           │  ┌─────┐  pc   ┌──────────┐  instr[31:0]   │
  │  PC   │◄────────────────────│  │     │───────►│ instr_mem│───────────────►│──┐
  │(FF)   │                     │  │     │        └──────────┘                │  │
  └───────┘  pc                 │  │ PC  │                                    │  │
      │──────────────────────►  │  │ mux │    instr[6:0] opcode               │  │
      │                         │  │     │◄───────────────────────────────────│◄─┤
      │  pc + 4                 │  └─────┘    instr[11:7]  rd_addr            │  │
      │──────────────────────►pc_plus4        instr[14:12] funct3             │  │
      │                         │             instr[19:15] rs1_addr           │  │
      │  pc + imm_b ──────────►branch_target  instr[24:20] rs2_addr           │  │
      │  (rs1+imm_i)&~1 ──────►jalr_target    instr[31:25] funct7             │  │
      │  pc + imm_j ──────────►(pc_next via jump)                             │  │
      │                         │                                              │  │
      │               ┌─────────┼─────────────────────────────┐               │  │
      │               │ opcode  │        control_unit          │               │  │
      │               │ ───────►│  reg_write  alu_op           │               │  │
      │               │         │  alu_src_a  mem_to_reg       │               │  │
      │               │         │  alu_src_b  branch           │               │  │
      │               │         │  mem_read   jump             │               │  │
      │               │         │  mem_write  jump_r           │               │  │
      │               └─────────┼──────────────────────────────┘               │  │
      │                         │                                              │  │
      │               ┌─────────┼───────────────────┐                         │  │
      │               │ funct3, │ alu_control        │                         │  │
      │               │ funct7, │  alu_sel           │                         │  │
      │               │ alu_op ►│  branch_inv        │                         │  │
      │               └─────────┼────────────────────┘                         │  │
      │                         │                                              │  │
      │               ┌─────────┼────────────────────────────────────┐         │  │
      │               │ imm_gen │ imm_i  imm_s  imm_b  imm_u  imm_j  │         │  │
      │               └─────────┼────────────────────────────────────┘         │  │
      │                         │                                              │  │
      │          rs1_addr ──►   │  ┌───────────────┐                           │  │
      │          rs2_addr ──►   │  │ register_file  │◄── reg_wd (write-back)   │  │
      │          rd_addr  ──►   │  │               │                           │  │
      │          reg_write ──►  │  │  rs1_data ────┼──► alu_a (via mux alu_src_a)│  │
      │                         │  │  rs2_data ────┼──► alu_b (via mux alu_src_b)│  │
      │                         │  │               │    rs2_data ──► data_mem.wd│  │
      │                         │  └───────────────┘                           │  │
      │                         │                                              │  │
      │                         │  ┌──────────┐                                │  │
      │                         │  │   ALU    │◄── alu_a, alu_b, alu_sel       │  │
      │                         │  │          │                                │  │
      │                         │  │ result ──┼──► data_mem.addr               │  │
      │                         │  │ zero   ──┼──► take_branch logic           │  │
      │                         │  └──────────┘                                │  │
      │                         │       │ alu_result                           │  │
      │                         │       ▼                                      │  │
      │                         │  ┌──────────┐                                │  │
      │                         │  │ data_mem │◄── mem_read, mem_write, funct3 │  │
      │                         │  │          │◄── wd = rs2_data               │  │
      │                         │  │  mem_rd ─┼──► write-back mux (mem_to_reg=01)│  │
      │                         │  └──────────┘                                │  │
      │                         │                                              │  │
      │                         │  ┌──────────────────────────────────┐        │  │
      │                         │  │  write-back mux (mem_to_reg)     │        │  │
      │                         │  │  00: alu_result                  │        │  │
      │                         │  │  01: mem_rd                      │────────►reg_wd
      │                         │  │  10: pc_plus4                    │        │
      │                         │  │  11: imm_u                       │        │
      │                         │  └──────────────────────────────────┘        │
      └─────────────────────────┴──────────────────────────────────────────────┘
```

---

## 6.6 Testbench de Integração: `tb/tb_arith.cpp`

### Programa de teste: `programs/test_arith.s`

O programa testa instruções R-type e I-type aritméticas. Cada registrador recebe um valor calculado e verificamos o resultado após a execução:

```asm
# =============================================================================
# Teste 1: Aritmética Básica — RISC-V RV32I
# Resultado esperado após execução:
#   x1  = 5
#   x2  = 3
#   x3  = 8    (x1 + x2 = 5 + 3)
#   x4  = 2    (x1 - x2 = 5 - 3)
#   x5  = 1    (x1 & x2 = 0101 & 0011 = 0001)
#   x6  = 7    (x1 | x2 = 0101 | 0011 = 0111)
#   x7  = 6    (x1 ^ x2 = 0101 ^ 0011 = 0110)
#   x8  = 10   (addi: x1 + 5 = 5 + 5)
#   x9  = 1    (slti: x2 < 5 ? 1 : 0 = 3 < 5 = 1)
#   x10 = 12   (slli: x2 << 2 = 3 << 2 = 12)
#   x11 = 6    (srli: x10 >> 1 = 12 >> 1 = 6)
#   x12 = 6    (srai: x10 >> 1 aritmético = 6)
#   x13 = -7   (addi x0, -7)
#   x14 = 1    (slt: x13 < x0 com sinal? -7 < 0 = 1)
#   x15 = 1    (sltu: x0 < x1 sem sinal? 0 < 5 = 1)
# =============================================================================
.section .text
.global _start
_start:
    addi  x1,  x0,  5      # x1 = 5
    addi  x2,  x0,  3      # x2 = 3
    add   x3,  x1,  x2     # x3 = 8
    sub   x4,  x1,  x2     # x4 = 2
    and   x5,  x1,  x2     # x5 = 1  (0101 & 0011)
    or    x6,  x1,  x2     # x6 = 7  (0101 | 0011)
    xor   x7,  x1,  x2     # x7 = 6  (0101 ^ 0011)
    addi  x8,  x1,  5      # x8 = 10
    slti  x9,  x2,  5      # x9 = 1  (3 < 5 com sinal)
    slli  x10, x2,  2      # x10 = 12 (3 << 2)
    srli  x11, x10, 1      # x11 = 6  (12 >> 1 lógico)
    srai  x12, x10, 1      # x12 = 6  (12 >> 1 aritmético)
    addi  x13, x0,  -7     # x13 = -7
    slt   x14, x13, x0     # x14 = 1  (-7 < 0 com sinal)
    sltu  x15, x0,  x1     # x15 = 1  (0 < 5 sem sinal)
loop:
    jal   x0,  loop        # halt: loop infinito
```

### Como montar o programa

O assembler GNU gera um arquivo objeto ELF. Precisamos extrair os bytes binários brutos e convertê-los para o formato hexadecimal que o `$readmemh` do SystemVerilog entende:

```bash
# 1. Montar: .s → .o (objeto ELF)
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 \
    -o programs/test_arith.o programs/test_arith.s

# 2. (Opcional) Gerar disassembly para verificação visual
riscv64-unknown-elf-objdump -d -M no-aliases \
    programs/test_arith.o > programs/test_arith.dis

# 3. Extrair bytes brutos: ELF → binário puro
riscv64-unknown-elf-objcopy -O binary \
    programs/test_arith.o programs/test_arith.bin

# 4. Converter binário little-endian para hexadecimal por palavra
python3 scripts/bin2hex.py programs/test_arith.bin programs/test_arith.hex
```

O script `bin2hex.py` lê o arquivo binário 4 bytes por vez (little-endian) e escreve cada palavra de 32 bits em uma linha do arquivo hex:

```python
#!/usr/bin/env python3
"""
Converte binário RISC-V (little-endian) para formato $readmemh do Verilator.
Uma palavra de 32 bits por linha, em hexadecimal.

Uso: python3 bin2hex.py <entrada.bin> <saida.hex>
"""
import struct
import sys

if len(sys.argv) != 3:
    print("Uso: " + sys.argv[0] + " <entrada.bin> <saida.hex>", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    data = f.read()

# Garante alinhamento de 4 bytes (padding com zeros se necessário)
while len(data) % 4:
    data += b'\x00'

with open(sys.argv[2], 'w') as f:
    for i in range(0, len(data), 4):
        word = struct.unpack_from('<I', data, i)[0]
        f.write(f'{word:08x}\n')

print(f"[bin2hex] {len(data)//4} palavras → {sys.argv[2]}")
```

### `tb/tb_arith.cpp`

O testbench segue um padrão simples: reset, execute N ciclos, verifique os registradores via porta de debug.

```cpp
// =============================================================================
// Testbench — Teste Aritmético (test_arith.hex)
// Valida: ADDI, ADD, SUB, AND, OR, XOR, SLTI, SLLI, SRLI, SRAI, SLT, SLTU
//
// Estratégia:
//   1. O Makefile copia test_arith.hex → sim/program.hex
//   2. O simulador é executado a partir do diretório sim/
//   3. instr_mem carrega program.hex via $readmemh
//   4. Executamos 20 ciclos (15 instruções + 5 iterações do loop de halt)
//   5. Lemos registradores via dbg_reg_sel / dbg_reg_val
// =============================================================================
#include <verilated.h>
#include "Vriscv_top.h"
#include <cstdio>
#include <cstdint>

static int passed = 0;
static int failed = 0;

// Gera uma borda de clock completa (posedge + negedge)
void tick(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->clk = 0; dut->eval(); ctx->timeInc(1);
    dut->clk = 1; dut->eval(); ctx->timeInc(1);
}

// Aplica reset ativo baixo por 2 ciclos e libera
void reset(Vriscv_top* dut, VerilatedContext* ctx) {
    dut->rst_n = 0;
    tick(dut, ctx);
    tick(dut, ctx);
    dut->rst_n = 1;
}

// Lê o valor de um registrador via porta de debug
// (não interfere na execução — a porta é somente leitura)
uint32_t read_reg(Vriscv_top* dut, int reg_num) {
    dut->dbg_reg_sel = reg_num;
    dut->eval();
    return (uint32_t)dut->dbg_reg_val;
}

// Verifica se o registrador tem o valor esperado e imprime PASS/FAIL
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

    // Estado inicial dos sinais de entrada
    dut->clk         = 0;
    dut->rst_n       = 1;
    dut->dbg_reg_sel = 0;
    dut->eval();

    printf("=== Teste Aritmético (test_arith.hex) ===\n\n");

    // Aplica reset
    reset(dut, ctx);

    // Executa: 15 instruções + alguns ciclos no loop de halt
    // Cada instrução consome exatamente 1 ciclo no modelo single-cycle
    for (int i = 0; i < 20; i++)
        tick(dut, ctx);

    // Verifica os resultados
    printf("[ Verificando registradores apos execucao ]\n");
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

## 6.7 Testbench: Load/Store (`tb/tb_loadstore.cpp`)

### Programa de teste: `programs/test_load_store.s`

Este programa exercita todas as variantes de load e store: byte (com e sem extensão de sinal), half-word e word.

```asm
# =============================================================================
# Teste 2: Load e Store — RISC-V RV32I
# Resultado esperado:
#   x1  = 100    (valor original)
#   x2  = 100    (lido da memória via LW)
#   x3  = 0x55   (byte sem sinal armazenado)
#   x4  = 0x55   (lido via LBU — sem extensão de sinal)
#   x5  = -85    (0xFFFFFFAB — valor com byte negativo)
#   x6  = -85    (lido via LB — extensão de sinal de 0xAB = -85)
#   x7  = 0x1234 (half-word construída bit a bit)
#   x8  = 0x1234 (lido via LHU — sem extensão de sinal)
# =============================================================================
.section .text
.global _start
_start:
    # Teste Word: SW / LW
    addi  x1, x0, 100        # x1 = 100
    sw    x1, 0(x0)          # mem[0] = 100  (word)
    lw    x2, 0(x0)          # x2 = 100

    # Teste Byte sem sinal: SB / LBU
    addi  x3, x0, 0x55       # x3 = 0x55 = 85
    sb    x3, 4(x0)          # mem[4] = 0x55  (somente byte baixo)
    lbu   x4, 4(x0)          # x4 = 0x55 (zero-extended)

    # Teste Byte com sinal: SB / LB
    addi  x5, x0, -85        # x5 = -85 = 0xFFFFFFAB
    sb    x5, 8(x0)          # mem[8] = 0xAB  (byte baixo de 0xFFFFFFAB)
    lb    x6, 8(x0)          # x6 = sext(0xAB) = -85 = 0xFFFFFFAB

    # Teste Half-word: SH / LHU
    # Construção de 0x1234 em dois passos (assembler não aceita imm > 2047)
    addi  x7, x0,  0x12      # x7 = 0x12
    slli  x7, x7,  8         # x7 = 0x1200
    ori   x7, x7,  0x34      # x7 = 0x1234
    sh    x7, 12(x0)         # mem[12] = 0x1234  (half-word)
    lhu   x8, 12(x0)         # x8 = 0x1234 (zero-extended)

loop:
    jal   x0, loop            # halt
```

### `tb/tb_loadstore.cpp`

```cpp
// =============================================================================
// Testbench — Load/Store (test_load_store.hex)
// Valida: LW/SW, LBU/SB, LB/SB (extensão de sinal), LHU/SH
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
        printf("  [PASS] x%-2d  %-28s = 0x%08X  (%d)\n",
               reg_num, descricao, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d  %-28s : esperado=0x%08X (%d),"
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

    printf("=== Teste Load/Store (test_load_store.hex) ===\n\n");

    reset(dut, ctx);

    // O programa tem 14 instruções + loop.
    // SW e SH escrevem na borda de subida, então precisamos de ciclos extras
    // para garantir que as escritas se propagaram antes de ler.
    // 25 ciclos é uma margem segura.
    for (int i = 0; i < 25; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores apos execucao ]\n");

    // x1 = 100 (valor original armazenado na memória)
    check(dut, 1,  100,            "addi: x1=100");

    // x2 = 100 (lido da memória via LW — deve reproduzir exatamente)
    check(dut, 2,  100,            "lw mem[0]: x2=100");

    // x3 = 0x55 = 85 (byte sem sinal)
    check(dut, 3,  0x55,           "addi: x3=0x55");

    // x4 = 0x55 (LBU não faz extensão de sinal — bit 7 de 0x55 é 0,
    //            mas mesmo que fosse 1, LBU zera os bits superiores)
    check(dut, 4,  0x55,           "lbu mem[4]: x4=0x55");

    // x5 = -85 = 0xFFFFFFAB (valor com bit de sinal no byte)
    check(dut, 5,  (uint32_t)(-85),"addi: x5=-85");

    // x6 = -85 (LB estende o sinal de 0xAB: bit 7 = 1 → sext → 0xFFFFFFAB)
    check(dut, 6,  (uint32_t)(-85),"lb mem[8]: x6=sext(0xAB)=-85");

    // x7 = 0x1234 (construído em 3 instruções)
    check(dut, 7,  0x1234,         "addi+slli+ori: x7=0x1234");

    // x8 = 0x1234 (LHU: half-word sem extensão de sinal;
    //             bit 15 de 0x1234 é 0, mas o comportamento seria o mesmo com LHU)
    check(dut, 8,  0x1234,         "lhu mem[12]: x8=0x1234");

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

## 6.8 Testbench: Branches (`tb/tb_branch.cpp`)

### Programa de teste: `programs/test_branch.s`

```asm
# =============================================================================
# Teste 3: Branches — RISC-V RV32I
# Resultado esperado:
#   x1  = 5
#   x2  = 5
#   x3  = 99   (BEQ tomado: pula a instrução que colocaria 1 em x3,
#                vai direto para skip_eq onde x3 recebe 99)
#   x4  = 0    (BNE NÃO tomado: x1==x2, então executa addi x4,x0,0)
#   x5  = 1    (BLT tomado: 3 < 5 → salta para set_blt → x5=1)
#   x6  = 1    (BGE tomado: 5 >= 5 → salta para set_bge → x6=1)
#   x7  = 1    (BLTU tomado: 0 < 0xFFFFFFFF sem sinal → x7=1)
# =============================================================================
.section .text
.global _start
_start:
    addi  x1, x0,  5          # x1 = 5
    addi  x2, x0,  5          # x2 = 5

    # BEQ x1, x2: x1==x2 → branch tomado → pula addi x3,x0,1
    beq   x1, x2, skip_eq     # tomado: vai para skip_eq
    addi  x3, x0,  1          # NÃO executa
skip_eq:
    addi  x3, x0,  99         # x3 = 99

    # BNE x1, x2: x1==x2 → branch NÃO tomado → executa addi x4,x0,0
    bne   x1, x2, skip_ne     # NÃO tomado (x1==x2)
    addi  x4, x0,  0          # executa: x4 = 0
skip_ne:

    # BLT x10, x1: 3 < 5 → tomado
    addi  x10, x0, 3          # x10 = 3
    blt   x10, x1, set_blt    # 3 < 5 → tomado
    addi  x5,  x0, 0          # NÃO executa
    jal   x0,  skip_blt
set_blt:
    addi  x5,  x0, 1          # x5 = 1
skip_blt:

    # BGE x1, x2: 5 >= 5 → tomado
    bge   x1, x2, set_bge     # 5 >= 5 → tomado
    addi  x6, x0, 0           # NÃO executa
    jal   x0, skip_bge
set_bge:
    addi  x6, x0, 1           # x6 = 1
skip_bge:

    # BLTU x0, x11: 0 < 0xFFFFFFFF sem sinal → tomado
    addi  x11, x0, -1         # x11 = 0xFFFFFFFF
    bltu  x0,  x11, set_bltu  # 0 < 0xFFFFFFFF (sem sinal) → tomado
    addi  x7,  x0, 0          # NÃO executa
    jal   x0,  skip_bltu
set_bltu:
    addi  x7, x0, 1           # x7 = 1
skip_bltu:

loop:
    jal   x0, loop             # halt
```

### `tb/tb_branch.cpp`

```cpp
// =============================================================================
// Testbench — Branches (test_branch.hex)
// Valida: BEQ, BNE, BLT, BGE, BLTU
// Verifica tanto branches tomados quanto não tomados
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
        printf("  [PASS] x%-2d  %-35s = 0x%08X  (%d)\n",
               reg_num, descricao, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d  %-35s : esperado=0x%08X (%d),"
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

    printf("=== Teste de Branches (test_branch.hex) ===\n\n");

    reset(dut, ctx);

    // O programa tem aproximadamente 22 instruções visíveis + labels e JALs.
    // 40 ciclos garante que todos os caminhos foram executados e o loop atingido.
    for (int i = 0; i < 40; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores apos execucao ]\n");

    check(dut, 1,  5,   "addi: x1=5");
    check(dut, 2,  5,   "addi: x2=5");

    // O teste mais sutil: BEQ tomado significa que addi x3,x0,1 NÃO executa,
    // e sim a instrução skip_eq que coloca 99 em x3.
    check(dut, 3,  99,  "BEQ tomado: x3=99 (nao 1)");

    // BNE não tomado: x1==x2, então o branch não acontece e x4 recebe 0.
    check(dut, 4,  0,   "BNE nao tomado: x4=0");

    // BLT: 3 < 5 com sinal → tomado → x5 = 1
    check(dut, 5,  1,   "BLT tomado (3<5): x5=1");

    // BGE: 5 >= 5 com sinal → tomado → x6 = 1
    check(dut, 6,  1,   "BGE tomado (5>=5): x6=1");

    // BLTU: 0 < 0xFFFFFFFF sem sinal → tomado → x7 = 1
    check(dut, 7,  1,   "BLTU tomado (0<0xFFFF...): x7=1");

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

## 6.9 Testbench: Jumps (`tb/tb_jump.cpp`)

### Programa de teste: `programs/test_jump.s`

Este programa testa chamada e retorno de função usando JAL e JALR. O mapa de endereços está anotado para que possamos verificar os endereços de retorno:

```asm
# =============================================================================
# Teste 4: Jumps (JAL e JALR) — RISC-V RV32I
#
# Mapa de endereços após montagem (cada instrução ocupa 4 bytes):
#   0x00  _start:    jal x1, func_a      → x1=0x04, salta para 0x0C
#   0x04  ret_a:     addi x5, x0, 77     → x5=77 (executado no retorno)
#   0x08             jal x0, test_jalr   → pula para test_jalr
#
#   0x0C  func_a:    addi x2, x0, 42     → x2=42
#   0x10             jalr x0, x1, 0      → retorna para 0x04 (ret_a)
#
#   0x14  test_jalr: auipc x10, 0        → x10 = 0x14 (PC desta instrução)
#   0x18             addi x10, x10, 16   → x10 = 0x14 + 0x10 = 0x24 (func_b)
#   0x1C             jalr x3, x10, 0     → x3=0x20, salta para func_b (0x24)
#   0x20  ret_b:     jal x0, loop        → pula para loop
#
#   0x24  func_b:    addi x4, x0, 99     → x4=99
#   0x28             jalr x0, x3, 0      → retorna para 0x20 (ret_b)
#
#   0x2C  loop:      jal x0, loop        → halt
#
# Resultado esperado:
#   x1  = 0x04   (link de JAL: PC+4 do primeiro jal)
#   x2  = 42     (func_a executou addi x2,x0,42)
#   x3  = 0x20   (link de JALR: PC+4 do jalr em 0x1C)
#   x4  = 99     (func_b executou addi x4,x0,99)
#   x5  = 77     (executado em ret_a após retorno de func_a)
# =============================================================================
.section .text
.global _start
_start:
    jal   x1,  func_a         # 0x00: x1 = 0x04, salta para func_a
ret_a:
    addi  x5,  x0, 77         # 0x04: x5 = 77  (ponto de retorno)
    jal   x0,  test_jalr      # 0x08: pula para test_jalr

func_a:                       # 0x0C
    addi  x2,  x0, 42         # x2 = 42
    jalr  x0,  x1, 0          # retorna para ret_a (endereço em x1 = 0x04)

test_jalr:                    # 0x14
    auipc x10, 0              # x10 = PC = 0x14
    addi  x10, x10, 16        # x10 = 0x14 + 16 = 0x24 (endereço de func_b)
    jalr  x3,  x10, 0         # x3 = 0x20 (PC+4), salta para func_b (0x24)
ret_b:
    jal   x0,  loop           # 0x20: pula para loop

func_b:                       # 0x24
    addi  x4,  x0, 99         # x4 = 99
    jalr  x0,  x3, 0          # retorna para ret_b (endereço em x3 = 0x20)

loop:                         # 0x2C
    jal   x0,  loop           # halt
```

### `tb/tb_jump.cpp`

```cpp
// =============================================================================
// Testbench — Jumps (test_jump.hex)
// Valida: JAL (link + salto relativo), JALR (salto via registrador + link),
//         AUIPC (endereço PC-relativo), chamada e retorno de função
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
        printf("  [PASS] x%-2d  %-40s = 0x%08X  (%d)\n",
               reg_num, descricao, got, (int32_t)got);
        passed++;
    } else {
        printf("  [FAIL] x%-2d  %-40s : esperado=0x%08X (%d),"
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

    printf("=== Teste de Jumps (test_jump.hex) ===\n\n");

    reset(dut, ctx);

    // O programa percorre: _start → func_a → ret_a → test_jalr → func_b → ret_b → loop
    // São 12 instruções no caminho crítico. 30 ciclos é mais do que suficiente.
    for (int i = 0; i < 30; i++)
        tick(dut, ctx);

    printf("[ Verificando registradores apos execucao ]\n");

    // JAL em 0x00 salva PC+4 = 0x04 em x1 (link register / ra)
    check(dut, 1, 0x00000004, "JAL: x1=PC+4=0x04 (link de func_a)");

    // func_a executou: addi x2, x0, 42
    check(dut, 2, 42,         "func_a: x2=42");

    // JALR em 0x1C salva PC+4 = 0x20 em x3
    check(dut, 3, 0x00000020, "JALR: x3=PC+4=0x20 (link de func_b)");

    // func_b executou: addi x4, x0, 99
    check(dut, 4, 99,         "func_b: x4=99");

    // Após retorno de func_a, executa em ret_a: addi x5, x0, 77
    check(dut, 5, 77,         "retorno JAL: x5=77 em ret_a");

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

## 6.10 O Makefile Completo

O Makefile coordena toda a toolchain: assembler RISC-V, conversão de binário, Verilator e execução dos testes. Coloque-o no diretório `meu_riscv/` (ou use diretamente em `riscv_harvard/`).

```makefile
# =============================================================================
# Makefile — Processador RISC-V Harvard (Verilator)
# =============================================================================

# Ferramentas
VERILATOR   := verilator
AS          := riscv64-unknown-elf-as
OBJCOPY     := riscv64-unknown-elf-objcopy
OBJDUMP     := riscv64-unknown-elf-objdump
PYTHON      := python3

# Diretórios
SRC_DIR     := src
TB_DIR      := tb
PROG_DIR    := programs
SIM_DIR     := sim
OBJ_DIR     := obj_dir

# Flags do Verilator
# --cc:           gera C++ a partir do SystemVerilog
# --sv:           habilita extensões SystemVerilog
# --exe --build:  compila e linka em uma etapa
# --Mdir:         diretório de saída dos arquivos gerados
# -I$(SRC_DIR):   diretório de busca para `include
# -Wall:          todos os warnings
# -Wno-UNUSEDSIGNAL: silencia warning de sinais de debug não usados internamente
VFLAGS_BASE := --cc --sv --exe --build \
               --Mdir $(OBJ_DIR)       \
               -I$(SRC_DIR)            \
               -Wall                   \
               -Wno-UNUSEDSIGNAL

# Flags do assembler RISC-V
# -march=rv32i: apenas a ISA base inteira de 32 bits (sem extensões M, A, F, etc.)
# -mabi=ilp32:  convenção de chamada de 32 bits
AS_FLAGS    := -march=rv32i -mabi=ilp32

# =============================================================================
# Alvos .PHONY: não correspondem a arquivos
# =============================================================================
.PHONY: all programs alu regfile arith loadstore branch jump wave clean help

# Alvo padrão: monta programas e executa todos os testes
all: programs alu regfile arith loadstore branch jump
	@echo ""
	@echo "============================================"
	@echo "  Todos os testes concluidos!"
	@echo "============================================"

# =============================================================================
# Montagem dos programas de teste (.s → .hex)
# =============================================================================
programs: $(PROG_DIR)/test_arith.hex       \
          $(PROG_DIR)/test_load_store.hex  \
          $(PROG_DIR)/test_branch.hex      \
          $(PROG_DIR)/test_jump.hex
	@echo "[OK] Programas montados"

# Regra genérica para cada programa:
# 1. Montar com riscv64-unknown-elf-as
# 2. Gerar disassembly (útil para debug)
# 3. Extrair binário puro com objcopy
# 4. Converter para hex com o script Python

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
# Teste unitário da ALU
# =============================================================================
alu: $(OBJ_DIR)/Valu
	@echo ""
	@echo "=== Executando teste da ALU ==="
	$(OBJ_DIR)/Valu
	@echo ""

$(OBJ_DIR)/Valu: $(SRC_DIR)/alu.sv $(TB_DIR)/tb_alu.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module alu \
	    $(SRC_DIR)/alu.sv               \
	    $(TB_DIR)/tb_alu.cpp            \
	    -o Valu

# =============================================================================
# Teste unitário do Banco de Registradores
# =============================================================================
regfile: $(OBJ_DIR)/Vregfile
	@echo ""
	@echo "=== Executando teste do Banco de Registradores ==="
	$(OBJ_DIR)/Vregfile
	@echo ""

$(OBJ_DIR)/Vregfile: $(SRC_DIR)/register_file.sv $(TB_DIR)/tb_regfile.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module register_file \
	    $(SRC_DIR)/register_file.sv     \
	    $(TB_DIR)/tb_regfile.cpp        \
	    -o Vregfile

# =============================================================================
# Compilação dos binários de simulação do processador completo
# Cada testbench tem seu próprio binário (inclui o top-level + testbench)
# =============================================================================

$(OBJ_DIR)/Varith: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_arith.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv         \
	    $(TB_DIR)/tb_arith.cpp          \
	    -o Varith

$(OBJ_DIR)/Vloadstore: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_loadstore.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv         \
	    $(TB_DIR)/tb_loadstore.cpp      \
	    -o Vloadstore

$(OBJ_DIR)/Vbranch: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_branch.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv         \
	    $(TB_DIR)/tb_branch.cpp         \
	    -o Vbranch

$(OBJ_DIR)/Vjump: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_jump.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --top-module riscv_top \
	    $(SRC_DIR)/riscv_top.sv         \
	    $(TB_DIR)/tb_jump.cpp           \
	    -o Vjump

# =============================================================================
# Execução dos testes de integração
#
# Padrão: copiar o hex correto para sim/program.hex e executar de lá.
# Isso funciona porque instr_mem usa $readmemh("program.hex", mem),
# que busca o arquivo relativo ao diretório de trabalho do simulador.
# =============================================================================

arith: $(OBJ_DIR)/Varith $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Aritmetico ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Varith
	@echo ""

loadstore: $(OBJ_DIR)/Vloadstore $(PROG_DIR)/test_load_store.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_load_store.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste Load/Store ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vloadstore
	@echo ""

branch: $(OBJ_DIR)/Vbranch $(PROG_DIR)/test_branch.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_branch.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Branches ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vbranch
	@echo ""

jump: $(OBJ_DIR)/Vjump $(PROG_DIR)/test_jump.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_jump.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Executando: Teste de Jumps ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vjump
	@echo ""

# =============================================================================
# Geração de waveform VCD para visualização no GTKWave
# =============================================================================
wave: $(OBJ_DIR)/Vwave $(PROG_DIR)/test_arith.hex
	@mkdir -p $(SIM_DIR)
	@cp $(PROG_DIR)/test_arith.hex $(SIM_DIR)/program.hex
	@echo ""
	@echo "=== Gerando Waveform VCD ==="
	cd $(SIM_DIR) && ../$(OBJ_DIR)/Vwave
	@echo "[OK] waves.vcd gerado em $(SIM_DIR)/"
	@echo "     Abrir com: gtkwave $(SIM_DIR)/waves.vcd"
	@echo ""

$(OBJ_DIR)/Vwave: $(SRC_DIR)/riscv_top.sv $(TB_DIR)/tb_wave.cpp
	@mkdir -p $(OBJ_DIR)
	$(VERILATOR) $(VFLAGS_BASE) --trace    \
	    --top-module riscv_top             \
	    $(SRC_DIR)/riscv_top.sv            \
	    $(TB_DIR)/tb_wave.cpp              \
	    -o Vwave

# =============================================================================
# Limpeza
# =============================================================================
clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)
	rm -f $(PROG_DIR)/*.o $(PROG_DIR)/*.bin $(PROG_DIR)/*.dis $(PROG_DIR)/*.hex

# =============================================================================
# Ajuda
# =============================================================================
help:
	@echo "Alvos disponiveis:"
	@echo "  make all        — monta programas + executa todos os testes"
	@echo "  make programs   — monta apenas os programas .s → .hex"
	@echo "  make alu        — teste unitario da ALU"
	@echo "  make regfile    — teste unitario do banco de registradores"
	@echo "  make arith      — teste aritmetico (ADDI, ADD, SUB, AND, ...)"
	@echo "  make loadstore  — teste de load/store (LW, SW, LB, SB, ...)"
	@echo "  make branch     — teste de branches (BEQ, BNE, BLT, BGE, ...)"
	@echo "  make jump       — teste de jumps (JAL, JALR)"
	@echo "  make wave       — gera sim/waves.vcd para GTKWave"
	@echo "  make clean      — remove arquivos gerados"
```

---

## 6.11 Sequência Completa de Execução

Para construir e testar o processador Harvard do zero:

```bash
# 1. Entrar no diretório do projeto
cd /Users/joaocarlosbrittofilho/Documents/neander_riscV/riscv_harvard

# 2. Montar todos os programas de teste
make programs

# 3. Testar componentes individualmente (diagnóstico rápido)
make alu
make regfile

# 4. Executar testes de integração
make arith
make loadstore
make branch
make jump

# 5. Ou tudo de uma vez
make all

# 6. Visualizar waveforms (opcional, requer GTKWave instalado)
make wave
gtkwave sim/waves.vcd
```

Saída esperada de `make arith` (parcial):

```
=== Teste Aritmético (test_arith.hex) ===

[IMEM] Carregando program.hex ...
[IMEM] Carregado. mem[0]=0x00500093

[ Verificando registradores apos execucao ]
  [PASS] x1   addi x0,5              = 0x00000005  (5)
  [PASS] x2   addi x0,3              = 0x00000003  (3)
  [PASS] x3   add x1,x2              = 0x00000008  (8)
  [PASS] x4   sub x1,x2              = 0x00000002  (2)
  ...
  [PASS] x15  sltu x0,x1 (0<5=1)    = 0x00000001  (1)

===================================
Resultados: 15 aprovados, 0 reprovados
===================================
```

---

## 6.12 Entendendo o Timing de Escrita em Memória

Um ponto sutil que frequentemente causa bugs é o timing das escritas. No modelo single-cycle com memórias síncronas:

```
Ciclo N:
  → PC aponta para instrução SW (store word)
  → instr_mem lê a instrução combinacionalmente
  → ALU calcula o endereço (rs1 + imm_s)
  → data_mem.wd = rs2_data (dado a escrever está disponível)
  → BORDA DE SUBIDA DO CLOCK
     - data_mem escreve wd no endereço calculado
     - PC avança para a próxima instrução
     - register_file escreve reg_wd em rd (se reg_write=1)

Ciclo N+1:
  → PC aponta para instrução LW (load word)
  → ALU calcula o endereço (rs1 + imm_i)
  → data_mem lê combinacionalmente o valor armazenado no ciclo N
  → O valor lido já está disponível no mesmo ciclo
```

Isso funciona porque a leitura da memória de dados é combinacional (não precisa de clock para aparecer na saída), e a escrita do ciclo anterior já aconteceu na borda de subida que separou os dois ciclos. É a principal razão pela qual o modelo single-cycle é simples: não há hazards de dados — o resultado de um SW sempre está disponível para um LW subsequente.

Esta garantia desaparece em processadores pipelined, onde um LW na instrução seguinte a um SW poderia encontrar o dado ainda não escrito (load-use hazard). Mas isso é assunto para quando você quiser adicionar pipeline ao seu processador.
