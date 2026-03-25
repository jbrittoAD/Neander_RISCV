# Parte 4 — Memória de Instruções e Memória de Dados (Arquitetura Harvard)

> **Pré-requisito:** você completou as Partes 1, 2 e 3 — o ambiente Verilator está configurado, a ALU funciona e o banco de registradores funciona.

Nesta parte construímos as duas memórias do processador Harvard: a memória de instruções (ROM) e a memória de dados (RAM). Ao final, teremos todos os blocos de armazenamento prontos para a integração.

---

## Por que duas memórias? Harvard vs Von Neumann

Para entender a escolha arquitetural, pense no que o processador precisa fazer em cada ciclo de clock no modelo single-cycle:

1. **Buscar a instrução** (instruction fetch): ler 32 bits da memória de instruções no endereço apontado pelo PC
2. **Acessar dado** (opcionalmente): instruções LW, LH, LB leem da memória de dados; SW, SH, SB escrevem na memória de dados

Em uma arquitetura **Von Neumann**, há um único barramento de memória. Se instrução e dado estão na mesma memória, as operações 1 e 2 concorrem pelo mesmo recurso. No modelo single-cycle mais simples, isso significa que não podemos fazer os dois no mesmo ciclo — precisaríamos de dois ciclos (um para fetch, outro para acesso a dado) ou de uma cache, ou de um banco de memória com duas portas independentes.

Na arquitetura **Harvard**, as memórias são fisicamente separadas e têm barramentos independentes:

```
        Harvard                          Von Neumann
  ┌─────────────────────┐          ┌─────────────────────┐
  │  CPU                │          │  CPU                │
  │  ┌───┐   ┌────────┐ │          │  ┌───┐              │
  │  │ PC│──►│ROM     │ │          │  │ PC│──┐           │
  │  └───┘   │(instrs)│ │          │  └───┘  │           │
  │          └────────┘ │          │         │ barramento │
  │          ┌────────┐ │          │  ┌──────┴──────────┐│
  │  ALU ───►│RAM     │ │          │  │   MEMÓRIA ÚNICA ││
  │          │(dados) │ │          │  │  (instrs+dados) ││
  │          └────────┘ │          │  └─────────────────┘│
  └─────────────────────┘          └─────────────────────┘
  Fetch e acesso a dado             Fetch OU acesso a dado
  acontecem simultaneamente         (não simultaneamente)
```

Para o processador single-cycle, Harvard é a escolha direta: cada componente tem sua função bem definida, a interface é simples e não há conflito de acesso.

**Trade-off:** Em hardware real, Harvard puro desperdiça espaço — a ROM para instruções e a RAM para dados são circuitos diferentes, e o espaço de endereçamento não é compartilhado. É por isso que processadores modernos usam caches separadas (L1-I e L1-D), que oferecem o benefício de banda Harvard no nível de cache mas têm memória DRAM unificada abaixo. Estudaremos Von Neumann na Parte 7.

---

## 4.1 Memória de Instruções (ROM)

### Decisões de projeto

Antes de escrever uma linha de código, precisamos tomar algumas decisões:

**Endereçamento:** o PC do RISC-V usa endereços de byte (cada byte tem seu próprio endereço). Instruções têm 4 bytes e devem estar alinhadas em múltiplos de 4. Portanto, os endereços de instrução são sempre 0, 4, 8, 12, ... — os dois bits menos significativos são sempre `00`. Podemos ignorar esses bits e endereçar por word.

**Tamanho:** 1024 words × 4 bytes = 4 KB. Suficiente para programas de teste com centenas de instruções.

**Leitura síncrona ou assíncrona?** Em hardware real, memórias são síncronas (leitura na borda do clock). No entanto, para o processador single-cycle, queremos que a instrução esteja disponível no mesmo ciclo em que o PC é apresentado — sem esperar uma borda de clock. Por isso usamos leitura **assíncrona** (combinacional): `assign instr = mem[addr];`.

**Somente leitura (ROM):** em simulação, carregamos o conteúdo com `$readmemh`. Em hardware real seria uma Flash ou uma BRAM inicializada. Escritas durante a simulação não são previstas.

### `src/instr_mem.sv`

```systemverilog
// instr_mem.sv
// Memória de instruções (ROM) — leitura combinacional (assíncrona).
// Carregada a partir de um arquivo .hex na inicialização da simulação.
//
// Interface:
//   addr  [31:0]  endereço de byte (os bits [1:0] são ignorados)
//   instr [31:0]  instrução lida (disponível combinacionalmente)

module instr_mem #(
    parameter DEPTH = 1024   // número de words (= 4 KB)
)(
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    // Array de words de 32 bits
    logic [31:0] mem [0:DEPTH-1];

    // Carrega o conteúdo do arquivo hex no início da simulação.
    // O arquivo deve ter uma word hexadecimal por linha (sem prefixo 0x).
    // $readmemh interpreta os valores como hexadecimal e os armazena
    // sequencialmente a partir do índice 0.
    initial begin
        $readmemh("program.hex", mem);
    end

    // Leitura combinacional: addr[31:2] converte endereço de byte em índice de word.
    // Exemplo: addr=0x0000_0000 → índice 0
    //          addr=0x0000_0004 → índice 1
    //          addr=0x0000_0008 → índice 2
    // Os bits addr[1:0] são descartados (sempre devem ser 00 para instruções válidas).
    assign instr = mem[addr[31:2]];

endmodule
```

**Por que `addr[31:2]`?**

O PC contém um endereço de byte. A instrução na posição 0 está no byte 0, mas também nos bytes 1, 2 e 3. A instrução na posição 1 (a segunda instrução) está nos bytes 4, 5, 6 e 7. Portanto, para converter endereço de byte em índice de array, dividimos por 4 — o que equivale a deslocar 2 bits para a direita, ou simplesmente selecionar os bits `[31:2]`.

```
Endereço   Bits [31:2]   Índice no array
   0x00       0              0   ← instrução 0
   0x04       1              1   ← instrução 1
   0x08       2              2   ← instrução 2
   0x0C       3              3   ← instrução 3
```

### Criando um arquivo de programa de teste

O formato `.hex` esperado pelo `$readmemh` é simples: uma word hexadecimal por linha, sem espaços ou prefixo `0x`. Cada linha representa uma instrução de 32 bits.

Crie o arquivo `programs/tiny.hex`:
```
deadbeef
cafebabe
12345678
00000013
```

- `deadbeef` = instrução 0 (endereço 0x00)
- `cafebabe` = instrução 1 (endereço 0x04)
- `12345678` = instrução 2 (endereço 0x08)
- `00000013` = `addi x0, x0, 0` — NOP padrão RISC-V (instrução 3, endereço 0x0C)

**Como interpretar as words:** o `$readmemh` armazena cada word exatamente como escrita no arquivo. `deadbeef` vira `32'hDEADBEEF` no índice 0.

### `tb/tb_instr_mem.cpp`

```cpp
// tb_instr_mem.cpp
// Testa a memória de instruções:
//   1. Carrega tiny.hex com 3 palavras conhecidas
//   2. Verifica que addr=0  retorna a primeira palavra
//   3. Verifica que addr=4  retorna a segunda palavra
//   4. Verifica que addr=8  retorna a terceira palavra
//   5. Verifica alinhamento: addr=1 e addr=2 retornam a mesma palavra que addr=0

#include <iostream>
#include <cstdint>
#include "Vinstr_mem.h"
#include "verilated.h"

// Macro de verificação: imprime PASS ou FAIL
#define CHECK(desc, got, expected) \
    do { \
        if ((uint32_t)(got) == (uint32_t)(expected)) { \
            std::cout << "PASS: " << desc << " = 0x" \
                      << std::hex << (uint32_t)(got) << std::dec << std::endl; \
        } else { \
            std::cout << "FAIL: " << desc \
                      << " esperado 0x" << std::hex << (uint32_t)(expected) \
                      << " obtido 0x"   << (uint32_t)(got) << std::dec << std::endl; \
            erros++; \
        } \
    } while(0)

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vinstr_mem* dut = new Vinstr_mem;
    int erros = 0;

    // --- Teste 1: leitura no endereço 0x00 ---
    dut->addr = 0x00000000;
    dut->eval();
    CHECK("addr=0x00 → instr[0]", dut->instr, 0xDEADBEEFu);

    // --- Teste 2: leitura no endereço 0x04 ---
    dut->addr = 0x00000004;
    dut->eval();
    CHECK("addr=0x04 → instr[1]", dut->instr, 0xCAFEBABEu);

    // --- Teste 3: leitura no endereço 0x08 ---
    dut->addr = 0x00000008;
    dut->eval();
    CHECK("addr=0x08 → instr[2]", dut->instr, 0x12345678u);

    // --- Teste 4: endereço desalinhado (bits [1:0] ignorados) ---
    // addr=0x01 → bits [31:2] = 0 → mesma word que addr=0x00
    dut->addr = 0x00000001;
    dut->eval();
    CHECK("addr=0x01 (desalinhado) → instr[0]", dut->instr, 0xDEADBEEFu);

    dut->addr = 0x00000006;
    dut->eval();
    CHECK("addr=0x06 (desalinhado) → instr[1]", dut->instr, 0xCAFEBABEu);

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

### Compilando e executando o teste da memória de instruções

```bash
# Copiar o hex de teste para o diretório de trabalho (Verilator busca no diretório atual)
cp programs/tiny.hex program.hex

verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/instr_mem.sv tb/tb_instr_mem.cpp \
  -o Vinstr_mem

./obj_dir/Vinstr_mem
```

Saída esperada:
```
PASS: addr=0x00 → instr[0] = 0xdeadbeef
PASS: addr=0x04 → instr[1] = 0xcafebabe
PASS: addr=0x08 → instr[2] = 0x12345678
PASS: addr=0x01 (desalinhado) → instr[0] = 0xdeadbeef
PASS: addr=0x06 (desalinhado) → instr[1] = 0xcafebabe

Todos os testes PASSARAM.
```

---

## 4.2 Memória de Dados (RAM)

### Decisões de projeto

A memória de dados é mais complexa porque o RISC-V suporta acessos de tamanhos diferentes:

| Instrução | Operação | Tamanho |
|-----------|----------|---------|
| `LB` / `LBU` | Load byte (com / sem sinal) | 8 bits |
| `LH` / `LHU` | Load half-word (com / sem sinal) | 16 bits |
| `LW` | Load word | 32 bits |
| `SB` | Store byte | 8 bits |
| `SH` | Store half-word | 16 bits |
| `SW` | Store word | 32 bits |

Para suportar acessos de 1, 2 ou 4 bytes no mesmo espaço de endereçamento, organizamos a memória como um **array de bytes** (8 bits por posição). Para ler/escrever words de 32 bits, acessamos 4 bytes consecutivos.

**Endianness — qual byte vai em qual endereço?**

O RISC-V é **little-endian**: o byte menos significativo está no endereço menor.

```
Endereço   Conteúdo (para 0xDEADBEEF em addr=0)
  0x00      0xEF   ← byte menos significativo (bits 7:0)
  0x01      0xBE   ← bits 15:8
  0x02      0xAD   ← bits 23:16
  0x03      0xDE   ← byte mais significativo (bits 31:24)
```

Portanto, ao escrever uma word de 32 bits:
- `mem[addr+0]` = `wd[7:0]`
- `mem[addr+1]` = `wd[15:8]`
- `mem[addr+2]` = `wd[23:16]`
- `mem[addr+3]` = `wd[31:24]`

E ao ler:
- `rd = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr+0]}`

**Escrita síncrona, leitura combinacional:** escrita no clock (para ser seguro em síntese). Leitura assíncrona (para o processador single-cycle funcionar em um único ciclo).

**Extensão de sinal em loads:** `LB` carrega 1 byte e o estende em sinal para 32 bits — o bit 7 do byte lido é replicado nos bits 31:8. `LBU` (unsigned) preenche com zeros. O mesmo vale para `LH` (sinal) e `LHU` (unsigned).

### `src/data_mem.sv`

```systemverilog
// data_mem.sv
// Memória de dados (RAM) — escrita síncrona, leitura combinacional.
// Suporta acessos de byte (8b), half-word (16b) e word (32b).
// Endianness: little-endian (byte menos significativo no endereço menor).
//
// Interface:
//   clk      clock
//   we       write enable (1 = escreve na borda de subida do clk)
//   width    largura do acesso: 00=byte, 01=half-word, 10=word
//   sign_ext extensão de sinal em load: 1=com sinal (LB,LH), 0=sem sinal (LBU,LHU)
//   addr     endereço de byte [31:0]
//   wd       write data [31:0]
//   rd       read data [31:0] (combinacional)

module data_mem #(
    parameter DEPTH = 1024   // número de bytes = 1 KB
)(
    input  logic        clk,
    input  logic        we,
    input  logic [1:0]  width,
    input  logic        sign_ext,
    input  logic [31:0] addr,
    input  logic [31:0] wd,
    output logic [31:0] rd
);
    // Array de bytes: cada posição armazena 8 bits
    logic [7:0] mem [0:DEPTH-1];

    // --- Escrita síncrona (clocked) ---
    // A escrita acontece na borda de subida do clock, apenas quando we=1.
    // Por que síncrona? Escrita assíncrona pode criar glitches em hardware real:
    // se addr ou wd mudam enquanto we=1, bytes errados podem ser escritos.
    // Sincronizar com o clock garante que escrevemos apenas quando os sinais
    // estão estáveis (after setup time).
    always_ff @(posedge clk) begin
        if (we) begin
            case (width)
                // SB: escreve apenas o byte menos significativo de wd
                2'b00: begin
                    mem[addr] <= wd[7:0];
                end

                // SH: escreve 2 bytes em little-endian
                2'b01: begin
                    mem[addr]   <= wd[7:0];   // byte baixo
                    mem[addr+1] <= wd[15:8];  // byte alto
                end

                // SW: escreve 4 bytes em little-endian
                2'b10: begin
                    mem[addr]   <= wd[7:0];    // bits  7:0
                    mem[addr+1] <= wd[15:8];   // bits 15:8
                    mem[addr+2] <= wd[23:16];  // bits 23:16
                    mem[addr+3] <= wd[31:24];  // bits 31:24
                end

                default: ; // não faz nada
            endcase
        end
    end

    // --- Leitura combinacional (assíncrona) ---
    // A leitura não depende do clock — assim que addr muda, rd é atualizado
    // imediatamente (dentro do mesmo ciclo). Isso é necessário para o
    // processador single-cycle funcionar.
    always_comb begin
        case (width)
            // LB / LBU: lê 1 byte
            2'b00: begin
                if (sign_ext)
                    // LB: replica o bit 7 (sinal) nos bits 31:8
                    rd = {{24{mem[addr][7]}}, mem[addr]};
                else
                    // LBU: preenche com zeros nos bits 31:8
                    rd = {24'b0, mem[addr]};
            end

            // LH / LHU: lê 2 bytes (little-endian: byte baixo em addr, alto em addr+1)
            2'b01: begin
                if (sign_ext)
                    // LH: replica o bit 7 do byte alto (= bit 15 da half-word)
                    rd = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};
                else
                    // LHU: preenche com zeros nos bits 31:16
                    rd = {16'b0, mem[addr+1], mem[addr]};
            end

            // LW: lê 4 bytes (little-endian)
            2'b10: begin
                rd = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
            end

            default: rd = 32'b0;
        endcase
    end

endmodule
```

### Extensão de sinal: por que é necessária?

Considere carregar o byte `0xFF` com `LB`:

```
Byte armazenado: 0xFF = 1111_1111 em binário

LB  (sign extend): 0xFF → 0xFFFF_FFFF = -1 em complemento de dois
LBU (zero extend): 0xFF → 0x0000_00FF = 255 sem sinal
```

Se você está trabalhando com `char` com sinal em C (que é um int8_t em RISC-V), `LB` é a instrução correta — o compilador a usa para preservar a semântica de sinal. Se está trabalhando com `unsigned char`, usa `LBU`. O hardware precisa suportar os dois.

A lógica de extensão no SystemVerilog:
```systemverilog
{{24{mem[addr][7]}}, mem[addr]}
```

- `mem[addr][7]` = bit 7 do byte lido (bit de sinal em complemento de dois)
- `{24{...}}` = replica esse bit 24 vezes
- O resultado: 24 cópias do bit de sinal concatenadas com o byte original = 32 bits

### `tb/tb_data_mem.cpp`

```cpp
// tb_data_mem.cpp
// Testa a memória de dados com a sequência completa de operações:
//   1. SW/LW:  word inteira
//   2. SH/LH:  half-word com e sem sinal
//   3. SB/LB:  byte com e sem sinal
//   4. Independência de endereços: escrita em um endereço não afeta outro

#include <iostream>
#include <cstdint>
#include "Vdata_mem.h"
#include "verilated.h"

// Constantes de width (iguais ao hardware)
static const uint8_t WIDTH_BYTE = 0b00;
static const uint8_t WIDTH_HALF = 0b01;
static const uint8_t WIDTH_WORD = 0b10;

int erros = 0;

// Gera uma borda de clock
void tick(Vdata_mem* dut) {
    dut->clk = 0; dut->eval();
    dut->clk = 1; dut->eval();
    dut->clk = 0; dut->eval();
}

// Escreve na memória (um ciclo com we=1)
void store(Vdata_mem* dut, uint32_t addr, uint32_t data, uint8_t width) {
    dut->we       = 1;
    dut->addr     = addr;
    dut->wd       = data;
    dut->width    = width;
    dut->sign_ext = 0;
    tick(dut);
    dut->we = 0;  // desabilita escrita após o ciclo
}

// Lê da memória (combinacional — não precisa de clock)
uint32_t load(Vdata_mem* dut, uint32_t addr, uint8_t width, bool sign_ext) {
    dut->we       = 0;
    dut->addr     = addr;
    dut->width    = width;
    dut->sign_ext = sign_ext ? 1 : 0;
    dut->eval();
    return (uint32_t)dut->rd;
}

void check(const char* desc, uint32_t got, uint32_t expected) {
    if (got == expected) {
        std::cout << "PASS: " << desc
                  << " = 0x" << std::hex << got << std::dec << std::endl;
    } else {
        std::cout << "FAIL: " << desc
                  << " esperado 0x" << std::hex << expected
                  << " obtido 0x"   << got << std::dec << std::endl;
        erros++;
    }
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vdata_mem* dut = new Vdata_mem;

    // Inicializa sinais
    dut->clk = 0; dut->we = 0; dut->addr = 0;
    dut->wd = 0; dut->width = WIDTH_WORD; dut->sign_ext = 0;
    dut->eval();

    std::cout << "=== Teste SW / LW ===" << std::endl;
    // Escreve 0xDEADBEEF no endereço 0
    store(dut, 0, 0xDEADBEEFu, WIDTH_WORD);
    // Lê de volta
    uint32_t lido = load(dut, 0, WIDTH_WORD, false);
    check("SW→LW addr=0", lido, 0xDEADBEEFu);

    std::cout << "\n=== Teste SH / LH / LHU ===" << std::endl;
    // Escreve half-word 0xABCD no endereço 4
    // Em little-endian: mem[4]=0xCD, mem[5]=0xAB
    store(dut, 4, 0x0000ABCDu, WIDTH_HALF);

    // LHU: zero extend → 0x0000ABCD
    lido = load(dut, 4, WIDTH_HALF, false);
    check("SH→LHU addr=4", lido, 0x0000ABCDu);

    // LH: sign extend (bit 15 = bit 7 de mem[5] = bit 7 de 0xAB = 1)
    // 0xABCD = 1010_1011_1100_1101 → bit 15 = 1 → extensão de sinal
    // resultado: 0xFFFF_ABCD
    lido = load(dut, 4, WIDTH_HALF, true);
    check("SH→LH  addr=4 (sign ext)", lido, 0xFFFFABCDu);

    // Escreve half-word 0x1234 (bit 15 = 0 → extensão de sinal = 0)
    store(dut, 8, 0x00001234u, WIDTH_HALF);
    lido = load(dut, 8, WIDTH_HALF, true);
    check("SH→LH  addr=8 (positivo, sem extensão negativa)", lido, 0x00001234u);

    std::cout << "\n=== Teste SB / LB / LBU ===" << std::endl;
    // Escreve byte 0xFF no endereço 16
    store(dut, 16, 0xFFu, WIDTH_BYTE);

    // LBU: zero extend → 0x000000FF = 255
    lido = load(dut, 16, WIDTH_BYTE, false);
    check("SB→LBU addr=16 (0xFF sem sinal = 255)", lido, 0x000000FFu);

    // LB: sign extend (bit 7 de 0xFF = 1) → 0xFFFFFFFF = -1
    lido = load(dut, 16, WIDTH_BYTE, true);
    check("SB→LB  addr=16 (0xFF com sinal = -1)", lido, 0xFFFFFFFFu);

    // Escreve byte 0x7F (bit 7 = 0 → sinal positivo)
    store(dut, 17, 0x7Fu, WIDTH_BYTE);
    lido = load(dut, 17, WIDTH_BYTE, true);
    check("SB→LB  addr=17 (0x7F com sinal = +127)", lido, 0x0000007Fu);

    std::cout << "\n=== Teste de independência de endereços ===" << std::endl;
    // Verifica que escrever no endereço 20 não altera o endereço 0
    store(dut, 20, 0xCAFEBABEu, WIDTH_WORD);
    lido = load(dut, 0, WIDTH_WORD, false);
    check("Endereço 0 inalterado após escrita em 20", lido, 0xDEADBEEFu);

    // Verifica endianness explicitamente: SW 0xAABBCCDD em addr=24
    // little-endian: mem[24]=0xDD, mem[25]=0xCC, mem[26]=0xBB, mem[27]=0xAA
    store(dut, 24, 0xAABBCCDDu, WIDTH_WORD);
    lido = load(dut, 24, WIDTH_BYTE, false);
    check("LBU addr=24 (byte baixo de 0xAABBCCDD = 0xDD)", lido, 0xDDu);
    lido = load(dut, 27, WIDTH_BYTE, false);
    check("LBU addr=27 (byte alto de 0xAABBCCDD = 0xAA)", lido, 0xAAu);

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

### Compilando e executando o teste da memória de dados

```bash
verilator --cc --sv --exe --build --Mdir obj_dir \
  -Wall -Wno-UNUSEDSIGNAL \
  src/data_mem.sv tb/tb_data_mem.cpp \
  -o Vdata_mem

./obj_dir/Vdata_mem
```

Saída esperada:
```
=== Teste SW / LW ===
PASS: SW→LW addr=0 = 0xdeadbeef

=== Teste SH / LH / LHU ===
PASS: SH→LHU addr=4 = 0xabcd
PASS: SH→LH  addr=4 (sign ext) = 0xffffabcd
PASS: SH→LH  addr=8 (positivo, sem extensão negativa) = 0x1234

=== Teste SB / LB / LBU ===
PASS: SB→LBU addr=16 (0xFF sem sinal = 255) = 0xff
PASS: SB→LB  addr=16 (0xFF com sinal = -1) = 0xffffffff
PASS: SB→LB  addr=17 (0x7F com sinal = +127) = 0x7f

=== Teste de independência de endereços ===
PASS: Endereço 0 inalterado após escrita em 20 = 0xdeadbeef
PASS: LBU addr=24 (byte baixo de 0xAABBCCDD = 0xDD) = 0xdd
PASS: LBU addr=27 (byte alto de 0xAABBCCDD = 0xAA) = 0xaa

Todos os testes PASSARAM.
```

---

## 4.3 O bin2hex.py — convertendo programas para o simulador

Quando escrevermos programas RISC-V reais, o fluxo de compilação produz um arquivo `.bin` (binário bruto). O `$readmemh` espera um arquivo `.hex` com uma word por linha. O script `bin2hex.py` faz essa conversão.

### `scripts/bin2hex.py`

```python
#!/usr/bin/env python3
"""
bin2hex.py — Converte arquivo .bin (saída do objcopy) para .hex (um word por linha).

Uso:
    python3 scripts/bin2hex.py programa.bin program.hex

O arquivo .hex gerado tem uma palavra de 32 bits por linha, em hexadecimal
minúsculo, sem prefixo 0x. Este formato é lido pelo $readmemh do SystemVerilog.

Exemplo de saída:
    00000013    ← addi x0, x0, 0  (NOP)
    00500093    ← addi x1, x0, 5
    00208133    ← add  x2, x1, x2
"""

import sys
import struct

def bin2hex(bin_path: str, hex_path: str) -> None:
    """
    Lê o arquivo binário e gera o arquivo hex correspondente.

    O arquivo .bin contém os bytes das instruções em ordem little-endian
    (como gerado pelo objcopy --output-target=binary para RISC-V).
    struct.unpack_from('<I', ...) interpreta 4 bytes como um inteiro de 32 bits
    em little-endian ('<' = little-endian, 'I' = unsigned int de 32 bits).
    """
    with open(bin_path, 'rb') as f:
        data = f.read()

    if len(data) == 0:
        print(f"Erro: arquivo '{bin_path}' está vazio.", file=sys.stderr)
        sys.exit(1)

    # Preenche com zeros para completar a última word (alinhamento em 4 bytes)
    remainder = len(data) % 4
    if remainder != 0:
        data += b'\x00' * (4 - remainder)

    num_words = len(data) // 4
    print(f"  {len(data)} bytes → {num_words} words de 32 bits", file=sys.stderr)

    with open(hex_path, 'w') as f:
        for i in range(0, len(data), 4):
            # '<I' = little-endian unsigned int 32-bit
            word = struct.unpack_from('<I', data, i)[0]
            f.write(f'{word:08x}\n')

    print(f"  Escrito: '{hex_path}'", file=sys.stderr)


def main():
    if len(sys.argv) != 3:
        print("Uso: bin2hex.py <entrada.bin> <saída.hex>", file=sys.stderr)
        print("Exemplo: bin2hex.py programa.bin program.hex", file=sys.stderr)
        sys.exit(1)

    bin_path = sys.argv[1]
    hex_path = sys.argv[2]

    try:
        bin2hex(bin_path, hex_path)
    except FileNotFoundError as e:
        print(f"Erro: arquivo não encontrado: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
```

### Fluxo completo: assembly → hex → simulação

```bash
# 1. Escreva um programa assembly em programs/soma.s
cat > programs/soma.s << 'EOF'
.text
.global _start
_start:
    addi x1, x0, 10    # x1 = 10
    addi x2, x0, 20    # x2 = 20
    add  x3, x1, x2    # x3 = x1 + x2 = 30
loop:
    j loop              # loop infinito (mantém o processador ocupado)
EOF

# 2. Monta o arquivo assembly em ELF
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 \
  -o programs/soma.o programs/soma.s

# 3. Liga (link) gerando ELF com endereço base 0x00000000
riscv64-unknown-elf-ld -m elf32lriscv \
  -Ttext=0x00000000 \
  -o programs/soma.elf programs/soma.o

# 4. Extrai o binário puro (apenas as instruções, sem cabeçalho ELF)
riscv64-unknown-elf-objcopy \
  --output-target=binary \
  programs/soma.elf programs/soma.bin

# 5. Converte para .hex
python3 scripts/bin2hex.py programs/soma.bin program.hex

# 6. Veja o resultado (opcional)
cat program.hex
```

Saída do `cat program.hex` (valores aproximados — dependem do assembler):
```
00a00093
01400113
00208133
0000006f
```

### Verificando as instruções geradas

Para inspecionar o que foi gerado e confirmar que está correto:

```bash
riscv64-unknown-elf-objdump -d programs/soma.elf
```

Saída:
```
programs/soma.elf:     file format elf32-littleriscv

Disassembly of section .text:

00000000 <_start>:
   0:   00a00093    addi    x1,x0,10
   4:   01400113    addi    x2,x0,20
   8:   00208133    add     x3,x1,x2

0000000c <loop>:
   c:   0000006f    jal     x0,c <loop>
```

As words no `.hex` devem coincidir com os valores da coluna da esquerda (após o endereço).

---

## Resumo da Parte 4

Nesta parte você:

1. Entendeu por que Harvard é a escolha natural para processadores single-cycle
2. Implementou `instr_mem.sv` — ROM com leitura combinacional e endereçamento por word
3. Implementou `data_mem.sv` — RAM com byte-array, little-endian, leitura/escrita de byte, half-word e word, com extensão de sinal
4. Testou ambas as memórias com testbenches C++ detalhados
5. Criou o script `bin2hex.py` para converter programas RISC-V para o formato `.hex`

**Próximo passo:** Parte 5 — o Gerador de Imediatos e a Unidade de Controle, onde construímos a lógica que decodifica cada instrução e gera os sinais que configuram o datapath.
