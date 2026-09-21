# Plugin Koter

**O Koter dentro de qualquer IA.** O corretor digita `/introducao` e o plugin descobre a corretora dele, mede o que já está configurado e configura o resto junto com ele — aplicando de verdade pelo MCP do Koter, em vez de explicar onde fica o botão.

São 23 skills: 22 que escrevem no Koter (Gestão, CRM, KoterZap e chatbot) e uma que monta, dentro da IA que o corretor já usa, os agentes especialistas que vão tocar a rotina depois.

> [Koter](https://koter.app) é a plataforma de CRM e gestão para corretoras de seguros de saúde no Brasil.

## Requisitos

- Um cliente de IA que carregue plugins no formato do Claude Code (Claude Code, ou outro hospedeiro compatível com `skills/` e `commands/`).
- O **conector MCP do Koter** ligado, autenticado com o usuário da corretora. É por ele que o plugin lê e escreve; sem ele as skills não têm o que chamar.
- Um cargo com permissão de escrita nos módulos que você for configurar. O plugin lê as permissões no início e poda sozinho o que você não pode fazer.

## Instalação

```
/plugin marketplace add koterplugins/koter-superpowers
/plugin install koter@koter
```

Ou, para instalar a partir de um clone local:

```bash
git clone https://github.com/koterplugins/koter-superpowers.git
```

e aponte seu cliente para a pasta do clone.

## Como usar

| Comando | O que faz |
|---|---|
| `/introducao` | Onboarding completo: descobre a corretora, diagnostica o que existe e configura o resto com você. |
| `/introducao continuar` | Retoma de onde parou, lendo o estado salvo. |
| `/introducao comissoes` | Pula direto para uma etapa, depois de checar os pré-requisitos dela. |
| `/especialistas` | Monta seus agentes especialistas dentro da IA que você usa. |

As skills também disparam sozinhas pelo assunto: pedir "cria um lead" ou "fecha o repasse do mês" carrega a skill certa sem você saber o nome dela.

## Estrutura

```
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
commands/introducao.md
commands/especialistas.md
skills/
  introducao/                          roteadora: handshake → perfil → diagnóstico → plano → execução
    references/passada-unica.md        a ordem ENTRE as três trilhas, e a lista de tela do corretor
    references/handshake.md            o que a primeira chamada responde e como reagir à falta de permissão
    references/estado.md               onde mora o progresso do onboarding
    references/trilha-gestao.md        as 12 skills do Gestão em ordem de dependência
    references/trilha-crm.md           as 6 skills do CRM em ordem de dependência
    references/trilha-koterzap.md      as 4 skills do KoterZap em ordem de dependência
  koter-gestao-fundacao/               funil de status + entidades de adesão
  koter-gestao-campos/                 campos personalizados de proposta e beneficiário
  koter-gestao-vendedores/             vendedores, categorias, gestores, hierarquia
  koter-gestao-comissoes/              tabelas de recebimento e repasse, variantes, override
  koter-gestao-financeiro/             contas, plano de contas, lançamentos, DRE e fluxo
  koter-gestao-baixa-parcelas/         liquidar, estornar, cancelar
  koter-gestao-conciliacao/            extrato, conciliação e críticas
  koter-gestao-repasse/                lote de repasse: fechar o mês e pagar
  koter-gestao-emprestimos-antecipacao/ empréstimo ao vendedor e antecipação
  koter-gestao-campanhas/              metas e premiação
  koter-gestao-automacao/              o que roda sozinho
  koter-proposta/                      cadastro de proposta — o destino do onboarding no Gestão
  koter-crm-fundacao/                  equipes e o funil de cada equipe
  koter-crm-origens-tags/              origens, tags e motivos de perda
  koter-crm-campos/                    campos personalizados de lead e contato
  koter-crm-lead/                      lead, tarefa, venda, perda — a rotina do dia a dia
  koter-crm-automacao/                 distribuição, resposta rápida, régua de follow-up
  koter-crm-renovacao/                 a rotina que segura carteira
  koter-zap-fundacao/                  os números, seus tipos e quem atende
  koter-zap-conhecimento/              a base que o agente de IA consulta
  koter-chatbot-fluxo/                 triagem, horário, desvio pelo CRM, transbordo
  koter-chatbot-ia/                    o agente que qualifica, cota e manda PDF
  koter-especialistas/                 recorta as 22 skills em agentes especialistas dentro da IA do corretor
    references/catalogo.md             as 7 fichas prontas, com os 8 campos de cada uma
    references/hospedeiros.md          a sonda de capacidade da IA e os três caminhos de entrega
```

A `koter-especialistas` é a única que **não escreve no Koter**: ela escreve na IA. Onde o hospedeiro criar agente, ela cria o arquivo; onde só houver projeto, entrega o texto para colar; onde não houver nada, entrega o bloco copiável e passa a vestir um especialista por vez.

## O contrato de toda skill filha

```
pré-requisitos → reconfere o companyId → detecta o que já existe →
lê o perfil do estado → pergunta só o delta → aplica via MCP →
valida relendo → grava o estado → sugere a próxima
```

## As cinco regras

1. Detectar antes de perguntar.
2. Toda pergunta é uma escolha de 2 a 4 opções, com consequência e recomendação.
3. Toda skill termina em configuração aplicada e conferida.
4. Nada é apagado sem pedido explícito do corretor, na mesma conversa.
5. O `companyId` é reconferido antes de cada rodada de escrita, não só no handshake.

## A passada única

As três trilhas são uma conversa só, em quatro atos (`skills/introducao/references/passada-unica.md`):

```
ATO 0 · Handshake e diagnóstico           as três trilhas de uma vez, nenhuma escrita
ATO 1 · Gestão até a primeira proposta    fundacao → campos → koter-proposta
ATO 2 · CRM até o primeiro lead           fundacao → origens-tags → campos → koter-crm-lead
ATO 3 · O que roda sozinho                comissão, repasse, automação, KoterZap, chatbot
```

A regra que a organiza: **o que depende de outra pessoa sai na frente.** Conectar a Cloud API do WhatsApp e aprovar template na Meta dependem de terceiros e não têm tool de MCP; por isso o diagnóstico do KoterZap roda no ato 0 e essas tarefas são entregues no começo, para o corretor tocar em paralelo.

## Depois da configuração: o time

As 22 skills são o que o Koter sabe fazer. **Ninguém opera 22 skills de cabeça** — e a cada conversa nova a IA recomeça sem saber se o assunto é comissão ou lead. `/especialistas` recorta o plugin em poucos agentes, cada um com um assunto, as skills daquele assunto e as travas daquele assunto:

| Especialista | Carrega | E não faz |
|---|---|---|
| **Cadastro** | `koter-proposta`, `koter-gestao-fundacao`, `-campos` | comissão, lead, funil |
| **Financeiro** | as 8 de comissão, repasse, caixa, conciliação e campanha | cadastro, CRM |
| **Vendas** | `koter-crm-lead`, `-renovacao` | estrutura de CRM |
| **CRM** | `koter-crm-fundacao`, `-origens-tags`, `-campos`, `-automacao`, `koter-gestao-automacao` | o lead do dia a dia |
| **Atendimento** | as 4 de KoterZap e chatbot | funil, lead |
| **Secretário geral** | **nenhuma skill do Koter** — lê as tarefas e recomenda conectores de e-mail, agenda e tarefas | escrever no Koter, conectar qualquer coisa |
| **Implantação** | `introducao` | só existe em conta nova |

A lista é podada pelo diagnóstico, não servida inteira: corretora solo junta Vendas e CRM, sem KoterZap não há Atendimento, e cargo sem escrita em comissão recebe o Financeiro em modo leitura.

**A trava é a parte que rende**, e é por isso que "o que eu NÃO posso" nunca sai da ficha: o especialista de vendas que não mexe no funil não quebra o funil às quintas.

## Como isto foi escrito

Nenhuma skill foi escrita de cabeça. Cada uma nasceu rodando as chamadas de verdade contra uma corretora de demonstração e anotando o que o Koter respondeu — por isso as skills trazem seções de armadilha com a mensagem de erro literal que a plataforma devolve.

- **Gestão, 12 skills**, escritas contra uma conta zerada: funil de 7 etapas, entidades de adesão, campos personalizados, vendedores, tabelas de comissão publicadas, proposta com beneficiários, conta bancária, lançamentos, empréstimo e campanha. O ciclo do dinheiro fecha inteiro pelo MCP — gerar parcela, baixar o recebível, montar e pagar o lote de repasse — e foi medido de ponta a ponta.
- **CRM, 6 skills**, na mesma conta: uma equipe com funil próprio, motivos de perda, campos personalizados, leads percorrendo o ciclo até venda e perda, uma automação que disparou com log de sucesso e a régua anual de renovação sobre a data de vigência.
- **KoterZap e chatbot, 4 skills**: base de conhecimento com texto e FAQ indexada e pesquisada, e um chatbot de 12 etapas — horário de atendimento, desvio pelo que o CRM sabe do contato, triagem, agente de IA e transbordo — gravado, validado e simulado, com o trace mostrando cada desvio.
- **`koter-especialistas`** não tem execução contra o Koter por construção: ela não escreve no Koter. O que ela produz se confere relendo o arquivo criado, e o passo final da skill manda fazer isso.

Três achados que mudam o desenho de quem for escrever skill nova: **funil é por equipe**, não da corretora; **a conta nasce com automações ligadas** e toda equipe nova nasce com etapas de sistema; e **não existe data no CRM** — o relógio da renovação mora no Gestão.

## Licença

MIT. Veja [LICENSE](LICENSE).
