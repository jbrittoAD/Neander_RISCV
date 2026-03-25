// =============================================================================
// Arithmetic and Logic Unit (ALU) — RISC-V RV32I
// Unidade Lógica e Aritmética (ALU) — RISC-V RV32I
// Supports all arithmetic/logic operations of the base instruction set
// Suporta todas as operações aritméticas/lógicas do conjunto base
// =============================================================================
module alu #(
    parameter WIDTH = 32
) (
    input  logic [WIDTH-1:0] a,        // Operand A / Operando A
    input  logic [WIDTH-1:0] b,        // Operand B / Operando B
    input  logic [3:0]       op,       // Selected operation / Operação selecionada

    output logic [WIDTH-1:0] result,   // Result / Resultado
    output logic             zero      // Flag: result == 0 / Flag: resultado == 0
);

    // ALU operation encoding / Codificação das operações da ALU
    localparam ALU_ADD  = 4'b0000;  // Addition / Adição
    localparam ALU_SUB  = 4'b0001;  // Subtraction / Subtração
    localparam ALU_AND  = 4'b0010;  // Bitwise AND / AND bit-a-bit
    localparam ALU_OR   = 4'b0011;  // Bitwise OR / OR bit-a-bit
    localparam ALU_XOR  = 4'b0100;  // Bitwise XOR / XOR bit-a-bit
    localparam ALU_SLL  = 4'b0101;  // Logical shift left / Shift lógico à esquerda
    localparam ALU_SRL  = 4'b0110;  // Logical shift right / Shift lógico à direita
    localparam ALU_SRA  = 4'b0111;  // Arithmetic shift right / Shift aritmético à direita
    localparam ALU_SLT  = 4'b1000;  // Signed less-than / Menor que (com sinal)
    localparam ALU_SLTU = 4'b1001;  // Unsigned less-than / Menor que (sem sinal)

    always_comb begin
        case (op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = {{(WIDTH-1){1'b0}}, ($signed(a) < $signed(b))};
            ALU_SLTU: result = {{(WIDTH-1){1'b0}}, (a < b)};
            default:  result = '0;
        endcase
    end

    assign zero = (result == '0);

endmodule
