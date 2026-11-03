---
name: koter-crm-automacao
description: Configura o que roda sozinho no CRM do Koter. Use quando pedirem para distribuir leads, ligar transbordo, montar régua de follow-up, reagir a venda perdida ou disparar template de WhatsApp.
---

# koter-crm-automacao

A etapa em que o CRM passa a trabalhar sem o corretor. **Termina com automação criada, disparada de verdade e o log conferido**: automação que ninguém viu rodar não está pronta.

## 0 · Pré-requisitos

`koter-crm-fundacao` e `koter-crm-origens-tags` rodadas: automação referencia equipe, etapa, origem e tag.

Permissão: gerenciar automações.

**A ordem certa é funil → rotina manual funcionando → automação do que já é repetitivo.** Corretora que ainda não tem funil definido e liga automação só acelera a bagunça. Se a fundação não rodou, volte para ela.

## 1 · Detecção: o que já está ligado

```
crm_automation_list_automations
crm_automation_fetch_automation_context
```

> **Corretora que passou pelo assistente de CRM na tela já tem automações ligadas**, sem ter escrito nenhuma. Na corretora de demonstração eram 6 cadastradas, 4 delas ativas e publicadas:
>
> | Automação | Gatilho | O que faz |
> |---|---|---|
> | Cobrar o primeiro contato | `LEAD_CREATED` na etapa Pendente | tarefa "Entrar em contato com {{lead.name}}" |
> | Rastrear tráfego pago | `LEAD_CREATED`, origem Tráfego pago | `ADD_TAG "Tráfego Pago"` |
> | Follow-up de proposta | `STATUS_CHANGED` → Proposta Enviada | tarefa daqui a 2 dias |
> | Marcar cliente fechado | `STATUS_CHANGED` → Venda Faturada | `ADD_TAG "Cliente"` |

Conta que não passou pelo assistente pode estar vazia. Não presuma: leia.

**Mostre as que já rodam antes de propor qualquer coisa.** Metade do que o corretor ia pedir pode já existir, e propor criar "follow-up de proposta" numa conta que já tem uma é o jeito mais rápido de parecer que você não olhou.

O limite vem em `automationLimit` no contexto (99 por corretora, lido no código em 03/11/2026), e o consumo em `usage` de `crm_automation_list_automations`.

## 2 · O defeito que estraga a automação mais comum

A automação que a plataforma mais usa, criar tarefa para o dono do lead, **falha quando o lead não tem dono**.

> Medido na corretora de demonstração, no log de `crm_automation_list_automation_logs`:
>
> ```
> status: FAILED
> errorMessage: "Não foi possível definir o responsável da tarefa:
>                lead sem dono e assigneeType não especificou usuário."
> ```

Lead criado por `crm_save_lead` nasce com quem chamou como dono, a menos que `ownerUserId: null` diga o contrário. Lead sem dono vem de `null`, de `teamId: null` numa edição, ou de integração que não achou ninguém disponível.

Três consertos, em ordem de preferência:

1. **Lead com dono**: `ownerUserId` na criação, ou `crm_save_lead` com `leadId` para consertar os que já estão sem (ver `koter-crm-lead`).
2. **`assigneeType: "SPECIFIC_USER"`** com `assigneeUserId`. Serve para corretora solo, onde o dono é sempre o mesmo.
3. **`ASSIGN_AGENT` antes de `CREATE_TASK`**. Funciona, mas é passo a mais quando o dono já pode vir na criação.

**Toda automação desta skill que crie tarefa tem que resolver o responsável.** E quando encontrar as automações do assistente na conta, confira os logs: elas falham para todo lead que entrar sem dono, e o corretor não tem como saber disso sem ler o log.

## 3 · As regras do motor

A sequência tem no máximo 20 passos e pelo menos uma ação, e cada passo precisa de um `id` único (uuid gerado por você). Os tipos de passo são `CONDITION`, `WAIT`, `ACTION` e `END`. As regras de espera, todas com consequência prática:

1. `WAIT` não pode ser o último passo, nem vir seguida de outra `WAIT`, nem vir logo antes de `END`.
2. **Soma máxima das esperas: 90 dias**, contando o máximo de cada espera aleatória. Régua de 12 meses **não cabe** numa automação de CRM.
3. **Novo disparo do mesmo lead durante a espera cancela a execução pendente e recomeça.** Reentrada substitui, não empilha: é o que impede mensagem duplicada.
4. **Pausar a automação, ou mudar `trigger` ou `steps`, cancela as execuções em espera.** Mexer numa régua no meio do mês descarta quem estava esperando; diga isso antes de editar.
5. **`CONDITION` depois de uma espera é avaliada com o estado atual do lead.**

A regra 5 é a que salva as réguas de follow-up:

```
WAIT 2 dias → CONDITION status ainda é "Proposta enviada" → lembrete
```

Sem essa condição de saída, a régua cutuca quem já respondeu. **Toda régua precisa dela.**

### Espera aleatória, janela de horário e ritmo de saída

`WAIT` tem três controles, que servem principalmente para envio em volume:

| Campo | O que faz | Exemplo |
|---|---|---|
| `maxAmount` | **espera aleatória**: cada lead sorteia um tempo entre `amount` e `maxAmount`, na mesma `unit`. Tem que ser maior que `amount` | `amount: 5, maxAmount: 30, unit: "MINUTES"` |
| `window` | **janela de horário**: a espera só termina dentro dela. `startMinutes` e `endMinutes` em minutos desde a meia-noite, `weekdays` de 0 (domingo) a 6, opcional. Se cair fora, vai para a próxima abertura, ainda espalhada. Fuso da automação, ou `America/Sao_Paulo` quando ela não tem | `{ startMinutes: 480, endMinutes: 1200, weekdays: [1,2,3,4,5] }` = 8h às 20h, segunda a sexta |
| `pace` | **ritmo de saída**: no máximo `maxRuns` execuções terminam a espera a cada `everyMinutes` (1 a 1440); o excedente vai para os blocos seguintes. Cada automação tem o seu ritmo | `{ maxRuns: 5, everyMinutes: 10 }` = até 5 a cada 10 minutos |

Antes de um template, use os três: espalha os envios, não manda de madrugada e não despeja tudo de uma vez. Para saber quando um disparo termina, leia `pendingSummary` em `crm_automation_list_automation_runs`: quantas execuções pendentes e entre que horários retomam.

Ritmo não é licença para disparo em massa: vale o passo 7.

### Se, senão: `onFalse` e `END`

Condição falsa encerra a execução (`CONDITION_NOT_MET`), a menos que ela diga para onde pular:

```
[c1] CONDITION saleNotCompletedReasonId EQUALS "<id de Sem retorno do cliente>"
     onFalse: { goto: "a2" }
[a1] ACTION CREATE_TASK "Retomar {{lead.name}}", RELATIVE, delayMinutes 43200, LEAD_OWNER
[e1] END
[a2] ACTION CREATE_TASK "Entender a perda de {{lead.name}}", RELATIVE, delayMinutes 1440, LEAD_OWNER
```

Os passos logo depois da condição são o lado "sim", fechado com `END`; o lado "não" começa no passo apontado.

- `onFalse.goto` só aponta para **depois** da condição: não há laço. Recusa: *"Uma condição só pode pular para um passo depois dela."*
- Passo logo depois de `END` tem que ser alvo de um `onFalse`. Recusa: *"Há passo depois de Encerrar que nenhuma condição alcança."*
- `END` não vem logo depois de `WAIT`. Recusa: *"A espera não pode vir logo antes de Encerrar."*

### A alternativa melhor que o `WAIT`

A automação "Follow-up de proposta" do assistente **não usa `WAIT`**: usa `CREATE_TASK` com `scheduleType: "RELATIVE"` e `delayMinutes: 2880` (2 dias).

É mais esperto, e vale como padrão desta skill quando o passo seguinte é humano:

| | `WAIT` + ação | tarefa com `delayMinutes` |
|---|---|---|
| Consome o teto de 90 dias | sim | não |
| Some se o lead reentra | sim (regra 3) | não |
| Some se alguém edita a automação | sim (regra 4) | não |
| Reavalia o estado do lead depois | sim (regra 5) | não, quem avalia é a pessoa |

> **Se o próximo passo é uma pessoa agir, agende a tarefa. `WAIT` é para quando a automação precisa decidir sozinha depois.**

## 4 · O que dispara e o que a condição enxerga

Gatilhos, em `triggers` de `crm_automation_fetch_automation_context`:

```
LEAD_CREATED · STATUS_CHANGED · TAG_ADDED · SALE_NOT_COMPLETED · CHAT_PENDING · CHAT_OPENED · CHAT_BOT · CHAT_FINALIZED · SCHEDULED
```

Campos de condição, lista **fechada**, em `conditionFields`:

```
hasLead · origin · statusId · teamId · userId · tags · perception · integrationId · leadPartner · saleNotCompletedReasonId · billing.amount · billing.lifes · phone · chatStatus · attendantId
```

mais os `extra.<chave>` dos campos personalizados.

- `origin`, `tags` e `statusId` aceitam id ou nome. Medido: uma condição `origin EQUALS "Tráfego pago"` disparou para lead cadastrado como "Tráfego Pago": a comparação tolera a caixa. Prefira o id, que sobrevive a renomear.
- **Campo personalizado é condição.** Cada item de `customFields` traz `conditionField` (`extra.<chave>`) e `options`; use esse valor como `field` da condição, o mesmo caminho que o chatbot lê em `crm.lead.extra.<chave>`. Em campo `SELECT`, **compare com o `value` da opção, não com o rótulo**. `IS_EMPTY` e `IS_NOT_EMPTY` respondem "o lead preencheu ou não". Campo `REFERENCE` é a exceção: vem com `conditionField: null` e não serve de condição.
- **Faturamento e parceiro são condição**: `billing.amount`, `billing.lifes` e `leadPartner`, então "lead de parceiro acima de X" não precisa de tag.
- `chatStatus` e `attendantId` só têm valor nos gatilhos de atendimento (`CHAT_*`), congelado no momento do disparo: ver passo 7.
- A tag `Transbordo` serve de condição em `tags`, mas `ADD_TAG` e `REMOVE_TAG` recusam: *"A tag Transbordo é do sistema e não pode ser adicionada nem removida por automação."* Lido no código: o transbordo acrescenta a tag direto no banco, sem o evento que alimenta `TAG_ADDED`. Não monte automação esperando esse gatilho com ela.

### Gatilho de motivo de perda

`SALE_NOT_COMPLETED` dispara quando o lead é marcado como venda não realizada com um motivo: é o que acontece no `outcome` `LOSS` de `crm_save_lead`. Para filtrar por motivo, condição em `saleNotCompletedReasonId` com o id que vem em `saleNotCompletedReasons` do contexto.

É o que permite tratar "Documentação não entregue" diferente de "Fechou com concorrente" sem tag nenhuma. Sem condição, dispara em toda perda. E como a perda move o lead para a etapa de sistema, uma automação de `STATUS_CHANGED` nessa etapa pode rodar junto: confira antes de criar a segunda.

### `CREATE_LEAD` é mais exigente do que parece

**Hoje ela não fecha em nenhum gatilho.** Lido no código em 03/11/2026, não executado: a ação exige a mensagem do cliente no contexto, e nenhum gatilho de automação do CRM entrega essa mensagem. `crm_automation_validate_automation` aprova, e ao rodar o log traz `FAILED` com *"CREATE_LEAD exige mensagem no contexto da automação."* Não monte régua que dependa dela. Para criar lead a partir do WhatsApp, use a etapa `ACTION` com `CREATE_LEAD` do chatbot (`koter-chatbot-fluxo`), que pede `teamId` e não depende disso.

Além disso, a ação só existe a partir de contexto de chat, só aceita `origin` e **exige que a instância de WhatsApp esteja vinculada a exatamente uma equipe**. Instância compartilhada, ou liberada só para usuários em vez de equipe, é **recusada**. A equipe do lead criado sai dessa instância, e é por isso que ela precisa ser uma só.

Confira `allowedTeams` da instância (`whatsappInstances` em `koterzap_configuracao_fetch_koterzap_config_context`) **antes** de ligar uma automação que já tenha essa ação. Se houver mais de uma equipe ou nenhuma, o conserto é **passo de tela**, na tela da instância: `koterzap_configuracao_update_inbox` recusa a caixa vinculada a uma instância. E é decisão do corretor, porque muda quem enxerga aquele número.

## 5 · As duas automações que se pagam

E só essas duas, por padrão. Toda automação nova precisa de `name`, `teamId`, `trigger` e `steps`.

### 1. Lead novo de origem paga → responder rápido

```
trigger: LEAD_CREATED
CONDITION origin EQUALS "<a origem paga dele>"
ACTION   CREATE_TASK "Ligar agora para {{lead.name}}", RELATIVE, delayMinutes 15, LEAD_OWNER, HIGH
```

O lead já entra com dono (passo 2); `ASSIGN_AGENT` e `ASSIGN_TEAM` só quando a regra for mesmo redistribuir. Velocidade é o que mais pesa em lead pago: pagar por lead e responder no dia seguinte é comprar lead para o concorrente.

### 2. Follow-up de cotação

```
trigger: STATUS_CHANGED
CONDITION statusId EQUALS "<Proposta enviada>"
ACTION    CREATE_TASK "Retomar a proposta de {{lead.name}}", RELATIVE, delayMinutes 2880, LEAD_OWNER
```

**Se a conta já tem a do assistente, não crie outra**: revise a existente e conserte o responsável (passo 2).

### `{{lead.name}}` funciona

Medido na corretora de demonstração: uma automação com o título `"Ligar agora para {{lead.name}}"` gerou a tarefa com o nome do lead, o horário 15 minutos à frente da criação e o responsável certo. Use nos títulos e descrições: tarefa genérica numa lista de trinta não diz nada.

## 6 · WhatsApp: cheque antes de prometer

**Nenhuma tool do MCP envia mensagem a cliente.** O que chega ao segurado por aqui é `SEND_WHATSAPP_TEMPLATE` numa automação, que depois roda sozinha. Não prometa envio ao corretor: prometa uma automação que ele aprovou.

> **Porta de cuidado.** `crm_automation_save_automation` e `crm_automation_import_automation` não saem marcadas como destrutivas e alcançam cliente. Deixe as duas em "Precisa de aprovação" na IA do corretor. Antes de gravar qualquer `SEND_WHATSAPP_TEMPLATE`, mostre o template, quem recebe e em que horário, e espere o sim dele. O mesmo vale para `SEND_WEBHOOK`, que manda o contexto a um endpoint externo já cadastrado (nenhuma tool cria endpoint; `endpointId` sai de `webhookEndpoints`).

```
koterzap_configuracao_fetch_koterzap_config_context   → include: ["whatsappInstances"]
```

> **`SEND_WHATSAPP_TEMPLATE` exige instância Cloud API oficial com template aprovado pela Meta. Instância Evolution é recusada.**

Na corretora de demonstração não há nenhuma instância e nenhum template: `whatsappInstances: []` e `whatsappTemplates: []` no contexto de automação. **Esse é o caso comum numa corretora nova.**

Trate como o caso "módulo que falta" do passo 1b da `introducao`: **constatação com três saídas, não pergunta.** E então:

> **Crie as duas automações do passo 5 sem a ação de WhatsApp.** Tarefa e atribuição resolvem metade do problema, funcionam hoje, e não ficam quebradas esperando um template que não existe.

A corretora de demonstração tem o contraexemplo pronto: a automação "Cross Selling" está publicada com dois passos `SEND_WHATSAPP_TEMPLATE` de parâmetros vazios e ficou **inativa**: automação escrita para um canal que não existe.

### Três tipos de instância, e só um critério

`instanceType` vem em três sabores: `EVOLUTION` (QR code), `CLOUD_API` (oficial da Meta) e `COEXISTENCE` (os dois no mesmo número). Leia `isCloudApi` antes de prometer qualquer disparo, e não trate "tem WhatsApp conectado" como "dá para automatizar". Automação com gatilho de atendimento ou de WhatsApp também exige o módulo KoterZap, e `crm_automation_validate_automation` aponta isso.

### O template não se cria por aqui

> **`koterzap_configuracao_save_message_template` não cria template da Meta.** Ele cria uma **resposta rápida interna** da corretora, texto pronto para o atendente usar no chat. O template aprovado pela Meta é outra coisa, e o MCP não o cria.

Isso importa porque o erro é silencioso na direção errada: a skill "cria o template", liga a automação, e o envio falha depois, longe dali, sem nada que explique. **Aprovar template da Meta é passo de tela**: mande o corretor aprovar e **confira** com `koterzap_configuracao_list_meta_message_templates` (com `instanceId`), que diz se já existe template `APPROVED`, antes de ligar a ação.

Quando houver Cloud API e template aprovado: o `instanceToken` da ação é o **id da instância**; `templateName` e `languageCode` (`pt_BR`) são do template da Meta. **Nenhuma ferramenta de automação confere isso na Meta**: `crm_automation_validate_automation` exige a instância Cloud API, mas o nome e o `languageCode` passam sem checagem, e `crm_automation_fetch_automation_context` lista só os nomes locais. Copie `name` e `language` de um template `APPROVED` em `koterzap_configuracao_list_meta_message_templates`, letra por letra.

## 7 · O que nunca automatizar

Não é preferência, é o que gera reclamação:

1. **Aviso de reajuste.** É a conversa mais delicada do ano. Template frio anunciando aumento é convite para o cliente cotar no concorrente. A automação avisa **o corretor**, não o cliente.
2. **Negativa**: proposta recusada, carência negada. Má notícia por robô gera reclamação.
3. **Cancelamento e retenção.** Cliente pedindo cancelamento vai para humano imediatamente: é o momento de maior valor da conversa.
4. **Qualquer coisa sobre doença.** Declaração de saúde, CPT, preexistência. O agente não preenche nem sugere Declaração de Saúde.
5. **Disparo em massa para base fria.** Arrisca o número, que é o ativo da corretora. Se a dúvida for o que pode ser enviado a quem, confirme com seu jurídico.

E a regra que cobre o erro mais visível de todos: **automação que fala em cima do humano.** Toda régua de mensagem precisa de condição que a desarme quando a etapa já mudou (`statusId` depois da espera). `chatStatus` e `attendantId` não resolvem isso numa régua comum (lido no código em 03/11/2026, não executado): só vêm preenchidos nos gatilhos `CHAT_*`, com o valor do disparo. Nos outros gatilhos ficam vazios, e depois de uma `WAIT` não se atualizam, ao contrário dos dados do lead. Nenhuma condição enxerga atendimento aberto no meio de uma régua de `LEAD_CREATED` ou `STATUS_CHANGED`: diga isso ao corretor antes de ligar.

## 8 · Distribuição

Quem pega o lead que chega. Pergunta em opções: quem estiver livre / rodízio / por especialidade.

**A fila não atribui lead criado por `crm_save_lead` nem lead cadastrado à mão.** Lido no código: ela entrega o que chega por integração e pelo atendimento.

### Rodízio: a fila da equipe

`crm_config_save_team` com `teamId`. Membro sempre pelo `userId`, em todos os campos:

- `queueOrder`: a ordem **completa**, todos os membros, cada um uma vez. Faltando alguém: *"queueOrder precisa trazer todos os membros do time, cada um uma vez, e nenhum outro usuário."*
- `memberSettings`: uma entrada por membro, e só os campos enviados mudam.
  - `inQueue: false` tira do rodízio sem tirar da equipe.
  - `maxLeads`, de 1 a 1000, é quantos leads ele recebe por rodada.
  - `receiveWeekDays`: dias em que recebe, 0 domingo a 6 sábado. Substitui a lista; `[]` faz ele não receber em dia nenhum.
  - `workSchedules`: `{ weekDay, start, end }` em `HH:MM`, no fuso da corretora, sem sobreposição no mesmo dia. Substitui todos os horários do membro; `[]` apaga (recebe a qualquer hora nos dias de recebimento).

Leia o estado atual em `crm_config_fetch_crm_config_context` com `teamDetails: true`: é o mesmo formato que `crm_config_save_team` recebe.

### Transbordo: lead parado passa para o próximo

`crm_config_save_team` com `queueOverflow`:

```
queueOverflow: { enabled: true, amount: 15, unit: "MINUTES" }
```

- De 5 a 999 minutos, ou de 1 a 999 horas ou dias. `DAYS` são **dias de trabalho do responsável**, não dias corridos, e só o horário de trabalho dele conta.
- **Se ninguém interagir com o lead distribuído pela fila dentro do prazo, ele vai para o próximo**, sem gastar a vez dele. Cada novo responsável ganha um prazo inteiro, até alguém interagir.
- **Vale para os leads distribuídos depois de salvar.** Desligar para também os que já estão transbordando.
- O lead que transborda ganha a tag do sistema `Transbordo`. Sem ninguém disponível, ele vai para o gerente da equipe, e o transbordo para ali: confira se a equipe tem gerente ativo.
- Só pessoa conta como interação. Automação, chatbot e webhook não contam; abrir o lead também não. Uma escrita do agente pelo MCP conta, porque age em nome do corretor (ver `koter-crm-lead`).

Antes de ligar, diga o que muda: "lead sem resposta em 15 minutos de horário de trabalho passa para o próximo da fila". Só o gerente da equipe, ou quem edita equipes de outros, muda isso.

### Histórico da fila

`crm_config_list_team_queue_history` com `teamId`: quem mudou, quando, de qual membro, e cada valor antigo e novo. `entity` diz o que mudou: `queue` (ordem, limite, participação), `member` (dias de recebimento) ou `work_schedule` (horários, em minutos desde a meia-noite). `includeAutomatic: true` acrescenta o andamento automático a cada lead distribuído, e `retentionDays` diz até onde o histórico vai. Só o gerente da equipe, ou quem edita equipes de outros, lê.

Use quando o corretor perguntar "por que fulano parou de receber lead?".

### Fila própria de integração: é de tela

Fila própria de uma integração, com regiões por DDD, **não tem tool**: nada no MCP lê nem grava isso. Mande o corretor para a tela da integração, e não diga que configurou. O efeito visível por aqui é a recusa ao excluir equipe com gente nessa fila.

### Por especialidade

É automação: `LEAD_CREATED` → `CONDITION` (origem, tag ou campo) → `ASSIGN_TEAM` / `ASSIGN_AGENT`.

**Rodízio cego manda PME de 40 vidas para quem só vende adesão.** Onde há especialização, a distribuição é por tipo de lead antes de ser por rodízio. Diga isso quando ele escolher rodízio numa corretora com vendedores especializados.

## 9 · Criar, e o cuidado que isso exige

> **Automação criada por `crm_automation_save_automation` nasce `PUBLISHED` e `active: true`.** Medido na corretora de demonstração: a automação voltou já no ar e disparou no lead seguinte, segundos depois. Não existe parâmetro de rascunho na criação.

Ou seja: **criar é ligar.** Duas obrigações daí:

1. **Diga o que vai passar a acontecer antes de criar**, em uma frase, e crie só depois do sim. É porta de cuidado (passo 6).
2. Se ele quiser revisar antes, crie e chame `crm_automation_save_automation` com o `automationId` e `active: false` na sequência, depois `active: true` quando ele aprovar.

`crm_automation_import_automation` faz o caminho inverso: a cópia nasce rascunho (`DRAFT`), inativa, sem equipe e com "(Importada)" no nome, e só liga com `crm_automation_save_automation` com o `automationId`, `teamId` e `publish: true`. Serve para copiar automação; o resto do cuidado é igual.

Sempre `crm_automation_validate_automation` antes: é dry-run, aponta id inexistente, ação desativada, agendamento inválido e estouro de limite **numa passada só**.

## 10 · Validação: no log, não na criação

A criação ter dado certo não prova que a automação funciona. **Faça-a disparar** e leia:

```
crm_automation_list_automation_logs
```

Os status: `SUCCESS`, `FAILED` (com `errorMessage` e `failedStepId`), `CONDITION_NOT_MET`, `WAITING`, `CANCELLED`. `executedStepIds` mostra até onde foi.

Se houver lead de teste disponível, crie um que case com a condição e leia o log. Se não, leia os logs das automações que já existiam: foi assim que o defeito do passo 2 apareceu.

> "Criei a régua de tráfego pago e testei: o lead entrou e a tarefa de ligar apareceu com 15 minutos. Aproveitei e consertei a 'Cobrar o primeiro contato', que estava falhando em todo lead sem dono."

Uma automação em `WAITING` aparece em `crm_automation_list_automation_runs` com `resumeAt`, e `pendingSummary` resume as pendentes. É onde conferir quem está no meio de uma régua antes de editá-la (regra 4).

## 11 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, as automações criadas ou consertadas, e se há Cloud API. A `koter-crm-renovacao` e as skills do KoterZap dependem dessa resposta.

Próxima, em até 4 opções:

- **`koter-crm-renovacao`**: a rotina que segura carteira, e a única que não cabe no motor do CRM *(recomendada)*
- `koter-crm-lead`: usar o que acabou de ser montado
- `koter-gestao-automacao`: o que o Gestão já roda sozinho
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Tarefa da automação nunca aparece | lead sem dono + `assigneeType: LEAD_OWNER` | lead com dono; só então pense em `ASSIGN_AGENT` |
| Automação nova já disparou sem aprovação | criação nasce publicada e ativa | avise antes; ou crie e pause com `active: false` |
| Régua cutuca quem já respondeu | falta `CONDITION` depois da espera | regra 5 |
| Quem estava na régua sumiu | editar cancela execuções em espera | regra 4; confira `crm_automation_list_automation_runs` antes |
| Régua de 12 meses não salva: *"A soma das esperas não pode passar de 90 dias."* | teto de 90 dias de espera | rotina no Gestão; ver `koter-crm-renovacao` |
| *"Na espera aleatória, o tempo máximo precisa ser um número inteiro maior que o mínimo."* | `maxAmount` igual ou menor que `amount` | suba `maxAmount` |
| Condição por campo personalizado não casa | comparou com o rótulo da opção | use o `value`, que vem em `customFields[].options` |
| `SEND_WHATSAPP_TEMPLATE` recusado | instância Evolution, não Cloud API | automação sem a ação de mensagem |
| Template "criado" e o envio falha mesmo assim | `koterzap_configuracao_save_message_template` cria resposta rápida interna, não template da Meta | aprovação na Meta é passo de tela; confira em `koterzap_configuracao_list_meta_message_templates` |
| Automação publicada e parada | escrita para um canal que não existe | remova a ação ou deixe pausada, e diga por quê |
| Mensagem em cima do atendente | a régua só olhava `chatStatus` ou `attendantId`, que vêm vazios fora de `CHAT_*` e não se atualizam depois da espera | condição em `statusId` depois da espera |
| `CREATE_LEAD` falha ao rodar | nenhum gatilho entrega a mensagem que a ação exige; e a instância precisa estar vinculada a exatamente uma equipe | use `ACTION` com `CREATE_LEAD` no chatbot |
| Importada não dispara | a cópia nasce `DRAFT`, sem equipe | `crm_automation_save_automation` com `teamId` e `publish: true` |
| Lead parado não transbordou | foi distribuído antes de ligar, ou criado por `crm_save_lead`, ou o agente mexeu nele | só vale para o que a fila distribuiu depois de salvar |
| Corretor pediu fila por região | fila própria de integração não tem tool | passo de tela; não simule com automação sem combinar |

## Conferência

Passos, gatilhos, campos, parâmetros e mensagens conferidos contra o código de `crm-automation` e `crm-config` em 03/11/2026, por leitura, sem execução. Espera aleatória, janela, ritmo, `onFalse`, `END`, `SALE_NOT_COMPLETED`, transbordo e a falha de `CREATE_LEAD` não foram disparados nesta revisão. As medições citadas vêm de ensaios anteriores na corretora de demonstração.
