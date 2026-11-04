---
name: koter-crm-renovacao
description: Monta a rotina de renovação no Koter a partir do fim de vigência do contrato, com tarefas e funil. Use quando pedirem para não perder renovação, acompanhar vencimento ou segurar carteira.
---

# koter-crm-renovacao

A última etapa da trilha do CRM, e a que mais vale dinheiro. Venda nova tem adrenalina e todo mundo cuida; renovação é silenciosa, tem data marcada, e quem não tem rotina só descobre que perdeu o cliente quando a comissão não cai.

## 0 · Pré-requisitos

- `koter-crm-fundacao` rodada.
- **Contratos implantados, com `endsAt` preenchido.** É de lá que o relógio lê. Contrato, implantação e o que muda com ele são assunto da `koter-contrato`: se `gestao_contratos_list_contracts` vier vazio, comece por ela. Carteira que só existe no CRM não tem como disparar renovação; mande primeiro para `koter-proposta`.

Permissões: gerenciar automações do Gestão, ver contratos, e as do CRM se for criar equipe. Precisa dos toolsets `gestao-automacao` e `gestao-contratos`.

## 1 · O relógio mora no Gestão, o funil mora no CRM

O dado que dispara a renovação é o **fim da vigência do contrato**, e ele vive no Gestão. O funil vive no CRM. Saber quem faz o quê é o que evita montar a rotina no lugar errado:

| | Gestão | CRM |
|---|---|---|
| Gatilho por data de um campo | **`DATE_FIELD` sobre `CONTRACT`** | não existe |
| Abrir card no funil a partir do contrato | **`CREATE_LEAD`** (ação do motor de Gestão) | só a partir de contexto de chat |
| Espera máxima numa automação | 90 dias | 90 dias |
| Agendamento fixo | - | `SCHEDULED` (da automação, não relativo ao lead) |
| Funil visual | status de proposta | etapas por equipe |

> **Uma régua de renovação de 12 meses não cabe no motor do CRM**: o teto de espera é 90 dias, e `SCHEDULED` dispara no calendário da automação, não na data de cada cliente. **A renovação se arma no Gestão.**

## 2 · O gatilho, exatamente como ele é

```
gestao_automacao_validate_management_automation   ← SEMPRE antes: o save já nasce ativo
gestao_automacao_save_management_automation       ← sem automationId: cria PUBLICADA e ATIVA
trigger: DATE_FIELD
dateField: {
  source: "CONTRACT",
  field:  "endsAt",            ← fim da vigência
  recurrence: "ONCE",          ← a própria data, uma vez
  offsetDays: 90,              ← positivo = ANTES
  dayHandling: "CLIP_TO_LAST_DAY"
}
```

- **`endsAt` é o fim da vigência.** `CONTRACT` só varre contratos vivos: ativos ou suspensos. Cancelado não dispara.
- **`offsetDays` positivo é antes.** 90 = noventa dias antes; 0 = no dia; negativo = depois. Teto de 3650.
- **`recurrence: "ONCE"`** porque `endsAt` já é a data de cada ciclo. Quando a renovação é registrada, `gestao_contratos_save_contract_event` com `type: "RENEWAL"` leva o novo `endsAt` (ver `koter-contrato`).
- **Contrato sem `endsAt`** não dispara por esse campo. Para ele, use `field: "startsAt"` com `recurrence: "YEARLY"`, que faz o início virar aniversário todo ano.
- **`dayHandling`** resolve o dia que não existe no mês alvo (31 em abril, 29/02 em ano comum): `CLIP_TO_LAST_DAY` dispara no último dia, `SKIP` não dispara. **Para renovação use `CLIP_TO_LAST_DAY`**: renovação que some em silêncio em fevereiro é exatamente o defeito que a rotina existe para evitar.
- A varredura é **diária**, uma vez por dia.

As condições dessa fonte enxergam, entre outros, `contractNumber`, `holderName`, `segmentId`, `insuranceCompanyId`, `sellerId`, `endsAt` e `currentPremium`. A lista completa está em `contextFieldsBySource` de `gestao_automacao_fetch_management_automation_context`.

> **Sem prazo legal aqui.** D-90, D-60 e companhia são rotina de trabalho da corretora, não prazo de lei nem de apólice. Se o corretor perguntar qual é o prazo para avisar, recusar ou renovar, a resposta é: confirme com seu jurídico e leia o contrato daquela seguradora. Não escreva prazo legal em tarefa, automação ou mensagem.

### O erro que aponta para o lugar errado

Se `field` não está no catálogo, a recusa culpa outra coisa:

> *"Este gatilho por data exige a configuração de antecedência (dateField) com um número inteiro de dias entre -3650 e 3650."*

Medido na corretora de demonstração: com `field: "vigencia"`, que é nome de coluna e não chave, voltou essa mensagem, **culpando `offsetDays`, que estava correto**. **Se `gestao_automacao_validate_management_automation` reclamar de antecedência com um `offsetDays` que você sabe estar certo, o problema é a chave do campo.** Leia o catálogo antes de gravar:

```
gestao_automacao_fetch_management_automation_context → dateFieldsBySource
```

Campos de `CONTRACT`: `endsAt` e `startsAt`.

### Carteira que ainda não virou contrato

Proposta antiga sem contrato não aparece em `CONTRACT`. O caminho certo é implantar (ver `koter-contrato`). Enquanto isso não acontece, o plano B é `source: "PROPOSAL"`, `field: "coverageStart"`, `recurrence: "YEARLY"`: a data de início vira aniversário. Campos de data de `PROPOSAL`: `coverageStart`, `billDueDate`, `implantationDate`, `proposalDate`, `clientBirthDate`. Diga ao corretor que é provisório.

## 3 · O que o gatilho produz: tarefa no CRM, com o cliente junto

`CREATE_TASK` no motor do Gestão cria a tarefa **já vinculada aos leads e contatos da proposta de origem do contrato**. Ele entra como um passo `ACTION` na lista `steps` da automação:

```
steps: [
  { id: "<uuid>", kind: "ACTION", type: "CREATE_TASK",
    params: { title: "Revisar a renovação", scheduleType: "RELATIVE", dueInDays: 7,
              assigneeType: "PROPOSAL_OWNER" } }
]
```

É isso que faz a rotina valer: a tarefa não é um lembrete solto, ela abre no cliente certo, com o histórico do lado.

**`dueInDays`** é o prazo da tarefa depois do disparo, não a antecedência; a antecedência é `offsetDays`. Confundir os dois é o erro mais fácil aqui.

O responsável é `assigneeType`: `PROPOSAL_OWNER` (o padrão: o dono da proposta, senão o usuário do vendedor) ou `SPECIFIC_USER` com `assigneeUserId`. Se a corretora tem uma pessoa dedicada à renovação que não é quem vendeu, use `SPECIFIC_USER` com o `userId` dela, senão a tarefa cai no vendedor. Numa carteira dividida entre várias pessoas de renovação, um usuário fixo não basta, e aí o caminho é a equipe de renovação do passo 6.

**Contrato sem proposta de origem não roda essas ações.** Lido no código: `CREATE_TASK`, `CREATE_LEAD` e `CREATE_CONTACT` precisam de proposta no contexto, e o log traz *"Ação ignorada: CREATE_TASK exige uma proposta no contexto."* Antes de armar, confira `originProposalId` em `gestao_contratos_list_contracts`: contrato pode existir sem ele.

**Por isso a ponte da `koter-crm-lead` importa:** proposta sem lead vinculado (`gestao_set_proposal_links` com `leads`) gera tarefa sem cliente do lado. Antes de armar a renovação, confira se as propostas da carteira estão ligadas aos seus leads.

## 4 · O calendário que funciona

Arme **duas ou três** automações, não seis. Régua demais vira ruído e o corretor desliga tudo.

| Quando | `offsetDays` | O quê |
|---|---|---|
| **D-90** | 90 | tarefa: revisar o contrato. Usou o plano? Reclamou? Incluiu vida? |
| **D-60** | 60 | tarefa: **avisar o corretor** de que o reajuste vem aí |
| **D-45** | 45 | conversa com o cliente, **por humano** |
| D-15 | 15 | decisão registrada: renovado, migrado ou cancelado |

A D-90 e a D-60 são as que se pagam sozinhas. As outras duas são rotina humana, e podem ser tarefa à mão.

> **Nunca arme automação que avise o cliente sobre reajuste.** É a conversa mais delicada do ano, e template frio anunciando aumento é convite para ele cotar no concorrente. A automação avisa o corretor; o corretor avisa o cliente. Essa regra não é negociável e vale a pena dizer em voz alta.

> **Porta de cuidado.** `gestao_automacao_save_management_automation` não sai marcada como destrutiva e alcança cliente: a ação `SEND_WHATSAPP_TEMPLATE` do Gestão manda ao contato da proposta. Essa ação só se configura na tela e a tool recusa esse passo em `steps`, mas `active` e `publish` ligam a automação que já o carrega. Deixe a tool em "Precisa de aprovação" na IA do corretor, e nesta rotina use só `CREATE_TASK` e `CREATE_LEAD`. Se ele pedir um template fora de reajuste, é passo de tela; lá a ação exige instância Cloud API e template aprovado, e proposta sem contato vinculado falha o passo. Antes de ligar uma automação que já tenha template, mostre texto, público e data. Nada aqui envia mensagem na hora: é a automação que envia depois, sozinha.

Na PME, lembre que o reajuste costuma vir do **pool de risco**, não do uso daquele cliente: o corretor não tem argumento de sinistralidade, então a preparação da D-90 é o que lhe dá alternativa concreta de mercado para oferecer.

## 5 · A vigência abre o card sozinha

A ação **`CREATE_LEAD`** do motor do Gestão: a mesma automação `DATE_FIELD` que cria a tarefa pode abrir o card no funil de renovação.

```
ACTION CREATE_LEAD
  teamId        ← o time do funil de renovação (obrigatório)
  statusId      ← a etapa de entrada; omitido, usa a primeira do time
  title         ← omitido, usa o nome do cliente da proposta
  origin, tags
  assigneeType  ← PROPOSAL_OWNER (padrão) ou SPECIFIC_USER + assigneeUserId
```

Ela reaproveita o contato da proposta (cria um se faltar), vincula o lead de volta à proposta e **não duplica**: se a proposta já tem lead aberto naquele time, o passo é sucesso sem criar outro. Medido na corretora de demonstração em 22/09/2026, sobre proposta: o primeiro disparo terminou `SUCCESS`, criou o lead e o contato e **gravou os dois vínculos na proposta**; o segundo disparo na mesma proposta voltou `SUCCESS` sem criar um segundo card.

**Tarefa e card não são a mesma decisão.** `CREATE_TASK` avisa quem cuida; `CREATE_LEAD` abre o trabalho no funil. Uma automação pode ter os dois passos, e para quem tem pessoa dedicada à renovação, deve ter.

**Para produção antiga ou importada, a ação é `CREATE_CONTACT`**, não `CREATE_LEAD`: ela garante o contato vinculado à proposta sem poluir o funil com card de quem não está em renovação agora.

Medido na corretora de demonstração: primeiro disparo criou o contato e vinculou (log `SUCCESS`); segundo disparo na mesma proposta voltou `SUCCESS` **sem criar um segundo contato**.

> O contato criado por `CREATE_CONTACT` **nasce só com o nome**: a proposta não guarda telefone, e por isso não há deduplicação por e-mail. Complete com `crm_save_contact` (com `contactId`) se o corretor precisar.

## 6 · O funil de renovação: quando vale o custo

Criar funil de renovação é **criar equipe** (ver `koter-crm-fundacao`). Pergunta em opções:

- **Fila de tarefas no Gestão**: funciona sem estrutura nova, e a data fica onde ela de fato existe. **← recomendada para quem faz renovação entre uma coisa e outra**
- **Equipe e funil de renovação no CRM**, alimentados sozinhos pela ação `CREATE_LEAD` da mesma automação: dá o quadro visual e a métrica de retenção separada, e ninguém precisa mover card à mão. Custo: mais uma equipe para manter.
- **As duas**: a tarefa avisa, o card organiza o trabalho. É o desenho certo para quem tem alguém dedicado à renovação.

**Só crie a equipe se a resposta da `koter-crm-fundacao` sobre quem cuida da renovação tiver sido "pessoa dedicada".** Com a equipe criada, o `teamId` dela é o que entra no `CREATE_LEAD` da automação: o funil passa a se encher sozinho.

Se criar, o funil que funciona, montado renomeando as três etapas de sistema, nunca criando etapas paralelas a elas:

```
A renovar (PENDING)  →  Reajuste recebido  →  Cliente avisado  →  Alternativas cotadas
  →  Renovado (INVOICED_SALES)  |  Migrado  |  Cancelado (SALE_NOT_COMPLETED)
```

Medido na corretora de demonstração: equipe "Renovação" (`OPERATIONAL`) criada, as três etapas de sistema renomeadas mantendo o `defaultType`, quatro etapas inseridas e a ordem corrigida com `crm_config_reorder_lead_statuses`: 7 etapas conferidas na releitura.

**"Migrado" tem que existir separado de "Renovado" e de "Cancelado":** é o cliente que ficou na corretora e trocou de produto. Comercialmente é vitória, e se cair em "Cancelado" a corretora lê a própria retenção errado.

E por que separar da venda nova, quando ele perguntar: a métrica é outra (retenção, não conversão), o gatilho é uma data sabida com antecedência, o responsável muitas vezes não é quem vendeu, e cliente renovando parado em "Negociação" no meio dos leads novos polui a previsão de vendas.

**Card em "Renovado" não renova o contrato.** O card é trabalho; o contrato é outra coisa. Registrar a renovação é `gestao_contratos_save_contract_event` com `type: "RENEWAL"`, e essa parte é da `koter-contrato`.

## 7 · Pós-venda, que é a outra metade

Três rotinas que seguram carteira e não dependem de canal nenhum:

1. **Boas-vindas depois da implantação**: cartão, rede, como usar, o que é carência. Automatizável com o gatilho `CONTRACT_IMPLANTED` → tarefa.
2. **Estar presente no primeiro uso ou no primeiro problema.** É onde o cliente decide se a corretora serve para algo além de vender.
3. **Movimentação em dia**: inclusão e exclusão de vidas. Burocrático, invisível, e é o que faz o RH manter ou trocar a corretora.

E o que quase ninguém faz: **revisão anual fora do reajuste**, uma conversa no meio do ano sem má notícia. É quando aparecem cross-sell e indicação. Uma automação `DATE_FIELD` com `offsetDays: 180` resolve.

O **pedido de indicação depois da implantação** é o de melhor retorno de todos: o canal que costuma converter mais, pedido no momento em que o cliente está feliz.

## 8 · Validação, e o limite honesto dela

Releia com `gestao_automacao_list_management_automations` e confira `dateField` e `active`.

**Mas a criação não prova o disparo.** A varredura de `DATE_FIELD` roda **uma vez por dia**, então a automação armada hoje só aparece no log quando a varredura passar por um contrato cuja data caia na janela. Medido na corretora de demonstração, com a régua sobre proposta: a automação D-90 foi criada, validada e nasceu ativa, e `gestao_automacao_list_automation_logs` voltou vazio no mesmo minuto, porque o D-90 da única proposta da conta já tinha passado.

Diga isso ao corretor exatamente assim, sem prometer o que você não viu:

> "Armei a régua de D-90 sobre o fim de vigência dos contratos. Ela varre uma vez por dia, então a primeira tarefa aparece quando o primeiro contrato entrar na janela. Vale conferir amanhã em Automações."

E **combine a conferência**: `gestao_automacao_list_automation_logs` no dia seguinte é o que transforma "armei" em "está rodando".

## 9 · Estado

Grave em `.koter/onboarding.json`: etapa `concluida`, as automações de data criadas com o `offsetDays` de cada uma, e a escolha do passo 6 (fila, funil, ou os dois).

Com esta skill a trilha do CRM fecha. Depois, em até 4 opções, **leia o estado antes** e ofereça a trilha que ainda está `pendente`:

- **`koter-zap-fundacao`**: o canal, se o KoterZap ainda não foi tocado *(recomendada quando `perfil.prioridade` é `atendimento`: é a trilha que falta)*
- `koter-contrato`: implantar o que ainda não virou contrato e registrar renovação
- `koter-crm-lead`: usar no dia a dia
- parar por aqui

Se a tarefa de tela 1 (Cloud API) ainda estiver `pendente`, diga aqui em uma linha que nenhuma régua com mensagem liga antes dela, e ofereça `koter-chatbot-fluxo`, que se monta inteiro sem número conectado.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `gestao_automacao_validate_management_automation` reclama da antecedência com `offsetDays` correto | `field` fora do catálogo | leia `dateFieldsBySource`; a mensagem culpa o campo errado |
| *"Ação ignorada: CREATE_TASK exige uma proposta no contexto."* | contrato sem proposta de origem | confira `originProposalId`; sem ela, a ação não roda |
| Nenhum contrato dispara | contrato sem `endsAt`, ou cancelado, ou a carteira ainda é só proposta | `startsAt` com `YEARLY`, ou `koter-contrato` |
| Dois cards do mesmo cliente no funil de renovação | a primeira execução do `CREATE_LEAD` falhou e deixou o lead sem vínculo | leia os logs; apague o órfão, da segunda em diante a dedupe segura |
| Renovação de contrato de dia 31 some em abril | `dayHandling: SKIP` | `CLIP_TO_LAST_DAY` |
| A tarefa vence antes de o corretor ter tempo | `dueInDays` confundido com `offsetDays` | `offsetDays` é a antecedência; `dueInDays` é o prazo da tarefa |
| Tarefa de renovação sem cliente do lado | proposta sem lead vinculado | `gestao_set_proposal_links` com `leads` |
| A tarefa caiu no vendedor, não na renovação | `assigneeType` omitido vale `PROPOSAL_OWNER` | `SPECIFIC_USER` com `assigneeUserId`, ou equipe de renovação (passo 6) |
| O lead não aparece no funil de renovação | a automação não tem o passo `CREATE_LEAD`, ou o `teamId` dele aponta para outra equipe | acrescente o `CREATE_LEAD` com o `teamId` certo e confira em `gestao_automacao_list_automation_logs` |
| Nada no log depois de criar | a varredura é diária | confira no dia seguinte |
| Cliente reclamou do aviso de reajuste | régua automática falou de reajuste | a automação avisa o corretor, nunca o cliente |

## Conferência

`CONTRACT`, `endsAt`, `startsAt`, ações e mensagens conferidos contra o código de `gestao-automacao` e `gestao-contratos` em 03/11/2026, por leitura, sem execução. As medições citadas são de ensaios anteriores sobre `PROPOSAL`: nenhuma régua sobre `CONTRACT` foi disparada, nem o novo ciclo depois de `RENEWAL`. Prazo legal: confirme com seu jurídico.
