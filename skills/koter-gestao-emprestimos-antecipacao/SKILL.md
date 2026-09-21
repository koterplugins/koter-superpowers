---
name: koter-gestao-emprestimos-antecipacao
description: Registra empréstimos a vendedores e antecipações de repasse no Koter, com juros, modo de cobrança, suspensão, perdão e cancelamento. Use quando falarem de adiantar comissão, emprestar dinheiro para vendedor, vale, antecipação de repasse, deságio ou desconto em folha do vendedor.
---

# koter-gestao-emprestimos-antecipacao

Nona etapa. Existe porque **"me adianta aí" na boca do vendedor pode ser duas coisas diferentes**, e o tratamento contábil de cada uma é outro.

## 1 · A distinção, antes de qualquer tool

| | Antecipação de repasse | Empréstimo ao vendedor |
|---|---|---|
| O que é | comissão que **já é dele**, paga antes da data | dinheiro da casa, que **não é comissão** |
| O que acontece | a parcela é re-datada e entra no lote, com deságio abatido no item | vira dívida amortizada nos lotes seguintes |
| Tools | `schedule_installment_payout_advance`, `cancel_installment_payout_advance` | `create_seller_loan` e família |

**Pergunte uma linha antes de escolher:** *"É comissão dele que ainda não venceu, ou é dinheiro da casa?"* Errar aqui faz a corretora emprestar o que já devia, ou descontar duas vezes.

## 2 · Antecipação

```
gestao_comissao_schedule_installment_payout_advance(installmentIds, date?, discountPercent?)
```

- **Agendar não é pagar.** O repasse continua `PENDENTE`, só muda de data — e entra no lote da rodada escolhida. Antecipação nunca sai por fora do lote.
- **O deságio é congelado na parcela** no momento do agendamento. `discountPercent` omitido aplica o default da corretora (`advanceDiscountPercent`); `null` ou `0` é sem deságio.
- Re-marcar uma parcela já agendada **atualiza data e deságio**. Parcelas com repasse já resolvido são puladas em silêncio — confira depois.
- `cancel_installment_payout_advance` desfaz, re-ancora a data na rotina e **tira o item dos lotes abertos**.

Quem pode antecipar é decidido por vendedor, em `allowsPayoutAdvance`.

**A antecipação é a resposta para "eu pago antes de receber".** O Koter é sobre o recebido por construção; a antecipação é a válvula, e configurar um deságio padrão é o que torna isso sustentável.

## 3 · Empréstimo

```
gestao_comissao_create_seller_loan(sellerId, principalAmount, loanDate, interestPercent?,
                                   chargeMode, capAmount?, capWindow?, retentionPercent?, schedule?)
```

**Os juros são um percentual único congelado na criação.** R$ 3.000 com 10% vira dívida de R$ 3.300 — confirmado na Koter Day (`interestAmount: 300`, `totalAmount: 3300`). Não é juros ao mês; não prometa que é.

Três modos de cobrança, e a escolha muda a experiência do vendedor:

| `chargeMode` | Como desconta | Quando usar |
|---|---|---|
| `CAP_AMOUNT` *(padrão)* | teto em R$ por janela (`capWindow`: `PER_MONTH` ou `PER_BATCH`) | "desconta até R$ 500 por mês" — o mais fácil de explicar |
| `PERCENT_OF_BATCH` | `retentionPercent` do bruto de cada lote até quitar | vendedor com renda variável |
| `FIXED_SCHEDULE` | parcelas com datas fixas | acordo formal |

**O desconto acontece sozinho nos lotes, e o vendedor nunca fica negativo:** a cascata limita ao disponível e o resíduo empurra para a rodada seguinte. Diga isso — é a pergunta que ele vai fazer.

Ciclo de vida: `register_seller_loan_payment` (pagamento por fora), `revert_seller_loan_payment`, `set_seller_loan_suspension` (pausa o desconto sem perdoar), `forgive_seller_loan` (perdoa saldo) e `cancel_seller_loan`.

**`forgive` e `cancel` são irreversíveis na prática.** Só com pedido explícito, na mesma conversa, e diga o saldo antes.

## 4 · A crítica que fecha o ciclo

`VENDEDOR_DESLIGADO_COM_DIVIDA` é uma das quatro críticas financeiras e nasce ligada. Vendedor que sai devendo aparece sozinho na fila — é o motivo de registrar empréstimo no sistema em vez de no WhatsApp.

## 5 · Validação e próxima

Mostre o saldo e o efeito no próximo lote:

> "Registrado: R$ 3.000 com 10% viram R$ 3.300, descontando até R$ 500 por mês. No lote de outubro ele recebe R$ 500 a menos."

Depois: `koter-gestao-repasse` para ver o desconto no lote, ou `koter-gestao-campanhas`.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Descontou duas vezes | adiantamento tratado como empréstimo | antecipação re-data a parcela; empréstimo cria dívida |
| Juros menores do que ele esperava | percentual único, congelado na criação | não é juros ao mês |
| Antecipação "não foi paga" | agendar ≠ pagar | ela entra no lote da rodada |
| Parcela ignorada no agendamento | repasse já resolvido | confira a lista depois |
| Vendedor ficou sem receber nada | desconto grande demais | a cascata limita ao disponível; reveja o teto |
