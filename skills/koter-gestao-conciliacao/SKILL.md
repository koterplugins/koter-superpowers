---
name: koter-gestao-conciliacao
description: Concilia o extrato do banco com lançamentos e comissões no Koter e configura as críticas financeiras. Use quando falarem de conciliação, OFX, bater o banco, divergência de valor ou crítica financeira.
---

# koter-gestao-conciliacao

Sétima etapa. É a skill que transforma "acho que recebi" em "recebi, e bate".

Extrato do **banco** é aqui. Extrato de **comissão** da seguradora é `gestao_comissao_save_commission_statement`, na `koter-gestao-repasse`.

## 0 · A importação começa aqui

```
gestao_financeiro_import_bank_statement(bankAccountId, fileName, content, encoding?)
    → { statementId, imported, duplicates, skipped, periodStart, periodEnd }
```

**Só OFX**: não PDF, não CSV, não planilha. `fileName` termina em `.ofx`, `content` é o texto do arquivo, como está. O charset declarado no cabeçalho do OFX (ex.: `CHARSET:1252`) é respeitado; `encoding: "base64"` só quando o arquivo tem caractere que esse charset não representa. Limite de 10 MB. **Reimportar o mesmo período é seguro**: transação já conhecida volta em `duplicates` e não entra de novo.

O que a skill pede ao corretor é o arquivo, não um passeio pela tela:

> "Me manda o OFX do mês da conta principal que eu importo e concilio daqui. Se você já importou pela tela, tudo bem também: eu leio o que entrou."

Depois da importação, `gestao_financeiro_list_bank_statements` e `gestao_financeiro_list_bank_transactions` mostram o que chegou. **Confirme lendo**: o número de `imported` é a prova, não a promessa.

## 1 · Conciliar

```
gestao_financeiro_list_bank_transactions(bankAccountId, ...)              → o que o banco diz
gestao_financeiro_get_reconcile_suggestions(transactionId)                → candidatos de uma transação
gestao_financeiro_get_reconcile_suggestions(bankAccountId)                → as conciliações exatas 1:1 da conta
gestao_financeiro_reconcile_bank_transactions(items[])                    → casa, até 100 por chamada
gestao_financeiro_unreconcile_bank_transaction(transactionId, reverseEntry?)   → desfaz
```

Informe `transactionId` **ou** `bankAccountId`, nunca os dois. Cada item é `{ transactionId, target }`, e `target.kind` diz com o que casa:

| `kind` | Casa com | Sugestão de onde vem |
|---|---|---|
| `entry` | lançamento existente | `entryCandidates` |
| `receipt` | recebimento de comissão já registrado à mão, só crédito | `receiptCandidates` |
| `recordReceipt` | registra um recebimento pelo que falta do crédito. Com `statementId` liga ao extrato confirmado; com `allocations` baixa as comissões previstas. Nunca os dois | `statementCandidates`, `expectationGroups` |
| `payoutBatch` | débito contra um ou vários lotes de repasse já pagos, com `batches: [{ batchId, amount }]` cuja soma é o débito | `payoutBatchCandidates` |
| `createEntry` | cria o lançamento já liquidado a partir da transação | |
| `ignore` | ignora. Com `rememberCounterparty: true` vira regra | |

O `target` das conciliações exatas (`bankAccountId`) serve direto. Ao copiar de uma sugestão, deixe de fora os nomes que ela acrescenta ao lado dos ids: o target não aceita campos a mais.

**Toda baixa nasce não conferida.** `recordReceipt` com `allocations` baixa a comissão, mas o repasse só fica a pagar depois de `gestao_comissao_save_lot_conference` com os `allocationIds` da resposta. Conciliar não encerra o assunto: diga isso, ou o vendedor não recebe. O passo está na `koter-gestao-repasse`.

**Crédito parcial.** A transação só fica conciliada quando a soma dos recebimentos iguala o crédito. Com recebimento parcial, só `recordReceipt` e `receipt` são aceitos; `receivedAmount` e `remainingAmount` mostram o que falta.

**`payoutBatch` não move dinheiro:** grava só o vínculo. Exige lotes pagos pela mesma conta, sem conciliação anterior.

Trabalhe pelas sugestões, não pela lista crua: o corretor não quer ler 200 linhas de extrato. Mostre as que casam com confiança alta, peça um "pode casar" para o bloco, e mande o bloco numa chamada só. **O lote não é atômico**: cada item passa ou falha sozinho, e a resposta separa `succeeded` de `failed`. Releia o `failed` e diga o que não entrou. Traga só as duvidosas uma a uma. `counterpartyMatch` (`RULE` ou `NAME`) ajuda a dar confiança.

Toda conciliação de transação com documento de contraparte cria ou completa uma **regra da contraparte**, que passa a sugerir (ou conciliar sozinha) as próximas. As regras aprendidas se leem e se corrigem com `gestao_financeiro_list_counterparty_rules`, `gestao_financeiro_update_counterparty_rule` e `gestao_financeiro_delete_counterparty_rule`.

**Desconciliar não desfaz tudo.**

- Recebimentos nascidos da conciliação são estornados juntos, **a menos que** algum já tenha sido alocado: aí a desconciliação é recusada inteira, e as alocações precisam sair antes com `gestao_comissao_reverse_commission_allocation`.
- Recebimento registrado à mão só é desligado e continua registrado. Para estornar: `gestao_comissao_reverse_commission_receipt`.
- Lote de repasse conciliado perde só o vínculo e continua pago.
- `reverseEntry: true` estorna também a liquidação do lançamento.

Transação que não casa com nada costuma ser: comissão que caiu junta de várias propostas, tarifa bancária, ou lançamento que ele nunca registrou. As três têm tratamento diferente: pergunte antes de forçar.

## 2 · As críticas: o que o Koter vigia sozinho

`gestao_financeiro_get_finance_issue_settings` mostra os tipos configuráveis. **Tipo sem configuração salva vale ligado, com tolerância de R$ 0,00.**

| Tipo | O que pega |
|---|---|
| `CONCILIACAO_VALOR_DIVERGENTE` | o extrato não bate com o destino conciliado |
| `PREMIUM_AMOUNT_DIVERGENT` | prêmio pago diferente do previsto |
| `COMMISSION_AMOUNT_DIVERGENT` | comissão recebida diferente da prevista |
| `COMMISSION_RATE_DIVERGENT` | taxa do extrato diferente da regra |
| `COMMISSION_OVER_CHARGEBACK` | estorno acima do liberado |
| `COMMISSION_LEDGER_MISMATCH` | razão de comissões fora do financeiro |
| `CAMPANHA_PROPOSTA_CANCELADA` | premiação paga sobre venda que caiu |
| `VENDEDOR_DESLIGADO_COM_DIVIDA` | saiu devendo empréstimo ou adiantamento |

**Tolerância zero significa que um centavo vira crítica.** Operadora que arredonda e banco que cobra tarifa geram fila de críticas sem valor nenhum. É a única pergunta que vale fazer aqui:

> "Diferença de quanto você quer que eu ignore? Até R$ 1 / até R$ 5 / nenhuma, quero ver tudo"

```
gestao_financeiro_save_finance_issue_settings(settings: [{ type, enabled, toleranceAmount }])
```

A fila de `gestao_financeiro_list_finance_issues` ainda traz dois tipos sem valor em jogo, que não se configuram, ligados ao Open Finance: `CONEXAO_BANCARIA_REQUER_ACAO` e `TRANSACAO_REMOVIDA_NO_BANCO`.

## 3 · Resolver

```
gestao_financeiro_list_finance_issues             → a fila, com o resumo de abertas e valor em risco
gestao_financeiro_list_finance_issues(ids)        → esperado, real, diferença, origem e availableActions
gestao_financeiro_resolve_finance_issue(issueId, action, note)   → resolve; action IGNORE ignora
```

Cada crítica já traz **as ações válidas para aquele tipo** em `availableActions`: use o que ela oferece. `note` é obrigatória e fica auditada, inclusive para ignorar. É destrutiva: confirme antes. Mostre sempre esperado, real e diferença juntos: é a diferença que explica, não o valor.

| `action` | Vale para | Faz |
|---|---|---|
| `ACCEPT_BANK_VALUE` | `CONCILIACAO_VALOR_DIVERGENTE` | aceita o valor do banco |
| `ACCEPT_ACTUAL_VALUE` | divergências de prêmio e comissão | em comissão, baixa o resto não recebido (`WRITTEN_OFF`) |
| `CLAIM_INSURER` | divergências de comissão | registra a cobrança e **não fecha**: a crítica segue aberta, envelhecendo em `ageDays` |
| `KEEP_CREDIT`, `DEBIT_NEXT_BATCH` | `CAMPANHA_PROPOSTA_CANCELADA` | mantém o crédito, ou debita no próximo lote |
| `SETTLE_DEBT`, `FORGIVE_DEBT` | `VENDEDOR_DESLIGADO_COM_DIVIDA` | quita ou perdoa |
| `UNDO_RECONCILIATION`, `DISCARD_TRANSACTION` | `TRANSACAO_REMOVIDA_NO_BANCO` | desfaz a conciliação, ou descarta |
| `MANUAL_ADJUSTMENT` | quase todos | registra ajuste feito à mão |

Fechar a crítica, resolvida ou ignorada, **tira o bloqueio da origem**. Em comissão, quem cobrou a seguradora fecha depois com `ACCEPT_ACTUAL_VALUE`, se ela não pagar, ou `MANUAL_ADJUSTMENT`.

**Ignorar não é resolver.** Ignorada some da fila e o dinheiro continua errado. Só ofereça ignorar quando a diferença for irrelevante e recorrente, e aí a resposta melhor é ajustar a tolerância, não ignorar uma a uma.

## 4 · Validação e próxima

Feche com a fila, não com a configuração:

> "Extrato de setembro conciliado: 38 de 41 transações casadas, 3 críticas abertas somando R$ 84. Duas são arredondamento da operadora; subi a tolerância para R$ 1 e elas somem no próximo mês."

Depois:

- **`koter-gestao-repasse`**: conferir as baixas e pagar o time *(recomendada)*
- `koter-gestao-emprestimos-antecipacao`: adiantamentos
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| "Importei e não apareceu" | arquivo que não é OFX, ou período já importado | a resposta diz: `imported: 0` com `duplicates > 0` é reimportação, não falha |
| Conciliou e o vendedor não recebeu | baixa nasce não conferida | `gestao_comissao_save_lot_conference` com os `allocationIds` |
| Enxurrada de críticas | tolerância zero, que é o padrão | `gestao_financeiro_save_finance_issue_settings` por tipo |
| Transação não casa com nada | comissão agrupada, tarifa, ou lançamento inexistente | trate cada caso; não force o match |
| Crédito fica pendente com recebimento | a soma não fechou o crédito | `recordReceipt` para o que falta |
| Crítica ignorada volta | ignorar não corrige a origem | resolva, ou ajuste a tolerância |
| Conciliou errado | match forçado | `gestao_financeiro_unreconcile_bank_transaction` |
| Desconciliação recusada | recebimento já alocado | `gestao_comissao_reverse_commission_allocation` antes |
| Lote continua pago depois de desconciliar | perde só o vínculo | para estornar o lote, `gestao_comissao_undo_payout_batch` |

## Conferência

Tools, `target.kind`, tipos de crítica e ações conferidos no inventário e lidos no código em 03/11/2026, não executados.
Conciliação com `recordReceipt` e `payoutBatch` nunca foi rodada a partir desta skill.
Os valores de exemplo são ilustrativos.
