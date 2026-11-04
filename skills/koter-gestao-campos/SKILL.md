---
name: koter-gestao-campos
description: Cria no Koter os campos que o corretor anota na planilha, de proposta e de beneficiário, e ajusta o formulário. Use quando falarem de campo que falta, campo obrigatório ou ordem do formulário.
---

# koter-gestao-campos

Segunda etapa da trilha. É a skill que tira a planilha paralela da mesa do corretor: tudo que ele anota "no caderninho" porque o sistema não tem onde guardar vira campo aqui.

**Faça antes da primeira proposta.** Campo criado depois não volta no passado: as propostas antigas ficam sem ele, e torná-lo obrigatório trava a edição delas (passo 5).

## 0 · Pré-requisitos

Fundação feita. E atenção ao espaço do id: **`segmentId` aqui é o segmento global** (Saúde, Dental, Auto), o mesmo da proposta.

## 1 · Detecção

```
gestao_config_fetch_gestao_config_context(
  include: ["proposalFields", "customFieldDefinitions", "customFieldCategories"],
  segmentId?, includeBeneficiario)
    proposalFields          → o formulário como ele é hoje
    customFieldDefinitions  → o que já foi criado
    customFieldCategories   → onde o campo vai morar
```

`proposalFields` devolve sistema e personalizados juntos, ordenados, com `required`, `visible`, `position` e, o que mais importa, **`locked`**: `{ delete, type, required }`. Campo travado não se mexe, e tentar é como a skill perde a confiança dele.

**As categorias já existem.** Mesmo numa conta nova o Koter traz o agrupador do sistema e os espelhos das categorias do segmento, estes `readOnly`. Não crie categoria sem necessidade; `gestao_config_save_custom_field_category` é para quando ele quiser um agrupamento próprio.

## 2 · A pergunta

Uma só, e concreta:

> **"O que você anota sobre uma venda que não cabe no sistema hoje?"**

Deixe ele falar em lista. Para cada item, você decide três coisas sem perguntar: **tipo**, **escopo** e **se é obrigatório**.

Só volte a perguntar quando a resposta mudar o campo de verdade, por exemplo, se "carência" tem valores fixos (vira `SELECT`) ou é texto livre.

## 3 · Criar

```
gestao_config_save_custom_field_definition   (sem definitionId = cria)
  categoryId      ← de customFieldCategories ("Todas as categorias" serve para quase tudo)
  entityType      ← PROPOSAL | BENEFICIARIO
  key             ← minúsculas, começa por letra: numero_apolice
  label, type     ← TEXT | SELECT | DATE   (REFERENCE é recusado na gestão)
  template        ← CPF | CNPJ | DATE | CURRENCY  (sobrescreve type e options)
  options         ← [{value,label}] quando SELECT
  segmentId       ← segmento GLOBAL; omitir = vale para todos os segmentos
  required, position, placeholder, helpText
```

**`REFERENCE` não vale aqui.** O tipo aparece no schema, mas a gestão recusa: não há catálogo de lead para o campo apontar. Campo de referência é coisa do CRM (`koter-crm-campos`).

**`template` é melhor que `type` quando serve.** `template: "CPF"` já valida formato; `type: "TEXT"` aceita qualquer coisa. Use template para CPF, CNPJ, data e dinheiro.

**Acerte na criação: depois não muda.** Com `definitionId`, a tool edita só `label`, `options`, `required`, `active`, `placeholder`, `helpText` e `position`; categoria, entidade, segmento, `key` e tipo ficam como nasceram. E cuidado ao recriar: uma `key` de campo excluído na mesma categoria, entidade e segmento **reativa aquele campo com o tipo original**: para trocar o tipo, use outra `key`.

**Escopo por segmento é o que faz o formulário parecer feito à mão:** "carência" só em saúde, "placa" só em auto. Omitir `segmentId` deixa o campo em todos os segmentos e polui o formulário de quem vende mais de um.

> **Pegadinha de leitura:** o parâmetro de entrada chama-se `segmentId`, mas na resposta o valor aparece em **`segmentRamoId`**, e `scope: "SEGMENT"`. Se você reler procurando `segmentId`, vai concluir que o escopo não pegou.

**Beneficiário é outra entidade.** `entityType: "BENEFICIARIO"` cria campo na ficha de cada vida, não na proposta: é onde entram CPF do dependente, matrícula, cartão nacional de saúde. Corretora de PME costuma precisar disso e nunca pede por esse nome.

**Não crie campo para Declaração de Saúde.** Esse dado não passa pelo agente: ele não preenche nem sugere.

## 4 · Ajustar o formulário

```
gestao_config_update_proposal_fields(setting: {systemFieldKey, required?, visible?, position?}, segmentId?)
gestao_config_update_proposal_fields(order: [{source, key|id, position}], segmentId?)
```

Um modo por chamada, nunca os dois juntos. `setting` mexe **só em campo de sistema**: não cria nem apaga nada. Campo com `locked.required` não pode virar opcional.

O `order` aceita sistema e personalizado na mesma lista: `source: "SYSTEM"` usa `key`, `source: "CUSTOM"` usa `id`. Mande a lista inteira; posições começam em 0.

**Esconder campo que ele não usa vale tanto quanto criar campo que falta.** Formulário com 17 campos onde 6 importam é o que faz o corretor voltar para a planilha.

## 5 · Obrigatório: a decisão que quebra o passado

**Tornar um campo obrigatório trava a edição das propostas que não o têm.** Medido em 21/09/2026 na corretora de demonstração: com "CPF / CNPJ" marcado obrigatório em Saúde, editar uma proposta antiga sem documento falhou com *"Os seguintes campos obrigatórios não foram preenchidos: CPF / CNPJ."*, e a proposta ficou sem como ser salva.

Então, antes de marcar qualquer campo como obrigatório:

1. Conte quantas propostas ficariam impedidas (`gestao_list_proposals` com filtro de `customFields` ajuda nos personalizados).
2. Diga o número em voz alta e ofereça as duas saídas: **obrigatório só daqui para frente** (criar o campo opcional agora e marcar depois de preencher o histórico) ou **obrigatório já**, assumindo que o histórico precisa ser completado.
3. Reversão é simples: `required: false` volta atrás, desde que o campo não seja `locked`.

Campo obrigatório também atinge a criação por MCP e a importação: toda proposta nova precisa mandá-lo, e a `koter-proposta` monta o payload lendo `proposalFields` justamente por isso. Na migração, `allowIncompleteHistory` da `koter-importacao` aceita registro antigo sem o campo, só com o aval dele.

**Campo personalizado não passa para o contrato.** O que a edição da proposta leva ao contrato são vigência, vencimento, prêmio, seguradora, categoria, estado, titular, documento, vidas, taxa e vendedores (`koter-contrato`).

## 6 · Validação e próxima

Releia `proposalFields` do segmento e mostre o formulário final na ordem em que ele vai ver na tela, marcando o que é obrigatório. Depois:

- **`koter-proposta`**: cadastrar uma proposta e ver o formulário de pé *(recomendada)*
- `koter-gestao-vendedores`: quem vende
- `koter-gestao-comissoes`: quanto cada um leva
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Escopo por segmento "não pegou" | a resposta grava em `segmentRamoId`, não em `segmentId` | leia `segmentRamoId` e `scope` |
| Lista de campos volta vazia | `segmentId` do espaço errado | use o segmento global |
| Proposta antiga não salva mais | campo virou obrigatório | `required: false`, ou complete o histórico |
| Campo não vira opcional | `locked.required` | é campo travado do sistema |
| CPF aceita qualquer coisa | criado como `TEXT` | crie outro com `template: "CPF"` e **outra `key`** (a mesma reativa o campo `TEXT`) |
| Campo some do formulário de outro segmento | criado com `segmentId` | omita para valer em todos |
| Formulário confuso | campos demais visíveis | `visible: false` no que ele não usa |

## Conferência

Tools, parâmetros, tipos e `segmentRamoId` conferidos no inventário e lidos no código em 03/11/2026, não executados.
A trava de campo obrigatório foi medida em 21/09/2026 na corretora de demonstração e não refeita.
