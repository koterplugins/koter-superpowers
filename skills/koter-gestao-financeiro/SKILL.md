---
name: koter-gestao-financeiro
description: Organiza o financeiro da corretora no Koter e mostra o resultado no DRE e no fluxo de caixa. Use quando falarem de caixa, despesa, conta a pagar ou a receber, plano de contas ou centro de custo.
---

# koter-gestao-financeiro

Quinta etapa da trilha. Depende só da fundação: **não espere comissão para começar o financeiro**, são trilhas paralelas.

## 0 · A primeira coisa: o plano de contas já existe

Numa conta nova o Koter **já traz o plano de contas pronto** (as categorias padrão são criadas na primeira leitura de `gestao_financeiro_fetch_finance_context`), com grupo de DRE definido. Entre elas, as que são contrapartida direta do módulo de comissão:

- **Comissões recebidas** (`RECEITA_OPERACIONAL`)
- **Repasses a vendedores** (`DESPESAS_COMERCIAIS`)
- **Reembolso de empréstimos a vendedores** (`OUTRAS_RECEITAS`)
- **Premiação de campanhas** e **Remuneração de seguradora** (`RECEITA_OPERACIONAL`), para o que a seguradora paga sem contrato: bônus de produção, PLR, campanha de carteira

E folha inteira já marcada com `isPayroll`: Salários, Encargos, Benefícios, Pró-labore, Prestadores de serviço.

**Então a pergunta nunca é "vamos montar seu plano de contas".** É: *"Seu plano de contas já veio pronto. Falta alguma coisa que você gasta e não está aqui?"* Conte as contas lendo `categories`. Montar do zero o que já existe é a forma mais rápida de perder o corretor no passo 1.

## 1 · Detecção

```
gestao_financeiro_fetch_finance_context(include?)   → numa chamada só:
    bankAccounts   → normalmente vazio; é o que realmente falta
                     (bankAccountPositions: computedBalance, ledgerBalance, payoutBatchesSum)
    categories     → o plano pronto
    costCenters, payees
gestao_financeiro_list_finance_recurrences
```

O retrato típico é plano pronto e **nenhuma conta bancária**: o que falta é a conta, não o plano.

## 2 · Conta bancária, o passo que destrava o resto

```
gestao_financeiro_save_bank_account(name, kind, bankName, bankCode, agency, accountNumber,
                                    initialBalance, initialBalanceDate)   ← sem bankAccountId cria
```

`kind`: `CORRENTE` (padrão), `POUPANCA` ou `CAIXA`. **`CAIXA` é para o dinheiro que não passa em banco**, e quase toda corretora pequena tem um.

**`initialBalance` é o que faz o fluxo de caixa dizer a verdade.** Ele vira a `base` do relatório: sem saldo inicial, o fluxo mostra a variação e não o dinheiro que ele tem. Pergunte o saldo do dia em que ele quer começar a contar, e a data junto.

## 3 · Favorecidos: puxe do que já existe

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
- **`competenceDate` é diferente de `dueDate`**: competência é o mês a que a despesa pertence, vencimento é quando ela é paga. Quem quer DRE honesto usa os dois.
- **`costCenterIds` só vale em despesa** (`PAGAR`), e o rateio é igualitário entre os centros informados.
- Conta que se repete todo mês é `gestao_financeiro_save_finance_recurrence`, não lançamento copiado.
- **Para listar só contas, mande `source: "ENTRY"`** em `gestao_financeiro_list_finance_entries`. O padrão é `ALL`, que mistura as linhas de comissão, e elas não são lançamentos.
- Trazendo histórico de outro sistema, use o alvo `FINANCE_ENTRIES` da `koter-importacao`.

## 5 · A regra que evita contar dinheiro duas vezes

**Não lance comissão à mão no financeiro.** O DRE e o fluxo de caixa já recebem a comissão do próprio módulo, em linhas separadas: o DRE traz um bloco `commission` com receita, repasse, imposto e margem; o fluxo de caixa detalha por origem, separando lançamentos de recebimento e repasse de comissão.

Um lançamento a receber criado na categoria "Comissões recebidas" conta como lançamento, **somando ao que o módulo de comissão projeta por conta própria**. O financeiro é para o que não é comissão: aluguel, software, folha, impostos, consultoria.

Duas exceções que nascem sozinhas, e que você não cria:

- **Repasse externo** (estipulante, cocorretor e indicador de fora): vira lançamento `PAGAR` depois da conferência. Só liquida pelo valor inteiro, e é recusado enquanto retido. `koter-contrato` explica quem é externo.
- **A receber da seguradora sem contrato**: bônus e PLR nascem a partir da baixa (`koter-gestao-repasse`), e o prêmio de campanha por `gestao_comissao_create_campaign_receivable`.

## 6 · Os relatórios, e os parâmetros que enganam

Os três saem de uma tool só, `gestao_financeiro_get_finance_report(report, ...)`, e parâmetro de outro relatório é recusado:

| `report` | Parâmetros | Detalhe |
|---|---|---|
| `dre` | **`year`** (número), `regime?` | não aceita `from`/`to` |
| `cash_flow` | **`from` / `to`** (ISO), `granularity?`, `bankAccountId?` | não aceita `year` |
| `cost_center` | `from` / `to`, `regime?` | rateio por centro |

**O DRE é regime de caixa por padrão** (`regime: "caixa"`): só entra o que foi liquidado. A despesa dada baixa aparece no mês; o a receber pendente, não. Diga isso ao corretor, porque ele vai estranhar não ver o que está a receber. Se ele quiser a visão por competência, `regime: "competencia"` traz os lançamentos não cancelados, pagos ou não, pela data de competência (ou de vencimento), e, no DRE, as comissões entram pelo vencimento da parcela.

O fluxo de caixa, ao contrário, separa **realizado** de **projetado** e parte da `base` (os saldos iniciais das contas ativas mais o realizado antes do primeiro período). É nele que o pendente aparece. Com `bankAccountId`, as comissões ficam de fora, porque não têm conta.

**Folha depende de permissão:** sem a permissão de ver folha, os lançamentos de folha somem do fluxo de caixa e do relatório por centro de custo, e no DRE viram uma linha só, "Pessoal". Se o número de quem pergunta não bate com o do dono, é isso.

## 7 · Validação e próxima

Feche mostrando o número, não a configuração:

> "Conta principal com R$ 10.000 de saldo inicial, uma despesa de R$ 499 já baixada, e o fluxo projetando R$ 12.201 no fim de novembro."

Depois:

- **`koter-gestao-baixa-parcelas`**: a rotina de dar baixa, feita junto com ele *(recomendada)*
- `koter-gestao-conciliacao`: bater o extrato do banco
- `koter-gestao-comissoes`: se ainda não fez
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Fluxo de caixa começa do zero | conta sem `initialBalance` | informe saldo e data |
| DRE não mostra o a receber | DRE é regime de caixa por padrão | use o fluxo de caixa, ou `regime: "competencia"` |
| `gestao_financeiro_get_finance_report` (`dre`) recusa o período | ele quer `year`, não `from`/`to` | e o `cash_flow` é o contrário |
| Comissão aparece dobrada | lançada à mão além do módulo | financeiro só para o que não é comissão |
| Vendedor duplicado como favorecido | criado à mão | `gestao_financeiro_save_finance_payee` com `fromSellerId` |
| Centro de custo recusado | só vale em `PAGAR` | rateio é de despesa |
| "4 contas vencendo" que não são contas | `gestao_financeiro_list_finance_entries` com `source` padrão soma comissão | mande `source: "ENTRY"` |
| Baixa de repasse externo recusada | repasse retido, ou valor parcial | espere a liberação, e liquide pelo valor inteiro |

## Conferência

Tools, parâmetros e categorias padrão conferidos no inventário e lidos no código em 03/11/2026, não executados.
O detalhamento do fluxo de caixa por origem vem da leitura do código. Nenhum relatório foi rodado com o motor atual de comissão.
