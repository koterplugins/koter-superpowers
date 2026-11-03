# Hospedeiros: onde o especialista mora

**Conferido em 03/11/2026.** Tudo aqui veio de páginas dos fabricantes e de relatos públicos lidos nessa data. **Nada foi testado em conta real.** Produto de IA muda de plano e de tela todo mês: se esta data tiver mais de três meses, confira a página do fabricante antes de afirmar. "(por trecho)" marca o que veio de trecho de busca, sem a página inteira aberta.

A mesma ficha vira cinco entregas. O que muda é o suporte, nunca o conteúdo.

---

## A sonda

A entrevista pergunta qual IA e qual plano. Esta sonda evita perguntar o que você já consegue ver.

**1 · Você escreve arquivo?** Olhe as suas ferramentas. Se sim, teste num caminho descartável e releia. Permissão negada ou disco só leitura são respostas legítimas: siga adiante sem drama.

**2 · Que convenção existe aqui?** Procure na raiz do projeto e no home:

| Caminho | IA | Formato |
|---|---|---|
| `~/.claude/agents/`, `.claude/agents/` | Claude Code. Cursor e VS Code também leem | `.md` com cabeçalho YAML |
| `.claude/skills/` | Claude Code | pasta com `SKILL.md` |
| `.cursor/agents/` | Cursor | `.md` com cabeçalho YAML |
| `.cursor/skills/`, `.agents/skills/` | Cursor | pasta com `SKILL.md`. `name` igual ao nome da pasta |
| `.github/agents/` | Copilot | `.agent.md` |

Pasta que existe manda. Escreve arquivo e nenhuma existe: crie `~/.claude/agents/`. Sabe que a sua IA usa outro caminho? Use o dela.

**3 · Sobrou dúvida?** Pergunte só o que ele vê na tela:

> "Sua IA tem Projetos, um lugar onde você guarda instruções fixas e abre conversas dentro? E tem uma área de Skills?"

Quem não souber o plano abre as configurações e manda um print.

---

## Tabela por plano de produto

| Produto e plano | Liga o Koter? | Entrega | Conexão | Rotina | Celular |
|---|---|---|---|---|---|
| **Claude Free** | Sim, uma conexão personalizada | B ou S. Skill exige "execução de código" ligada. Plugin não | Uma: o pacote do módulo principal | Não | Usa a conexão feita no computador |
| **Claude Pro, Max, Ultra** | Sim | Plugin, S e B. Sub-agente fica acinzentado no chat | Três pacotes, um ligado por conversa | Tarefa agendada no Cowork, até de hora em hora | Usa. Instalar conector pelo celular está em beta |
| **Claude Team, Enterprise** | Sim. Só o Owner adiciona, cada membro faz login | Igual ao Pro | Igual ao Pro | Tarefa agendada no Cowork | Web e celular do Cowork em Team (beta) |
| **Claude Code** (Pro para cima) | Sim | **A** | **Recorte por agente** | Tarefa agendada na nuvem, intervalo mínimo de 1 hora | Agente de `.claude/` não carrega em sessão de nuvem |
| **ChatGPT Free, Go** | Provável que não | C, sem Koter | Nenhuma | 3 tarefas, no máximo diária | Sim |
| **ChatGPT Plus** | **Não confirmado.** As fontes oficiais se contradizem, e um teste público de agosto falhou ao listar ferramentas | Teste. Falhou: C, sem Koter | Tratar como uma só | 5 tarefas. Uso do Koter nelas não confirmado | Não confirmado |
| **ChatGPT Pro** | Leitura, em texto antigo. Não confirmado | Teste. Falhou: C, sem Koter | Tratar como uma só | 15 tarefas. Idem | Não confirmado |
| **ChatGPT Business, Enterprise, Edu** | Sim, adicionado na web (por trecho) | S e B. Plano de Skill com fontes em conflito | Tratar como uma só | 10 a 15 tarefas. Idem | Não confirmado |
| **Gemini**, qualquer plano | **Não no Brasil.** MCP próprio só nos EUA, em inglês | C, sem Koter | Nenhuma | Pro e Ultra | Sim, sem Koter |
| **Grok, chat** | Provável, por conector personalizado. Não testado | C | Tratar como uma só | Automations, todos os planos | Sim |
| **Grok Bot** (Premium, Super e Ultra da Assinatura X. Plus não inclui) | A conferir. A doc aceita MCP remoto, e o Koter não foi testado. Brasil sem confirmação oficial | **G** | Uma, e vale para a conta inteira | Rotina, intervalo mínimo de 5 minutos | iPhone, iPad e Android completos |
| **Cursor** pago | Sim, com `.cursor/mcp.json` | A, no formato dele | URL do arquivo. `readonly` é a única trava no agente | Automations | iOS em beta |
| **n8n, Make** | Sim, com um técnico | Agente no fluxo | **Recorte por nó** | Sim | Não achei |

GPT e Gem não são entrega deste plugin: a retirada foi anunciada para dezembro de 2026 (OpenAI por trecho). Quem tem um refaz como Projeto ou Skill.

### O que dizer quando não vai dar

**Gemini:**

> "O Gemini ainda não deixa ligar o Koter no Brasil. Dá para ter o especialista de texto, mas ele não vê seus dados. Se quiser que ele opere o Koter, o caminho é o Claude."

**ChatGPT Plus ou Pro:**

> "Vamos testar: entra em chatgpt.com/plugins, no botão de adicionar, e me diz se aparece 'Add custom MCP server'."

Não aparece, ou conecta e não lista ferramentas: ofereça C e pare de insistir.

### Dado de segurado

Confira a regra do plano antes de pôr dado real. Isto não é parecer: para LGPD e prazo legal, confirme com seu jurídico.

| Produto | O que as páginas dizem |
|---|---|
| Claude Free, Pro, Max | Conversa pode treinar modelo se a opção de melhoria estiver ligada. Conteúdo bruto de conector fica de fora, e o colado na conversa não. CPF passado a uma ferramenta: trate como conversa |
| Claude Team, Enterprise | Sem treino por padrão (por trecho) |
| ChatGPT | Página oficial não aberta. Confira no plano |
| Grok Bot | Ver a entrega G |

---

## Entrega A: arquivo em Claude Code

Um arquivo por especialista, `koter-<assunto>.md`: `koter-multicalculo`, `koter-vendas`, `koter-cadastro`, `koter-financeiro`, `koter-crm`, `koter-atendimento`, `koter-secretario`, `koter-implantacao`, `koter-migracao`.

Escreva em `~/.claude/agents/`, ou em `.claude/agents/` do projeto. **Nunca na pasta `agents/` do plugin:** agente que vem dentro de plugin perde `mcpServers`, `hooks` e `permissionMode`, e o recorte some.

```yaml
---
name: koter-financeiro
description: Comissão, repasse, contrato e caixa. Use quando o assunto for quanto entrou, quanto eu devo, fechamento do mês ou estorno.
tools: Read, Skill, mcp__koter-financeiro__*
disallowedTools: mcp__koter-financeiro__gestao_comissao_undo_payout_batch
mcpServers:
  - koter-financeiro:
      type: http
      url: https://api.koter.app/mcp-user/koter?toolsets=gestao-comissao,gestao-financeiro,gestao-config,gestao-contratos
memory: user
maxTurns: 30
---

Você é o Especialista Financeiro do Koter, na corretora <nome>.

[campos 1 a 10 da ficha, na ordem, com os títulos]
```

- **`description` com as palavras do corretor**, em até 200 caracteres. É ela que faz a IA escolher o agente.
- **`tools` define tudo o que ele tem.** O que não está na lista some, por isso `Skill` entra nela.
- **`disallowedTools` leva a coluna "Bloqueada"** da tabela de permissões, uma entrada por ferramenta, com o prefixo `mcp__<servidor>__`.
- **Skill vai por nome literal no campo 3.** Coisas do plugin ganham o prefixo `koter:`. Se o campo `skills:` do cabeçalho aceita nome com prefixo não foi testado: fique no campo 3.
- **Campo 9 inteiro em cada arquivo.**

Falta testar se a definição dentro de `mcpServers` dispara o login. Se não disparar, cadastre com `claude mcp add --transport http --scope user koter-financeiro <url>` e deixe só o nome em `mcpServers`, sabendo que a sessão principal também passa a enxergar essa conexão.

**Depois de escrever:** releia, confira os dez campos e peça para listar os agentes. Arquivo sem `name` e campo desconhecido são ignorados sem aviso. Só então diga que existe, com o caminho completo.

**Outras IAs que leem arquivo.** Cursor aceita `name`, `description`, `model`, `readonly` e `is_background`: não há `tools` nem `mcpServers` na lista, então o agente herda tudo, e `readonly: true` é a única trava. Copilot usa `.github/agents/<nome>.agent.md`. `mcp-servers` lá vale no GitHub.com, não no VS Code. Ambos são ferramenta de programador: não recomende, entregue se ele já usa.

---

## Entrega S: skill empacotada

"Te mando um arquivo, você sobe uma vez, e ele aparece sozinho quando o assunto chega."

```
koter-financeiro/
  SKILL.md
  references/       as skills do campo 3, se a IA não tiver o plugin
```

```yaml
---
name: koter-financeiro
description: Cuida de comissão, repasse, contrato e caixa no Koter. Use quando falarem de quanto entrou, quanto devo, fechar o mês ou estorno.
---

[campos 1 a 10 da ficha]
```

- **Só `name` e `description` no cabeçalho.** Campo fora do padrão dá erro no upload.
- `name` em minúsculas, com hífen, até 64 caracteres, igual ao nome da pasta. `description` até 200.
- **Tem o plugin?** A ficha já acha as skills. Plugin instalado funciona com skills e comandos no chat do Claude pago.
- **Não tem o plugin?** A ficha cita skill que a IA não tem. Copie o `SKILL.md` de cada skill do campo 3 para `references/` e cite o caminho. Leia antes de empacotar, e tire qualquer dado de cliente.
- Compacte a **pasta** em ZIP.

| Produto | Como subir |
|---|---|
| Claude | Customizar > Skills. Exige "execução de código" ligada. Em todos os planos |
| ChatGPT | Skills > Create. Plano com fontes em conflito (por trecho) |
| Gemini | Upload só na web. Vale como texto: o Koter não liga no Brasil |

Quem não consegue gerar o ZIP cai para B. **Skill mais Projeto:** a skill leva o procedimento, o Projeto leva a corretora (comissão combinada, tom, horários).

---

## Entrega B: colar em Projeto

O corretor cola, então o texto vai sem cabeçalho YAML e com a URL escrita no campo 10.

```
Você é o Especialista <nome> do Koter, na corretora <nome da corretora>.

Quando me chamar: <campo 1>
Com quem falo, meu indicador e onde eu paro: <campo 2>
Skills do plugin Koter que eu carrego: <campo 3>
O que eu posso: <campo 4>
O que eu não posso, e quem faz: <campo 5, com as linhas de encaminhamento>
Pré-requisito que só você resolve: <campo 6>
Armadilhas do meu assunto: <campo 7>
Por onde eu começo: <campo 8>
Regras que eu herdo: <campo 9, inteiro>
A conexão que eu uso: <campo 10>
```

| Produto | Onde colar | O que notar |
|---|---|---|
| Claude | Projeto, campo de instruções | Conector não se prende a Projeto: liga e desliga por conversa, no menu `+`. Free tem até 5 Projetos |
| ChatGPT | Projeto, instruções | Em memória, "só do projeto" isola do resto (por trecho) |

> "Cria um projeto chamado 'Financeiro Koter' e cola isso nas instruções. Em cada conversa, deixa ligado só o Koter daquele assunto. Me avisa quando colar."

No Projeto do Financeiro, desligue "Use account memory" para não misturar assuntos.

---

## Entrega G: Grok Bot

Caminho próprio, porque ele não tem arquivo nem tela de configuração: as regras vivem na conversa com o Bot.

**Diga estes fatos antes, sem julgar:**

- O Bot trabalha num computador na nuvem, nos Estados Unidos.
- As páginas lidas não confirmam a disponibilidade no Brasil. O preço é em dólar.
- App conectado vale para a conta inteira: todos os Bots enxergam o Koter.
- Separar Bots não isola. Eles dividem computador, arquivos e sessões, e o fabricante avisa para não usar Bot separado como fronteira de segurança.
- Fora do Enterprise não há registro de auditoria.

> "Antes de pôr dado real de segurado aqui, confirme se isso serve para a sua corretora. Pode ser?"

**Conectar.** No chat do Bot: "adicione um servidor MCP personalizado", com a URL do pacote do primeiro especialista. Não use a conexão inteira. Autorize no cartão que aparecer. Peça para rodar `list_toolsets` e fazer uma leitura. Conectar o Koter por aqui não foi testado.

**Criar.** Botão **+**, com o nome do especialista. Um Bot por especialista, sem prometer isolamento. A primeira mensagem é a ficha no formato da entrega B, terminando assim:

```
Lembre disso como suas regras. Depois liste o que você guardou.
```

**Dê uma tarefa concreta com fim claro**, corrija, e só então peça "salve isso como skill". Skill precisa estar habilitada no Bot. Se o Grok Bot lê o pacote da entrega S não foi confirmado.

**Regras "Ask first".** Vencem as de permitir. Até 20 de cada, 1.000 caracteres por regra. Cole estas:

```
Pergunte antes de usar qualquer ferramenta do Koter que grave, altere, importe, pague, publique, apague ou desfaça.
Pergunte antes de criar, editar ou importar automação ou chatbot no Koter.
Pergunte antes de enviar mensagem, e-mail ou arquivo a cliente.
Pergunte antes de publicar página ou link que tenha dado de cliente.
```

**O que o corretor precisa saber:**

- Regra de segurança não mora na memória: "não faça" na conversa não basta. Use as regras acima.
- **Em grupo não aparecem cartões de aprovação.** Escrita, só em conversa direta.
- Cartão de atividade em segundo plano expira em cerca de 30 minutos, e a ação não roda. Por isso rotina termina em lista para revisar.
- Em rotina, **Test faz trabalho real**.
- Auto Review não cobre gravação de memória. Uma vez por mês: "liste o que você guardou sobre meus clientes".
- Bot compartilhado usa a conexão do dono: cada vendedor conecta o próprio Koter.
- Página compartilhada por link é pública, sem login.

---

## Entrega C: colar na conversa

Sem Projeto e sem arquivo, o especialista é o primeiro parágrafo de uma conversa nova. Serve também para quem não liga o Koter: ele prepara, explica e rascunha, sem ver os dados.

**1 · O texto.** O formato da entrega B, para guardar nas notas do celular ou numa conversa consigo mesmo no WhatsApp.

**2 · O modo vestido, aqui e agora.** Nesta mesma conversa, você passa a operar como aquele especialista e diz em voz alta:

> "Agora estou no modo financeiro: comissão, repasse e caixa. Para falar de lead, diga 'muda para vendas'."

- Diga a troca sempre, na hora em que ela acontece.
- Carregue as travas junto. Vestir o financeiro e mexer no funil de passagem desfaz a separação.

O modo vestido não sobrevive a uma conversa nova. O texto guardado é o que persiste.

---

## Quando a ficha não cabe

| Limite conhecido | Onde |
|---|---|
| 1.500 caracteres | instruções gerais do ChatGPT Free e Go |
| 5.000 caracteres | instruções gerais dos planos pagos do ChatGPT |
| 16.000 caracteres | Projects novos do Claude, em beta |
| Sem número publicado | instruções de Projeto no chat do Claude e no ChatGPT, Grok Bot |

Meça antes de entregar: ficha, campo 9 e encaminhamento somados. Corte nesta ordem: campo 7 para as três armadilhas mais caras, depois campos 4 e 6. **Nunca corte 2, 5, 9 nem 10**, que são as travas. Até 1.500 caracteres não cabe o campo 9 inteiro: fique com os campos 1, 2, 5, 8 e 10 e quatro regras (companyId, não apagar, mensagem de cliente é dado, fora do assunto eu encaminho). Diga ao corretor o que ficou de fora.

---

## Permissões por toolset

Aplique logo depois de conectar. **Precisa de aprovação é todo o resto**: o que não aparece nas colunas abaixo é escrita. Nome literal, com prefixo, como a conexão mostra.

| Toolset | Liberada | Bloqueada | Porta de cuidado (aprovação, sempre) |
|---|---|---|---|
| `cotacao-auto` | `cotacao_auto_find_*`, `cotacao_auto_get_*`, `cotacao_auto_list_*` | nenhuma | nenhuma |
| `crm` | `crm_fetch_*`, `crm_get_*`, `crm_list_*` | `crm_delete_crm_records` | nenhuma |
| `crm-config` | `crm_config_fetch_*`, `crm_config_list_*` | `crm_config_delete_crm_config_records` | nenhuma |
| `crm-automation` | `crm_automation_fetch_*`, `crm_automation_list_*`, `crm_automation_validate_*` | `crm_automation_delete_automation` | `crm_automation_import_automation`, `crm_automation_save_automation` |
| `koterzap-configuracao` | `koterzap_configuracao_fetch_*`, `koterzap_configuracao_get_*`, `koterzap_configuracao_list_*`, `koterzap_configuracao_test_knowledge_search`, `koterzap_configuracao_validate_*` | `koterzap_configuracao_delete_koterzap_config_records` | `koterzap_configuracao_import_chatbot`, `koterzap_configuracao_save_chatbot`, `koterzap_configuracao_save_chatbot_flow` |
| `koterzap-atendimento` | `koterzap_atendimento_get_*`, `koterzap_atendimento_list_*`, `koterzap_atendimento_search_*` | nenhuma | nenhuma |
| `gestao` | `gestao_fetch_*`, `gestao_list_*`, `gestao_search_*` | `gestao_archive_proposal`, `gestao_delete_proposal_records` | nenhuma |
| `gestao-config` | `gestao_config_fetch_*`, `gestao_config_list_*` | `gestao_config_delete_gestao_config_records` | nenhuma |
| `gestao-contratos` | `gestao_contratos_get_*`, `gestao_contratos_list_*`, `gestao_contratos_preview_*` | `gestao_contratos_remove_contract_commission_override`, `gestao_contratos_reverse_contract_implantation` | nenhuma |
| `gestao-comissao` | `gestao_comissao_get_*`, `gestao_comissao_list_*`, `gestao_comissao_resolve_commission` | `gestao_comissao_archive_commission_grade`, `gestao_comissao_cancel_scheduled_commission_table`, `gestao_comissao_delete_commission_bank_fee_rule`, `gestao_comissao_delete_commission_campaign`, `gestao_comissao_end_seller_loan`, `gestao_comissao_remove_market_commission_table`, `gestao_comissao_reverse_commission_allocation`, `gestao_comissao_reverse_commission_receipt`, `gestao_comissao_reverse_commission_statement`, `gestao_comissao_revert_seller_loan_payment`, `gestao_comissao_undo_payout_batch` | nenhuma |
| `gestao-automacao` | `gestao_automacao_fetch_*`, `gestao_automacao_list_*`, `gestao_automacao_validate_*` | `gestao_automacao_delete_management_automation` | `gestao_automacao_save_management_automation` |
| `gestao-financeiro` | `gestao_financeiro_fetch_*`, `gestao_financeiro_get_*`, `gestao_financeiro_list_*` | `gestao_financeiro_deactivate_finance_recurrence`, `gestao_financeiro_delete_counterparty_rule`, `gestao_financeiro_delete_finance_records`, `gestao_financeiro_undo_finance_entry`, `gestao_financeiro_unreconcile_bank_transaction` | nenhuma |
| `admin-usuarios` | `admin_usuarios_fetch_*`, `admin_usuarios_list_*` | `admin_usuarios_delete_admin_users_records` | nenhuma |
| `admin-cargos` | `admin_cargos_fetch_*`, `admin_cargos_list_*` | `admin_cargos_delete_company_role` | nenhuma |
| `importacao` | `importacao_fetch_*`, `importacao_get_*`, `importacao_preview_*` | `importacao_undo_import` | nenhuma |

Lido no código em 03/11/2026, não executado.

- **Porta de cuidado** alcança o cliente da corretora, e a maioria não sai marcada como destrutiva: IA que decide pela marcação não freia.
- **Estorno de verdade.** Bloqueada é o ponto de partida. Quando um estorno precisar sair, passe aquela ferramenta para "Precisa de aprovação", faça, e volte. Quem estorna toda semana deixa em aprovação.
- **Nunca em "Sempre permitir":** `gestao_comissao_pay_payout_batch`, `gestao_comissao_publish_commission_table`, `gestao_contratos_save_contract`, `gestao_contratos_save_contract_event`, `gestao_financeiro_settle_finance_entries`, `importacao_confirm_import`, `admin_usuarios_send_invitations`, `cotacao_auto_create_auto_quote`, `cotacao_auto_dispatch_auto_quote`, `cotacao_auto_create_auto_quote_version`.
- **Secretário Geral:** em `crm`, tudo o que não é leitura fica "Bloqueada".
- **O que o corretor disse que nunca se automatiza** vai para "Bloqueada", mesmo que a tabela diga aprovação.

| Produto | Como aplicar |
|---|---|
| Claude, chat e Cowork | Customizar > Conectores: "Sempre permitir", "Precisa de aprovação" ou "Bloqueada", por ferramenta. Reconfira depois de cada mudança no Koter: há relato de "Always allow" zerado |
| Claude Code | `tools` e `disallowedTools` no agente. O resto pede aprovação. Nada de pular aprovações com dado real |
| ChatGPT | Escrita pede confirmação por padrão, e a decisão lembrada vale só naquela conversa. Toda ferramenta sem marca de leitura conta como escrita |
| Grok Bot | Regras "Ask first" da entrega G. Sem escolha por ferramenta |
| n8n | "Tools to Include": Selecionadas. Aprovação humana por ferramenta |
| Sem permissão por ferramenta | Diga ao corretor que a trava é só o texto da ficha |

---

## Rotina

Só leitura, sempre. Primeira linha: "Antes de tudo, confirme que consegue ler o Koter. Se não conseguir, escreva só 'Koter fora' e pare." Nasce pausada.

| Produto | Onde | O que notar |
|---|---|---|
| Claude pago | Tarefa agendada no Cowork | Até de hora em hora. Tarefas novas de Pro, Max e Ultra rodam na nuvem, com o computador desligado |
| Claude Code | Tarefa agendada na nuvem | Em preview, mínimo de 1 hora. Conectores vêm todos marcados: tire os outros |
| ChatGPT | Tarefas agendadas | Uso do Koter nelas não confirmado |
| Grok, chat | Automations | Todos os planos |
| Grok Bot | Rotina em texto simples | Mínimo de 5 minutos. **Test faz trabalho real** |
| n8n, Make | Gatilho de agenda | Com técnico |

**Risco aberto no Claude:** há relatos, com logs, de ferramenta de conector próprio que não aparece em execução agendada, e a tarefa consta como concluída. "Executar agora" funciona. Por isso a primeira linha existe. Confira a primeira execução real, não só o teste.

O que acontece com ferramenta em "Precisa de aprovação" numa execução sem ninguém olhando não está documentado. Mais um motivo para rotina só ler.

---

## Memória, lista velha e celular

- **Memória guarda preferência, não número.** Comissão, parcela e vencimento o especialista busca no Koter. CPF, apólice e valor nunca.
- **Lista velha.** Depois de mudança no Koter, a IA pode ficar com a lista anterior por minutos ou horas, sem regra clara. Abra a página do conector, peça "atualizar", e reconfira as permissões. Remover e recolocar com a mesma URL não adiantou nos relatos. Ferramenta sumida? Confira com `list_toolsets`.
- **Configura no computador, usa no celular.** A parte de ligar se faz uma vez no computador. Exceção: Grok Bot, completo no celular. Quem só tem celular: Grok Bot, ou Claude pelo navegador do celular, sem confirmação de que funcione.

---

## Quando a criação falha no meio

Não recomece e não pergunte o que fazer.

1. Diga o que ficou pronto, com o caminho.
2. Entregue o que faltou por S, B ou C, na mesma resposta.
3. Grave no estado o que de fato existe.

> "O arquivo não pôde ser escrito nessa pasta, então vai como texto. Cola no seu Projeto ou guarda nas notas."

---

## O que esta página não sabe

- **`?toolsets=` em conector da claude.ai:** relatos recentes mostram a URL com query chegando ao servidor, e a URL idêntica é recusada. Nada oficial garante. Teste com duas conexões.
- **Revogação entre conexões:** se as IAs reaproveitam o mesmo cliente entre conectores não foi comprovado. Por isso os pacotes não se tocam.
- **ChatGPT Plus e Pro:** só testando em conta real.
- **Grok Bot:** se conecta o Koter por OAuth, se todos os Bots enxergam, se conector criado em grok.com aparece no Bot.
- **Limite de instruções** de Projeto no Claude e no ChatGPT, e de Skill no Gemini: não achei número.
- **`disallowedTools` junto de `tools`** com ferramenta de MCP: lido na doc, não testado.

---

## Fontes principais

Abertas em 03/11/2026, salvo as marcadas.

- Claude Code: [agentes](https://code.claude.com/docs/en/sub-agents), [MCP](https://code.claude.com/docs/en/mcp), [tarefas agendadas](https://code.claude.com/docs/en/routines), [plugins](https://code.claude.com/docs/en/plugins-reference)
- Claude: [conectores](https://support.claude.com/en/articles/11176164-use-connectors-to-extend-claude-s-capabilities), [conector próprio](https://claude.com/docs/connectors/custom/remote-mcp), [skills](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills), [plugins](https://support.claude.com/en/articles/13837440-use-plugins-in-claude), [Projetos](https://support.claude.com/en/articles/9519177-how-can-i-create-and-manage-projects), [tarefas no Cowork](https://support.claude.com/en/articles/13854387-schedule-recurring-tasks-in-claude-cowork), [treino de modelo](https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training)
- Relatos: [URL repetida](https://github.com/anthropics/claude-ai-mcp/issues/178), [lista velha](https://github.com/anthropics/claude-ai-mcp/issues/1044), [conector em tarefa agendada](https://github.com/anthropics/claude-ai-mcp/issues/1131)
- ChatGPT: [conectar MCP](https://developers.openai.com/apps-sdk/deploy/connect-chatgpt), [modo desenvolvedor](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt) (por trecho), [retirada de GPT](https://help.openai.com/en/articles/20001519-custom-gpt-retirement-and-migration-faq) (por trecho)
- Gemini: [conectar MCP](https://support.google.com/gemini/answer/17209137?hl=pt-BR), [retirada de Gem](https://support.google.com/gemini/answer/18560919?hl=en)
- Grok Bot: [Bots](https://docs.x.ai/grok-bot/bots), [apps](https://docs.x.ai/grok-bot/computer-and-apps), [aprovações](https://docs.x.ai/grok-bot/approvals-security-and-privacy), [rotinas](https://docs.x.ai/grok-bot/skills-routines-and-automations), [planos](https://docs.x.ai/x-subscription/grok-bot)
- Formato comum de skill: [agentskills.io](https://agentskills.io/specification)
