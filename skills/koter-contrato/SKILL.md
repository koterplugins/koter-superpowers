---
name: koter-contrato
description: Implanta a venda e cuida do contrato, com eventos, vendedores, taxas e prévia de comissão. Use quando falarem de implantar, cancelar, reajustar, renovar, inadimplência ou quanto a venda rende.
---

# koter-contrato

**Todo o dinheiro do Koter lê o contrato, não a proposta.** Comissão prevista, baixa, repasse, estorno, campanha e renovação saem dele. Proposta sem contrato não gera um centavo, e mover a proposta para "Implantada" não cria contrato.

```
proposta → implantação (contrato) → prêmio, comissão prevista e repasse previsto
         → recebimento → baixa → conferência → lote de repasse
```

Esta skill vai da implantação ao fim da vida do contrato. A regra de comissão é `koter-gestao-comissoes`. Dar baixa, conferir e pagar é `koter-gestao-repasse`.

## 0 · Antes de mexer

1. **Conexão.** `gestao-contratos` é categoria própria: conexão feita antes dela existir não a ganha sozinha. Chame `list_toolsets`. Se o toolset não aparecer, pare e peça para reconectar com ele na URL.
2. **Acompanhamento.** Leia `gestao_comissao_get_commission_settings`. Com `commissionTrackedSince` nulo o contrato nasce, mas nenhuma comissão é gerada e nenhuma pendência abre. Ligar é decisão do corretor e mora na `koter-gestao-comissoes`.
3. **Regra.** Sem tabela de recebimento da seguradora o contrato fica na pendência `CONTRACT_WITHOUT_RULE`, e a prévia volta `NO_RULE`.
4. **Aprovação.** Implantar, registrar evento e desfazer mexem em dinheiro de outras pessoas. Diga o que vai acontecer e espere o "pode". `gestao_contratos_save_contract_event` e `gestao_contratos_reverse_contract_implantation` são destrutivas, e evento registrado não se desfaz por esta ferramenta.

Campos terminados em `Name` são só leitura: não os reenvie numa escrita.

## 1 · Achar o contrato

```
gestao_list_proposals(hasContract: false, statusIds: [<status de implantada>])   → vendida e não implantada
gestao_contratos_list_contracts(proposalId)                                      → o contrato de uma proposta
gestao_contratos_list_contracts(statuses: ["SUSPENDED"])                         → inadimplentes
gestao_contratos_list_contracts(hasOpenPendency: true)                           → com pendência de comissão
gestao_contratos_list_contracts(commissionSchedule: "MISSING")                   → sem comissão prevista
gestao_contratos_list_contracts(missingTerm: true)                               → apólice incompleta
gestao_contratos_list_contracts(ids: [...], include: ["events", "participants", "premiumInstallments"])
```

Sem `ids` são até 100 por página; com `ids`, até 20. `include` só vale com `ids`. `startsTo` é exclusivo: para incluir o dia 31, mande o dia 1 seguinte. `missingTerm` só aceita `page` e `pageSize` junto.

| `statuses` | Quer dizer |
|---|---|
| `ACTIVE` | ativo |
| `SUSPENDED` | inadimplente, com repasses retidos |
| `CANCELLED` | cancelado |
| `TRANSFERRED_OUT` | foi para outra corretora, sem volta |
| `EXPIRED` | vigência acabou. Uma varredura diária marca no dia seguinte ao fim |
| `RENEWED` | renovado, o contrato novo é outro |

`model` diz o tipo: `RECURRING_INVOICE` (fatura mensal, padrão), `TERM_POLICY` (apólice com vigência e prêmio parcelado), `CONTRIBUTION_PLAN` (previdência e capitalização) ou `CONSORTIUM_QUOTA` (consórcio). Ele vem do segmento e muda quais dados faltam.

## 2 · Implantar

```
gestao_contratos_save_contract(proposalId, statusId?)
```

É a ação Implantar. Copia da proposta titular, documento, catálogo, início de vigência, dia de vencimento, vidas, prêmio e vendedores.

- Vale para proposta ativa, fora do rascunho, sem contrato, **em qualquer status**.
- Na implantação só valem `proposalId` e `statusId`. Corrija depois com `contractId`, ou edite a proposta antes.
- `statusId` omitido leva ao status com o papel `IMPLANTED`, se houver. `null` deixa a proposta onde está. Um id leva para ele.
- O prêmio é `pricing.value` e, sem ele, `proposalValue`.
- Os vendedores são os `payoutSellers` da proposta. Proposta sem vendedor dá contrato sem vendedor, e nenhum repasse nasce: corrija com `gestao_contratos_save_contract_participants` (§6).
- Sem vigência na proposta, o início vira presumido (`startsAtPresumed: true`), pela data de implantação. Mandar `startsAt` depois confirma a data. **Valor nunca é presumido:** prêmio ausente fica faltando.

Com o acompanhamento ligado, comissão prevista e repasse previsto são montados sozinhos, em fila. Logo depois de implantar a lista pode vir vazia: isso não é erro. Confira com `gestao_comissao_get_contract_commission_status(contractId)` e, se quiser forçar, `gestao_comissao_recompute_contract_commission(contractId)`.

Não existe geração manual de parcela. Automação também implanta, com a ação `IMPLANT_CONTRACT` (`koter-gestao-automacao`).

**Implantar dispara o gatilho `CONTRACT_IMPLANTED`** e, com o `statusId`, as automações do status de destino. Pergunte antes de implantar em lote.

## 3 · Prévia: quanto esta venda rende

```
gestao_contratos_preview_contract_commission(contractId)
gestao_contratos_preview_contract_commission(contractId, participants: [{ sellerId, payoutGradeId? }])
```

Simula sem gravar. **Exige contrato:** não há prévia sobre proposta sem implantar. Antes disso, para só ver a regra: `gestao_comissao_resolve_commission(insuranceCompanyId, sellerId?)`.

| Campo | Lê assim |
|---|---|
| `simulated: false` | não simulou. `reason` é `MISSING_DATA` (veja `missingFields`) ou `NO_RULE` |
| `sellers` | por vendedor: grade (`gradeId`), de onde veio (`source`), `payoutTotal`, e os repasses de liderança |
| `slots` | cada parcela da comissão: `kind`, `ordinal`, `competence`, `receivable`, `payout`, `margin`, `inScope`, `locked` |
| `externals` | estipulante, cocorretor e indicador de fora |
| `receivableTotal`, `payoutTotal`, `margin` | os totais |
| `hasNegativeMargin` | o repasse passa do que a corretora recebe |

`participants` troca só os vendedores da simulação; externos continuam. Quem tem visão só do próprio repasse vê os próprios valores, e `payoutTotal` dos outros vem nulo.

Pelo código, a prévia não depende de o acompanhamento estar ligado. Prévia é simulação: nada disso entrou no caixa. Diga isso ao mostrar o número.

**Provar a regra numa venda real:**

```
1. gestao_contratos_save_contract(proposalId, statusId: null)     ← não mexe no funil
2. gestao_contratos_preview_contract_commission(contractId)
3. "Bate com o que você recebe e paga hoje?"
4. Se a venda não era para ficar: gestao_contratos_reverse_contract_implantation(contractId)
```

Avise antes: implantar é ato real. A proposta ganha contrato, o gatilho `CONTRACT_IMPLANTED` dispara, e o passo 4 só funciona sem movimento.

## 4 · Corrigir sem evento

| Quero | Use | Efeito |
|---|---|---|
| Dado errado desde o início | `gestao_contratos_save_contract(contractId, ...)` | Só os campos enviados. Vale só no contrato, a proposta não muda |
| Corrigir pela proposta | `gestao_save_proposal(proposalId, ...)` | Passa ao contrato só o que mudou. A resposta traz `contractTranslation` |
| Reajuste com data | evento `PREMIUM_ADJUSTMENT`, ou `premiumEffectiveDate` em `gestao_save_proposal` | Vale daí em diante |
| Prêmio digitado errado | `basePremium` em `gestao_contratos_save_contract` | Corrige desde o início |
| Apólice incompleta | `gestao_contratos_list_contracts(missingTerm: true)`, depois `endsAt`, `installmentsCount` e `basePremium` em `gestao_contratos_save_contract` | Falta `endsAt`, `termNetPremium` ou `installmentsCount` |

O caminho é de mão única: proposta corrige contrato, contrato não corrige proposta. **O que já tem baixa não muda.** `lockedExpectationCount` e `lockedDifferences` dizem quantas ficaram de fora, e isso precisa ser dito ao corretor.

`gestao_contratos_save_contract` com `contractId` também aceita `contractNumber`, `issuedAt`, `startsAt`, `dueDay`, `insuranceCompanyId`, `segmentCategoryId`, `stateId`, `insurerTaxPercent`, `holderName`, `holderDocument`, `livesCount`, `distributorPartyId`, `administratorPartyId`, `iofAmount`, `policyCostAmount`, `financeChargeAmount`, `premiumBasis`, `adjustmentWindowDays`, `contributionFrequency`, `creditValue` e `cancelledAt`. IOF, custo de apólice e juros nunca entram na base da comissão.

Trocar o pagador: o id de distribuidor ou administradora vem de `gestao_comissao_list_payer_parties`. Com distribuidor, só valem as tabelas dele.

## 5 · Eventos: o que aconteceu com o contrato

```
gestao_contratos_save_contract_event(contractId, type, effectiveDate, ...)
```

Cada tipo aceita só os seus campos. `effectiveDate` é obrigatório, menos em `REINSTATEMENT` (padrão hoje) e em `POLICY_ADJUSTMENT`, `PREMIUM_DECLARATION` e `CANCELLATION_REFUND_UPDATE`, que valem no dia do registro. Nunca antes do início de vigência.

**Os do dia a dia:**

| `type` | Quando | Campos | Efeito |
|---|---|---|---|
| `CANCELLATION` | cancelou | `reason` (obrigatório), `refundedNetPremium`, `unpaidNetPremiumCancelled`, `estimate`, `note`, `statusId` | Anula o que vence depois, prevê estorno pela política e retém repasses não pagos até o fim da janela |
| `CANCELLATION_REFUND_UPDATE` | veio o valor real | `refundedNetPremium` (obrigatório, zero vale), `unpaidNetPremiumCancelled`, `note` | Troca a estimativa e fecha a pendência `CHARGEBACK_ESTIMATED` |
| `REINSTATEMENT` | voltou | `note`, `statusId` | Desfaz a previsão de estorno e a retenção, se o número da apólice estiver livre |
| `DEFAULT_STARTED` | entrou em inadimplência | `note` | Suspende o contrato e retém os repasses não pagos. Não mexe no status da proposta |
| `DEFAULT_CURED` | saiu da inadimplência | `note` | Volta a ativo e libera os repasses |
| `PREMIUM_ADJUSTMENT` | reajuste | `netPremium` (obrigatório) | Vale de `effectiveDate` em diante. Não aceita `note` |
| `RENEWAL` | renovou | `netPremium`, `endsAt`, `contractNumber`, `insuranceCompanyId`, `note`, `statusId` | Cria um contrato novo ligado ao anterior. `effectiveDate` é o início novo |
| `BROKER_CHANGE_OUT` | cliente levou para outra corretora | `newBrokerName`, `note`, `statusId` | Encerra sem volta. Prevê estorno sem reter repasse |
| `LIVES_CHANGE` | entrou ou saiu vida em saúde PME | `livesDelta` (obrigatório), `netPremiumDelta`, `appliesInclusionCommission`, `note` | Saída alimenta estorno proporcional. Sem `netPremiumDelta` a fração é estimada pelas vidas |

`reason`: `CLIENT_REQUEST`, `DEFAULT`, `INSURER_DECISION`, `TOTAL_LOSS`, `SUBSTITUTION`, `FULL_WITHDRAWAL` ou `OTHER`.

**Renovação com a mesma seguradora** não paga agenciamento de novo e continua a numeração. **Trocando de seguradora**, a cadeia recomeça: vale a regra de negócio novo e os coassegurados não vêm junto. Antes de renovar, mostre qual dos dois casos é, porque muda o que o vendedor recebe.

Prazo legal de cancelamento e devolução: confirme com seu jurídico.

**Os de produto específico:**

| `type` | Para quê |
|---|---|
| `ENDORSEMENT` | endosso de apólice de prêmio fixo. `netPremiumDelta` com sinal. Parcela paga nunca muda |
| `POLICY_ADJUSTMENT` | ajuste de apólice de prêmio ajustável. Exige `netPremiumDelta` e `firstDueDate` |
| `PREMIUM_DECLARATION` | averbação de apólice aberta. Exige `netPremium`, `competence` e `dueDate` |
| `EXTRA_CONTRIBUTION` | aporte avulso de previdência (`amount`) |
| `PORTABILITY_IN`, `PORTABILITY_OUT` | portabilidade. Saída com `full: true` encerra e retém; parcial exige `amount` e saldo conhecido |
| `WITHDRAWAL` | resgate. `full` é obrigatório. Total também cancela o contrato |
| `RESERVE_BALANCE_UPDATE` | saldo da reserva numa data (`reserveBalance`). Sem saldo, a comissão sobre saldo não é projetada |
| `CREDIT_VALUE_CHANGE` | mudança do crédito de consórcio. A base de comissão fixada na emissão não muda |

**Quem cai no estorno:** cancelamento e portabilidade total retêm repasse. `BROKER_CHANGE_OUT`, portabilidade parcial e endosso não. Sem política de estorno vinculada à regra, vale sem estorno. O acerto do que foi estornado está na `koter-gestao-repasse`.

**Com status:** `CANCELLATION`, `BROKER_CHANGE_OUT`, `PORTABILITY_OUT` total e `WITHDRAWAL` total levam a proposta de origem ao status com o papel `CANCELLED`, e `REINSTATEMENT` ao de `IMPLANTED`, se houver. `null` deixa onde está. `RENEWAL` só move com `statusId`. Cancelar não arquiva a proposta, e mover a proposta nunca cancela contrato.

**Automação:** cancelar dispara `CONTRACT_CANCELLED`, e a inadimplência dispara `CONTRACT_DEFAULT_STARTED`. A varredura de inadimplência só roda com `premiumDefaultSweepEnabled` ligado.

## 6 · Quem recebe: participantes

```
gestao_contratos_save_contract_participants(contractId, participants, effectiveDate?)
```

Mande a **lista completa**: quem não vier sai.

| `role` | Quem é | Precisa de |
|---|---|---|
| `SELLER` (padrão) | vendedor interno | `sellerId`. `payoutGradeId` opcional |
| `CO_BROKER`, `REFERRER` internos | vendedor da casa | `sellerId`. O papel é só rótulo |
| `CO_BROKER`, `REFERRER` externos | gente de fora | `externalName`, `payoutGradeId` obrigatório, `externalDocument` opcional |
| `STIPULANT` | estipulante, sempre externo | `externalName`, sem grade |

- **Com `effectiveDate`** é troca datada: quem sai fica com o período até a data.
- **Sem `effectiveDate`** é correção desde o início. Pergunte qual dos dois ele quer, porque muda quem recebe o passado.
- A lista vale só no contrato. Mandar a mesma lista responde `changed: false`.
- Repasse externo não passa por lote: é um lançamento a pagar, quitado por `gestao_financeiro_settle_finance_entries`, só pelo valor inteiro e recusado enquanto retido.

Antes de gravar, simule: `gestao_contratos_preview_contract_commission(contractId, participants)`.

## 7 · Taxa, cosseguro e exceção

**Taxa em intervalo:** quando a regra deixa escolher a taxa dentro de uma faixa.

```
gestao_contratos_get_contract_rate_choices(contractId)                  → minPercent, maxPercent, defaultPercent, chosenPercent, effectivePercent
gestao_contratos_save_contract_rate_choices(contractId, choices: [{ componentKey, percent }])
```

A lista substitui a anterior; lista vazia volta ao padrão. Fora do intervalo é recusado. Renovação começa no padrão e não herda a escolha. Só o que está em aberto muda.

**Cosseguro:**

```
gestao_contratos_save_contract_coinsurers(contractId, coinsurers: [{ payerPartyId, sharePercent, isLeader }])
```

Partes somam 100, com uma líder, que é a seguradora do contrato. Só vale quando quem paga é a seguradora: com distribuidor, as partes ficam guardadas sem efeito.

**Exceção de recebimento:** taxa negociada que vale só neste contrato, por um período.

```
gestao_contratos_list_contract_commission_overrides(contractId)
gestao_contratos_save_contract_commission_override(contractId, ruleSetId, validFrom, validTo, reason, overrideId?)
gestao_contratos_remove_contract_commission_override(contractId, overrideId)
```

`ruleSetId` vem de `gestao_comissao_list_commission_rule_sets`, de uma grade de recebimento da mesma seguradora. Períodos não se sobrepõem. `validTo: null` é sem fim. Em todos os três casos, o que já foi recebido não muda.

## 8 · Carteira antiga

Ligar `commissionTrackedSince` carimba, em segundo plano, todo contrato que começa antes da data, para venda velha não gerar passado. A resposta traz `trackedFromStamp: { queued: true }`. O carimbo pula quem esconderia parcela já baixada.

Ajuste fino, contrato a contrato:

```
gestao_comissao_save_contract_tracked_from(contractIds, trackedFrom)
```

Parcelas que vencem antes de `trackedFrom` ficam fora do escopo. Com vários contratos, cada um passa ou é pulado, com `reason` em `NOT_FOUND`, `NOT_LIVE`, `INCOMPLETE`, `WITHOUT_RULE`, `HIDES_SETTLED` ou `CONCURRENT_WRITE` (este, é só mandar de novo).

Se ele quer trazer também o passado de comissão e repasse pago, o caminho é a `koter-importacao`.

## 9 · Desfazer a implantação

```
gestao_contratos_reverse_contract_implantation(contractId, statusId?)
```

Para contrato criado por engano. Apaga o contrato, a linha do tempo, os vendedores comissionados, as comissões previstas e as parcelas de prêmio. A proposta continua ativa e pode ser implantada de novo. `statusId` omitido deixa a proposta onde está.

Só vale em contrato ativo sem movimento: nenhuma baixa, nenhum repasse além de previsto, nenhum evento além da emissão, das correções e da troca de vendedores. Com movimento, o caminho é `CANCELLATION`.

## 10 · Diagnóstico: por que não tem comissão

```
gestao_comissao_get_contract_commission_status(contractId)
```

| Olhe | Quer dizer |
|---|---|
| `allGood` | contrato vivo, completo, com regra, comissão prevista e sem pendência. **Não prova que há repasse:** contrato sem vendedor passa, e com `RECEIVABLE_ONLY` o repasse nem é checado |
| `coverage` | início, prêmio e campos faltando |
| `receivableRule` | a regra que vale e de onde veio |
| `payout` | a grade de cada vendedor. `null` com `RECEIVABLE_ONLY` |
| `schedule` | quantas comissões previstas há, e `dirtySince` se espera recálculo |
| `pendingConference` | repasses esperando a conferência da baixa |
| `reserveBalance` | saldo exigido e ausente |

Depois: `gestao_comissao_list_commission_pendencies(contractId)`. Pendência fecha sozinha quando a causa some. Corrigiu e não quer esperar: `gestao_comissao_resolve_commission_pendency(action: "RETRY", pendencyIds)`. `DISMISS` faz o Koter parar de cobrar aquela configuração: é decisão do corretor, nunca sua.

Corrigir também tem mão certa: dado do contrato aqui, regra ou grade em `koter-gestao-comissoes`, seguida de `RETRY`.

## 11 · Validação e próxima

Releia sempre: `gestao_contratos_list_contracts(ids: [contractId], include: ["events", "participants"])`. Evento que não aparece na linha do tempo não aconteceu.

> "Contrato da Maria implantado na Amil PME, início em 01/11, prêmio de R$ 1.500. A prévia dá R$ 2.700 a receber e R$ 1.350 de repasse. Falta só receber."

Depois, em até 4 opções:

- **`koter-gestao-repasse`** para dar baixa e pagar *(recomendada quando já há recebimento)*
- `koter-gestao-comissoes` se a prévia veio `NO_RULE`
- `koter-gestao-automacao` para avisar inadimplência e fim de vigência
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| "Implantada" e sem comissão | mudar status não implanta | `gestao_contratos_save_contract(proposalId)` |
| Implantou e a lista veio vazia | montagem na fila, ou `commissionTrackedSince` nulo | `gestao_comissao_get_contract_commission_status`, depois `gestao_comissao_recompute_contract_commission` |
| Comissão prevista e nenhum repasse | contrato sem vendedor | `gestao_contratos_list_contracts(ids, include: ["participants"])`, depois `gestao_contratos_save_contract_participants` |
| `result.status` `SKIPPED_NOT_TRACKING` | acompanhamento desligado ou contrato fora dele | `koter-gestao-comissoes` |
| "Proposta arquivada ou em rascunho não ganha contrato." | proposta inativa ou rascunho | restaure ou conclua a proposta |
| "Esta proposta já tem contrato." | implantação repetida | `gestao_list_proposals` traz `contract` |
| "Este contrato já tem movimento. Registre o cancelamento em vez de desfazer a implantação." | houve baixa, repasse ou evento | `CANCELLATION` |
| "Proposta revisada só pode ser editada por um cargo acima de Consultor." | trava de revisão | quem tem cargo acima faz |
| "Na implantação o contrato copia os dados da proposta; não mande ..." | campo a mais na implantação | implante e corrija com `contractId` |
| Erro de escrita concorrente | o contrato mudou durante o pedido, nada foi gravado | leia de novo e repita |
| Arquivar a proposta é recusado | contrato vivo | registre cancelamento ou transferência antes |
| Corretor acha que a prévia é dinheiro | é simulação | diga na hora de mostrar |
| Correção não mudou uma parcela | ela já tem baixa | `lockedDifferences` mostra a diferença; diga ao corretor antes de seguir |

## Conferência

Tools e parâmetros conferidos no inventário e lidos no código em 03/11/2026, não executados.
Nenhum contrato real foi implantado, simulado ou desfeito por esta skill, nem os exemplos de valor foram rodados.
O prazo que a montagem das comissões leva depois de implantar não é conhecido: é fila.
