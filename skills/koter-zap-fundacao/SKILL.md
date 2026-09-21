---
name: koter-zap-fundacao
description: Levanta o WhatsApp da corretora no Koter — que números estão conectados, de que tipo, quem atende cada um, e o que cada tipo permite de verdade. Use quando pedirem para configurar o WhatsApp, conectar um número, entender por que a mensagem automática não sai, organizar quem atende o WhatsApp, criar respostas rápidas, ou quando /introducao encaminhar para a etapa do KoterZap.
---

# koter-zap-fundacao

A primeira etapa do KoterZap, e a mais ingrata: **boa parte dela é dizer ao corretor o que o plugin não faz.** Conectar número é tela e é Meta. O que esta skill entrega é o diagnóstico honesto do canal e tudo o que dá para arrumar em volta dele.

Termina com o corretor sabendo, em uma frase, **o que o WhatsApp dele consegue fazer hoje** — e com quem atende cada número definido.

## 0 · Pré-requisitos

Módulo `KOTERZAP` em `modules` (passo 0 da `introducao`). Sem ele, é o caso "módulo que falta" do passo 1b: constatação com três saídas, não pergunta.

Permissões: `read:whatsapp-instance:list` para o diagnóstico, `manage:whatsapp-instances` e `inbox:manage` para ajustar.

Nada aqui depende do CRM nem do Gestão. Mas a `koter-crm-automacao` depende **desta**: é aqui que se descobre se `SEND_WHATSAPP_TEMPLATE` é possível.

> **O diagnóstico desta skill provavelmente já foi feito.** A `/introducao` roda `list_whatsapp_instances` no passo 2, junto com o do Gestão e o do CRM, e entrega as tarefas de tela 1 e 2 (conectar Cloud API, aprovar template) logo no começo — justamente porque dependem da Meta e levam dias. Leia `pre_requisitos_de_tela` no estado **antes** de anunciar de novo: se já foram oferecidas, **pergunte se ele conseguiu**, não repita a explicação. Descobrir isto no fim do onboarding, depois de tudo pronto, é o erro que esta ordem existe para evitar.

> **Confira o `companyId` antes de aplicar qualquer coisa.** `admin_cargos_get_my_effective_permissions` de novo, e compare com o que a `introducao` guardou. Já aconteceu de a conexão trocar de corretora no meio de uma sessão — e o sintoma é `Operação não permitida.` numa chamada que acabou de funcionar. Ver as armadilhas no fim.

## 1 · Detecção

```
koterzap_configuracao_list_whatsapp_instances
koterzap_configuracao_list_inboxes
koterzap_configuracao_list_message_templates
```

> **O KoterZap nasce vazio.** Comprovado na Koter Day: `instances: []`, `inboxes: []`, `templates: []`, `chatbots: []`, `bases: []` — cinco listas zeradas.
>
> Isso é o **oposto** do CRM, que nasce com quatro automações ligadas. Aqui não há nada de fábrica para revisar: ou existe número conectado, ou a conversa inteira é sobre o que fazer antes disso.

Se `instances` vier vazio, pule para o passo 4 e não configure mais nada: **tudo no KoterZap pendura em um número.**

## 2 · Os três tipos, e o que muda entre eles

`instanceType` vem em três sabores, e a diferença não é técnica, é de o que o corretor pode prometer ao cliente:

| | `EVOLUTION` | `CLOUD_API` | `COEXISTENCE` |
|---|---|---|---|
| Como conecta | QR code, pelo app WhatsApp Business | credencial oficial da Meta | os dois no mesmo número |
| Mensagem livre | sempre | só dentro da janela de 24h | pelo QR enquanto aberto; senão, janela |
| Template aprovado pela Meta | **não** | sim | sim |
| Automação de mensagem no CRM | **não** | sim | sim |
| Lista e botões interativos | não | só dentro da janela | só dentro da janela |

**Leia `instanceType` antes de prometer qualquer disparo.** "Tem WhatsApp conectado" e "dá para automatizar mensagem" são coisas diferentes, e confundir as duas é o jeito mais rápido de montar uma automação que nunca envia.

### A janela de 24h, em português

A Meta só deixa a empresa escrever para o cliente **nas 24 horas seguintes à última mensagem que o cliente mandou**. Passou disso, só template aprovado reabre a conversa.

O erro que aparece é literal: *"A janela de conversa de 24h expirou. Envie um template aprovado para reabrir o atendimento."*

Duas consequências que o corretor precisa ouvir antes de montar qualquer coisa:

1. **Régua de follow-up por WhatsApp em número Cloud API só funciona com template.** "Mandar um oi no terceiro dia" não existe sem template aprovado.
2. **Só conta o inbound recente.** Mensagem que o cliente mandou mês passado não reabre nada.

### A coexistência muda de comportamento sozinha

`COEXISTENCE` é credencial da Meta **mais** o lado QR no mesmo número. Enquanto o QR está conectado, a mensagem livre sai por ele, sem janela. **Se o QR cai, o mesmo número passa a se comportar como Cloud API pura** — e a janela de 24h começa a morder de um dia para o outro, sem ninguém ter mexido em nada.

Quando encontrar uma instância `COEXISTENCE`, diga isso em voz alta. É a causa número um de "ontem funcionava".

## 3 · Quem atende cada número

Duas listas por instância, e elas não são a mesma coisa:

- **`allowedTeams`** — equipes que enxergam aquele número.
- **`allowedUsers`** — pessoas soltas, sem passar por equipe.

Ajuste pelo inbox: `koterzap_configuracao_set_inbox_allowed_teams` e `set_inbox_linked_instance`. Inbox com `allowedTeamIds` vazio significa **qualquer atendente**, não "ninguém".

> **A pegadinha que quebra automação do CRM:** a ação `CREATE_LEAD` exige que a instância esteja vinculada a **exatamente uma** equipe. Nenhuma equipe, duas equipes, ou liberada só para usuários: a ação é recusada. A equipe do lead criado sai dessa instância, e é por isso que precisa ser uma só.

Então, ao arrumar `allowedTeams`, pergunte antes de mexer — muda quem enxerga aquele número, e isso é decisão do corretor, não sua.

## 4 · O que o plugin não faz, e por que dizer isso logo

Três coisas, todas fora do alcance de qualquer skill:

| O quê | Por quê | O que dizer |
|---|---|---|
| **Criar instância** | Não existe tool de MCP para isso, em nenhum dos três tipos | "Conectar o número é na tela do Koter — leva dois minutos com o celular na mão" |
| **Registrar Cloud API** | Exige o cadastro embutido da Meta, ou token + wabaId + phoneNumberId | "Esse é o caminho oficial; a Meta entra no meio e pede verificação da empresa" |
| **Aprovar template** | A aprovação é da Meta, e os use cases nem estão no MCP | "Você escreve o template na tela, a Meta aprova em algumas horas ou dias" |

E a licença: registrar instância exige licença de WhatsApp na assinatura; plano free aceita **uma** instância conectada.

**Diga os três de uma vez, no começo.** Descobrir no fim, depois de montar um chatbot e uma régua, que nada disso vai ao ar, é a pior sequência possível.

### ⚠️ `create_message_template` não é o template da Meta

Essa é a armadilha que mais engana nesta área inteira.

> `koterzap_configuracao_create_message_template` cria uma **resposta rápida interna** — texto pronto que o atendente dispara com um clique no chat. A própria tool diz: *"Não são os templates aprovados pela Meta."*
>
> O template da Meta é outra entidade, ligada à instância, e **o MCP continua não criando nenhum** — a aprovação é da Meta.

Uma skill que "cria o template" assim e liga uma automação de mensagem vai falhar **no envio**, longe dali, com um erro que não explica nada. Nunca feche esse laço.

### Mas agora dá para SABER se existe template aprovado

```
koterzap_configuracao_list_meta_message_templates(instanceId, status?, name?, limit?, after?)
    → { templates, paging }
```

Só leitura, e **só funciona em instância Cloud API oficial**. É a tool que responde a pergunta que trava régua de mensagem e renovação: *existe template `APPROVED` para o `SEND_WHATSAPP_TEMPLATE` usar?* Antes de prometer qualquer automação que manda mensagem, consulte — e leve o nome do template aprovado para a automação, em vez de torcer.

Não confunda com `list_message_templates`, que lista as respostas rápidas internas e nem pede `instanceId`.

> **Esta skill é a dona do assunto.** Desde 21/09/2026 a `/introducao` não rastreia mais o template da Meta: no ato 0 ela diz uma frase de orientação junto da tarefa de conectar o número, e para por aí. A conferência acontece aqui, **na hora em que a régua de mensagem for montada** — que é o único momento em que a resposta muda alguma decisão. Não peça ao corretor que "avise quando o template sair": leia.

> ⚠️ **O erro não explica nada.** Medido na Koter Day em 21/09/2026 com um `instanceId` que não existe: a resposta foi só *"Recurso não encontrado."* — não diz que a instância não existe, nem que precisa ser Cloud API. **Confira antes com `list_whatsapp_instances`** e diga ao corretor o que falta; não repasse esse erro cru. (A Koter Day não tem nenhuma instância, então o caminho feliz desta tool segue sem prova.)

### E resposta rápida exige número

> Comprovado na Koter Day: `create_message_template` tem `instances` com pelo menos um item obrigatório. Não dá para deixar respostas rápidas prontas esperando o número chegar. Com um id que não existe, o que volta é erro cru de banco:
>
> ```
> Foreign key constraint violated on the constraint:
> `crm_whatsapp_message_template_whatsapp_instances_instance__fkey`
> ```

Ou seja: **respostas rápidas são passo de depois.** Se não há instância, anote o texto que o corretor quer e volte a criar quando o número existir — não tente e não entregue erro de banco a ele.

## 5 · As respostas rápidas que se pagam

Quando já houver número, três textos resolvem a maior parte do dia, e é por eles que se começa:

1. **Primeiro contato** — quem é a corretora, e a pergunta que qualifica ("é para você, família ou empresa?").
2. **Pedido de documentos** — a lista exata, sempre a mesma, sempre esquecida pela metade.
3. **Cotação enviada** — o texto que acompanha o PDF e marca o próximo passo com data.

O nome vira um atalho único na corretora, então nomeie pelo que o atendente vai digitar (`/docs`, `/cotacao`), não pelo assunto.

**Não crie mais do que três de saída.** Biblioteca de quinze respostas que ninguém decora é pior que nenhuma: o atendente volta a escrever na mão e ainda perde tempo procurando.

## 6 · O que nunca prometer por este canal

O número é o ativo da corretora. Perder o número é perder a carteira inteira de conversas, e a Meta bloqueia sem aviso e sem recurso prático.

1. **Disparo em massa para base fria.** É o caminho mais curto para o bloqueio, e viola a regra de opt-in.
2. **Mensagem sobre doença, tratamento, carência por preexistência.** Dado sensível pela LGPD, num canal que o cliente compartilha com a família.
3. **Aviso de reajuste automático.** A conversa mais delicada do ano não vai por robô. A automação avisa **o corretor**, não o cliente.
4. **Negativa e cancelamento.** Má notícia por robô vira reclamação, às vezes processo.

Isso não é preferência de estilo: é o que gera denúncia no aplicativo, e três denúncias derrubam o número.

## 7 · Validação

Releia o que você mexeu, sempre:

```
koterzap_configuracao_list_whatsapp_instances   → confere allowedTeams
koterzap_configuracao_get_inbox                 → confere a instância vinculada
koterzap_configuracao_list_message_templates    → confere as respostas criadas
```

E feche com a frase que resume o canal, que é o entregável real desta skill:

> "Você tem um número, do tipo Evolution, atendido pela equipe Comercial. Ele conversa normalmente e não tem limite de janela — mas **não dispara mensagem automática**, porque isso só existe no número oficial da Meta. Se quiser régua de WhatsApp, o caminho é conectar um Cloud API; enquanto isso, a régua vira tarefa para você."

## 8 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, os números e seus tipos, e — o campo que mais importa para as outras skills — **se existe Cloud API e se existe template aprovado**. A `koter-crm-automacao`, a `koter-crm-renovacao` e as duas skills de chatbot leem essa resposta.

Próxima, em até 4 opções:

- **`koter-chatbot-fluxo`** — montar o bot de triagem, que funciona mesmo sem número conectado *(recomendada)*
- `koter-zap-conhecimento` — a base que o agente de IA vai consultar
- `koter-crm-automacao` — agora que se sabe o que o canal aguenta
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Automação de mensagem recusada | instância Evolution, não Cloud API | régua sem a ação de mensagem, ou conectar Cloud API |
| Template "criado" e o envio falha | `create_message_template` é resposta rápida interna | aprovar na Meta, pela tela; conferir com `list_meta_message_templates` |
| `list_meta_message_templates` devolve "Recurso não encontrado." | id inexistente, ou instância que não é Cloud API | cheque `list_whatsapp_instances` antes e diga qual dos dois é |
| Resposta rápida devolve erro de banco | não há instância, e `instances` é obrigatório | criar só depois que existir número |
| "Ontem funcionava" | coexistência com o lado QR caído | a janela de 24h passou a valer; reconectar o QR |
| Mensagem só sai depois que o cliente escreve | janela de 24h em Cloud API | é o comportamento correto; use template para reabrir |
| `CREATE_LEAD` recusado na automação | instância sem exatamente uma equipe | `set_inbox_allowed_teams`, com o corretor |
| Diagnóstico de atendimento parece quebrado numa conta nova | sem número, não há inbox nem conversa | as tools de atendimento devolvem vazio, não erro — é diagnóstico, não falha |
| Número duplicado no pareamento | só uma instância conectada por número | desconectar a antiga antes |
| `Operação não permitida.` numa chamada que funcionava | a conexão trocou de corretora | reler `companyId`; **não repetir a chamada** |

## As tools de atendimento numa conta sem número

Conferido na Koter Day em 21/09/2026, com `instances: []`. As leituras de atendimento **respondem normalmente e voltam vazias** — não dão erro, então servem no diagnóstico do passo 2 sem tratamento especial:

| Chamada | Conta sem número |
|---|---|
| `koterzap_configuracao_list_inboxes` | `{inboxes: [], total: 0}` |
| `koterzap_atendimento_get_conversation_counts` | `{mine: 0, pending: 0, all: 0, resolved: 0, archived: 0}` |
| `koterzap_atendimento_list_conversations` | `{conversations: [], total: 0}` |
| `koterzap_atendimento_list_reply_templates` | `{templates: [], total: 0}` |

A exceção é `koterzap_atendimento_search_inbox_messages`, que **exige `inboxId`**: sem nenhuma caixa, não há id para passar e a chamada não tem como ser feita. Não a inclua no diagnóstico — ela só entra depois que existe número.

Confirma o que a seção 1 já dizia: **o KoterZap nasce vazio**, e vazio aqui é resposta, não defeito.
