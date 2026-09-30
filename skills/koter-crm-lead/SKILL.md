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
crm_list_leads   → phone: "<o número como ele falou>"
```

**O filtro `phone` casa o número em qualquer grafia.** Comprovado na Koter Day em 21/09/2026, contra um lead gravado como `+5511990000003`:

| Consulta | Resultado |
|---|---|
| `(11) 99000-0003` | **achou** |
| `1190000003` (sem o nono dígito) | **achou** |

Com ou sem `+55`, com ou sem o nono dígito, com ou sem máscara — pode perguntar o telefone ao corretor do jeito que ele fala e passar direto. **Buscar antes de criar deixou de ter desculpa.**

## 2 · Criar o lead

```
crm_save_lead   (sem leadId)
```

O que vale saber antes:

- **`name` é o único obrigatório.** Todo o resto é opcional, e é por isso que dá para registrar o lead no meio de uma conversa de WhatsApp com o que ele tiver na mão.
- **O contato vem junto, sozinho.** O `crm_save_lead` procura o contato por `phone`, `mobilePhone` e `email` (o telefone em qualquer grafia) e só cria um novo quando não acha nenhum. Comprovado: uma criação de lead devolveu `contactId` de um contato que não existia antes. Não crie contato antes do lead; se ele já existe, passe `contactId` ou o telefone.
- **`origin` e `tags` vão pelo NOME; `interests` e `statusId` pelo id.** Mistura dos dois espaços é o erro mais comum aqui. **Um nome de origem que não bate com nenhum da lista (nem ignorando caixa, acento e espaço) vira origem nova, sem erro** — confira a grafia contra `origins` do contexto antes de mandar (ver `koter-crm-origens-tags`). Sem `origin`, o lead nasce como "Captação Própria".
- **`statusId` exige `teamId` na criação**, e é sempre conferido contra as etapas do time do lead. Sem `teamId`, o lead nasce fora de qualquer time e sem etapa do funil.
- **`extra` usa a `key` do campo personalizado**, nunca o `label`, e todo valor vai como string. Na edição, `extra`, `tags` e `interests` substituem o conjunto inteiro: repita os atuais que devem ficar.
- **`lgpd`** tem sentido jurídico: `CONSENT` é ele ter autorizado, `LEGITIMATE_INTEREST` e `PREEXISTING_CONTRACT` cobrem cliente e indicação. O padrão é `NOT_PROVIDED`. Marque o que é verdade, não o que é conveniente — e nunca marque `CONSENT` sem o corretor dizer que houve.
- **`perception`** (`COLD`/`WARM`/`HOT`) é o campo nativo de temperatura. Use ele, não tag. **Só vale na criação**: depois, quem muda a temperatura é a ação `CHANGE_PERCEPTION` de uma automação.

### O dono do lead, agora no ato

`crm_save_lead` tem **`ownerUserId`**, nos dois modos:

| Valor | criação (sem `leadId`) | edição (com `leadId`) |
|---|---|---|
| omitido | o dono é quem chamou a tool | não mexe no dono |
| `userId` | atribui àquela pessoa | troca o dono |
| `null` | cria sem dono | remove o dono |

Os ids saem de `responsibles` em `crm_fetch_crm_context` (ou de `members[].userId` dos times em `crm_config_fetch_crm_config_context` com `teamDetails`). **O novo dono precisa ser membro do time do lead**, e atribuir a outra pessoa exige a permissão de criar lead para terceiros — sem ela o lead fica com quem chamou, em silêncio.

Comprovado na Koter Day: a edição com `ownerUserId` registrou no histórico *"Responsável: sem responsável → Walter Gama"*, e a criação com `ownerUserId: null` criou o lead com `owner: null`.

> ⚠️ **`null` não sobrevive a uma automação de atribuição.** No time Comercial, um lead criado com `ownerUserId: null` apareceu logo depois com dono — a automação de fábrica que faz `ASSIGN_AGENT` na entrada assumiu o card. Se o corretor quer mesmo lead sem dono para a fila distribuir, confira o funil depois de criar; o dono que aparecer veio da automação, não da sua chamada.

**Lead sem dono ainda faz falhar automação que cria tarefa para o dono do lead.** A diferença é que agora o conserto é seu e é na hora: passe `ownerUserId` na criação, em vez de montar um `ASSIGN_AGENT` só para isso.

## 3 · Mover no funil

```
crm_save_lead   (com leadId)
```

**A edição grava só o que você manda**: `name` omitido mantém o nome atual. Mande `leadId` e `statusId`, e mais nada, para só mover.

`statusId` move de etapa, e tem que ser uma etapa do time do lead. Mover **dispara as automações de `STATUS_CHANGED`** — é assim que "Marcar cliente fechado" põe a tag `Cliente` sozinha.

Nota antes de contar: use `crm_save_note` com `kind: "lead"`. Nota é onde mora o que foi combinado, e é o que salva a corretora quando o vendedor sai.

## 4 · Agendar o retorno

```
crm_save_task   (sem taskId)
```

- `schedule` pontual é `{ "kind": "ONE_TIME", "oneTimeAt": "<ISO 8601>" }`. Existem também `MONTHLY` e `ANNUAL`, e a anual é a peça da renovação (ver `koter-crm-renovacao`).
- `leadIds` amarra a tarefa ao lead; sem isso ela vira lembrete solto.
- `responsibleIds` sai de `responsibles` em `crm_fetch_crm_context`; omitido, cai em você mesmo.
- `reminderOffsetMinutes` são minutos **antes** do horário.

Comprovado na Koter Day: tarefa criada com `leadIds`, relida em `crm_list_tasks` (com `ids`) com o lead vinculado e o responsável certo.

**Toda conversa que termina sem próximo passo marcado é um lead que vai esfriar.** Quando o corretor contar o que aconteceu e não pedir tarefa, ofereça uma — em opções de data, não em pergunta aberta.

## 5 · Fechar: venda ou perda

### Venda

```
crm_save_lead   → leadId, outcome: { type: "SALE", amount, lifes, billingPaidAt, statusId, optionKey }
```

- `amount`, `lifes` e `billingPaidAt` são obrigatórios. **A marcação é independente do funil**: passe `statusId` dentro do `outcome` para mover junto, ou o lead fica numa etapa do meio com venda marcada. A etapa de venda não realizada é recusada ali.
- `optionKey` amarra a venda ao que ele contratou, vindo de `crm_get_lead_deal_options` (as ofertas precificadas da última cotação). **Sem cotação a lista vem vazia** — comprovado — e aí a venda é manual: passe `null` e o Koter grava `dealSource: { mode: "manual" }`. Omitir `optionKey` é outra coisa: congela o que o negócio do lead já mostrava.
- Comprovado na Koter Day: venda de R$ 4.820,50 / 14 vidas gravou `billing`, `billingPaidAt`, `saleMarkedAt` e um evento `BILLING_PAID` no histórico — e disparou a automação de `STATUS_CHANGED`, que acrescentou a tag `Cliente` ao lead.

### Perda

```
crm_save_lead   → leadId, outcome: { type: "LOSS", lossReasonId, note }
```

- Exige `lossReasonId` e **move o lead sozinho** para a etapa `SALE_NOT_COMPLETED` da equipe. Não mova à mão antes.
- **Pergunte o motivo em opções**, lendo `lossReasons` — motivo escolhido no chute é a razão de o relatório de perda não servir para nada.
- `note` vira nota no lead. Use: "não respondeu depois de 3 cobranças de documento" vale mais que o motivo sozinho.
- **Bloqueado se o lead já tem venda marcada**, ou se ele não está em nenhum time. Desfaça a venda antes com `outcome: { type: "NONE" }` — só depois de o corretor confirmar; o valor e a data de faturamento ficam, só a marcação sai.
- Comprovado na Koter Day: perda com o motivo "Documentação não entregue" gravou `SALE_NOT_COMPLETED` e a nota no histórico, e moveu o lead.

## 6 · A ponte com o Gestão

O lead ganho e a proposta são dois registros. Quem liga os dois:

```
gestao_set_proposal_links   → leads: [...]
```

Comprovado na Koter Day: uma proposta do Gestão passou a apontar para o lead da Padaria Pão Quente numa chamada. A mesma tool com `contacts` faz o mesmo com o contato — uma lista por chamada, `leads` **ou** `contacts`.

**É substituição total**: a lista enviada troca a atual inteira daquele tipo (a do outro fica como está). Para acrescentar, leia o que já está lá (`gestao_list_proposals` com `ids`) e mande a lista completa.

Faça esse vínculo **toda vez que uma venda virar proposta**. É ele que permite olhar uma proposta e saber de onde aquele cliente veio, e é o que faz a origem de lead significar alguma coisa lá na frente.

**No sentido contrário, o caminho automático é a ação `CREATE_LEAD` do motor do Gestão**, que cria o card num time do CRM a partir de uma proposta. Ver `koter-crm-renovacao`.

## 7 · Validação

Releia com `crm_list_leads` (com `ids`) e conte o que ficou gravado, incluindo o que apareceu sozinho:

> "Lead da Padaria Pão Quente criado na Qualificação, PME de 10 a 29 vidas, com tarefa de ligar amanhã às 10h. Marquei a venda: R$ 4.820,50, 14 vidas — e o Koter já marcou ele como Cliente sozinho, pela sua automação."

Contar o efeito da automação é o que faz o corretor confiar nela.

## 8 · Estado

Esta skill não é etapa de onboarding: ela roda sempre. Não marque `concluida` em `etapas` — grave em `usou_de_verdade.koter-crm-lead` a data da primeira vez. É esse o marco que encerra o **ato 2** da passada única.

Com `usou_de_verdade` preenchido nas duas (aqui e em `koter-proposta`), o onboarding cumpriu o que se propôs: o corretor cadastrou uma proposta e um lead de verdade. O que vier depois é o ato 3 — o que passa a rodar sozinho — e a ordem dele sai de `perfil.prioridade`.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `list_leads` com `phone` não acha um lead que existe | o número é de outro dono e o cargo só vê os próprios leads | confirme por nome; a grafia do telefone não é mais a causa |
| Dois leads da mesma pessoa | a busca vazia foi lida como "não existe" | trate vazio como inconclusivo |
| Contato duplicado | contato criado à mão, com outro telefone, antes do lead | `save_lead` já acha ou cria o contato |
| Origem nova e parecida com uma existente | `origin` vai por nome, e nome que não bate vira origem nova | compare com a lista, com acento e caixa, antes de mandar |
| `extra` não grava | usou o `label` no lugar da `key` | leia a `key` no contexto |
| Campos personalizados sumiram depois de editar | `extra` na edição substitui todos | repita os atuais que devem ficar |
| Automação de tarefa não gerou nada | o lead está sem dono | passe `ownerUserId` na criação, ou corrija com `save_lead` |
| `get_lead_deal_options` vem vazio | não houve cotação | venda manual, `optionKey: null` |
| Perda (`outcome` `LOSS`) recusada | o lead tem venda marcada, ou está sem time | `outcome` `NONE` antes, com confirmação |
| Lead com venda marcada parado no meio do funil | o `outcome` `SALE` não move sozinho | passe `statusId` dentro do `outcome` |
| Vínculo com a proposta sumiu | `set_proposal_links` é substituição total | leia a lista atual e mande completa |
