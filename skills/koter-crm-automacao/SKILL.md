---
name: koter-crm-automacao
description: Configura o que passa a rodar sozinho no CRM do Koter — distribuição de lead, resposta rápida, régua de follow-up e disparo de WhatsApp. Use quando pedirem para automatizar o CRM, distribuir leads entre vendedores, responder lead novo automaticamente, criar régua de follow-up ou cobrança, ou quando /introducao encaminhar para a etapa de automação da trilha do CRM.
---

# koter-crm-automacao

A etapa em que o CRM passa a trabalhar sem o corretor. **Termina com automação criada, disparada de verdade e o log conferido** — automação que ninguém viu rodar não está pronta.

## 0 · Pré-requisitos

`koter-crm-fundacao` e `koter-crm-origens-tags` rodadas: automação referencia equipe, etapa, origem e tag.

Permissão: `manage:automations`.

**A ordem certa é funil → rotina manual funcionando → automação do que já é repetitivo.** Corretora que ainda não tem funil definido e liga automação só acelera a bagunça. Se a fundação não rodou, volte para ela.

## 1 · Detecção — e a maior surpresa desta trilha

```
crm_automation_list_automations
crm_automation_fetch_automation_context
```

> **O CRM já vem com automações ligadas.** Comprovado na Koter Day: 6 automações cadastradas, 4 delas ativas e publicadas, sem ninguém ter configurado nada:
>
> | Automação | Gatilho | O que faz |
> |---|---|---|
> | Cobrar o primeiro contato | `LEAD_CREATED` na etapa Pendente | tarefa "Entrar em contato com {{lead.name}}" |
> | Rastrear tráfego pago | `LEAD_CREATED`, origem Tráfego pago | `ADD_TAG "Tráfego Pago"` |
> | Follow-up de proposta | `STATUS_CHANGED` → Proposta Enviada | tarefa daqui a 2 dias |
> | Marcar cliente fechado | `STATUS_CHANGED` → Venda Faturada | `ADD_TAG "Cliente"` |

**Mostre as que já rodam antes de propor qualquer coisa.** Metade do que o corretor ia pedir já existe — e propor criar "follow-up de proposta" numa conta que já tem uma é o jeito mais rápido de parecer que você não olhou.

O contexto também devolve `automationLimit`: **50 por corretora**, com o consumo atual em `list_automations`.

## 2 · O defeito que estraga a automação mais comum

A automação que a plataforma mais usa — criar tarefa para o dono do lead — **falha quando o lead não tem dono**, e lead criado por MCP nunca tem.

> Comprovado na Koter Day. Dois leads criados por MCP, e o log de `crm_automation_get_automation_logs`:
>
> ```
> status: FAILED
> errorMessage: "Não foi possível definir o responsável da tarefa:
>                lead sem dono e assigneeType não especificou usuário."
> ```
>
> **Inclusive na automação que vem de fábrica** ("Cobrar o primeiro contato"), que falhou com o mesmo erro nos mesmos dois leads.

**O conserto mudou de lugar: agora é no lead, não na automação.** `crm_create_lead` e `crm_update_lead` têm `ownerUserId` (ver `koter-crm-lead`), então o lead entra com dono e `LEAD_OWNER` resolve.

Três consertos, em ordem de preferência:

1. **Crie o lead com dono** — `ownerUserId` na criação, ou `update_lead` para consertar os que já estão sem. Resolve na origem e conserta de uma vez as automações de fábrica.
2. **`assigneeType: "SPECIFIC_USER"`** com `assigneeUserId`. Serve para corretora solo, onde o dono é sempre o mesmo.
3. **`ASSIGN_AGENT` antes de `CREATE_TASK`**, o contorno antigo. Continua funcionando, mas **não monte mais uma automação só para dar dono ao lead** — é passo a mais para fazer o que a criação já faz.

**Toda automação desta skill que crie tarefa tem que resolver o responsável.** E quando encontrar as automações de fábrica na conta, confira os logs: elas falham para todo lead que entrar sem atribuição, e o corretor não tem como saber disso sem ler o log.

## 3 · As cinco regras do motor

Documentadas na própria tool, e todas com consequência prática:

1. `WAIT` não pode ser o último passo, nem vir seguida de outra `WAIT`.
2. **Soma máxima das esperas: 90 dias.** Régua de renovação de 12 meses **não cabe** numa automação de CRM.
3. **Novo disparo do mesmo lead durante a espera cancela a execução pendente e recomeça.** Reentrada substitui, não empilha — é o que impede mensagem duplicada.
4. **Editar ou pausar a automação cancela as execuções em espera.** Mexer numa régua no meio do mês descarta quem estava esperando; diga isso antes de editar.
5. **`CONDITION` depois de uma espera é avaliada com o estado atual do lead.**

A regra 5 é a que salva as réguas de follow-up:

```
WAIT 2 dias → CONDITION status ainda é "Proposta enviada" → lembrete
```

Sem essa condição de saída, a régua cutuca quem já respondeu. **Toda régua precisa dela.**

### A alternativa melhor que o `WAIT`

A automação de fábrica "Follow-up de proposta" **não usa `WAIT`**: usa `CREATE_TASK` com `scheduleType: "RELATIVE"` e `delayMinutes: 2880` (2 dias).

É mais esperto, e vale como padrão desta skill quando o passo seguinte é humano:

| | `WAIT` + ação | tarefa com `delayMinutes` |
|---|---|---|
| Consome o teto de 90 dias | sim | não |
| Some se o lead reentra | sim (regra 3) | não |
| Some se alguém edita a automação | sim (regra 4) | não |
| Reavalia o estado do lead depois | sim (regra 5) | não — quem avalia é a pessoa |

> **Se o próximo passo é uma pessoa agir, agende a tarefa. `WAIT` é para quando a automação precisa decidir sozinha depois.**

## 4 · O que a condição enxerga

Lista **fechada**, de `fetch_automation_context`:

```
hasLead · origin · statusId · teamId · userId · tags · perception · phone · chatStatus · attendantId
```

- `origin`, `tags` e `statusId` resolvem id ↔ nome sozinhos. Comprovado: uma condição `origin EQUALS "Tráfego pago"` disparou para lead cadastrado como "Tráfego Pago" — a comparação tolera a caixa.
- **Campo personalizado agora é condição.** Cada item de `customFields` traz `conditionField` (`extra.<chave>`) e `options`; use esse valor como `field` da condição — é o mesmo caminho que o chatbot lê em `crm.lead.extra.<chave>`. Em campo `SELECT`, **compare com o `value` da opção, não com o rótulo**. `IS_EMPTY` e `IS_NOT_EMPTY` respondem "o lead preencheu ou não". Campo `REFERENCE` é a exceção: vem com `conditionField: null` e não serve de condição.
- A lista `conditionFields` ganhou `integrationId`, `leadPartner`, `billing.amount` e `billing.lifes` — faturamento e parceiro viraram condição, então "lead de parceiro acima de X" não precisa mais de tag.
- Comprovado na Koter Day em 21/09/2026: `fetch_automation_context` devolveu `faixa_de_vidas` como `extra.faixa_de_vidas` com as quatro opções (`2-9`, `10-29`, `30-99`, `100+`), e `conditionFields` com os quatro campos novos. **A régua que só funcionava no chatbot funciona igual na automação.**
- `chatStatus` e `attendantId` são a saída para a regra de ouro do passo 7: não falar em cima do humano.

### `CREATE_LEAD` é mais exigente do que parece

A ação `CREATE_LEAD` só existe a partir de contexto de chat, e **exige que a instância de WhatsApp esteja vinculada a exatamente uma equipe** — instância compartilhada, ou liberada só para usuários em vez de equipe, é **recusada**. A equipe do lead criado sai dessa instância, e é por isso que ela precisa ser uma só.

Confira `allowedTeams` da instância (`koterzap_configuracao_list_whatsapp_instances`) **antes** de propor qualquer régua que crie lead. Se houver mais de uma equipe ou nenhuma, o conserto é `koterzap_configuracao_set_inbox_allowed_teams` — e é decisão do corretor, porque muda quem enxerga aquele número.

## 5 · As duas automações que se pagam

E só essas duas, por padrão.

### 1. Lead novo de origem paga → responder rápido

```
trigger: LEAD_CREATED
CONDITION origin EQUALS "<a origem paga dele>"
ACTION   CREATE_TASK "Ligar agora para {{lead.name}}", RELATIVE, delayMinutes 15, HIGH
         (o lead já entra com dono via ownerUserId; ASSIGN_AGENT/ASSIGN_TEAM só
          quando a regra for mesmo redistribuir, não para tapar buraco)
[ACTION  SEND_WHATSAPP_TEMPLATE — só se houver Cloud API, passo 6]
```

Velocidade é o fator isolado que mais converte lead pago. Pagar por lead e responder no dia seguinte é comprar lead para o concorrente.

### 2. Follow-up de cotação

```
trigger: STATUS_CHANGED
CONDITION statusId EQUALS "<Proposta enviada>"
ACTION    CREATE_TASK "Retomar a proposta de {{lead.name}}", RELATIVE, delayMinutes 2880
```

**Se a conta já tem essa automação de fábrica, não crie outra** — revise a existente e conserte o responsável (passo 2).

### `{{lead.name}}` funciona

Comprovado na Koter Day: uma automação com o título `"Ligar agora para {{lead.name}}"` gerou a tarefa `"Ligar agora para Lead C — com ASSIGN_AGENT antes"`, com o horário 15 minutos à frente da criação e o responsável certo. Use nos títulos e descrições: tarefa genérica numa lista de trinta não diz nada.

## 6 · WhatsApp: cheque antes de prometer

```
koterzap_configuracao_list_whatsapp_instances
```

> **`SEND_WHATSAPP_TEMPLATE` exige instância Cloud API oficial com template aprovado pela Meta. Instância Evolution é recusada** — e a documentação da ação usa essa palavra.

Na Koter Day não há nenhuma instância e nenhum template: `whatsappInstances: []` e `whatsappTemplates: []` no contexto de automação. **Esse é o caso comum numa corretora nova.**

Trate como o caso "módulo que falta" do passo 1b da `introducao`: **constatação com três saídas, não pergunta.** E então:

> **Crie as duas automações do passo 5 sem a ação de WhatsApp.** Tarefa e atribuição resolvem metade do problema, funcionam hoje, e não ficam quebradas esperando um template que não existe.

A conta de demonstração tem o contraexemplo pronto: a automação "Cross Selling" está publicada com dois passos `SEND_WHATSAPP_TEMPLATE` de parâmetros vazios e ficou **inativa** — automação escrita para um canal que não existe.

### Três tipos de instância, e só um resolve

`instanceType` vem em três sabores: `EVOLUTION` (QR code), `CLOUD_API` (oficial da Meta) e `COEXISTENCE` (credenciais da Meta e o lado QR no mesmo número, com comportamento que muda conforme o lado QR esteja aberto ou fechado). **Só instância com credencial da Meta envia template.** Leia `instanceType` antes de prometer qualquer disparo, e não trate "tem WhatsApp conectado" como "dá para automatizar".

### O template não se cria por aqui

> **`koterzap_configuracao_create_message_template` não cria template da Meta.** Ele cria uma **resposta rápida interna** da corretora — texto pronto para o atendente usar no chat. O template aprovado pela Meta é outra coisa, e o MCP não o cria.

Isso importa porque o erro é silencioso na direção errada: a skill "cria o template", liga a automação, e o envio falha depois, longe dali, sem nada que explique. **Aprovar template da Meta é passo de tela**, e a skill trata assim: manda o corretor aprovar e **confere** com `koterzap_configuracao_list_meta_message_templates(instanceId)`, que diz se já existe template `APPROVED`, antes de ligar a ação.

Quando houver Cloud API e template aprovado: o `instanceToken` da ação é o **id da instância**; `templateName` e `languageCode` (`pt_BR`) são do template da Meta, e é `crm_automation_validate_automation` que confere os componentes contra ela — `fetch_automation_context` lista só os nomes locais.

## 7 · O que nunca automatizar

Não é preferência, é o que gera reclamação:

1. **Aviso de reajuste.** É a conversa mais delicada do ano. Template frio anunciando aumento é convite para o cliente cotar no concorrente. A automação avisa **o corretor**, não o cliente.
2. **Negativa** — proposta recusada, carência negada. Má notícia por robô gera reclamação e às vezes processo.
3. **Cancelamento e retenção.** Cliente pedindo cancelamento vai para humano imediatamente: é o momento de maior valor da conversa.
4. **Qualquer coisa sobre doença.** Declaração de saúde, CPT, preexistência: dado sensível pela LGPD.
5. **Disparo em massa para base fria.** Viola a regra de opt-in de marketing e arrisca o número, que é o ativo da corretora.

E a regra que cobre o erro mais visível de todos: **automação que fala em cima do humano.** Toda régua de mensagem precisa de condição que a desarme quando há atendimento aberto (`chatStatus`, `attendantId`) ou quando a etapa já mudou.

## 8 · Distribuição

Quem pega o lead que chega — pergunta em opções: quem estiver livre / rodízio / por especialidade.

- **Rodízio** é a fila da equipe: `crm_config_update_team_queue`, mandando **o estado completo da fila** (`id` e `memberId` de cada entrada, `order`, `maxLeads`, `active`). O `memberId` é o **id da participação na equipe**, não o `userId` — e ele só aparece em `crm_config_list_teams`, não no contexto do CRM. Confundir os dois é o erro clássico aqui.
- **Por especialidade** é automação: `LEAD_CREATED` → `CONDITION` (origem, tag ou interesse) → `ASSIGN_TEAM` / `ASSIGN_AGENT`.

**Rodízio cego manda PME de 40 vidas para quem só vende adesão.** Onde há especialização, a distribuição é por tipo de lead antes de ser por rodízio. Diga isso quando ele escolher rodízio numa corretora com vendedores especializados.

E lembre do passo 2: **a fila não atribui lead criado por MCP nem lead cadastrado à mão** — ela distribui o que chega pelo atendimento. **[inferência]**

## 9 · Criar, e o cuidado que isso exige

> **Automação criada por MCP nasce `PUBLISHED` e `active: true`.** Comprovado na Koter Day: `crm_automation_create_automation` devolveu a automação já no ar, e ela disparou no lead seguinte, segundos depois. Não existe parâmetro de rascunho na criação.

Ou seja: **criar é ligar.** Duas obrigações daí:

1. **Diga o que vai passar a acontecer antes de criar**, em uma frase, e crie só depois do sim.
2. Se ele quiser revisar antes, crie e chame `crm_automation_set_automation_active` com `false` na sequência — depois `true` quando ele aprovar.

Sempre `crm_automation_validate_automation` antes: é dry-run, aponta id inexistente, ação desativada, agendamento inválido e estouro de limite **numa passada só**. Cada passo precisa de um `id` único (uuid gerado por você).

## 10 · Validação — no log, não na criação

A criação ter dado certo não prova que a automação funciona. **Faça-a disparar** e leia:

```
crm_automation_get_automation_logs
```

Os status: `SUCCESS`, `FAILED` (com `errorMessage` e `failedStepId`), `CONDITION_NOT_MET`, `WAITING`, `CANCELLED`. `executedStepIds` mostra até onde foi.

Se houver lead de teste disponível, crie um que case com a condição e leia o log. Se não, leia os logs das automações que já existiam — foi assim que o defeito do passo 2 apareceu.

> "Criei a régua de tráfego pago e testei: o lead entrou, foi atribuído, e a tarefa de ligar apareceu com 15 minutos. Aproveitei e consertei a 'Cobrar o primeiro contato', que estava falhando em todo lead sem dono."

Uma automação em `WAITING` aparece em `crm_automation_list_automation_runs` com `resumeAt` — é onde conferir quem está no meio de uma régua antes de editá-la (regra 4).

## 11 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, as automações criadas ou consertadas, e se há Cloud API — a `koter-crm-renovacao` e as skills do KoterZap dependem dessa resposta.

Próxima, em até 4 opções:

- **`koter-crm-renovacao`** — a rotina que segura carteira, e a única que não cabe no motor do CRM *(recomendada)*
- `koter-crm-lead` — usar o que acabou de ser montado
- `koter-gestao-automacao` — o que o Gestão já roda sozinho
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Tarefa da automação nunca aparece | lead sem dono + `assigneeType: LEAD_OWNER` | crie o lead com `ownerUserId`; só então pense em `ASSIGN_AGENT` |
| Automação nova já disparou sem aprovação | criação nasce publicada e ativa | avise antes; ou crie e `set_automation_active(false)` |
| Régua cutuca quem já respondeu | falta `CONDITION` depois da espera | regra 5 |
| Quem estava na régua sumiu | editar cancela execuções em espera | regra 4; confira `list_automation_runs` antes |
| Régua de 12 meses não salva | teto de 90 dias de espera | tarefa anual no Gestão; ver `koter-crm-renovacao` |
| Condição por campo personalizado não casa | comparou com o rótulo da opção | use o `value`, que vem em `customFields[].options` |
| `SEND_WHATSAPP_TEMPLATE` recusado | instância Evolution, não Cloud API | automação sem a ação de mensagem |
| Template "criado" e o envio falha mesmo assim | `create_message_template` cria resposta rápida interna, não template da Meta | aprovação na Meta é passo de tela; confira em `whatsappTemplates` |
| Automação publicada e parada | escrita para um canal que não existe | remova a ação ou deixe pausada, e diga por quê |
| Fila de rodízio recusa a chamada | `memberId` recebeu o `userId` | `memberId` vem de `list_teams` |
| Mensagem em cima do atendente | falta condição de atendimento aberto | `chatStatus` / `attendantId` |
| `CREATE_LEAD` recusado | a instância não está vinculada a exatamente uma equipe | ajuste `allowedTeams` da instância, com o corretor |
