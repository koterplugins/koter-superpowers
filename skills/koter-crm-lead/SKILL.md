---
name: koter-crm-lead
description: A rotina do dia a dia no CRM do Koter — cadastrar lead, achar lead pelo telefone, mover no funil, agendar follow-up, marcar venda ou perda e ligar o lead à proposta do Gestão. Use quando pedirem para cadastrar um cliente novo, registrar um contato que chegou, dar andamento num lead, agendar retorno, marcar venda fechada ou venda perdida.
---

# koter-crm-lead

A skill que roda todo dia, e o destino de toda a trilha do CRM. As outras se fazem uma vez; esta é o trabalho.

## 0 · Pré-requisitos

`crm_fetch_crm_context` numa chamada resolve `teamId`, `statusId`, interesses, tags, campos personalizados (com as `key`) e os enums. **Chame antes de qualquer escrita** — todo id desta skill sai dela.

Permissões: `create:lead`, `update:lead`, `create:task`, `read:lead`.

## 1 · Antes de criar, procure

Lead duplicado é o defeito mais caro do CRM: dois vendedores ligando para a mesma pessoa, e o histórico partido em dois.

```
crm_find_lead_by_phone
```

**Ela casa o número em qualquer grafia.** Comprovado na Koter Day em 21/09/2026, contra um lead gravado como `+5511990000003`:

| Consulta | Resultado |
|---|---|
| `(11) 99000-0003` | **achou** |
| `1190000003` (sem o nono dígito) | **achou** |

Com ou sem `+55`, com ou sem o nono dígito, com ou sem máscara — pode perguntar o telefone ao corretor do jeito que ele fala e passar direto. **Buscar antes de criar deixou de ter desculpa.**

## 2 · Criar o lead

```
crm_create_lead
```

O que vale saber antes:

- **`name` é o único obrigatório.** Todo o resto é opcional, e é por isso que dá para registrar o lead no meio de uma conversa de WhatsApp com o que ele tiver na mão.
- **O contato é criado junto, sozinho.** Comprovado: um `create_lead` devolveu `contactId` de um contato que não existia antes. Não crie contato antes do lead — você acaba com dois.
- **`origin` e `tags` vão pelo NOME; `interests` e `statusId` pelo id.** Mistura dos dois espaços é o erro mais comum aqui. O nome da origem precisa bater com um da lista (ver `koter-crm-origens-tags`).
- **`extra` usa a `key` do campo personalizado**, nunca o `label`, e todo valor vai como string.
- **`lgpd`** tem sentido jurídico: `CONSENT` é ele ter autorizado, `LEGITIMATE_INTEREST` e `PREEXISTING_CONTRACT` cobrem cliente e indicação. O padrão é `NOT_PROVIDED`. Marque o que é verdade, não o que é conveniente — e nunca marque `CONSENT` sem o corretor dizer que houve.
- **`perception`** (`COLD`/`WARM`/`HOT`) é o campo nativo de temperatura. Use ele, não tag.

### O dono do lead, agora no ato

`create_lead` e `update_lead` têm **`ownerUserId`**:

| Valor | `create_lead` | `update_lead` |
|---|---|---|
| omitido | o dono é quem chamou a tool | não mexe no dono |
| `userId` | atribui àquela pessoa | troca o dono |
| `null` | cria sem dono | remove o dono |

Os ids saem de `crm_config_list_teams` → `members[].userId` (a mesma lista de `assignableUsers` do contexto de automação). **O novo dono precisa ser membro do time do lead**, e atribuir a outra pessoa exige a permissão de criar lead para terceiros — sem ela o lead fica com quem chamou, em silêncio.

Comprovado na Koter Day: `update_lead` com `ownerUserId` registrou no histórico *"Responsável: sem responsável → Walter Gama"*, e `create_lead` com `ownerUserId: null` criou o lead com `owner: null`.

> ⚠️ **`null` não sobrevive a uma automação de atribuição.** No time Comercial, um lead criado com `ownerUserId: null` apareceu logo depois com dono — a automação de fábrica que faz `ASSIGN_AGENT` na entrada assumiu o card. Se o corretor quer mesmo lead sem dono para a fila distribuir, confira o funil depois de criar; o dono que aparecer veio da automação, não da sua chamada.

**Lead sem dono ainda faz falhar automação que cria tarefa para o dono do lead.** A diferença é que agora o conserto é seu e é na hora: passe `ownerUserId` na criação, em vez de montar um `ASSIGN_AGENT` só para isso.

## 3 · Mover no funil

```
crm_update_lead
```

**`name` é obrigatório no update.** Chame `crm_get_lead` antes e devolva o nome atual, ou você renomeia o lead sem querer.

`statusId` move de etapa. Mover **dispara as automações de `STATUS_CHANGED`** — é assim que "Marcar cliente fechado" põe a tag `Cliente` sozinha.

Nota antes de contar: use `crm_create_lead_note`. Nota é onde mora o que foi combinado, e é o que salva a corretora quando o vendedor sai.

## 4 · Agendar o retorno

```
crm_create_task
```

- `schedule` pontual é `{ "kind": "ONE_TIME", "oneTimeAt": "<ISO 8601>" }`. Existem também `MONTHLY` e `ANNUAL`, e a anual é a peça da renovação (ver `koter-crm-renovacao`).
- `leadIds` amarra a tarefa ao lead; sem isso ela vira lembrete solto.
- `responsibleIds` sai de `crm_list_responsibles`; omitido, cai em você mesmo.
- `reminderOffsetMinutes` são minutos **antes** do horário.

Comprovado na Koter Day: tarefa criada com `leadIds`, relida em `crm_get_task` com o lead vinculado e o responsável certo.

**Toda conversa que termina sem próximo passo marcado é um lead que vai esfriar.** Quando o corretor contar o que aconteceu e não pedir tarefa, ofereça uma — em opções de data, não em pergunta aberta.

## 5 · Fechar: venda ou perda

### Venda

```
crm_mark_lead_sale
```

- `amount`, `lifes` e `billingPaidAt` são obrigatórios. **A marcação é independente do funil**: passe `statusId` para mover junto, ou o lead fica numa etapa do meio com venda marcada.
- `optionKey` amarra a venda ao que ele contratou, vindo de `crm_get_lead_deal_options` (as ofertas precificadas da última cotação). **Sem cotação a lista vem vazia** — comprovado — e aí a venda é manual: passe `null` e o Koter grava `dealSource: { mode: "manual" }`.
- Comprovado na Koter Day: venda de R$ 4.820,50 / 14 vidas gravou `billing`, `billingPaidAt`, `saleMarkedAt` e um evento `BILLING_PAID` no histórico — e disparou a automação de `STATUS_CHANGED`, que acrescentou a tag `Cliente` ao lead.

### Perda

```
crm_mark_lead_loss
```

- Exige `saleNotCompletedReasonId` e **move o lead sozinho** para a etapa `SALE_NOT_COMPLETED` da equipe. Não mova à mão antes.
- **Pergunte o motivo em opções**, lendo `lossReasons` — motivo escolhido no chute é a razão de o relatório de perda não servir para nada.
- `note` vira nota no lead. Use: "não respondeu depois de 3 cobranças de documento" vale mais que o motivo sozinho.
- **Bloqueado se o lead já tem venda marcada.** Reverta antes com `crm_revert_lead_sale`.
- Comprovado na Koter Day: perda com o motivo "Documentação não entregue" gravou `SALE_NOT_COMPLETED` e a nota no histórico, e moveu o lead.

## 6 · A ponte com o Gestão

O lead ganho e a proposta são dois registros. Quem liga os dois:

```
gestao_set_proposal_leads
```

Comprovado na Koter Day: uma proposta do Gestão passou a apontar para o lead da Padaria Pão Quente numa chamada. `gestao_set_proposal_contacts` faz o mesmo com o contato.

**As duas são substituição total**: a lista enviada troca a atual inteira. Para acrescentar, leia o que já está lá e mande a lista completa.

Faça esse vínculo **toda vez que uma venda virar proposta**. É ele que permite olhar uma proposta e saber de onde aquele cliente veio, e é o que faz a origem de lead significar alguma coisa lá na frente.

**No sentido contrário não existe caminho automático:** nenhuma ação do motor do Gestão cria lead no CRM. Ver `koter-crm-renovacao`.

## 7 · Validação

Releia com `crm_get_lead` e conte o que ficou gravado, incluindo o que apareceu sozinho:

> "Lead da Padaria Pão Quente criado na Qualificação, PME de 10 a 29 vidas, com tarefa de ligar amanhã às 10h. Marquei a venda: R$ 4.820,50, 14 vidas — e o Koter já marcou ele como Cliente sozinho, pela sua automação."

Contar o efeito da automação é o que faz o corretor confiar nela.

## 8 · Estado

Esta skill não é etapa de onboarding: ela roda sempre. Não marque `concluida` em `etapas` — grave em `usou_de_verdade.koter-crm-lead` a data da primeira vez. É esse o marco que encerra o **ato 2** da passada única.

Com `usou_de_verdade` preenchido nas duas (aqui e em `koter-proposta`), o onboarding cumpriu o que se propôs: o corretor cadastrou uma proposta e um lead de verdade. O que vier depois é o ato 3 — o que passa a rodar sozinho — e a ordem dele sai de `perfil.prioridade`.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `find_lead_by_phone` não acha um lead que existe | o número é de outro dono e o cargo só vê os próprios leads | confirme por nome; a grafia do telefone não é mais a causa |
| Dois leads da mesma pessoa | a busca vazia foi lida como "não existe" | trate vazio como inconclusivo |
| O lead foi renomeado sem querer | `update_lead` exige `name` | `get_lead` antes, devolva o nome atual |
| Contato duplicado | contato criado à mão antes do lead | `create_lead` já cria o contato |
| "origem inválida" | `origin` vai por nome e não bateu | compare com a lista, com acento e caixa |
| `extra` não grava | usou o `label` no lugar da `key` | leia a `key` no contexto |
| Automação de tarefa não gerou nada | o lead está sem dono | passe `ownerUserId` na criação, ou corrija com `update_lead` |
| `get_lead_deal_options` vem vazio | não houve cotação | venda manual, `optionKey: null` |
| `mark_lead_loss` recusa | o lead tem venda marcada | `revert_lead_sale` antes |
| Lead com venda marcada parado no meio do funil | `mark_lead_sale` não move sozinho | passe `statusId` |
| Vínculo com a proposta sumiu | `set_proposal_leads` é substituição total | leia a lista atual e mande completa |
