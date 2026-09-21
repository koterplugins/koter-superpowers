---
name: koter-gestao-baixa-parcelas
description: Ensina e executa a rotina de dar baixa no financeiro do Koter — liquidar um lançamento, liquidar em lote, estornar e cancelar — fazendo a primeira baixa junto com o corretor. Use quando falarem de dar baixa, marcar como pago ou recebido, liquidar parcela, estornar baixa ou cancelar lançamento.
---

# koter-gestao-baixa-parcelas

A skill do dia a dia do financeiro. **Ela não descreve a tela: dá a primeira baixa junto com ele**, num lançamento real, e só depois explica o resto.

## 0 · Pré-requisitos

`koter-gestao-financeiro`: conta bancária e ao menos um lançamento. Sem isso, não há o que baixar — e a skill deve dizer isso em vez de ensinar no vazio.

## 1 · Comece pelo que está vencendo

```
gestao_financeiro_list_finance_entries(status: "PENDENTE", ...)
```

Abra com o retrato, não com a explicação:

> "Você tem 4 contas vencendo esta semana, R$ 3.120 no total. Quer dar baixa na primeira agora comigo?"

Fazer junto é o ponto da skill. Um corretor que deu uma baixa não precisa que ninguém explique a segunda.

## 2 · Dar baixa

```
gestao_financeiro_settle_finance_entry(entryId, bankAccountId?, date?, settledAmount?)
```

- `settledAmount` **omitido usa o valor do lançamento**. Informe-o só quando o valor pago foi outro — e aí diga em voz alta que ficou diferente, porque é isso que gera crítica de valor divergente depois.
- `date` omitido é agora. Baixa retroativa é comum ("paguei semana passada") — pergunte a data quando o contexto sugerir.
- `bankAccountId` decide de qual conta saiu. Com mais de uma conta, nunca assuma.

O status vai de `PENDENTE` para `LIQUIDADO`, com `settledAmount` e `settledAt` preenchidos.

**Em lote:** `gestao_financeiro_settle_finance_entries_bulk`. Antes de rodar, **liste o que vai ser baixado e o total**, e peça o "pode dar baixa". Baixa em lote errada é chata de desfazer uma a uma.

## 3 · Estornar ≠ cancelar

Os dois desfazem coisas diferentes, e confundir bagunça o DRE:

| Tool | O que faz | Quando |
|---|---|---|
| `reverse_finance_entry` | desfaz a **baixa**: volta para `PENDENTE`, limpa `settledAmount`/`settledAt`, **o lançamento continua existindo e devido** | baixou errado, baixou na conta errada, baixou o valor errado |
| `cancel_finance_entry` | cancela o **lançamento**: a dívida deixa de existir | a conta não vai mais ser paga (contrato cancelado, cobrança indevida) |
| `delete_finance_entry` | apaga o registro | erro de digitação, lançamento que nunca deveria existir |

Comprovado na Koter Day: o estorno devolveu o lançamento a `PENDENTE` com os campos de liquidação zerados e o valor intacto.

**Nunca escolha por ele.** Pergunte em uma linha: *"A conta continua devida, ou ela não existe mais?"* — a resposta escolhe a tool.

## 4 · O histórico é a defesa

```
gestao_financeiro_get_finance_entry_history(entryId)
```

Toda baixa, estorno e alteração fica registrada. Quando o corretor disser "eu não mexi nisso", é aqui que se resolve — não na memória.

## 5 · Parcela de comissão é outra coisa — e agora também tem tool

**Há dois "dar baixa" no Koter, e eles não se encontram:**

| | Lançamento financeiro | Parcela de comissão |
|---|---|---|
| O que é | conta a pagar ou a receber da corretora | a parcela da venda, que gera recebível e repasse |
| Onde vive | `gestao_financeiro_*` | `gestao_comissao_*` (motor de comissão) |
| Baixa por MCP | **sim**, é esta skill | **sim**, é a `koter-gestao-repasse` |

Esta skill baixa **lançamento**, não parcela. Baixar comissão à mão como lançamento financeiro conta o dinheiro duas vezes, porque o DRE e o fluxo de caixa já recebem a comissão do próprio módulo.

**Quando o corretor disser "dei baixa e o vendedor não recebeu"**, a pergunta é qual das duas baixas ele deu. A do repasse é outra rotina:

```
gestao_comissao_list_proposal_installments(proposalId)   → lista vazia = parcelas nem geradas
gestao_comissao_generate_proposal_installments(proposalId)
gestao_comissao_set_installment_receivable_status(installmentId, "RECEBIDA")
gestao_comissao_mark_installments_received(installmentIds)   → em lote
```

Só depois disso a parcela entra no lote de repasse. Mande para `koter-gestao-repasse` em vez de improvisar um lançamento financeiro.

## 6 · Validação e próxima

Releia o lançamento e o saldo, e diga o efeito em dinheiro:

> "Baixada: R$ 499 saíram da Conta principal em 21/09. Saldo projetado de novembro: R$ 12.201."

Depois:

- **`koter-gestao-conciliacao`** — deixar o banco conferir isso sozinho *(recomendada)*
- `koter-gestao-repasse` — pagar o time
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Baixa saiu da conta errada | `bankAccountId` assumido | estorne e baixe de novo na conta certa |
| Valor liquidado diferente do lançado | `settledAmount` informado | é legítimo, mas gera crítica de divergência |
| "Cancelei e a dívida sumiu" | `cancel` ≠ `reverse` | estorno mantém a dívida |
| DRE não mudou depois da baixa | DRE é regime de caixa e usa a data da liquidação | confira `date` |
| Comissão contada duas vezes | baixa manual de comissão | conciliação e lote de repasse |
