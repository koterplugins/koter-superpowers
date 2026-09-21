---
name: koter-gestao-campos
description: Cria no Koter os campos que o corretor anota fora do sistema — campos personalizados de proposta e de beneficiário, por ramo ou gerais — e ajusta obrigatoriedade, visibilidade e ordem do formulário. Use quando falarem de campo que falta, informação que ele anota na planilha, campo personalizado, deixar campo obrigatório ou mudar a ordem do formulário da proposta.
---

# koter-gestao-campos

Segunda etapa da trilha. É a skill que tira a planilha paralela da mesa do corretor: tudo que ele anota "no caderninho" porque o sistema não tem onde guardar vira campo aqui.

**Faça antes da primeira proposta.** Campo criado depois não volta no passado: as propostas antigas ficam sem ele, e torná-lo obrigatório trava a edição delas (passo 5).

## 0 · Pré-requisitos

Fundação feita. E atenção ao espaço do id: **`segmentId` aqui é o ramo global** (Saúde, Dental, Auto), o mesmo da proposta. O ramo da corretora saiu do MCP em 21/09/2026: não há mais `management_segment` para confundir com este.

## 1 · Detecção

```
gestao_config_get_proposal_fields(segmentId?, includeBeneficiario)  → o formulário como ele é hoje
gestao_config_list_custom_field_definitions                          → o que já foi criado
gestao_config_list_custom_field_categories                           → onde o campo vai morar
```

`get_proposal_fields` devolve sistema e personalizados juntos, ordenados, com `required`, `visible`, `position` e — o que mais importa — **`locked`**: `{ delete, type, required }`. Campo travado não se mexe, e tentar é como a skill perde a confiança dele.

**As categorias já existem.** Mesmo numa conta zerada o Koter traz "Todas as categorias" (sistema) e uma por categoria de contrato — Pessoa Física, Adesão, PME, Empresarial — estas quatro `readOnly`. Não crie categoria sem necessidade; `create_custom_field_category` é para quando ele quiser um agrupamento próprio.

## 2 · A pergunta

Uma só, e concreta:

> **"O que você anota sobre uma venda que não cabe no sistema hoje?"**

Deixe ele falar em lista. Para cada item, você decide três coisas sem perguntar: **tipo**, **escopo** e **se é obrigatório**.

Só volte a perguntar quando a resposta mudar o campo de verdade — por exemplo, se "carência" tem valores fixos (vira `SELECT`) ou é texto livre.

## 3 · Criar

```
gestao_config_create_custom_field_definition
  categoryId      ← de list_custom_field_categories ("Todas as categorias" serve para quase tudo)
  entityType      ← PROPOSAL | BENEFICIARIO
  key             ← minúsculas, começa por letra: numero_apolice
  label, type     ← TEXT | SELECT | DATE   (REFERENCE é recusado na gestão)
  template        ← CPF | CNPJ | DATE | CURRENCY  (sobrescreve type e options)
  options         ← [{value,label}] quando SELECT
  segmentId       ← ramo GLOBAL; omitir = vale para todos os ramos
  required, position, placeholder, helpText
```

**`REFERENCE` não vale aqui.** O tipo aparece no schema, mas a gestão recusa: não há catálogo de lead para o campo apontar. Campo de referência é coisa do CRM (`koter-crm-campos`).

**`template` é melhor que `type` quando serve.** `template: "CPF"` já valida formato; `type: "TEXT"` aceita qualquer coisa. Use template para CPF, CNPJ, data e dinheiro.

**Escopo por ramo é o que faz o formulário parecer feito à mão:** "carência" só em saúde, "placa" só em auto. Omitir `segmentId` deixa o campo em todos os ramos e polui o formulário de quem vende mais de um.

> **Pegadinha de leitura:** o parâmetro de entrada chama-se `segmentId`, mas na resposta o valor aparece em **`segmentRamoId`**, com `segmentId: null` e `scope: "SEGMENT"`. Comprovado na Koter Day. Se você reler procurando `segmentId`, vai concluir que o escopo não pegou.

**Beneficiário é outra entidade.** `entityType: "BENEFICIARIO"` cria campo na ficha de cada vida, não na proposta — é onde entram CPF do dependente, matrícula, cartão nacional de saúde. Corretora de PME costuma precisar disso e nunca pede por esse nome.

## 4 · Ajustar o formulário

```
gestao_config_set_proposal_field_setting(systemFieldKey, required?, visible?, position?, segmentId?)
gestao_config_reorder_proposal_fields(order: [{source, key|id, position}], segmentId?)
```

`set_proposal_field_setting` mexe **só em campo de sistema** — não cria nem apaga nada. Campo com `locked.required` não pode virar opcional.

O reorder aceita sistema e personalizado na mesma lista: `source: "SYSTEM"` usa `key`, `source: "CUSTOM"` usa `id`. Mande a lista inteira; posições começam em 0.

**Esconder campo que ele não usa vale tanto quanto criar campo que falta.** Formulário com 17 campos onde 6 importam é o que faz o corretor voltar para a planilha.

## 5 · Obrigatório: a decisão que quebra o passado

**Tornar um campo obrigatório trava a edição das propostas que não o têm.** Comprovado na Koter Day: com "CPF / CNPJ" marcado obrigatório no ramo Saúde, editar uma proposta antiga sem documento falhou com *"Os seguintes campos obrigatórios não foram preenchidos: CPF / CNPJ."* — e a proposta já existia, intacta, sem como ser salva.

Então, antes de marcar qualquer campo como obrigatório:

1. Conte quantas propostas ficariam impedidas (`gestao_list_proposals` com filtro de `customFields` ajuda nos personalizados).
2. Diga o número em voz alta e ofereça as duas saídas: **obrigatório só daqui para frente** (criar o campo opcional agora e marcar depois de preencher o histórico) ou **obrigatório já**, assumindo que o histórico precisa ser completado.
3. Reversão é simples — `required: false` volta atrás, desde que o campo não seja `locked`.

Campo obrigatório também atinge a criação por MCP: toda proposta nova precisa mandá-lo, e a `koter-proposta` monta o payload lendo `proposalFields` justamente por isso.

## 6 · Validação e próxima

Releia `get_proposal_fields` do ramo e mostre o formulário final na ordem em que ele vai ver na tela, marcando o que é obrigatório. Depois:

- **`koter-proposta`** — cadastrar uma proposta e ver o formulário de pé *(recomendada)*
- `koter-gestao-vendedores` — quem vende
- `koter-gestao-comissoes` — quanto cada um leva
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Escopo por ramo "não pegou" | a resposta grava em `segmentRamoId`, não em `segmentId` | leia `segmentRamoId` / `scope` |
| Lista de campos volta vazia | `segmentId` do espaço errado | use o ramo global |
| Proposta antiga não salva mais | campo virou obrigatório | `required: false`, ou complete o histórico |
| Campo não vira opcional | `locked.required` | é campo travado do sistema |
| CPF aceita qualquer coisa | criado como `TEXT` | recrie com `template: "CPF"` |
| Campo some do formulário de outro ramo | criado com `segmentId` | omita para valer em todos |
| Formulário confuso | campos demais visíveis | `visible: false` no que ele não usa |
