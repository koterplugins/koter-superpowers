---
name: koter-gestao-financeiro
description: Organiza o financeiro da corretora no Koter — contas bancárias, plano de contas, centros de custo, favorecidos, contas a pagar e a receber — e mostra o resultado no DRE e no fluxo de caixa. Use quando falarem de caixa, despesa, conta a pagar, conta a receber, plano de contas, DRE, centro de custo ou fluxo de caixa.
---

# koter-gestao-financeiro

Quinta etapa da trilha. Depende só da fundação — **não espere comissão para começar o financeiro**, são trilhas paralelas.

## 0 · A primeira coisa: o plano de contas já existe

Numa conta zerada o Koter **já traz o plano de contas pronto**: 23 categorias com grupo de DRE definido, confirmado na Koter Day. Entre elas, três que são a contrapartida direta do módulo de comissão:

- **Comissões recebidas** (`RECEITA_OPERACIONAL`)
- **Repasses a vendedores** (`DESPESAS_COMERCIAIS`)
- **Reembolso de empréstimos a vendedores** (`OUTRAS_RECEITAS`)

E folha inteira já marcada com `isPayroll`: Salários, Encargos, Benefícios, Pró-labore, Prestadores de serviço.

**Então a pergunta nunca é "vamos montar seu plano de contas".** É: *"Seu plano de contas já veio pronto, com 23 contas. Falta alguma coisa que você gasta e não está aqui?"* Montar do zero o que já existe é a forma mais rápida de perder o corretor no passo 1.

## 1 · Detecção

```
gestao_financeiro_fetch_finance_context(include?)   → numa chamada só:
    bankAccounts   → normalmente vazio; é o que realmente falta
    categories     → o plano pronto
    costCenters, payees
gestao_financeiro_list_finance_recurrences
```

Na Koter Day: 23 categorias, **nenhuma conta bancária**. Esse é o retrato típico — o que falta é a conta, não o plano.

## 2 · Conta bancária — o passo que destrava o resto

```
gestao_financeiro_save_bank_account(name, kind, bankName, bankCode, agency, accountNumber,
                                    initialBalance, initialBalanceDate)   ← sem bankAccountId cria
```

`kind`: `CORRENTE`, `POUPANCA` ou `CAIXA` — **`CAIXA` é para o dinheiro que não passa em banco**, e quase toda corretora pequena tem um.

**`initialBalance` é o que faz o fluxo de caixa dizer a verdade.** Ele vira a `base` do relatório: sem saldo inicial, o fluxo mostra a variação e não o dinheiro que ele tem. Pergunte o saldo do dia em que ele quer começar a contar, e a data junto.

## 3 · Favorecidos — puxe do que já existe

```
gestao_financeiro_save_finance_payee(fromSellerId)   ← só fromSellerId; idempotente: reaproveita se já existir
gestao_financeiro_save_finance_payee(name, kind, ...)   ← os demais
```

Vendedor não se cadastra duas vezes: com `fromSellerId` a tool herda nome e documento e devolve o favorecido existente se já houver (todo vendedor já aparece como favorecido `VENDEDOR` em `payees`). Use esse caminho para todo mundo que já é vendedor antes de criar qualquer favorecido à mão.

## 4 · Lançamentos

```
gestao_financeiro_save_finance_entry     ← sem entryId cria
  direction: PAGAR | RECEBER
  description, categoryId, amount
  dueDate                ← obrigatório no avulso
  installments: { count, firstDueDate }   ← série parcelada; substitui dueDate
  bankAccountId, payeeId, competenceDate, costCenterIds, notes
```

- **Parcelado é `installments`**, não vários lançamentos: 2 a 120 parcelas regidas por `firstDueDate`.
- **`competenceDate` é diferente de `dueDate`** — competência é o mês a que a despesa pertence, vencimento é quando ela é paga. Quem quer DRE honesto usa os dois.
- **`costCenterIds` só vale em despesa** (`PAGAR`), e o rateio é igualitário entre os centros informados.
- Conta que se repete todo mês é `save_finance_recurrence`, não lançamento copiado.

## 5 · A regra que evita contar dinheiro duas vezes

**Não lance comissão à mão no financeiro.** O DRE e o fluxo de caixa já recebem a comissão do próprio módulo, em linhas separadas: o DRE traz um bloco `commission` com receita, repasse, imposto e margem; o fluxo de caixa separa `commissionReceivableProjected` / `commissionPayoutProjected` de `entriesInflowProjected` / `entriesOutflowProjected`.

Comprovado na Koter Day: um lançamento a receber criado na categoria "Comissões recebidas" caiu em `entriesInflowProjected`, **somando ao que o módulo de comissão já projeta por conta própria**. O financeiro é para o que não é comissão — aluguel, software, folha, impostos, consultoria.

## 6 · Os relatórios — e os parâmetros que enganam

Os três saem de uma tool só, `gestao_financeiro_get_finance_report(report, ...)` — e parâmetro de outro relatório é recusado:

| `report` | Parâmetros | Detalhe |
|---|---|---|
| `dre` | **`year`** (número), `regime?` | não aceita `from`/`to` |
| `cash_flow` | **`from` / `to`** (ISO), `granularity?`, `bankAccountId?` | não aceita `year` |
| `cost_center` | `from` / `to`, `regime?` | rateio por centro |

**O DRE é regime de caixa por padrão** (`regime: "caixa"`): só entra o que foi liquidado. Comprovado — a despesa dada baixa apareceu no mês; o a receber pendente, não. Diga isso ao corretor, porque ele vai estranhar não ver o que está a receber. Se ele quiser a visão por competência, `regime: "competencia"` traz os lançamentos não cancelados, pagos ou não.

O fluxo de caixa, ao contrário, separa **realizado** de **projetado** e parte da `base` (a soma dos saldos iniciais). É nele que o pendente aparece.

## 7 · Validação e próxima

Feche mostrando o número, não a configuração:

> "Conta principal com R$ 10.000 de saldo inicial, uma despesa de R$ 499 já baixada, e o fluxo projetando R$ 12.201 no fim de novembro."

Depois:

- **`koter-gestao-baixa-parcelas`** — a rotina de dar baixa, feita junto com ele *(recomendada)*
- `koter-gestao-conciliacao` — bater o extrato do banco
- `koter-gestao-comissoes` — se ainda não fez
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Fluxo de caixa começa do zero | conta sem `initialBalance` | informe saldo e data |
| DRE não mostra o a receber | DRE é regime de caixa por padrão | use o fluxo de caixa, ou `regime: "competencia"` |
| `get_finance_report` (`dre`) recusa o período | ele quer `year`, não `from`/`to` | e o `cash_flow` é o contrário |
| Comissão aparece dobrada | lançada à mão além do módulo | financeiro só para o que não é comissão |
| Vendedor duplicado como favorecido | criado à mão | `save_finance_payee` com `fromSellerId` |
| Centro de custo recusado | só vale em `PAGAR` | rateio é de despesa |
