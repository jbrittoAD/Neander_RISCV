# Lista 5 — Manipulação de Bits ⭐⭐

**Pré-requisito:** Listas 1–2 + Tutorial 02 (Aritmética e operações lógicas)

Exercícios focados em operações de bit — um conjunto de habilidades essencial para
sistemas embarcados, drivers de hardware e protocolos de comunicação.

---

## Por que manipulação de bits importa?

Em sistemas reais, registradores de hardware são "campos de bits": cada bit ou grupo
de bits controla algo diferente. Exemplos:

```
Registrador de controle GPIO (hipotético):
  bit 7: habilita interrupção
  bit 6: direção (0=entrada, 1=saída)
  bits [3:0]: velocidade do clock
```

Para alterar apenas o bit 6 sem tocar os outros, você usa `OR`, `AND` e `XOR` com
**máscaras** — exatamente o que este exercício treina.

---

## Exercício 21 — Extração de campo de bits

Dado o valor `x1 = 0x7AB4D3AF`, extraia os **bits [11:4]** (8 bits).

**Técnica:**
```
passo 1: srli x2, x1, 4       ← desloca o campo para os bits [7:0]
passo 2: andi x2, x2, 0xFF    ← apaga tudo acima do bit 7 (máscara 8 bits)
```

**Resultado esperado:** `x2 = 58` (= 0x3A)

**Generalização:** para extrair N bits a partir da posição P:
```asm
srli  xd, xs, P        # alinha o campo
andi  xd, xd, (2^N)-1  # aplica máscara de N bits
```

---

## Exercício 22 — Set, Clear e Toggle de bits individuais

Dado `x1 = 0b10101010` (= 0xAA = 170), realize três operações **sem alterar os
outros bits**:

| Operação    | Fórmula            | Resultado esperado |
|-------------|--------------------|--------------------|
| Set bit 4   | `x \| (1 << 4)`  | `x2 = 186` (0xBA)  |
| Clear bit 7 | `x & ~(1 << 7)`  | `x3 = 42`  (0x2A)  |
| Toggle bit 1| `x ^ (1 << 1)`   | `x4 = 168` (0xA8)  |

**Dica:** para calcular `~(1 << N)` em RISC-V (sem instrução NOT):
```asm
addi  x5, x0, 1
slli  x5, x5, N     # x5 = 1 << N
xori  x5, x5, -1    # x5 = ~x5  (xori com -1 = XOR com todos os bits 1)
```

---

## Exercício 23 — Empacotar e desempacotar dois valores de 16 bits

Dados dois valores de 16 bits, empacote-os em um único registrador de 32 bits e
depois recupere cada um.

**Entrada:**
```
x1 = 0x1234   ← valor alto (vai para os bits [31:16])
x2 = 0x5678   ← valor baixo (fica nos bits [15:0])
```

**Resultado esperado:**
```
x3 = 0x12345678   ← empacotado
x4 = 0x1234       ← desempacotado: parte alta
x5 = 0x5678       ← desempacotado: parte baixa
```

**Técnicas:**
```asm
# Empacotar:
slli  x3, x1, 16       # x3 = x1 << 16  (valor alto na posição certa)
or    x3, x3, x2       # x3 = x3 | x2   (combina com valor baixo)

# Desempacotar parte alta:
srli  x4, x3, 16       # zeros entram pela esquerda → limpa parte baixa

# Desempacotar parte baixa (sem máscara de 16 bits — não cabe em addi):
slli  x5, x3, 16       # apaga os 16 bits altos levando-os para fora
srli  x5, x5, 16       # traz de volta com zeros na parte alta
```

**Por que não usar `andi` para a máscara?**
O imediato de 12 bits do `andi` suporta no máximo 0x7FF (positivo). O valor
`0xFFFF` = 65535 está fora do alcance. O double-shift é a solução padrão no RV32I.

---

## Compilar e testar

```bash
# No diretório lista_05_bits/gabarito/:
riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o ex21.o ex21_extrai_campo.s
riscv64-unknown-elf-objcopy -O binary ex21.o ex21.bin
python3 ../../../riscv_harvard/scripts/bin2hex.py ex21.bin ex21.hex
python3 ../../../simulator/riscv_sim.py ex21.hex --run
```

Ou use o verificador automático:
```bash
cd ../../..   # diretório raiz
python3 exercicios/verifica_gabaritos.py
```
