---
name: koter-superpoderes
description: Acha o que mais trava a corretora e aponta 3 técnicas para configurar seus agentes. Use quando perguntarem como tirar mais da IA, por que o agente erra ou por onde começar.
---

# koter-superpoderes

Esta skill acha onde a operação trava e aponta **três técnicas**, cada uma com algo para fazer hoje no Koter. As 19 técnicas ficam em `references/tecnicas.md`, e você só abre as três que saírem daqui.

Superpoder aqui é trabalho que o corretor deixa de repetir e erro que ele pega antes do cliente. Nenhuma técnica foi testada com corretor: diga isso se perguntarem, e não prometa número.

## 0 · Limites

- **Esta skill só lê e orienta.** Não escreve no Koter, não liga automação e não monta agente. Quem monta é `koter-especialistas`. Quem prova é `koter-prova`.
- **Dois tipos de agente.** O do corretor mora na IA dele e fala com ele. O do cliente mora no KoterZap e fala com o segurado. Nenhuma ferramenta da conexão manda mensagem a cliente, e o agente de WhatsApp não tem ferramenta de auto. Não prometa envio.
- **No máximo 3 técnicas por diagnóstico.** Se pedirem todas, aponte `references/tecnicas.md` sem colar o arquivo.

## 1 · Pergunte uma vez, em bloco

Quatro perguntas, numa mensagem só. Quem preferir pode mandar um áudio contando a semana.

1. Qual IA e qual plano você usa?
2. O que mais dói toda semana?
3. Você já tem agente rodando? Nenhum, um ou vários?
4. O que você nunca quer automatizar?

O que o Koter responde, não pergunte. Se faltar uma resposta, siga com o que tem e diga o que supôs.

## 2 · Confira a dor no Koter, se a conexão deixar

Uma leitura basta, escolhida pela dor. Antes dela, veja o que a conexão alcança com `admin_cargos_fetch_admin_roles_context(include: ["myPermissions"])`. Se o cargo não alcançar, use `list_toolsets`. Sem conexão, pule este passo.

| Dor | Leitura | O que olhar |
|---|---|---|
| Inadimplência, carteira | `gestao_contratos_list_contracts(statuses: ["SUSPENDED"], pageSize: 1)` | `total`. Zero não prova carteira em dia (ver a receita) |
| Cotação auto parada | `cotacao_auto_list_auto_quotes(pageSize: 20)` | linhas sem `chosenOffer` |
| Atendimento atrasado | `koterzap_atendimento_list_conversations(onlyMine: true, statuses: ["OPEN", "PENDING"], archived: false)` | última mensagem do cliente, com `lastMessage.direction: "INCOMING"` |
| Agenda fora de controle | `crm_list_tasks(type: "pending", pageSize: 1)` | `total` |
| Comissão | `gestao_comissao_list_commission_pendencies(pageSize: 1)` | `openCountByType` |

Mostre só a contagem. Sem nome de cliente, sem documento e sem valor nesta etapa.

## 3 · Ache o gargalo

Escolha a linha que mais parece com o que ele contou.

| O que o corretor diz | Gargalo | Técnicas | Receita |
|---|---|---|---|
| "Não sei por onde começar" | falta um primeiro trabalho | T19, T3, T4 | a dor número 1 dele |
| "Perco dinheiro sem ver: inadimplente, apólice vencida" | ninguém corre atrás | T4, T2, T8 | recuperação de carteira |
| "Cotação fica parada e o cliente esfria" | sem próximo passo | T2, T8, T10 | cotação parada |
| "Cotar auto toma meu dia" | coleta e repetição | T9, T2, T7 | multicálculo |
| "Começo o dia sem saber o que olhar" | excesso de lugares para ver | T17, T8, T2 | abertura do dia |
| "Não sei se a comissão bateu" | conferência manual | T4, T8, T16 | conferência de comissão |
| "O agente erra ou inventa" | sem verificação | T9, T14, T16 | a que ele já usa |
| "Explico tudo de novo a cada conversa" | regra no lugar errado | T5, T6, T7 | nenhuma |
| "Tenho medo de ele mexer no que não deve" | permissão | T1, T11, T13 | nenhuma |
| "Tem ferramenta e agente demais, virou bagunça" | escopo | T3, T12, T2 | nenhuma |
| "Corrijo sempre a mesma coisa" | sem aprendizado | T7, T10, T15 | a que ele já usa |
| "Quero IA falando com meu cliente no WhatsApp" | agente do cliente | T1, T18, T13 | nenhuma, use `koter-chatbot-ia` |

Três ajustes:

- **Permissão não configurada, ou ele não sabe dizer:** T11 entra no lugar da terceira técnica.
- **Plano com uma conexão só, como Claude Free:** em T12, escolha o assunto principal e use essa conexão, sem os três pacotes.
- **Grok Bot:** leia `references/grok-bot.md` antes de responder. Peça que ele confirme disponibilidade e regra de dados antes de pôr dado real de segurado.

## 4 · Entregue três e pare

Leia em `references/tecnicas.md` só as três escolhidas. Responda neste formato, sem passar de uma tela:

```
Seu gargalo: <uma frase, com a contagem do passo 2 se houver>

1. <nome da técnica, sem o código T>: <o que é, em uma linha>
   Faça hoje: <uma ação, com palavras de corretor>
2. ...
3. ...

Agente para começar: <receita de references/receitas.md, ou "nenhum por enquanto">
Depois: /prova, antes de confiar nele.
```

O código T e o nome de ferramenta são para você, não para ele. Se a ação pede uma leitura no Koter, rode e mostre o resultado, em vez de mandar o corretor chamar a ferramenta. Se pede gravação, ofereça levar para a skill certa.

Termine com uma pergunta só: qual das três ele quer fazer agora. Se escolher, mande para a skill certa:

| Ele quer | Skill |
|---|---|
| Montar o agente | `koter-especialistas` |
| Provar o agente | `koter-prova` |
| Cotar auto | `koter-multicalculo-auto` |
| Agente do WhatsApp | `koter-chatbot-ia` |
| Automação | `koter-crm-automacao` ou `koter-gestao-automacao` |
| Renovação | `koter-crm-renovacao` |

## 5 · Se perguntarem de onde veio

Cada técnica traz a fonte em uma linha. A lista completa, com link, data e força da evidência, está em `references/fontes.md`. Relato de fabricante é relato de fabricante: diga isso. Um caso real da base do Koter, sem nome: uma corretora com cerca de 50 vendedores automatizou o cadastro de propostas com um plano comum do Claude conectado ao Koter. É relato do cliente, não estudo.

## Conferência

Nomes e parâmetros de ferramenta conferidos no inventário e no código do Koter em 03/11/2026, por leitura, sem execução. O diagnóstico não foi testado com corretor.

Fontes externas lidas em 03/11/2026, parte delas por resumo, como `references/fontes.md` indica.
