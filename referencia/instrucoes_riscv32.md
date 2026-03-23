# Cartão de Referência — RISC-V RV32I

> Para impressão em 1–2 páginas A4. Projeto educacional RISC-V (equivalente ao Neander — UFRGS).

---

## Formatos de Instrução

| Tipo   | [31:25]      | [24:20]    | [19:15]    | [14:12]    | [11:7]      | [6:0]      |
|--------|-------------|-----------|-----------|-----------|------------|-----------|
| R      | funct7      | rs2       | rs1       | funct3    | rd         | opcode    |
| I      | imm[11:5]   | imm[4:0]  | rs1       | funct3    | rd         | opcode    |
| S      | imm[11:5]   | rs2       | rs1       | funct3    | imm[4:0]   | opcode    |
| U      | imm[31:12]  |           |           |           | rd         | opcode    |

| Tipo   | [31]      | [30:25]      | [24:20]    | [19:15]    | [14:12]    | [11:8]      | [7]       | [6:0]    |
|--------|----------|-------------|-----------|-----------|-----------|------------|----------|---------|
| B      | imm[12]  | imm[10:5]   | rs2       | rs1       | funct3    | imm[4:1]   | imm[11]  | opcode  |

| Tipo   | [31]      | [30:21]      | [20]      | [19:12]      | [11:7]    | [6:0]    |
|--------|----------|-------------|----------|-------------|---------|---------|
| J      | imm[20]  | imm[10:1]   | imm[11]  | imm[19:12]  | rd      | opcode  |

---

## Conjunto de Instruções RV32I

### R-type — Registrador–Registrador (opcode = `0110011`)

| Instrução              | Tipo | Operação                          | funct3 | funct7   | Exemplo              |
|------------------------|------|-----------------------------------|--------|----------|----------------------|
| `add  rd, rs1, rs2`    | R    | rd = rs1 + rs2                    | `000`  | `0000000`| `add  x5, x1, x2`   |
| `sub  rd, rs1, rs2`    | R    | rd = rs1 − rs2                    | `000`  | `0100000`| `sub  x5, x1, x2`   |
| `sll  rd, rs1, rs2`    | R    | rd = rs1 << (rs2 & 31)            | `001`  | `0000000`| `sll  x5, x1, x2`   |
| `slt  rd, rs1, rs2`    | R    | rd = (rs1 <ₛ rs2) ? 1 : 0        | `010`  | `0000000`| `slt  x5, x1, x2`   |
| `sltu rd, rs1, rs2`    | R    | rd = (rs1 <ᵤ rs2) ? 1 : 0        | `011`  | `0000000`| `sltu x5, x1, x2`   |
| `xor  rd, rs1, rs2`    | R    | rd = rs1 ^ rs2                    | `100`  | `0000000`| `xor  x5, x1, x2`   |
| `srl  rd, rs1, rs2`    | R    | rd = rs1 >>ᵤ (rs2 & 31) lógico   | `101`  | `0000000`| `srl  x5, x1, x2`   |
| `sra  rd, rs1, rs2`    | R    | rd = rs1 >>ₛ (rs2 & 31) aritmético| `101`  | `0100000`| `sra  x5, x1, x2`   |
| `or   rd, rs1, rs2`    | R    | rd = rs1 \| rs2                   | `110`  | `0000000`| `or   x5, x1, x2`   |
| `and  rd, rs1, rs2`    | R    | rd = rs1 & rs2                    | `111`  | `0000000`| `and  x5, x1, x2`   |

### I-type — Imediato Aritmético (opcode = `0010011`)

| Instrução               | Tipo | Operação                              | funct3 | funct7/nota        | Exemplo               |
|-------------------------|------|---------------------------------------|--------|--------------------|-----------------------|
| `addi  rd, rs1, imm`    | I    | rd = rs1 + sext(imm)                  | `000`  | —                  | `addi x5, x1, 10`    |
| `slti  rd, rs1, imm`    | I    | rd = (rs1 <ₛ sext(imm)) ? 1 : 0      | `010`  | —                  | `slti x5, x1, 5`     |
| `sltiu rd, rs1, imm`    | I    | rd = (rs1 <ᵤ sext(imm)) ? 1 : 0      | `011`  | —                  | `sltiu x5, x1, 5`    |
| `xori  rd, rs1, imm`    | I    | rd = rs1 ^ sext(imm)                  | `100`  | —                  | `xori x5, x1, 0xFF`  |
| `ori   rd, rs1, imm`    | I    | rd = rs1 \| sext(imm)                 | `110`  | —                  | `ori  x5, x1, 0xF`   |
| `andi  rd, rs1, imm`    | I    | rd = rs1 & sext(imm)                  | `111`  | —                  | `andi x5, x1, 0xF`   |
| `slli  rd, rs1, shamt`  | I    | rd = rs1 << shamt                     | `001`  | funct7=`0000000`   | `slli x5, x1, 3`     |
| `srli  rd, rs1, shamt`  | I    | rd = rs1 >>ᵤ shamt lógico             | `101`  | funct7=`0000000`   | `srli x5, x1, 3`     |
| `srai  rd, rs1, shamt`  | I    | rd = rs1 >>ₛ shamt aritmético         | `101`  | funct7=`0100000`   | `srai x5, x1, 3`     |

### I-type — Cargas (opcode = `0000011`)

| Instrução              | Tipo | Operação                           | funct3 | Exemplo               |
|------------------------|------|------------------------------------|--------|-----------------------|
| `lb  rd, imm(rs1)`     | I    | rd = sext(mem₈[rs1+imm])           | `000`  | `lb  x5, 4(x1)`      |
| `lh  rd, imm(rs1)`     | I    | rd = sext(mem₁₆[rs1+imm])          | `001`  | `lh  x5, 4(x1)`      |
| `lw  rd, imm(rs1)`     | I    | rd = mem₃₂[rs1+imm]                | `010`  | `lw  x5, 4(x1)`      |
| `lbu rd, imm(rs1)`     | I    | rd = zext(mem₈[rs1+imm])           | `100`  | `lbu x5, 4(x1)`      |
| `lhu rd, imm(rs1)`     | I    | rd = zext(mem₁₆[rs1+imm])          | `101`  | `lhu x5, 4(x1)`      |

### S-type — Armazenamentos (opcode = `0100011`)

| Instrução              | Tipo | Operação                           | funct3 | Exemplo               |
|------------------------|------|------------------------------------|--------|-----------------------|
| `sb rs2, imm(rs1)`     | S    | mem₈[rs1+imm] = rs2[7:0]           | `000`  | `sb  x5, 4(x1)`      |
| `sh rs2, imm(rs1)`     | S    | mem₁₆[rs1+imm] = rs2[15:0]         | `001`  | `sh  x5, 4(x1)`      |
| `sw rs2, imm(rs1)`     | S    | mem₃₂[rs1+imm] = rs2               | `010`  | `sw  x5, 4(x1)`      |

### B-type — Desvios Condicionais (opcode = `1100011`)

| Instrução                   | Tipo | Operação                           | funct3 | Exemplo                    |
|-----------------------------|------|------------------------------------|--------|----------------------------|
| `beq  rs1, rs2, label`      | B    | if rs1 == rs2: PC += sext(imm)     | `000`  | `beq  x1, x2, loop`       |
| `bne  rs1, rs2, label`      | B    | if rs1 ≠ rs2: PC += sext(imm)      | `001`  | `bne  x1, x2, loop`       |
| `blt  rs1, rs2, label`      | B    | if rs1 <ₛ rs2: PC += sext(imm)    | `100`  | `blt  x1, x2, loop`       |
| `bge  rs1, rs2, label`      | B    | if rs1 ≥ₛ rs2: PC += sext(imm)    | `101`  | `bge  x1, x2, loop`       |
| `bltu rs1, rs2, label`      | B    | if rs1 <ᵤ rs2: PC += sext(imm)    | `110`  | `bltu x1, x2, loop`       |
| `bgeu rs1, rs2, label`      | B    | if rs1 ≥ᵤ rs2: PC += sext(imm)    | `111`  | `bgeu x1, x2, loop`       |

### U-type — Imediato Superior

| Instrução              | Tipo | Operação                           | opcode     | Exemplo               |
|------------------------|------|------------------------------------|------------|-----------------------|
| `lui   rd, imm`        | U    | rd = imm << 12                     | `0110111`  | `lui  x5, 0x12345`   |
| `auipc rd, imm`        | U    | rd = PC + (imm << 12)              | `0010111`  | `auipc x5, 0x1`      |

### J-type — Desvios Incondicionais

| Instrução               | Tipo | Operação                           | opcode     | funct3 | Exemplo               |
|-------------------------|------|------------------------------------|------------|--------|-----------------------|
| `jal  rd, label`        | J    | rd = PC+4; PC += sext(imm)         | `1101111`  | —      | `jal  x1, func`      |
| `jalr rd, rs1, imm`     | I    | rd = PC+4; PC = (rs1+imm) & ~1     | `1100111`  | `000`  | `jalr x0, x1, 0`     |

---

## Registradores (x0–x31)

| Reg    | Nome ABI | Uso convencional                          | Salvo por  |
|--------|----------|-------------------------------------------|------------|
| x0     | `zero`   | Sempre zero (escrita ignorada)            | —          |
| x1     | `ra`     | Endereço de retorno (return address)      | Caller     |
| x2     | `sp`     | Stack pointer                             | Callee     |
| x3     | `gp`     | Global pointer                            | —          |
| x4     | `tp`     | Thread pointer                            | —          |
| x5–x7  | `t0–t2`  | Temporários                               | Caller     |
| x8     | `s0/fp`  | Saved / Frame pointer                     | Callee     |
| x9     | `s1`     | Saved register                            | Callee     |
| x10–x11| `a0–a1`  | Argumentos / valores de retorno           | Caller     |
| x12–x17| `a2–a7`  | Argumentos                                | Caller     |
| x18–x27| `s2–s11` | Saved registers                           | Callee     |
| x28–x31| `t3–t6`  | Temporários                               | Caller     |

---

## Pseudoinstruções Comuns

O assembler expande automaticamente as pseudoinstruções abaixo para instruções reais.

| Pseudoinstrução          | Expansão                      | Descrição                        |
|--------------------------|-------------------------------|----------------------------------|
| `nop`                    | `addi x0, x0, 0`              | Nenhuma operação                 |
| `li rd, imm`             | `lui` + `addi`                | Carrega constante de 32 bits     |
| `mv rd, rs`              | `addi rd, rs, 0`              | Copia registrador                |
| `neg rd, rs`             | `sub rd, x0, rs`              | Negação aritmética               |
| `not rd, rs`             | `xori rd, rs, -1`             | Complemento bit a bit            |
| `ret`                    | `jalr x0, x1, 0`              | Retorno de função                |
| `j label`                | `jal x0, label`               | Desvio incondicional             |
| `call label`             | `jal x1, label`               | Chamada de função                |
| `beqz rs, label`         | `beq rs, x0, label`           | Desvia se rs == 0                |
| `bnez rs, label`         | `bne rs, x0, label`           | Desvia se rs ≠ 0                 |
| `blez rs, label`         | `bge x0, rs, label`           | Desvia se rs ≤ 0 (signed)        |
| `bgtz rs, label`         | `blt x0, rs, label`           | Desvia se rs > 0 (signed)        |
| `bltz rs, label`         | `blt rs, x0, label`           | Desvia se rs < 0 (signed)        |
| `bgez rs, label`         | `bge rs, x0, label`           | Desvia se rs ≥ 0 (signed)        |

---

## Convenção de Chamada RISC-V (resumo)

| Aspecto          | Registradores           | Nota                                      |
|------------------|-------------------------|-------------------------------------------|
| Argumentos       | a0–a7 (x10–x17)         | Extras passados na pilha                  |
| Retorno          | a0–a1 (x10–x11)         | Valores de até 64 bits                    |
| Caller-saved     | t0–t6, a0–a7            | Chamador deve salvar se precisar          |
| Callee-saved     | s0–s11, sp              | Chamado deve restaurar antes de retornar  |
| Link register    | ra (x1)                 | Salvo pelo chamador em chamadas aninhadas |

---

## Ranges de Imediatos

| Formato | Bits | Range                         | Observação                          |
|---------|------|-------------------------------|-------------------------------------|
| I, S    | 12   | −2048 a +2047                 | Complemento de dois, extensão sinal |
| B       | 13   | −4096 a +4094                 | Múltiplos de 2 (bit 0 sempre 0)     |
| U       | 20   | 0 a 0xFFFFF (× 4096)          | Ocupa bits [31:12] da palavra       |
| J       | 21   | −1 MB a +1 MB − 2             | Múltiplos de 2 (bit 0 sempre 0)     |

---

*Especificação: RISC-V ISA Volume I: Unprivileged ISA — versão 20191213.*
