# Exercícios de Assembly RISC-V RV32I

20 exercícios progressivos para praticar programação em assembly RISC-V,
organizados em 4 listas de dificuldade crescente.

---

## Como usar

### Compilar um exercício

```bash
# Compila seu arquivo .s para .hex
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o prog.o meu_prog.s
riscv64-unknown-elf-objcopy -O binary prog.o prog.bin
python3 ../riscv_harvard/scripts/bin2hex.py prog.bin prog.hex

# Verifica no simulador
python3 ../simulator/riscv_sim.py prog.hex --run

# Ou executa interativamente para depurar:
python3 ../simulator/riscv_sim.py prog.hex
riscv> step    ← instrução por instrução
riscv> reg     ← inspeciona registradores
riscv> mem 0x0000 8   ← inspeciona memória
```

### Compilar e testar os gabaritos

```bash
# Entra em uma lista e compila o gabarito
cd exercicios/lista_01_basico/gabarito/
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex01.o ex01_soma.s
riscv64-unknown-elf-objcopy -O binary ex01.o ex01.bin
python3 ../../../riscv_harvard/scripts/bin2hex.py ex01.bin ex01.hex
python3 ../../../simulator/riscv_sim.py ex01.hex --run
```

---

## Listas de exercícios

### Lista 1 — Básico ⭐

[Ver enunciados](lista_01_basico/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Ex. 1 | Soma de dois números | x3 = 42 |
| Ex. 2 | Operações lógicas (AND, OR, XOR, NOT) | x3=130, x4=254, x5=124, x6=-203 |
| Ex. 3 | Deslocamentos (sll, srl, sra) | x2=8, x3=2, x4=-8, x5=1073741816 |
| Ex. 4 | Constante grande com LUI+ADDI | x1 = 0xDEAD1234 |
| Ex. 5 | Troca com XOR (sem auxiliar) | x1=25, x2=10 |

---

### Lista 2 — Intermediário ⭐⭐

[Ver enunciados](lista_02_intermediario/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Ex. 6  | Valor absoluto | x2 = 42 |
| Ex. 7  | Máximo de dois números | x3 = 3 |
| Ex. 8  | Soma de 1 até N | x2 = 55 |
| Ex. 9  | Contagem de bits 1 (popcount) | x2 = 5 |
| Ex. 10 | Busca linear em array | x2 = 2 (índice do 42) |

---

### Lista 3 — Avançado ⭐⭐⭐

[Ver enunciados](lista_03_avancado/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Ex. 11 | Soma de array com ponteiro | x2 = 105 |
| Ex. 12 | Inversão de array in-place | mem = [5,4,3,2,1] |
| Ex. 13 | Função: dobro de um número | x11=14, x10=42 |
| Ex. 14 | Função iterativa: fatorial | x11=120, x10=6 |
| Ex. 15 | Fibonacci com verificação | x3=34, x20=1 |

---

### Lista 4 — Expert ⭐⭐⭐⭐

[Ver enunciados](lista_04_expert/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Ex. 16 | Fibonacci recursivo | x10=21 |
| Ex. 17 | Fatorial recursivo | x10=720 |
| Ex. 18 | Busca binária (função) | s0=6 (índice do 38) |
| Ex. 19 | Inversão de string | dmem="EDCBA\0" |
| Ex. 20 | MMC | x3=36 |

---

### Lista 5 — Manipulação de Bits ⭐⭐

[Ver enunciados](lista_05_bits/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Ex. 21 | Extração de campo de bits | x2 = 58 (bits [11:4] de 0x7AB4D3AF) |
| Ex. 22 | Set, Clear e Toggle de bits | x2=186, x3=42, x4=168 |
| Ex. 23 | Empacotar/desempacotar 16+16→32 bits | x3=0x12345678, x4=0x1234, x5=0x5678 |

---

### Capstone — Ordenação + Busca + Soma ⭐⭐⭐⭐⭐

[Ver enunciado](capstone/enunciado.md)

| Exercício | Tema | Resultado esperado |
|---|---|---|
| Capstone | Insertion Sort + Binary Search + Soma | x10=5, x11=146, dmem=[4,5,8,11,16,23,37,42] |

Integra todos os conceitos das Listas 1–4: manipulação de arrays com ponteiros,
funções callee-saved, leaf functions, convenção de chamada e pilha.

---

## Dicas gerais

### Halt (parar a execução)
Todo programa deve terminar com um loop para si mesmo:
```asm
fim:
    jal x0, fim    # equivale ao HLT do Neander
```

### Carregar constantes
- Valores de -2048 a 2047: `addi x1, x0, valor`
- Valores maiores: `lui x1, parte_alta` + `addi x1, x1, parte_baixa`

### Sem instrução NOP?
Use `addi x0, x0, 0` — escreve em x0 que sempre é zero. Não faz nada.

### Multiplicação?
RV32I não tem `mul`. Use soma repetida (como em factorial.s nos exemplos)
ou extensão M (fora do escopo desta disciplina).

### Depurando com o simulador
```
riscv> step          ← executa 1 instrução, mostra o que mudou
riscv> imem 0x0000   ← mostra as instruções com o PC marcado
riscv> bp 0x10       ← para automaticamente em 0x10
riscv> run           ← executa até o halt ou breakpoint
riscv> mem 0x0000 8  ← mostra 8 words de dados
```
