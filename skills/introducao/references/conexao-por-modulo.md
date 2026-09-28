# A conexão por módulo — uma URL por especialista

A conexão completa do Koter entrega **265 ferramentas**. Nenhuma IA escolhe bem entre 265, e o corretor que liga tudo num assistente só paga isso em toda conversa: lista maior, escolha pior, e um agente de comissão com poder de apagar origem do CRM.

O MCP do Koter aceita **filtro por toolset na própria URL**, e é isso que transforma um assistente genérico num time de especialistas com tesoura.

```
https://api.koter.app/mcp-user/koter?toolsets=<lista separada por vírgula>
```

---

## Os 12 toolsets, medidos

Medido em 28/09/2026 com `list_toolsets`, que é a fonte — **não decore estes números, releia**, porque eles mudam. Na última rodada o Gestão encolheu pela metade: criar e editar viraram um `save_*` só (sem id cria, com id edita), os `get_*` viraram `list_*` com `ids`, as listas de apoio viraram um `fetch_*_context` com `include`, e ações irmãs viraram uma tool com `mode` ou `kind`. CRM, KoterZap e Administração ficaram como estavam.

| Módulo | Toolset | Tools | O que tem dentro |
|---|---|---:|---|
| CRM | `crm` | 25 | lead, contato, tarefa, venda e perda |
| | `crm-config` | 37 | equipe, funil, origem, tag, motivo de perda, campo personalizado |
| | `crm-automation` | 14 | automação do CRM |
| KoterZap | `koterzap-configuracao` | 42 | chatbot, fluxo, base de conhecimento, inbox, leitura de instância |
| | `koterzap-atendimento` | 9 | conversa, mensagem, anexo, transcrição — **não envia** |
| Gestão | `gestao` | 12 | proposta, beneficiário, nota, vínculo com lead e contato, catálogo do ramo |
| | `gestao-config` | 14 | status, entidade, vendedor, campo personalizado e formulário de proposta |
| | `gestao-comissao` | 36 | grade, tabela, parcela, recebível, lote de repasse, empréstimo, campanha |
| | `gestao-automacao` | 8 | automação do Gestão — **é ela que tem relógio** |
| | `gestao-financeiro` | 27 | conta, lançamento, plano de contas, extrato, conciliação, crítica, relatórios (caixa, DRE, setor) |
| Administração | `admin-usuarios` | 31 | usuário, convite, hierarquia, acesso |
| | `admin-cargos` | 10 | cargo, permissão, e o **handshake** |
| | **total** | **265** | |

`gestao-comissao`, com 36, continua o maior do Gestão, mas caiu à metade — e com ele o especialista financeiro deixou de ser o caso difícil.

---

## Os dois achados que decidem o desenho

**1 · A regra 6 sobrevive sem o toolset de administração.** Reconferir o `companyId` antes de cada rodada de escrita é a regra que não pode cair, e a leitura natural para isso é o handshake — que mora em `admin-cargos`. Medido em 28/09/2026: **não é a única**.

| Leitura | Onde vem o `companyId` |
|---|---|
| `crm_config_fetch_crm_config_context` | em `tags[].companyId` e em `customFieldCategories[].companyId` |
| `gestao_list_proposals` | em `proposals[].company`, com `{ id, name }` — traz o **nome da corretora** junto |

Então um especialista de CRM ou de Gestão reconfere a corretora com uma tool do próprio módulo, e a URL dele não precisa de `admin-cargos`. O que ele perde sem o handshake são `modules`, `permissions`, `licensed` e `crmAccess` — e isso ele não precisa descobrir, porque **a `/introducao` já descobriu e escreveu na ficha dele**.

**2 · A `/introducao` é a exceção, e não dá para recortá-la.** Ela precisa da conexão completa por dois motivos que não têm volta:

- O passo 0 é `admin_cargos_get_my_effective_permissions`, que só existe em `admin-cargos`. Sem handshake não há módulo, não há permissão, e a skill manda parar.
- O ato 0 diagnostica **os três módulos na mesma rodada**, de propósito — é essa simultaneidade que faz a tarefa de tela do KoterZap sair no começo em vez de no fim.

Ou seja: **a separação por módulo não é como a `/introducao` roda, é o que ela entrega.** Ela roda inteira uma vez, e uma das coisas que deixa montadas é o recorte de conexão de cada especialista.

**3 · `koter-gestao-vendedores` é a única skill que precisa de `admin-usuarios`**, para `list_company_people`, `list_users`, `get_person_hierarchy`, `merge_company_people` e `send_invitations`. Cadastrar vendedor é ato de implantação, não de rotina: deixe na conexão completa e o especialista financeiro trabalha sobre os vendedores que já existem.

---

## O recorte de cada especialista

| Especialista | `?toolsets=` | Tools | Quanto cai |
|---|---|---:|---|
| **Secretário Geral** | `crm` | 25 | −91% |
| **Atendimento** | `koterzap-configuracao,koterzap-atendimento` | 51 | −81% |
| **Cadastro** | `gestao,gestao-config` | 26 | −90% |
| **CRM** | `crm-config,crm-automation,gestao-automacao` | 59 | −78% |
| **Vendas** | `crm,crm-config,gestao-automacao,gestao` | 82 | −69% |
| **Financeiro** | `gestao-comissao,gestao-financeiro,gestao-config` | 77 | −71% |
| **Implantação** (`/introducao`) | *(sem filtro — a conexão completa)* | 265 | — |

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
- **Atendimento** pode levar `crm-config` se o bot for desviar pelo funil (`HANDOFF` e `CREATE_LEAD` usam equipe e etapa) — 88 em vez de 51. Só acrescente quando o fluxo realmente ler o CRM.

**O financeiro deixou de ser o que menos ganha.** Com o Gestão enxuto, ele caiu de 150 para 77 tools, e quem menos ganha agora é Vendas, porque atravessa dois módulos. Se ainda ficar grande na prática, a segunda alavanca é a de sessão (abaixo), ou parta em dois — `gestao-comissao,gestao-config` (50) para comissão e repasse, `gestao-financeiro` (27) para caixa e conciliação.

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

> "Dá para dar a cada especialista só as ferramentas do assunto dele. O de atendimento passa de 265 para 51, e de quebra ele deixa de conseguir mexer no seu funil sem querer. São seis links, um por especialista — te passo prontos."

E a trava é metade do valor, não um detalhe: **o especialista financeiro com a URL do financeiro não apaga origem do CRM nem quando erra.** O campo 4 da ficha ("o que eu NÃO posso") deixa de ser promessa e passa a ser o que a conexão permite.

A entrega inteira é da `koter-especialistas`, que monta a ficha e a URL juntas.
