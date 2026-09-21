# Trilha do CRM — ordem de dependência

> A ordem **entre** as três trilhas, e onde cada passo de tela é dito ao corretor, está em `passada-unica.md`. Este arquivo cobre só a ordem interna deste módulo.

Não é ordem de importância. É o que quebra se for feito fora de ordem.

| # | Skill | Resolve | Depende de | Estado |
|---|---|---|---|---|
| 1 | `koter-crm-fundacao` | equipes e o funil de cada equipe — **a única que muda a estrutura** | — | ✅ rodada |
| 2 | `koter-crm-origens-tags` | de onde vem o lead, como ele é marcado, por que se perde | 1 | ✅ rodada |
| 3 | `koter-crm-campos` | o que ele pergunta no primeiro contato e o Koter não guarda | 1 | ✅ rodada |
| 4 | `koter-crm-lead` | **a rotina do dia a dia: lead, tarefa, venda, perda, ponte com a proposta** | 1, 2, 3 | ✅ rodada |
| 5 | `koter-crm-automacao` | distribuição, resposta rápida, régua de follow-up | 1, 2 | ✅ rodada, com log de disparo |
| 6 | `koter-crm-renovacao` | a rotina que segura carteira — gatilho anual no Gestão | 1, e proposta com vigência | ⚠️ armada; a varredura é diária, o disparo se confere no dia seguinte |

Todas validadas contra a corretora de demonstração Koter Day em 21/09/2026, rodando as chamadas de verdade — não só lendo schema.

As 1, 2, 3 e 5 são "faça uma vez". A 4 é "faça todo dia", e é onde o onboarding do CRM termina. A 6 é "arme uma vez, colha o ano inteiro".

## As três regras que atravessam a trilha inteira

1. **Funil é por equipe.** `crm_config_list_lead_statuses` exige `teamId`. "Funil separado" e "equipe separada" são a mesma coisa — e por isso não se cria estrutura para corretora solo.
2. **O CRM já vem com coisa ligada.** Quatro automações ativas de fábrica na conta de demonstração, e toda equipe nova nasce com três etapas de sistema. Mostre o que já roda antes de propor criar.
3. **Nada de data no CRM.** Não há tipo data nem gatilho por data de campo. O relógio mora no Gestão (`DATE_FIELD`), e é de lá que a renovação sai.

## Onde a trilha do CRM encosta na do Gestão

| Ponte | Tool | Por quê |
|---|---|---|
| Lead ganho → proposta | `gestao_set_proposal_leads` | é o que faz a origem do lead significar alguma coisa lá na frente, e o que põe o cliente na tarefa de renovação |
| Vigência → tarefa no CRM | `gestao_automacao_create_management_automation`, `DATE_FIELD` | o único gatilho por data que existe nos dois módulos |
| Produtos e operadoras | lidos da fundação do Gestão | tags de produto e funil de cross-sell saem daí, sem perguntar de novo |

**Nenhuma ação do motor do Gestão cria lead no CRM.** A renovação chega como tarefa no cliente certo, não como card no funil. Ver `koter-crm-renovacao`.

## Atalhos legítimos

- Corretora que só quer **parar de perder lead**: 1 → 2 → 4. Campos e automação depois.
- Corretora que já tem funil rodando e só quer medir: 2 (motivos de perda) → 5 (consertar as automações de fábrica).
- Corretora solo: 1 cria **uma** equipe e para por aí; pule a conversa de distribuição da 5.
- Quem já perdeu renovação este ano: 6 antes de tudo, porque ela rende sozinha enquanto o resto é montado.

Diga o atalho em voz alta quando escolher um: "vou pular a conversa de equipe, porque você é o único que atende".

Funil por produto, onde os leads travam, WhatsApp e renovação estão descritos dentro das skills correspondentes.
