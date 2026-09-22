---
name: koter-especialistas
description: Monta os agentes especialistas do Koter dentro da IA que o corretor usa — financeiro, cadastro, vendas, CRM, atendimento e secretário geral —, cada um já sabendo quais skills carrega, o que pode e o que não pode. Use quando pedirem para organizar agentes, criar especialistas, "montar meu time de IA", separar assuntos em agentes, ou quando o corretor perguntar como não ficar explicando tudo de novo a cada conversa.
---

# koter-especialistas

O plugin tem 22 skills. Ninguém opera 22 skills de cabeça — nem o corretor, nem a IA, que a cada conversa nova começa sem saber se o assunto é comissão ou lead.

Esta skill resolve isso **recortando** o plugin em poucos especialistas, cada um com um assunto, as skills daquele assunto e as travas daquele assunto. É a única skill do plugin que **não escreve nada no Koter**: ela escreve na IA.

**Ela termina com os especialistas existindo e conferidos** — arquivo relido, ou o corretor confirmando que colou. Nunca com uma lista de sugestões.

## 0 · Pré-requisitos

Duas leituras, nenhuma escrita:

```
admin_cargos_get_my_effective_permissions   → companyId, modules, permissions
```

É o que poda a lista: quem não tem `KOTERZAP` em `modules` não ganha especialista de atendimento, e quem não tem permissão de escrita em comissão ganha o financeiro **em modo leitura**, dito na ficha.

O segundo é o diagnóstico da `introducao` (passo 2), **se já tiver rodado**. Se não rodou, não force: esta skill funciona com o handshake sozinho, e o que ela perde é só a poda fina.

> ⚠️ **`permissions: ["all"]` é perfil master.** Pare, avise e não monte nada — um especialista de conta master escreve na corretora errada com a cara de quem está ajudando. A regra vale aqui como vale em todo o plugin.

## 1 · O que é um especialista, e o que não é

Um especialista é **um recorte do plugin com nome, escopo e trava**, materializado no formato que a IA hospedeira entender: um agente, um projeto, uma pasta ou um bloco de texto que o corretor cola.

Ele **não** é uma cópia do plugin com outro nome, e **não** é uma persona ("você é um consultor experiente e carismático"). O que faz um especialista funcionar são cinco linhas concretas — quais skills ele carrega, o que pode, o que não pode, o que é pré-requisito de tela e por onde ele começa a ler. Sem isso, seis agentes são seis conversas iguais em pastas diferentes.

**A trava é a parte que rende.** O especialista de vendas que não mexe no funil não quebra o funil às quintas; o financeiro que não cria lead não polui o CRM. É isso que o corretor ganha ao separar, e é por isso que o item "o que não pode" nunca sai da ficha.

## 2 · Detecte a capacidade do hospedeiro — não suponha

Nem toda IA cria agente. Algumas criam arquivo, outras criam projeto, outras não criam nada — e as três precisam terminar com o corretor tendo os especialistas na mão.

**A sonda é sua, não do corretor.** Ele não sabe responder "sua IA suporta subagentes?", e perguntar isso é jogar o problema no colo dele. Olhe as suas próprias ferramentas e o disco, nesta ordem — o procedimento inteiro, com os caminhos e os formatos, está em `references/hospedeiros.md`:

| Sonda | O que ela responde |
|---|---|
| Você tem ferramenta de **escrever arquivo**? | separa o caminho A dos outros dois |
| Existe pasta de convenção de agente? (`.claude/agents/`, `.cursor/rules/`, `.github/chatmodes/`, `AGENTS.md`) | diz **em que formato** escrever |
| Nenhuma das duas | o hospedeiro tem Projetos/GPTs/Gems? Isso sim **se pergunta**, em uma escolha de 3 opções |

E daí saem os três caminhos:

| Caminho | Quando | O que o corretor recebe | Como se confere |
|---|---|---|---|
| **A · Agente de arquivo** | você escreve arquivo e existe convenção | um arquivo por especialista, no formato nativo | **releia o arquivo** e mostre o caminho |
| **B · Projeto na IA** | o hospedeiro tem Projeto/GPT/Gem, você não escreve nele | o texto pronto de cada especialista, **um por vez**, com onde colar | ele confirma que colou; você pergunta um por um |
| **C · Nada disso** | chat comum, sem projeto e sem arquivo | o texto de cada especialista como bloco copiável, e **você passa a vestir um por vez** nesta mesma conversa | ele guarda onde quiser; a conversa segue com o especialista ativo dito em voz alta |

**O caminho C não é o prêmio de consolação.** Um corretor no celular, num chat comum, com o texto do especialista financeiro colado no começo da conversa, tem exatamente o que o caminho A entrega — só não tem persistência. Diga isso assim, sem pedir desculpa:

> "Sua IA não guarda agente, então vou te dar o texto de cada especialista. Cola o do financeiro quando for falar de comissão e a conversa já começa sabendo tudo. Guarda os seis nas suas notas: é um copiar e colar por assunto."

**Nunca prometa o caminho A sem ter escrito o arquivo.** Se a escrita falhar, caia para B ou C na mesma resposta, sem perguntar — o corretor não tem como decidir isso melhor que você.

## 3 · Escolha os especialistas — pelo diagnóstico, não pelo catálogo

`references/catalogo.md` tem **sete** fichas prontas. Ninguém recebe as sete. A poda é automática e sai do passo 0:

| Regra | Efeito |
|---|---|
| `porte: solo` | **Vendas e CRM viram um só** (`Especialista de Vendas`, carregando também a estrutura). Corretor sozinho não tem quem quebre o funil dele |
| `KOTERZAP` fora de `modules` | sem especialista de atendimento — e diga por quê |
| `GESTAO` fora de `modules` | sem financeiro e sem cadastro; sobra CRM e secretário |
| sem permissão de escrita em comissão | o financeiro nasce **em modo leitura**: lê DRE, lote e grade, não publica tabela nem paga lote |
| Gestão e CRM ainda vazios | **o de implantação entra e é o primeiro**; numa conta já montada ele não existe |
| o corretor pediu um que não está no catálogo | monte com o **mesmo molde** (seção 4). O catálogo é o começo, não o teto |

O resultado típico de uma corretora com vendedores e os três módulos são **cinco**: cadastro, financeiro, vendas, CRM e atendimento — mais o secretário, que é de outra natureza.

**Mostre a lista antes de criar**, em uma frase por especialista, e deixe ele cortar:

> "Pelo que li da sua conta, cinco fazem sentido: cadastro (proposta e beneficiário), financeiro (comissão, repasse, caixa), vendas (lead e renovação), CRM (funil, origem, automação) e atendimento (WhatsApp e bot). O secretário geral eu explico à parte, porque ele não é do Koter. Corto algum?"

## 4 · O molde da ficha — nove campos, nenhum opcional

Todo especialista nasce com os nove. Faltando um, o agente improvisa justamente onde dói: escreve sem reconferir a corretora, promete mensagem sem Cloud API, apaga origem com lead dentro.

```
1 · Nome e quando me chamar        uma linha, na língua do corretor
2 · Skills que eu carrego          nomes literais das skills do plugin
3 · O que eu posso                 os verbos, por objeto do Koter
4 · O que eu NÃO posso             e para quem eu mando (seção 5)
5 · Pré-requisito de tela          o que só o corretor faz, e o que trava
6 · As armadilhas do meu assunto   3 a 5, literais, com o conserto junto
7 · Por onde eu começo             a primeira leitura, sempre leitura
8 · As regras que eu herdo         o núcleo comum, copiado inteiro
9 · A conexão que eu uso           a URL do Koter com os toolsets do meu assunto
```

**O campo 8 é copiado igual em todos**, e é ele que faz seis agentes soarem como um produto:

```
- Reconfiro o companyId antes de cada rodada de escrita, não só no começo.
- Detecto antes de perguntar: o que o Koter responde, eu não pergunto.
- Toda pergunta minha é uma escolha de 2 a 4 opções, com consequência e recomendação.
- Não apago nada sem o corretor mandar, por escrito, na mesma conversa.
- Termino em configuração aplicada e relida, nunca em explicação de tela.
- Fora do meu assunto eu encaminho, não improviso.
```

A última linha é a que só existe aqui, e é o que separa um time de especialistas de seis cópias do mesmo assistente.

**O campo 9 é o que faz o campo 4 valer.** Sem ele, "eu não mexo no seu funil" é uma promessa de texto, que a IA quebra na primeira vez que se confundir. Com ele, a tool nem está na lista. Ver a seção 4b.

**O campo 6 não se inventa.** Cada ficha do catálogo já traz as armadilhas do assunto dela, tiradas de execução real na corretora de demonstração — `create_origin` e caixa alta, `LEAD_OWNER` sem dono, `AGENCIAMENTO` × `ANGARIACAO`, a base que indexa depois. Se você montar um especialista novo, vá buscar as dele nas `SKILL.md` das skills que ele carrega; ficha sem armadilha é ficha que ainda não foi escrita.

## 4b · O campo 9 na prática

O campo 9 é uma linha na ficha e uma URL que o corretor cola na IA dele:

```
9 · A conexão que eu uso
https://api.koter.app/mcp-user/koter?toolsets=crm-config,crm-automation,gestao-automacao
Se a sua IA só aceita uma conexão do Koter, use a completa e me diga — eu desligo
o resto da lista com disable_toolset assim que a conversa começa.
```

**A cada ficha, a sua.** A conexão completa tem **356 tools**, medidas em 22/09/2026:

| Especialista | `?toolsets=` | Tools |
|---|---|---:|
| Secretário Geral | `crm` | 25 |
| Atendimento | `koterzap-configuracao,koterzap-atendimento` | 51 |
| Cadastro | `gestao,gestao-config` | 55 |
| CRM | `crm-config,crm-automation,gestao-automacao` | 66 |
| Vendas | `crm,crm-config,gestao-automacao,gestao` | 100 |
| Financeiro | `gestao-comissao,gestao-financeiro,gestao-config` | 150 |
| Implantação | *(a conexão completa, sem filtro)* | 356 |

Três coisas que essa tabela ensina e que não são óbvias:

- **A implantação não se recorta.** A `/introducao` precisa do handshake (`admin-cargos`) e diagnostica os três módulos na mesma rodada. É a única que fica com tudo.
- **Três especialistas atravessam módulo**, e é por isso que o recorte por especialista rende mais que "um link por módulo": Vendas e CRM levam `gestao-automacao`, porque o motor com relógio — o gatilho por data que arma a renovação — é do Gestão, e Vendas leva `gestao` porque ligar o lead ganho à proposta é `gestao_set_proposal_leads`.
- **O financeiro é o que menos ganha**, e diga isso em vez de fingir: `gestao-comissao` sozinho é 72 tools. Se incomodar, parta em dois — `gestao-comissao,gestao-config` para comissão e repasse, `gestao-financeiro` para caixa.

**O que fica de fora de todos:** `admin-usuarios` (31 tools — convidar, remover, trocar cargo, mesclar pessoa). Só `koter-gestao-vendedores` precisa dele, para cadastrar e convidar vendedor, e isso é ato de implantação, não de rotina. Fica na conexão completa; o Financeiro trabalha sobre os vendedores que já existem e encaminha o resto.

A íntegra do raciocínio em `../introducao/references/conexao-por-modulo.md`.

Se você **não montou a ficha pela `/introducao`**, não invente a URL: chame `list_toolsets` na conexão que estiver ligada e monte a partir do que ela devolver. Os números mudam — em 21/09/2026 saíram 15 tools e `gestao-config` caiu de 47 para 32.

## 5 · O encaminhamento — a tabela que todo especialista carrega

Sem ela, o corretor bate na trava e fica parado. Com ela, a trava vira uma frase de uma linha. Cada ficha leva a sua, no campo 4:

| Se ele pedir | Quem resolve |
|---|---|
| cadastrar proposta, beneficiário, campo de proposta, status | **Cadastro** |
| tabela de comissão, baixa, lote de repasse, DRE, extrato, empréstimo, campanha | **Financeiro** |
| lead, follow-up, venda, perda, renovação | **Vendas** |
| equipe, funil, origem, tag, motivo de perda, automação de CRM | **CRM** |
| número de WhatsApp, bot, base de conhecimento, template | **Atendimento** |
| e-mail, agenda, tarefa fora do Koter | **Secretário geral** |
| "não sei por onde começar", conta nova | **Implantação** (`/introducao`) |

A frase do encaminhamento é sempre a mesma forma: **o que é, quem faz, e o que ele diz.**

> "Isso é funil, e funil é do especialista de CRM — se você abrir ele e disser 'quero uma etapa nova entre Proposta e Fechado', sai em um minuto."

## 6 · O secretário geral é outra coisa, e diga isso

Ele é o único da lista **sem skill do Koter para carregar**, porque e-mail, agenda e tarefa de fora não são do Koter. Tratá-lo como os outros é prometer integração que o plugin não tem.

O que ele **de fato** tem:

- **Leitura da agenda que já existe dentro do Koter**: `crm_list_tasks` (`type: today | upcoming | pending`) é a lista de follow-up do corretor, e ela é de verdade. Um secretário que abre o dia com "você tem 4 follow-ups hoje, dois do lead que entrou ontem" já vale a pasta.
- **Recomendação de conectores**, que é o resto do trabalho dele. Não integração: **recomendação**, com o nome do conector e o que ele destrava.

| O que ele quer | Conector a recomendar | O que muda |
|---|---|---|
| ler e escrever e-mail | Gmail ou Outlook | responder cliente sem sair da IA, e achar a proposta que veio por e-mail |
| agenda | Google Calendar ou Outlook Calendar | a tarefa do Koter vira compromisso com hora |
| tarefas e anotação | Todoist, Notion, Linear | o que não é lead nem proposta para de morar na cabeça dele |
| arquivo | Google Drive, OneDrive | apólice e proposta em PDF ao alcance da conversa |

**Diga a verdade inteira, de uma vez:**

> "O secretário geral é o único que não vem pronto: o Koter não guarda seu e-mail nem sua agenda. Ele já consegue ler suas tarefas do Koter hoje. Para o resto, você conecta o Gmail e o Google Agenda na sua IA — é configuração dela, não minha — e aí ele passa a cruzar as duas coisas. Quer que eu monte ele assim mesmo, já útil com as tarefas?"

Se a IA hospedeira tiver como listar ou sugerir conectores, use — mas **nunca diga que conectou**. Conectar é ato do corretor, na configuração da IA dele.

## 7 · Aplique

Um especialista por vez, na ordem em que eles rendem: **implantação (se existir) → cadastro → vendas → financeiro → CRM → atendimento → secretário**. Cadastro e vendas primeiro porque são o dia a dia; o resto é "faça uma vez".

Entre um e outro, **pare e mostre**. Seis fichas despejadas de uma vez não são lidas por ninguém — e no caminho B ou C, seis blocos de texto seguidos garantem que ele cole zero.

## 8 · Valide relendo, como toda skill do plugin

| Caminho | A releitura |
|---|---|
| **A** | releia cada arquivo escrito e confira que os **nove campos** estão lá. Diga o caminho completo de cada um |
| **B** | pergunte um por um: "o financeiro já está colado?". Só marque o seguinte quando ele confirmar o anterior |
| **C** | peça para ele **abrir uma conversa nova e colar o de cadastro**. A prova é a IA respondendo já sabendo o assunto |

**A prova final é a mesma nos três, e é ela que fecha a skill:** faça o especialista trabalhar uma vez, na frente dele.

> "Cola o de vendas e escreve só 'entrou um lead, Maria, 11 99000-0000, veio do Instagram'. Se ele cadastrar a Maria sem te perguntar mais nada, está funcionando."

Esse teste é o equivalente, aqui, do que `koter-proposta` e `koter-crm-lead` são na passada única: **configuração pronta e ninguém usando é onboarding que falhou.**

## 9 · Estado

Grave em `.koter/onboarding.json` (`references/estado.md` da `introducao`), no bloco da corretora:

```json
"especialistas": {
  "caminho": "A",
  "formato": ".claude/agents",
  "criados": ["cadastro", "vendas", "financeiro", "crm", "atendimento"],
  "recusados": ["secretario"],
  "conectores_sugeridos": ["gmail", "google-calendar"],
  "em": "2026-09-21"
}
```

`caminho`: `A`, `B`, `C`. `criados` são os que o corretor confirmou. **Recusado não se reoferece** — quem disse não ao secretário não quer ser perguntado de novo na semana seguinte.

Ao reentrar, **releia antes de recriar**: no caminho A, o arquivo diz a verdade; nos B e C, o estado é tudo o que existe, então trate-o como memória de conversa e pergunte em vez de afirmar.

## 10 · Onde esta skill encosta nas outras

| Ponte | O quê |
|---|---|
| `introducao` | ela dá o diagnóstico e o `porte` que podam a lista. Esta skill é o passo natural **depois** do ato 2 — quando ele já cadastrou proposta e lead e a pergunta vira "e agora, como eu uso isso todo dia?" |
| todas as 22 skills | são a matéria-prima. Cada especialista é um recorte delas, **por nome literal** — nunca uma paráfrase |
| `references/catalogo.md` | as sete fichas prontas |
| `references/hospedeiros.md` | a sonda de capacidade, os formatos por hospedeiro e os textos de fallback |

## Ensaiado em 21/09/2026

A sonda e o molde foram **rodados**, não só escritos:

- **A sonda do passo 2 correu num hospedeiro real** que escreve arquivo e não tinha nenhuma das convenções conhecidas. Resultado: caminho A com `.claude/agents/` criada, que é exatamente a saída que o degrau 2 prescreve quando nenhuma pasta existe.
- **A ficha do Financeiro foi gerada como arquivo de agente e relida**: os oito campos de então presentes (o nono, a conexão, entrou em 22/09/2026), cabeçalho com `name` e `description`, **3.300 caracteres**. Duas consequências úteis: o molde cabe folgado no campo de instruções de um projeto (caminho B), e reler conferindo os títulos numerados é um teste de dois segundos.
- **As 22 skills do plugin estão cobertas**, conferido por comparação entre os nomes citados nas fichas e as pastas de `skills/` — nenhuma skill ficou sem especialista, e nenhum nome citado aponta para pasta inexistente.

## Pendente de validação

**Nada nesta skill foi rodado contra a corretora de demonstração**, e não por acaso: ela não escreve no Koter. O que ela escreve é arquivo ou texto, e isso se confere relendo — o que o passo 8 manda fazer.

O que **fica em aberto de verdade**, e deve ser conferido no primeiro corretor real:

- **A sonda do passo 2 foi desenhada, não medida em campo.** Os caminhos de `.claude/agents/`, `.cursor/rules/`, `.github/chatmodes/` e `AGENTS.md` são as convenções conhecidas; um hospedeiro com convenção diferente cai no caminho B ou C, que é o comportamento seguro, mas perde o caminho A que talvez tivesse.
- **O secretário geral nunca rodou com conector ligado.** A leitura de `crm_list_tasks` é do Koter e está provada em `koter-crm-lead`; o cruzamento com agenda e e-mail depende de conector do corretor e não foi exercitado aqui.
- **A poda por permissão** (`financeiro em modo leitura`) foi escrita a partir da lista de permissões do handshake, não observada numa conta de cargo restrito.
