# Como o MCP do Koter funciona hoje

Este é o manual da conexão: o que existe, como conectar, o que a URL corta, os limites, os erros e o que não dá para fazer. **É o único arquivo do plugin que escreve número de ferramenta**, e o número muda quando o Koter muda. Nas outras skills, confira com `list_toolsets`.

---

## Os 16 toolsets

**266 ferramentas abertas à corretora, mais 3 meta-ferramentas** (`list_toolsets`, `enable_toolset`, `disable_toolset`).

**266 é teto, não o que cada um vê.** A ferramenta só aparece se o cargo, a licença e o consentimento da conexão deixarem. `list_toolsets` responde o que **aquela** conexão enxerga, em `toolsCount`. Ele não conta o total do Koter, e é a fonte certa para qualquer decisão.

| Módulo | Toolset | Tools | O que tem dentro |
|---|---|---:|---|
| Cotação | `cotacao-auto` | 11 | multicálculo de auto: disponibilidade, veículo, cotação, versões, oferta escolhida, PDF da seguradora |
| CRM | `crm` | 11 | lead, contato, tarefa, nota, venda e perda |
| | `crm-config` | 15 | equipe, fila e transbordo, funil, origem, tag, motivo de perda, campo personalizado com grupos e layout, interesse da corretora |
| | `crm-automation` | 16 | automação do CRM, com espera, janela e ritmo, e os modelos, imagens e rodapé de e-mail das automações |
| | `formularios` | 6 | formulário de captura: perguntas, condições, publicação, pergunta só de formulário, respostas dos visitantes |
| KoterZap | `koterzap-configuracao` | 22 | chatbot, fluxo, base de conhecimento, caixa, resposta rápida, leitura de instância e de template da Meta |
| | `koterzap-atendimento` | 6 | conversa, mensagem, anexo, transcrição. **Não envia** |
| Gestão | `gestao` | 11 | proposta, beneficiário, nota, vínculo com lead e contato, catálogo do segmento |
| | `gestao-config` | 17 | status, entidade, vendedor, campo personalizado com grupos e layout, formulário de proposta |
| | `gestao-contratos` | 12 | implantação, eventos do contrato, participantes, cosseguro, prévia de comissão |
| | `gestao-comissao` | 67 | regras, grades, expectativa, recebimento, extrato, lote, conferência, repasse, estorno, empréstimo, campanha |
| | `gestao-automacao` | 16 | automação do Gestão, com gatilho por data de proposta, contrato ou lançamento (`DATE_FIELD`), e os modelos, imagens e rodapé de e-mail |
| | `gestao-financeiro` | 27 | conta, lançamento, plano de contas, extrato bancário, conciliação, crítica, relatórios |
| Administração | `admin-usuarios` | 17 | usuário, convite, pessoa, hierarquia, informativo, seguradoras ativas |
| | `admin-cargos` | 5 | cargo, permissão, e o **handshake** |
| Importação | `importacao` | 7 | trazer histórico de outro sistema: vendedores, contatos, leads, propostas, lançamentos, extratos OFX |
| | **total** | **266** | |

Por módulo: Cotação 11, CRM 48 (`formularios` é do módulo CRM), KoterZap 28, Gestão 150, Administração 22, Importação 7.

Em `list_toolsets`, cada linha traz `key` (o nome que vai na URL), `module`, `label`, `description`, `toolsCount` e `enabled`. Toolset com zero ferramenta para aquele cargo aparece com `enabled: false`.

Nomes iguais em dois toolsets só se separam pelo prefixo: `crm_config_save_custom_field_definition` e `gestao_config_save_custom_field_definition`, `crm_automation_list_automation_logs` e `gestao_automacao_list_automation_logs`. O plugin sempre escreve o nome com prefixo, que é como a conexão unificada mostra.

---

## Como conectar

**URL da conexão:**

```
https://api.koter.app/mcp-user/koter
```

No Koter, a tela **Acessos** (dentro de MCP, "O que seu cargo pode conectar") monta a mesma URL com as áreas que você marcar. O número que a tela mostra é o tamanho da área, sem o filtro do cargo: para saber o que a sua conexão vê, chame `list_toolsets`.

**O login é por OAuth.** Quem conecta não copia chave nenhuma:

1. No Claude e no Claude Code, a conexão vem com o plugin, e o login abre no primeiro uso. Nas outras IAs, cola a URL e autoriza.
2. Entra no Koter e vê a lista de áreas, agrupadas por módulo.
3. Marca as áreas. O Koter concede só o que o cargo dele permite, mesmo que ele tenha marcado mais.
4. A IA volta conectada.

O que vale depois disso:

- **A conexão se renova sozinha.** O acesso dura 7 dias e se renova por 30 dias a cada uso: quem usa ao menos uma vez por mês não precisa entrar de novo.
- **A conexão segue a corretora ativa da pessoa, não a de quando foi criada.** Trocar de corretora no Koter leva a IA junto, e a permissão passa a ser a de lá. É por isso que o `companyId` se reconfere antes de cada rodada de escrita.
- **Conexão antiga não ganha área nova sozinha.** Área que nasceu depois da sua conexão só entra reconectando e marcando. Se `cotacao-auto` não aparece em `list_toolsets` de uma conexão antiga, reconecte e marque a área.
- **Depois de mudança no Koter, a IA pode ficar com a lista velha.** Na claude.ai (situação em out/2026), a lista se atualiza sozinha depois de minutos ou horas, sem regra clara, e abrir a página do conector pode resolver. Depois disso, reconfira as permissões de cada ferramenta, porque elas podem voltar zeradas.
- **Limite:** 100 conexões ativas por usuário e corretora. Mensagem literal: `Você atingiu o limite de 100 chaves de acesso MCP ativas. Revogue uma chave existente antes de criar outra.`

Uma rota por área também existe (`/mcp-user/<área>`), com nomes sem prefixo e sem as meta-ferramentas. O plugin não a usa.

---

## O que `?toolsets=` faz

**É o teto da conexão.** Ele limita a sessão, o `list_toolsets`, o consentimento e a aprovação.

| URL | Resultado |
|---|---|
| sem parâmetro | tudo o que a conexão alcança, ligado desde o início |
| `?toolsets=all` | igual. Se `all` aparecer em qualquer posição da lista, vale tudo |
| `?toolsets=crm,gestao` | só esses. Os outros nem aparecem em `list_toolsets` |
| `?toolsets=none` | só as 3 meta-ferramentas ligadas. Vale sozinho: `none,crm` dá 400. Não serve para a claude.ai (ver abaixo) |
| toolset fora do que a conexão concedeu | **400** |

**Corta assunto, não corta escrita.** Com `?toolsets=crm`, a conexão continua podendo gravar lead. Ver "Escrita".

Na tela de autorização, a URL com filtro deveria oferecer só aquelas áreas, com a recusa `A URL desta conexão limita as áreas que ela pode receber; marque só as que ela pede.` Nem toda IA leva o filtro até a autorização. Se a tela mostrar tudo e você desmarcar uma área que a URL pede, **toda chamada** passa a dar 400. Regra prática: marque exatamente o que a URL pede.

### `enable_toolset` e `disable_toolset`

Eles ligam e desligam um toolset **dentro do teto da URL**, numa sessão, e dependem de a IA reenviar o cabeçalho `Mcp-Session-Id`. Sem isso, a resposta é erro, começando por `Esta conexão não reenviou o Mcp-Session-Id que o initialize devolveu`.

**Não ajudam na claude.ai.** A lista é montada uma vez, no início, e `tools/list_changed` é ignorado. Ligar depois não entrega ferramenta nova; desligar não encolhe a lista guardada, e chamar uma ferramenta desligada dá erro. Não conte com essa alavanca em nenhuma IA: a que funciona é a URL, definida antes de conectar. Trocar a URL exige recriar o conector.

Uma sessão nova volta ao conjunto da URL, que pode não ser tudo.

---

## Escrita: somente leitura não é trava

**Toda conexão por OAuth nasce com escrita.** O corretor não tem caminho de conexão somente leitura. "Agente só de leitura" é regra de instrução, ou permissão na IA. Nunca prometa como trava de conexão.

**A trava mora na IA.** Depois de conectar, deixe as ferramentas assim, onde a IA der essa opção:

| Tipo | Permissão |
|---|---|
| Leitura (`list_*`, `get_*`, `fetch_*`) | liberada |
| Escrita (`save_*`, `set_*`, e as demais) | "Precisa de aprovação" |
| Exclusão e desfazer (`delete_*`, `reverse_*`, `undo_*`) | bloqueada, ou "Precisa de aprovação" |

**Portas de cuidado.** Estas nove gravações fazem o Koter mandar algo ao cliente da corretora, ou para fora dele, sem nova confirmação. Hoje, só `koterzap_configuracao_save_chatbot_flow` sai marcada como destrutiva, então a IA que decide pela marcação não freia as outras. Sempre "Precisa de aprovação", mesmo para quem liberou o resto:

| Ferramenta | Como alcança o cliente |
|---|---|
| `crm_save_task` | `actions` com `SEND_WHATSAPP_TEMPLATE` ou `SEND_EMAIL` envia aos leads e contatos da tarefa no horário dela; `guestEmails` faz o Google mandar convite por e-mail a cada convidado |
| `crm_automation_save_automation` | ações `SEND_WHATSAPP_TEMPLATE`, `SEND_EMAIL` e `SEND_WEBHOOK`. A automação criada já nasce publicada e ativa. Criar endpoint de webhook não é por MCP |
| `gestao_automacao_save_management_automation` | ação `SEND_EMAIL` ao contato da proposta; `active: true` também religa uma automação de tela com WhatsApp ou webhook |
| `crm_automation_save_email_template`, `gestao_automacao_save_email_template` | muda o e-mail que as automações ligadas já mandam |
| `crm_automation_save_email_footer`, `gestao_automacao_save_email_footer` | muda o rodapé de todos os modelos, a partir do próximo envio |
| `koterzap_configuracao_save_chatbot` | `active: true` liga o bot na instância; `replaceOccupant: true` tira dela o bot que atendia, que volta a rascunho pausado |
| `koterzap_configuracao_save_chatbot_flow` | troca na hora o fluxo de um bot ligado: contato parado numa etapa apagada volta ao início na próxima mensagem |

A base de conhecimento numa etapa de bot ligado muda na hora o que ele responde. `koterzap_configuracao_save_knowledge_source`, `koterzap_configuracao_import_knowledge_url` e `koterzap_configuracao_restore_knowledge_source_version` pedem o mesmo cuidado quando a base está num bot ligado.

Tarefa sem `actions` e sem `guestEmails` não alcança o cliente. As cópias de `crm_automation_import_automation` e `koterzap_configuracao_import_chatbot` nascem rascunho e desligadas: só chegam ao cliente quando uma porta as liga. Todo chatbot nasce pausado, e vincular o número não liga: só `active: true` liga.

---

## Limites

| Limite por minuto | Valor | Vale por |
|---|---|---|
| Leitura | 300 | conexão |
| Escrita | 60 | conexão |
| Requisições HTTP | 600 | conexão, teto contra abuso |
| `cotacao_auto_find_vehicle` | 30 | usuário |
| `cotacao_auto_get_fipe_catalog` | 60 | usuário |
| Disparo de auto (`cotacao_auto_create_auto_quote` com disparo, `cotacao_auto_dispatch_auto_quote`, `cotacao_auto_create_auto_quote_version`) | 10 | usuário |
| `koterzap_atendimento_get_message_attachment_url` | 60 | usuário |
| Aprovação do OAuth | 10 | usuário |

A janela é deslizante, e a recusa não conta. Só chamada de ferramenta conta. Mensagem literal: `Limite de 60 chamadas de escrita por minuto desta conexão atingido. Espere Ns e repita a chamada; a recusa não conta no limite.`

Cotas por mês do multicálculo:

| Cota | Valor |
|---|---|
| Disparos de auto | 30 |
| Consultas de veículo (`cotacao_auto_find_vehicle`) | 60 |

Contam por usuário, somando todas as conexões dele, e só no MCP: a tela não tem cota. Viram no dia 1. Recusa literal: `Limite de 30 disparos de cotação por mês atingido. Renova em 01/MM.` (ou `60 consultas de veículo`).

Outros tetos que uma rotina ou lote encontra:

- Automações do CRM: 99 por corretora (`automationLimit` em `crm_automation_fetch_automation_context`).
- Importação: uma na fila por usuário, três por corretora.

---

## Erros de conexão

| Erro | O que quer dizer | O que fazer |
|---|---|---|
| **400** `Bad Request: toolset(s) fora do alcance desta conexão em "toolsets": <lista>. Toolsets disponíveis: <lista> (ou "all").` | a URL pede um toolset que a conexão não concedeu: desmarcado no consentimento, ou perdido por cargo ou módulo | a própria mensagem diz o que está disponível. Tire da URL, ou reconecte marcando a área |
| **401** | conexão inválida, revogada ou vencida, ou sem nenhuma área do MCP. Área nunca concedida que a URL pede é 400, não 401 | a IA refaz o OAuth. É o sintoma também de uma conexão revogada por outra (ver pacotes) |
| **403** `Seu perfil não tem mais permissão para usar esta conexão do Koter via MCP na corretora X.` | a conexão está boa, mas nenhuma área continua valendo naquela corretora | muda o cargo ou o módulo, ou confira a corretora ativa. Reconectar não resolve |
| **403 ou erro de ferramenta** `Nenhuma corretora ativa para este usuário. Selecione uma corretora no Koter e tente novamente.` | a pessoa não tem corretora selecionada | selecione no Koter. Enquanto a conexão segue guardada, por até 5 minutos, sobem só as 3 meta-ferramentas |
| erro de ferramenta `Seu perfil não tem permissão para usar a ferramenta "x" na corretora Y.` | a conexão vale, o cargo não alcança aquela ferramenta | diga o que falta e de quem depende |
| erro de ferramenta `Seu perfil não tem permissão para fazer esta operação com a ferramenta "x" na corretora Y.` | a ferramenta abre, mas aquela operação pede mais | idem |
| erro de ferramenta `Limite de ...` | passou do limite por minuto | espere o tempo que a mensagem diz e repita |

Perda de cargo pode levar até 5 minutos para mudar a lista, mas cada chamada revalida cargo e corretora na hora.

Parâmetro fora do esquema é erro de validação em qualquer profundidade: nunca é descartado em silêncio.

---

## O que não dá para fazer pelo MCP

**Responder o cliente numa conversa.** `koterzap-atendimento` lê, busca, baixa anexo e transcreve; não envia, não atribui, não resolve. O agente do corretor prepara o texto, e quem manda é o corretor.

O que chega ao cliente pela conexão sai só das portas de cuidado: a lista está em "Escrita".

O resto da lista:

- **Cotar saúde ou odonto.** Cotação de saúde pelo MCP é só master. A única cotação aberta à corretora é `cotacao-auto`. O agente do KoterZap cota saúde dentro do WhatsApp, e isso é outra coisa.
- **Multicálculo auto no WhatsApp.** O agente do KoterZap não tem ferramenta de auto. O multicálculo fala com o corretor, nunca com o segurado, e o link da cotação é tela interna: não vai ao segurado.
- **Cotar auto de pessoa jurídica.** O multicálculo pelo MCP é só pessoa física.
- **Ver cotação de auto de colega.** `cotacao_auto_list_auto_quotes` só alcança as do próprio usuário.
- **Credencial de seguradora, captcha e modelo de cobertura de auto.** Só na tela.
- **Conectar ou migrar número de WhatsApp.** Só na tela, assim como as equipes de uma instância.
- **Aprovar template na Meta.** É com a Meta. `koterzap_configuracao_save_message_template` cria resposta rápida, não template.
- **Simular chatbot com contato real.** `koterzap_configuracao_simulate_chatbot` só roda simulação isolada. `koterzap_configuracao_import_chatbot` só cria, não sobrescreve.
- **Fila de integração e regiões por DDD.** Só na tela. O transbordo de equipe tem ferramenta: `crm_config_save_team` com `queueOverflow`.
- **Mexer no catálogo global** (operadoras, tabelas de preço, produtos). É da operação do Koter.

---

## Três pacotes sem sobreposição

**O risco:** quando a IA conclui um login novo no Koter, o Koter revoga na hora as outras conexões ativas da mesma pessoa que têm o mesmo `client_id` (a identidade da IA no OAuth) e pelo menos uma área concedida em comum com a nova. O sintoma é 401 numa conexão que funcionava. `crm` e `gestao` separados convivem. `crm` e `crm,crm-config` não: a mais nova derruba a outra.

- **Conta a área concedida**, a que ficou marcada no consentimento e que o cargo permitiu, não o `?toolsets=` da URL. As duas só coincidem quando a tela de autorização respeitou o filtro da URL.
- **O `client_id` decide o alcance.** Endereço `https://` (documento de metadados, o mesmo para toda instalação daquela IA): só cai a conexão da mesma corretora. Cliente registrado no Koter (cada registro gera um novo): cai a do mesmo registro em qualquer corretora.
- **Só o login novo revoga.** A renovação automática da conexão não derruba ninguém.

**Trate todos os conectores da mesma IA como se tivessem o mesmo `client_id`**: a IA pode reaproveitar o mesmo registro entre conectores.

Onde a IA não dá recorte por agente, use estes três pacotes. Nenhuma área se repete:

| Pacote | `?toolsets=` | Tools | Queda sobre 266 |
|---|---|---:|---:|
| **Venda** | `crm,crm-config,cotacao-auto` | 37 | −86% |
| **Dinheiro** | `gestao,gestao-config,gestao-contratos,gestao-comissao,gestao-financeiro` | 134 | −50% |
| **Operação** | `crm-automation,gestao-automacao,koterzap-configuracao,koterzap-atendimento` | 60 | −77% |

```
VENDA     https://api.koter.app/mcp-user/koter?toolsets=crm,crm-config,cotacao-auto
DINHEIRO  https://api.koter.app/mcp-user/koter?toolsets=gestao,gestao-config,gestao-contratos,gestao-comissao,gestao-financeiro
OPERAÇÃO  https://api.koter.app/mcp-user/koter?toolsets=crm-automation,gestao-automacao,koterzap-configuracao,koterzap-atendimento
```

- Quem não tem o módulo, ou não precisa dele, tira o toolset da URL. Nunca deixe na URL um toolset que a conexão não concede: dá 400.
- Dentro da IA, deixe ligado só o pacote da conversa, e "Precisa de aprovação" na escrita.
- `admin-usuarios`, `admin-cargos` e `importacao` ficam fora dos três de propósito: são de implantação, não de rotina. Uma conexão só com eles não encosta em nenhum pacote.
- `formularios` também fica fora dos três. Quem cuida dos formulários de captura acrescenta a área ao pacote Venda (`?toolsets=crm,crm-config,cotacao-auto,formularios`, 43 tools) e marca `formularios` no consentimento. Os pacotes continuam sem área repetida.
- **A conexão inteira encosta em tudo.** No mesmo cliente de IA, criar uma conexão inteira depois dos pacotes pode derrubá-los, e criar um pacote depois dela pode derrubá-la. A que vem com o plugin no Claude e no Claude Code é inteira: quem usar os pacotes ali deixa a do plugin desligada.
- **Claude Free: uma conexão só.** Escolha o pacote do módulo principal, sem `all`.

**Quem trabalha com dinheiro precisa de `gestao-contratos`.** O contrato só nasce por `gestao_contratos_save_contract`: sem esse toolset não há implantação, e sem implantação não há comissão.

---

## O recorte por especialista

Recorte por especialista de verdade só onde a IA faz essa separação: Claude Code por agente, tarefa agendada, n8n ou Make por nó. No resto, use os três pacotes.

| Especialista | `?toolsets=` | Tools | Queda sobre 266 |
|---|---|---:|---:|
| Secretário Geral | `crm` | 11 | −96% |
| Multicálculo auto | `cotacao-auto` | 11 | −96% |
| Multicálculo com CRM | `cotacao-auto,crm` | 22 | −92% |
| Atendimento | `koterzap-configuracao,koterzap-atendimento` | 28 | −89% |
| CRM | `crm-config,crm-automation,gestao-automacao` | 47 | −82% |
| Cadastro | `gestao,gestao-config,gestao-contratos` | 40 | −85% |
| Vendas | `crm,crm-config,gestao-automacao,gestao` | 53 | −80% |
| Financeiro | `gestao-comissao,gestao-financeiro,gestao-config,gestao-contratos` | 123 | −54% |
| Migração | `importacao` | 7 | −97% |
| Módulo Gestão inteiro | os seis `gestao*` | 150 | −44% |

**Estes recortes se tocam**: Secretário e Vendas dividem `crm`, Cadastro e Financeiro dividem `gestao-config` e `gestao-contratos`. Eles só convivem onde cada agente tem a própria conexão com um cliente próprio. Na dúvida, use os pacotes. "Seis links, um por especialista" não é oferta para todo mundo: cada URL é um login, e isso assusta quem nunca fez.

Comece por **um** especialista e prove um fluxo antes de montar time. O catálogo é cardápio, não instalação.

Por que certos recortes atravessam módulo:

- **Vendas** leva `gestao-automacao` porque a régua de renovação é automação do Gestão (`DATE_FIELD`, fonte `CONTRACT`, campo `endsAt`), e leva `gestao` porque ligar o lead ganho à proposta é `gestao_set_proposal_links` com `leads`. Para implantar, precisa de `gestao-contratos`, e aí sobe para 65.
- **CRM** leva `gestao-automacao` porque as automações do CRM e do Gestão são dele. Se for cuidar dos formulários de captura (`koter-formularios`), acrescente `formularios`: 53 em vez de 47.
- **Atendimento** não precisa de `crm-config` para o bot desviar pelo funil: `koterzap_configuracao_fetch_koterzap_config_context` já traz `teams`, `users`, `leadStatuses`, `tags` e `customFields`, que `HANDOFF`, `CREATE_LEAD` e as condições usam.
- **Financeiro** é o que menos encolhe. Se ficar grande na prática, parta em dois: `gestao-comissao,gestao-config,gestao-contratos` (96) para comissão e repasse, `gestao-financeiro` (27) para caixa e conciliação.
- **Migração** com `importacao` sozinha deve bastar: as leituras de referência vêm embutidas em `importacao_get_import_schema`. Se faltar alguma, acrescente a área que ela pede.

Sobre relógio: `crm-automation` tem gatilho agendado (`SCHEDULED`), que com `dateField` roda em cada lead ou contato no dia de uma data dele (inclusive campo `DATE`), e espera (`WAIT`) com janela e ritmo. A data do contrato, como o fim de vigência, só o Gestão lê (`DATE_FIELD`).

---

## Módulo AUTO

Quem pode cotar: a corretora com `AUTO` em `modules`, e a pessoa com a permissão `app:auto-quote:create` e licença.

- Em assinatura modular, sem o módulo, a tela e o consentimento podem oferecer a área e a conexão derrubá-la depois. A prova é a leitura: `cotacao-auto` em `list_toolsets`, com `toolsCount` acima de zero.
- O primeiro passo é sempre `cotacao_auto_get_auto_insurer_availability`, que mostra por seguradora `READY`, `MISSING`, `SUSPENDED` ou `NOT_LINKED`.
- O restante mora na skill `koter-multicalculo-auto`.

Se o multicálculo já está em produção não foi consultado: o código está pronto, a produção não foi olhada.

---

## Como isso amarra com o plugin

**1 · O `companyId` não depende de `admin-cargos`.** O handshake mora ali, mas estas leituras também trazem a corretora:

| Leitura | Onde vem o `companyId` |
|---|---|
| `crm_config_fetch_crm_config_context` | em `tags[].companyId` e em `customFieldCategories[].companyId` |
| `gestao_list_proposals` | em `proposals[].company`, com `{ id, name }`, o que traz o **nome da corretora** junto |

O que se perde sem o handshake são `modules`, `permissions`, `licensed` e `crmAccess`. Num especialista, isso a `/introducao` já descobriu e deixou na ficha. Ferramentas do Gestão acrescentam o nome ao lado do id (`insuranceCompanyName`, por exemplo): é só leitura, nunca reenvie numa escrita.

**2 · A `/introducao` roda com a conexão inteira.** O passo 0 usa `admin-cargos` e o diagnóstico atravessa todos os módulos na mesma rodada. A separação não é como ela roda, é o que ela entrega. Quem não alcança `admin-cargos` usa o plano B do `handshake.md`.

**3 · Quatro skills pedem toolsets fora dos pacotes ou específicos:**

| Skill | Precisa de |
|---|---|
| `koter-gestao-vendedores` | `admin-usuarios`, para `admin_usuarios_list_company_people` (`include: ["hierarchy"]` só junto de `ids`), `admin_usuarios_list_users`, `admin_usuarios_save_company_person`, `admin_usuarios_merge_company_people` e `admin_usuarios_send_invitations`. É ato de implantação |
| `koter-importacao` | `importacao` |
| `koter-formularios` | `formularios` |
| `koter-multicalculo-auto` | `cotacao-auto` |

**4 · Skill de dinheiro confere antes.** Toda skill que mexe em comissão chama `list_toolsets` no início. Faltando `gestao-contratos`, ela para e pede reconexão.

---

## Como oferecer isso ao corretor

Nunca como configuração de MCP. Ele não quer saber o que é toolset. Fale pela consequência:

> "Dá para separar o Koter em três conexões: venda, dinheiro e operação. Em cada conversa você deixa ligada só a do assunto. A IA escolhe melhor, e a de venda não consegue mexer na sua comissão sem querer. Te passo os três links prontos."

E a trava é metade do valor: **a conexão de venda não mexe no financeiro nem quando erra.** O campo "O que eu NÃO posso" da ficha do especialista deixa de ser promessa e passa a ser o que a conexão permite. Só não diga que ela não grava: grava, dentro do assunto dela. Quem segura a escrita é "Precisa de aprovação".

A entrega é da `koter-especialistas`, que monta a ficha e a conexão juntas.
