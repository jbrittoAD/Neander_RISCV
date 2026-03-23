# Lista 1 — Exercícios Básicos de Assembly RISC-V

**Nível:** ⭐ Iniciante
**Pré-requisito:** Tutorial 01 (Olá Mundo) e Tutorial 02 (Aritmética)

---

## Como resolver

1. Escreva seu programa em um arquivo `.s`
2. Compile: `riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 -o prog.o prog.s`
3. Gere o .hex: `riscv64-unknown-elf-objcopy -O binary prog.o prog.bin && python3 simulator/scripts/bin2hex.py prog.bin prog.hex`
4. Execute no simulador: `python3 simulator/riscv_sim.py prog.hex --run`
5. Verifique os registradores com `reg` ou `--run`

Os gabaritos estão em `gabarito/` — tente resolver sozinho antes de ver!

---

## Exercício 1 — Soma de dois números

Escreva um programa que:
1. Carregue o valor `15` no registrador `x1`
2. Carregue o valor `27` no registrador `x2`
3. Calcule a soma e armazene em `x3`

**Resultado esperado:** `x3 = 42`

**Dica:** Use `addi` para carregar constantes e `add` para somar.

---

## Exercício 2 — Operações lógicas

Dados os valores `x1 = 0b11001010` (202) e `x2 = 0b10110110` (182), calcule:
- `x3` = AND de x1 e x2
- `x4` = OR de x1 e x2
- `x5` = XOR de x1 e x2
- `x6` = NOT de x1 (inverta todos os bits)

**Resultados esperados:**
- `x3 = 0b10000010 = 130`
- `x4 = 0b11111110 = 254`
- `x5 = 0b01111100 = 124`
- `x6 = 0xFFFFFF35 = -203` (em decimal com sinal)

**Dica:** NOT não existe em RV32I — use `xori rd, rs, -1` (XOR com todos os bits 1).

---

## Exercício 3 — Deslocamentos (shifts)

Carregue `x1 = 1` e use deslocamentos para calcular potências de 2:
- `x2` = 1 deslocado 3 posições à esquerda (= 8 = 2³)
- `x3` = valor de x2 deslocado 2 posições à direita lógico (= 2)
- `x4` = o valor -32 deslocado 2 posições à direita **aritmético** (= -8)
- `x5` = o valor -32 deslocado 2 posições à direita **lógico** (= 0x3FFFFFF8 = um valor grande positivo)

**Resultados esperados:**
- `x2 = 8`
- `x3 = 2`
- `x4 = -8` (0xFFFFFFF8)
- `x5 = 0x3FFFFFF8` (1073741816)

**Dica:** `slli`, `srli` e `srai`. Compare x4 e x5 para entender a diferença entre shift lógico e aritmético.

---

## Exercício 4 — Constante grande com LUI + ADDI

O imediato do `addi` só suporta 12 bits com sinal (de -2048 a +2047).
Para carregar o valor `0xDEAD0000` em `x1`, use `lui`:

```
lui x1, 0xDEAD    ← carrega os 20 bits superiores
```

Agora, como você carregaria `0xDEAD1234` em `x1`?
(Cuidado: `0x1234 = 4660` que cabe em 12 bits não-negativos — mas e se precisasse de um valor com bit 11 = 1?)

**Resultado esperado:** `x1 = 0xDEAD1234 = 3735879220`

**Dica:** `lui x1, 0xDEAD` depois `addi x1, x1, 0x1234`.

---

## Exercício 5 — Troca de valores (sem variável temporária)

Dados `x1 = 10` e `x2 = 25`, **troque** os valores entre os registradores
usando apenas operações **XOR** (sem usar um registrador auxiliar):

```
x1 = x1 XOR x2
x2 = x1 XOR x2
x1 = x1 XOR x2
```

**Resultado esperado:** `x1 = 25`, `x2 = 10`

**Por que funciona?** Propriedades do XOR:
- a XOR a = 0
- a XOR 0 = a
- a XOR b XOR b = a

Esta é uma técnica clássica usada em sistemas embarcados quando memória é escassa.

---

## Verificação rápida

Após resolver cada exercício, use o simulador para conferir:
```bash
python3 simulator/riscv_sim.py meu_prog.hex --run
```

O resultado correto aparecerá nos registradores finais.

---

**Próxima lista:** [Lista 2 — Intermediário](../lista_02_intermediario/enunciado.md)
