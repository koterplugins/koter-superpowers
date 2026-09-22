---
name: koter-crm-renovacao
description: Monta a rotina de renovação da carteira no Koter — o gatilho anual por data de vigência no Gestão, a fila de tarefas que ele gera no CRM e, quando se justifica, o funil de renovação em equipe própria. Use quando pedirem para não perder renovação, avisar antes do reajuste, acompanhar vencimento de contrato, segurar carteira ou montar pós-venda.
---

# koter-crm-renovacao

A última etapa da trilha do CRM, e a que mais vale dinheiro. Venda nova tem adrenalina e todo mundo cuida; renovação é silenciosa, tem data marcada, e quem não tem rotina só descobre que perdeu o cliente quando a comissão não cai.

## 0 · Pré-requisitos

- `koter-crm-fundacao` rodada.
- **Propostas cadastradas no Gestão com `coverageStart` preenchida.** É de lá que o relógio lê. Carteira que só existe no CRM não tem como disparar renovação — se for o caso, diga isso e mande primeiro para `koter-proposta`.

Permissões: `manage:management-automations`, e as do CRM se for criar equipe.

## 1 · O relógio mora no Gestão, o funil mora no CRM

O dado que dispara a renovação é a **data de vigência da proposta**, e ela vive no Gestão. O funil vive no CRM. Saber quem faz o quê é o que evita montar a rotina no lugar errado:

| | Gestão | CRM |
|---|---|---|
| Gatilho por data de um campo | **`DATE_FIELD`, com recorrência anual** | não existe |
| Abrir card no funil a partir da proposta | **`CREATE_LEAD`** (ação do motor de Gestão) | só a partir de contexto de chat |
| Espera máxima numa automação | — | 90 dias |
| Agendamento fixo | — | `SCHEDULED` (da automação, não relativo ao lead) |
| Funil visual | status de proposta | etapas por equipe |

> **Uma régua de renovação de 12 meses não cabe no motor do CRM** — o teto de espera é 90 dias, e `SCHEDULED` dispara no calendário da automação, não no aniversário de cada cliente. **A renovação se arma no Gestão.**

## 2 · O gatilho, exatamente como ele é

```
gestao_automacao_create_management_automation
trigger: DATE_FIELD
dateField: {
  source: "PROPOSAL",
  field:  "coverageStart",     ← a chave, não "vigencia"
  recurrence: "YEARLY",
  offsetDays: 90,              ← positivo = ANTES
  dayHandling: "CLIP_TO_LAST_DAY"
}
```

- **`offsetDays` positivo é antes.** 90 = noventa dias antes; 0 = no dia; negativo = depois. Teto de 3650.
- **`recurrence: "YEARLY"`** é o que faz a data virar aniversário, todo ano, em vez de um evento único.
- **`dayHandling`** resolve o dia que não existe no mês alvo (31 em abril, 29/02 em ano comum): `CLIP_TO_LAST_DAY` dispara no último dia, `SKIP` não dispara. **Para renovação use `CLIP_TO_LAST_DAY`** — renovação que some silenciosamente em fevereiro é exatamente o defeito que a rotina existe para evitar.
- A varredura é **diária**, uma vez por dia.

### A armadilha de `field`, e o erro que aponta para o lugar errado

A documentação da tool dá **`vigencia`** como exemplo de `field`. `vigencia` é o nome da **coluna**; a chave válida é **`coverageStart`**.

> Comprovado na Koter Day: o mesmo payload com `field: "vigencia"` voltou `valid: false` — e a mensagem foi *"Este gatilho por data exige a configuração de antecedência (dateField) com um número inteiro de dias entre -3650 e 3650"*, **culpando `offsetDays`, que estava correto**. Trocando para `coverageStart`, `valid: true`.

**Se `validate` reclamar de antecedência com um `offsetDays` que você sabe estar certo, o problema é a chave do campo.** Leia o catálogo antes de gravar:

```
gestao_automacao_list_management_automation_triggers → dateFieldsBySource
```

Campos de data de `PROPOSAL`: `coverageStart` (Vigência), `billDueDate`, `implantationDate`, `proposalDate`, `clientBirthDate`.

## 3 · O que o gatilho produz: tarefa no CRM, com o cliente junto

`CREATE_TASK` no motor do Gestão cria a tarefa **já vinculada aos leads e contatos da proposta**, com responsável derivado do dono da proposta ou do vendedor.

É isso que faz a rotina valer: a tarefa não é um lembrete solto, ela abre no cliente certo, com o histórico do lado.

**`dueInDays`** é o prazo da tarefa depois do disparo, não a antecedência — a antecedência é `offsetDays`. Confundir os dois é o erro mais fácil aqui.

O responsável **não é parametrizável**: vem da proposta. Se a corretora tem uma pessoa dedicada à renovação que não é quem vendeu, a tarefa vai cair no vendedor — diga isso antes, e resolva com a equipe de renovação do passo 6, não tentando forçar o responsável.

**Por isso a ponte da `koter-crm-lead` importa:** proposta sem lead vinculado (`gestao_set_proposal_leads`) gera tarefa sem cliente do lado. Antes de armar a renovação, confira se as propostas da carteira estão ligadas aos seus leads.

## 4 · O calendário que funciona

Arme **duas ou três** automações, não seis. Régua demais vira ruído e o corretor desliga tudo.

| Quando | `offsetDays` | O quê |
|---|---|---|
| **D-90** | 90 | tarefa: revisar o contrato — usou o plano? reclamou? incluiu vida? |
| **D-60** | 60 | tarefa: **avisar o corretor** de que o reajuste vem aí |
| **D-45** | 45 | conversa com o cliente — **por humano** |
| D-15 | 15 | decisão registrada: renovado, migrado ou cancelado |

A D-90 e a D-60 são as que se pagam sozinhas. As outras duas são rotina humana, e podem ser tarefa à mão.

> **Nunca arme automação que avise o cliente sobre reajuste.** É a conversa mais delicada do ano, e template frio anunciando aumento é convite para ele cotar no concorrente. A automação avisa o corretor; o corretor avisa o cliente. Essa regra não é negociável e vale a pena dizer em voz alta.

Na PME, lembre que o reajuste vem do **pool de risco**, não do uso daquele cliente — o corretor não tem argumento de sinistralidade, então a preparação da D-90 é o que lhe dá alternativa concreta de mercado para oferecer.

## 5 · A vigência agora abre o card sozinha

O motor do Gestão ganhou a ação **`CREATE_LEAD`**: a mesma automação `DATE_FIELD` sobre `coverageStart` que criava a tarefa pode abrir o card no funil de renovação.

```
ACTION CREATE_LEAD
  teamId        ← o time do funil de renovação (obrigatório)
  statusId      ← a etapa de entrada; omitido, usa a primeira do time
  title         ← omitido, usa o nome do cliente da proposta
  origin, tags
  assigneeType  ← PROPOSAL_OWNER (padrão) ou SPECIFIC_USER + assigneeUserId
```

Ela reaproveita o contato da proposta (cria um se faltar), vincula o lead de volta à proposta e **não duplica**: se a proposta já tem lead aberto naquele time, o passo é sucesso sem criar outro. Revalidado na Koter Day em 22/09/2026: o primeiro disparo terminou `SUCCESS`, criou o lead e o contato e **gravou os dois vínculos na proposta**; o segundo disparo na mesma proposta voltou `SUCCESS` sem criar um segundo card. O defeito antigo do vínculo está corrigido.

**Tarefa e card não são a mesma decisão.** `CREATE_TASK` avisa quem cuida; `CREATE_LEAD` abre o trabalho no funil. Uma automação pode ter os dois passos — e para quem tem pessoa dedicada à renovação, deve ter.

**Para produção antiga ou importada, a ação é `CREATE_CONTACT`**, não `CREATE_LEAD`: ela garante o contato vinculado à proposta sem poluir o funil com card de quem não está em renovação agora.

Medido na Koter Day: primeiro disparo criou o contato e vinculou (log `SUCCESS`); segundo disparo na mesma proposta voltou `SUCCESS` **sem criar um segundo contato**, como promete a descrição.

> ⚠️ Medido: o contato criado por `CREATE_CONTACT` **nasce só com o nome**. A ação promete nome, e-mail e nascimento, mas a proposta do Koter não tem campo de e-mail nem de nascimento do titular — então não há insumo, e por tabela o "reaproveita o contato de mesmo e-mail" nunca tem o que casar. Espere contato só com nome, e complete com `crm_update_contact` se o corretor precisar.

## 6 · O funil de renovação: quando vale o custo

Criar funil de renovação é **criar equipe** (ver `koter-crm-fundacao`). Pergunta em opções:

- **Fila de tarefas no Gestão** — funciona sem estrutura nova, e a data fica onde ela de fato existe. **← recomendada para quem faz renovação entre uma coisa e outra**
- **Equipe e funil de renovação no CRM**, alimentados sozinhos pela ação `CREATE_LEAD` da mesma automação — dá o quadro visual e a métrica de retenção separada, e ninguém precisa mover card à mão. Custo: mais uma equipe para manter.
- **As duas** — a tarefa avisa, o card organiza o trabalho. É o desenho certo para quem tem alguém dedicado à renovação.

**Só crie a equipe se a resposta da `koter-crm-fundacao` sobre quem cuida da renovação tiver sido "pessoa dedicada".** Com a equipe criada, o `teamId` dela é o que entra no `CREATE_LEAD` da automação — o funil passa a se encher sozinho.

Se criar, o funil que funciona — montado renomeando as três etapas de sistema, nunca criando etapas paralelas a elas:

```
A renovar (PENDING)  →  Reajuste recebido  →  Cliente avisado  →  Alternativas cotadas
  →  Renovado (INVOICED_SALES)  |  Migrado  |  Cancelado (SALE_NOT_COMPLETED)
```

Comprovado na Koter Day: equipe "Renovação" (`OPERATIONAL`) criada, as três etapas de sistema renomeadas mantendo o `defaultType`, quatro etapas inseridas e a ordem corrigida com `reorder_lead_statuses` — 7 etapas conferidas na releitura.

**"Migrado" tem que existir separado de "Renovado" e de "Cancelado":** é o cliente que ficou na corretora e trocou de produto. Comercialmente é vitória, e se cair em "Cancelado" a corretora lê a própria retenção errado.

E por que separar da venda nova, quando ele perguntar: a métrica é outra (retenção, não conversão), o gatilho é uma data sabida com um ano de antecedência, o responsável muitas vezes não é quem vendeu, e cliente renovando parado em "Negociação" no meio dos leads novos polui a previsão de vendas.

## 7 · Pós-venda, que é a outra metade

Três rotinas que seguram carteira e não dependem de canal nenhum:

1. **Boas-vindas depois da implantação** — cartão, rede, como usar, o que é carência. Automatizável com `PROPOSAL_STATUS_CHANGED` → tarefa.
2. **Estar presente no primeiro uso ou no primeiro problema.** É onde o cliente decide se a corretora serve para algo além de vender.
3. **Movimentação em dia** — inclusão e exclusão de vidas. Burocrático, invisível, e é o que faz o RH manter ou trocar a corretora.

E o que quase ninguém faz: **revisão anual fora do reajuste**, uma conversa no meio do ano sem má notícia. É quando aparecem cross-sell e indicação. Uma automação `DATE_FIELD` com `offsetDays: 180` resolve.

O **pedido de indicação depois da implantação** é o de melhor retorno de todos: a origem que mais converte, pedida no único momento em que o cliente está feliz.

## 8 · Validação — e o limite honesto dela

Releia com `gestao_automacao_list_management_automations` e confira `dateField` e `active`.

**Mas a criação não prova o disparo.** A varredura de `DATE_FIELD` roda **uma vez por dia**, então a automação armada hoje só aparece no log quando a varredura passar por uma proposta cuja data caia na janela. Comprovado na Koter Day: a automação D-90 foi criada, validada e nasceu ativa, e `get_management_automation_logs` voltou vazio no mesmo minuto — porque a única proposta da conta tem vigência em 01/10/2026, e o D-90 dela já passou.

Diga isso ao corretor exatamente assim, sem prometer o que você não viu:

> "Armei a régua de D-90 sobre a data de vigência. Ela varre uma vez por dia, então a primeira tarefa aparece quando a primeira proposta entrar na janela — vale conferir amanhã em Automações."

E **combine a conferência**: `gestao_automacao_get_management_automation_logs` no dia seguinte é o que transforma "armei" em "está rodando".

## 9 · Estado

Grave em `.koter/onboarding.json`: etapa `concluida`, as automações de data criadas com o `offsetDays` de cada uma, e a escolha do passo 6 (fila, funil, ou os dois).

Com esta skill a trilha do CRM fecha. Depois, em até 4 opções — **leia o estado antes**, e ofereça a trilha que ainda está `pendente`:

- **`koter-zap-fundacao`** — o canal, se o KoterZap ainda não foi tocado *(recomendada quando `perfil.prioridade` é `atendimento`: é a trilha que falta)*
- `koter-gestao-comissoes` — se o Gestão parou na primeira proposta
- `koter-crm-lead` — usar no dia a dia
- parar por aqui

Se a tarefa de tela 1 (Cloud API) ainda estiver `pendente`, diga aqui em uma linha que a régua de mensagem desta renovação só liga depois dela — e ofereça `koter-chatbot-fluxo`, que se monta inteiro sem número conectado.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `validate` reclama da antecedência com `offsetDays` correto | `field` recebeu `vigencia` em vez de `coverageStart` | leia `dateFieldsBySource`; a mensagem culpa o campo errado |
| Dois cards do mesmo cliente no funil de renovação | a primeira execução do `CREATE_LEAD` falhou e deixou o lead sem vínculo | leia os logs; apague o órfão — da segunda em diante a dedupe segura |
| A régua disparou uma vez e nunca mais | `recurrence: ONCE` | `YEARLY` |
| Renovação de contrato de 31 some em abril | `dayHandling: SKIP` | `CLIP_TO_LAST_DAY` |
| A tarefa vence antes de o corretor ter tempo | `dueInDays` confundido com `offsetDays` | `offsetDays` é a antecedência; `dueInDays` é o prazo da tarefa |
| Tarefa de renovação sem cliente do lado | proposta sem lead vinculado | `gestao_set_proposal_leads` |
| A tarefa caiu no vendedor, não na renovação | o responsável vem da proposta e não é parametrizável | equipe de renovação (passo 6) |
| O lead não aparece no funil de renovação | nenhuma ação do Gestão cria lead no CRM | fila de tarefas, ou alguém move o card |
| Webhook não consegue criar o lead | payload fixo, sem telefone nem e-mail | não conte com esse caminho hoje |
| Nada no log depois de criar | a varredura é diária | confira no dia seguinte |
| Cliente reclamou do aviso de reajuste | régua automática falou de reajuste | a automação avisa o corretor, nunca o cliente |
