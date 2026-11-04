---
name: koter-gestao-repasse
description: Leva a comissão do recebimento ao pagamento do vendedor, com baixa, extrato, conferência e lote de repasse. Use quando falarem de fechar o mês, pagar vendedor, baixa de comissão ou estorno.
---

# koter-gestao-repasse

A peça que transforma comissão configurada em dinheiro pago. Sem ela, a skill de comissões termina numa planilha bonita e ninguém recebe.

**Nada aqui paga sozinho.** Uma varredura diária prepara o lote `AUTO` na data da cadência, mas nunca paga: o pagamento é sempre um ato manual, e é assim de propósito.

## 0 · Pré-requisitos, e o caminho do dinheiro

Comissão configurada (`koter-gestao-comissoes`) e vendedores cadastrados.

**Confira a conexão primeiro.** Chame `list_toolsets`: `gestao-comissao` e `gestao-contratos` precisam aparecer. Se faltar um deles, pare e peça para reconectar com o toolset na URL, porque conexão antiga não ganha a categoria sozinha. Em hospedeiro de conexão única, o pacote de dinheiro é `gestao,gestao-config,gestao-contratos,gestao-comissao,gestao-financeiro`.

**A proposta não carrega dinheiro.** O dinheiro só lê o contrato, e o caminho tem etapas que o corretor não enxerga:

```
contrato → expectativa → recebimento → alocação (baixa) → lote de conciliação → conferência → repasse a pagar → lote de repasse → pagamento
```

| Etapa | O que é | Quem faz |
|---|---|---|
| Contrato | a venda implantada | o corretor, `gestao_contratos_save_contract` (`koter-contrato`) |
| Expectativa | a comissão que um pagador deve, parcela a parcela, com os repasses pendurados | o Koter, sozinho, na fila |
| Recebimento | dinheiro que entrou | §2 |
| Alocação | a baixa: o recebimento encostado na expectativa | §2 e §3 |
| Extrato | a planilha do pagador, que baixa muitas de uma vez | §4 |
| Lote de conciliação | a capa de um conjunto de baixas | §5 |
| Conferência | o segundo ato, que libera o repasse | §6 |
| Lote de repasse | a rodada de um vendedor | §7 |

Não existe passo manual de gerar parcela de comissão: o Koter monta sozinho depois da implantação. E não pergunte se está pronto: olhe.

```
gestao_comissao_get_commission_settings            → commissionTrackedSince nulo = pare aqui
gestao_contratos_list_contracts                    → a venda tem contrato?
gestao_comissao_get_contract_commission_status(contractId)   → allGood, coverage, receivableRule, payout, schedule, pendingConference, pendências
gestao_comissao_list_commission_expectations(contractId | proposalId | sellerId, statuses?, kinds?)
gestao_comissao_list_commission_pendencies         → o que travou
```

Sem `commissionTrackedSince` nada é gerado e nenhuma pendência abre. Quem liga isso é `koter-gestao-comissoes`.

## 1 · Do contrato à expectativa

Mudar a proposta para "Implantada" **não** cria contrato. Quem cria é `gestao_contratos_save_contract(proposalId, statusId?)`. Implantar, corrigir contrato e registrar evento ficam com `koter-contrato`.

Depois de implantar, o Koter monta o cronograma de prêmio, as expectativas (`PROJECTED`) e os repasses projetados **na fila**. Logo depois da implantação a lista pode vir vazia. Quem não quer esperar:

```
gestao_comissao_recompute_contract_commission(contractId)
  → result.status: BUILT | SKIPPED_NOT_TRACKING | MISSING_DATA (com missingFields) | NO_RULE
```

Status da expectativa: `PROJECTED`, `PARTIALLY_SETTLED`, `SETTLED`, `WRITTEN_OFF`, `VOIDED`, `OUT_OF_SCOPE`. Status do repasse: `PROJECTED`, `PENDING_CONFERENCE`, `PAYABLE`, `BATCHED`, `PAID`, `POSTED` (débito), `VOIDED`.

`gestao_comissao_list_commission_expectations` não tem detalhe por ids: filtre. O id do repasse é `payout.shares[].id`, e o cronograma de prêmio sai de `gestao_contratos_list_contracts(ids, include: ["premiumInstallments"])`.

O que travou fica em `gestao_comissao_list_commission_pendencies`. Corrigida a causa, `gestao_comissao_resolve_commission_pendency(action: "RETRY", pendencyIds)`. `DISMISS` faz o Koter parar de cobrar aquilo daquele contrato: é decisão do corretor, nunca sua.

## 2 · Entrou dinheiro: quatro portas

Escolher errado é o erro mais caro do fluxo. Pergunte o que ele tem em mãos.

| Ele tem | Tool | O valor é |
|---|---|---|
| A planilha do pagador | `gestao_comissao_save_commission_statement` (§4) | as linhas do arquivo |
| O valor de **comissão** que entrou | `gestao_comissao_save_commission_receipt(amount, receivedAt, idempotencyKey, targets?, origin?, payerPartyId?, bankTransactionId?, lotId?)` | comissão |
| Várias comissões vieram como o esperado | `gestao_comissao_save_commission_allocation(items[{ expectationId, amount? }], idempotencyKey, receivedAt?, lotId?)` | comissão; `amount` omitido usa o restante esperado |
| O **prêmio** que o cliente pagou | `gestao_comissao_save_premium_settlement(expectationId, paidGrossAmount \| actualNetAmount, idempotencyKey, paidAt?, lotId?)` | prêmio; a comissão é calculada |

**Prêmio não é comissão.** `gestao_comissao_save_commission_receipt.amount` é comissão. `actualNetAmount` e `paidGrossAmount` são prêmio; se os dois vierem, vale o líquido. Trocar um pelo outro gera erro de múltiplos sem recusa nenhuma do sistema, então confirme em voz alta qual dos dois ele está falando.

**`idempotencyKey` é obrigatória em tudo que move dinheiro:** uma chave por lançamento, e a MESMA na repetição. `gestao_comissao_save_commission_receipt`, `gestao_comissao_save_premium_settlement` e `gestao_comissao_save_chargeback_confirmation` respondem `replayed`, que diz que nada foi lançado de novo. `gestao_comissao_save_commission_allocation` com fonte não leva chave: repetir responde `Este recebimento já está alocado a esta comissão.`

`items` aceita até 500 expectativas, agrupa por contrato e pagador, e um grupo recusado volta em `failures` sem impedir os outros. Diga o que ficou de fora.

Só registrar que o cliente pagou, sem baixar comissão: `gestao_comissao_save_premium_payment(premiumInstallmentId, actualNetAmount?, paidGrossAmount?, paidAt?)`.

Veio pelo banco? `gestao_financeiro_get_reconcile_suggestions` e `gestao_financeiro_reconcile_bank_transactions`, em `koter-gestao-conciliacao`. `gestao_comissao_save_commission_receipt` com `bankTransactionId` pede também a permissão de conciliar extrato bancário, e a transação só fica conciliada quando a soma dos recebimentos iguala o crédito.

## 3 · Alocar

Recebimento sem `targets` fica com pendência até alguém dizer onde ele entra:

```
gestao_comissao_save_commission_allocation(receiptId | statementId + lineId, targets[], lotId?)
```

Cada alvo é um dos três:

- `expectationId` + `amount`.
- `contractId` + `installmentSequence` ou `competence` (com `kinds?`) + `amount`: slot que ainda não tem expectativa, e o Koter materializa.
- `financeEntryId` ou `create: true`: a receber da corretora sem contrato (bônus, PLR, campanha de carteira). É exatamente um alvo. `gestao_comissao_get_statement_line_remuneration` mostra os candidatos.

`amount` é sempre comissão, negativo em estorno. A soma não passa do saldo da fonte. A resposta traz `allocationIds`, que você usa na conferência.

## 4 · O extrato do pagador

O caminho de quem recebe planilha da seguradora ou da administradora.

```
gestao_comissao_list_payer_parties            → seguradora e cliente nascem sozinhos, no primeiro uso
gestao_comissao_save_payer_party              → só distribuidor e administradora
gestao_comissao_list_statement_layouts        → como ler as colunas
gestao_comissao_save_statement_layout(payerPartyId, mapping | templateId)   → um por pagador
gestao_comissao_save_commission_statement(payerPartyId, rows, paymentDate, referencePeriod?, operationalDate?, confirm?)
```

- `rows` é a planilha como lista de linhas, cada linha uma lista de células em texto, cabeçalho incluído, até 20.000 linhas.
- `confirm` padrão `true`. Com `false` fica em rascunho (`DRAFT`) para você mostrar a prévia, e confirma depois com `statementId`. **Prefira `false` no primeiro extrato de um pagador.**
- A baixa roda na fila, contrato a contrato: `CONFIRMING` até terminar, depois `CONFIRMED`. Só confira o lote (`lot.id`) depois de `CONFIRMED`: `gestao_comissao_list_commission_statements` com ids mostra o andamento.
- Casamento na resposta: `MATCHED`, `NO_EFFECT`, `PRIOR_BALANCE`, `UNMATCHED`. Acima de 300 linhas, só voltam as que não casaram (`linesTrimmed`).

Linha `UNMATCHED`: `gestao_comissao_list_commission_statements` com ids dá o motivo (`WITHOUT_CONTRACT`, `NO_CONTRACT`, `AMBIGUOUS_CONTRACT`, `NO_EXPECTATION`, `ALREADY_SETTLED`, `NO_PRIOR_BALANCE`). Resolva com `gestao_comissao_save_commission_allocation(statementId, lineId, targets)`. Corrigiu o que faltava? `gestao_comissao_save_commission_statement(statementId, rematch: true)`, só em extrato `CONFIRMED`.

| Quero | Tool |
|---|---|
| Dizer que um dinheiro pagou o extrato | `gestao_comissao_save_commission_receipt` com `recognitionMode: "STATEMENT"`, depois `gestao_comissao_save_receipt_statement_link(receiptId, statementId, amount?)`. Cada chamada cria um vínculo novo: não repita |
| Levar saldo de um extrato a outro | `gestao_comissao_save_statement_offset(fromStatementId, toStatementId, amount?)` |
| Tratar divergência apontada | `gestao_financeiro_list_finance_issues` e `gestao_financeiro_resolve_finance_issue` |

## 5 · O lote de conciliação

Toda baixa cai num lote: o do extrato, o manual do dia (aberto sozinho, por usuário e pagador) ou um aberto à mão.

```
gestao_comissao_list_settlement_lots                  → declarado, baixado, diferença, pendingConference
gestao_comissao_save_settlement_lot(action: "OPEN" | "EDIT_DATES" | "CLOSE", ...)
gestao_comissao_reopen_settlement_lot(lotId, reason)
```

- `CLOSE` exige `reason` se houver diferença ou acerto.
- `EDIT_DATES` pode responder ocupado: nada foi gravado, repita.
- Lote fechado não aceita baixa nem desfazer, **mas aceita conferência**.
- Reabrir pede a permissão de gerenciar comissionamento: quem só gerencia baixas fecha, mas não reabre.

## 6 · Conferir: o passo que faltava

**Toda baixa nasce não conferida.** O repasse fica `PENDING_CONFERENCE` e só vira `PAYABLE` com a conferência. É a causa mais provável de "dei baixa e o vendedor não recebeu".

```
gestao_comissao_save_lot_conference(conferred: true, lotIds? | lineIds? | allocationIds?)
```

Pode combinar os três: o resultado é a soma. Roda na fila, e a resposta traz `conferenceId`, `allocations` e `contracts`. O andamento aparece em `pendingConference` de `gestao_comissao_list_settlement_lots`: espere zerar antes de montar a rodada. `conferred: false` desconfere e é recusado se um repasse daquela baixa já foi pago. A única baixa que nasce conferida é a de importação histórica.

**Quando o repasse fica a pagar:** na próxima data da rotina da corretora, contada da **data operacional do lote**. Não é a data da baixa nem o vencimento. Para cair numa rodada, é a data operacional que manda.

A descrição de `gestao_comissao_save_settlement_lot` diz que é `receiptDate` que ancora essa data. No código lido, quem ancora é `operationalDate`: ensine a operacional.

**Quando libera depende da `base` do componente de repasse:**

| `base` | De onde vem o valor | Quando libera |
|---|---|---|
| `COMMISSION_RECEIVED` | proporcional a cada baixa | a cada baixa conferida |
| `COMMISSION_EXPECTED`, `PREMIUM_NET`, `FIXED` | do previsto, do prêmio ou do valor fixo | só com a expectativa `SETTLED` e todas as baixas positivas conferidas |

Tabela de repasse que veio do modelo antigo ficou em `PREMIUM_NET`. Por isso uma baixa parcial nela não libera nada: é a resposta para "baixei metade e não apareceu repasse".

## 7 · A rodada

```
gestao_comissao_save_payout_batch(sellerId, roundDate?)   ← sem batchId, cria
```

Um lote agrupa os repasses de **um** vendedor em **uma** rodada. Sem `roundDate`, vale a próxima data da cadência. Só entra repasse a pagar, conferido, sem retenção, com data até a rodada, ou com antecipação agendada.

**A resposta traz `pendingConference`: olhe antes de pagar.** É o que ficou de fora por falta de conferir, com quantidade, valor e os lotes de baixa. Se vier preenchido, confira, espere a fila e rode `refresh`.

Só existe um lote aberto por vendedor por rodada: `Já existe um lote aberto para este vendedor nesta rodada.` Use o que existe.

Origem do lote: `AUTO` (varredura da cadência), `MANUAL` (este caminho), `AD_HOC` (legado) e `HISTORICAL_IMPORT` (importação). Status: `ABERTO` (editável), `PAGO`, `DIFERIDO`, `ESTORNADO`.

```
gestao_comissao_save_payout_batch(sellerId)              → cria: coleta repasses, retenções por crítica e ajustes tipados
gestao_comissao_save_payout_batch(batchId, refresh)      → recoleta; obrigatório depois de conferir ou mudar qualquer regra
gestao_comissao_save_payout_batch(batchId, add|remove)   → inclui ou retira repasses pelo payoutShareId
gestao_comissao_save_payout_batch_adjustments            → crédito ou débito manual
gestao_comissao_set_payout_batch_invoice                 → a nota fiscal do corretor PJ
gestao_comissao_pay_payout_batch(batchId, bankAccountId?, date?)   → o ato manual que paga
gestao_comissao_undo_payout_batch(mode)                  → revert estorna lote pago ou diferido; delete descarta lote aberto;
                                                           remove_invoice apaga a nota; delete_adjustments exclui ajuste manual
```

`add` recusa repasse que ainda não venceu: `O repasse ainda não venceu para a rodada deste lote. Para pagar antes da data, use a antecipação do repasse.`

**Diga de qual conta saiu.** `bankAccountId` é opcional, mas é ele que põe o líquido no saldo da conta, e a conciliação (`koter-gestao-conciliacao`) só casa o débito com lote pago pela mesma conta. `date` omitido é hoje, e data futura é recusada.

**Ajuste tipado ≠ ajuste manual.** Campanha, crítica, empréstimo, arrasto de diferimento, antecipação e recuperação de estorno nascem dos coletores e **não podem ser criados à mão**. Só o ajuste genérico é manual: é o que você usa para "combinei um extra com ele esse mês". Um ajuste tipado que não deve entrar nesta rodada sai com `excluded: true` em `gestao_comissao_save_payout_batch_adjustments`; apagar, só o manual.

**A nota fiscal por MCP é número e data.** `gestao_comissao_set_payout_batch_invoice(batchId, number, issuedAt)` vale em lote `ABERTO` ou `PAGO` e congela o valor da nota em bruto mais créditos, menos a recuperação de estorno. O arquivo PDF ou XML só se anexa pela tela.

**Repasse externo não passa por lote.** Estipulante, cocorretor e indicador de fora nascem como lançamento a pagar na conferência, e se pagam por `gestao_financeiro_settle_finance_entries`, só pelo valor inteiro e recusado enquanto retido (`koter-gestao-baixa-parcelas`).

## 8 · Piso, cascata e o que o corretor não espera

`payoutMinimumAmount` na rotina financeira é o piso da rodada, e `payoutMinimumOverride` no vendedor vence o da corretora. **Lote com líquido abaixo do piso é `DIFERIDO`, não pago**: nada é pago, os repasses voltam a ficar a pagar e **as amortizações de empréstimo são consumadas mesmo assim**. Explique antes de fechar, senão vira ligação do vendedor. Pagar abaixo do piso só com `forceBelowFloor: true` **e** `forcedReason`, que fica auditado.

A cascata de `gestao_comissao_pay_payout_batch` é fixa: bruto, menos deságios de antecipação, mais créditos, menos recuperação de estornos; depois IR e ISS, débitos de crítica, arrasto, amortizações de empréstimo, tarifas e débitos manuais. O pagamento relê tudo: o que saiu, foi desconferido ou ficou retido sai do lote com aviso.

A recuperação de estorno respeita o teto: `chargebackRecoveryCapPercent` da corretora, ou o do vendedor em `gestao_config_save_seller`. Sem teto, a dívida inteira entra no lote seguinte. `allowsNegativeBalance` no vendedor faz o débito que não coube virar dívida cobrada no próximo lote.

Recusas que aparecem aqui. Diga qual delas foi, não "deu erro":

- `O pagamento de comissão deste vendedor está bloqueado no cadastro dele. Desmarque "Bloqueia pagamento de comissão" para pagar.`
- `Este vendedor só recebe com nota fiscal. Registre a nota do lote antes de pagar.`
- `O lote não tem itens nem créditos a pagar.`

## 9 · Quando o prêmio muda, e quando se erra a baixa

```
gestao_comissao_save_premium_settlement(expectationId, paidGrossAmount | actualNetAmount, idempotencyKey)
gestao_comissao_save_premium_payment(premiumInstallmentId, dueDay)
gestao_comissao_reverse_commission_allocation(allocationId)
```

- **`gestao_comissao_save_premium_settlement` é prêmio, não comissão.** Recalcula esta expectativa e as seguintes não travadas, e dá a baixa. Em expectativa travada, a baixa sai pelo valor calculado e a diferença vai para um slot de correção. Use só quando o prêmio mudou de verdade; prêmio igual ao previsto é `gestao_comissao_save_commission_allocation`.
- **Nada é apagado.** A linha que deixou de valer fica cancelada ou anulada (`voidReason: REGENERATED`), e o que já foi baixado trava. Mesmo assim, releia `gestao_comissao_list_commission_expectations` antes da próxima baixa do mesmo contrato.
- **`dueDay` é dia, de 1 a 31**, e reancora as parcelas de prêmio ainda não pagas do contrato. Não combine com pagamento: são chamadas separadas. `gestao_contratos_save_contract(contractId, dueDay)` faz o mesmo pelo contrato.
- **`gestao_comissao_reverse_commission_allocation` desfaz uma baixa**, reabre a expectativa e desfaz os repasses que nasceram dela. **Se o repasse já foi pago, ele vira débito do vendedor.** Avise antes. Recusa em lote fechado.

## 10 · Estorno: quando o dinheiro volta

| Fato | Tool | Efeito |
|---|---|---|
| Cliente cancelou | `gestao_contratos_save_contract_event` tipo `CANCELLATION` (`koter-contrato`) | prevê o estorno (`kind: CHARGEBACK`) e retém os repasses não pagos até o fim da janela |
| Refinou o valor | `gestao_contratos_save_contract_event` tipo `CANCELLATION_REFUND_UPDATE` | troca a estimativa |
| Pagador estornou fora de extrato | `gestao_comissao_save_chargeback_confirmation(expectationId, amount, idempotencyKey, final?, occurredAt?, lotId?)` | cria extrato manual de uma linha negativa; devolve `allocationIds` para conferir |
| Veio no extrato | linha negativa em `gestao_comissao_save_commission_statement` | mesmo efeito |
| Reativou | `gestao_contratos_save_contract_event` tipo `REINSTATEMENT` | desfaz a previsão e a retenção |
| A comissão não veio e não vem | `gestao_comissao_save_chargeback_confirmation(expectationId, writeOff: true)` | `WRITTEN_OFF`; repasses projetados sobre o recebido são anulados, **os de outra base ficam a pagar** |

Sem política de estorno vinculada à tabela, vale sem estorno (`koter-gestao-comissoes`). Cancelamento e portabilidade total retêm repasse; troca de corretor, portabilidade parcial e endosso não. Janela vencida sem nada confirmado anula a previsão sozinha e solta a retenção.

**Como o vendedor paga:** repasse já pago vira débito (`POSTED`), recuperado nos lotes seguintes até o teto; repasse ainda não pago é reduzido. Exemplo da regra: vendedor com 20%, repasse pago de 120 sobre 600, outro projetado de 120, estorno de 300. O pago é debitado em 60, e o projetado cai para 60.

| Quero | Tool |
|---|---|
| Abonar **um** débito | `gestao_comissao_save_seller_debit_waiver(debitId, waived, amount?, reason)` |
| Perdoar a dívida toda | `gestao_comissao_save_seller_debt_adjustment(sellerId, kind: "FORGIVE", amount?, reason)` |
| Registrar devolução do vendedor | `gestao_comissao_save_seller_debt_adjustment(sellerId, kind: "SETTLE", amount, reason)` |

O `debitId` sai de `debits` em `gestao_comissao_get_seller_payout_statement`. Só com pedido explícito, e diga o saldo antes.

## 11 · Antecipação, empréstimo e débito: nomes diferentes para coisas diferentes

O vendedor fala "me adianta aí" e "me perdoa essa dívida" sem distinguir, e o tratamento é outro:

| | O que é | Tools |
|---|---|---|
| **Antecipação de repasse** | pagar antes um repasse de comissão **ainda não recebida**; o deságio é abatido no lote | `gestao_comissao_save_payout_share_advance` (`cancel: true` desfaz) |
| **Empréstimo ao vendedor** | dinheiro que não é comissão, amortizado nos lotes seguintes | `gestao_comissao_save_seller_loan`, `gestao_comissao_register_seller_loan_payment`, `gestao_comissao_end_seller_loan` (`forgive` \| `cancel`) |
| **Débito de estorno** | comissão que voltou ao pagador depois de paga ao vendedor; recuperada no lote | `gestao_comissao_save_seller_debit_waiver`, `gestao_comissao_save_seller_debt_adjustment` |

Antecipação nunca é paga por fora: ela **entra no lote**. Regras em `koter-gestao-emprestimos-antecipacao`.

## 12 · O extrato do vendedor: o que encerra a discussão

```
gestao_comissao_get_seller_payout_statement(sellerId?, from?, to?)
```

Tudo opcional. Sem `sellerId`, é o extrato de quem chama. `to` é **exclusivo**: outubro inteiro é `from: 2026-10-01` e `to: 2026-11-01`.

A resposta traz saldo de abertura e de fechamento, `accruedPayable`, `debt`, e três listas: `lines` (cada lançamento, com contrato, expectativa, `payoutShareId` e lote), `debits` (valor, recuperado, abonado, em aberto) e `batches` (os lotes do período). É o documento que resolve "por que esse mês veio menor" sem ninguém abrir planilha.

`gestao_comissao_list_payout_batches` com `ids` e `export: true` dá a prévia de pagamento, e o CSV, antes de fechar.

## 13 · Desfazer: do mais recente para o mais antigo

Um passo por vez, relendo entre eles. Cada recusa abaixo está na descrição da tool, mas a sequência inteira nunca foi executada: não prometa o desfecho.

1. Lote pago: `gestao_comissao_undo_payout_batch(batchId, mode: "revert", reason?)`. Lote aberto: `mode: "delete"`, ou `gestao_comissao_save_payout_batch(batchId, remove)` para retirar um repasse.
2. `gestao_comissao_save_lot_conference(conferred: false, ...)`.
3. `gestao_comissao_reopen_settlement_lot(lotId, reason)`, se o lote fechou.
4. `gestao_comissao_reverse_commission_allocation(allocationId)` ou `gestao_comissao_reverse_commission_statement(statementId)`. Reverter o extrato desfaz as compensações junto, e o mesmo arquivo pode ser importado de novo.
5. `gestao_comissao_reverse_commission_receipt(receiptId)`: só manual ou direto, sem baixas vivas. Veio do banco: `gestao_financeiro_unreconcile_bank_transaction`.

## 14 · Regras de segurança desta skill

- **Pagar é irreversível na prática.** `gestao_comissao_pay_payout_batch` só depois de mostrar o líquido, os débitos e a quem se refere, e receber o "pode pagar" na mesma conversa.
- **`gestao_comissao_undo_payout_batch` com `mode: "revert"` existe**, mas desfazer pagamento gera ruído com o vendedor. Não trate como Ctrl+Z. É recusado em lote conciliado com o banco (`Desfaça a conciliação bancária deste lote antes de estornar.`), em diferimento cujo arrasto um lote posterior já absorveu, em repasse que já recebeu débito de estorno e em lote `HISTORICAL_IMPORT`.
- **Mudou regra ou conferiu baixa? `gestao_comissao_save_payout_batch` com `batchId` e `refresh: true` antes de pagar.** Lote aberto não se atualiza sozinho.
- **Nunca pague em lote vários vendedores sem listar antes** quem entra, quanto cada um leva e quanto some por piso.
- **Confirme antes de toda escrita que mexe em dinheiro ou desfaz baixa:** conferência, estorno, abono, antecipação, reabertura de lote e qualquer `reverse_*`. `amount` é número que vai para o bolso de alguém: repita-o antes.

## 15 · Validação e próxima

Releia o lote e o extrato do vendedor e diga, em números, o que foi pago, o que ficou diferido, o que segue em `pendingConference` e por quê. Depois:

- **`koter-gestao-financeiro`** para o pagamento aparecer no caixa *(recomendada)*
- `koter-contrato` para cancelamento, troca de vendedor e correção de contrato
- `koter-gestao-emprestimos-antecipacao` para adiantamentos e empréstimos
- `koter-gestao-campanhas` para metas que viram crédito no lote
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Lote nasce zerado | em ordem: acompanhamento desligado; sem contrato; contrato sem vendedor; sem baixa; **baixa sem conferir (a mais comum)**; repasse com data depois da rodada; base `PREMIUM_NET` com expectativa parcial | `gestao_comissao_get_contract_commission_status` e `pendingConference` dizem qual; vendedor, `gestao_contratos_list_contracts(ids, include: ["participants"])` |
| "Dei baixa e o vendedor não recebeu" | baixa nasce não conferida | `gestao_comissao_save_lot_conference`, depois `refresh` no lote |
| "Baixei metade e não apareceu repasse" | base que só libera com a expectativa `SETTLED` | quite a expectativa, ou reveja a base em `koter-gestao-comissoes` |
| Contrato sem expectativa logo depois de implantar | o cálculo é na fila | espere ou `gestao_comissao_recompute_contract_commission` |
| Comissão muito alta numa baixa | prêmio mandado como comissão | `gestao_comissao_reverse_commission_allocation`; `gestao_comissao_save_commission_receipt.amount` é comissão |
| Baixa lançada em dobro | chave nova na repetição | use a MESMA `idempotencyKey`; desfaça com `gestao_comissao_reverse_commission_allocation` |
| Repasse com `heldReason` | `CONTRACT_DEFAULT` ou `CHARGEBACK_PENDING` | resolva o contrato; retido não entra em lote |
| Repasse da angariação não aparece | angariação só paga repasse por nome | componente de repasse com a chave em `sourceComponentKeys` (`koter-gestao-comissoes`) |
| `Já existe um lote aberto para este vendedor nesta rodada.` | um lote por vendedor por rodada | use o que existe |
| Valor não bate depois de mudar a tabela | lote aberto não recoleta sozinho | `gestao_comissao_save_payout_batch` com `refresh: true` |
| Lote fechado e nada pago | líquido abaixo de `payoutMinimumAmount` | é `DIFERIDO`; acumula para a próxima |
| Ajuste de campanha não deixa criar | ajustes tipados vêm dos coletores | só o ajuste manual é criável |
| Vendedor devendo sem ter pego empréstimo | estorno virou débito | `gestao_comissao_get_seller_payout_statement`, em `debits` |

## A prévia mostra dinheiro que ainda não existe

`gestao_contratos_preview_contract_commission(contractId, participants?)` simula o cronograma inteiro **sem gravar**, e exige contrato: não existe prévia sobre proposta sem implantar. Para só ver a regra de uma operadora antes da implantação, `gestao_comissao_resolve_commission(insuranceCompanyId, sellerId?)`.

Duas coisas valem ao mesmo tempo, e as duas importam no onboarding:

1. **Dá para mostrar a comissão da primeira venda logo depois de implantar**, com a tabela dele, mesmo antes de ligar o acompanhamento.
2. **E é simulação, não caixa.** O lote continua vazio até haver baixa conferida. Diga as duas coisas na mesma frase, e já ofereça o próximo passo:

> "Pela sua tabela, essa venda dá R$ X de comissão. Isso é cálculo, não dinheiro: quando a operadora pagar, me diga o valor que eu dou a baixa, confiro com você e o repasse entra na rodada."

A grade Padrão vale para todos, mesmo com `sellerIds` vazio. Grade com `sellerIds` vazio só é sinal de problema quando **não** é a padrão.

## Conferência

Tools, parâmetros, status e mensagens de recusa lidos no código em 03/11/2026, contra o inventário de tools da mesma data. Nada foi executado.
O fluxo novo, do contrato ao pagamento, ainda não rodou de ponta a ponta numa corretora de demonstração. As medições feitas no modelo anterior de comissão foram removidas e precisam ser refeitas.
Sem comprovação: quanto a fila leva depois de implantar e a sequência completa do §13.
