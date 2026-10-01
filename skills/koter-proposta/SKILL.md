---
name: koter-proposta
description: Cadastra uma proposta no módulo Gestão do Koter, com beneficiários, e confere o resultado relendo. Use quando pedirem para cadastrar, lançar ou registrar uma proposta, incluir beneficiário ou dependente numa proposta, mover proposta de etapa, ou quando /introducao chegar ao fim da trilha do Gestão.
---

# koter-proposta

A skill do dia a dia, e o destino do onboarding. As outras são "faça uma vez"; esta é "faça toda semana". **O onboarding só termina quando o corretor cadastrou uma proposta real por aqui** — configuração pronta e ninguém usando é onboarding que falhou.

## 0 · Pré-requisitos

- **Funil de status** (`koter-gestao-fundacao`). Sem status a proposta até nasce, mas nasce sem etapa.
- **Campos personalizados** (`koter-gestao-campos`), se ele anota algo que o padrão não tem. Campo `required` criado depois obriga a editar as propostas antigas.
- Vendedor é **opcional** no cadastro. Não trave a primeira proposta esperando `koter-gestao-vendedores`.

## 1 · A proposta roda no catálogo global

Ramo, categoria (PF, PME, Adesão — o que antes se chamava modalidade) e seguradora vêm do **catálogo global do Koter**. O cadastro equivalente da corretora é legado e não participa. O schema de `save_proposal` diz isso com todas as letras: `insuranceCompanyId` é *"o id de uma seguradora de insuranceCompanies em list_segment_catalog, com o segmentId da proposta. Seguradora fora do ramo é recusada."*

**O `segmentId` é sempre o ramo global.** O ramo da corretora não existe mais no MCP desde 21/09/2026, então a confusão antiga acabou — mas id de espaço errado continua devolvendo lista vazia em vez de erro. Se `proposalFields` ou as `categories` de `list_segment_catalog` vierem `[]`, confira o id contra `segments`.

## 2 · Resolver o ramo, depois tudo o mais

```
gestao_fetch_gestao_context                       → segments (27 globais: Saúde, Dental, Auto…)
gestao_fetch_gestao_context(segmentId: <global>)  → proposalFields, customFieldDefinitions, categories, statuses, sellers, entities, states
```

> **`gestao_fetch_gestao_context` emagreceu, mas não é leve.** Medido na Koter Day em 21/09/2026, já sem o catálogo de seguradoras: **42.525 caracteres** (eram 173.211). `insuranceCompanies` não vem mais — a operadora se resolve por `list_segment_catalog`. Naquela medição o que pesava era a lista de modalidades (19.417 caracteres, 123 itens de todos os ramos); em 30/09/2026 ela virou `categories`, uma lista plana de todos os ramos, ainda sem medida nova. Continua sendo chamada de montagem de proposta, não de diagnóstico.
>
> **Como conviver:** chame só no momento em que for montar a proposta, nunca no diagnóstico, e leia apenas os campos que for usar. Para a seguradora, resolva pelo ramo com `gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"], insuranceCompanySearch)`, em vez de varrer as 2.304.

Escolha o ramo pelo que ele vende (a `koter-gestao-fundacao` guardou isso no estado — não pergunte de novo se já está lá). **A segunda chamada é obrigatória:** é ela que diz quais campos são obrigatórios *naquele ramo*, e a obrigatoriedade muda de ramo para ramo.

A categoria sai de `gestao_list_segment_catalog(segmentId, include: ["categories"])`, e o que a proposta grava é o `id` dela em **`segmentCategoryId`**. Com `insuranceCompanyId`, a categoria sai da própria seguradora (cada linha de seguradora já traz o seu `segmentCategoryId`).

## 3 · A seguradora — e o problema de tamanho

```
gestao_list_segment_catalog(segmentId: <global>, include: ["insuranceCompanies"],
  insuranceCompanySearch: "<nome>" | segmentCategoryId: <categoria>)
```

Um dos dois filtros é obrigatório desde 01/10/2026: sem eles, pedir `insuranceCompanies` é recusado. Devolve em `insuranceCompanies` o conjunto válido para aquele ramo, e `save_proposal` **rejeita seguradora fora do ramo**.

**A resposta agora é compacta e paginada.** Cada item vem com `{ id, name, segmentCategoryId }` e nada mais, ~128 caracteres; a paginação vem em `insuranceCompaniesPaging` (`insuranceCompanyPage`/`insuranceCompanyPageSize`, padrão 100, máximo 200). Medido em Saúde na Koter Day: `total: 571`, primeira página de 100 em **12.845 caracteres**.

**Busque, não pagine:**

```
gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"], insuranceCompanySearch: "amil")
gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"], segmentCategoryId: <id>)
```

`insuranceCompanySearch` ignora caixa e acento. `includeInsuranceCompanyImages: true` só quando precisar do logo — com imagens cada item custa ~1.440 caracteres (a lista inteira de Saúde passa de 800 KB), e é o que antes estourava o contexto.

Os mesmos dois cuidados da fundação valem aqui:

- **Cada linha é operadora × categoria × ramo.** "Amil" em Saúde tem linha de PME e linhas de Adesão. Escolha pela categoria da venda, e confirme com ele em uma linha quando houver mais de um candidato de verdade.
- **A busca ordena por relevância, mas não decide por você:** o nome exato vem primeiro, depois os nomes com alguma palavra começando pelo termo, e só quando nada disso existe entram os que apenas contêm o termo ("São C**amil**o"). Ainda assim a mesma marca aparece em várias linhas: mostre as candidatas reais ao corretor.

## 4 · Montar o payload a partir de `proposalFields`, nunca de um modelo fixo

A API **valida a obrigatoriedade do formulário da corretora**, campos personalizados inclusive. Um campo `required` que existe na conta dele e não no seu modelo derruba a criação com *"Os seguintes campos obrigatórios não foram preenchidos: …"*.

Então: leia `proposalFields` do ramo, separe `source: SYSTEM` de `source: CUSTOM`, e só então monte a chamada. Campos personalizados vão em `customFields` como `{ key: valor }` — `DATE` em `yyyy-mm-dd`, `CPF`/`CNPJ` só dígitos, `SELECT` com um dos `value` das opções.

```
gestao_save_proposal                (sem proposalId = cria)
  clientName, clientType (PHYSICAL_PERSON | LEGAL_PERSON)
  segmentId (global), segmentCategoryId (categoria), insuranceCompanyId (catálogo)
  statusId (da corretora), proposalValue, coverageStart, dueDay
  customFields: { ... }
  contactIds: [ ... ]        ← o cliente no CRM; só vale na criação
  beneficiariesDetailed: true
```

**`contactIds` vincula o contato do CRM à proposta.** Se a proposta for criada mas o vínculo falhar, a resposta vem com `proposal` **e** `warning`: nesse caso **conserte com `set_proposal_links(proposalId, contacts: [...])` e não recrie a proposta** (a lista substitui a atual inteira) — recriar deixa duas propostas do mesmo cliente, e a segunda é que o corretor vê.

**"Beneficiários" é obrigatório por padrão e trava a criação.** `save_proposal` não tem parâmetro de beneficiário, e `save_proposal_beneficiary` precisa de uma proposta que ainda não existe — o ovo e a galinha. A saída é **`beneficiariesDetailed: true`**, que satisfaz o campo e passa a contar as vidas pelos beneficiários. Consequência: `coveredLifes` passa a ser o número de beneficiários, recalculado a cada um; o schema diz que, *"enquanto não houver nenhum, fica o valor informado"* — então não conte com o número mandado na mão depois do primeiro beneficiário.

Se ele não quer detalhar vidas, aí sim `beneficiariesDetailed` fica de fora e `coveredLifes` é informado — mas só funciona se "Beneficiários" não estiver `required` na conta dele (`gestao_config_update_proposal_fields` com `setting` resolve, e isso é decisão dele, não sua).

## 5 · Beneficiários

```
gestao_save_proposal_beneficiary(proposalId, role: "TITULAR", name, birthDate, cpf)
gestao_save_proposal_beneficiary(proposalId, role: "DEPENDENTE", name, holderParticipationId)
```

Sem `participationId` adiciona; com ele edita só os campos enviados. Remover é `gestao_delete_proposal_records` (kind `beneficiary`).

**`holderParticipationId` é o `id` da participação do titular, não o `beneficiaryId`.** A resposta do titular traz os dois, e trocar é fácil: use o `id` de fora, o mesmo que `list_proposals` com `ids` e `include: ["beneficiaries"]` devolve.

Comprovado na Koter Day: titular + dependente numa proposta `beneficiariesDetailed` levaram `coveredLifes` de 0 para 2 sozinhos.

## 6 · Validação — releia, sempre

```
gestao_list_proposals(ids: [proposalId], include: ["beneficiaries"])
```

Devolve o que ficou gravado, com os nomes resolvidos (ramo, categoria, seguradora e status, cada um com o nome ao lado do id) — é o que você mostra para ele conferir:

> "Cadastrei: **Amil PME, Saúde**, R$ 1.500, 2 vidas, na etapa Cotação. Confere?"

Se algo não aparecer na releitura, **diga**. Não dê por feito o que você não viu.

## 7 · A proposta não gera parcelas

`save_proposal` **não gera parcela nenhuma** na criação — a própria tool avisa: só `gestao_comissao_generate_proposal_installments` cria do zero, e `save_proposal` na edição apenas **regenera** (quando manda `payoutSellers` e já existem parcelas).

Consequência para esta skill: cadastrar a proposta **não** faz a comissão existir. Se o corretor for acompanhar o dinheiro, o passo seguinte é gerar as parcelas — `gestao_comissao_generate_proposal_installments`, que exige `coverageStart`, valor e uma tabela de comissão que resolva para a seguradora e a categoria da proposta, ou na tela. Diga isso ao entregar a proposta, em uma linha, em vez de deixá-lo descobrir no fim do mês.

## 8 · O repasse, quando houver comissão configurada

```
gestao_preview_proposal_payout(proposalId)
```

Simula sem persistir. **Sem vendedor comissionado e sem grade, ela devolve tudo `null` e nenhum erro** — na Koter Day veio `perSeller: []`, `payoutTotal: null`. Isso não é falha: é conta sem comissão configurada. Só ofereça essa prova depois de `koter-gestao-comissoes`, e quando vier vazio, diga o porquê em vez de mostrar o vazio.

## 9 · Mudar de etapa

```
gestao_set_proposal_status(proposalIds: [...], statusId, reason)
```

Aceita lote. **Mudar status dispara as automações de Gestão vinculadas àquele status** — a própria tool avisa. Antes de mover em lote, diga quantas propostas vão se mover e que automação pode disparar.

## 10 · Fechamento

Grave em `usou_de_verdade.koter-proposta` a data da primeira proposta. É esse o marco que encerra o **ato 1** da passada única — o Gestão deixou de ser configuração e virou uso.

E feche com a tarefa de tela na mesma frase, não numa nota de rodapé: registre `pre_requisitos_de_tela.parcelas_geradas` como `pendente` e diga o que ela destrava.

> "Proposta da Maria cadastrada, 3 vidas. Para a comissão dela existir, falta gerar as parcelas — isso é na tela da proposta e leva um clique. Depois disso o repasse tem de onde sair."

Depois ofereça, em até 4 opções:

- **`koter-crm-fundacao`** — montar o funil, que é o ato 2 *(recomendada: é o que faz o lead virar esta proposta sozinho)*
- `koter-gestao-comissoes` — configurar comissão para ver quanto esta proposta rende
- cadastrar mais uma proposta agora
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `proposalFields` ou `categories` vêm `[]` | passou o ramo da corretora no lugar do ramo global | use o `id` de `segments` do `fetch_gestao_context` |
| "campos obrigatórios não preenchidos: Beneficiários" | campo `required` e sem parâmetro na criação | `beneficiariesDetailed: true` |
| "campos obrigatórios não preenchidos: <campo dele>" | payload montado de modelo fixo | monte a partir de `proposalFields` do ramo |
| Busca de seguradora traz gente demais | a mesma marca tem várias linhas, e sem nome exato a busca cai em substring | filtre por `segmentCategoryId` também, e confirme com o corretor |
| `fetch_gestao_context` ainda pesa | 42,5 mil caracteres na última medição (21/09) | chamar só ao montar a proposta, e ler só os campos que for usar |
| Seguradora recusada na criação | linha do catálogo é de outro ramo | use `insuranceCompanies` de `list_segment_catalog` do ramo escolhido |
| Dependente não entra | `holderParticipationId` recebeu o `beneficiaryId` | use o `id` da participação |
| `coveredLifes` não bate com o que mandou | `beneficiariesDetailed: true` conta pelos beneficiários | adicione os beneficiários |
| Preview de repasse todo `null` | sem comissionado ou sem grade | rode `koter-gestao-comissoes` antes |
| Corretor acha que a comissão já entrou | o preview calcula **sem** as parcelas existirem | dizer que é simulação da tabela, e que o lote só enche depois de gerar parcela |
| Proposta cadastrada e comissão não existe | `save_proposal` não gera parcela | `gestao_comissao_generate_proposal_installments`, logo depois de criar |
