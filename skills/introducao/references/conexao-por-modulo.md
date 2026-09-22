# A conexão por módulo — uma URL por especialista

A conexão completa do Koter entrega **356 ferramentas**. Nenhuma IA escolhe bem entre 356, e o corretor que liga tudo num assistente só paga isso em toda conversa: lista maior, escolha pior, e um agente de comissão com poder de apagar origem do CRM.

O MCP do Koter aceita **filtro por toolset na própria URL**, e é isso que transforma um assistente genérico num time de especialistas com tesoura.

```
https://api.koter.app/mcp-user/koter?toolsets=<lista separada por vírgula>
```

---

## Os 12 toolsets, medidos

Medido em 22/09/2026 com `list_toolsets`, que é a fonte — **não decore estes números, releia**, porque eles mudam (em 21/09/2026 saíram 15 tools de ramo, seguradora e categoria, e `gestao-config` encolheu de 47 para 32).

| Módulo | Toolset | Tools | O que tem dentro |
|---|---|---:|---|
| CRM | `crm` | 25 | lead, contato, tarefa, venda e perda |
| | `crm-config` | 37 | equipe, funil, origem, tag, motivo de perda, campo personalizado |
| | `crm-automation` | 14 | automação do CRM |
| KoterZap | `koterzap-configuracao` | 42 | chatbot, fluxo, base de conhecimento, inbox, leitura de instância |
| | `koterzap-atendimento` | 9 | conversa, mensagem, anexo, transcrição — **não envia** |
| Gestão | `gestao` | 23 | proposta, beneficiário, catálogo de seguradora e modalidade |
| | `gestao-config` | 32 | status, entidade, vendedor, campo personalizado de proposta |
| | `gestao-comissao` | 72 | grade, tabela, parcela, recebível, lote de repasse, empréstimo, campanha |
| | `gestao-automacao` | 15 | automação do Gestão — **é ela que tem relógio** |
| | `gestao-financeiro` | 46 | conta, lançamento, plano de contas, extrato, conciliação, DRE |
| Administração | `admin-usuarios` | 31 | usuário, convite, hierarquia, acesso |
| | `admin-cargos` | 10 | cargo, permissão, e o **handshake** |
| | **total** | **356** | |

`gestao-comissao`, com 72, é o maior toolset sozinho — é ele que faz o especialista financeiro continuar grande por mais que se recorte.

---

## Os dois achados que decidem o desenho

**1 · A regra 6 sobrevive sem o toolset de administração.** Reconferir o `companyId` antes de cada rodada de escrita é a regra que não pode cair, e a leitura natural para isso é o handshake — que mora em `admin-cargos`. Medido em 22/09/2026: **não é a única**.

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
| **Secretário Geral** | `crm` | 25 | −93% |
| **Atendimento** | `koterzap-configuracao,koterzap-atendimento` | 51 | −86% |
| **Cadastro** | `gestao,gestao-config` | 55 | −85% |
| **CRM** | `crm-config,crm-automation,gestao-automacao` | 66 | −81% |
| **Vendas** | `crm,crm-config,gestao-automacao,gestao` | 100 | −72% |
| **Financeiro** | `gestao-comissao,gestao-financeiro,gestao-config` | 150 | −58% |
| **Implantação** (`/introducao`) | *(sem filtro — a conexão completa)* | 356 | — |

E as três URLs prontas, para o corretor que prefere uma por módulo em vez de uma por especialista:

```
CRM       https://api.koter.app/mcp-user/koter?toolsets=crm,crm-config,crm-automation
KOTERZAP  https://api.koter.app/mcp-user/koter?toolsets=koterzap-configuracao,koterzap-atendimento
GESTÃO    https://api.koter.app/mcp-user/koter?toolsets=gestao,gestao-config,gestao-comissao,gestao-automacao,gestao-financeiro
```

### O que a tabela mostra e não é óbvio

**Três especialistas atravessam módulo**, e é por isso que o recorte por especialista rende mais que o recorte por módulo:

- **Vendas** leva `gestao-automacao` porque a régua de renovação é automação **do Gestão** (gatilho `DATE_FIELD` sobre `coverageStart`), e leva `gestao` porque ligar o lead ganho à proposta é `gestao_set_proposal_leads`.
- **CRM** leva `gestao-automacao` pelo mesmo motivo: os dois motores de automação são dele.
- **Atendimento** pode levar `crm-config` se o bot for desviar pelo funil (`HANDOFF` e `CREATE_LEAD` usam equipe e etapa) — 88 em vez de 51. Só acrescente quando o fluxo realmente ler o CRM.

**O financeiro é o que menos ganha**, e dizer isso é mais honesto que fingir o contrário: `gestao-comissao` sozinho é 72 tools e o assunto dele é comissão. Se ficar grande demais na prática, a segunda alavanca é a de sessão (abaixo), ou parta em dois — `gestao-comissao,gestao-config` para comissão e repasse, `gestao-financeiro` para caixa e conciliação.

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

> "Dá para dar a cada especialista só as ferramentas do assunto dele. O de atendimento passa de 356 para 51, e de quebra ele deixa de conseguir mexer no seu funil sem querer. São seis links, um por especialista — te passo prontos."

E a trava é metade do valor, não um detalhe: **o especialista financeiro com a URL do financeiro não apaga origem do CRM nem quando erra.** O campo 4 da ficha ("o que eu NÃO posso") deixa de ser promessa e passa a ser o que a conexão permite.

A entrega inteira é da `koter-especialistas`, que monta a ficha e a URL juntas.
