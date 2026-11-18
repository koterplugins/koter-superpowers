# Arquitetura do plugin

Para quem vai revisar ou escrever skill. Para usar o plugin, o [README](../README.md) basta.

## Estrutura

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
  koter-formularios/                    formulários de captura do CRM e as respostas

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

## O contrato de toda skill filha

```
pré-requisitos → reconfere o companyId → detecta o que já existe →
lê o perfil do estado → pergunta só o delta → aplica via MCP →
valida relendo → grava o estado → sugere a próxima
```

## As seis regras

1. Detectar antes de perguntar.
2. Toda pergunta é uma escolha de 2 a 4 opções, com consequência e recomendação.
3. Toda skill termina em configuração aplicada e conferida.
4. Nada é apagado sem pedido explícito do corretor, na mesma conversa.
5. Na conta que já tem histórico, mudança de configuração é retroativa até prova em contrário: meça quantos registros ela alcança e diga o número antes de aplicar.
6. O `companyId` é reconferido antes de cada rodada de escrita, não só no handshake.

## A passada única

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

## Três fatos para quem for escrever skill nova

1. **Funil é por equipe**, não da corretora. Funil separado é equipe separada.
2. **Coisa nasce ligada.** A Gestão já vem com automações padrão ativas, toda equipe nova do CRM nasce com etapas de sistema, e automação criada pela conexão já nasce no ar.
3. **A data da renovação mora no contrato.** O CRM tem campo tipo data e automação agendada pela data do lead ou do contato, mas o fim de vigência fica no contrato, na Gestão, e é de lá que a renovação dispara.

## Fora das skills por decisão

Ferramentas da corretora que nenhuma skill usa. Elas existem na conexão e a IA pode chamá-las, mas nenhum manual do plugin as roteiriza.

| Ferramentas | Motivo |
|---|---|
| `admin_cargos_list_company_roles`, `admin_cargos_save_company_role`, `admin_cargos_set_role_wallet_scope`, `admin_usuarios_fetch_admin_users_context`, `admin_usuarios_list_invitations` | **Cargo, permissão e convite.** Mudam o que cada pessoa alcança, inclusive pela conexão, e o limite de carteira de um cargo ou da corretora inteira: decisão de quem administra. O plugin só lê o cargo de quem conecta, pelo handshake. O contexto de usuários traz cargos e estados para convite, troca de cargo e informativo, escritas que nenhuma skill roteiriza, e a skill de vendedores só aponta o convite como ato de administração |
| `admin_usuarios_list_informatives`, `admin_usuarios_save_informative` | **Aviso interno** ao time da corretora. Não é configuração de módulo nem rotina de venda ou dinheiro |
| `admin_usuarios_list_company_insurance_companies`, `admin_usuarios_set_company_insurance_companies_status`, `admin_usuarios_set_company_segment_management_status`, `admin_usuarios_set_hide_future_insurance_companies` | **Seguradoras e segmentos da corretora.** Ajuste da corretora inteira, de quem administra: seguradora desligada some das cotações do time e dos registros novos do Gestão, um segmento inteiro pode ser desligado no Gestão, e uma regra vale para as seguradoras que ainda vão entrar no catálogo |

## Palavras que aparecem nas skills


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

