# Parte 2 — A Unidade Lógica e Aritmética (ALU)

> **Pré-requisito:** você já tem o ambiente Verilator instalado e sabe compilar um módulo simples (veja a Parte 1).

Esta parte constrói a ALU do zero, peça por peça. Começamos com o componente mais fundamental possível — o meio-somador de 1 bit — e chegamos até uma ALU completa de 32 bits capaz de executar todas as operações exigidas pelo conjunto de instruções RISC-V RV32I.

---

## Seção 1 — O Meio-Somador (Half-Adder)

### O que é um meio-somador?

Um meio-somador é o circuito digital mais simples capaz de somar dois bits. Ele recebe dois bits de entrada (`a` e `b`) e produz dois bits de saída:

- **`sum`** (soma): o bit de resultado da adição.
- **`carry`** (vai-um): o bit de "transporte" para a próxima posição de peso maior.

A tabela-verdade completa é:

| `a` | `b` | `sum` | `carry` |
|-----|-----|-------|---------|
|  0  |  0  |   0   |    0    |
|  0  |  1  |   1   |    0    |
|  1  |  0  |   1   |    0    |
|  1  |  1  |   0   |    1    |

Observando a tabela:

- `sum` é **1** apenas quando `a` e `b` são **diferentes** → isso é exatamente a operação XOR.
- `carry` é **1** apenas quando **ambos** são 1 → isso é exatamente a operação AND.

Portanto, as equações booleanas são:

```
sum   = a XOR b
carry = a AND b
```

Por que "meio" somador? Porque ele não tem entrada de carry (não consegue receber o carry de uma posição anterior). Para somar números com mais de 1 bit precisamos do somador completo (Seção 2).

### Implementação em SystemVerilog: `half_adder.sv`

```systemverilog
// half_adder.sv
// Meio-somador de 1 bit
// Entradas: a, b
// Saídas:   sum (soma), carry (vai-um)

module half_adder (
    input  logic a,
    input  logic b,
    output logic sum,
    output logic carry
);

    // sum  = a XOR b  (diferença sem considerar carry)
    // carry = a AND b  (vai-um gerado)
    assign sum   = a ^ b;
    assign carry = a & b;

endmodule
```

**Por que usamos `assign` (lógica combinacional)?**
Um somador não tem memória — o resultado muda imediatamente quando as entradas mudam. Não há clock, não há flip-flops. O `assign` cria um fio com uma expressão lógica contínua, o que mapeia diretamente para portas AND e XOR na síntese.

**Por que `logic` em vez de `wire` ou `reg`?**
Em SystemVerilog, `logic` é o tipo preferido para a maioria dos sinais. Ele unifica `wire` e `reg` do Verilog clássico, eliminando ambiguidade. Use `logic` por padrão.

### Testbench C++: `tb_half_adder.cpp`

O testbench instancia o módulo Verilator, aplica todas as 4 combinações de entrada e verifica se as saídas batem com os valores esperados.

```cpp
// tb_half_adder.cpp
// Testbench para o meio-somador

#include "Vhalf_adder.h"   // gerado pelo Verilator
#include "verilated.h"
#include <iostream>
#include <cstdint>

// Estrutura para um caso de teste
struct TestCase {
    uint8_t a;
    uint8_t b;
    uint8_t expected_sum;
    uint8_t expected_carry;
};

int main(int argc, char** argv) {
    // Inicializa o contexto do Verilator
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    // Instancia o módulo
    Vhalf_adder* dut = new Vhalf_adder(contextp);

    // Define todos os 4 casos de teste possíveis
    TestCase tests[] = {
        {0, 0, 0, 0},   // 0 + 0 = 0, carry = 0
        {0, 1, 1, 0},   // 0 + 1 = 1, carry = 0
        {1, 0, 1, 0},   // 1 + 0 = 1, carry = 0
        {1, 1, 0, 1},   // 1 + 1 = 0, carry = 1  (resultado 2 em binário = "10")
    };

    int num_tests = sizeof(tests) / sizeof(tests[0]);
    int passed    = 0;

    std::cout << "=== Testbench: Half-Adder ===" << std::endl;
    std::cout << std::endl;

    for (int i = 0; i < num_tests; i++) {
        // Aplica as entradas
        dut->a = tests[i].a;
        dut->b = tests[i].b;

        // Avalia o circuito (processa a lógica combinacional)
        dut->eval();

        // Verifica as saídas
        bool sum_ok   = (dut->sum   == tests[i].expected_sum);
        bool carry_ok = (dut->carry == tests[i].expected_carry);
        bool test_ok  = sum_ok && carry_ok;

        // Imprime resultado
        std::cout << "Teste " << i+1 << ": a=" << (int)tests[i].a
                  << " b=" << (int)tests[i].b
                  << "  sum=" << (int)dut->sum
                  << " (esperado=" << (int)tests[i].expected_sum << ")"
                  << "  carry=" << (int)dut->carry
                  << " (esperado=" << (int)tests[i].expected_carry << ")"
                  << "  [" << (test_ok ? "PASS" : "FAIL") << "]"
                  << std::endl;

        if (test_ok) passed++;
    }

    std::cout << std::endl;
    std::cout << "Resultado: " << passed << "/" << num_tests << " testes passaram." << std::endl;

    if (passed == num_tests) {
        std::cout << "STATUS: TODOS OS TESTES PASSARAM!" << std::endl;
    } else {
        std::cout << "STATUS: FALHA EM " << (num_tests - passed) << " TESTE(S)!" << std::endl;
    }

    // Limpeza
    dut->final();
    delete dut;
    delete contextp;

    return (passed == num_tests) ? 0 : 1;
}
```

### Como compilar com Verilator

Execute o comando abaixo no diretório onde estão os arquivos `half_adder.sv` e `tb_half_adder.cpp`:

```bash
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    half_adder.sv tb_half_adder.cpp -o Vhalf_adder
```

**Explicação de cada flag:**

| Flag | Significado |
|------|-------------|
| `--cc` | Gera código C++ (em vez de SystemC) |
| `--sv` | Habilita extensões SystemVerilog |
| `--exe` | Inclui o arquivo C++ como executável (não apenas biblioteca) |
| `--build` | Compila automaticamente após gerar o C++ |
| `--Mdir obj_dir` | Pasta de saída dos arquivos gerados |
| `-Wall` | Ativa todos os avisos (boa prática) |
| `-o Vhalf_adder` | Nome do executável final |

### Como executar

```bash
./obj_dir/Vhalf_adder
```

Saída esperada:

```
=== Testbench: Half-Adder ===

Teste 1: a=0 b=0  sum=0 (esperado=0)  carry=0 (esperado=0)  [PASS]
Teste 2: a=0 b=1  sum=1 (esperado=1)  carry=0 (esperado=0)  [PASS]
Teste 3: a=1 b=0  sum=1 (esperado=1)  carry=0 (esperado=0)  [PASS]
Teste 4: a=1 b=1  sum=0 (esperado=0)  carry=1 (esperado=1)  [PASS]

Resultado: 4/4 testes passaram.
STATUS: TODOS OS TESTES PASSARAM!
```

---

## Seção 2 — O Somador Completo (Full-Adder)

### O que é um somador completo?

O problema do meio-somador é que ele não aceita um carry de entrada. Para somar números com múltiplos bits, cada posição (exceto a menos significativa) pode receber um carry da posição anterior. O somador completo resolve isso adicionando uma terceira entrada: `cin` (carry-in).

Entradas: `a`, `b`, `cin`
Saídas: `sum`, `cout` (carry-out)

Tabela-verdade:

| `cin` | `a` | `b` | `sum` | `cout` |
|-------|-----|-----|-------|--------|
|   0   |  0  |  0  |   0   |    0   |
|   0   |  0  |  1  |   1   |    0   |
|   0   |  1  |  0  |   1   |    0   |
|   0   |  1  |  1  |   0   |    1   |
|   1   |  0  |  0  |   1   |    0   |
|   1   |  0  |  1  |   0   |    1   |
|   1   |  1  |  0  |   0   |    1   |
|   1   |  1  |  1  |   1   |    1   |

As equações booleanas são:

```
sum  = a XOR b XOR cin
cout = (a AND b) OR (cin AND (a XOR b))
```

A segunda equação expressa: "carry de saída existe se ambos a e b são 1, OU se o carry de entrada é 1 e pelo menos um de a/b é 1".

### Implementação em SystemVerilog: `full_adder.sv`

**Versão 1: usando dois meio-somadores (estrutural)**

Esta versão demonstra como reusar o módulo `half_adder`. É uma boa prática de design hierárquico.

```systemverilog
// full_adder.sv (versão estrutural com dois half-adders)

`include "half_adder.sv"   // inclui o módulo anterior

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);

    // Fios internos para conectar os dois meio-somadores
    logic sum1;    // soma parcial do primeiro HA
    logic carry1;  // carry do primeiro HA
    logic carry2;  // carry do segundo HA

    // Primeiro meio-somador: soma a e b
    half_adder ha1 (
        .a     (a),
        .b     (b),
        .sum   (sum1),
        .carry (carry1)
    );

    // Segundo meio-somador: soma a soma parcial com cin
    half_adder ha2 (
        .a     (sum1),
        .b     (cin),
        .sum   (sum),
        .carry (carry2)
    );

    // O carry de saída é 1 se qualquer um dos dois meio-somadores
    // gerou um carry. Nunca podem ser 1 ao mesmo tempo (por que?
    // porque se carry1=1, então sum1=0, logo carry2=0)
    assign cout = carry1 | carry2;

endmodule
```

**Versão 2: equações diretas (comportamental)**

Mais simples, o sintetizador gera a mesma estrutura de hardware:

```systemverilog
// full_adder.sv (versão comportamental)

module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));

endmodule
```

### Testbench C++: `tb_full_adder.cpp`

```cpp
// tb_full_adder.cpp
// Testbench para o somador completo — testa todas as 8 combinações

#include "Vfull_adder.h"
#include "verilated.h"
#include <iostream>
#include <cstdint>

struct TestCase {
    uint8_t a, b, cin;
    uint8_t expected_sum, expected_cout;
};

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    Vfull_adder* dut = new Vfull_adder(contextp);

    // Todas as 8 combinações (cin=0: 4 casos, cin=1: 4 casos)
    TestCase tests[] = {
        // cin=0
        {0, 0, 0,  0, 0},   // 0+0+0 = 0
        {0, 1, 0,  1, 0},   // 0+1+0 = 1
        {1, 0, 0,  1, 0},   // 1+0+0 = 1
        {1, 1, 0,  0, 1},   // 1+1+0 = 2 → sum=0, cout=1
        // cin=1
        {0, 0, 1,  1, 0},   // 0+0+1 = 1
        {0, 1, 1,  0, 1},   // 0+1+1 = 2 → sum=0, cout=1
        {1, 0, 1,  0, 1},   // 1+0+1 = 2 → sum=0, cout=1
        {1, 1, 1,  1, 1},   // 1+1+1 = 3 → sum=1, cout=1
    };

    int num_tests = sizeof(tests) / sizeof(tests[0]);
    int passed = 0;

    std::cout << "=== Testbench: Full-Adder ===" << std::endl;
    std::cout << std::endl;

    for (int i = 0; i < num_tests; i++) {
        dut->a   = tests[i].a;
        dut->b   = tests[i].b;
        dut->cin = tests[i].cin;
        dut->eval();

        bool ok = (dut->sum  == tests[i].expected_sum) &&
                  (dut->cout == tests[i].expected_cout);

        std::cout << "Teste " << i+1
                  << ": cin=" << (int)tests[i].cin
                  << " a="   << (int)tests[i].a
                  << " b="   << (int)tests[i].b
                  << "  sum=" << (int)dut->sum
                  << "(exp=" << (int)tests[i].expected_sum << ")"
                  << "  cout=" << (int)dut->cout
                  << "(exp=" << (int)tests[i].expected_cout << ")"
                  << "  [" << (ok ? "PASS" : "FAIL") << "]"
                  << std::endl;

        if (ok) passed++;
    }

    std::cout << std::endl;
    std::cout << "Resultado: " << passed << "/" << num_tests << " testes passaram." << std::endl;

    dut->final();
    delete dut;
    delete contextp;
    return (passed == num_tests) ? 0 : 1;
}
```

**Compilar e executar:**

```bash
# Se usar a versão estrutural, inclua ambos os arquivos:
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    half_adder.sv full_adder.sv tb_full_adder.cpp -o Vfull_adder

./obj_dir/Vfull_adder
```

---

## Seção 3 — Somador de 32 Bits

### O que é um ripple-carry adder?

Para somar números de 32 bits, precisamos de 32 somadores completos encadeados. O carry de saída de cada somador completo se torna o carry de entrada do próximo. Este encadeamento chama-se **ripple-carry adder** (somador de propagação de carry).

```
Bit 0:  FA(a[0], b[0], 0)         → sum[0], carry[0]
Bit 1:  FA(a[1], b[1], carry[0])  → sum[1], carry[1]
Bit 2:  FA(a[2], b[2], carry[1])  → sum[2], carry[2]
...
Bit 31: FA(a[31], b[31], carry[30]) → sum[31], carry[31]
```

O `carry[31]` final é o carry-out do somador de 32 bits (indica overflow em aritmética sem sinal).

**Limitação:** o ripple-carry é simples, mas lento. O atraso cresce linearmente com o número de bits porque cada carry deve "propagar" pelo circuito inteiro. Para uma CPU real, somadores mais rápidos (carry-lookahead, carry-select) são usados. Para aprendizado e para sínteses em FPGA com DSPs dedicados, o ripple-carry é perfeito.

### Implementação em SystemVerilog: `adder32.sv`

**Versão 1: usando generate (explícita e didática)**

```systemverilog
// adder32.sv (usando generate para instanciar 32 full-adders)

`include "full_adder.sv"

module adder32 (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        cin,
    output logic [31:0] sum,
    output logic        cout
);

    // Vetor de carries intermediários: c[0]=cin, c[32]=cout
    logic [32:0] c;

    // O carry de entrada do bit 0 é o cin externo
    assign c[0] = cin;

    // Gera 32 somadores completos
    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : gen_adder
            full_adder fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (c[i]),
                .sum  (sum[i]),
                .cout (c[i+1])
            );
        end
    endgenerate

    // O carry de saída final
    assign cout = c[32];

endmodule
```

O bloco `generate` com `genvar` cria instâncias repetidas automaticamente. O sintetizador expande isso em 32 full-adders independentes conectados em série pelos carries. O nome `gen_adder` é um rótulo obrigatório para blocos `generate` nomeados — ele permite referenciar instâncias individuais (ex: `gen_adder[5].fa`).

**Versão 2: usando o operador `+` (recomendada para projetos reais)**

```systemverilog
// adder32.sv (versão simples — deixa o sintetizador escolher a implementação)

module adder32 (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        cin,
    output logic [31:0] sum,
    output logic        cout
);

    // Usa 33 bits para capturar o carry de saída
    logic [32:0] result;

    always_comb begin
        result = {1'b0, a} + {1'b0, b} + {32'b0, cin};
    end

    assign sum  = result[31:0];
    assign cout = result[32];

endmodule
```

**Por que a versão 2 é preferida na prática?** O sintetizador (Quartus, Vivado, etc.) e o Verilator são altamente otimizados para inferir adicionadores eficientes a partir do operador `+`. Em FPGA, ele usa blocos DSP ou carry-chains dedicados, muito mais rápidos que um ripple-carry explícito. Para a nossa ALU de 32 bits, usaremos esta abordagem.

### Testbench C++: `tb_adder32.cpp`

```cpp
// tb_adder32.cpp
// Testbench para o somador de 32 bits

#include "Vadder32.h"
#include "verilated.h"
#include <iostream>
#include <cstdint>
#include <iomanip>   // para std::hex

struct TestCase {
    uint32_t a, b;
    uint8_t  cin;
    uint32_t expected_sum;
    uint8_t  expected_cout;
    const char* description;
};

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Vadder32* dut = new Vadder32(contextp);

    TestCase tests[] = {
        // a,            b,          cin,  expected_sum,  expected_cout, descrição
        {0x00000000, 0x00000000, 0,  0x00000000, 0, "0 + 0 = 0"},
        {0x00000001, 0x00000001, 0,  0x00000002, 0, "1 + 1 = 2"},
        {0xFFFFFFFF, 0x00000001, 0,  0x00000000, 1, "0xFFFFFFFF + 1 = overflow"},
        {0x00000064, 0x000000C8, 0,  0x0000012C, 0, "100 + 200 = 300"},
        {0x7FFFFFFF, 0x00000001, 0,  0x80000000, 0, "MAX_INT + 1 (overflow signed)"},
        {0x00000001, 0x00000001, 1,  0x00000003, 0, "1 + 1 + cin=1 = 3"},
    };

    int num_tests = sizeof(tests) / sizeof(tests[0]);
    int passed = 0;

    std::cout << "=== Testbench: Adder 32 bits ===" << std::endl;
    std::cout << std::endl;

    for (int i = 0; i < num_tests; i++) {
        dut->a   = tests[i].a;
        dut->b   = tests[i].b;
        dut->cin = tests[i].cin;
        dut->eval();

        bool sum_ok  = (dut->sum  == tests[i].expected_sum);
        bool cout_ok = (dut->cout == tests[i].expected_cout);
        bool ok      = sum_ok && cout_ok;

        std::cout << "Teste " << i+1 << " [" << tests[i].description << "]: ";
        std::cout << std::hex << std::uppercase;
        std::cout << "sum=0x" << dut->sum
                  << " (exp=0x" << tests[i].expected_sum << ")"
                  << " cout=" << (int)dut->cout
                  << " (exp=" << (int)tests[i].expected_cout << ")";
        std::cout << std::dec;
        std::cout << "  [" << (ok ? "PASS" : "FAIL") << "]" << std::endl;

        if (ok) passed++;
    }

    std::cout << std::endl;
    std::cout << "Resultado: " << passed << "/" << num_tests << " testes passaram." << std::endl;

    dut->final();
    delete dut;
    delete contextp;
    return (passed == num_tests) ? 0 : 1;
}
```

**Compilar e executar:**

```bash
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    adder32.sv tb_adder32.cpp -o Vadder32

./obj_dir/Vadder32
```

> **Observação sobre overflow:** `0xFFFFFFFF + 1` em 32 bits sem sinal resulta em `0x00000000` com carry=1. Este carry indica que o resultado não cabe em 32 bits. Na aritmética com sinal (complemento de dois), `0xFFFFFFFF` representa -1, então -1 + 1 = 0, que é correto.

---

## Seção 4 — A ALU Completa (10 Operações)

### Por que precisamos de uma ALU?

A ALU (Arithmetic Logic Unit) é o componente que realiza todas as computações de uma CPU. No RISC-V RV32I, as instruções do tipo R e I usam a ALU para computar resultados. O módulo de controle da CPU decide qual operação a ALU deve executar em cada ciclo.

### As 10 operações da ALU RISC-V

A tabela a seguir descreve cada operação que nossa ALU deve suportar, com o código de 4 bits (`alu_op`) que usaremos internamente:

| `alu_op` | Operação | Expressão | Instrução RISC-V |
|----------|----------|-----------|------------------|
| `0000`   | ADD      | `a + b`   | ADD, ADDI, LW, SW, AUIPC, JAL, JALR |
| `0001`   | SUB      | `a - b`   | SUB, BEQ, BNE, BLT, etc. |
| `0010`   | AND      | `a & b`   | AND, ANDI |
| `0011`   | OR       | `a \| b`  | OR, ORI |
| `0100`   | XOR      | `a ^ b`   | XOR, XORI |
| `0101`   | SLL      | `a << b[4:0]` | SLL, SLLI |
| `0110`   | SRL      | `a >> b[4:0]` | SRL, SRLI |
| `0111`   | SRA      | `$signed(a) >>> b[4:0]` | SRA, SRAI |
| `1000`   | SLT      | `($signed(a) < $signed(b)) ? 1 : 0` | SLT, SLTI |
| `1001`   | SLTU     | `(a < b) ? 1 : 0` | SLTU, SLTIU |

**Detalhes importantes de cada operação:**

**ADD / SUB:** ADD soma normalmente. SUB usa complemento de dois: `a - b = a + (~b) + 1`. Na prática, o operador `-` do SystemVerilog faz isso automaticamente.

**AND / OR / XOR:** Operações bit a bit padrão. Simples e diretas.

**SLL (Shift Left Logical):** Desloca `a` para a esquerda por `b[4:0]` posições. Usamos apenas os 5 bits menos significativos de `b` porque deslocar mais de 31 posições um número de 32 bits sempre resulta em zero — o campo `shamt` (shift amount) no RISC-V tem apenas 5 bits. Zeros preenchem à direita.

**SRL (Shift Right Logical):** Desloca para a direita, preenchendo com zeros à esquerda. Trata `a` como número sem sinal. O operador `>>` do SystemVerilog é sempre lógico para tipos `logic`.

**SRA (Shift Right Arithmetic):** Desloca para a direita, mas preserva o bit de sinal. Se `a` é negativo (bit 31 = 1), o deslocamento preenche com 1s à esquerda. O cast `$signed(a)` faz o SystemVerilog tratar `a` como número em complemento de dois; o operador `>>>` então realiza o shift aritmético.

**SLT (Set Less Than, com sinal):** Compara `a` e `b` como inteiros com sinal. Retorna 1 se `a < b`, 0 caso contrário. O resultado é sempre 0 ou 1 (não usa os 31 bits superiores). O cast `$signed()` é essencial aqui.

**SLTU (Set Less Than, sem sinal):** Igual ao SLT, mas trata ambos como sem sinal. Importante para comparações de endereços de memória.

### O flag `zero`

O flag `zero` é 1 quando `result == 0`. Para que serve?

A instrução `BEQ` (Branch if Equal) precisa saber se `a == b`. A CPU faz `a - b` na ALU e verifica se o resultado é zero. Se `result == 0`, então `a == b` e o branch é tomado. O flag zero evita que o bloco de controle precise comparar o resultado de 32 bits — é um sinal de 1 bit muito eficiente.

Similarmente, `BNE` (Branch if Not Equal) usa `zero == 0`.

### Implementação em SystemVerilog: `alu.sv`

```systemverilog
// alu.sv
// ALU de 32 bits para processador RISC-V RV32I
// Suporta 10 operações: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU

module alu (
    input  logic [31:0] a,         // operando A (geralmente rs1)
    input  logic [31:0] b,         // operando B (rs2 ou imediato)
    input  logic  [3:0] alu_op,    // código da operação (4 bits)
    output logic [31:0] result,    // resultado da operação
    output logic        zero       // flag: result == 0
);

    // Parâmetros para os códigos de operação
    // Usar parâmetros em vez de números mágicos torna o código legível
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // Lógica principal: always_comb garante que result é atualizado
    // imediatamente sempre que qualquer entrada muda
    always_comb begin
        // Valor padrão: evita latches (importante para síntese!)
        result = 32'b0;

        case (alu_op)
            // Adição simples
            ALU_ADD:  result = a + b;

            // Subtração: a - b em complemento de dois
            ALU_SUB:  result = a - b;

            // Operações lógicas bit a bit
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;

            // Shifts: b[4:0] limita o deslocamento a 0-31 posições
            ALU_SLL:  result = a << b[4:0];

            // Shift lógico: zeros preenchem à esquerda
            ALU_SRL:  result = a >> b[4:0];

            // Shift aritmético: bit de sinal propaga à esquerda
            // $signed() faz o SystemVerilog tratar 'a' como int com sinal
            ALU_SRA:  result = $signed(a) >>> b[4:0];

            // Set Less Than com sinal: retorna 1 se a < b (signed)
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;

            // Set Less Than sem sinal: retorna 1 se a < b (unsigned)
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;

            // Operação desconhecida: resultado indefinido
            default:  result = 32'hDEADBEEF;  // valor de depuração
        endcase
    end

    // Flag zero: 1 quando o resultado é zero
    // Usado por instruções de branch (BEQ, BNE, etc.)
    assign zero = (result == 32'b0) ? 1'b1 : 1'b0;

endmodule
```

**Decisões de design importantes:**

1. **`always_comb` em vez de `always @(*)`:** Em SystemVerilog, `always_comb` é mais seguro — ele garante sensibilidade a todas as variáveis usadas e avisa se a lógica pode criar latches involuntários.

2. **`result = 32'b0` como valor padrão:** Em `always_comb`, se um `case` não cobrir todos os valores, o sintetizador pode criar um latch (memória não intencional). Atribuir um valor padrão antes do `case` evita isso.

3. **`localparam` em vez de `parameter`:** `localparam` é local ao módulo (não pode ser sobrescrito externamente). Para constantes internas como códigos de operação, isso é o correto.

4. **`$signed()` para SRA e SLT:** O SystemVerilog trata `logic [31:0]` como sem sinal por padrão. O cast `$signed()` não muda os bits — apenas instrui o sintetizador a interpretar o valor como complemento de dois ao fazer a operação.

5. **`default: result = 32'hDEADBEEF`:** O valor `0xDEADBEEF` é um padrão clássico de debugging. Se você ver esse valor na simulação, sabe que um código de operação inválido foi enviado à ALU.

### Testbench C++: `tb_alu.cpp`

```cpp
// tb_alu.cpp
// Testbench completo para a ALU de 32 bits
// Testa todas as 10 operações com valores específicos

#include "Valu.h"
#include "verilated.h"
#include <iostream>
#include <cstdint>
#include <iomanip>
#include <string>

// Códigos de operação (devem bater com os localparam do alu.sv)
enum AluOp : uint8_t {
    ALU_ADD  = 0b0000,
    ALU_SUB  = 0b0001,
    ALU_AND  = 0b0010,
    ALU_OR   = 0b0011,
    ALU_XOR  = 0b0100,
    ALU_SLL  = 0b0101,
    ALU_SRL  = 0b0110,
    ALU_SRA  = 0b0111,
    ALU_SLT  = 0b1000,
    ALU_SLTU = 0b1001,
};

struct TestCase {
    AluOp    op;
    uint32_t a, b;
    uint32_t expected_result;
    uint8_t  expected_zero;
    std::string description;
};

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Valu* dut = new Valu(contextp);

    TestCase tests[] = {
        // ========== ADD ==========
        {ALU_ADD,  10,          20,          30,          0, "ADD: 10 + 20 = 30"},
        {ALU_ADD,  0xFFFFFFFF,  1,           0x00000000,  1, "ADD: 0xFFFFFFFF + 1 = 0 (overflow, zero=1)"},
        {ALU_ADD,  0,           0,           0,           1, "ADD: 0 + 0 = 0 (zero=1)"},

        // ========== SUB ==========
        {ALU_SUB,  50,          30,          20,          0, "SUB: 50 - 30 = 20"},
        {ALU_SUB,  30,          30,          0,           1, "SUB: 30 - 30 = 0 (zero=1, usado por BEQ)"},
        {ALU_SUB,  5,           10,          0xFFFFFFFB,  0, "SUB: 5 - 10 = -5 (0xFFFFFFFB em compl2)"},

        // ========== AND ==========
        {ALU_AND,  0xFF00FF00,  0x0F0F0F0F,  0x0F000F00,  0, "AND: 0xFF00FF00 & 0x0F0F0F0F"},
        {ALU_AND,  0xFFFFFFFF,  0x00000000,  0x00000000,  1, "AND: qualquer & 0 = 0"},

        // ========== OR ==========
        {ALU_OR,   0xF0F0F0F0,  0x0F0F0F0F,  0xFFFFFFFF,  0, "OR: 0xF0F0F0F0 | 0x0F0F0F0F = 0xFFFFFFFF"},

        // ========== XOR ==========
        {ALU_XOR,  0xAAAAAAAA,  0xAAAAAAAA,  0x00000000,  1, "XOR: x ^ x = 0"},
        {ALU_XOR,  0xAAAAAAAA,  0x55555555,  0xFFFFFFFF,  0, "XOR: 0xAAAA ^ 0x5555 = 0xFFFF"},

        // ========== SLL (Shift Left Logical) ==========
        {ALU_SLL,  0x00000001,  4,           0x00000010,  0, "SLL: 1 << 4 = 16"},
        {ALU_SLL,  0x00000001,  31,          0x80000000,  0, "SLL: 1 << 31 = 0x80000000"},
        {ALU_SLL,  0xFFFFFFFF,  1,           0xFFFFFFFE,  0, "SLL: 0xFFFF << 1 (MSB cai fora)"},

        // ========== SRL (Shift Right Logical) ==========
        {ALU_SRL,  0x80000000,  1,           0x40000000,  0, "SRL: 0x80000000 >> 1 = 0x40000000 (0 preenche)"},
        {ALU_SRL,  0xFFFFFFFF,  4,           0x0FFFFFFF,  0, "SRL: 0xFFFF >> 4 = 0x0FFFFFFF"},

        // ========== SRA (Shift Right Arithmetic) ==========
        {ALU_SRA,  0x80000000,  1,           0xC0000000,  0, "SRA: 0x80000000 >>> 1 = 0xC0000000 (sinal propaga)"},
        {ALU_SRA,  0xFFFFFFFF,  4,           0xFFFFFFFF,  0, "SRA: -1 >>> 4 = -1 (todos 1s)"},
        {ALU_SRA,  0x7FFFFFFF,  1,           0x3FFFFFFF,  0, "SRA: positivo >>> 1 = divide por 2"},

        // ========== SLT (Set Less Than, com sinal) ==========
        {ALU_SLT,  (uint32_t)(-1), 0,        1,           0, "SLT: -1 < 0 (signed) = 1"},
        {ALU_SLT,  0,           1,           1,           0, "SLT: 0 < 1 (signed) = 1"},
        {ALU_SLT,  1,           0,           0,           1, "SLT: 1 < 0 (signed) = 0 (zero=1!)"},
        {ALU_SLT,  5,           5,           0,           1, "SLT: 5 < 5 = 0 (iguais)"},

        // ========== SLTU (Set Less Than, sem sinal) ==========
        {ALU_SLTU, 0xFFFFFFFF,  0,           0,           1, "SLTU: 0xFFFF < 0 (unsigned) = 0 (0xFFFF é maior)"},
        {ALU_SLTU, 0,           0xFFFFFFFF,  1,           0, "SLTU: 0 < 0xFFFF (unsigned) = 1"},
        {ALU_SLTU, 100,         200,         1,           0, "SLTU: 100 < 200 = 1"},
    };

    int num_tests = sizeof(tests) / sizeof(tests[0]);
    int passed = 0;

    std::cout << "=== Testbench: ALU de 32 bits ===" << std::endl;
    std::cout << std::endl;

    for (int i = 0; i < num_tests; i++) {
        dut->a      = tests[i].a;
        dut->b      = tests[i].b;
        dut->alu_op = tests[i].op;
        dut->eval();

        bool result_ok = (dut->result == tests[i].expected_result);
        bool zero_ok   = (dut->zero   == tests[i].expected_zero);
        bool ok        = result_ok && zero_ok;

        std::cout << "Teste " << std::setw(2) << i+1
                  << " [" << (ok ? "PASS" : "FAIL") << "] "
                  << tests[i].description << std::endl;

        if (!ok) {
            std::cout << "        result: obtido=0x" << std::hex << dut->result
                      << " esperado=0x" << tests[i].expected_result << std::dec << std::endl;
            std::cout << "        zero:   obtido=" << (int)dut->zero
                      << " esperado=" << (int)tests[i].expected_zero << std::endl;
        }

        if (ok) passed++;
    }

    std::cout << std::endl;
    std::cout << "Resultado: " << passed << "/" << num_tests << " testes passaram." << std::endl;

    if (passed == num_tests) {
        std::cout << "STATUS: ALU 100% FUNCIONAL!" << std::endl;
    } else {
        std::cout << "STATUS: " << (num_tests - passed) << " FALHA(S) DETECTADA(S)!" << std::endl;
    }

    dut->final();
    delete dut;
    delete contextp;
    return (passed == num_tests) ? 0 : 1;
}
```

**Compilar e executar:**

```bash
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    alu.sv tb_alu.cpp -o Valu

./obj_dir/Valu
```

**Nota sobre o caso `SLT: 1 < 0 = 0` com `zero=1`:** Quando `result=0` (resultado do SLT foi 0, significando "não é menor"), o flag `zero` fica em 1. Isso parece contra-intuitivo mas está correto: o flag `zero` simplesmente indica se o resultado da ALU é o número zero — e o número 0 é exatamente o resultado de SLT quando `a >= b`.

---

## Seção 5 — O Controle da ALU (ALU Control)

### Por que separar o controle da ALU?

A ALU em si não sabe qual instrução está sendo executada. Ela recebe apenas `alu_op` (4 bits) e os operandos. Quem decide o valor de `alu_op` é o módulo **ALU Control**, que interpreta os campos da instrução.

Esta separação segue o princípio de responsabilidade única: a ALU faz cálculos, o controle interpreta instruções. Isso facilita modificações (ex: adicionar uma nova instrução) sem tocar na ALU.

### Como o RISC-V codifica operações

Cada instrução RISC-V de tipo R/I tem campos que identificam a operação:

- **`opcode` (bits 6:0):** identifica o tipo de instrução (R, I, S, B, U, J).
- **`funct3` (bits 14:12):** sub-operação dentro do tipo.
- **`funct7` (bits 31:25):** diferenciador adicional (principalmente bit 5).

A unidade de controle principal decodifica o `opcode` e gera um sinal de 2 bits chamado **`ALUOp`**:

| `ALUOp` | Significado |
|---------|-------------|
| `00`    | Forçar ADD (para LW, SW — endereçamento de memória) |
| `01`    | Forçar SUB (para branches — BEQ, BNE, etc.) |
| `10`    | Olhar funct3/funct7 (instruções tipo R e I aritmético) |

O módulo ALU Control recebe `ALUOp`, `funct3` e `funct7[5]` e produz o `alu_op` de 4 bits.

### Por que funct7[5] e não o funct7 inteiro?

O campo `funct7` tem 7 bits, mas no RV32I apenas o bit 5 é relevante para distinguir operações. Por exemplo:
- `funct7 = 0000000` → ADD (bit 5 = 0)
- `funct7 = 0100000` → SUB (bit 5 = 1)
- `funct7 = 0100000` → SRA (bit 5 = 1)

Passar apenas o bit 5 simplifica a interface sem perder informação.

### Tabela de decodificação completa

| `ALUOp` | `funct3` | `funct7[5]` | `alu_op` | Instrução |
|---------|----------|-------------|----------|-----------|
| `00`    | xxx      | x           | `0000`   | ADD (LW/SW) |
| `01`    | xxx      | x           | `0001`   | SUB (branches) |
| `10`    | `000`    | `0`         | `0000`   | ADD |
| `10`    | `000`    | `1`         | `0001`   | SUB |
| `10`    | `001`    | x           | `0101`   | SLL |
| `10`    | `010`    | x           | `1000`   | SLT |
| `10`    | `011`    | x           | `1001`   | SLTU |
| `10`    | `100`    | x           | `0100`   | XOR |
| `10`    | `101`    | `0`         | `0110`   | SRL |
| `10`    | `101`    | `1`         | `0111`   | SRA |
| `10`    | `110`    | x           | `0011`   | OR |
| `10`    | `111`    | x           | `0010`   | AND |

> **Nota sobre instruções I (imediatas):** ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI usam o mesmo `funct3` que as instruções R correspondentes. O `ALUOp=10` funciona para ambas — a diferença é que o operando B vem do imediato em vez do registrador, mas isso é resolvido em outro multiplexor (não no ALU Control).

**A exceção SRAI vs SRLI:** Ambas têm `funct3=101`. A diferença é `imm[10]` (equivalente ao `funct7[5]` no formato de instrução I imediata de shift). O ALU Control trata isso do mesmo jeito: usa o bit 5 do campo de 7 bits relevante.

### Implementação em SystemVerilog: `alu_control.sv`

```systemverilog
// alu_control.sv
// Decodifica funct3, funct7[5] e ALUOp para gerar o código de operação da ALU

module alu_control (
    input  logic [1:0] alu_op,     // da unidade de controle principal
    input  logic [2:0] funct3,     // bits 14:12 da instrução
    input  logic       funct7_5,   // bit 5 do funct7 (bit 30 da instrução)
    output logic [3:0] alu_ctrl    // código para a ALU
);

    always_comb begin
        // Valor padrão seguro — evita latch
        alu_ctrl = 4'b0000;  // ADD como padrão

        case (alu_op)

            // ALUOp=00: acesso à memória (LW, SW)
            // Sempre gera ADD para calcular endereço: base + offset
            2'b00: alu_ctrl = 4'b0000;  // ADD

            // ALUOp=01: instruções de branch
            // Sempre gera SUB para comparar: rs1 - rs2, verifica zero
            2'b01: alu_ctrl = 4'b0001;  // SUB

            // ALUOp=10: instruções R e I aritméticas/lógicas
            // Precisa olhar funct3 e funct7[5]
            2'b10: begin
                case (funct3)
                    // funct3=000: ADD ou SUB (diferenciados por funct7[5])
                    3'b000: begin
                        if (funct7_5 == 1'b1)
                            alu_ctrl = 4'b0001;  // SUB (funct7[5]=1)
                        else
                            alu_ctrl = 4'b0000;  // ADD (funct7[5]=0)
                    end

                    // funct3=001: SLL (shift left logical)
                    3'b001: alu_ctrl = 4'b0101;  // SLL

                    // funct3=010: SLT (set less than, signed)
                    3'b010: alu_ctrl = 4'b1000;  // SLT

                    // funct3=011: SLTU (set less than unsigned)
                    3'b011: alu_ctrl = 4'b1001;  // SLTU

                    // funct3=100: XOR
                    3'b100: alu_ctrl = 4'b0100;  // XOR

                    // funct3=101: SRL ou SRA (diferenciados por funct7[5])
                    3'b101: begin
                        if (funct7_5 == 1'b1)
                            alu_ctrl = 4'b0111;  // SRA (aritmético)
                        else
                            alu_ctrl = 4'b0110;  // SRL (lógico)
                    end

                    // funct3=110: OR
                    3'b110: alu_ctrl = 4'b0011;  // OR

                    // funct3=111: AND
                    3'b111: alu_ctrl = 4'b0010;  // AND

                    // Nunca deve acontecer no RV32I
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            // ALUOp=11: reservado (não usado no RV32I base)
            default: alu_ctrl = 4'b0000;

        endcase
    end

endmodule
```

### Como ADD e SUB são distinguidos

Este é o ponto mais sutil do decodificador. Ambas as instruções `ADD r1, r2, r3` e `SUB r1, r2, r3` têm:
- Mesmo `opcode` (0110011 — tipo R)
- Mesmo `funct3` (000)

A única diferença é o campo `funct7`:
- `ADD`: `funct7 = 0000000` → `funct7[5] = 0`
- `SUB`: `funct7 = 0100000` → `funct7[5] = 1`

Portanto, quando `ALUOp=10` e `funct3=000`:
- Se `funct7[5]=0` → `alu_ctrl = 0000` (ADD)
- Se `funct7[5]=1` → `alu_ctrl = 0001` (SUB)

**Importante:** para instruções I (como `ADDI`), `funct7[5]` é sempre 0 (os bits 31:25 fazem parte do imediato de 12 bits, não de um funct7 real). Por isso `ADDI` sempre gera ADD, o que está correto — não existe `SUBI` no RISC-V (usa-se `ADDI` com imediato negativo).

### Testbench para o ALU Control

```cpp
// tb_alu_control.cpp
// Verifica o decodificador ALU Control

#include "Valu_control.h"
#include "verilated.h"
#include <iostream>

struct TestCase {
    uint8_t alu_op;
    uint8_t funct3;
    uint8_t funct7_5;
    uint8_t expected_ctrl;
    const char* description;
};

int main(int argc, char** argv) {
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    Valu_control* dut = new Valu_control(contextp);

    TestCase tests[] = {
        // ALUOp=00: memória → sempre ADD
        {0b00, 0b000, 0, 0b0000, "LW/SW: ALUOp=00 → ADD"},
        {0b00, 0b101, 1, 0b0000, "LW/SW: ALUOp=00, funct3/7 ignorados → ADD"},

        // ALUOp=01: branches → sempre SUB
        {0b01, 0b000, 0, 0b0001, "BEQ: ALUOp=01 → SUB"},
        {0b01, 0b111, 1, 0b0001, "BLT: ALUOp=01, funct3/7 ignorados → SUB"},

        // ALUOp=10: R-type e I-type
        {0b10, 0b000, 0, 0b0000, "ADD:  funct3=000, funct7[5]=0"},
        {0b10, 0b000, 1, 0b0001, "SUB:  funct3=000, funct7[5]=1"},
        {0b10, 0b001, 0, 0b0101, "SLL:  funct3=001"},
        {0b10, 0b010, 0, 0b1000, "SLT:  funct3=010"},
        {0b10, 0b011, 0, 0b1001, "SLTU: funct3=011"},
        {0b10, 0b100, 0, 0b0100, "XOR:  funct3=100"},
        {0b10, 0b101, 0, 0b0110, "SRL:  funct3=101, funct7[5]=0"},
        {0b10, 0b101, 1, 0b0111, "SRA:  funct3=101, funct7[5]=1"},
        {0b10, 0b110, 0, 0b0011, "OR:   funct3=110"},
        {0b10, 0b111, 0, 0b0010, "AND:  funct3=111"},
    };

    int num_tests = sizeof(tests) / sizeof(tests[0]);
    int passed = 0;

    std::cout << "=== Testbench: ALU Control ===" << std::endl << std::endl;

    for (int i = 0; i < num_tests; i++) {
        dut->alu_op   = tests[i].alu_op;
        dut->funct3   = tests[i].funct3;
        dut->funct7_5 = tests[i].funct7_5;
        dut->eval();

        bool ok = (dut->alu_ctrl == tests[i].expected_ctrl);

        std::cout << "Teste " << i+1
                  << " [" << (ok ? "PASS" : "FAIL") << "] "
                  << tests[i].description;

        if (!ok) {
            std::cout << " | obtido=0b"
                      << (int)((dut->alu_ctrl >> 3) & 1)
                      << (int)((dut->alu_ctrl >> 2) & 1)
                      << (int)((dut->alu_ctrl >> 1) & 1)
                      << (int)((dut->alu_ctrl >> 0) & 1)
                      << " esperado=0b"
                      << (int)((tests[i].expected_ctrl >> 3) & 1)
                      << (int)((tests[i].expected_ctrl >> 2) & 1)
                      << (int)((tests[i].expected_ctrl >> 1) & 1)
                      << (int)((tests[i].expected_ctrl >> 0) & 1);
        }

        std::cout << std::endl;
        if (ok) passed++;
    }

    std::cout << std::endl;
    std::cout << "Resultado: " << passed << "/" << num_tests << " testes passaram." << std::endl;

    dut->final();
    delete dut;
    delete contextp;
    return (passed == num_tests) ? 0 : 1;
}
```

**Compilar e executar:**

```bash
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    alu_control.sv tb_alu_control.cpp -o Valu_control

./obj_dir/Valu_control
```

---

## Resumo da Parte 2

Construímos a ALU de baixo para cima:

```
half_adder (1 bit)
    ↓
full_adder (1 bit com carry-in)
    ↓
adder32 (32 bits via ripple-carry ou operador +)
    ↓
alu (10 operações: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
    ↓
alu_control (decodifica funct3/funct7/ALUOp → alu_op)
```

Na Parte 3, construiremos o banco de registradores, que fornece os operandos `a` e `b` para a ALU.

**Arquivos criados nesta parte:**
- `half_adder.sv` + `tb_half_adder.cpp`
- `full_adder.sv` + `tb_full_adder.cpp`
- `adder32.sv` + `tb_adder32.cpp`
- `alu.sv` + `tb_alu.cpp`
- `alu_control.sv` + `tb_alu_control.cpp`
