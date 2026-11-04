# Plugin Koter

**Configure e toque sua corretora conversando com a sua IA.** Você digita `/introducao`, o plugin lê a sua corretora no Koter, mostra o que está pronto e o que falta, e configura o resto com você, aplicando de verdade, em vez de explicar onde fica o botão.

Depois da configuração, parte do trabalho da semana pode passar pela conversa:

- **Cotar auto** de pessoa física em várias seguradoras, comparar as ofertas e sair com o texto pronto para você mandar ao cliente.
- **Cuidar do dinheiro:** contrato, comissão, repasse, baixa, conciliação e caixa.
- **Não perder cliente:** lead, tarefa, renovação e automação.
- **Organizar o WhatsApp:** base de conhecimento, chatbot e o agente que atende o cliente no KoterZap.
- **Trazer o histórico** de outro sistema para dentro do Koter.
- **Ter um especialista** que conhece um assunto, sabe onde parar e pede a sua aprovação antes de gravar.

São 29 skills e 5 comandos. Você não precisa decorar nada: pedir "cria um lead" ou "fecha o repasse do mês" abre a skill certa.

> [Koter](https://koter.app) é a plataforma de CRM e gestão para corretoras de seguros no Brasil.

**Antes de confiar:** multicálculo auto, contrato, importação, `/superpoderes` e `/prova` foram escritos lendo o código do Koter e ainda não rodaram em conta real. O que foi ensaiado e o que falta testar estão em [Como isto foi escrito](#como-isto-foi-escrito).

## Palavras que aparecem aqui

| Palavra | O que quer dizer |
|---|---|
| **Conexão** (MCP) | O caminho entre a sua IA e o Koter. MCP é o nome técnico. É por ele que a IA lê e grava no Koter, com o seu login |
| **Ferramenta** | Cada ação que a IA pode fazer pela conexão, como listar leads ou criar tarefa. O nome é técnico, como `crm_list_leads`, mas você não digita isso: pede com as suas palavras |
| **Área** | Um grupo de ferramentas do mesmo assunto, como CRM ou comissão. No manual e na URL aparece como `toolset` |
| **Skill** | Um manual que a IA abre sozinha quando o assunto aparece |
| **Comando** | Um atalho digitado na conversa, que começa com `/` |
| **Agente** | A IA com um trabalho definido, regras e limites |
| **"Precisa de aprovação"** | Opção da sua IA que pede o seu sim antes de usar uma ferramenta |
| **Template** | Modelo de mensagem aprovado pela Meta para o WhatsApp |
| **Webhook** | Aviso automático que o Koter manda para outro sistema |

## Comece aqui

**1. Veja se a sua IA serve.**

| Sua IA | Plugin | Conexão com o Koter |
|---|---|---|
| Claude pago (Pro, Max, Ultra, Team, Enterprise) | instala | sim. No Team e no Enterprise, só o Owner adiciona, e cada membro faz login |
| Claude Code | instala | sim |
| Claude Free | não instala. Skill avulsa sobe em Customizar > Skills, com "execução de código" ligada | uma conexão só |
| Outras (ChatGPT, Gemini, Grok, Cursor) | depende do produto e do plano | muitas não confirmadas. No Gemini, não dá no Brasil |

A tabela completa, com data, está em [`hospedeiros.md`](skills/koter-especialistas/references/hospedeiros.md). Ela vem da documentação de cada produto, sem teste em conta real.

**2. Ligue a conexão.** O plugin não traz a conexão, e sem ela as skills não alcançam o Koter.

1. Na sua IA, adicione um conector personalizado. No Claude, fica em Customizar > Conectores. No Claude Code, é `claude mcp add --transport http --scope user koter <url>`.
2. Cole a URL `https://api.koter.app/mcp-user/koter`, ou uma das três de [Como a conexão funciona](#como-a-conexão-funciona). Escolha antes: trocar depois exige recriar o conector.
3. Entre no Koter e marque as áreas. Não há chave para copiar.

**3. Instale o plugin.**

- **Claude pago:** em Customizar > Plugins, adicione o marketplace `https://github.com/koterplugins/koter-superpowers` e instale `koter`. Esse caminho vem da documentação do Claude e não foi testado com este plugin.
- **Claude Code:** digite estas duas linhas, uma de cada vez.

```
/plugin marketplace add koterplugins/koter-superpowers
/plugin install koter@koter
```

**4. Digite `/introducao`.** No Claude Code, o comando pode aparecer com o prefixo do plugin: `/koter:introducao`.

O que você precisa ter no Koter:

- **Um cargo com permissão** nos módulos que for configurar. O plugin lê as permissões no início e deixa de fora o que o seu cargo não alcança.
- **Para cotar auto:** o módulo de auto e as credenciais das seguradoras, que se resolvem na tela do Koter.

## Dois tipos de agente

São dois agentes, em lugares diferentes, com riscos diferentes. Quase tudo neste plugin depende dessa separação.

| | Agente do corretor | Agente do cliente |
|---|---|---|
| **Mora** | na sua IA, ligada ao Koter pela conexão | no KoterZap |
| **Fala com** | você e a sua equipe | o segurado, no WhatsApp |
| **Cota** | seguro auto de pessoa física | saúde, dentro do WhatsApp. Não tem ferramenta de auto |
| **O que segura** | a permissão por ferramenta na sua IA | ferramentas desligadas, transferência para humano e prova no simulador |
| **Risco** | mexer em dado | falar em nome da corretora |
| **Skills** | `koter-especialistas`, `koter-multicalculo-auto` e as de rotina | `koter-chatbot-ia`, `koter-chatbot-fluxo`, `koter-zap-conhecimento` |

Três coisas que o plugin não promete:

- **Nenhuma ferramenta da conexão manda mensagem a cliente.** O agente do corretor prepara o texto, e quem manda é você. O que chega ao cliente sai por automação com template aprovado, por chatbot ativo ou por webhook de automação, e essas portas pedem cuidado.
- **Multicálculo auto não vai para o WhatsApp.** O link da cotação é tela interna e nunca vai ao segurado.
- **A cotação aberta à corretora pela conexão é a de auto.** Quem cota saúde é o agente do KoterZap, dentro do WhatsApp, e isso é outra coisa.

## Os comandos

| Você quer | Comando | O que acontece |
|---|---|---|
| Configurar o Koter | `/introducao` | Descobre a corretora, vê como estão Gestão, CRM, KoterZap e auto, e configura o resto com você, uma skill por vez |
| Cotar auto | `/multicalculo` | Confere quem cota, pede os dados uma vez, numa mensagem só, mostra o resumo e só dispara depois do seu sim. Entrega o comparativo e o texto para você mandar |
| Ter um agente para um assunto | `/especialistas` | Entrevista você, monta um especialista na sua IA e testa num caso real. Um por vez |
| Descobrir onde a IA pode ajudar | `/superpoderes` | Procura o que mais trava a corretora e aponta 3 técnicas, cada uma com algo para fazer hoje. Só orienta: não grava no Koter |
| Testar um agente antes de confiar | `/prova` | Monta um teste com casos reais da corretora. Cada caso roda 3 vezes, o resultado é conferido no Koter, e o agente é comparado com e sem a skill |

Cada um aceita um complemento:

| Exemplo | O que faz |
|---|---|
| `/introducao continuar` | Retoma de onde parou |
| `/introducao comissoes` | Pula para uma etapa, depois de checar o que ela exige |
| `/multicalculo cota o gol do joão` | Começa com o que veio e pede só o que falta |
| `/multicalculo ver` | Retoma a cotação em andamento, sem criar outra |
| `/especialistas financeiro` | Monta esse especialista direto |
| `/especialistas proximo` | Confere se o último passou na prova e monta o seguinte |
| `/especialistas catalogo` | Mostra os especialistas em uma linha cada |
| `/superpoderes cotação parada` | Parte dessa dor e pula as perguntas que ela já responde |

## Como a conexão funciona

- **O que cada um enxerga** depende do cargo, da licença e do que foi marcado. Para saber o que a sua conexão vê, peça à IA para rodar `list_toolsets`.
- **Toda conexão nasce podendo gravar.** "Somente leitura" não é trava. A trava é a permissão por ferramenta na sua IA: leitura liberada, gravação em "Precisa de aprovação", exclusão bloqueada.
- **Automação e chatbot ficam sempre em "Precisa de aprovação".** Essas ferramentas alcançam o cliente e não saem marcadas como destrutivas, então a IA não freia sozinha.
- **O final `?toolsets=` da URL escolhe as áreas.** Ele corta assunto, não corta gravação. É o limite máximo da conexão e se define antes de conectar.
- **Três conexões que não se cruzam:** Venda, Dinheiro e Operação. Duas conexões com área em comum na mesma IA podem derrubar uma à outra. Claude Free tem uma conexão só.

```
VENDA     https://api.koter.app/mcp-user/koter?toolsets=crm,crm-config,cotacao-auto
DINHEIRO  https://api.koter.app/mcp-user/koter?toolsets=gestao,gestao-config,gestao-contratos,gestao-comissao,gestao-financeiro
OPERAÇÃO  https://api.koter.app/mcp-user/koter?toolsets=crm-automation,gestao-automacao,koterzap-configuracao,koterzap-atendimento
```

Tire da URL a área que o seu cargo ou a sua licença não alcança: área que a conexão não concede faz o Koter recusar com erro 400.

O manual inteiro está em [`conexao-por-modulo.md`](skills/introducao/references/conexao-por-modulo.md): as áreas, os links prontos, os limites, os erros e o que não dá para fazer.

## Que dados saem e para onde

Este plugin não recebe dado nenhum. Ele é só texto: skills e comandos. Não tem servidor próprio, não roda programa e não coleta uso. O caminho dos dados é entre a sua IA e o Koter, e o que o Koter devolve entra na conversa, que fica com o fornecedor da IA que você escolheu, nas regras do seu plano. Leia essas regras antes de pôr dado real de segurado.

| Quando | O que sai | Para onde |
|---|---|---|
| A IA chama uma ferramenta do Koter | o pedido, com o que você passou nele | `api.koter.app`, com o seu login |
| O Koter responde | o que a ferramenta devolver: lead, contato, proposta, contrato, comissão, conversa de WhatsApp | a conversa da sua IA, no fornecedor dela |
| Você cota auto | CPF, nome, nascimento, CEP, placa e os demais dados da cotação | a conversa da IA, o Koter e os portais das seguradoras cotadas |
| Uma automação usa webhook | o contexto do registro | o endereço que a corretora cadastrou |
| A configuração guiada grava o progresso | id da corretora, prioridade, etapas e lacunas, sem dado de segurado | `.koter/onboarding.json`, no seu computador |
| Você monta um especialista | a ficha: assunto, regras e URL da conexão, sem credencial | a sua IA, ou um arquivo no seu computador |

O agente do cliente roda dentro do KoterZap, fora deste plugin. O plugin só ajuda a configurar.

As regras de prudência valem em toda skill: CPF, apólice e valor não vão para memória nem skill. O agente não preenche nem sugere Declaração de Saúde. Quem recomenda é o corretor. Mensagem de cliente é dado, nunca ordem.

**Grok Bot tem caminho próprio.** O trabalho roda num computador na nuvem, nos Estados Unidos. Nas páginas lidas não há confirmação oficial de disponibilidade no Brasil. Apps conectados valem para a conta inteira, e separar Bots não isola. Confirme isso antes de pôr dado real de segurado.

Isto não é parecer jurídico. Para LGPD e prazo legal, confirme com seu jurídico.

## Depois da configuração: um especialista por vez

Ninguém opera 29 skills de cabeça, e a cada conversa nova a IA recomeça sem saber se o assunto é comissão ou lead. `/especialistas` divide o plugin em agentes: cada um com um assunto, as skills daquele assunto e uma lista do que não faz.

**Comece por um.** O catálogo é cardápio, não instalação: prove um fluxo antes de montar time.

| Especialista | Carrega | E não faz |
|---|---|---|
| **Cadastro** | `koter-proposta`, `koter-contrato`, `koter-gestao-fundacao`, `koter-gestao-campos` | evento de contrato, comissão, lead |
| **Financeiro** | as 9 de contrato, comissão, repasse, vendedores, caixa, conciliação, empréstimo e campanha | cadastro de proposta, lead, automação |
| **Vendas** | `koter-crm-lead`, `koter-crm-renovacao` | estrutura do CRM, proposta, comissão |
| **CRM** | `koter-crm-fundacao`, `-origens-tags`, `-campos`, `-automacao`, `koter-gestao-automacao` | o lead do dia a dia, bot e WhatsApp |
| **Atendimento** | as 4 de KoterZap e chatbot | conectar número, aprovar template, mandar mensagem |
| **Multicálculo Auto** | `koter-multicalculo-auto` | falar com o segurado, pessoa jurídica, emitir apólice, dizer qual é a melhor oferta |
| **Secretário Geral** | **nenhuma skill do Koter:** abre o seu dia a partir das tarefas | escrever no Koter, conectar qualquer coisa |
| **Implantação** | `introducao` | só existe enquanto a conta não está de pé |
| **Migração** (sob demanda) | `koter-importacao` | venda nova, extrato de comissão, confirmar sem a sua ordem |

A lista muda conforme o que a corretora tem. A ficha do especialista tem 10 campos, do nome à conexão que ele usa, e sai em cinco formatos: arquivo, skill empacotada, texto para colar em Projeto, Grok Bot, ou texto para colar na conversa.

**Cada um com a sua conexão, onde a IA deixa.** Separar a conexão por especialista só dá onde a ferramenta faz essa separação: Claude Code por agente, tarefa agendada, e ferramentas de automação como n8n e Make. No resto, use as três conexões. Elas separam assunto, e quem segura a gravação é "Precisa de aprovação".

**Rotina agendada só lê** e entrega a você. A primeira linha confere se o Koter respondeu, e ela nasce pausada.

`koter-especialistas` escreve na sua IA, não no Koter. Onde a IA cria agente, ela cria o arquivo. Onde só há projeto, entrega o texto para colar. Onde não há nada, entrega um bloco para copiar.

## Como isto foi escrito

A primeira versão das skills foi escrita rodando as chamadas numa corretora de demonstração e anotando o que o Koter respondia. Por isso elas trazem armadilhas com a mensagem de erro literal.

**A atualização de 03/11/2026 foi lida contra o código do Koter e não foi executada.** Nomes de ferramenta, parâmetros, opções e mensagens foram conferidos por leitura. Nenhuma conta foi conectada, nenhuma cotação foi disparada, nenhum contrato foi implantado e nenhuma comissão foi publicada para escrever esta versão.

Na prática:

- **Skills novas nunca rodaram:** `koter-multicalculo-auto`, `koter-contrato`, `koter-importacao`, `koter-superpoderes` e `koter-prova`. As técnicas de `koter-superpoderes` não foram testadas com corretor, e os números de `koter-prova` são regra de bolso.
- **As medições do ciclo de comissão saíram.** Elas valiam para o modelo anterior de comissão, que mudou. Fica a regra escrita a partir da leitura.
- **Medição antiga que ainda aparece vem com a ressalva de que não foi refeita.** São ensaios de setembro de 2026 na corretora de demonstração, como funil, campos, proposta, base de conhecimento e simulador de chatbot.
- **Cada `SKILL.md` termina em `## Conferência`,** dizendo o que foi conferido, contra o quê, e o que continua sem execução. Leia essa seção antes de confiar numa skill com dado real.

**O que falta testar em conta real:**

- Uma cotação de auto completa: esperar o resultado na conversa, o tamanho da resposta com muitas seguradoras e o PDF da seguradora. Se a área de auto já está aberta para a sua corretora, `list_toolsets` responde.
- O caminho do dinheiro no modelo atual: do contrato implantado ao repasse pago, incluindo publicar uma tabela de comissão, que não tem simulação.
- Uma importação real, planejada, confirmada e desfeita.
- O agente do cliente num número de WhatsApp ligado, com a versão atual.
- Duas conexões na mesma IA: quando uma derruba a outra, com áreas separadas e com áreas em comum, e com o plugin instalado.
- Uma conexão criada antes da área de auto: se ela aparece, em quanto tempo, e se abrir a página do conector resolve.
- Uma ferramenta em "Precisa de aprovação" dentro de tarefa agendada: se ela trava, falha ou passa.
- Ligar e desligar área no meio da conversa na claude.ai, que em setembro de 2026 não fazia efeito.
- Outras IAs: Grok Bot conectando o Koter, e se todos os Bots da conta enxergam a conexão; ChatGPT, onde as páginas se contradizem por plano.
- `/especialistas`, `/superpoderes` e `/prova` com um corretor de verdade.
- A instalação do plugin no chat do Claude pago.

## Para quem quer ver por dentro

Daqui para baixo é para quem vai revisar ou escrever skill. Para usar o plugin, não precisa ler.

Quem usa Git também pode clonar o repositório e apontar o Claude Code para a pasta:

```bash
git clone https://github.com/koterplugins/koter-superpowers.git
```

### Estrutura

```
.claude-plugin/plugin.json
.claude-plugin/marketplace.json
commands/
  introducao.md  multicalculo.md  especialistas.md  superpoderes.md  prova.md
skills/
  introducao/                           roteadora: handshake → perfil → diagnóstico → plano → execução
    references/passada-unica.md         a ordem entre as trilhas e a lista de tela do corretor
    references/handshake.md             a primeira chamada, o plano B e cada erro de conexão
    references/estado.md                onde mora o progresso do onboarding
    references/conexao-por-modulo.md    o manual do MCP
    references/trilha-gestao.md         a ordem dentro do Gestão
    references/trilha-crm.md            a ordem dentro do CRM
    references/trilha-koterzap.md       a ordem dentro do KoterZap

  koter-gestao-fundacao/                funil de status e entidades de adesão
  koter-gestao-campos/                  campos personalizados de proposta e beneficiário
  koter-gestao-vendedores/              vendedores, gestores e hierarquia
  koter-gestao-comissoes/               tabela da operadora, repasse, variantes e estorno
  koter-gestao-financeiro/              caixa, plano de contas, DRE e fluxo
  koter-gestao-baixa-parcelas/          baixa de conta a pagar e a receber
  koter-gestao-conciliacao/             extrato, conciliação e críticas
  koter-gestao-repasse/                 do recebimento ao lote de repasse pago
  koter-gestao-emprestimos-antecipacao/ antecipação, empréstimo e débito de estorno
  koter-gestao-campanhas/               metas e premiação
  koter-gestao-automacao/               o que roda sozinho no Gestão
  koter-proposta/                       proposta e beneficiários
  koter-contrato/                       implantação, eventos do contrato e prévia de comissão

  koter-crm-fundacao/                   equipes e o funil de cada equipe
  koter-crm-origens-tags/               origens, tags e motivos de perda
  koter-crm-campos/                     campos personalizados de lead e contato
  koter-crm-lead/                       lead, tarefa, venda e perda
  koter-crm-automacao/                  distribuição, transbordo e régua de follow-up
  koter-crm-renovacao/                  a rotina que segura carteira

  koter-zap-fundacao/                   os números, seus tipos e quem atende
  koter-zap-conhecimento/               a base que o agente do WhatsApp consulta
  koter-chatbot-fluxo/                  triagem, horário, desvio pelo CRM e transbordo
  koter-chatbot-ia/                     o agente do cliente

  koter-multicalculo-auto/              cotação auto de pessoa física
    references/parametros.md            parâmetros, opções e chaves de recotação
    references/armadilhas.md            o que dá errado em silêncio
    references/erros.md                 cada mensagem e a conduta

  koter-importacao/                     migração em dois atos, planejar e confirmar

  koter-especialistas/                  monta um especialista na IA do corretor
    references/catalogo.md              as 9 fichas
    references/hospedeiros.md           o que cada IA permite e as cinco entregas
  koter-superpoderes/                   o gargalo e as 3 técnicas
    references/tecnicas.md              as técnicas, cada uma com "faça hoje"
    references/receitas.md              receitas prontas de agente
    references/grok-bot.md              o caminho do Grok Bot
    references/fontes.md                de onde veio cada técnica
  koter-prova/                          a prova de um agente
```

### O contrato de toda skill filha

```
pré-requisitos → reconfere o companyId → detecta o que já existe →
lê o perfil do estado → pergunta só o delta → aplica via MCP →
valida relendo → grava o estado → sugere a próxima
```

### As seis regras

1. Detectar antes de perguntar.
2. Toda pergunta é uma escolha de 2 a 4 opções, com consequência e recomendação.
3. Toda skill termina em configuração aplicada e conferida.
4. Nada é apagado sem pedido explícito do corretor, na mesma conversa.
5. Na conta que já tem histórico, mudança de configuração é retroativa até prova em contrário: meça quantos registros ela alcança e diga o número antes de aplicar.
6. O `companyId` é reconferido antes de cada rodada de escrita, não só no handshake.

### A passada única

As trilhas são uma conversa só, em atos (`skills/introducao/references/passada-unica.md`):

```
ATO 0 · Handshake e diagnóstico           uma sessão, nenhuma escrita
ATO 1 · Gestão até a primeira venda       fundacao → campos → koter-proposta → koter-contrato
ATO 2 · CRM até o primeiro lead           fundacao → origens-tags → campos → koter-crm-lead
PONTO AUTO · Primeira cotação             koter-multicalculo-auto, só com o módulo
ATO 3 · O que roda sozinho                comissão, recebimento, repasse, automação, KoterZap, chatbot
```

A regra que a organiza: **o que depende de outra pessoa sai na frente.** Conectar a Cloud API do WhatsApp e aprovar template na Meta não têm ferramenta na conexão. Por isso o diagnóstico do KoterZap roda no ato 0, e essas tarefas são entregues no começo, para você tocar em paralelo.

Na conta que já está em uso, o plugin não pede cadastro de teste: mede o volume de cada módulo, e o ato daquele módulo vira leitura.

### Três achados para quem for escrever skill nova

1. **Funil é por equipe**, não da corretora. Funil separado é equipe separada.
2. **Coisa nasce ligada.** A Gestão já vem com automações padrão ativas, toda equipe nova do CRM nasce com etapas de sistema, e automação criada pela conexão já nasce no ar.
3. **O CRM não tem data.** Campo personalizado do CRM não tem tipo data, e nenhum gatilho de lá lê data de campo. O relógio da renovação mora no fim de vigência do contrato, na Gestão.

## Licença

MIT. Veja [LICENSE](LICENSE).
