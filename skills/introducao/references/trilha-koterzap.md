# Trilha do KoterZap e do chatbot — ordem de dependência

> A ordem **entre** as três trilhas, e onde cada passo de tela é dito ao corretor, está em `passada-unica.md`. Este arquivo cobre só a ordem interna deste módulo.

Não é ordem de importância. É o que quebra se for feito fora de ordem.

| # | Skill | Resolve | Depende de | Estado |
|---|---|---|---|---|
| 1 | `koter-zap-fundacao` | que números existem, de que tipo, quem atende — e **o que o canal não faz** | — | ✅ rodada |
| 2 | `koter-zap-conhecimento` | o que o agente de IA sabe responder | — (**não precisa de número**) | ✅ validada |
| 3 | `koter-chatbot-fluxo` | **triagem, horário, desvio pelo CRM e transbordo** | 1 para ligar no fim; CRM com equipe | ✅ validada |
| 4 | `koter-chatbot-ia` | o agente que qualifica, cota e manda PDF | 2 e 3 | ✅ validada |

Validadas contra a corretora de demonstração Koter Day em 21/09/2026, rodando as chamadas de verdade — incluindo uma conversa simulada inteira, com respostas do cliente e o agente de IA respondendo. O que cada execução provou está na seção **"Provado na Koter Day"** de cada skill.

## As quatro regras que atravessam a trilha inteira

1. **O KoterZap nasce vazio.** Zero instância, chatbot, inbox, base e resposta rápida — o oposto do CRM, que nasce com automações ligadas. Não há o que revisar: ou existe número, ou a conversa é sobre o que fazer antes disso.
2. **O chatbot se monta inteiro sem número conectado**, e é assim que deve ser feito. Ele nasce `active: true` mas é inerte sem instância, então vincular o número é o **último** passo, depois de validar e simular.
3. **Conectar número e aprovar template não é passo do plugin.** Não existe tool de MCP para criar instância de nenhum tipo, e a aprovação de template é da Meta. Diga isso no começo, não no fim. **Divisão desde 21/09/2026:** a `/introducao` só carrega o número (tarefa de tela do ato 0) e diz uma frase sobre o template; o template em si é assunto desta trilha, conferido com `list_meta_message_templates(instanceId)` na hora em que a régua de mensagem for montada.
4. **Só instância com credencial da Meta dispara mensagem.** "Tem WhatsApp conectado" e "dá para automatizar" são coisas diferentes.

## O que só se descobre rodando

- **`create_message_template` não é o template da Meta.** Cria resposta rápida interna. Skill que fecha esse laço com uma automação de mensagem falha no envio, longe dali, sem explicar.
- **Resposta rápida exige instância**, e sem nenhuma devolve erro cru de banco.
- **O `CONDITION` do chatbot lê campo personalizado** (`crm.lead.extra.<chave>`) — o que a automação do CRM **não** faz. Quando a régua precisa olhar campo personalizado, o lugar dela pode ser o chatbot.
- **Sem lead, toda regra `crm.lead.*` é falsa menos `IS_EMPTY`.** Monte "já é cliente" por `IS_NOT_EMPTY`, com o novo caindo no `ELSE`.
- **A base indexa depois de gravada.** Testar na mesma respiração devolve zero e parece erro de conteúdo.
- **`transfer_to_human` é `fixed: true`** — o transbordo para humano não se desliga.

## Onde a trilha encosta nas outras

| Ponte | Tool | Por quê |
|---|---|---|
| Canal → automação do CRM | `list_whatsapp_instances` | `SEND_WHATSAPP_TEMPLATE` só existe com Cloud API; é aqui que se sabe |
| Instância → `CREATE_LEAD` | `set_inbox_allowed_teams` | a ação exige **exatamente uma** equipe na instância |
| Chatbot → CRM | `CONDITION` com `crm.*`, `ACTION`, `HANDOFF` por equipe | equipe e funil vêm de `koter-crm-fundacao` |
| Agente de IA → catálogo | ferramentas de cotação | planos e produtos saem do catálogo global, sem perguntar de novo |

## Atalhos legítimos

- **Corretora sem número conectado:** 3 → 2 → 4, e a 1 vira só o diagnóstico e a lista do que ele precisa resolver na tela. O bot fica pronto esperando o WhatsApp.
- **Corretora que só quer parar de responder a mesma pergunta:** 2 → 4, com um fluxo mínimo.
- **Corretora que atende bem e só quer triagem fora do horário:** 1 → 3, e para. Sem IA, sem base, sem custo.
- **Corretora que já tem bot rodando:** 1 para ler o canal, depois `get_chatbot_flow` e revisar — nunca recriar.

Diga o atalho em voz alta quando escolher um: "vou deixar o bot pronto antes do número, porque conectar o WhatsApp é na tela e não depende de mim".

O que cada skill precisa saber está na própria `SKILL.md` dela — tipos de instância, janela de 24h e o modelo do chatbot inclusive.
