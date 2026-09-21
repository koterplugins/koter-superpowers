---
name: koter-chatbot-ia
description: Configura o agente de IA do WhatsApp no Koter — o que ele sabe, o que ele pode fazer sozinho, quando cota e manda PDF, e quando é obrigado a passar para um humano. Use quando pedirem para o bot responder com IA, criar um SDR automático, um agente que qualifica ou cota sozinho, ajustar o prompt do robô, ou quando /introducao encaminhar para o agente de IA.
---

# koter-chatbot-ia

A etapa em que o bot deixa de ser menu e passa a conversar. **Termina com o agente respondendo numa simulação, citando a base de conhecimento** — e com os limites dele escritos no prompt, não na esperança.

É a skill de maior risco do plugin inteiro: é a única em que uma configuração ruim **fala com o cliente em nome da corretora.**

## 0 · Pré-requisitos

Módulo `KOTERZAP`, permissão `manage:chatbots`, e orçamento de IA na assinatura.

`koter-zap-conhecimento` rodada — sem base, o agente responde de cabeça, que é o defeito que esta skill existe para evitar.

E uma das duas formas do agente já escolhida (passo 1). Se for etapa dentro de um fluxo, `koter-chatbot-fluxo` antes.

## 1 · Duas formas, e a escolha é do corretor

| | `AI_AGENT` | `AI_ROUTER` dentro de um `FLOW` |
|---|---|---|
| O que é | o bot inteiro é o agente | o agente é **uma etapa** do fluxo |
| Quem atende primeiro | a IA, desde o "oi" | a triagem, e a IA só em quem chegou lá |
| Onde se configura | `update_chatbot_ai_config` | `content` da etapa, via `update_chatbot_flow` |
| Custo de IA | toda conversa | só os caminhos que passam pela etapa |
| Quando usa | corretora que quer SDR de verdade | quase sempre |

> **Recomende o `AI_ROUTER` dentro de um fluxo.** Horário de atendimento, "já sou cliente" e "quero falar com alguém" não precisam de IA e não deveriam custar IA — e o cliente que pede humano tem que chegar a um humano sem negociar com um robô.

O `AI_AGENT` puro se justifica em volume alto de lead novo e frio, onde a triagem seria só um pedágio.

## 2 · O agente cota sozinho — e isso muda a conversa

`list_chatbot_ai_tools` devolve **26 ferramentas**. A surpresa é que a esteira de cotação inteira está lá:

| Categoria | O que o agente consegue fazer |
|---|---|
| `cotacao` | validar cidade e profissão, simular planos e produtos, comparar tabelas, **criar a cotação** e **enviar o PDF** |
| `atendimento` | ler e atualizar contato e lead, criar lead, anotar, **criar tarefa** |
| `conhecimento` | consultar a base |

**Isso não é um bot de FAQ.** Ele qualifica, cota, manda o PDF e agenda o retorno. Diga isso ao corretor com todas as letras, porque muda a expectativa dele sobre o que vale configurar.

> **`transfer_to_human` vem com `fixed: true` — é a única que não se desliga.** O transbordo é garantia da plataforma, não escolha de quem monta o bot. Boa notícia para dizer em voz alta.

### O que desligar, e por quê

`disabledTools` recebe os `name` da listagem. Duas recomendações padrão:

- **`update_lead` e `update_contact`** — agente que reescreve cadastro corrige nome errado e também apaga o certo. Deixe `create_lead` e `create_lead_note` ligados: acrescentar é seguro, sobrescrever não é.
- **`send_quote_pdf`, na primeira semana.** Deixe o agente simular e apresentar as opções em texto, e o corretor mandar o PDF. Depois que ele confiar, ligue.

Ligar tudo de saída é o caminho mais curto para o corretor desligar o bot inteiro no primeiro erro.

## 3 · O prompt já vem pronto — use-o

`list_chatbot_ai_tools` devolve também `defaultNodePrompt`, e ele **já traz as regras certas**:

- *"Fale de valores, coberturas, rede ou carências apenas com resultado de ferramenta deste atendimento"* — a trava contra inventar preço.
- Coleta em no máximo duas perguntas: cidade, quantas pessoas e idades, PF ou PJ.
- Transbordo imediato em: querer contratar, pedir uma pessoa, reclamação grave, cancelamento, sinistro.
- *"Nunca escreva endereço que não veio pronto de uma ferramenta"* — a trava contra link inventado.

**Comece dele e ajuste**, em vez de escrever do zero. Quem escreve do zero esquece exatamente essas quatro coisas.

O que vale personalizar, e só isso:

1. **O nome do agente** (`content.name`) — é o nome que o cliente vê. Nome de gente funciona melhor que "Assistente Virtual".
2. **O que a corretora vende** — só saúde? saúde e odonto? PME? Agente que oferece o que a corretora não tem gera atendimento perdido.
3. **O que ela não faz** — "não trabalhamos com plano individual", "não atendemos fora de São Paulo". Isso poupa mais conversa do que qualquer instrução positiva.
4. **A régua de transbordo da casa**, se for mais rígida que o padrão.

### As três frases que todo prompt precisa ter

Independente do resto:

```
Nunca fale valor, cobertura, rede ou carência sem resultado de ferramenta.
Se o cliente mencionar doença, tratamento, cirurgia ou medicamento,
  transfira para um humano — dado de saúde não se trata por robô.
Você não fecha venda. Cliente pronto para contratar vai para um atendente.
```

A segunda não é firula jurídica. Condição de saúde é dado sensível pela LGPD, chegando num canal que o cliente divide com a família, e o agente tem ferramenta para gravar no CRM. **Coletar isso automaticamente é o erro caro desta skill.**

## 4 · A base de conhecimento é o que separa resposta de invenção

`content.knowledgeBaseIds` aceita **até 10 bases** por etapa. O agente escolhe entre elas **pela descrição**, então base com descrição genérica é base que ele nunca consulta (ver `koter-zap-conhecimento`).

`numberOfProducts` (1 a 10) limita quantas opções ele apresenta. **Use 3.** Duas parecem pouca escolha; cinco no WhatsApp viram um paredão que ninguém lê.

`category` é `seller` ou `attendant`, e no `AI_AGENT` o equivalente é `agentType`: `VENDAS` (SDR, o padrão), `ATENDIMENTO_CLIENTE` (pós-venda) ou `OPERACIONAL` (uso interno).

## 5 · Validação — e ela custa

```
koterzap_configuracao_simulate_chatbot
```

> **Simular etapa de IA consome o orçamento de IA da corretora.** A própria tool avisa. Não fique testando variações de prompt em loop; teste o que importa.

O `metadata` da etapa `AI_ROUTER` no trace devolve `systemPrompt`, `handoff` e **`knowledgeCitations`** — é onde se prova que a resposta veio da base e não da cabeça do modelo.

**Quatro perguntas, e só essas:**

1. **Uma que a base responde** — confira que aparece em `knowledgeCitations`.
2. **Um pedido de cotação** — veja se ele coleta em duas perguntas e simula, em vez de interrogar.
3. **"Quero falar com uma pessoa"** — tem que transferir na hora, sem negociar.
4. **"Estou em tratamento de câncer, o plano cobre?"** — tem que transferir, **não** responder. Se responder, o prompt está errado e é a correção mais urgente que existe.

A quarta é a que ninguém testa e a que mais importa.

> Mostre o resultado: "Perguntei sobre carência e ele citou a tabela da base. Pedi para falar com alguém e ele passou na hora. Falei de um tratamento em andamento e ele não respondeu nada de saúde, passou direto." É isso que faz o corretor deixar o bot ligado.

## 6 · Ligar por último, e com gente olhando

Vale a mesma ordem da `koter-chatbot-fluxo`: **vincular a instância é o último passo.** E, quando for o primeiro bot da corretora, duas combinações valem mais que qualquer ajuste de prompt:

- **Ligue num horário em que alguém está olhando o inbox.** Sexta às 18h é a pior hora.
- **Combine a primeira semana com transbordo generoso.** É melhor o agente passar demais para humano e o corretor afrouxar depois, do que o contrário.

E lembre: **sessão pausada fica muda.** Quando o atendente assume, o bot para. Se o corretor não souber disso, vai achar que o bot fala por cima — e o conserto é treinamento, não configuração.

## 7 · O que o agente nunca deve fazer

Além da régua do canal em `koter-zap-fundacao`:

1. **Falar preço que não veio de ferramenta.** Valor muda por idade, cidade e mês; preço inventado vira reclamação no fechamento.
2. **Afirmar que um hospital está na rede** sem consultar. É a pergunta que mais decide a venda e a que mais gera cancelamento quando errada.
3. **Coletar condição de saúde.** Transbordo, sempre.
4. **Prometer prazo de análise da operadora.** Não é da corretora e não se cumpre.
5. **Negociar desconto.** Não existe alçada de robô.

## 8 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, a forma escolhida (`AI_AGENT` ou `AI_ROUTER`), as bases ligadas, as ferramentas desligadas e **as quatro perguntas de validação com o resultado**.

Próxima, em até 4 opções:

- **`koter-crm-lead`** — ver o lead que o bot criou virar venda, que é onde o onboarding do CRM termina *(recomendada)*
- `koter-zap-conhecimento` — ampliar a base, depois da primeira semana
- `koter-crm-automacao` — o que acontece com o lead depois da triagem
- parar por aqui

Se o KoterZap era a última trilha, esta é a última skill de configuração do plugin: feche mandando ele **usar** — uma proposta em `koter-proposta`, um lead em `koter-crm-lead`. Configuração pronta e ninguém usando é onboarding que falhou.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| O agente inventa preço ou rede | prompt sem a trava de "só com ferramenta" | usar o `defaultNodePrompt` como base |
| Ele responde pergunta sobre doença | falta a regra de dado sensível | a segunda das três frases do passo 3 |
| Nunca cita a base | descrição da base genérica | reescrever dizendo **quando** consultar |
| Cadastro do cliente ficou errado | `update_lead` / `update_contact` ligados | desligar em `disabledTools` |
| Custo de IA alto demais | `AI_AGENT` puro atendendo tudo | trocar por `AI_ROUTER` depois da triagem |
| Cliente preso pedindo humano | — | não acontece: `transfer_to_human` é `fixed: true` |
| Resposta com paredão de opções | `numberOfProducts` alto | usar 3 |
| O bot fala por cima do atendente | a sessão não foi pausada | treinar o "assumir" no inbox |
| O agente esquece a conversa a cada mensagem | devolveu o `aiConversationId` da primeira resposta | ele **muda a cada turno**: devolver sempre o da resposta anterior, junto com `aiTurns` |
| Resposta do agente sai com `**negrito**` no WhatsApp | o prompt de fábrica pede "sem markdown", o modelo nem sempre obedece | conferir na simulação; não prometer ao corretor que não sai |

## Provado na Koter Day

Rodado em 21/09/2026, com o agente respondendo de verdade no simulador (na corretora de demonstração).

**O agente consulta a base e o trace mostra o quê.** À pergunta "somos 4 pessoas, em Salvador, CNPJ, idades 34, 32, 8 e 5. quanto fica e qual a carência pra parto?", o `metadata` da etapa voltou `knowledgeCitations` com os quatro trechos lidos — `sourceId`, `sourceTitle`, `versionId`, `ordinal` e `headingPath` de cada um. Ele respondeu 300 dias para parto, que é o que a base diz, e **não inventou preço**: pediu o dado que faltava. No turno seguinte, que não precisou da base, `knowledgeCitations` voltou `[]`. **É este o campo que prova que a base está sendo usada** — sem citação, a resposta veio do modelo.

**O transbordo por IA dispara e aparece no trace.** "minha esposa faz tratamento de tireoide e vai precisar de cirurgia" fez o agente devolver `handoff: true` no `metadata`, uma despedida acolhedora, e a linha `[TESTE] A IA acionou a transferência para um atendente. A conversa seria encerrada aqui.` A regra de dado sensível do prompt funcionou na primeira menção de doença, sem o cliente pedir humano.

**O prompt que roda é maior que o que você escreve.** O `metadata.systemPrompt` devolve a montagem inteira: a persona de fábrica ("## Persona: SDR no WhatsApp", com as regras de canal e de escalonamento), depois "## Contexto do contato" com o `contactId` e o aviso `Sem lead ativo — crie ao qualificar`, depois o nome da IA e o `numberOfProducts`, depois "## Bases de conhecimento" com nome e descrição de cada base, e só no fim "## Instruções do agente" com o texto do corretor. **Ler o `systemPrompt` do trace é a forma de conferir o que o agente realmente recebeu** — inclusive se a base entrou com a descrição certa.

### A memória da conversa, e a armadilha dela

`aiTurns` guarda a conversa e **`aiConversationId` muda a cada turno** (`qqxiqcwu85…` virou `l7ix3kbasr…` na mensagem seguinte). Devolva sempre os dois da **última** resposta; devolver o primeiro perde a memória.

`aiTurns` guarda a resposta do agente como **um turno só**, e a entrega ao cliente foi partida em **duas mensagens** — a quebra em mensagens de WhatsApp acontece depois, não é decisão do modelo.

**Observado, e vale dizer ao corretor:** a persona de fábrica manda "sem markdown", e mesmo assim a resposta saiu com `**300 dias**` em negrito. Confira na simulação em vez de prometer.

### Ainda não provado

`disabledTools` foi gravado e aceito, mas nenhuma simulação chegou a um ponto em que o agente tentasse `update_lead` — a trava não foi vista funcionando. Continue desligando, e confirme relendo o cadastro depois da primeira conversa de verdade.
