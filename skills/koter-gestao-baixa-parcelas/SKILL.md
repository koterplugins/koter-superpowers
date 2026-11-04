---
name: koter-gestao-baixa-parcelas
description: Dá baixa em contas a pagar e a receber no financeiro do Koter, com estorno e cancelamento. Use quando falarem de dar baixa em conta ou marcar como pago. Baixa de comissão fica no repasse.
---

# koter-gestao-baixa-parcelas

A skill do dia a dia do financeiro. **Ela não descreve a tela: dá a primeira baixa junto com ele**, num lançamento real, e só depois explica o resto.

## 0 · Pré-requisitos

`koter-gestao-financeiro`: conta bancária e ao menos um lançamento. Sem isso, não há o que baixar, e a skill deve dizer isso em vez de ensinar no vazio.

## 1 · Comece pelo que está vencendo

```
gestao_financeiro_list_finance_entries(source: "ENTRY", status: "PENDENTE", ...)
```

**Mande sempre `source: "ENTRY"`.** O padrão é `ALL`, que devolve também as linhas de comissão (`source: COMMISSION`, com `rowKind: SELLER_DEBIT` nos débitos do vendedor). Sem o filtro, o "4 contas vencendo" soma comissão, e a baixa dessas linhas falha, porque elas não são lançamentos.

Abra com o retrato, não com a explicação:

> "Você tem 4 contas vencendo esta semana, R$ 3.120 no total. Quer dar baixa na primeira agora comigo?"

Fazer junto é o ponto da skill. Um corretor que deu uma baixa não precisa que ninguém explique a segunda.

## 2 · Dar baixa

```
gestao_financeiro_settle_finance_entries(items[{ entryId, bankAccountId?, date?, settledAmount? }])
```

- `settledAmount` **omitido usa o valor do lançamento**. Informe-o só quando o valor pago foi outro, e diga em voz alta que ficou diferente: a diferença pode virar divergência **na conciliação com o banco**.
- `date` omitido é agora. Baixa retroativa é comum ("paguei semana passada"): pergunte a data quando o contexto sugerir.
- `bankAccountId` decide de qual conta saiu. Com mais de uma conta, nunca assuma.

O status vai de `PENDENTE` para `LIQUIDADO`, com `settledAmount` e `settledAt` preenchidos.

**Em lote:** a mesma tool, com vários `items` (até 500). Antes de rodar, **liste o que vai ser baixado e o total**, e peça o "pode dar baixa". Baixa em lote errada é chata de desfazer uma a uma. **O lote não é atômico**: cada item passa ou falha sozinho (`succeeded` / `failed`). Lançamento cancelado ou já liquidado falha, e o resto segue. Diga o que ficou de fora.

**Lançamento de repasse a participante externo** (estipulante, cocorretor, indicador de fora) só liquida pelo valor inteiro e é recusado enquanto o repasse estiver retido, com a mensagem do motivo. Editar, excluir ou cancelar esse lançamento também é recusado.

## 3 · Estornar ≠ cancelar

Os dois desfazem coisas diferentes, e confundir bagunça o DRE:

Os três são `gestao_financeiro_undo_finance_entry(entryId, mode)`:

| `mode` | O que faz | Quando |
|---|---|---|
| `reverse` | desfaz a **baixa**: volta para `PENDENTE`, limpa `settledAmount`/`settledAt`, **o lançamento continua existindo e devido** | baixou errado, baixou na conta errada, baixou o valor errado |
| `cancel` | cancela o **lançamento** em aberto: a dívida deixa de existir (fica como `CANCELADO`); com `deactivateRecurrence: true`, também para a recorrência de onde ele veio | a conta não vai mais ser paga (contrato cancelado, cobrança indevida) |
| `delete` | apaga o registro em aberto, desde que nenhuma transação bancária o referencie | erro de digitação, lançamento que nunca deveria existir |

Lançamento liquidado não se cancela nem se exclui: estorne primeiro. E se ele estiver conciliado, `gestao_financeiro_unreconcile_bank_transaction` vem antes do estorno.

**Nunca escolha por ele.** Pergunte em uma linha: *"A conta continua devida, ou ela não existe mais?"* A resposta escolhe o `mode`.

## 4 · O histórico é a defesa

```
gestao_financeiro_list_finance_entries(ids: [entryId], include: ["history"])
```

Toda baixa, estorno e alteração fica registrada. Quando o corretor disser "eu não mexi nisso", é aqui que se resolve, não na memória.

## 5 · Comissão é outra coisa

**Há dois "dar baixa" no Koter, e eles não se encontram:**

| | Lançamento financeiro | Comissão |
|---|---|---|
| O que é | conta a pagar ou a receber da corretora | expectativa que um pagador deve, com os repasses pendurados |
| Onde vive | `gestao_financeiro_*` | `gestao_comissao_*` |
| Baixa | esta skill | `koter-gestao-repasse` |

Esta skill baixa **lançamento**. Baixar comissão à mão como lançamento financeiro conta o dinheiro duas vezes, porque o DRE e o fluxo de caixa já recebem a comissão do próprio módulo. Cuidado com dupla contagem também ao lançar à mão um dinheiro que já entrou por extrato de comissão.

**Quando o corretor disser "dei baixa e o vendedor não recebeu"**, a pergunta é qual das duas baixas ele deu. Se foi a de comissão, diagnostique (precisa do toolset `gestao-comissao` e, para achar o contrato, de `gestao-contratos`):

```
gestao_comissao_get_contract_commission_status(contractId)
  allGood false e pendências      → falta dado ou regra
  schedule zerado                 → acompanhamento desligado, ou cálculo ainda na fila
  pendingConference.count > 0     → baixou e não conferiu: gestao_comissao_save_lot_conference
gestao_comissao_list_commission_expectations(contractId)
  payout.shares[].status PAYABLE  → conferido, espera a rodada
  heldReason preenchido           → retido por inadimplência ou estorno
```

Mande para `koter-gestao-repasse` em vez de improvisar um lançamento financeiro. Se a venda nem tem contrato, o caminho começa em `koter-contrato`.

## 6 · Validação e próxima

Releia o lançamento e o saldo, e diga o efeito em dinheiro:

> "Baixada: R$ 499 saíram da Conta principal em 21/09. Saldo projetado de novembro: R$ 12.201."

Depois:

- **`koter-gestao-conciliacao`** para deixar o banco conferir isso sozinho *(recomendada)*
- `koter-gestao-repasse` para pagar o time
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Lista soma mais do que as contas dele | `source` no padrão `ALL` trouxe comissão | `source: "ENTRY"` |
| Baixa falha numa linha da lista | linha de comissão (`source: COMMISSION`) não é lançamento | mande para `koter-gestao-repasse` |
| Baixa saiu da conta errada | `bankAccountId` assumido | estorne e baixe de novo na conta certa |
| Valor liquidado diferente do lançado | `settledAmount` informado | é legítimo, mas pode virar divergência na conciliação |
| Repasse externo não liquida | retido, ou valor diferente do inteiro | o motivo vem na mensagem; só pelo valor inteiro |
| "Cancelei e a dívida sumiu" | `cancel` ≠ `reverse` | estorno mantém a dívida |
| DRE não mudou depois da baixa | no regime de caixa (o padrão) o DRE usa a data da liquidação | confira `date` |
| Comissão contada duas vezes | baixa manual de comissão como lançamento | conciliação e lote de repasse; cuidado com dupla contagem |

## Conferência

`gestao_financeiro_settle_finance_entries`, `gestao_financeiro_undo_finance_entry` e o filtro `source` de `gestao_financeiro_list_finance_entries` lidos no código em 03/11/2026, não executados nesta reescrita.
O estorno que devolve o lançamento a `PENDENTE` com o valor intacto foi executado antes, numa corretora de demonstração. O diagnóstico do §5 vem do código, sem execução.
