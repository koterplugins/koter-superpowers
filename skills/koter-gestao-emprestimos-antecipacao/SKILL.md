---
name: koter-gestao-emprestimos-antecipacao
description: Registra antecipação de repasse, empréstimo a vendedor e trata débito de estorno, com deságio e perdão. Use quando falarem de adiantar comissão, vale, emprestar para vendedor ou perdoar dívida.
---

# koter-gestao-emprestimos-antecipacao

Nona etapa. Existe porque **"me adianta aí" e "me perdoa essa dívida" na boca do vendedor podem ser coisas diferentes**, e o tratamento de cada uma é outro.

## 1 · A distinção, antes de qualquer tool

| | Antecipação de repasse | Empréstimo ao vendedor | Débito de estorno |
|---|---|---|---|
| O que é | comissão que **vai ser dele**, paga antes de a corretora receber | dinheiro da casa, que **não é comissão** | comissão que voltou ao pagador depois de paga ao vendedor |
| O que acontece | o repasse vira a pagar na data e entra no lote, com deságio abatido | vira dívida amortizada nos lotes seguintes | é recuperado nos lotes seguintes, até o teto |
| Tools | `gestao_comissao_save_payout_share_advance` | `gestao_comissao_save_seller_loan` e família | `gestao_comissao_save_seller_debit_waiver`, `gestao_comissao_save_seller_debt_adjustment` |

**Pergunte uma linha antes de escolher:** *"É comissão dele que ainda não entrou, é dinheiro da casa, ou é estorno de venda que caiu?"* Errar aqui faz a corretora emprestar o que já devia, ou descontar duas vezes.

## 2 · Antecipação

```
gestao_comissao_save_payout_share_advance(payoutShareIds, date?, discountPercent?)   ← agenda
gestao_comissao_save_payout_share_advance(payoutShareIds, cancel: true)              ← cancela
```

O id sai de `gestao_comissao_list_commission_expectations(sellerId, statuses: ["PROJECTED"])`, em `payout.shares[].id`, ou de `gestao_comissao_get_seller_payout_statement`, em `payoutShareId`.

**A regra que muda o conselho: só antecipa repasse de comissão ainda intocada.** Expectativa `PROJECTED`, sem nenhum valor baixado. Depois do primeiro recebimento, nem agendar nem mudar data ou deságio: `A comissão deste repasse já começou a ser recebida, então ele não pode mais ser antecipado.`

- **Agendar não é pagar.** O repasse vira a pagar na data escolhida e entra no lote. Antecipação nunca sai por fora do lote.
- **O deságio é congelado no repasse** no agendamento e vai como desconto por item no lote. `discountPercent` omitido aplica o padrão da corretora (`advanceDiscountPercent`); `null` ou `0` é sem deságio.
- Agendar de novo, antes do primeiro recebimento, **atualiza data e deságio**.
- **`skipped` traz o motivo de cada repasse.** Só é erro quando nenhum passa. Confira depois e diga o que ficou de fora.
- `cancel: true` não aceita `date` nem `discountPercent`, e o repasse volta a esperar o recebimento. Em repasse já em lote ou pago, volta em `skipped`: desfaça o lote com `gestao_comissao_undo_payout_batch` antes.
- Se o repasse morre (cancelamento do contrato, novo cálculo), a antecipação morre junto.

Quem pode antecipar é decidido por vendedor, em `allowsPayoutAdvance`.

**A antecipação responde a "eu pago antes de receber", com ressalva:** só antes do primeiro recebimento. Quem paga sempre antes tem alternativa melhor na própria tabela: repasse com base `COMMISSION_EXPECTED` ou `PREMIUM_NET`, em `koter-gestao-comissoes`. Atenção: repasse dessas bases só libera com a expectativa quitada, e cada caminho muda quando o dinheiro sai.

## 3 · Empréstimo

```
gestao_comissao_save_seller_loan(sellerId, principalAmount, loanDate, interestPercent?,
                                 chargeMode?, capAmount?, capWindow?, retentionPercent?, schedule?)   ← sem loanId cria
```

Com `loanId` edita um empréstimo ativo: modo de cobrança, teto, janela, retenção e cronograma mudam a qualquer hora e valem para as próximas rodadas; **principal, juros e data só até a primeira amortização** (por lote ou avulsa).

**Os juros são um percentual único congelado na criação.** R$ 3.000 com 10% vira dívida de R$ 3.300. Não é juros ao mês; não prometa que é.

Três modos de cobrança, e a escolha muda a experiência do vendedor:

| `chargeMode` | Como desconta | Quando usar |
|---|---|---|
| `CAP_AMOUNT` *(padrão)* | teto em R$ (`capAmount`, obrigatório neste modo) por janela (`capWindow`: `PER_MONTH` ou `PER_BATCH`) | "desconta até R$ 500 por mês", o mais fácil de explicar |
| `PERCENT_OF_BATCH` | `retentionPercent` do bruto de cada lote até quitar | vendedor com renda variável |
| `FIXED_SCHEDULE` | parcelas com datas fixas, em `schedule` | acordo formal |

**O desconto acontece sozinho nos lotes, e o vendedor nunca fica negativo:** a cascata limita ao disponível e o resíduo empurra para a rodada seguinte. Diga isso: é a pergunta que ele vai fazer.

Ciclo de vida, todos com prefixo `gestao_comissao_`:

- `gestao_comissao_list_seller_loans` lista com saldo devedor; com `ids`, dá o extrato completo do empréstimo, com amortizações por lote, pagamentos avulsos e perdão.
- `gestao_comissao_register_seller_loan_payment` é o pagamento por fora: por padrão já gera a receita liquidada no financeiro, na categoria "Reembolso de empréstimos a vendedores". Se houver lote aberto com amortização proposta, a resposta avisa para atualizar a coleta do lote.
- `gestao_comissao_revert_seller_loan_payment`: desfaça a conciliação antes, se a receita estiver conciliada.
- `gestao_comissao_save_seller_loan` com `loanId` e `suspended: true` + `suspensionReason` pausa o desconto sem perdoar; `false` retoma.
- `gestao_comissao_end_seller_loan` com `mode: "forgive"` perdoa o saldo; com `mode: "cancel"` serve para criado por engano, só antes de qualquer amortização e sem linha proposta em lote aberto. `reason` obrigatório nos dois.

**`forgive` e `cancel` são irreversíveis na prática.** Só com pedido explícito, na mesma conversa, e diga o saldo antes.

## 4 · Débito de estorno

Venda caiu depois de o vendedor receber? O repasse pago vira débito, recuperado nos lotes seguintes até o teto (`chargebackRecoveryCapPercent` da corretora, ou o do vendedor). Quem cria o débito é o estorno: o cancelamento se registra em `koter-contrato`, a confirmação fica em `koter-gestao-repasse`, e aqui se resolve a dívida.

```
gestao_comissao_get_seller_payout_statement(sellerId)     → debits, com debitId e a parte em aberto; debt
gestao_comissao_save_seller_debit_waiver(debitId, waived: true, amount?, reason)   ← abona um débito
gestao_comissao_save_seller_debit_waiver(debitId, waived: false, reason)           ← desfaz o abono
gestao_comissao_save_seller_debt_adjustment(sellerId, kind: "FORGIVE", amount?, reason)   ← perdoa a dívida toda
gestao_comissao_save_seller_debt_adjustment(sellerId, kind: "SETTLE", amount, reason)     ← ele devolveu
```

`gestao_comissao_save_seller_debt_adjustment` atua sobre a dívida somada, do débito mais antigo ao mais novo, e o valor não passa dela. Motivo obrigatório. Empréstimo perdoa com `gestao_comissao_end_seller_loan`, débito não: confira qual dos dois ele quer antes.

## 5 · A crítica que fecha o ciclo

`VENDEDOR_DESLIGADO_COM_DIVIDA` é uma das oito críticas financeiras configuráveis, e nasce ligada. Vendedor que sai devendo aparece sozinho na fila: é o motivo de registrar empréstimo no sistema em vez de no WhatsApp.

## 6 · Validação e próxima

Mostre o saldo e o efeito no próximo lote:

> "Registrado: R$ 3.000 com 10% viram R$ 3.300, descontando até R$ 500 por mês. No lote de outubro ele recebe R$ 500 a menos."

Depois: `koter-gestao-repasse` para ver o desconto no lote, ou `koter-gestao-campanhas`.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Descontou duas vezes | adiantamento tratado como empréstimo | antecipação mexe no repasse; empréstimo cria dívida |
| Juros menores do que ele esperava | percentual único, congelado na criação | não é juros ao mês |
| Antecipação "não foi paga" | agendar ≠ pagar | ela entra no lote da rodada |
| `A comissão deste repasse já começou a ser recebida, então ele não pode mais ser antecipado.` | já houve recebimento | antecipação acabou; o repasse segue o caminho normal |
| Repasse em `skipped` | não é de vendedor interno, sem valor, fora de previsto, comissão começou a ser recebida, ou vendedor não permite | leia `reason` item a item |
| `cancel` volta em `skipped` | repasse já em lote ou pago | `gestao_comissao_undo_payout_batch` primeiro |
| Vendedor ficou sem receber nada | desconto grande demais | a cascata limita ao disponível; reveja o teto |
| "Nunca peguei empréstimo e estou devendo" | estorno virou débito | `debits` em `gestao_comissao_get_seller_payout_statement` |

## Conferência

`gestao_comissao_save_payout_share_advance`, `gestao_comissao_save_seller_debit_waiver`, `gestao_comissao_save_seller_debt_adjustment`, tools de empréstimo e mensagens de recusa lidos no código em 03/11/2026, não executados.
A conta de juros foi executada antes, numa corretora de demonstração; empréstimo não mudou de regra na virada do modelo de comissão, pelo código lido. A antecipação no modelo novo ainda não rodou.
