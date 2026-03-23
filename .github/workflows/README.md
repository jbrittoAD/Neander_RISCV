# CI Pipeline — RISC-V RV32I

Este diretório contém o workflow de integração contínua (CI) do projeto.
O pipeline garante que o simulador, os gabaritos dos exercícios e os designs
de hardware em SystemVerilog continuem funcionando a cada commit ou pull request.

---

## Quando o pipeline executa

| Evento | Comportamento |
|---|---|
| `push` em qualquer branch | Executa os 3 jobs |
| `pull_request` para `main` | Executa os 3 jobs |

---

## Os 3 jobs do pipeline

Os jobs são encadeados em sequência: cada um só inicia se o anterior passou.
Isso evita gastar tempo de CI em jobs mais lentos quando um problema básico já
foi detectado.

```
simulator  -->  gabaritos  -->  hardware
(~3 s)          (~60 s)         (~120 s)
```

---

### Job 1 — `simulator`: Simulador Python (89 testes)

**O que testa:** executa `simulator/tests/test_core.py`, que valida o
simulador Python do processador RV32I contra 89 casos de teste unitários.

**Dependências externas:** nenhuma — apenas Python 3 (disponível no runner).

**Tempo esperado:** 2-3 segundos.

**Por que importa:** este job é a rede de segurança mais rápida. Se qualquer
lógica central do simulador quebrar (decodificação de instrução, ALU,
controle de PC, etc.), ele falha aqui antes de qualquer instalação pesada de
toolchain.

---

### Job 2 — `gabaritos`: Verificação dos Gabaritos (23 exercícios)

**O que testa:** executa `exercicios/verifica_gabaritos.py`, que monta cada
arquivo `.s` dos gabaritos das listas de exercícios usando o assembler RISC-V
e verifica a corretude da saída.

**Dependências externas:**
- `gcc-riscv64-unknown-elf` — compilador/assembler RISC-V
- `binutils-riscv64-unknown-elf` — utilitários binários RISC-V

**Tempo esperado:** ~60 segundos (instalação do toolchain + montagem dos 23 exercícios).

**Por que importa:** garante que os gabaritos das listas 01-05 continuam
sintaticamente corretos e produzem o binário esperado após qualquer edição.

---

### Job 3 — `hardware`: Testes de Hardware Verilator (Harvard + Von Neumann)

**O que testa:** compila e simula ambos os designs SystemVerilog usando
Verilator e executa os programas de teste de cada implementação:

- `riscv_harvard/` — processador com memórias separadas (ROM + RAM)
- `riscv_von_neumann/` — processador com memória unificada

**Dependências externas:**
- `verilator` — simulador de hardware
- `gcc-riscv64-unknown-elf` + `binutils-riscv64-unknown-elf` — toolchain RISC-V

**Tempo esperado:** ~120 segundos.

**Aviso sobre versão do Verilator:** o pacote `verilator` disponível via `apt`
no Ubuntu pode ser a versão 4.x, enquanto este projeto foi desenvolvido e
testado com Verilator 5.x. Se este job falhar com erros de parsing de
SystemVerilog, a causa provável é incompatibilidade de versão — não um bug no
RTL. A solução é compilar o Verilator 5.x a partir do código-fonte ou usar
uma GitHub Action que instale a versão correta.

---

## Como ver os resultados no GitHub

1. Acesse a aba **Actions** do repositório.
2. Clique no workflow **"CI — RISC-V RV32I"**.
3. Selecione a execução correspondente ao seu commit ou PR.
4. Expanda cada job para ver os logs detalhados de cada step.

O badge no `README.md` principal mostra o status da branch `main` em tempo
real.

---

## Diagnóstico de falhas comuns

### Job 1 falha (`simulator`)

**Causa mais provável:** bug no simulador Python introduzido por uma edição
recente em `simulator/`.

**Como investigar:**
- Leia a saída do step "Executar testes do simulador" — ela mostrará qual
  teste falhou e a diferença entre o resultado esperado e o obtido.
- Reproduza localmente: `python3 simulator/tests/test_core.py`

---

### Job 2 falha (`gabaritos`)

**Causa mais provável (A):** erro de sintaxe em um arquivo de gabarito
Assembly (`.s`) de algum exercício da lista.

**Causa mais provável (B):** incompatibilidade de versão do toolchain
`binutils-riscv64-unknown-elf` do apt com alguma pseudo-instrução usada nos
gabaritos.

**Como investigar:**
- Leia a saída do step "Verificar gabaritos" para identificar qual exercício
  falhou.
- Reproduza localmente (com toolchain instalado):
  `python3 exercicios/verifica_gabaritos.py`

---

### Job 3 falha (`hardware`)

**Causa mais provável (A):** bug de SystemVerilog introduzido no RTL em
`riscv_harvard/src/` ou `riscv_von_neumann/src/`.

**Causa mais provável (B):** incompatibilidade de versão do Verilator — o apt
pode fornecer a versão 4.x, mas o projeto requer 5.x. Nesse caso, o step
"Verificar versão do Verilator" mostrará a versão instalada, e os erros serão
de parsing de SystemVerilog (não de lógica do design).

**Como investigar:**
- Verifique a versão do Verilator no log do step "Verificar versão do
  Verilator".
- Reproduza localmente: `cd riscv_harvard && make all` e
  `cd riscv_von_neumann && make all`

---

## Como rodar localmente sem o CI

Para validar rapidamente antes de fazer push:

```bash
# Job 1 — Simulador Python (sem dependências externas)
python3 simulator/tests/test_core.py

# Job 2 — Gabaritos (requer toolchain RISC-V instalado)
python3 exercicios/verifica_gabaritos.py

# Job 3 — Hardware (requer Verilator 5.x e toolchain RISC-V)
cd riscv_harvard && make all
cd ../riscv_von_neumann && make all
```

Ou todos de uma vez:

```bash
python3 simulator/tests/test_core.py && python3 exercicios/verifica_gabaritos.py
```

---

## Estrutura do diretório `.github/workflows/`

```
.github/
└── workflows/
    ├── ci.yml       # Definição do workflow de CI
    └── README.md    # Este arquivo
```
