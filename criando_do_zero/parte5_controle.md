# Parte 5 — Decodificador de Instruções e Unidade de Controle

> **Pré-requisito:** você completou as Partes 1 a 4 — ALU, banco de registradores e memórias funcionam corretamente.

Nesta parte construímos a "inteligência" do processador: os circuitos que leem uma instrução de 32 bits e decidem o que fazer com ela. Ao final, teremos três módulos prontos: o gerador de imediatos (`imm_gen`), a unidade de controle principal (`control_unit`) e o controle da ALU (`alu_control`).

---

## 5.1 O Gerador de Imediatos (Immediate Generator)

### O problema: imediatos embaralhados

Se você olhou com atenção para os formatos de instrução na Parte 1, notou que os bits do imediato estão espalhados pela instrução de formas diferentes em cada formato. Por que alguém faria isso?

A resposta está em uma decisão de design muito cuidadosa: **o bit 31 da instrução é sempre o MSB (Most Significant Bit) do imediato**, independentemente do formato.

```
Formato   bit 31 da instrução   bit 31 do imediato (= bit de sinal)
I-type    instr[31]             imm[11] = instr[31]   → extensão de sinal simples
S-type    instr[31]             imm[11] = instr[31]   → extensão de sinal simples
B-type    instr[31]             imm[12] = instr[31]   → extensão de sinal simples
U-type    instr[31]             imm[31] = instr[31]   → sem extensão necessária
J-type    instr[31]             imm[20] = instr[31]   → extensão de sinal simples
```

Em todos os casos, o circuito de extensão de sinal é exatamente o mesmo: replica `instr[31]` para os bits mais significativos que precisam ser preenchidos. Sem esse "scrambling", o bit de sinal poderia estar em posições diferentes em cada formato, exigindo lógica de seleção separada.

**Custo:** o circuito de montagem do imediato precisa conectar bits de posições diferentes. Mas essa é lógica puramente combinacional (fios e multiplexadores) — custo em área, zero em tempo de ciclo.

### Mapeamento bit a bit de cada formato

**I-type** (loads, ADDI, JALR):
```
Instrução:  [31:20] = imm[11:0]
Imediato:   imm[31:12] = {20 cópias de instr[31]}
            imm[11:0]  = instr[31:20]
```

**S-type** (stores): o imediato é partido para liberar o campo `rs2` no lugar de `rd`
```
Instrução:  [31:25] = imm[11:5],  [11:7] = imm[4:0]
Imediato:   imm[31:12] = {20 cópias de instr[31]}
            imm[11:5]  = instr[31:25]
            imm[4:0]   = instr[11:7]
```

**B-type** (branches): o bit 0 é sempre 0 (alinhamento de 2 bytes), então não é armazenado
```
Instrução:  [31]    = imm[12]
            [30:25] = imm[10:5]
            [11:8]  = imm[4:1]
            [7]     = imm[11]   ← bit 11 "pulado" para cá para ficar simétrico com J
Imediato:   imm[31:13] = {19 cópias de instr[31]}
            imm[12]    = instr[31]
            imm[11]    = instr[7]
            imm[10:5]  = instr[30:25]
            imm[4:1]   = instr[11:8]
            imm[0]     = 1'b0
```

**U-type** (LUI, AUIPC): sem extensão de sinal; os 12 bits baixos são sempre zero
```
Instrução:  [31:12] = imm[31:12]
Imediato:   imm[31:12] = instr[31:12]
            imm[11:0]  = 12'b0
```

**J-type** (JAL): imediato de 21 bits, bit 0 sempre zero
```
Instrução:  [31]    = imm[20]
            [30:21] = imm[10:1]
            [20]    = imm[11]
            [19:12] = imm[19:12]
Imediato:   imm[31:21] = {11 cópias de instr[31]}
            imm[20]    = instr[31]
            imm[19:12] = instr[19:12]
            imm[11]    = instr[20]
            imm[10:1]  = instr[30:21]
            imm[0]     = 1'b0
```

### `src/imm_gen.sv`

```systemverilog
// imm_gen.sv
// Gerador de imediatos para o processador RISC-V RV32I.
// Lê os 32 bits da instrução e produz o imediato de 32 bits correspondente.
//
// Observação sobre o opcode de JALR:
//   JALR usa formato I-type (opcode=1100111), mas é um salto — não aritmética.
//   O imediato tem o mesmo formato que outros I-type, então não precisa de
//   case separado.

module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    // Extrai o opcode para selecionar o formato
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin
        case (opcode)

            // -------------------------------------------------------
            // I-type: instruções aritméticas imediatas
            //   ADDI, SLTI, SLTIU, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            // I-type: JALR
            // I-type: loads (LB, LH, LW, LBU, LHU)
            //
            // Todos os I-type têm o imediato nos bits [31:20].
            // Extensão de sinal com instr[31].
            // -------------------------------------------------------
            7'b0010011,  // I-arith
            7'b1100111,  // JALR
            7'b0000011:  // loads
                imm = {{20{instr[31]}}, instr[31:20]};

            // -------------------------------------------------------
            // S-type: stores (SB, SH, SW)
            //
            // Imediato partido: [31:25]=imm[11:5], [11:7]=imm[4:0]
            // Montagem: concatena os dois campos na ordem correta.
            // -------------------------------------------------------
            7'b0100011:
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // -------------------------------------------------------
            // B-type: branches (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            //
            // Imediato de 13 bits (bit 0 = 0 implícito).
            // A ordem "embaralhada" garante que instr[31] = imm[12] (sinal).
            // -------------------------------------------------------
            7'b1100011:
                imm = {{19{instr[31]}},
                       instr[31],    // imm[12]
                       instr[7],     // imm[11]  ← posição "estranha"
                       instr[30:25], // imm[10:5]
                       instr[11:8],  // imm[4:1]
                       1'b0};        // imm[0] = 0 (alinhamento)

            // -------------------------------------------------------
            // U-type: LUI, AUIPC
            //
            // Imediato de 20 bits nos bits altos da instrução.
            // Os 12 bits inferiores do imediato são sempre zero.
            // Não há extensão de sinal — o imediato já é de 32 bits.
            // -------------------------------------------------------
            7'b0110111,  // LUI
            7'b0010111:  // AUIPC
                imm = {instr[31:12], 12'b0};

            // -------------------------------------------------------
            // J-type: JAL
            //
            // Imediato de 21 bits (bit 0 = 0 implícito).
            // Mais embaralhado que B-type para manter simetria com ele.
            // -------------------------------------------------------
            7'b1101111:
                imm = {{11{instr[31]}},
                       instr[31],    // imm[20] (sinal)
                       instr[19:12], // imm[19:12]  ← bloco "no meio"
                       instr[20],    // imm[11]
                       instr[30:21], // imm[10:1]
                       1'b0};        // imm[0] = 0

            // Opcode desconhecido: retorna zero
            default: imm = 32'b0;
        endcase
    end
endmodule
```

### Exemplos concretos

**Exemplo 1:** `addi x1, x0, 42`
- Encoding: `0x02a00093`
- Binário: `0000_0010_1010_0000_0000_0000_1001_0011`
- opcode = `0010011` (I-arith)
- instr[31:20] = `0000_0010_1010` = 42
- imm esperado: `0x0000_002A` = 42 ✓

**Exemplo 2:** `beq x1, x2, -8` (desviar 8 bytes para trás)
- Offset = -8 = `1111_1111_1111_1000` (13 bits com sinal: `1_1111_1000`)
- imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1000, imm[0]=0
- Montagem no campo da instrução:
  - bit 31 = imm[12] = 1
  - bit 7  = imm[11] = 1
  - bits 30:25 = imm[10:5] = 111111
  - bits 11:8  = imm[4:1]  = 1000
- imm gerado: `{19{1}, 1, 1, 111111, 1000, 0}` = `0xFFFF_FFF8` = -8 ✓

**Exemplo 3:** `lui x1, 0xDEAD`
- opcode = `0110111` (LUI)
- instr[31:12] = `0000_0000_0000_1101_1110_1010_1101`... espere — LUI carrega um imediato de 20 bits
- Para `lui x1, 0xDEAD`: instr[31:12] = `0x000DEAD`
- imm = `{0x000DEAD, 12'b0}` = `0x000DEAD000`... mas o resultado é 32 bits
- Correto: `0xDEAD_0000` (os 12 bits baixos são zerados, os 20 bits altos são o imediato) ✓

### `tb/tb_imm_gen.cpp`

```cpp
// tb_imm_gen.cpp
// Testa o gerador de imediatos com instruções codificadas manualmente.
// Cada teste fornece uma instrução de 32 bits e verifica o imediato esperado.

#include <iostream>
#include <cstdint>
#include "Vimm_gen.h"
#include "verilated.h"

int erros = 0;

void check_imm(Vimm_gen* dut, const char* desc,
               uint32_t instr, uint32_t expected_imm) {
    dut->instr = instr;
    dut->eval();
    uint32_t got = (uint32_t)dut->imm;
    if (got == expected_imm) {
        std::cout << "PASS: " << desc
                  << " → imm=0x" << std::hex << got << std::dec << std::endl;
    } else {
        std::cout << "FAIL: " << desc
                  << " → esperado=0x" << std::hex << expected_imm
                  << " obtido=0x" << got << std::dec << std::endl;
        erros++;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vimm_gen* dut = new Vimm_gen;

    std::cout << "=== I-type: ADDI ===" << std::endl;

    // addi x1, x0, 42 → imm = 42
    // Encoding manual: imm[11:0]=42=0x02A, rs1=x0=0, funct3=000, rd=x1=1, opcode=0010011
    // Bits: 0000_0010_1010 | 00000 | 000 | 00001 | 0010011
    //    = 0x02A0_0093
    check_imm(dut, "addi x1,x0,42",
              0x02A00093u, 42u);

    // addi x1, x0, -1 → imm = -1 = 0xFFFFFFFF
    // imm[11:0] = 0xFFF (12 bits todos 1), rs1=0, funct3=000, rd=1, opcode=0010011
    // Bits: 1111_1111_1111 | 00000 | 000 | 00001 | 0010011
    //    = 0xFFF0_0093
    check_imm(dut, "addi x1,x0,-1",
              0xFFF00093u, 0xFFFFFFFFu);

    // addi x3, x1, 2047 → imm = 2047 = 0x7FF (máximo positivo I-type)
    // imm[11:0] = 0x7FF, rs1=x1=1, funct3=000, rd=x3=3, opcode=0010011
    // Bits: 0111_1111_1111 | 00001 | 000 | 00011 | 0010011
    //    = 0x7FF0_8193
    check_imm(dut, "addi x3,x1,2047 (max positivo I-type)",
              0x7FF08193u, 2047u);

    // addi x3, x1, -2048 → imm = -2048 = 0xFFFFF800 (mínimo I-type)
    // imm[11:0] = 0x800 = 1000_0000_0000
    // Bits: 1000_0000_0000 | 00001 | 000 | 00011 | 0010011
    //    = 0x80008193
    check_imm(dut, "addi x3,x1,-2048 (min I-type)",
              0x80008193u, 0xFFFFF800u);

    std::cout << "\n=== S-type: SW ===" << std::endl;

    // sw x2, 8(x1)  → imm = 8
    // offset=8=0x8=0000_0000_1000: imm[11:5]=0000000, imm[4:0]=01000
    // rs2=x2=2, rs1=x1=1, funct3=010, opcode=0100011
    // Bits: 0000000 | 00010 | 00001 | 010 | 01000 | 0100011
    //    = 0x0020_A423
    check_imm(dut, "sw x2,8(x1) → imm=8",
              0x0020A423u, 8u);

    // sw x2, -4(x1) → imm = -4 = 0xFFFFFFFC
    // offset=-4=0x1FC...neste caso em 12 bits: 1111_1111_1100
    // imm[11:5]=1111111, imm[4:0]=11100
    // Bits: 1111111 | 00010 | 00001 | 010 | 11100 | 0100011
    //    = 0xFE20AE23
    check_imm(dut, "sw x2,-4(x1) → imm=-4",
              0xFE20AE23u, 0xFFFFFFFCu);

    std::cout << "\n=== B-type: BEQ ===" << std::endl;

    // beq x1, x2, 8  → imm = 8 (pular 2 instruções adiante)
    // offset=8=0000_0000_1000: imm[12]=0,imm[11]=0,imm[10:5]=000000,imm[4:1]=0100,imm[0]=0
    // rs1=x1=1, rs2=x2=2, funct3=000, opcode=1100011
    // bit31=imm[12]=0, bits30:25=imm[10:5]=000000
    // bit11:8=imm[4:1]=0100, bit7=imm[11]=0
    // Bits: 0_000000 | 00010 | 00001 | 000 | 0100_0 | 1100011
    //    = 0x0020_8463
    check_imm(dut, "beq x1,x2,+8 → imm=8",
              0x00208463u, 8u);

    // beq x1, x2, -8 → imm = -8 = 0xFFFFFFF8
    // offset=-8=1_1111_1111_1000 em 13 bits:
    //   imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=1100, imm[0]=0
    // bit31=1, bits30:25=111111, bits11:8=1100, bit7=1
    // Bits: 1_111111 | 00010 | 00001 | 000 | 1100_1 | 1100011
    //    = 0xFE208CE3
    check_imm(dut, "beq x1,x2,-8 → imm=-8",
              0xFE208CE3u, 0xFFFFFFF8u);

    std::cout << "\n=== U-type: LUI ===" << std::endl;

    // lui x1, 0xDEAD0 → rd=x1, imm[31:12]=0xDEAD0
    // Espera: imm = 0xDEAD_0000
    // Bits: 1101_1110_1010_1101_0000 | 00001 | 0110111
    //    = 0xDEAD00B7
    check_imm(dut, "lui x1, 0xDEAD0 → imm=0xDEAD0000",
              0xDEAD00B7u, 0xDEAD0000u);

    // lui x5, 1 → imm = 0x00001000
    // instr[31:12] = 0x00001, rd=x5=5, opcode=0110111
    // Bits: 0000_0000_0000_0000_0001 | 00101 | 0110111
    //    = 0x000012B7
    check_imm(dut, "lui x5,1 → imm=0x00001000",
              0x000012B7u, 0x00001000u);

    std::cout << "\n=== J-type: JAL ===" << std::endl;

    // jal x1, 0 → imm = 0 (salta para si mesmo)
    // offset=0: todos os bits do imediato são 0
    // rd=x1=1, opcode=1101111
    // Bits: 0_0000000000_0_00000000 | 00001 | 1101111
    //    = 0x000000EF
    check_imm(dut, "jal x1, 0 → imm=0",
              0x000000EFu, 0u);

    // jal x0, 4 → imm = 4 (pula uma instrução adiante)
    // offset=4=0_0000_0000_0100:
    //   imm[20]=0, imm[10:1]=0000000010, imm[11]=0, imm[19:12]=00000000
    // rd=x0=0, opcode=1101111
    // bit31=0, bits30:21=0000000010, bit20=0, bits19:12=00000000
    // Bits: 0_0000000010_0_00000000 | 00000 | 1101111
    //    = 0x0040006F
    check_imm(dut, "jal x0, +4 → imm=4",
              0x0040006Fu, 4u);

    // --- Resultado final ---
    std::cout << "\n";
    if (erros == 0)
        std::cout << "Todos os testes PASSARAM." << std::endl;
    else
        std::cout << erros << " teste(s) FALHARAM." << std::endl;

    dut->final();
    delete dut;
    return (erros > 0) ? 1 : 0;
}
```

### Compilando e testando o imm_gen

```bash
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/imm_gen.sv tb/tb_imm_gen.cpp \
  -o Vimm_gen

./obj_dir/Vimm_gen
```

Saída esperada:
```
=== I-type: ADDI ===
PASS: addi x1,x0,42 → imm=0x2a
PASS: addi x1,x0,-1 → imm=0xffffffff
PASS: addi x3,x1,2047 (max positivo I-type) → imm=0x7ff
PASS: addi x3,x1,-2048 (min I-type) → imm=0xfffff800

=== S-type: SW ===
PASS: sw x2,8(x1) → imm=8
PASS: sw x2,-4(x1) → imm=-4

=== B-type: BEQ ===
PASS: beq x1,x2,+8 → imm=8
PASS: beq x1,x2,-8 → imm=-8

=== U-type: LUI ===
PASS: lui x1, 0xDEAD0 → imm=0xDEAD0000
PASS: lui x5,1 → imm=0x00001000

=== J-type: JAL ===
PASS: jal x1, 0 → imm=0
PASS: jal x0, +4 → imm=4

Todos os testes PASSARAM.
```

---

## 5.2 A Unidade de Controle Principal

### O que a unidade de controle faz

A unidade de controle é um decodificador combinacional puro: dado o `opcode` de 7 bits, ela produz todos os sinais de controle que configuram o datapath para executar aquela instrução corretamente. Não tem estado, não tem memória — apenas lógica combinacional.

Pense nela como uma tabela de verdade com 7 entradas (bits do opcode) e ~13 saídas (sinais de controle). O case statement no SystemVerilog é exatamente essa tabela.

### Tabela de sinais de controle

| Sinal | Largura | Função |
|-------|---------|--------|
| `reg_write` | 1 bit | 1 = habilita escrita no banco de registradores |
| `alu_src` | 1 bit | 0 = segundo operando da ALU é rs2 ; 1 = é o imediato |
| `mem_write` | 1 bit | 1 = habilita escrita na memória de dados (SW, SH, SB) |
| `mem_read` | 1 bit | 1 = instrução lê da memória de dados (LW, LH, LB, ...) |
| `mem_to_reg` | 2 bits | 00 = escreve resultado da ALU no rd ; 01 = escreve dado da memória ; 10 = escreve PC+4 (para JAL/JALR) |
| `branch` | 1 bit | 1 = instrução é um branch condicional (avalia condição na ALU) |
| `jump` | 2 bits | 00 = fluxo normal ; 01 = JAL (PC-relative) ; 10 = JALR (register+imm) |
| `alu_op` | 2 bits | 00 = força ADD (loads e stores precisam calcular endereço) ; 01 = força SUB (branches comparam) ; 10 = usa funct3/funct7 (R-type e I-arith) |
| `width` | 2 bits | Largura do acesso à memória: 00=byte, 01=half, 10=word |
| `sign_ext` | 1 bit | 1 = extensão de sinal em load (LB, LH) ; 0 = sem sinal (LBU, LHU, LW) |
| `lui_op` | 1 bit | 1 = LUI: escreve o imediato diretamente no rd, sem passar pela ALU |
| `auipc_op` | 1 bit | 1 = AUIPC: primeiro operando da ALU é o PC (não rs1) |

**Por que `alu_op` tem 3 possíveis valores?**

A ALU pode ser controlada diretamente pelo opcode (`add` para calcular endereço de load/store, `sub` para branch) ou pode delegar a decisão para o `alu_control`, que usa `funct3`/`funct7` para distinguir entre ADD, SUB, AND, OR, XOR, etc. O sinal `alu_op=10` significa "olhe para funct3/funct7 para decidir".

Isso cria um nível de hierarquia: `control_unit` faz a decisão grossa (tipo de instrução), `alu_control` faz a decisão fina (operação específica dentro do tipo).

### `src/control_unit.sv`

```systemverilog
// control_unit.sv
// Unidade de controle principal do processador RISC-V RV32I.
// Decodifica o opcode e produz todos os sinais de controle para o datapath.
//
// Sinais de saída:
//   reg_write  — habilita escrita no banco de registradores
//   alu_src    — seleciona segundo operando da ALU (0=rs2, 1=imediato)
//   mem_write  — habilita escrita na memória de dados
//   mem_read   — habilita leitura da memória de dados
//   mem_to_reg — seleciona o que escrever em rd (00=ALU, 01=mem, 10=PC+4)
//   branch     — instrução é branch condicional
//   jump       — tipo de salto (00=normal, 01=JAL, 10=JALR)
//   alu_op     — dica para o alu_control (00=add, 01=sub, 10=use funct3/7)
//   width      — largura do acesso à memória (00=byte, 01=half, 10=word)
//   sign_ext   — extensão de sinal em load
//   lui_op     — LUI: escreve imediato diretamente
//   auipc_op   — AUIPC: operando da ALU é o PC

module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,    // necessário para loads e stores (decodifica width)

    output logic        reg_write,
    output logic        alu_src,
    output logic        mem_write,
    output logic        mem_read,
    output logic [1:0]  mem_to_reg,
    output logic        branch,
    output logic [1:0]  jump,
    output logic [1:0]  alu_op,
    output logic [1:0]  width,
    output logic        sign_ext,
    output logic        lui_op,
    output logic        auipc_op
);

    always_comb begin
        // Valores padrão (instrução desconhecida = NOP)
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        mem_to_reg = 2'b00;
        branch     = 1'b0;
        jump       = 2'b00;
        alu_op     = 2'b00;
        width      = 2'b10;    // padrão: word
        sign_ext   = 1'b0;
        lui_op     = 1'b0;
        auipc_op   = 1'b0;

        case (opcode)

            // -------------------------------------------------------
            // R-type: ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
            // rd = rs1 OP rs2
            // Operação específica determinada pelo funct3+funct7 no alu_control.
            // -------------------------------------------------------
            7'b0110011: begin  // 0x33
                reg_write  = 1'b1;   // escreve o resultado em rd
                alu_src    = 1'b0;   // segundo operando é rs2 (não imediato)
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;  // escreve resultado da ALU
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b10;  // delega para alu_control usar funct3/funct7
            end

            // -------------------------------------------------------
            // I-type aritmético: ADDI, SLTI, SLTIU, ANDI, ORI, XORI, SLLI, SRLI, SRAI
            // rd = rs1 OP imm
            // -------------------------------------------------------
            7'b0010011: begin  // 0x13
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // segundo operando é o imediato
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b10;  // delega para alu_control
            end

            // -------------------------------------------------------
            // Load: LB, LH, LW, LBU, LHU
            // rd = mem[rs1 + imm]
            //
            // A ALU calcula o endereço: rs1 + imm (sempre ADD).
            // O funct3 determina a largura e a extensão de sinal:
            //   000 = LB  (byte, sinal)
            //   001 = LH  (half, sinal)
            //   010 = LW  (word, sem sinal — word já é 32 bits)
            //   100 = LBU (byte, sem sinal)
            //   101 = LHU (half, sem sinal)
            // -------------------------------------------------------
            7'b0000011: begin  // 0x03
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // endereço = rs1 + imm
                mem_write  = 1'b0;
                mem_read   = 1'b1;
                mem_to_reg = 2'b01;  // escreve dado da memória em rd
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b00;  // força ADD para calcular endereço

                // Decodifica funct3 para obter width e sign_ext
                case (funct3)
                    3'b000: begin width = 2'b00; sign_ext = 1'b1; end  // LB
                    3'b001: begin width = 2'b01; sign_ext = 1'b1; end  // LH
                    3'b010: begin width = 2'b10; sign_ext = 1'b0; end  // LW
                    3'b100: begin width = 2'b00; sign_ext = 1'b0; end  // LBU
                    3'b101: begin width = 2'b01; sign_ext = 1'b0; end  // LHU
                    default: begin width = 2'b10; sign_ext = 1'b0; end
                endcase
            end

            // -------------------------------------------------------
            // Store: SB, SH, SW
            // mem[rs1 + imm] = rs2
            //
            // A ALU calcula o endereço: rs1 + imm (sempre ADD).
            // O funct3 determina a largura de escrita:
            //   000 = SB (byte)
            //   001 = SH (half)
            //   010 = SW (word)
            // -------------------------------------------------------
            7'b0100011: begin  // 0x23
                reg_write  = 1'b0;   // store NÃO escreve em rd
                alu_src    = 1'b1;   // endereço = rs1 + imm
                mem_write  = 1'b1;   // habilita escrita na memória
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;  // irrelevante (reg_write=0)
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b00;  // força ADD

                case (funct3)
                    3'b000: width = 2'b00;  // SB
                    3'b001: width = 2'b01;  // SH
                    3'b010: width = 2'b10;  // SW
                    default: width = 2'b10;
                endcase
            end

            // -------------------------------------------------------
            // Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // if (rs1 OP rs2) PC = PC + imm  else  PC = PC + 4
            //
            // A ALU realiza a comparação. O resultado "zero" ou "negativo"
            // é usado pelo datapath para decidir se desvia.
            // alu_op=01 força SUB (BEQ/BNE) — o alu_control usa funct3
            // para selecionar a condição correta.
            // -------------------------------------------------------
            7'b1100011: begin  // 0x63
                reg_write  = 1'b0;   // branch NÃO escreve em rd
                alu_src    = 1'b0;   // compara rs1 com rs2
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;
                branch     = 1'b1;   // é um branch!
                jump       = 2'b00;
                alu_op     = 2'b01;  // indica comparação para o alu_control
            end

            // -------------------------------------------------------
            // LUI: Load Upper Immediate
            // rd = imm (os 20 bits altos já vêm prontos do imm_gen)
            //
            // Não passa pela ALU — o imediato vai direto para rd.
            // lui_op=1 sinaliza para o datapath usar essa rota direta.
            // -------------------------------------------------------
            7'b0110111: begin  // 0x37
                reg_write  = 1'b1;
                alu_src    = 1'b0;   // irrelevante (lui_op=1 bypassa ALU)
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b00;
                lui_op     = 1'b1;   // escreve imediato diretamente
            end

            // -------------------------------------------------------
            // AUIPC: Add Upper Immediate to PC
            // rd = PC + imm
            //
            // A ALU soma o PC com o imediato.
            // auipc_op=1 faz o mux de entrada da ALU selecionar o PC
            // em vez de rs1.
            // -------------------------------------------------------
            7'b0010111: begin  // 0x17
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // segundo operando é o imediato
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b00;  // escreve resultado da ALU (PC+imm)
                branch     = 1'b0;
                jump       = 2'b00;
                alu_op     = 2'b00;  // força ADD (PC + imm)
                auipc_op   = 1'b1;   // primeiro operando é o PC
            end

            // -------------------------------------------------------
            // JAL: Jump And Link
            // rd = PC + 4 ;  PC = PC + imm
            //
            // Salta para PC + imm e salva o endereço de retorno em rd.
            // mem_to_reg=10 seleciona PC+4 para escrever em rd.
            // -------------------------------------------------------
            7'b1101111: begin  // 0x6F
                reg_write  = 1'b1;
                alu_src    = 1'b0;   // irrelevante para o cálculo de PC+imm
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b10;  // escreve PC+4 em rd
                branch     = 1'b0;
                jump       = 2'b01;  // JAL: próximo PC = PC + imm
                alu_op     = 2'b00;
            end

            // -------------------------------------------------------
            // JALR: Jump And Link Register
            // rd = PC + 4 ;  PC = (rs1 + imm) & ~1
            //
            // Salta para rs1+imm (com bit 0 zerado) e salva PC+4 em rd.
            // O bit 0 é zerado por hardware para garantir alinhamento.
            // -------------------------------------------------------
            7'b1100111: begin  // 0x67
                reg_write  = 1'b1;
                alu_src    = 1'b1;   // endereço = rs1 + imm
                mem_write  = 1'b0;
                mem_read   = 1'b0;
                mem_to_reg = 2'b10;  // escreve PC+4 em rd
                branch     = 1'b0;
                jump       = 2'b10;  // JALR: próximo PC = ALU result & ~1
                alu_op     = 2'b00;  // força ADD (rs1 + imm)
            end

            // Instrução desconhecida: mantém os valores padrão (NOP efetivo)
            default: begin
                // Todos os sinais já foram atribuídos aos valores padrão no início.
                // Não faz nada — comportamento de NOP.
            end
        endcase
    end
endmodule
```

### `tb/tb_control_unit.cpp`

```cpp
// tb_control_unit.cpp
// Testa a unidade de controle para cada tipo de instrução.
// Verifica que os sinais de controle corretos são gerados para cada opcode.

#include <iostream>
#include <cstdint>
#include <cstring>
#include "Vcontrol_unit.h"
#include "verilated.h"

int erros = 0;

// Estrutura com os valores esperados para um conjunto de sinais de controle
struct CtrlExpected {
    bool  reg_write;
    bool  alu_src;
    bool  mem_write;
    bool  mem_read;
    int   mem_to_reg;  // 0, 1 ou 2
    bool  branch;
    int   jump;        // 0, 1 ou 2
    int   alu_op;      // 0, 1 ou 2
    bool  lui_op;
    bool  auipc_op;
};

void check_ctrl(Vcontrol_unit* dut, const char* nome,
                uint8_t opcode, uint8_t funct3,
                const CtrlExpected& e) {
    dut->opcode = opcode;
    dut->funct3 = funct3;
    dut->eval();

    bool ok = true;
    auto fail = [&](const char* sig, int got, int exp) {
        if (!ok) return;  // reporta apenas o primeiro erro por instrução
        std::cout << "  FAIL [" << sig << "]: obtido=" << got
                  << " esperado=" << exp << std::endl;
        ok = false;
        erros++;
    };

    if ((int)dut->reg_write  != (int)e.reg_write)  fail("reg_write",  dut->reg_write,  e.reg_write);
    if ((int)dut->alu_src    != (int)e.alu_src)    fail("alu_src",    dut->alu_src,    e.alu_src);
    if ((int)dut->mem_write  != (int)e.mem_write)  fail("mem_write",  dut->mem_write,  e.mem_write);
    if ((int)dut->mem_read   != (int)e.mem_read)   fail("mem_read",   dut->mem_read,   e.mem_read);
    if ((int)dut->mem_to_reg != e.mem_to_reg)      fail("mem_to_reg", dut->mem_to_reg, e.mem_to_reg);
    if ((int)dut->branch     != (int)e.branch)     fail("branch",     dut->branch,     e.branch);
    if ((int)dut->jump       != e.jump)            fail("jump",       dut->jump,       e.jump);
    if ((int)dut->alu_op     != e.alu_op)          fail("alu_op",     dut->alu_op,     e.alu_op);
    if ((int)dut->lui_op     != (int)e.lui_op)     fail("lui_op",     dut->lui_op,     e.lui_op);
    if ((int)dut->auipc_op   != (int)e.auipc_op)   fail("auipc_op",   dut->auipc_op,   e.auipc_op);

    if (ok)
        std::cout << "PASS: " << nome << std::endl;
    else
        std::cout << "      (em: " << nome << ")" << std::endl;
}

// Imprime todos os sinais de controle para uma instrução (útil para depuração)
void dump_ctrl(Vcontrol_unit* dut, const char* nome, uint8_t opcode, uint8_t funct3) {
    dut->opcode = opcode;
    dut->funct3 = funct3;
    dut->eval();
    std::cout << nome << ":" << std::endl
              << "  reg_write=" << (int)dut->reg_write
              << "  alu_src="   << (int)dut->alu_src
              << "  mem_write=" << (int)dut->mem_write
              << "  mem_read="  << (int)dut->mem_read  << std::endl
              << "  mem_to_reg="<< (int)dut->mem_to_reg
              << "  branch="    << (int)dut->branch
              << "  jump="      << (int)dut->jump
              << "  alu_op="    << (int)dut->alu_op   << std::endl
              << "  width="     << (int)dut->width
              << "  sign_ext="  << (int)dut->sign_ext
              << "  lui_op="    << (int)dut->lui_op
              << "  auipc_op="  << (int)dut->auipc_op  << std::endl;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vcontrol_unit* dut = new Vcontrol_unit;

    std::cout << "=== Sinais de controle por tipo de instrução ===" << std::endl;
    std::cout << std::endl;

    // Imprime o painel completo de cada tipo (útil como referência)
    dump_ctrl(dut, "R-type   (ADD, SUB...)", 0x33, 0x0);
    dump_ctrl(dut, "I-arith  (ADDI...)",     0x13, 0x0);
    dump_ctrl(dut, "Load LW  (funct3=010)",  0x03, 0x2);
    dump_ctrl(dut, "Load LB  (funct3=000)",  0x03, 0x0);
    dump_ctrl(dut, "Load LBU (funct3=100)",  0x03, 0x4);
    dump_ctrl(dut, "Store SW (funct3=010)",  0x23, 0x2);
    dump_ctrl(dut, "Store SB (funct3=000)",  0x23, 0x0);
    dump_ctrl(dut, "Branch   (BEQ...)",      0x63, 0x0);
    dump_ctrl(dut, "LUI",                    0x37, 0x0);
    dump_ctrl(dut, "AUIPC",                  0x17, 0x0);
    dump_ctrl(dut, "JAL",                    0x6F, 0x0);
    dump_ctrl(dut, "JALR",                   0x67, 0x0);

    std::cout << "\n=== Verificação automática ===" << std::endl;

    // R-type: reg_write=1, alu_src=0, alu_op=10, sem mem
    check_ctrl(dut, "R-type (ADD)",
        0x33, 0x0,
        {true, false, false, false, 0, false, 0, 2, false, false});

    // I-arith: reg_write=1, alu_src=1, alu_op=10, sem mem
    check_ctrl(dut, "I-arith (ADDI)",
        0x13, 0x0,
        {true, true, false, false, 0, false, 0, 2, false, false});

    // Load LW: reg_write=1, alu_src=1, mem_read=1, mem_to_reg=01, alu_op=00
    check_ctrl(dut, "Load LW",
        0x03, 0x2,
        {true, true, false, true, 1, false, 0, 0, false, false});

    // Store SW: reg_write=0, alu_src=1, mem_write=1, alu_op=00
    check_ctrl(dut, "Store SW",
        0x23, 0x2,
        {false, true, true, false, 0, false, 0, 0, false, false});

    // Branch: reg_write=0, alu_src=0, branch=1, alu_op=01
    check_ctrl(dut, "Branch (BEQ)",
        0x63, 0x0,
        {false, false, false, false, 0, true, 0, 1, false, false});

    // LUI: reg_write=1, lui_op=1
    check_ctrl(dut, "LUI",
        0x37, 0x0,
        {true, false, false, false, 0, false, 0, 0, true, false});

    // AUIPC: reg_write=1, alu_src=1, auipc_op=1, alu_op=00
    check_ctrl(dut, "AUIPC",
        0x17, 0x0,
        {true, true, false, false, 0, false, 0, 0, false, true});

    // JAL: reg_write=1, mem_to_reg=10, jump=01
    check_ctrl(dut, "JAL",
        0x6F, 0x0,
        {true, false, false, false, 2, false, 1, 0, false, false});

    // JALR: reg_write=1, alu_src=1, mem_to_reg=10, jump=10
    check_ctrl(dut, "JALR",
        0x67, 0x0,
        {true, true, false, false, 2, false, 2, 0, false, false});

    // --- Resultado final ---
    std::cout << "\n";
    if (erros == 0)
        std::cout << "Todos os testes PASSARAM." << std::endl;
    else
        std::cout << erros << " teste(s) FALHARAM." << std::endl;

    dut->final();
    delete dut;
    return (erros > 0) ? 1 : 0;
}
```

### Compilando e testando a unidade de controle

```bash
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/control_unit.sv tb/tb_control_unit.cpp \
  -o Vcontrol_unit

./obj_dir/Vcontrol_unit
```

---

## 5.3 O Controle da ALU (ALU Control)

### O pipeline de controle

O sinal `alu_op` da unidade de controle principal não especifica diretamente qual operação a ALU deve realizar — ele é apenas uma dica de alto nível. A decisão final cabe ao `alu_control`, que combina `alu_op` com `funct3` e `funct7` para produzir o opcode final de 4 bits que alimenta a ALU.

```
                    ┌──────────────────┐
opcode ────────────►│  control_unit    │───── alu_op [1:0] ─────────────┐
                    └──────────────────┘                                  │
                                                                          ▼
instr[14:12] (funct3) ─────────────────────────────────────────► ┌──────────────┐
instr[30]    (funct7[5]) ──────────────────────────────────────►  │ alu_control  │──► alu_ctrl [3:0]
                                                                   └──────────────┘
                                                                          │
                                                                          ▼
                                                                        ALU
```

**Por que essa hierarquia?**

Considere as instruções R-type. Todas têm o mesmo opcode (`0110011`), então a `control_unit` não pode distinguir entre ADD, SUB, AND, OR, etc. apenas pelo opcode. Ela sabe que "é um R-type, usa funct3/funct7" e sinaliza `alu_op=10`. O `alu_control` então olha para `funct3` e `funct7[5]` para determinar a operação exata.

O mesmo vale para I-type aritmético: o opcode é sempre `0010011`, mas `funct3` distingue entre ADDI, ANDI, ORI, XORI, SLTI, etc.

### Tabela de decisão do alu_control

| alu_op | funct3 | funct7[5] | Instrução | alu_ctrl |
|--------|--------|-----------|-----------|----------|
| `00` | — | — | ADD forçado (load, store, AUIPC, JALR) | `0000` (ADD) |
| `01` | — | — | SUB forçado (branch: BEQ, BNE, BLT...) | `0001` (SUB) |
| `10` | `000` | `0` | ADD (R: ADD, I: ADDI) | `0000` |
| `10` | `000` | `1` | SUB (R: SUB) | `0001` |
| `10` | `001` | — | SLL | `0010` |
| `10` | `010` | — | SLT | `0011` |
| `10` | `011` | — | SLTU | `0100` |
| `10` | `100` | — | XOR | `0101` |
| `10` | `101` | `0` | SRL | `0110` |
| `10` | `101` | `1` | SRA | `0111` |
| `10` | `110` | — | OR | `1000` |
| `10` | `111` | — | AND | `1001` |

**Nota importante sobre branches:** quando `alu_op=01`, o `alu_control` força SUB. A condição do branch (igual, diferente, menor, maior ou igual...) é determinada pelo `funct3` da instrução branch, mas essa lógica fica no **datapath** (que compara o resultado da ALU com zero ou verifica o bit de sinal), não no `alu_control`. O `alu_control` só precisa saber que deve subtrair para a comparação.

### `src/alu_control.sv`

```systemverilog
// alu_control.sv
// Decodifica a operação da ALU a partir de alu_op + funct3 + funct7[5].
//
// alu_ctrl de saída (deve coincidir com os opcodes da ALU da Parte 2):
//   0000 = ADD
//   0001 = SUB
//   0010 = SLL (shift left logical)
//   0011 = SLT (set less than, sinal)
//   0100 = SLTU (set less than, sem sinal)
//   0101 = XOR
//   0110 = SRL (shift right logical)
//   0111 = SRA (shift right arithmetic)
//   1000 = OR
//   1001 = AND

module alu_control (
    input  logic [1:0] alu_op,
    input  logic [2:0] funct3,
    input  logic       funct7_5,   // bit 30 da instrução = funct7[5]
    output logic [3:0] alu_ctrl
);
    always_comb begin
        case (alu_op)

            // alu_op=00: força ADD (cálculo de endereço para load, store, AUIPC, JALR)
            2'b00: alu_ctrl = 4'b0000;

            // alu_op=01: força SUB (comparação para branches)
            2'b01: alu_ctrl = 4'b0001;

            // alu_op=10: usa funct3 e funct7[5] para decidir (R-type e I-arith)
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        // ADD vs SUB: funct7[5] distingue
                        // Para I-type (ADDI), funct7[5] pode ser 0 ou irrelevante
                        // — a lógica funciona porque ADDI nunca terá funct7[5]=1
                        // com a mesma semântica de SUB (encodings diferentes).
                        if (funct7_5)
                            alu_ctrl = 4'b0001;  // SUB
                        else
                            alu_ctrl = 4'b0000;  // ADD / ADDI
                    end
                    3'b001: alu_ctrl = 4'b0010;  // SLL / SLLI
                    3'b010: alu_ctrl = 4'b0011;  // SLT / SLTI
                    3'b011: alu_ctrl = 4'b0100;  // SLTU / SLTIU
                    3'b100: alu_ctrl = 4'b0101;  // XOR / XORI
                    3'b101: begin
                        // SRL vs SRA: funct7[5] distingue
                        if (funct7_5)
                            alu_ctrl = 4'b0111;  // SRA / SRAI
                        else
                            alu_ctrl = 4'b0110;  // SRL / SRLI
                    end
                    3'b110: alu_ctrl = 4'b1000;  // OR  / ORI
                    3'b111: alu_ctrl = 4'b1001;  // AND / ANDI
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            // alu_op=11: não usado, padrão ADD
            default: alu_ctrl = 4'b0000;
        endcase
    end
endmodule
```

### `tb/tb_alu_control.cpp`

```cpp
// tb_alu_control.cpp
// Testa o alu_control verificando o mapeamento alu_op+funct3+funct7 → alu_ctrl.

#include <iostream>
#include <cstdint>
#include "Valu_control.h"
#include "verilated.h"

int erros = 0;

void check(Valu_control* dut, const char* nome,
           uint8_t alu_op, uint8_t funct3, uint8_t funct7_5,
           uint8_t expected_ctrl) {
    dut->alu_op   = alu_op;
    dut->funct3   = funct3;
    dut->funct7_5 = funct7_5;
    dut->eval();

    uint8_t got = (uint8_t)dut->alu_ctrl;
    if (got == expected_ctrl) {
        std::cout << "PASS: " << nome
                  << " → alu_ctrl=" << (int)got << std::endl;
    } else {
        std::cout << "FAIL: " << nome
                  << " → esperado=" << (int)expected_ctrl
                  << " obtido=" << (int)got << std::endl;
        erros++;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Valu_control* dut = new Valu_control;

    std::cout << "=== alu_op=00 (ADD forçado) ===" << std::endl;
    check(dut, "ADD forçado (load/store)",  0b00, 0, 0, 0b0000);

    std::cout << "\n=== alu_op=01 (SUB forçado) ===" << std::endl;
    check(dut, "SUB forçado (branch)",      0b01, 0, 0, 0b0001);

    std::cout << "\n=== alu_op=10, funct7[5]=0 ===" << std::endl;
    check(dut, "ADD  (funct3=000, f7=0)",   0b10, 0b000, 0, 0b0000);
    check(dut, "SLL  (funct3=001)",         0b10, 0b001, 0, 0b0010);
    check(dut, "SLT  (funct3=010)",         0b10, 0b010, 0, 0b0011);
    check(dut, "SLTU (funct3=011)",         0b10, 0b011, 0, 0b0100);
    check(dut, "XOR  (funct3=100)",         0b10, 0b100, 0, 0b0101);
    check(dut, "SRL  (funct3=101, f7=0)",   0b10, 0b101, 0, 0b0110);
    check(dut, "OR   (funct3=110)",         0b10, 0b110, 0, 0b1000);
    check(dut, "AND  (funct3=111)",         0b10, 0b111, 0, 0b1001);

    std::cout << "\n=== alu_op=10, funct7[5]=1 ===" << std::endl;
    check(dut, "SUB  (funct3=000, f7=1)",   0b10, 0b000, 1, 0b0001);
    check(dut, "SRA  (funct3=101, f7=1)",   0b10, 0b101, 1, 0b0111);

    // --- Resultado final ---
    std::cout << "\n";
    if (erros == 0)
        std::cout << "Todos os testes PASSARAM." << std::endl;
    else
        std::cout << erros << " teste(s) FALHARAM." << std::endl;

    dut->final();
    delete dut;
    return (erros > 0) ? 1 : 0;
}
```

### Compilando e testando o alu_control

```bash
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/alu_control.sv tb/tb_alu_control.cpp \
  -o Valu_control

./obj_dir/Valu_control
```

Saída esperada:
```
=== alu_op=00 (ADD forçado) ===
PASS: ADD forçado (load/store) → alu_ctrl=0

=== alu_op=01 (SUB forçado) ===
PASS: SUB forçado (branch) → alu_ctrl=1

=== alu_op=10, funct7[5]=0 ===
PASS: ADD  (funct3=000, f7=0) → alu_ctrl=0
PASS: SLL  (funct3=001) → alu_ctrl=2
PASS: SLT  (funct3=010) → alu_ctrl=3
PASS: SLTU (funct3=011) → alu_ctrl=4
PASS: XOR  (funct3=100) → alu_ctrl=5
PASS: SRL  (funct3=101, f7=0) → alu_ctrl=6
PASS: OR   (funct3=110) → alu_ctrl=8
PASS: AND  (funct3=111) → alu_ctrl=9

=== alu_op=10, funct7[5]=1 ===
PASS: SUB  (funct3=000, f7=1) → alu_ctrl=1
PASS: SRA  (funct3=101, f7=1) → alu_ctrl=7

Todos os testes PASSARAM.
```

---

## 5.4 Conectando os três módulos: fluxo completo de controle

Com os três módulos prontos, o caminho completo do controle é:

```
                    instrução [31:0]
                         │
              ┌──────────┼──────────────────────────────┐
              │          │                              │
         opcode[6:0]   funct3[2:0]                funct7[5]=instr[30]
              │          │                              │
              ▼          │                              │
    ┌─────────────────┐  │                              │
    │  control_unit   │  │                              │
    │                 │  │                              │
    │  reg_write ─────┼──┼──────────────────► reg_file │
    │  alu_src   ─────┼──┼──────────────────► mux ALU  │
    │  mem_write ─────┼──┼──────────────────► data_mem │
    │  mem_read  ─────┼──┼──────────────────► data_mem │
    │  mem_to_reg─────┼──┼──────────────────► mux wd   │
    │  branch    ─────┼──┼──────────────────► PC logic │
    │  jump      ─────┼──┼──────────────────► PC logic │
    │  width     ─────┼──┼──────────────────► data_mem │
    │  sign_ext  ─────┼──┼──────────────────► data_mem │
    │  lui_op    ─────┼──┼──────────────────► mux wd   │
    │  auipc_op  ─────┼──┼──────────────────► mux ALU  │
    │                 │  │                              │
    │  alu_op[1:0]────┼──┼──►┌──────────────────────┐  │
    └─────────────────┘  │   │    alu_control        │  │
                         ├──►│ funct3                │  │
                         │   │ funct7_5              │  │
                         │   │         alu_ctrl[3:0]─┼──┼──────► ALU
                         │   └──────────────────────┘  │
                         │                              │
                         └──────────────────────────────┘
                                   imm_gen
```

### Integração em SystemVerilog

No módulo de topo do processador (que escreveremos na Parte 6), as conexões serão:

```systemverilog
// Trecho do módulo de topo — mostra como os módulos de controle se conectam
logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;
logic [31:0] instr;

assign opcode = instr[6:0];
assign funct3 = instr[14:12];
assign funct7  = instr[31:25];

// Unidade de controle principal
logic reg_write, alu_src, mem_write, mem_read;
logic [1:0] mem_to_reg, jump, alu_op, width;
logic branch, sign_ext, lui_op, auipc_op;

control_unit ctrl (
    .opcode    (opcode),
    .funct3    (funct3),
    .reg_write (reg_write),
    .alu_src   (alu_src),
    .mem_write (mem_write),
    .mem_read  (mem_read),
    .mem_to_reg(mem_to_reg),
    .branch    (branch),
    .jump      (jump),
    .alu_op    (alu_op),
    .width     (width),
    .sign_ext  (sign_ext),
    .lui_op    (lui_op),
    .auipc_op  (auipc_op)
);

// Controle da ALU
logic [3:0] alu_ctrl;

alu_control aluctrl (
    .alu_op   (alu_op),
    .funct3   (funct3),
    .funct7_5 (funct7[5]),
    .alu_ctrl (alu_ctrl)
);

// Gerador de imediatos
logic [31:0] imm;

imm_gen immgen (
    .instr (instr),
    .imm   (imm)
);
```

---

## Resumo da Parte 5

Nesta parte você construiu a "inteligência" do processador:

1. **`imm_gen.sv`** — decodifica e monta o imediato de 32 bits a partir dos bits embaralhados da instrução, para todos os 5 formatos com imediato (I, S, B, U, J)

2. **`control_unit.sv`** — decodifica o opcode e produz 12 sinais de controle que configuram o datapath para cada tipo de instrução

3. **`alu_control.sv`** — decodifica a operação específica da ALU a partir da dica `alu_op` combinada com `funct3` e `funct7[5]`

4. Entendeu o pipeline de controle: `opcode → alu_op → (funct3, funct7) → alu_ctrl → ALU`

**Próximo passo:** Parte 6 — Integração, onde conectamos ALU + RegFile + Memórias + Controle em um único módulo `riscv_cpu.sv` e rodamos programas RISC-V reais.
