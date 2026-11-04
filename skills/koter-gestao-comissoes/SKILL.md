---
name: koter-gestao-comissoes
description: Configura a comissão no Koter, da tabela da operadora ao repasse, variantes e estorno, e prova numa venda real. Use quando falarem de comissão, agenciamento, percentual ou quanto o vendedor ganha.
---

# koter-gestao-comissoes

O coração do módulo. **Termina em prova, não em promessa:** a skill monta a regra, simula sobre uma venda que o corretor já comissionou na mão e mostra o número que o Koter pagaria. Bate, acabou. Não bate, a diferença aponta o campo errado.

## 0 · Pré-requisitos

Fundação (com as operadoras com que ele trabalha anotadas no estado) e vendedores, **se ele repassa**. Corretor que não repassa configura só o recebimento e pula metade da skill.

**Confira a conexão.** Chame `list_toolsets`: `gestao-comissao` e `gestao-contratos` precisam aparecer. Sem o segundo a prova não roda, porque simular exige contrato. Se faltar, pare e peça para reconectar com o toolset na URL: conexão antiga não ganha a categoria sozinha.

**A proposta não carrega dinheiro.** O dinheiro lê o contrato: venda vira contrato, contrato vira expectativa de comissão, e o resto acontece em `koter-gestao-repasse`. Esta skill cuida das regras.

## 1 · O vocabulário que evita configurar errado com número certo

Em saúde e odonto existem **duas remunerações na mesma venda**, e o corretor costuma falar só de uma:

| | O que é | Faixa típica em saúde PME |
|---|---|---|
| **Agenciamento** | pagamento de entrada, múltiplo da primeira mensalidade, uma vez só | 150% a 200% |
| **Comissão recorrente** | percentual da mensalidade, mês a mês | 3% a 10% |

Perguntar "qual o seu percentual de comissão?" e receber "8%" configura **errado com número certo**: some o agenciamento, que é a maior parte do dinheiro da venda.

Três formatos de recorrente, todos comuns: **vitalícia**, **prazo fixo** (12 ou 24 meses) e **não existe** (só agenciamento). **Nunca assuma vitalícia**: é a suposição que gera projeção de receita errada.

Cuidado com o **agenciamento diluído**: operadora que paga 30% extra da 1ª à 12ª parcela parece recorrente alta e não é, acaba na 12ª.

No Koter, cada remuneração é um **componente** da regra: `kind: AGENCY` (agenciamento), `BROKERAGE` (corretagem), `RECURRING` (recorrente), `PRO_LABORE`, `BONUS`.

> ⚠️ **Agenciamento e angariação não são sinônimos.** O múltiplo da primeira mensalidade pago pela operadora é agenciamento. Angariação é o dinheiro que o **cliente** paga no boleto: componente com `payerKind: CLIENT`. Ela só paga repasse quando um componente de repasse lista a chave dela em `sourceComponentKeys`. Sem isso, nunca vira repasse, nem com `sourceKinds`.

## 2 · Detecção, antes da primeira pergunta

```
gestao_comissao_get_commission_settings            → cadência, prazo, deságio, override, commissionTrackedSince, commissionModel, teto de estorno
gestao_comissao_get_commission_summary(by: "operator", segmentId, segmentCategoryId,   # os dois obrigatórios
                                       insuranceCompanySearch?, page?)
                                                   → operadoras da categoria (100 por página, total em operatorsPaging), com managerName, hasReceivable / hasPayoutDefault
gestao_comissao_list_commission_grades             → grades existentes (e o overrideSplitMode de cada uma)
gestao_comissao_list_commission_rule_sets          → regras publicadas, com vigência e componentes
gestao_comissao_list_chargeback_policies           → políticas de estorno
gestao_comissao_list_payer_parties                 → quem paga, além da seguradora
gestao_comissao_list_commission_campaigns          → campanhas já criadas
gestao_config_list_sellers                         → se repassa ou não
```

`gestao_comissao_get_commission_settings` pede a permissão de gerenciar comissionamento. Sem ela, siga com o resto e diga o que não deu para ler.

> ⚠️ **Busque a operadora pelo nome antes de listar a categoria.** Categoria grande passa de 100 operadoras e vem em várias páginas. Com `insuranceCompanySearch` volta só o que interessa, separado pelo `managerName`. Percorra as páginas só quando precisar do panorama inteiro.

## 3 · O roteiro: as perguntas, o resto se deduz

Cada uma como card de decisão de 2 a 4 opções, consequência em uma linha, recomendação marcada.

**P0 · Desde quando você quer acompanhar comissão no Koter?** → `commissionTrackedSince`. **Vem antes de tudo.** Sem essa data, nada é gerado e nenhuma pendência abre. Junto: quem repassa grava `commissionModel: "RECEIVABLE_AND_PAYOUT"`.

**P1 · Você repassa comissão para alguém?** → *dedutível*: se há vendedores cadastrados, confirme em vez de perguntar. **"Não repassa" encerra o roteiro em P5 e vai direto para a prova.**

**P2 · Com quais operadoras, e qual é a maior?** → *dedutível*: a fundação guardou as operadoras dele no estado, e a maior sai do volume de propostas. **Configure a maior primeiro e use como modelo.**

**P2b · Você recebe direto da operadora, ou por uma administradora ou distribuidor?** → seguradora e cliente nascem sozinhos como pagadores. Administradora e distribuidor se criam com `gestao_comissao_save_payer_party` e entram no contrato com `gestao_contratos_save_contract` (`administratorPartyId`, `distributorPartyId`). Sem pagador resolvido, abre a pendência `PAYER_UNRESOLVED`.

**P3 · O que a operadora te paga na entrada?**
> Um múltiplo da primeira mensalidade (agenciamento) / Só o percentual mensal / Os dois / Não sei, vou olhar o contrato

**A pergunta mais valiosa do roteiro.** Nenhuma leitura responde.

**P4 · E o percentual mensal, dura quanto tempo?**
> Enquanto o cliente pagar / 12 meses / 24 meses / Não tem mensal

Vira `kind: RECURRING` com `duration`: `UNTIL_CANCELLED`, `UNTIL_TERM_END`, `MAX_INSTALLMENTS` (com `maxInstallments`) ou `MAX_MONTHS` (com `maxMonths`).

**P5 · Quanto a operadora demora para pagar?** → vira `receivableDelayDaysDefault` (ou `insurerPaymentTerms` de `gestao_comissao_save_commission_settings`, por operadora). *Parcialmente dedutível* do que ele já recebeu.

**P5b · Quando o cliente cancela, a operadora toma a comissão de volta?** → escolhe a política de estorno. **Sem política, vale sem estorno**, e o vendedor fica com o dinheiro que a corretora devolveu. Ver §4.

**P6 · O vendedor ganha quando você fatura ou quando você recebe?**
> Quando eu recebo *(recomendado)* / Quando a venda é implantada, eu banco o intervalo

**Essa pergunta escolhe a `base` do repasse**, e não é detalhe: muda quando o dinheiro libera.

| `base` do repasse | Em português | Libera |
|---|---|---|
| `COMMISSION_RECEIVED` | percentual do que eu recebo | a cada baixa conferida |
| `COMMISSION_EXPECTED` | percentual do que eu deveria receber | com a expectativa quitada |
| `PREMIUM_NET` | percentual do prêmio líquido | com a expectativa quitada |
| `FIXED` | valor fixo | com a expectativa quitada |

O Koter só é "sobre o recebido" **quando a base é `COMMISSION_RECEIVED`**. Nas outras, dar a comissão como não recebida (`writeOff`) deixa o repasse a pagar. Quem paga antes de receber pode usar **antecipação** (`gestao_comissao_save_payout_share_advance`), que só vale antes do primeiro recebimento (`koter-gestao-emprestimos-antecipacao`).

**P7 · Todos ganham igual?** → Sim: só Padrão. Categorias: variantes. Caso a caso: **resista** e proponha Padrão + desvios. *Dedutível* se já existem variantes.

**P8 · Quanto o vendedor leva, do que você recebe?** → "metade do que eu recebo" é `COMMISSION_RECEIVED` com 50. Múltiplo sobre o prêmio é `PREMIUM_NET`. Os dois podem dar o mesmo número e liberar em momentos diferentes: decida com a P6, não com a conta.

**P9 · Supervisor ou gerente ganha sobre a venda do time?** → `managerPercent`, `supervisorPercent` e `directorPercent`, por degrau, sobre a mesma base. *Pulável* quando não há liderança no organograma.

**P9b · (só se alguém tiver mais de um líder do mesmo tipo)** os dois ganham? → `overrideSplitMode`. **Totalmente dedutível**: só pergunte se a hierarquia mostrar o caso.

**P10 · Quando você paga o time?** → `payoutFrequency`: `DAILY`, `WEEKLY` (exige `payoutWeekdays`) ou `MONTHLY` (exige `payoutDayOfMonth`). **P10b · piso?** → `payoutMinimumAmount`; lote abaixo do piso é **DIFERIDO**, não pago. **P10c · teto de recuperação de estorno?** → `chargebackRecoveryCapPercent`, de 0 a 100; vazio, a dívida inteira entra no lote seguinte.

**P11 · Imposto: desconta do vendedor ou a casa absorve?** → `passTaxToSeller` por vendedor. Na regra, `taxPercent` no degrau, depois no componente, depois `defaultTaxPercent` no conjunto; vazio herda nessa ordem e cai no da corretora. Origem silenciosa de divergência no extrato.

**P12 · Tem meta ou campanha?** → **meta é campanha, nunca tabela.** Se ele descrever meta enquanto fala de percentual, separe as duas coisas em voz alta, senão ele embute a meta na grade e o número sai errado. Fica com `koter-gestao-campanhas`.

**P13 · A prova.** Ver passo 6.

## 4 · Aplicação

**Ordem que economiza trabalho:** rotina financeira e acompanhamento → política de estorno → recebimento da maior operadora → repasse Padrão → variantes como exceção. **A variante nasce vazia e segue a base**, então configurar vendedor por vendedor desde o começo é trabalho jogado fora.

### Rotina e acompanhamento

```
gestao_comissao_save_commission_settings
  settings: { receivableDelayDaysDefault, payoutFrequency, payoutWeekdays, payoutDayOfMonth   (os quatro obrigatórios)
              commissionTrackedSince, commissionModel, chargebackRecoveryCapPercent, premiumDefaultSweepEnabled,
              overrideMaxDepth, payoutMinimumAmount, advanceDiscountPercent,
              invoiceEmail, invoiceNotice, otherRemunerationCategoryId }
  insurerPaymentTerms: [ { insuranceCompanyId, receivableDelayDays?, insurerTaxPercent? } ]   ← por operadora, opcional
  bankFeeRules: [ ... ]                                                                       ← tarifas, opcional
```

- **Os quatro são obrigatórios em toda gravação de `settings`, mesmo para mudar outra coisa.** Leia antes com `gestao_comissao_get_commission_settings` e devolva os valores. Em `MONTHLY`, `payoutWeekdays` vai como lista vazia; fora de `MONTHLY`, `payoutDayOfMonth` vai `null`.
- **Ligar `commissionTrackedSince` carimba a carteira.** A resposta traz `trackedFromStamp: { queued: true }`, e todo contrato que começa antes da data passa a ser acompanhado só dali em diante, para venda velha não gerar passado. Ajuste fino: `gestao_comissao_save_contract_tracked_from(contractIds, trackedFrom)`. Até a tabela existir, contratos aparecem com a pendência `CONTRACT_WITHOUT_RULE`, que fecha sozinha.
- **`commissionModel`: não prometa o que o nome sugere.** A descrição diz que `RECEIVABLE_ONLY` só acompanha o recebimento, mas no código lido ele só muda a cobrança de pendência e o status do contrato. Não diga que ele impede repasse de nascer. Quem repassa grava `RECEIVABLE_AND_PAYOUT`, senão a pendência `PARTICIPANT_WITHOUT_PAYOUT_RULE` não abre.
- `premiumDefaultSweepEnabled` é para quem registra o pagamento dos prêmios: a varredura diária suspende contrato com parcela de prêmio vencida.

Carteira com histórico para trazer, comissão recebida e repasse já pago: `koter-importacao`, **depois** de publicar a tabela e ligar o acompanhamento. Sem isso, os prêmios entram e as comissões não.

### Política de estorno

```
gestao_comissao_save_chargeback_policy(name, mode, tiers?, triggers, reasons, includesDefault?, confirmationWindowDays?)
```

`mode`: `NONE`, `PAID_INSTALLMENTS_TABLE`, `TENURE_TABLE`, `FULL_BEFORE`, `UNEARNED_PREMIUM`. **`triggers` e `reasons` sem lista não disparam nada**: uma política sem eles é o mesmo que não ter política. Vincule em `draft.defaultChargebackPolicyId` ou em `components[].chargebackPolicyId`.

### Publicar a regra

> ⚠️ **Aqui não há exemplo pronto, e é de propósito.** Este formato de `gestao_comissao_publish_commission_table` nunca foi executado por esta skill, e a tool **não tem `dryRun`**: publicar vale de verdade e encerra a versão vigente. O mapa abaixo saiu da leitura do schema. Diga isso ao corretor antes da primeira publicação. Se ele tiver uma corretora de demonstração, publique lá primeiro. Se não, comece por uma operadora só e só replique depois da prova.

`validFrom` no futuro agenda, mas **não é ensaio**: a primeira versão publicada também vale para venda mais antiga que ela, e versão agendada já presa a contrato não se cancela (`A versão agendada já está em uso por contratos e não pode ser cancelada nem substituída. Publique uma nova versão com vigência posterior a ela.`). Regra errada se corrige publicando outra versão.

```
gestao_comissao_publish_commission_table(target, draft, validFrom?)

target: { kind: "RECEIVABLE",     insuranceCompanyId, marketId?, productKey?, distributorPartyId? }   ← a margem da casa, visível só a gestor
      | { kind: "PAYOUT_DEFAULT", insuranceCompanyId }                                                ← tabela Padrão de repasse
      | { kind: "PAYOUT_GRADE",   gradeId, insuranceCompanyId }                                       ← variante ou acordo
draft:  { components: [...], defaultTaxPercent?, defaultChargebackPolicyId?, inheritance? }
```

Cada componente exige `key`, `kind`, `base`, `release`, `releaseAnchor` e `steps`. Parâmetro fora do schema é erro de validação: `rows`, `commissionType`, `isLifetime` e `installmentNumber` não existem mais.

| O corretor disse | Campo |
|---|---|
| Agenciamento de 180% na primeira mensalidade | `kind: "AGENCY"`, degrau `{ fromOrdinal: 1, toOrdinal: 1, percent: 180 }` |
| 8% enquanto o cliente pagar | `kind: "RECURRING"`, `duration: { type: "UNTIL_CANCELLED" }`, degrau com `toOrdinal` vazio, `percent: 8` |
| 8% por 24 meses | `duration: { type: "MAX_MONTHS", maxMonths: 24 }` |
| A recorrente corre junto com o agenciamento desde a 1ª | `startSequence: 1` |
| A recorrente começa depois do agenciamento | `startSequence: 2` |
| Percentual sobre a mensalidade | recebimento: `base: "NET_PREMIUM_INSTALLMENT"`; com imposto da seguradora abatido, `baseDeductions: ["INSURER_TAX"]` |
| Auto, sobre o prêmio da apólice | recebimento: `base: "NET_PREMIUM_TERM"` |
| Metade do que eu recebo | repasse: `base: "COMMISSION_RECEIVED"`, `percent: 50` |
| Repasse puxando do agenciamento | repasse: `sourceComponentKeys: ["<chave do componente de recebimento>"]` |
| Gerente leva 10 | no degrau do repasse: `managerPercent: 10` |
| Muda por faixa de vidas | `conditions: { livesMin, livesMax }` |

Limites que o Koter recusa com mensagem clara, e a mensagem diz o componente:

- Chave com até 40 caracteres, em minúsculas, números e hífen, sem repetir.
- Regra de repasse só aceita base `COMMISSION_RECEIVED`, `COMMISSION_EXPECTED`, `PREMIUM_NET` ou `FIXED`, e não aceita taxa em intervalo (`rateMode: RANGE`).
- Base `FIXED` e `PER_LIFE` usam `amount` no degrau, com `rateMode: "AMOUNT"`, sem percentual.
- Degraus não se sobrepõem. Condição por forma de pagamento ainda é recusada.

A combinação de `release`, `releaseAnchor` e `ordinalBasis` de cada componente é justamente a parte nunca executada. Os valores existem no schema (`release`: `UPFRONT`, `PER_INSTALLMENT`, `EXHAUSTION`, `PERIODIC`; `releaseAnchor`: `ISSUANCE`, `FIRST_PAYMENT`, `EACH_PAYMENT`, `EVENT_DATE`; `ordinalBasis`: `PREMIUM_SEQUENCE`, `RELEASE_COUNT`). Se já houver regra publicada, leia uma com `gestao_comissao_list_commission_rule_sets` e copie o desenho dela, em vez de deduzir. Sem nenhuma regra na conta, o ponto de partida é o das tabelas que o Koter converteu do modelo antigo, lido no código e não publicado por esta skill: `release: "PER_INSTALLMENT"` e `releaseAnchor: "EACH_PAYMENT"` em todo componente, de recebimento e de repasse, com `ordinalBasis: "PREMIUM_SEQUENCE"` no agenciamento e `ordinalBasis: "RELEASE_COUNT"` com `ordinalScope: "CHAIN"` na recorrente.

Depois de publicar, releia com `gestao_comissao_list_commission_rule_sets`, confirme status e componentes, e vá para a prova.

**`insuranceCompanyId` aqui é o id do catálogo global**, o mesmo que a proposta grava. A categoria é derivada da operadora no servidor; você não a informa.

Publicar encerra a versão vigente e põe a nova em vigor numa transação só, e os contratos que esperavam regra são montados em seguida. **A primeira publicação de `PAYOUT_DEFAULT` cria a grade "Padrão" sozinha**: não crie grade antes.

Outras alavancas:

- `gestao_comissao_cancel_scheduled_commission_table` desfaz versão agendada que nenhum contrato usa.
- `gestao_comissao_remove_market_commission_table` devolve a praça à regra da seguradora.
- `target.marketId` e `target.productKey` criam regra mais específica, que vence a da seguradora. Com `target.distributorPartyId`, a tabela vale só para contratos daquele distribuidor.

### Variantes e exceções

`gestao_comissao_create_payout_variant(segmentCategoryId, name, sellerIds?, parentGradeId?)` (a categoria vem de `categories` em `gestao_list_segment_catalog`), depois `gestao_comissao_update_commission_grade(gradeId, addSellerIds | removeSellerIds)`. Com `parentGradeId`, a variante segue outra grade no que não tiver de próprio. `draft.inheritance.cells` faz percentuais de uma `PAYOUT_GRADE` acompanharem a base.

`gestao_comissao_apply_seller_deviation(sellerId, changes[], dryRun: true)` simula antes, com `changes[].ruleSet` em `draft` ou `componentSteps`. Depois aplica com `confirm` igual ao desfecho, `MATCH` ou `NEW`.

Condição de uma venda só: `gestao_comissao_create_proposal_payout_agreement(proposalId, name, ruleSet)`, ou exceção no contrato, em `koter-contrato`.

## 5 · O `overrideSplitMode` que vem ligado no pior valor

A grade Padrão nasce com **`overrideSplitMode: "INTEGRAL"`**. Integral significa que, se o vendedor tem dois gerentes, **cada um recebe o percentual inteiro e a casa paga duas vezes**. É a configuração que faz a corretora pagar mais do que recebeu e só descobrir no fechamento.

Quando houver alguém com mais de um líder do mesmo tipo, mostre as três opções (`INTEGRAL`, `DIVIDIDO`, `PRINCIPAL`) e recomende `PRINCIPAL`: `gestao_comissao_update_commission_grade(gradeId, overrideSplitMode)`. A troca recalcula em fila a comissão **ainda não realizada** das vendas da grade, e o andamento aparece em `recomputeRuns` de `gestao_comissao_get_commission_settings`. Quando não houver, não gaste a pergunta, mas **registre que ficou em INTEGRAL**, para reoferecer quando a equipe crescer.

`overrideMaxDepth` (1 a 10) decide quantos níveis o override sobe; vazio vale o teto de 10.

## 6 · A prova: o passo que encerra a skill

> "Me conta uma venda que você comissionou na mão recentemente."

**Simular exige contrato.** Não existe prévia sobre proposta sem implantar, e implantar é ato real: a proposta ganha contrato, e só dá para desfazer enquanto não houver movimento. **Diga isso antes de implantar.**

```
1. gestao_contratos_save_contract(proposalId, statusId: null)      ← null não mexe no funil
2. gestao_contratos_preview_contract_commission(contractId, participants: [{ sellerId }])
3. "Bate com o que você pagou?"
4. Se a venda não era para ficar: gestao_contratos_reverse_contract_implantation(contractId)
```

Cadastre a venda (`koter-proposta`), ou use uma já cadastrada. Implantação e correção de contrato ficam com `koter-contrato`.

**A prévia simula; ela não grava.** É prova de que a regra está certa, não de que o dinheiro existe. Ela funciona mesmo antes de o acompanhamento estar ligado.

O prêmio do contrato vem de `pricing.value` ou de `proposalValue`: um dos dois basta. Se vier `simulated: false`, `reason` diz `MISSING_DATA` (com `missingFields`) ou `NO_RULE`. A resposta traz `sellers`, `slots` (`kind`, `ordinal`, `competence`, `receivable`, `payout`, `margin`, `inScope`, `locked`), `externals`, `receivableTotal`, `payoutTotal`, `margin` e `hasNegativeMargin`.

Conta de referência, feita à mão para conferir o raciocínio, não saída do Koter. Numa venda de R$ 1.500/mês, com agenciamento de 180% e recorrente de 8%, repassando metade:

| Parcela | Recebe | Repassa | Margem |
|---|---|---|---|
| 1 (agenciamento) | 2.700 | 1.350 | 1.350 |
| 2 em diante (recorrente) | 120 | 60 | 60 |

`hasNegativeMargin` acusa quando a soma dos repasses passa do recebimento. **Margem negativa é permitida no Koter** e fica visível ao gestor, então não trate como erro: pergunte se é intencional.

Mostre os números do Koter e pergunte: **bate com o que você pagou?** Se não bate, a diferença aponta o campo: valor errado na primeira é agenciamento; valor errado na cauda é a recorrente ou sua duração; total certo mas data errada é prazo de recebimento.

## 7 · Estado e próxima

Grave o que foi publicado, por operadora, e o que ficou pendente (operadoras sem tabela, `overrideSplitMode` em INTEGRAL, ausência de piso, data do acompanhamento, modelo, operadoras sem política de estorno). Depois:

- **`koter-gestao-repasse`** para transformar isso em dinheiro pago *(recomendada: comissão configurada e ninguém pago não fechou o ciclo)*
- `koter-contrato` para implantar as vendas e cuidar da vida do contrato
- `koter-gestao-campanhas` para metas e premiação
- `koter-gestao-financeiro` para plano de contas e caixa
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Nada foi gerado | `commissionTrackedSince` nulo | `gestao_comissao_save_commission_settings`, P0 |
| Implantou e nada apareceu | cálculo na fila, ou sem acompanhamento | `gestao_comissao_recompute_contract_commission(contractId)` |
| `simulated: false` | falta dado ou regra | `reason` e `missingFields` dizem qual |
| Tabela publicada não vale no contrato | regra não resolveu, ou id errado | `gestao_comissao_get_contract_commission_status`, em `receivableRule`, e a pendência `CONTRACT_WITHOUT_RULE`; use o id do catálogo global |
| Erro de validação ao publicar | formato antigo (`rows`) ou campo inventado | §4, sem `rows`, com `draft.components[].steps[]` |
| Receita projetada alta demais | recorrente assumida vitalícia | P4, sempre |
| Falta o dinheiro da entrada | só a recorrente foi configurada | P3, sempre |
| Estorno não veio | sem política, ou política sem `triggers` e `reasons` | P5b |
| Repasse não libera em baixa parcial | base `PREMIUM_NET` ou `COMMISSION_EXPECTED` | P6; é a regra da base |
| Casa paga duas vezes o override | `overrideSplitMode: INTEGRAL`, que é o default | `gestao_comissao_update_commission_grade` com `overrideSplitMode: PRINCIPAL` |
| Meta embutida na grade | meta é campanha | separe explicitamente; `koter-gestao-campanhas` |
| Vendedor reclama de valor que mudou | `insurerTaxPercent` por operadora **recalcula** o não pago | avise antes de salvar |
| Mudei o imposto do vendedor e nada mudou | `gestao_config_bulk_set_sellers_pass_tax` não refaz o que já existe | só vale daí em diante |
| Vendedor reclama de data que mudou | prazo ou cadência alterados em `gestao_comissao_save_commission_settings` **re-datam** o que está em aberto (só datas, nunca valores) | avise antes de salvar a rotina |

## Conferência

Schemas, enums e mensagens de recusa lidos no código em 03/11/2026, contra o inventário de tools da mesma data. Nada foi executado.
`gestao_comissao_publish_commission_table` no formato de componentes **nunca foi executado** e não tem `dryRun`: o mapa do §4 não é exemplo validado. Remedir numa corretora de demonstração antes de publicar um exemplo aqui.
A conta do §6 é feita à mão. A prova com `gestao_contratos_preview_contract_commission` ainda não rodou. Efeito real de `commissionModel` sobre repasse: sem comprovação.
