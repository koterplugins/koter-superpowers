---
name: koter-chatbot-fluxo
description: Monta o chatbot de WhatsApp do Koter — triagem, horário de atendimento, desvio pelo que o CRM já sabe do contato e transbordo para humano — e prova o fluxo por simulação antes de ligar. Use quando pedirem para criar um chatbot, atendimento automático no WhatsApp, triagem, menu, URA, robô de primeiro atendimento, ou quando /introducao encaminhar para o chatbot.
---

# koter-chatbot-fluxo

A etapa mais forte do KoterZap, e a que mais surpreende: **o chatbot se monta inteiro, e se prova, sem número conectado.**

Termina com o fluxo gravado, validado e **simulado com o trace na mesa** — não com um desenho bonito que ninguém viu rodar.

## 0 · Pré-requisitos

Módulo `KOTERZAP` e permissão `manage:chatbots`. Licença de WhatsApp na assinatura (`save_chatbot` exige).

**Não precisa de número conectado.** Precisa, sim, do CRM já com equipe e funil (`koter-crm-fundacao`), porque o transbordo aponta para equipe e as condições leem status e etiqueta.

Se houver base de conhecimento a usar, rode `koter-zap-conhecimento` antes — os ids entram na etapa de IA.

> Reconfira o `companyId` antes de gravar. Ver a armadilha no fim de `koter-zap-fundacao`.

## 1 · A regra que organiza tudo: um bot por número

`Chatbot` é único por instância de WhatsApp (a própria `save_chatbot` diz: *"Uma instância atende um chatbot só."*). **Não existem dois bots no mesmo número**, e não dá para ter um bot "de vendas" e outro "de pós-venda" na mesma linha. A separação entre os dois é *dentro* do fluxo, por triagem.

Se o corretor quer atendimentos muito diferentes, a pergunta certa é se ele quer dois números — e isso é decisão dele, com custo de licença.

## 2 · A ordem que evita o bot meia-boca atendendo cliente

> **O chatbot nasce `active: true`.** Comprovado na Koter Day: a criação devolveu `"active": true, "whatsappInstanceId": null` (hoje é `save_chatbot` sem `chatbotId`, com `name` e `type: "FLOW"`).
>
> Criar é ligar. Mas sem instância ele é **inerte** — e é exatamente isso que dá a ordem segura.

```
1. save_chatbot              name + type FLOW, sem whatsappInstanceId   ← nasce ativo, mas mudo
2. validate_chatbot_flow     antes de cada gravação
3. save_chatbot_flow         o fluxo inteiro, com expectedUpdatedAt
4. simulate_chatbot          a conversa, com trace
5. save_chatbot              chatbotId + whatsappInstanceId   ← só agora ele atende
```

**Vincular a instância é o último passo, nunca o primeiro.** A descrição da própria tool recomenda isso: *"Um chatbot vinculado já responde as mensagens da instância: num FLOW, grave o fluxo antes de vincular."* O `whatsappInstanceId` sai de `whatsappInstances` em `fetch_koterzap_config_context`; `null` desvincula, e `active: false` pausa sem apagar.

E isso resolve o caso comum: corretora que ainda não conectou o número **consegue deixar o bot pronto e conferido hoje**, e ligar quando o WhatsApp chegar. Diga isso ao corretor — é o contrário do que ele espera.

## 3 · As etapas, e as que importam

Doze tipos. Na prática, seis montam 90% dos fluxos:

| Tipo | Para quê | Saídas |
|---|---|---|
| `START` | exatamente uma, sempre | uma |
| `MESSAGE` | fala e segue | uma (512 caracteres) |
| `QUESTION` | menu; guarda a escolha numa variável | uma por opção, mais `default` |
| `CONDITION` | desvia pelo que o CRM sabe | id do grupo, mais `ELSE` |
| `BUSINESS_HOURS` | dentro ou fora do expediente | `open` e `closed` |
| `HANDOFF` | entrega a humano e **encerra a sessão do bot** | uma |

As outras: `AI_ROUTER` (é a `koter-chatbot-ia`), `HTTP_REQUEST` (`success`/`error`), `ACTION` (age no CRM: `CREATE_TASK`, `CREATE_NOTE`, `GENERATE_QUOTE` ou `CREATE_LEAD`, este com `teamId`, `assignmentType` e `preventDuplicate`), `GO_BACK`, `END`. **`INPUT_WAIT` é formato antigo — não crie.**

Teto de 300 etapas, o que nunca é o limite real. O limite real é a paciência de quem está do outro lado.

### `QUESTION` numera sozinho

> Comprovado: com as opções "Cotar um plano", "Já sou cliente" e "Falar com uma pessoa", o que saiu foi:
>
> ```
> O que você precisa agora?
> 1. Cotar um plano
> 2. Já sou cliente
> 3. Falar com uma pessoa
> ```

**Não escreva a numeração no `text`** — ela sai duplicada. E preencha `keywords` em cada opção: o cliente responde "quero saber o preço", não "1".

A saída `default` é para o que não casou com nada. Sem ela, toda opção precisa estar conectada, e a validação recusa.

## 4 · A descoberta: o chatbot enxerga o CRM melhor que a automação do CRM

O `CONDITION` do chatbot lê, **na hora da conversa**, dados do contato e do lead (os ids de estágio, equipe e usuário, as tags e as `key` dos campos personalizados saem de `fetch_koterzap_config_context`):

```
crm.lead.exists          crm.lead.status        crm.lead.tags
crm.lead.perception      crm.lead.user          crm.lead.team
crm.lead.billing.amount  crm.lead.billing.lifes
crm.lead.extra.<chave>   crm.contact.tags       crm.contact.extra.<chave>
```

> **`crm.lead.extra.<chave>` é campo personalizado — e a automação do CRM não consegue isso.** Lá, `conditionFields` é lista fechada e campo personalizado não é condição; a saída documentada era usar tag. No chatbot, `crm.lead.extra.faixa_de_vidas IN ["30-99","100+"]` foi aceito, validado e gravado na Koter Day.

Ou seja: **quando a régua precisa olhar um campo personalizado, o lugar dela pode ser o chatbot, não a automação.** É um caminho que a trilha do CRM não tinha.

Quatro detalhes que mordem:

1. **Sem lead, toda regra `crm.lead.*` é falsa — menos `IS_EMPTY`.** Inclusive `crm.lead.exists IS_EMPTY`. Monte o desvio "já é cliente" sempre por `IS_NOT_EMPTY`, com o caso novo caindo no `ELSE`.
2. **`billing` igual a 0 conta como vazio.** Lead sem faturamento preenchido e lead com faturamento zero são a mesma coisa para a condição.
3. **`IN`, `NOT_IN` e `ALL_OF` leem só `values`** e ignoram `value`. Preencher o campo errado não dá erro: dá condição que nunca bate.
4. **O lead lido é o lead ativo do contato atualizado por último.** Contato com dois leads abertos é ambíguo por construção.

Chave `crm.*` desconhecida, operador fora da lista de cada campo, ou `IN`/`NOT_IN`/`ALL_OF` sem `values`, é recusada — e hoje já no `validate_chatbot_flow`, não só ao gravar. Os operadores aceitos por campo: `exists` só `IS_EMPTY`/`IS_NOT_EMPTY`; `status`, `user` e `team` `EQUALS`, `NOT_EQUALS`, `IN`, `NOT_IN`, `IS_EMPTY`, `IS_NOT_EMPTY`; `tags` `IN` (tem alguma), `NOT_IN` (não tem nenhuma), `ALL_OF` (tem todas), `CONTAINS`, `NOT_CONTAINS`, `IS_EMPTY`, `IS_NOT_EMPTY`; `perception` (`COLD`, `WARM`, `HOT`) `EQUALS`, `NOT_EQUALS`, `IN`, `NOT_IN`; `billing.*` `EQUALS`, `NOT_EQUALS`, `GREATER_THAN`, `LESS_THAN`, `IS_EMPTY`, `IS_NOT_EMPTY`; `extra.*` qualquer um. Num campo personalizado `SELECT`, compare com o `value` da opção, não com o rótulo.

## 5 · O fluxo de referência

Este é o que foi montado e gravado na Koter Day — 12 etapas, 16 ligações, `valid: true`. Use como ponto de partida e pode até o osso conforme a corretora.

```
START
 └─ BUSINESS_HOURS  seg-sex 8-18, sáb 9-13, America/Sao_Paulo
     ├─ closed → MESSAGE "nosso horário é..., me conta aqui" → END
     └─ open   → CONDITION  crm.lead.exists IS_NOT_EMPTY
                  ├─ sim   → MESSAGE "oi de novo, já achei seu cadastro"
                  └─ ELSE  → MESSAGE "oi, aqui é o atendimento da corretora"
                              ↓ (os dois caem na mesma triagem)
                            QUESTION  "O que você precisa agora?"
                              ├─ Cotar um plano   → CONDITION  faixa de vidas 30+
                              │                      ├─ sim  → HANDOFF equipe Comercial
                              │                      └─ ELSE → AI_ROUTER (cota sozinho)
                              ├─ Já sou cliente   → HANDOFF equipe Comercial
                              ├─ Falar com alguém → HANDOFF equipe Comercial
                              └─ default          → AI_ROUTER
```

Três decisões de desenho, e o porquê de cada uma:

- **Horário primeiro.** Bot que faz triagem às 23h e promete atendimento gera a reclamação de manhã. Fora do horário, a mensagem honesta é melhor que o menu.
- **Reconhecer quem já é cliente antes de perguntar.** Quem já está no CRM ouvir "oi, tudo bem, qual seu nome?" é o que faz o cliente pedir um humano.
- **Empresa grande vai direto para gente.** Lead de 30+ vidas é o de maior ticket da corretora; cotar por robô é economizar no lugar errado.

## 6 · Validar é obrigatório, e erra bem

```
koterzap_configuracao_validate_chatbot_flow
```

> Comprovado: um `QUESTION` com a segunda opção sem ligação devolveu
>
> ```json
> { "valid": false, "code": "UNCONNECTED_OUTPUT",
>   "nodeId": "n2", "nodeName": "Triagem", "handle": "b2",
>   "message": "A pergunta \"Triagem\" tem a opção \"Já sou cliente\" sem conexão.
>               Conecte a opção ou a saída \"Resposta não esperada\"." }
> ```

Devolve **o primeiro** problema, não a lista: é corrigir e validar de novo até `valid: true`. O fluxo de referência acima passou com `{ "valid": true, "nodes": 12, "edges": 16 }`.

E o que ele **não** confere: se os ids referenciados pertencem à corretora. Id de base de conhecimento errado só estoura no `save_chatbot_flow` (`KNOWLEDGE_BASE_NOT_FOUND`); id de equipe, usuário, estágio ou estado errado **não é conferido por nenhuma ferramenta** e só aparece quando o chatbot roda. Tire os ids sempre de `fetch_koterzap_config_context`, nunca de memória, e confira o `targetName` do `HANDOFF` na simulação.

### Gravar substitui tudo

`save_chatbot_flow` troca o fluxo inteiro. **Etapa que ficar de fora é apagada, com as ligações dela.** O roteiro de edição é sempre:

```
list_chatbots (ids: [chatbotId], include: ["flow"])
    → alterar mantendo os ids das etapas que continuam
    → validate_chatbot_flow → save_chatbot_flow com expectedUpdatedAt
```

`expectedUpdatedAt` é a proteção contra o corretor ter mexido na tela enquanto você montava: se alguém salvou depois, a gravação é **recusada** em vez de sobrescrever. **Sempre passe** o `updatedAt` lido em `list_chatbots` ou devolvido pela última gravação. Sem ele, o trabalho da tela some sem aviso.

Etapa nova ganha id novo ao gravar: a resposta traz o de-para em `nodeIdMap`. Releia antes de editar de novo.

## 7 · Simular é o que convence

```
koterzap_configuracao_simulate_chatbot
```

Primeira chamada **sem `message`** e sem `simulationId` abre a conversa. Depois, repita o `simulationId` devolvido (prefixo `sim-`), o `currentNodeId` e o `variables` **mesclando `variables` e `internalVariables`** da resposta anterior.

> Comprovado na Koter Day, abertura do fluxo de referência:
>
> ```json
> "trace": [
>   { "nodeType": "BUSINESS_HOURS", "conditionResult": true,
>     "metadata": { "output": "Aberto", "weekday": "mon", "localTime": "11:33" } },
>   { "nodeType": "CONDITION", "nodeName": "Já tem lead?", "conditionResult": false,
>     "metadata": { "output": "Senão", "crmLeadId": null,
>                   "crmContext": "Contato não encontrado nesta corretora" } }
> ]
> ```

**O `trace` é o entregável.** Ele mostra *por que* cada desvio foi tomado, não só o que o bot respondeu. É com ele que se mostra ao corretor que a triagem funciona, antes de qualquer cliente falar com ela.

Cuidados reais:

- **A simulação não usa contato real.** Não há mais `contactId`: nada da sessão é gravado, e os dados do contato vêm do seu usuário (o nome, de `pushName`).
- **`HTTP_REQUEST` chama o endereço de verdade.** Peça confirmação antes de simular fluxo que tenha um.
- **`AI_ROUTER` consome o orçamento de IA da corretora.** Simulação de fluxo com IA não é grátis.
- **`ACTION` e `HANDOFF` só são descritos** e não gravam no CRM. Esses são seguros.

### O que testar, no mínimo

Três caminhos, sempre: **a opção mais comum, o `default`, e o transbordo.** O `default` é o mais esquecido e o mais usado por cliente real, que nunca digita "1".

## 8 · Transbordo é a parte que salva o bot

`HANDOFF` entrega a humano e **apaga a sessão** do bot — o cliente não volta para o menu depois. `#sair` faz o mesmo, digitado pelo cliente, de qualquer ponto.

`handoffType` é `USER`, `TEAM` ou `RANDOM`. **Prefira `TEAM`**: pessoa entra de férias, equipe não.

E a regra que evita a pior reclamação de todas: **sessão pausada fica muda.** Quando o atendente assume na mão, o bot para e guarda o lugar; volta no "Retomar". Isso significa que o bot **não fala em cima do humano** — mas só se o atendente pausar. Diga isso ao corretor no treinamento, porque é o passo que ninguém faz.

Duas saídas obrigatórias em qualquer fluxo:

1. **"Falar com uma pessoa" no menu principal.** Sempre. Bot sem saída é o que faz cliente xingar a corretora.
2. **`default` do `QUESTION` levando a humano ou a IA**, nunca repetindo o menu. Menu repetido duas vezes é onde o cliente desiste.

## 9 · A sessão, e por que a conversa não reinicia no meio

- A expiração é **por inatividade**: cada turno empurra o prazo. Conversa longa não é reiniciada no meio de uma pergunta.
- **Mensagens seguidas são juntadas** antes de chamar a IA (uns 5 segundos). O cliente que manda "oi" / "quero cotar" / "para minha empresa" em três balões é lido como um só.
- Há trava por contato e número, para não consumir a resposta de um `QUESTION` duas vezes.

Nada disso se configura. Serve para explicar comportamento que parece defeito e não é.

## 10 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, o id do chatbot, **se a instância já foi vinculada**, e os caminhos que foram simulados com sucesso.

Próxima, em até 4 opções:

- **`koter-chatbot-ia`** — dar cérebro à etapa de IA do fluxo *(recomendada)*
- `koter-zap-fundacao` — conectar o número, se ainda não há
- `koter-crm-automacao` — o que acontece com o lead depois da triagem
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Etapas somem depois de editar | `save_chatbot_flow` substitui o fluxo inteiro | ler com `list_chatbots` (`include: ["flow"]`) e devolver tudo |
| Trabalho feito na tela desapareceu | gravou sem `expectedUpdatedAt` | sempre passar o `updatedAt` lido |
| Menu sai com números duplicados | numeração escrita no `text` | `QUESTION` numera sozinho |
| Cliente digita texto e o bot trava | falta a saída `default` | conectar `default` a humano ou IA |
| Condição nunca bate | `IN`/`NOT_IN`/`ALL_OF` com `value` em vez de `values` | preencher `values` |
| Desvio "é cliente" pega todo mundo | sem lead, só `IS_EMPTY` é verdadeira | usar `IS_NOT_EMPTY` e tratar o novo no `ELSE` |
| Lead com faturamento 0 cai no "vazio" | 0 conta como vazio em `billing.*` | usar outro campo para esse corte |
| `KNOWLEDGE_BASE_NOT_FOUND` ao gravar | validação não confere ids da corretora, ou a base foi excluída | ids sempre de `fetch_koterzap_config_context`; tirar de `knowledgeBaseIds` a base apagada |
| Bot já atendendo antes de estar pronto | nasce `active: true` | vincular a instância só no fim |
| O bot fala por cima do atendente | a sessão não foi pausada | treinar o "assumir"; `HANDOFF` encerra a sessão |
| Condição compara a variável da triagem e nunca bate | `saveToVariable` guarda o **texto cru do cliente**, não o rótulo nem o id da opção | desviar pela saída da própria `QUESTION`, não por `CONDITION` sobre a variável |
| Simulação volta ao "oi" a cada mensagem | não devolveu `simulationId` e `currentNodeId` da resposta anterior | repetir o `simulationId` `sim-` e o estado |
| Cliente responde a triagem e não recebe nada | o caminho cai direto num `AI_ROUTER`, que entra mudo | pôr um `MESSAGE` antes da etapa de IA |

## Provado na Koter Day

Rodado de ponta a ponta em 21/09/2026, com o simulador, no chatbot de referência (na corretora de demonstração). O que a execução mostrou, além do que já estava escrito:

**A `QUESTION` casa por palavra-chave e entrega o número.** "quero cotar um plano pra minha empresa" voltou `metadata: {matchedOption: "Cotar um plano", optionNumber: 1}`. Resposta fora das opções ("oi, bom dia, tudo certo por aí?") voltou `matchedOption: null` e seguiu pela saída `default` — a saída `default` não é teórica, é o caminho de quem cumprimenta antes de pedir.

**⚠️ `saveToVariable` guarda o texto cru do cliente.** A variável `intencao` ficou com `"quero cotar um plano pra minha empresa"`, **não** com `b_cotar` nem com `"Cotar um plano"`. Quem montar uma `CONDITION` comparando essa variável com o rótulo da opção monta um desvio que nunca bate. O desvio certo sai da própria saída da `QUESTION`. O fluxo também ganha `last_message` sozinho, com a última fala do cliente.

**A `CONDITION` lê o CRM na hora, e diz qual lead leu.** Com contato real, o trace voltou `crmLeadId` preenchido e `crmContext: "Decidido com o lead ativo do contato atualizado por último"` — contato com mais de um lead é decidido pelo mais recente, não pelo que o corretor tem em mente.

**O campo personalizado do lead é lido com o valor de verdade.** Provado com controle negativo, no mesmo lead (`faixa_de_vidas: "10-29"`): `crm.lead.extra.faixa_de_vidas EQUALS "10-29"` deu `conditionResult: true`; `IN ["30-99","100+"]` deu `false`. Não é presença do campo, é o conteúdo.

**O `HANDOFF` resolve o destino e encerra.** Voltou `[TESTE] Aqui a conversa seria transferida para equipe "Comercial". A sessão do chatbot seria encerrada.`, com `simulatedHandoff: true` e `targetName` resolvido a partir do `targetId` — é assim que se confere que a equipe do `targetId` é mesmo a que o corretor quis. Depois dele a resposta não traz `currentNodeId`: a sessão acabou.

### ⚠️ Duas descobertas que mudam como se simula

**Em 21/09, com `contactId` de contato real, a simulação recomeçava do `START` a cada chamada**, e conversa de várias mensagens só funcionava com o id `sim-`. Hoje o simulador não aceita mais contato real: só `simulationId` (prefixo `sim-`), e os dados do contato vêm do seu usuário. As provas de `CONDITION` com lead real acima foram feitas pelo caminho antigo. Se a `CONDITION` encontra lead para o contato simulado ainda não foi conferido; até lá, trate o desvio por dado do CRM como provado pelo trace da primeira conversa real, não pela simulação.

**A etapa `AI_ROUTER` entra muda.** Ao cair nela, a resposta veio com `messages: []` e `metadata: {awaitingUserInput: true}` — o agente não abre a conversa, ele espera a próxima mensagem do cliente. Aconteceu nos três caminhos que terminam em IA. Se o caminho inteiro for `QUESTION → AI_ROUTER`, o cliente responde a triagem e **não recebe nada**. Ponha um `MESSAGE` de passagem antes da etapa de IA.
