# Trilha do CRM: ordem de dependência

> A ordem **entre** as trilhas, e onde cada passo de tela é dito ao corretor, está em `passada-unica.md`. Este arquivo cobre só a ordem interna deste módulo.

Não é ordem de importância. É o que quebra se for feito fora de ordem.

| # | Skill | Resolve | Depende de |
|---|---|---|---|
| 1 | `koter-crm-fundacao` | equipes e o funil de cada equipe, **a única que muda a estrutura** | nada |
| 2 | `koter-crm-origens-tags` | de onde vem o lead, como ele é marcado, por que se perde | 1 |
| 3 | `koter-crm-campos` | o que ele pergunta no primeiro contato e o Koter não guarda | 1 |
| 4 | `koter-crm-lead` | **a rotina do dia a dia: lead, tarefa, venda, perda, ponte com a proposta** | 1, 2, 3 |
| 5 | `koter-crm-automacao` | distribuição, resposta rápida, régua de follow-up | 1, 2 |
| 6 | `koter-crm-renovacao` | a rotina que segura carteira, com gatilho no Gestão | 1, e contrato com fim de vigência. A varredura é diária, e o disparo se confere no dia seguinte |

As 1, 2, 3 e 5 são "faça uma vez". A 4 é "faça todo dia", e é onde o onboarding do CRM termina. A 6 é "arme uma vez, colha o ano inteiro".

## As três regras que atravessam a trilha inteira

1. **Funil é por equipe.** `crm_config_fetch_crm_config_context` devolve o funil em `funnelStagesByTeam`, um por equipe, e criar etapa exige `teamId`. "Funil separado" e "equipe separada" são a mesma coisa, e por isso não se cria estrutura para corretora solo.
2. **O CRM já vem com coisa ligada.** A corretora de demonstração nasceu com quatro automações ativas de fábrica, e toda equipe nova nasce com três etapas de sistema. Mostre o que já roda antes de propor criar.
3. **Nada de campo de data no CRM.** Não há campo tipo data nem gatilho por data de campo. O CRM conta tempo (gatilho `SCHEDULED`, passo `WAIT` com janela e ritmo), mas quem lê uma data de vigência é o Gestão (`DATE_FIELD`), e é de lá que a renovação sai.

## Onde a trilha do CRM encosta na do Gestão

| Ponte | Tool | Por quê |
|---|---|---|
| Lead ganho → proposta | `gestao_set_proposal_links` (`leads`) | é o que faz a origem do lead significar alguma coisa lá na frente, e o que põe o cliente na tarefa de renovação |
| Vigência → tarefa no CRM | `gestao_automacao_save_management_automation`, `DATE_FIELD` com fonte `CONTRACT` e campo `endsAt` | o único gatilho por data de campo nos dois módulos. Só existe para quem tem contrato implantado |
| Lead → cotação de auto | `leadId` em `cotacao_auto_create_auto_quote` | só na criação; depois não dá para vincular. Assunto da `koter-multicalculo-auto` |
| Produtos e operadoras | lidos da fundação do Gestão | tags de produto e funil de cross-sell saem daí, sem perguntar de novo |

**A renovação chega como tarefa no cliente certo**, e o motor do Gestão também tem `CREATE_LEAD` e `CREATE_CONTACT`, para quem quer o card no funil. Qual dos dois usar é decisão da `koter-crm-renovacao`.

## Atalhos legítimos

- Corretora que só quer **parar de perder lead**: 1 → 2 → 4. Campos e automação depois.
- Corretora que já tem funil rodando e só quer medir: 2 (motivos de perda) → 5 (consertar as automações de fábrica).
- Corretora solo: 1 cria **uma** equipe e para por aí; pule a conversa de distribuição da 5.
- Quem já perdeu renovação este ano: 6 antes de tudo, porque ela rende sozinha enquanto o resto é montado.

Diga o atalho em voz alta quando escolher um: "vou pular a conversa de equipe, porque você é o único que atende".

Funil por produto, onde os leads travam, WhatsApp e renovação estão descritos dentro das skills correspondentes. `crm_automation_save_automation` alcança o cliente: fica sempre em "Precisa de aprovação".
