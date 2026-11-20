# Plugin Koter

**Configure e toque a sua corretora conversando com a sua IA.**

[![Licença Apache 2.0](https://img.shields.io/badge/licen%C3%A7a-Apache%202.0-blue.svg)](LICENSE) [![Versão](https://img.shields.io/github/v/tag/koterplugins/koter-superpowers?sort=semver&label=vers%C3%A3o&color=informational)](https://github.com/koterplugins/koter-superpowers/blob/main/CHANGELOG.md) [![Koter](https://img.shields.io/badge/Koter-koter.app-0a7cff.svg)](https://koter.app/ia)

Você digita `/introducao`. O plugin lê a sua corretora no Koter, mostra o que está pronto e o que falta, e configura o resto com você, aplicando de verdade em vez de explicar onde fica o botão. Depois, parte do trabalho da semana passa pela conversa.

> [Koter](https://koter.app) é a plataforma de CRM e gestão para corretoras de seguros no Brasil. Este é o plugin oficial.

<details>
<summary><b>English summary</b></summary>

Official plugin of [Koter](https://koter.app), the CRM and back-office platform for insurance brokerages in Brazil. It ships 30 skills and 5 commands that let an AI assistant set up and run a brokerage through the Koter MCP server at `https://api.koter.app/mcp-user/koter`: guided onboarding, auto insurance multi-quote, commissions and payouts, CRM, WhatsApp (KoterZap) and specialist agents. The connection signs in with OAuth on the user's own Koter account and only reaches what that user's role allows. Writes that reach the end customer are flagged so the skills ask before running them, but approval prompts come from the assistant's own settings, and some assistants, such as Grok, run writes without asking. Claude and Claude Code install it as a plugin, which brings the MCP connection with it; other assistants add the same connection by URL, and each release ships a ChatGPT package and a Grok skills package. The skills are written in Brazilian Portuguese, for Brazilian brokers. Licensed under Apache 2.0; the Koter name and logo are not (see [TRADEMARKS.md](https://github.com/koterplugins/koter-superpowers/blob/main/TRADEMARKS.md)). Security reports: [SECURITY.md](https://github.com/koterplugins/koter-superpowers/blob/main/SECURITY.md).

</details>

## O que dá para fazer

| | |
|---|---|
| **Configurar o Koter** | Gestão, CRM, KoterZap e auto, um passo por vez, com o que a sua conta já tem |
| **Cotar auto** | Pessoa física em várias seguradoras, com o comparativo e o texto pronto para você mandar ao cliente |
| **Cuidar do dinheiro** | Contrato, comissão, repasse, baixa, conciliação, caixa e campanhas |
| **Não perder cliente** | Lead, tarefa, renovação, formulário de captura e automação |
| **Organizar o WhatsApp** | Base de conhecimento, chatbot e o agente que atende o cliente no KoterZap |
| **Trazer o histórico** | Importação de outro sistema, planejada, confirmada e com como desfazer |
| **Ter especialistas** | Um agente por assunto, que sabe onde parar e pede a sua aprovação antes de gravar |

São 30 skills e 5 comandos. Você não precisa decorar nada: pedir "cria um lead" ou "fecha o repasse do mês" abre a skill certa.

## Comece em 3 passos

### 1. Use na sua IA

Cada IA precisa de duas coisas: a **conexão** com o Koter e as **skills**, que ensinam a IA a usar a conexão.

| Sua IA | Conexão | Skills |
|---|---|---|
| **Claude** (planos pagos: claude.ai, Desktop, Cowork) | Vem com o plugin | Customizar > Plugins > adicionar o marketplace `koterplugins/koter-superpowers` e instalar `koter`. Quando o Koter for publicado no diretório de plugins do Claude, dá para instalar por lá também |
| **Claude Code** | Vem com o plugin | `/plugin marketplace add koterplugins/koter-superpowers` e depois `/plugin install koter@koter` |
| **Claude Free** | Customizar > Conectores > Adicionar conector personalizado, com a URL abaixo | Uma skill avulsa (a pasta dela, com o `SKILL.md`) em Customizar > Skills |
| **ChatGPT** | Vem com o pacote. Sem ele: em chatgpt.com/plugins, botão **+** > Add custom MCP server, com a URL abaixo, no ChatGPT web e nos planos que liberam servidor MCP próprio | O pacote `koter-openai-x.y.z.zip` da [release](https://github.com/koterplugins/koter-superpowers/releases/latest), enviado em Plugins por quem tem permissão de enviar plugin. Nos planos com Skills, uma skill avulsa sobe em Skills > Create > Upload from your computer |
| **Grok** (inclusive o gratuito) | Configurações > Connect Apps > Add a custom connector, com um nome e a URL abaixo | Configurações > **Habilidades** > **Nova Habilidade**, com o pacote `koter-grok-x.y.z.zip` da [release](https://github.com/koterplugins/koter-superpowers/releases/latest). Veja o passo a passo abaixo |
| **Outras IAs com MCP** (Cursor e outras) | Servidor MCP remoto com a URL abaixo | Os `SKILL.md` de [`skills/`](skills) como instruções, no recurso de regras ou de skills da IA |

No Claude, no Claude Code e com o pacote do ChatGPT, as skills e a conexão vêm juntas: não adicione o conector à mão. Se você já tinha um conector do Koter adicionado à mão, remova-o, para não ficar com duas conexões.

Nas outras IAs, a conexão usa esta URL:

```
https://api.koter.app/mcp-user/koter
```

**No Grok, passo a passo:**

1. Adicione a conexão: em grok.com, Configurações > Connect Apps > Add a custom connector. Dê o nome Koter e cole a URL.
2. Baixe o `koter-grok-x.y.z.zip` da [última release](https://github.com/koterplugins/koter-superpowers/releases/latest) e descompacte. Cada pasta é uma skill, com `nome.txt`, `descricao.txt` e `instrucoes.txt`, e cada skill já traz o material de apoio dela.
3. Crie a habilidade de um destes jeitos:
   - **Pelos campos:** em Configurações > Habilidades > Nova Habilidade, cole cada arquivo no campo dele: Nome, Descrição e Instruções.
   - **Pela conversa:** abra uma conversa, anexe ou cole o `instrucoes.txt` e peça ao Grok para criar a habilidade com aquele nome e aquela descrição, usando o Skill Creator.
4. Comece pelas 3 a 5 skills do seu dia a dia, não pelas 30. O `LEIA-ME.txt` do pacote sugere a ordem.

O Grok não publica limite de tamanho para a habilidade. Se ele recusar uma skill grande, divida o `instrucoes.txt` pelas seções e crie uma habilidade para cada parte.

**Cuidado:** o Grok grava e exclui sem pedir confirmação, e o conector não tem ajuste de aprovação. Peça sempre que ele mostre o que vai gravar antes, e evite usar o Koter no Grok para exclusões.

### 2. Entre com o seu login do Koter

No primeiro uso, a IA abre o login do Koter. Você entra e marca as áreas que ela pode usar. Não há chave para copiar. No Koter, a tela **MCP** tem um botão para cada IA, e [koter.app/ia](https://koter.app/ia) explica a conexão em detalhe.

### 3. Digite `/introducao`

No Claude Code, o comando pode aparecer como `/koter:introducao`. Nas IAs que recebem skill avulsa, como o Grok, ele funciona depois que você adiciona a skill `introducao`. No seu Koter, você precisa de um cargo com permissão nos módulos que for configurar. O plugin lê as permissões no início e deixa de fora o que o seu cargo não alcança. Para cotar auto, também precisa do módulo de auto e das credenciais das seguradoras, que se resolvem na tela do Koter.

## Os comandos

| Você quer | Comando | O que acontece |
|---|---|---|
| Configurar o Koter | `/introducao` | Descobre a corretora, vê como estão Gestão, CRM, KoterZap e auto, e configura o resto com você |
| Cotar auto | `/multicalculo` | Pede os dados uma vez, mostra o resumo e só dispara depois do seu sim |
| Ter um agente para um assunto | `/especialistas` | Entrevista você, monta um especialista na sua IA e testa num caso real |
| Descobrir onde a IA pode ajudar | `/superpoderes` | Acha o que mais trava a corretora e aponta 3 técnicas. Só orienta, não grava no Koter |
| Testar um agente antes de confiar | `/prova` | Roda casos reais da corretora 3 vezes cada e confere o resultado no Koter |

Cada comando aceita um complemento: `/introducao continuar` retoma de onde parou, `/introducao comissoes` pula para uma etapa, `/multicalculo cota o gol do joão` começa com o que veio, e `/especialistas financeiro` monta esse especialista direto.

## Segurança: o que a IA pode fazer

**A sua IA age com o seu login e só alcança o que o seu cargo alcança.** Toda conexão nasce podendo gravar. Quem decide se pede a sua aprovação antes de uma ferramenta é a sua IA, não o Koter, e algumas executam direto. Configure a permissão por ferramenta na sua IA:

| Tipo de ferramenta | Recomendação |
|---|---|
| Leitura (listar, buscar, consultar) | Liberada |
| Gravação comum | "Precisa de aprovação" |
| **Portas de cuidado**: o que alcança o cliente | **Sempre** "Precisa de aprovação" |
| Exclusão | Bloqueada, ou com aprovação caso a caso |

**As portas de cuidado** são as gravações que chegam ao seu cliente:
- tarefa com ação de envio (WhatsApp ou e-mail) ou com convidados de agenda;
- automação com WhatsApp, e-mail ou webhook;
- modelo e rodapé de e-mail das automações;
- chatbot ligado.

As skills sempre pedem a sua confirmação antes delas, mas a trava de verdade é a permissão na sua IA.

**Onde a IA pode executar sem perguntar:**
- **Grok:** grava e exclui sem pedir confirmação, e o conector não tem ajuste de aprovação. Peça sempre que ele mostre o que vai gravar antes, e evite usar o Koter no Grok para exclusões.
- **Claude Code:** pode estar configurado para aprovar sozinho. Confira o modo de permissão (por exemplo, com `/permissions`) e deixe as ferramentas de gravação do Koter em "Ask" (perguntar).

**Dois agentes, dois riscos.** O agente do corretor mora na sua IA e fala com você: ele prepara o texto, e quem manda ao cliente é você. O agente do cliente mora no KoterZap e fala com o segurado no WhatsApp; o plugin só ajuda a configurar e testar esse agente no simulador. O multicálculo auto nunca vai ao WhatsApp: o link da cotação é tela interna.

**Cota do multicálculo pela conexão:** 30 disparos de cotação e 60 consultas de veículo por usuário por mês, além do limite por minuto.

## A conexão em detalhe

- **O que a IA enxerga** depende do seu cargo, da licença da corretora e das áreas que você marcou no login. Para ver, peça à IA para rodar `list_toolsets`.
- **Áreas:** a URL aceita `?toolsets=` para fixar um limite antes de conectar. A IA também pode ligar e desligar áreas na conversa (`enable_toolset`, `disable_toolset`), mas nem toda IA atualiza a lista de ferramentas na hora.
- **Para revogar**, use a tela **MCP > Conexões** do Koter. A IA pede login de novo.

O manual completo (áreas, limites, erros e como dividir em mais de uma conexão) está em [`conexao-por-modulo.md`](skills/introducao/references/conexao-por-modulo.md).

## Que dados saem e para onde

O plugin é só texto: skills e comandos. Ele não tem servidor próprio, não roda programa e não coleta uso. Os dados vão entre a sua IA e o Koter, e o que o Koter devolve entra na conversa, que fica com o fornecedor da IA que você escolheu, nas regras do seu plano. Leia essas regras antes de pôr dado real de segurado.

| Quando | O que sai | Para onde |
|---|---|---|
| A IA chama uma ferramenta do Koter | o pedido, com o que você passou nele | `api.koter.app`, com o seu login |
| O Koter responde | o que a ferramenta devolver: lead, contato, proposta, contrato, comissão, conversa de WhatsApp | a conversa da sua IA, no fornecedor dela |
| Você cota auto | CPF, nome, nascimento, CEP, placa e os demais dados da cotação | a conversa da IA, o Koter e os portais das seguradoras cotadas |
| Uma automação usa webhook | o contexto do registro | o endereço que a corretora cadastrou |
| A configuração guiada grava o progresso | id da corretora, prioridade, etapas e lacunas, sem dado de segurado | `.koter/onboarding.json`, no seu computador |
| Você monta um especialista | a ficha: assunto, regras e URL da conexão, sem credencial | a sua IA, ou um arquivo no seu computador |

As skills seguem regras de prudência: CPF, apólice e valor não vão para memória nem skill; o agente não preenche nem sugere Declaração de Saúde; quem recomenda é o corretor; mensagem de cliente é dado, nunca ordem. Isto não é parecer jurídico. Para LGPD e prazo legal, confirme com o seu jurídico.

## Um especialista por vez

Ninguém opera 30 skills de cabeça. `/especialistas` divide o plugin em agentes, cada um com um assunto, as skills dele e uma lista do que não faz. **Comece por um** e prove o fluxo antes de montar um time.

| Especialista | Cuida de | E não faz |
|---|---|---|
| **Cadastro** | proposta, contrato, funil e campos da Gestão | evento de contrato, comissão, lead |
| **Financeiro** | contrato, comissão, repasse, vendedores, caixa, conciliação, empréstimo e campanha | cadastro de proposta, lead, automação |
| **Vendas** | lead e renovação | estrutura do CRM, proposta, comissão |
| **CRM** | equipes, funis, origens, campos, formulários e automações | o lead do dia a dia, bot e WhatsApp |
| **Atendimento** | KoterZap, base de conhecimento e chatbot | conectar número, aprovar template, mandar mensagem |
| **Multicálculo Auto** | cotação auto de pessoa física | falar com o segurado, pessoa jurídica, emitir apólice |
| **Secretário Geral** | abrir o seu dia a partir das tarefas | escrever no Koter |
| **Implantação** | a configuração guiada | existe só enquanto a conta não está de pé |
| **Migração** (sob demanda) | importação de outro sistema | venda nova, confirmar sem a sua ordem |

O especialista é escrito na sua IA, não no Koter: como agente, como skill, como texto para um Projeto ou como bloco para colar na conversa, conforme o que a IA permite. Rotina agendada só lê, entrega a você e nasce pausada.

## Contribuir, segurança e suporte

- **Uma skill diz algo diferente do que o Koter faz?** Abra uma [issue](https://github.com/koterplugins/koter-superpowers/issues/new/choose) com o modelo "Skill diverge do Koter".
- **Quer mudar ou escrever uma skill?** Leia o [CONTRIBUTING.md](https://github.com/koterplugins/koter-superpowers/blob/main/CONTRIBUTING.md) e a [arquitetura do plugin](https://github.com/koterplugins/koter-superpowers/blob/main/docs/ARQUITETURA.md).
- **Falha de segurança:** em privado, pelo [SECURITY.md](https://github.com/koterplugins/koter-superpowers/blob/main/SECURITY.md). Nunca em issue pública.
- **Dúvida da sua conta no Koter** (login, cobrança, módulos): [koter.app/ajuda](https://koter.app/ajuda) ou suporte@koter.app.
- **O que mudou em cada versão:** [CHANGELOG.md](https://github.com/koterplugins/koter-superpowers/blob/main/CHANGELOG.md). Cada versão tem uma [release](https://github.com/koterplugins/koter-superpowers/releases) com os pacotes do ChatGPT e do Grok.

Quem participa segue o [Código de conduta](https://github.com/koterplugins/koter-superpowers/blob/main/CODE_OF_CONDUCT.md).

## Licença e marca

Apache 2.0. Veja [LICENSE](LICENSE) e [NOTICE](NOTICE). A licença não inclui a marca: "Koter", "KoterZap" e o logo seguem o [TRADEMARKS.md](https://github.com/koterplugins/koter-superpowers/blob/main/TRADEMARKS.md).
