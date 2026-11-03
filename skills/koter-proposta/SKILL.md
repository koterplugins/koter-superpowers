---
name: koter-proposta
description: Cadastra uma proposta na Gestão do Koter, com beneficiários, e confere relendo. Use quando pedirem para lançar proposta, incluir dependente, mudar etapa, ou ao fim da trilha do Gestão na /introducao.
---

# koter-proposta

A skill do dia a dia, e o destino do onboarding. As outras são "faça uma vez"; esta é "faça toda semana". **O onboarding só termina quando o corretor cadastrou uma proposta real por aqui**: configuração pronta e ninguém usando é onboarding que falhou.

## 0 · Pré-requisitos

- **Funil de status** (`koter-gestao-fundacao`). Toda corretora já nasce com os quatro status de papel; o funil dele pode ter mais.
- **Campos personalizados** (`koter-gestao-campos`), se ele anota algo que o padrão não tem. Campo `required` criado depois obriga a editar as propostas antigas.
- Vendedor é **opcional** no cadastro. Não trave a primeira proposta esperando `koter-gestao-vendedores`. Mas é da proposta que o contrato copia quem recebe: sem `sellerId` nem `payoutSellers`, o contrato nasce sem vendedor e nenhum repasse existe. Se ele repassa, mande o vendedor.

## 1 · A proposta roda no catálogo global

Segmento, categoria (PF, PME, Adesão, o que antes se chamava modalidade) e seguradora vêm do **catálogo global do Koter**. O cadastro equivalente da corretora é legado e não participa. O schema de `gestao_save_proposal` diz: `insuranceCompanyId` é *"o id de uma seguradora de insuranceCompanies em list_segment_catalog, com o segmentId da proposta. Seguradora fora do segmento é recusada."*

**O `segmentId` é sempre o segmento global.** Id de espaço errado devolve lista vazia em vez de erro. Se `proposalFields` ou as `categories` de `gestao_list_segment_catalog` vierem `[]`, confira o id contra `segments`.

## 2 · Resolver o segmento, depois tudo o mais

```
gestao_fetch_gestao_context                       → segments (Saúde, Dental, Auto...)
gestao_fetch_gestao_context(segmentId: <global>)  → proposalFields, customFieldDefinitions, categories, statuses, sellers, entities, states
```

> **`gestao_fetch_gestao_context` não é leve.** Na medição de 21/09/2026, na corretora de demonstração, deu 42.525 caracteres, antes de a lista de modalidades virar `categories`; não foi medido de novo. Chame só no momento de montar a proposta, nunca no diagnóstico, e leia apenas os campos que for usar.

Escolha o segmento pelo que ele vende (a `koter-gestao-fundacao` guardou isso no estado: não pergunte de novo se já está lá). **A segunda chamada é obrigatória:** é ela que diz quais campos são obrigatórios *naquele segmento*.

A categoria sai de `gestao_list_segment_catalog(segmentId, include: ["categories"])`, e o que a proposta grava é o `id` dela em **`segmentCategoryId`**. Com `insuranceCompanyId`, a categoria sai da própria seguradora (cada linha já traz o seu `segmentCategoryId`).

## 3 · A seguradora, e o problema de tamanho

```
gestao_list_segment_catalog(segmentId: <global>, include: ["insuranceCompanies"],
  segmentCategoryId: <categoria>, insuranceCompanySearch?: "<nome>")
```

`segmentCategoryId` é obrigatório: primeiro a categoria, depois a operadora. A busca só afina dentro da categoria. A mesma operadora pode vir duas vezes na mesma categoria, uma por administradora; `managerName` separa as duas, e é ela que o corretor precisa escolher. A lista é o conjunto válido para aquele segmento.

**A resposta é compacta e paginada:** `{ id, name, managerName, segmentCategoryId }`, com a paginação em `insuranceCompaniesPaging` (`insuranceCompanyPage`, `insuranceCompanyPageSize`, máximo 100).

**Busque, não pagine.** `insuranceCompanySearch` ignora caixa e acento. `includeInsuranceCompanyImages: true` só quando precisar do logo: com imagens cada item pesa cerca de dez vezes mais, e era o que estourava o contexto.

Dois cuidados:

- **Cada linha é operadora × categoria × segmento.** "Amil" em Saúde tem linha de PME e linhas de Adesão. Escolha pela categoria da venda, e confirme em uma linha quando houver mais de um candidato de verdade.
- **A busca ordena por relevância, mas não decide por você.** Nome exato primeiro, depois nomes com alguma palavra começando pelo termo, e só então os que apenas contêm o termo ("São C**amil**o"). Mostre as candidatas reais ao corretor.

## 4 · Montar o payload a partir de `proposalFields`, nunca de um modelo fixo

A API **valida a obrigatoriedade do formulário da corretora**, campos personalizados inclusive. Um campo `required` que existe na conta dele e não no seu modelo derruba a criação com *"Os seguintes campos obrigatórios não foram preenchidos: ..."*.

Leia `proposalFields` do segmento, separe `source: SYSTEM` de `source: CUSTOM`, e só então monte a chamada. Campos personalizados vão em `customFields` como `{ key: valor }`: `DATE` em `yyyy-mm-dd`, `CPF` e `CNPJ` só dígitos, `SELECT` com um dos `value` das opções.

```
gestao_save_proposal                (sem proposalId = cria)
  clientName, clientType (PHYSICAL_PERSON | LEGAL_PERSON)
  segmentId (global), segmentCategoryId (categoria), insuranceCompanyId (catálogo)
  statusId (da corretora), proposalValue, coverageStart, dueDay
  sellerId                   ← o vendedor responsável
  customFields: { ... }
  contactIds: [ ... ]        ← o cliente no CRM; só vale na criação
  payoutSellers: [{ sellerId, payoutGradeId? }]   ← omitido, semeia o vendedor responsável
  beneficiariesDetailed: true
```

**`contactIds` vincula o contato do CRM à proposta.** Se a proposta for criada mas o vínculo falhar, a resposta vem com `proposal` **e** `warning`: **conserte com `gestao_set_proposal_links(proposalId, contacts: [...])` e não recrie** (a lista substitui a atual inteira). Recriar deixa duas propostas do mesmo cliente.

**"Beneficiários" é obrigatório por padrão e trava a criação.** `gestao_save_proposal` não tem parâmetro de beneficiário, e `gestao_save_proposal_beneficiary` precisa de uma proposta que ainda não existe. A saída é **`beneficiariesDetailed: true`**, que satisfaz o campo e passa a contar as vidas pelos beneficiários. `coveredLifes` passa a ser o número de beneficiários, recalculado a cada um; o schema diz que, *"enquanto não houver nenhum, fica o valor informado"*.

Se ele não quer detalhar vidas, `beneficiariesDetailed` fica de fora e `coveredLifes` é informado, mas só funciona se "Beneficiários" não estiver `required` na conta dele (`gestao_config_update_proposal_fields` com `setting` resolve, e isso é decisão dele).

## 5 · Beneficiários

```
gestao_save_proposal_beneficiary(proposalId, role: "TITULAR", name, birthDate, cpf)
gestao_save_proposal_beneficiary(proposalId, role: "DEPENDENTE", name, holderParticipationId)
```

Sem `participationId` adiciona; com ele edita só os campos enviados. Remover é `gestao_delete_proposal_records` (kind `beneficiary`).

**`holderParticipationId` é o `id` da participação do titular, não o `beneficiaryId`.** A resposta do titular traz os dois: use o `id` de fora, o mesmo que `gestao_list_proposals` com `ids` e `include: ["beneficiaries"]` devolve.

Medido em 21/09/2026 na corretora de demonstração: titular e dependente numa proposta `beneficiariesDetailed` levaram `coveredLifes` de 0 para 2 sozinhos.

**Declaração de Saúde:** o agente não preenche nem sugere. CPF do beneficiário vai para o Koter, nunca para memória ou skill.

## 6 · Validação: releia, sempre

```
gestao_list_proposals(ids: [proposalId], include: ["beneficiaries"])
```

Devolve o que ficou gravado, com os nomes resolvidos. É o que você mostra para ele conferir:

> "Cadastrei: **Amil PME, Saúde**, R$ 1.500, 2 vidas, na etapa Cotação. Confere?"

Se algo não aparecer na releitura, **diga**. Não dê por feito o que você não viu.

## 7 · A proposta não vira dinheiro sozinha

```
gestao_save_proposal                                       → proposta, sem contrato
gestao_contratos_save_contract(proposalId, statusId?)      → contrato (a ação Implantar)
gestao_comissao_list_commission_expectations(contractId)   → comissões, se a corretora acompanha
```

`gestao_save_proposal` não implanta. Mover a proposta para "Implantada" **também não**. Só `gestao_contratos_save_contract` faz nascer o contrato, e a comissão sai dele. `gestao_list_proposals` traz `contract` (ou `null`), e o filtro `hasContract: false` acha quem está parado.

Diga ao entregar, em uma linha, em vez de deixá-lo descobrir no fim do mês:

> "Proposta da Maria cadastrada. Para o dinheiro existir, falta implantar. Quer que eu implante?"

O passo a passo de implantar, corrigir e cancelar está na `koter-contrato`.

## 8 · Quanto esta venda rende

Simular exige contrato: não há prévia sobre proposta sem implantar. Depois de implantar:

```
gestao_contratos_preview_contract_commission(contractId, participants?: [{ sellerId, payoutGradeId? }])
```

Antes disso, para só ver a regra: `gestao_comissao_resolve_commission(insuranceCompanyId, sellerId?)`.

`simulated: false` não é falha: `reason` diz `MISSING_DATA`, com `missingFields`, ou `NO_RULE`. Diga o porquê em vez de mostrar o vazio, e ofereça `koter-gestao-comissoes`. Prévia é simulação: nada entrou no caixa.

## 9 · Mudar de etapa

```
gestao_set_proposal_status(proposalIds: [...], statusId, reason)
```

Aceita lote. **Mudar status dispara as automações de Gestão vinculadas àquele status.** Antes de mover em lote, diga quantas propostas vão se mover e que automação pode disparar.

**Mudar status só move no funil:** nunca cria, recusa nem encerra contrato, em qualquer direção, inclusive o de implantada. Cancelar é `gestao_contratos_save_contract_event`. E `gestao_archive_proposal` é recusado com contrato vivo.

## 10 · Editar proposta que já tem contrato

`gestao_save_proposal` com `proposalId` passa ao contrato só o que mudou. A resposta traz `contractTranslation`, com `corrections`, `premiumAdjustment`, `participantsChanged` e `lockedExpectationCount`, as comissões que já têm baixa e não mudam. Mostre isso ao corretor.

Mudar `proposalValue` corrige o prêmio desde o início. Com `premiumEffectiveDate`, vira reajuste daquela data em diante: pergunte qual dos dois ele quer. `payoutSellers` corrige os vendedores do contrato desde o início.

## 11 · Fechamento

Grave em `usou_de_verdade.koter-proposta` a data da primeira proposta. É esse o marco que encerra o **ato 1** da passada única: o Gestão deixou de ser configuração e virou uso.

Depois ofereça, em até 4 opções:

- **`koter-contrato`**: implantar esta proposta *(recomendada: é o que faz o dinheiro existir)*
- `koter-crm-fundacao`: montar o funil, que é o ato 2
- `koter-gestao-comissoes`: configurar comissão para ver quanto esta proposta rende
- cadastrar mais uma proposta agora

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `proposalFields` ou `categories` vêm `[]` | id que não é de `segments` | use o `id` de `segments` de `gestao_fetch_gestao_context` |
| "Os seguintes campos obrigatórios não foram preenchidos: Beneficiários." | campo `required` e sem parâmetro na criação | `beneficiariesDetailed: true` |
| "Os seguintes campos obrigatórios não foram preenchidos: <campo dele>." | payload montado de modelo fixo | monte a partir de `proposalFields` do segmento |
| "Para listar as seguradoras informe segmentCategoryId ..." | pediu seguradora sem categoria | resolva a categoria antes |
| Busca de seguradora traz gente demais | a mesma marca tem várias linhas | filtre por `segmentCategoryId` e confirme com o corretor |
| Seguradora recusada na criação | linha do catálogo é de outro segmento | use `insuranceCompanies` do segmento escolhido |
| Dependente não entra | `holderParticipationId` recebeu o `beneficiaryId` | use o `id` da participação |
| `coveredLifes` não bate com o que mandou | `beneficiariesDetailed: true` conta pelos beneficiários | adicione os beneficiários |
| "Implantada" sem comissão | status não implanta | `gestao_contratos_save_contract(proposalId)` |
| Contrato sem repasse | proposta implantada sem vendedor | `gestao_contratos_save_contract_participants` (`koter-contrato`); trocar só o `sellerId` da proposta não muda o contrato |
| Implantou e nada apareceu | `commissionTrackedSince` nulo, ou montagem na fila | `gestao_comissao_get_commission_settings`; `gestao_comissao_recompute_contract_commission` |
| "Proposta arquivada ou em rascunho não ganha contrato." | proposta inativa ou rascunho | restaure ou conclua |
| "Esta proposta já tem contrato." | implantação repetida | `gestao_list_proposals` traz o contrato |
| `simulated: false` na prévia | falta dado ou regra | `reason` e `missingFields` dizem o quê |
| Corretor acha que a comissão já entrou | prévia não é dinheiro | diga que é simulação, e que o repasse depende de recebimento e conferência |

## Conferência

Tools, parâmetros e mensagens conferidos no inventário e lidos no código em 03/11/2026, não executados.
Criação, beneficiários e catálogo foram medidos em 21/09/2026 na corretora de demonstração e não refeitos. Tamanhos de resposta podem ter mudado.
Implantação e prévia a partir desta skill nunca foram rodadas.
