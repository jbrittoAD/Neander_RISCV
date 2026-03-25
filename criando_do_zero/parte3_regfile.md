# Parte 3 — O Banco de Registradores (Register File)

> **Pré-requisito:** você completou a Parte 2 e tem a ALU funcionando.

O banco de registradores é o conjunto de memória ultra-rápida dentro da CPU. No RISC-V, toda instrução aritmética lê seus operandos do banco de registradores e escreve o resultado de volta nele. Entender sua estrutura é essencial para qualquer implementação de processador.

---

## Seção 1 — O Banco de Registradores RISC-V

### Estrutura básica

O RISC-V RV32I define **32 registradores de 32 bits** cada, numerados de `x0` a `x31`. Isso totaliza `32 × 32 = 1024 bits = 128 bytes` de armazenamento. Fisicamente, em um chip real, esses registradores são implementados como células SRAM de acesso extremamente rápido (tipicamente 1 ciclo de clock).

Para endereçar 32 registradores, precisamos de `log2(32) = 5 bits`. Por isso os campos `rs1`, `rs2` e `rd` nas instruções RISC-V têm exatamente 5 bits cada.

### A regra especial de x0

`x0` é **hardwired to zero** ("ligado rigidamente ao zero"). Isso significa:

- **Leitura:** qualquer leitura de `x0` retorna sempre `0x00000000`, independentemente de qualquer escrita prévia.
- **Escrita:** qualquer tentativa de escrever em `x0` é **silenciosamente ignorada**. O valor de `x0` nunca muda.

**Por que isso é útil?**

O zero é uma constante extremamente comum em computação. Com `x0` hardwired, você pode:

```assembly
addi x1, x0, 42     # x1 = 0 + 42 = 42  (carregar constante)
add  x2, x1, x0     # x2 = x1 + 0 = x1  (mover valor)
sub  x3, x0, x1     # x3 = 0 - x1 = -x1 (negar)
beq  x1, x0, label  # branch se x1 == 0
sw   x1, 0(x0)      # store no endereço 0
```

Sem `x0`, precisaríamos de instrução especial `MOV` e `NEG`. Com `x0`, o RISC-V mantém o conjunto de instruções pequeno.

### Portas do banco de registradores

O banco tem **duas portas de leitura** e **uma porta de escrita**:

```
        ┌─────────────────┐
rs1[4:0]│→               →│rd1[31:0]   (leitura 1, combinacional)
rs2[4:0]│→  Register     →│rd2[31:0]   (leitura 2, combinacional)
        │   File          │
  rd[4:0]│→  32 × 32 bits │
  wd[31:0]│→               │
        │                 │
    clk ─┤                 │
     we ─┤ (write enable)  │
        └─────────────────┘
```

**Por que duas portas de leitura?**

A maioria das instruções precisa de dois operandos simultaneamente. Uma instrução `ADD x1, x2, x3` precisa ler `x2` e `x3` no mesmo ciclo. Se o banco tivesse apenas uma porta de leitura, levaria dois ciclos só para buscar os operandos, dobrando o tempo de execução.

**Por que uma porta de escrita?**

Em um processador single-cycle simples, cada instrução produz no máximo um resultado. Duas portas de escrita seriam desperdício de área de silício. Processadores superescalares (que executam múltiplas instruções por ciclo) têm múltiplas portas de escrita, mas para o nosso RV32I single-cycle, uma basta.

**Por que leitura é combinacional (assíncrona) mas escrita é síncrona?**

Veremos isso em detalhe na Seção 4. Por enquanto: a leitura deve estar disponível no mesmo ciclo que o endereço chega (para o processador single-cycle funcionar), então ela não pode esperar pela borda do clock.

### Tabela de nomes ABI (Application Binary Interface)

O RISC-V define nomes "amigáveis" para os registradores, usados pela convenção de chamada de funções. O compilador e o programador assembly usam esses nomes:

| Número | Nome ABI | Uso convencional | Salvo por quem |
|--------|----------|------------------|----------------|
| x0     | zero     | Constante zero (hardwired) | N/A |
| x1     | ra       | Return Address (endereço de retorno) | Caller |
| x2     | sp       | Stack Pointer (ponteiro de pilha) | Callee |
| x3     | gp       | Global Pointer (dados globais) | — |
| x4     | tp       | Thread Pointer (dados de thread) | — |
| x5     | t0       | Temporário / link alternativo | Caller |
| x6     | t1       | Temporário | Caller |
| x7     | t2       | Temporário | Caller |
| x8     | s0/fp    | Saved register / Frame Pointer | Callee |
| x9     | s1       | Saved register | Callee |
| x10    | a0       | Argumento 0 / valor de retorno | Caller |
| x11    | a1       | Argumento 1 / valor de retorno 2 | Caller |
| x12    | a2       | Argumento 2 | Caller |
| x13    | a3       | Argumento 3 | Caller |
| x14    | a4       | Argumento 4 | Caller |
| x15    | a5       | Argumento 5 | Caller |
| x16    | a6       | Argumento 6 | Caller |
| x17    | a7       | Argumento 7 | Caller |
| x18    | s2       | Saved register | Callee |
| x19    | s3       | Saved register | Callee |
| x20    | s4       | Saved register | Callee |
| x21    | s5       | Saved register | Callee |
| x22    | s6       | Saved register | Callee |
| x23    | s7       | Saved register | Callee |
| x24    | s8       | Saved register | Callee |
| x25    | s9       | Saved register | Callee |
| x26    | s10      | Saved register | Callee |
| x27    | s11      | Saved register | Callee |
| x28    | t3       | Temporário | Caller |
| x29    | t4       | Temporário | Caller |
| x30    | t5       | Temporário | Caller |
| x31    | t6       | Temporário | Caller |

**Caller-saved vs Callee-saved:**
- **Caller-saved (t0-t6, a0-a7):** Se uma função A chama outra função B, e A quer preservar t0, A deve salvar t0 na pilha antes de chamar B (porque B pode modificar t0 livremente).
- **Callee-saved (s0-s11, sp):** Se a função B usa s0, B deve salvar e restaurar s0. Quando B retorna, s0 tem o mesmo valor que tinha quando B foi chamada.

Para o hardware do banco de registradores, essa convenção não importa — todos os 32 registradores se comportam da mesma forma em hardware (exceto x0). A convenção é apenas um contrato entre o compilador e o programador.

---

## Seção 2 — Implementação em SystemVerilog

### Análise do módulo

Antes de ver o código, vamos detalhar cada sinal:

**Entradas:**
- `clk`: clock do sistema (a escrita acontece na borda de subida)
- `we`: write enable — quando 0, ignora qualquer tentativa de escrita; quando 1, escreve `wd` no registrador `rd` na próxima borda de subida
- `rs1[4:0]`: índice do registrador fonte 1 (Read Source 1) — qual registrador ler para `rd1`
- `rs2[4:0]`: índice do registrador fonte 2 (Read Source 2) — qual registrador ler para `rd2`
- `rd[4:0]`: índice do registrador destino (Register Destination) — onde escrever
- `wd[31:0]`: write data — dado a ser escrito no registrador `rd`

**Saídas:**
- `rd1[31:0]`: read data 1 — conteúdo do registrador `rs1`
- `rd2[31:0]`: read data 2 — conteúdo do registrador `rs2`

### Implementação: `register_file.sv`

```systemverilog
// register_file.sv
// Banco de registradores RISC-V RV32I
// - 32 registradores de 32 bits (x0 a x31)
// - x0 hardwired to zero
// - 2 portas de leitura combinacional (assíncrona)
// - 1 porta de escrita síncrona (borda de subida do clock)

module register_file (
    // Controle
    input  logic        clk,    // clock (escrita na borda de subida)
    input  logic        we,     // write enable

    // Porta de leitura 1
    input  logic [4:0]  rs1,    // endereço do registrador fonte 1
    output logic [31:0] rd1,    // dado lido do registrador rs1

    // Porta de leitura 2
    input  logic [4:0]  rs2,    // endereço do registrador fonte 2
    output logic [31:0] rd2,    // dado lido do registrador rs2

    // Porta de escrita
    input  logic [4:0]  rd,     // endereço do registrador destino
    input  logic [31:0] wd      // dado a ser escrito
);

    // Array de 32 registradores de 32 bits
    // regs[0] corresponde a x0, regs[31] a x31
    logic [31:0] regs [0:31];

    // ----------------------------------------------------------------
    // ESCRITA SÍNCRONA
    // ----------------------------------------------------------------
    // A escrita acontece na borda de subida do clock.
    // Condições para escrever:
    //   1. we == 1 (write enable ativo)
    //   2. rd != 0 (não escreve em x0 — guarda do hardwired zero)
    // ----------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (we && (rd != 5'b00000)) begin
            regs[rd] <= wd;
        end
        // Se we==0 ou rd==0: não faz nada (os flip-flops mantêm seus valores)
    end

    // ----------------------------------------------------------------
    // LEITURA COMBINACIONAL (ASSÍNCRONA)
    // ----------------------------------------------------------------
    // As leituras são instantâneas — não dependem do clock.
    // Usamos assign com condição ternária para implementar o
    // hardwired zero: se rs1==0, retorna 0 independentemente de regs[0].
    //
    // Por que não simplesmente deixar regs[0] ser sempre 0?
    // Porque o always_ff já garante que regs[0] NUNCA é escrito,
    // mas na inicialização do simulador regs[0] pode ter valor indefinido (X).
    // A condição ternária garante 0 mesmo nesse caso.
    // ----------------------------------------------------------------
    assign rd1 = (rs1 == 5'b00000) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'b00000) ? 32'b0 : regs[rs2];

endmodule
```

### Decisões de design detalhadas

**1. `always_ff` para escrita:**

`always_ff` é a construção SystemVerilog para flip-flops. Diferente de `always_comb`, ele é sensível apenas ao `posedge clk`. O operador `<=` (non-blocking assignment) dentro de `always_ff` é obrigatório: ele garante que todas as atualizações de flip-flops dentro do mesmo bloco acontecem simultaneamente (não sequencialmente), o que espelha o comportamento real do hardware.

Se usássemos `=` (blocking assignment) aqui, causaríamos um race condition no simulador e comportamento inesperado na síntese.

**2. Guarda `rd != 5'b00000` na escrita:**

Poderíamos deixar `regs[0]` ser escrito e depois forçar a leitura a retornar 0. Mas a abordagem mais limpa e sintetizável é nunca deixar o hardware tentar modificar `regs[0]`. Isso simplifica o entendimento: `regs[0]` literalmente nunca muda.

**3. Condição ternária na leitura:**

```systemverilog
assign rd1 = (rs1 == 5'b00000) ? 32'b0 : regs[rs1];
```

Esta linha é equivalente a um multiplexor 2:1 de 32 bits. O sintetizador gera exatamente isso: um mux selecionado pelo sinal `(rs1 == 0)`. O custo em área é mínimo (32 muxes de 2:1).

**4. `logic [31:0] regs [0:31]` — a sintaxe do array:**

Em SystemVerilog, `logic [31:0] regs [0:31]` declara um array de 32 elementos, cada um com 32 bits. A dimensão `[31:0]` é a dimensão dos bits (bit-width), e `[0:31]` é a dimensão do array (índice). Note que os colchetes ficam em lados diferentes do nome.

Alternativamente, `logic [31:0] regs [32]` é equivalente em SystemVerilog moderno (os índices vão de 0 a 31 implicitamente).

---

## Seção 3 — Testbench Detalhado

O testbench de um módulo síncrono (que tem clock) é mais elaborado que o da ALU. Precisamos gerar o clock manualmente e aplicar as entradas respeitando a temporização.

### Estratégia de temporização

Para um flip-flop sensível à borda de subida (`posedge clk`), a regra de ouro é:

1. **Aplique as entradas na borda de descida** (ou algum tempo depois da descida).
2. **Leia as saídas após a borda de subida** seguinte.

Isso garante que os dados chegam estáveis antes da borda de captura, respeitando os tempos de setup dos flip-flops.

No Verilator, controlamos o tempo com `contextp->timeInc(1)` e chamadas a `eval()`. O clock é alternado manualmente.

### Testbench C++: `tb_regfile.cpp`

```cpp
// tb_regfile.cpp
// Testbench completo para o banco de registradores RISC-V

#include "Vregister_file.h"
#include "verilated.h"
#include <iostream>
#include <cstdint>
#include <string>

// Instância global para simplificar as funções auxiliares
Vregister_file* dut;
VerilatedContext* contextp;

// Variável para contar testes passados/totais
int total_tests = 0;
int passed_tests = 0;

// ============================================================
// Funções auxiliares de temporização
// ============================================================

// Avança meio ciclo de clock (sem borda de subida)
void half_cycle() {
    dut->clk = 0;
    contextp->timeInc(5);
    dut->eval();
}

// Gera uma borda de subida do clock (escreve nos flip-flops)
void rising_edge() {
    dut->clk = 1;
    contextp->timeInc(5);
    dut->eval();
}

// Ciclo completo: sobe, desce
void clock_cycle() {
    rising_edge();
    half_cycle();
}

// Escreve em um registrador (leva 1 ciclo de clock)
void write_reg(uint8_t reg_addr, uint32_t value) {
    dut->we  = 1;
    dut->rd  = reg_addr;
    dut->wd  = value;
    clock_cycle();  // borda de subida captura os dados
    dut->we  = 0;   // desativa write enable após escrita
}

// Lê de rs1 (leitura combinacional — imediata após eval)
uint32_t read_rs1(uint8_t reg_addr) {
    dut->rs1 = reg_addr;
    dut->eval();    // atualiza a saída combinacional
    return dut->rd1;
}

// Lê de rs2 (leitura combinacional)
uint32_t read_rs2(uint8_t reg_addr) {
    dut->rs2 = reg_addr;
    dut->eval();
    return dut->rd2;
}

// Macro de verificação com mensagem
void check(bool condition, const std::string& test_name,
           uint32_t obtained, uint32_t expected) {
    total_tests++;
    if (condition) {
        passed_tests++;
        std::cout << "[PASS] " << test_name << std::endl;
    } else {
        std::cout << "[FAIL] " << test_name
                  << " | obtido=0x" << std::hex << obtained
                  << " esperado=0x" << expected << std::dec << std::endl;
    }
}

// ============================================================
// Testes
// ============================================================

// Teste 1: Escrita simples e leitura de rs1
void test1_write_and_read_rs1() {
    std::cout << std::endl << "--- Teste 1: Escreve 42 em x5, lê via rs1 ---" << std::endl;

    write_reg(5, 42);
    uint32_t val = read_rs1(5);

    check(val == 42,
          "x5 deve conter 42 após escrita",
          val, 42);
}

// Teste 2: Dual-port — lê dois registradores simultaneamente
void test2_dual_port() {
    std::cout << std::endl << "--- Teste 2: Escrita em x10, leitura simultânea de x5 e x10 ---" << std::endl;

    // x5 já tem 42 do teste anterior
    write_reg(10, 99);

    // Configura ambos os endereços de leitura
    dut->rs1 = 5;
    dut->rs2 = 10;
    dut->eval();

    check(dut->rd1 == 42,
          "rs1=x5 deve retornar 42",
          dut->rd1, 42);

    check(dut->rd2 == 99,
          "rs2=x10 deve retornar 99",
          dut->rd2, 99);
}

// Teste 3: Tenta escrever em x0 — deve ser ignorado
void test3_write_to_x0() {
    std::cout << std::endl << "--- Teste 3: Tentativa de escrita em x0 (deve ser ignorada) ---" << std::endl;

    // Tenta escrever 0xDEADBEEF em x0
    write_reg(0, 0xDEADBEEF);

    // Lê x0 de duas formas
    uint32_t via_rs1 = read_rs1(0);
    uint32_t via_rs2 = read_rs2(0);

    check(via_rs1 == 0,
          "x0 via rs1 deve sempre ser 0",
          via_rs1, 0);

    check(via_rs2 == 0,
          "x0 via rs2 deve sempre ser 0",
          via_rs2, 0);
}

// Teste 4: Escreve e lê todos os 31 registradores (x1 a x31)
void test4_all_registers() {
    std::cout << std::endl << "--- Teste 4: Escreve e lê todos os registradores x1-x31 ---" << std::endl;

    // Escreve um valor único em cada registrador
    // Valor = índice * 1000 + 0xABC00000 para ser facilmente identificável
    for (int i = 1; i <= 31; i++) {
        uint32_t value = (uint32_t)(i * 1000);
        write_reg((uint8_t)i, value);
    }

    // Verifica cada registrador via rs1
    bool all_ok = true;
    for (int i = 1; i <= 31; i++) {
        uint32_t expected = (uint32_t)(i * 1000);
        uint32_t obtained = read_rs1((uint8_t)i);

        if (obtained != expected) {
            std::cout << "  [FAIL] x" << i
                      << ": obtido=0x" << std::hex << obtained
                      << " esperado=0x" << expected << std::dec << std::endl;
            all_ok = false;
        }
    }

    total_tests++;
    if (all_ok) {
        passed_tests++;
        std::cout << "[PASS] Todos os 31 registradores (x1-x31) leram corretamente via rs1" << std::endl;
    } else {
        std::cout << "[FAIL] Erros encontrados na leitura dos registradores" << std::endl;
    }

    // Verifica também via rs2
    bool all_ok_rs2 = true;
    for (int i = 1; i <= 31; i++) {
        uint32_t expected = (uint32_t)(i * 1000);
        uint32_t obtained = read_rs2((uint8_t)i);

        if (obtained != expected) {
            all_ok_rs2 = false;
            break;
        }
    }

    total_tests++;
    if (all_ok_rs2) {
        passed_tests++;
        std::cout << "[PASS] Todos os 31 registradores (x1-x31) leram corretamente via rs2" << std::endl;
    } else {
        std::cout << "[FAIL] Erros encontrados na leitura via rs2" << std::endl;
    }
}

// Teste 5: Write Enable desativado — escrita não deve ocorrer
void test5_write_enable_disabled() {
    std::cout << std::endl << "--- Teste 5: Write Enable desativado (we=0) ---" << std::endl;

    // Primeiro, escreve um valor conhecido em x15
    write_reg(15, 12345);

    // Tenta escrever com we=0 (não deve funcionar)
    dut->we  = 0;       // desativado!
    dut->rd  = 15;
    dut->wd  = 99999;   // novo valor que NÃO deve ser escrito
    clock_cycle();       // borda de subida com we=0

    uint32_t val = read_rs1(15);

    check(val == 12345,
          "x15 deve manter 12345 (write ignorado por we=0)",
          val, 12345);
}

// Teste 6: Escrita e leitura no mesmo ciclo (forwarding)
// No processador real, isso pode ser necessário dependendo do design
void test6_write_then_immediate_read() {
    std::cout << std::endl << "--- Teste 6: Leitura imediatamente após escrita ---" << std::endl;

    // Escreve 777 em x20
    write_reg(20, 777);

    // Lê imediatamente (sem ciclos adicionais)
    // Na leitura assíncrona, deve retornar o novo valor
    uint32_t val = read_rs1(20);

    check(val == 777,
          "x20 deve retornar 777 na leitura pós-escrita",
          val, 777);
}

// Teste 7: Sobrescrita — escreve duas vezes no mesmo registrador
void test7_overwrite() {
    std::cout << std::endl << "--- Teste 7: Sobrescrita do mesmo registrador ---" << std::endl;

    write_reg(7, 100);
    write_reg(7, 200);   // sobrescreve

    uint32_t val = read_rs1(7);
    check(val == 200,
          "x7 deve conter 200 (último valor escrito)",
          val, 200);
}

// Teste 8: Verifica x0 após múltiplas tentativas de escrita
void test8_x0_hardwired_extensive() {
    std::cout << std::endl << "--- Teste 8: x0 permanece 0 após múltiplas tentativas de escrita ---" << std::endl;

    for (int i = 0; i < 5; i++) {
        write_reg(0, (uint32_t)(0xCAFE0000 + i));
    }

    // x0 deve continuar 0
    dut->rs1 = 0;
    dut->rs2 = 0;
    dut->eval();

    check(dut->rd1 == 0,
          "x0 via rs1 = 0 após 5 tentativas de escrita",
          dut->rd1, 0);

    check(dut->rd2 == 0,
          "x0 via rs2 = 0 após 5 tentativas de escrita",
          dut->rd2, 0);
}

// ============================================================
// Função principal
// ============================================================

int main(int argc, char** argv) {
    contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    dut = new Vregister_file(contextp);

    // Estado inicial: clock baixo, write enable desativado
    dut->clk = 0;
    dut->we  = 0;
    dut->rs1 = 0;
    dut->rs2 = 0;
    dut->rd  = 0;
    dut->wd  = 0;
    dut->eval();

    std::cout << "============================================" << std::endl;
    std::cout << "    Testbench: Register File RISC-V        " << std::endl;
    std::cout << "============================================" << std::endl;

    // Executa todos os testes
    test1_write_and_read_rs1();
    test2_dual_port();
    test3_write_to_x0();
    test4_all_registers();
    test5_write_enable_disabled();
    test6_write_then_immediate_read();
    test7_overwrite();
    test8_x0_hardwired_extensive();

    // Resumo final
    std::cout << std::endl;
    std::cout << "============================================" << std::endl;
    std::cout << "Resultado: " << passed_tests << "/" << total_tests
              << " testes passaram." << std::endl;

    if (passed_tests == total_tests) {
        std::cout << "STATUS: BANCO DE REGISTRADORES 100% FUNCIONAL!" << std::endl;
    } else {
        std::cout << "STATUS: " << (total_tests - passed_tests)
                  << " FALHA(S) DETECTADA(S)!" << std::endl;
    }
    std::cout << "============================================" << std::endl;

    dut->final();
    delete dut;
    delete contextp;

    return (passed_tests == total_tests) ? 0 : 1;
}
```

### Como compilar e executar

```bash
verilator --cc --sv --exe --build --Mdir obj_dir -Wall \
    register_file.sv tb_regfile.cpp -o Vregister_file

./obj_dir/Vregister_file
```

Saída esperada:

```
============================================
    Testbench: Register File RISC-V
============================================

--- Teste 1: Escreve 42 em x5, lê via rs1 ---
[PASS] x5 deve conter 42 após escrita

--- Teste 2: Escrita em x10, leitura simultânea de x5 e x10 ---
[PASS] rs1=x5 deve retornar 42
[PASS] rs2=x10 deve retornar 99

--- Teste 3: Tentativa de escrita em x0 (deve ser ignorada) ---
[PASS] x0 via rs1 deve sempre ser 0
[PASS] x0 via rs2 deve sempre ser 0

--- Teste 4: Escreve e lê todos os registradores x1-x31 ---
[PASS] Todos os 31 registradores (x1-x31) leram corretamente via rs1
[PASS] Todos os 31 registradores (x1-x31) leram corretamente via rs2

--- Teste 5: Write Enable desativado (we=0) ---
[PASS] x15 deve manter 12345 (write ignorado por we=0)

--- Teste 6: Leitura imediatamente após escrita ---
[PASS] x20 deve retornar 777 na leitura pós-escrita

--- Teste 7: Sobrescrita do mesmo registrador ---
[PASS] x7 deve conter 200 (último valor escrito)

--- Teste 8: x0 permanece 0 após múltiplas tentativas de escrita ---
[PASS] x0 via rs1 = 0 após 5 tentativas de escrita
[PASS] x0 via rs2 = 0 após 5 tentativas de escrita

============================================
Resultado: 13/13 testes passaram.
STATUS: BANCO DE REGISTRADORES 100% FUNCIONAL!
============================================
```

---

## Seção 4 — Por que a Leitura é Assíncrona?

Esta é uma das perguntas mais importantes sobre o design de um processador. A resposta muda dependendo da arquitetura do processador.

### O processador single-cycle

No nosso processador RV32I single-cycle, cada instrução é executada em um único ciclo de clock. O diagrama de execução (simplificado) é:

```
Ciclo N:
  ┌──────────────────────────────────────────────────────────┐
  │  Borda de subida                                         │
  │      ↓                                                   │
  │  [PC atualiza]                                           │
  │      ↓                                                   │
  │  [Busca instrução na memória]  ←── combinacional         │
  │      ↓                                                   │
  │  [Decodifica instrução]        ←── combinacional         │
  │      ↓                                                   │
  │  [Lê rs1 e rs2 do reg file]    ←── COMBINACIONAL         │
  │      ↓                                                   │
  │  [ALU processa]                ←── combinacional         │
  │      ↓                                                   │
  │  [Acessa memória (se LW/SW)]   ←── combinacional/síncr. │
  │      ↓                                                   │
  │  [Escreve resultado em rd]                               │
  │      ↓                                                   │
  │  Próxima borda de subida                                 │
  └──────────────────────────────────────────────────────────┘
```

Tudo entre duas bordas de subida é combinacional — formando um grande caminho crítico de lógica. O clock só bate uma vez por instrução, capturando o estado final.

**Por que a leitura do banco de registradores precisa ser combinacional?**

Porque ela fica no meio do caminho crítico. Se a leitura fosse síncrona (esperasse pelo próximo clock), precisaríamos de dois ciclos só para buscar os operandos, tornando a arquitetura single-cycle impossível.

Em outras palavras: no ciclo N, quando a instrução `ADD x1, x2, x3` é executada, o hardware precisa:
1. Buscar a instrução (ciclo N)
2. Decodificar e identificar x2, x3 como fontes (ciclo N)
3. **Ler x2 e x3 imediatamente** — mesmas combinações de portas (ciclo N)
4. Passar para a ALU (ciclo N)
5. Escrever resultado em x1 na borda do ciclo N+1

Se a leitura fosse síncrona, etapa 3 só aconteceria no ciclo N+1, e etapas 4 e 5 no N+2. Seriam 2 ciclos por instrução em vez de 1.

### O processador pipelined — uma perspectiva futura

Em um processador com pipeline (como o clássico MIPS ou RISC-V com 5 estágios), a história é diferente:

```
Estágios do pipeline RISC-V clássico:
  IF    ID    EX    MEM   WB
  ─────────────────────────────
  Busca Decod ALU   Mem   Escrita
        Lê          Lê/   no reg
        regs        Escr  file
```

No estágio `ID` (Instruction Decode), o banco de registradores é lido. Como cada estágio ocupa exatamente um ciclo, a leitura ainda precisa ser completada dentro do mesmo ciclo do estágio ID — portanto, ainda assíncrona.

Entretanto, o pipeline introduz um problema chamado **hazard de dados**: a instrução `ADD x1, x2, x3` está no estágio EX enquanto a instrução seguinte `ADD x4, x1, x5` está no estágio ID lendo x1 — mas x1 ainda não foi escrito (está no caminho EX→MEM→WB)! O valor lido é o valor antigo.

**Soluções para hazards de dados em pipelines:**

1. **Stalls (bolhas):** Insere ciclos de espera até o valor estar disponível. Simples, mas lento.

2. **Forwarding (data forwarding / bypassing):** O resultado da ALU é encaminhado diretamente de volta para a entrada da ALU no ciclo seguinte, sem esperar a escrita no banco. Isso exige um mux extra e lógica de detecção de hazards.

3. **Leitura síncrona com forwarding interno:** Neste design alternativo, o banco de registradores tem saídas registradas, mas faz forwarding interno: se o endereço de leitura bate com uma escrita pendente, retorna o novo valor em vez do armazenado. Útil em FPGAs onde memórias síncronas são mais eficientes em área.

**Para o nosso processador single-cycle:** nenhum desses problemas existe. Cada instrução completa todos os estágios em um único ciclo, então quando a instrução seguinte começa, o banco já foi atualizado.

### Resumo da escolha de design

| Aspecto | Single-cycle | Pipelined |
|---------|-------------|-----------|
| Leitura do banco | Assíncrona (combinacional) | Assíncrona (combinacional) |
| Por que? | Instrução completa em 1 ciclo | Estágio ID deve completar em 1 ciclo |
| Hazard de dados? | Não | Sim — requer forwarding ou stalls |
| Leitura síncrona viável? | Não (dobraria ciclos) | Em FPGAs, com forwarding interno |
| Clock do banco | Apenas para escrita | Apenas para escrita (ou leitura com forwarding) |

A leitura assíncrona do banco de registradores é uma característica fundamental dos processadores RISC single-cycle e do estágio ID de pipelines clássicos. É uma das razões pelas quais o banco de registradores é implementado em SRAM customizada em chips reais (não em DRAM, que é síncrona e mais lenta).

---

## Resumo da Parte 3

Implementamos o banco de registradores completo:

```
register_file.sv
├── 32 registradores de 32 bits (regs[0:31])
├── x0 hardwired to zero
│   ├── Escrita bloqueada por guarda (rd != 0)
│   └── Leitura retorna 0 por condição ternária
├── 2 portas de leitura combinacional (rs1→rd1, rs2→rd2)
└── 1 porta de escrita síncrona (posedge clk, controlada por we)
```

O banco de registradores complementa a ALU da Parte 2: a ALU processa dados, o banco fornece e armazena esses dados.

**Na Parte 4**, conectaremos ALU, banco de registradores, memória de instruções e unidade de controle para formar o datapath completo do processador single-cycle.

**Arquivos criados nesta parte:**
- `/Users/joaocarlosbrittofilho/Documents/neander_riscV/guia_implementacao/parte3_regfile.md` (este arquivo)
- `register_file.sv` — módulo SystemVerilog
- `tb_regfile.cpp` — testbench C++ com Verilator
