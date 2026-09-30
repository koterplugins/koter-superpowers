# A conexão por módulo — uma URL por especialista

A conexão completa do Koter entrega **180 ferramentas**. Nenhuma IA escolhe bem entre 180, e o corretor que liga tudo num assistente só paga isso em toda conversa: lista maior, escolha pior, e um agente de comissão com poder de apagar origem do CRM.

O MCP do Koter aceita **filtro por toolset na própria URL**, e é isso que transforma um assistente genérico num time de especialistas com tesoura.

```
https://api.koter.app/mcp-user/koter?toolsets=<lista separada por vírgula>
```

---

## Os 12 toolsets, medidos

Medido em 30/09/2026 com `list_toolsets`, que é a fonte — **não decore estes números, releia**, porque eles mudam: foram 356 em 22/09, 265 em 28/09 e 180 em 30/09. Em 28/09 o Gestão encolheu pela metade; em 30/09 foi a vez de CRM, KoterZap e Administração, pelo mesmo desenho: criar e editar viraram um `save_*` só (sem id cria, com id edita), os `get_*` viraram `list_*` com `ids`, as listas de apoio viraram um `fetch_*_context` com `include`, e as exclusões viraram um `delete_*_records` com `kind`.

| Módulo | Toolset | Tools | O que tem dentro |
|---|---|---:|---|
| CRM | `crm` | 11 | lead, contato, tarefa, nota, venda e perda |
| | `crm-config` | 11 | equipe, funil, origem, tag, motivo de perda, campo personalizado, interesse |
| | `crm-automation` | 8 | automação do CRM |
| KoterZap | `koterzap-configuracao` | 22 | chatbot, fluxo, base de conhecimento, inbox, leitura de instância |
| | `koterzap-atendimento` | 9 | conversa, mensagem, anexo, transcrição — **não envia** |
| Gestão | `gestao` | 12 | proposta, beneficiário, nota, vínculo com lead e contato, catálogo do ramo |
| | `gestao-config` | 14 | status, entidade, vendedor, campo personalizado e formulário de proposta |
| | `gestao-comissao` | 36 | grade, tabela, parcela, recebível, lote de repasse, empréstimo, campanha |
| | `gestao-automacao` | 8 | automação do Gestão — **é ela que tem relógio** |
| | `gestao-financeiro` | 27 | conta, lançamento, plano de contas, extrato, conciliação, crítica, relatórios (caixa, DRE, setor) |
| Administração | `admin-usuarios` | 16 | usuário, convite, pessoa, hierarquia, informativo, seguradoras ativas |
| | `admin-cargos` | 6 | cargo, permissão, e o **handshake** |
| | **total** | **180** | |

`gestao-comissao`, com 36, é agora o maior toolset do MCP inteiro — e é por isso que o especialista financeiro voltou a ser o que menos encolhe.

---

## Os dois achados que decidem o desenho

**1 · A regra 6 sobrevive sem o toolset de administração.** Reconferir o `companyId` antes de cada rodada de escrita é a regra que não pode cair, e a leitura natural para isso é o handshake — que mora em `admin-cargos`. Medido em 22/09/2026 e ainda válido pelo schema de 30/09: **não é a única**.

| Leitura | Onde vem o `companyId` |
|---|---|
| `crm_config_fetch_crm_config_context` | em `tags[].companyId` e em `customFieldCategories[].companyId` |
| `gestao_list_proposals` | em `proposals[].company`, com `{ id, name }` — traz o **nome da corretora** junto |

Então um especialista de CRM ou de Gestão reconfere a corretora com uma tool do próprio módulo, e a URL dele não precisa de `admin-cargos`. O que ele perde sem o handshake são `modules`, `permissions`, `licensed` e `crmAccess` — e isso ele não precisa descobrir, porque **a `/introducao` já descobriu e escreveu na ficha dele**.

**2 · A `/introducao` é a exceção, e não dá para recortá-la.** Ela precisa da conexão completa por dois motivos que não têm volta:

- O passo 0 é `admin_cargos_fetch_admin_roles_context` com `include: ["myPermissions"]`, que só existe em `admin-cargos`. Sem handshake não há módulo, não há permissão, e a skill manda parar.
- O ato 0 diagnostica **os três módulos na mesma rodada**, de propósito — é essa simultaneidade que faz a tarefa de tela do KoterZap sair no começo em vez de no fim.

Ou seja: **a separação por módulo não é como a `/introducao` roda, é o que ela entrega.** Ela roda inteira uma vez, e uma das coisas que deixa montadas é o recorte de conexão de cada especialista.

**3 · `koter-gestao-vendedores` é a única skill que precisa de `admin-usuarios`**, para `list_company_people` (com `include: ["hierarchy"]` no lugar da antiga `get_person_hierarchy`), `list_users`, `save_company_person`, `merge_company_people` e `send_invitations`. Cadastrar vendedor é ato de implantação, não de rotina: deixe na conexão completa e o especialista financeiro trabalha sobre os vendedores que já existem.

---

## O recorte de cada especialista

| Especialista | `?toolsets=` | Tools | Quanto cai |
|---|---|---:|---|
| **Secretário Geral** | `crm` | 11 | −94% |
| **Atendimento** | `koterzap-configuracao,koterzap-atendimento` | 31 | −83% |
| **Cadastro** | `gestao,gestao-config` | 26 | −86% |
| **CRM** | `crm-config,crm-automation,gestao-automacao` | 27 | −85% |
| **Vendas** | `crm,crm-config,gestao-automacao,gestao` | 42 | −77% |
| **Financeiro** | `gestao-comissao,gestao-financeiro,gestao-config` | 77 | −57% |
| **Implantação** (`/introducao`) | *(sem filtro — a conexão completa)* | 180 | — |

E as três URLs prontas, para o corretor que prefere uma por módulo em vez de uma por especialista:

```
CRM       https://api.koter.app/mcp-user/koter?toolsets=crm,crm-config,crm-automation
KOTERZAP  https://api.koter.app/mcp-user/koter?toolsets=koterzap-configuracao,koterzap-atendimento
GESTÃO    https://api.koter.app/mcp-user/koter?toolsets=gestao,gestao-config,gestao-comissao,gestao-automacao,gestao-financeiro
```

### O que a tabela mostra e não é óbvio

**Três especialistas atravessam módulo**, e é por isso que o recorte por especialista rende mais que o recorte por módulo:

- **Vendas** leva `gestao-automacao` porque a régua de renovação é automação **do Gestão** (gatilho `DATE_FIELD` sobre `coverageStart`), e leva `gestao` porque ligar o lead ganho à proposta é `gestao_set_proposal_links` com `leads`.
- **CRM** leva `gestao-automacao` pelo mesmo motivo: os dois motores de automação são dele.
- **Atendimento** pode levar `crm-config` se o bot for desviar pelo funil (`HANDOFF` e `CREATE_LEAD` usam equipe e etapa) — 42 em vez de 31. Só acrescente quando o fluxo realmente ler o CRM.

**O financeiro voltou a ser o que menos ganha.** Ele caiu de 150 para 77 tools em 28/09 e parou aí, enquanto CRM e KoterZap encolheram de novo em 30/09. Se ficar grande na prática, a segunda alavanca é a de sessão (abaixo), ou parta em dois — `gestao-comissao,gestao-config` (50) para comissão e repasse, `gestao-financeiro` (27) para caixa e conciliação.

---

## A segunda alavanca: ligar e desligar na sessão

Nem toda IA deixa o corretor ter seis conexões. Para essas, a mesma conexão completa se afina por sessão, sem URL nova:

```
list_toolsets                      → o que existe e o que está ligado
disable_toolset(<key>)             → tira desta sessão
enable_toolset(<key>)              → devolve
```

**Prefira sempre a URL.** O filtro da URL é configuração do corretor, vale para todas as conversas daquele especialista e não depende de a IA lembrar de chamar nada. O `disable_toolset` vale só para a sessão em que foi chamado, e uma sessão nova volta com tudo ligado.

O caso em que a alavanca de sessão é a certa: hospedeiro de conexão única, e o corretor acabou de dizer que a conversa é sobre comissão.

---

## Como oferecer isso ao corretor

Nunca como configuração de MCP — ele não quer saber o que é toolset. Como consequência:

> "Dá para dar a cada especialista só as ferramentas do assunto dele. O de atendimento passa de 180 para 31, e de quebra ele deixa de conseguir mexer no seu funil sem querer. São seis links, um por especialista — te passo prontos."

E a trava é metade do valor, não um detalhe: **o especialista financeiro com a URL do financeiro não apaga origem do CRM nem quando erra.** O campo 4 da ficha ("o que eu NÃO posso") deixa de ser promessa e passa a ser o que a conexão permite.

A entrega inteira é da `koter-especialistas`, que monta a ficha e a URL juntas.
