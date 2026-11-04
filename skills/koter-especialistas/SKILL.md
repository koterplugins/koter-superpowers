---
name: koter-especialistas
description: Monta um especialista do Koter na IA do corretor, com entrevista, ficha, conexão e permissões. Use quando pedirem para criar agente, montar time de IA ou parar de explicar tudo a cada conversa.
---

# koter-especialistas

O plugin tem 29 skills. Ninguém opera isso de cabeça, nem o corretor, nem a IA, que a cada conversa nova começa sem saber se o assunto é comissão ou lead.

Esta skill **entrevista o corretor e sai com um especialista só**: um recorte do plugin com assunto, skills, trava, conexão e permissões, provado num caso real. Depois vem o próximo. O catálogo é cardápio, não instalação.

É a única skill do plugin que **não escreve nada no Koter**: ela escreve na IA dele. Termina com o especialista existindo e provado, nunca com uma lista de sugestões.

## 0 · Antes de perguntar

Detecte o que dá para detectar. Duas leituras, nenhuma escrita:

```
admin_cargos_fetch_admin_roles_context(include: ["myPermissions"])   → companyId, modules, permissions, licensed, crmAccess
```

Sem essa ferramenta, o cargo não alcança `admin-cargos`: chame `list_toolsets`. Toolset com `toolsCount` acima de zero está aberto, e o retrato é parcial. Detalhes em `../introducao/references/handshake.md`.

- `companyId` nulo: nada segue até ele selecionar uma corretora no Koter.
- `permissions` com `all`: a conexão não é de corretora. Pare e avise. Corretora nunca recebe `all`.
- Diagnóstico da `introducao` já rodado: aproveite o `porte`. Se não rodou, não force.

Olhe também as suas próprias ferramentas: você escreve arquivo? Está em Claude Code? O que você descobrir sozinho, não pergunte. A sonda está em `references/hospedeiros.md`.

## 1 · Dois tipos de agente, e diga qual é este

| | Agente do corretor | Agente do cliente |
|---|---|---|
| Mora em | IA do corretor, via MCP | KoterZap: etapa `AI_ROUTER` ou chatbot `AI_AGENT` |
| Fala com | o corretor | o segurado, no WhatsApp |
| Cota | auto (`cotacao-auto`) | saúde, dentro do KoterZap. Nenhuma ferramenta de auto |
| Trava principal | permissão por ferramenta na IA | `disabledTools`, `transfer_to_human` fixa, barreiras do canal |

**Toda ficha deste catálogo é agente do corretor.** Ele lê, rascunha e grava com aprovação. Nenhuma ferramenta MCP manda mensagem a cliente: o especialista prepara o texto e o corretor envia. As saídas indiretas são automação com template, chatbot ativo e webhook de automação, e são elas que pedem cuidado.

O Especialista de Atendimento configura o agente do cliente. Ele não é esse agente. O agente do cliente se monta com `koter-chatbot-ia`.

## 2 · A entrevista: quatro perguntas, numa mensagem

Comece aqui, antes de falar em agente. Pergunte de uma vez, sem questionário:

> "Antes de montar, quatro perguntas. Se preferir, manda um áudio contando sua semana que eu tiro as respostas dele.
> 1. Qual IA você usa? (Claude, ChatGPT, Gemini, Grok, outra)
> 2. Qual plano? (grátis, pago individual, de empresa, não sei)
> 3. O que te toma tempo toda semana e você queria largar?
> 4. O que nunca pode ser automatizado na sua corretora?"

Quem não souber o plano abre as configurações da IA e manda um print.

| Pergunta | O que ela decide |
|---|---|
| Qual IA e qual plano | a entrega, a conexão e se o Koter liga. A mesma marca muda de resposta por plano (`references/hospedeiros.md`) |
| O que dói toda semana | **qual** especialista nasce primeiro (passo 3) |
| O que nunca automatizar | o campo 2 (onde eu paro), o campo 5 e o que fica "Bloqueada" na IA |

Sinistro, recusa, reclamação e recomendação de cobertura ficam com o corretor mesmo que ele não diga. Quando a resposta 1 ou 2 fechar um caminho, diga logo, com a fala pronta de `references/hospedeiros.md`. Não deixe ele descobrir sozinho.

## 3 · Saia com um especialista

Compare a dor com esta tabela e proponha **um**:

| O que ele disse | Especialista |
|---|---|
| "perco tempo cotando auto", "recotar", "comparar seguradora" | **Multicálculo Auto** |
| lead parado, retorno esquecido, renovação que escapa | **Vendas** |
| "o que eu tenho hoje", tarefa que some | **Secretário Geral** |
| proposta, beneficiário, venda que não foi implantada | **Cadastro** |
| quanto entrou, quanto devo, fechar o mês, repasse | **Financeiro** |
| funil que não reflete a venda, automação que ninguém entende | **CRM** |
| "respondo a mesma coisa o dia todo", bot, WhatsApp | **Atendimento** |
| conta nova, "não sei por onde começar" | **Implantação** (`/introducao`) |
| trazer histórico de outro sistema | **Migração**, sob demanda |

Duas dores empatadas: prefira a que acontece toda semana, tem passos estáveis e é **correr atrás, não aconselhar**. Pedido que não está na tabela: monte com o mesmo molde (passo 4).

A resposta passa por esta poda antes de virar proposta:

| Regra | Efeito |
|---|---|
| `AUTO` fora de `modules`, ou `cotacao-auto` sem ferramenta em `list_toolsets` | sem Multicálculo Auto, e diga por quê |
| `KOTERZAP` fora de `modules` | sem Atendimento |
| `GESTAO` fora de `modules` | sem Financeiro e sem Cadastro |
| `crmAccess: false` | sem Vendas, CRM e Secretário |
| `licensed: false` | diga antes: boa parte da escrita vai falhar |
| `porte: solo` | Vendas absorve o CRM, quando o CRM for pedido |
| cargo sem escrita em comissão | Financeiro com o aviso da ficha |
| Gestão e CRM vazios | Implantação vem primeiro. Numa conta montada ela não entra |

Faça a proposta em uma frase, e deixe ele trocar:

> "Pelo que você contou, o primeiro é o de Multicálculo Auto. Ele cota pessoa física, compara as ofertas e te entrega o texto para você mandar ao cliente. Monto esse, a gente prova num caso real, e só então vemos o próximo. Pode ser?"

**Não monte time.** Sete agentes logo de cara custam atenção e uso, e nenhum fica provado. Coordenador só faz sentido com dois ou três já provados.

## 4 · O molde da ficha: dez campos, nenhum opcional

Todo especialista nasce com os dez. Faltando um, o agente improvisa onde dói.

```
1  · Nome e quando me chamar             uma linha, na língua do corretor
2  · Com quem falo, meu indicador        um trabalho, um número que ele acompanha,
     e onde eu paro                      um ponto de parada
3  · Skills que eu carrego               nomes literais das skills do plugin
4  · O que eu posso                      os verbos, por objeto do Koter
5  · O que eu NÃO posso e para quem      a trava, com o encaminhamento (passo 7)
     mando
6  · Pré-requisito de tela               o que só o corretor faz, e o que trava
7  · Armadilhas do meu assunto           3 a 8, literais, com o conserto junto
8  · Por onde eu começo                  a primeira leitura, sempre leitura
9  · Regras que eu herdo                 o núcleo comum, copiado inteiro
10 · A conexão que eu uso                a URL ou o pacote, conforme a IA
```

**Campo 2 é a vaga de emprego.** "Cuido de cotação auto de pessoa física. Meu indicador é cotação parada. Paro em sinistro, recusa, ou se faltar dado depois de duas perguntas." Sem isso, o especialista é uma persona. Acrescente aqui o que o corretor disse na pergunta 4.

**Campo 7 não se inventa.** As fichas prontas trazem as armadilhas tiradas das skills. Especialista novo: vá buscá-las na seção "Armadilhas conhecidas" das skills que ele carrega.

**Campo 9 é igual em todos** e está no fim de `references/catalogo.md`. Vai inteiro em cada entrega: referência cruzada não sobrevive, cada ficha é lida sozinha.

**Cada regra na sua camada.** Fato fixo da corretora (comissão combinada, tom) vai nas instruções. Procedimento vai na skill. Prêmio, parcela e vigência vêm da ferramenta, sempre. "Nunca" vai na permissão da IA. Memória guarda preferência, nunca número.

## 5 · Campo 10: recorte onde a IA recorta, pacote onde não recorta

`?toolsets=` é o teto da conexão. **Corta assunto, não corta escrita**: toda conexão nasce gravando dentro do assunto dela. Quem separa ler de escrever é a permissão na IA (passo 6).

Recorte por especialista de verdade só existe onde a IA faz: **Claude Code por agente, tarefa agendada, n8n ou Make por nó.** Nesses lugares, com a URL do campo 10, a ferramenta de fora nem aparece.

No resto, use os três pacotes. Conexões que dividem área no mesmo cliente de IA podem se revogar, e o sintoma é 401 numa conexão que funcionava. Estes três não se tocam:

| Pacote | `?toolsets=` |
|---|---|
| **Venda** | `crm,crm-config,cotacao-auto` |
| **Dinheiro** | `gestao,gestao-config,gestao-contratos,gestao-comissao,gestao-financeiro` |
| **Operação** | `crm-automation,gestao-automacao,koterzap-configuracao,koterzap-atendimento` |

- Nunca deixe na URL um toolset que a conexão não concede: dá 400. Sem o módulo, tire o toolset.
- Claude Free tem uma conexão só: o pacote do módulo principal.
- A conexão inteira encosta em tudo. Só a Implantação usa, e ela pode derrubar os pacotes no mesmo cliente de IA.
- Monte a URL antes de conectar. Depois, trocar exige recriar o conector. `enable_toolset` e `disable_toolset` não ajudam na claude.ai.
- Quem conectou antes de a área existir precisa reconectar para ganhá-la. Confira sempre com `list_toolsets`.
- Cada URL é um login. Para quem nunca fez isso, comece com uma.

Não escreva número de ferramenta em ficha nenhuma: mande conferir com `list_toolsets`. O manual da conexão é `../introducao/references/conexao-por-modulo.md`.

Na fala com o corretor, nada de toolset:

> "Vou te passar um link do Koter só para venda. A IA escolhe melhor, e essa conexão nem enxerga sua comissão. Ela ainda grava lead, e por isso a gente deixa a escrita pedindo sua aprovação."

## 6 · Uma fonte, cinco entregas, e as permissões no primeiro dia

A ficha é uma só, em `references/catalogo.md`. Muda o suporte, nunca o conteúdo.

| Entrega | Quando | O que o corretor recebe | Como se confere |
|---|---|---|---|
| **A · Arquivo em Claude Code** | Claude Code, ou IA que lê arquivo de agente | um arquivo em `~/.claude/agents/`, com `mcpServers` | releia, e peça para listar os agentes |
| **S · Skill empacotada** | Claude, e o que aceita pasta com `SKILL.md` | um ZIP, subido uma vez | ele abre uma conversa e o especialista aparece |
| **B · Colar em Projeto** | Claude e ChatGPT, sem `SKILL.md` ou somando à S | o texto, com onde colar | ele confirma que colou |
| **G · Grok Bot** | Grok Bot | a primeira mensagem do Bot e as regras "perguntar antes" | ele pede ao Bot para listar o que guardou |
| **C · Colar na conversa** | qualquer chat, inclusive sem Koter | um bloco para guardar, e você veste o especialista aqui | conversa nova com o texto colado |

Formatos, moldes e o passo a passo por produto estão em `references/hospedeiros.md`. S e B combinam: a skill leva o procedimento, o Projeto leva a corretora. **Nunca prometa A sem ter escrito o arquivo.** Se a escrita falhar, caia para S, B ou C na mesma resposta, sem perguntar.

**C não é prêmio de consolação.** O texto colado no começo da conversa faz o mesmo trabalho: só não persiste.

**Permissão não fica para depois.** Logo depois de conectar, aplique a tabela por toolset de `references/hospedeiros.md`:

| Tipo | Permissão |
|---|---|
| Leitura | liberada |
| Escrita | "Precisa de aprovação" |
| Exclusão e desfazer | bloqueada |
| Portas de cuidado | "Precisa de aprovação", sempre, mesmo para quem liberou o resto |

As portas de cuidado alcançam o cliente da corretora: `crm_automation_save_automation`, `crm_automation_import_automation`, `gestao_automacao_save_management_automation`, `koterzap_configuracao_save_chatbot`, `koterzap_configuracao_save_chatbot_flow`, `koterzap_configuracao_import_chatbot`. Chatbot `FLOW` nasce ligado. IA que decide pela marcação da ferramenta não freia a maioria delas.

"Agente só de leitura" não é trava: é texto. Onde a IA dá permissão por ferramenta, ela é a trava. Onde não dá, diga isso ao corretor.

## 7 · O encaminhamento

Sem esta tabela, o corretor bate na trava e fica parado. Cada ficha leva as linhas dos outros, no campo 5:

| Se ele pedir | Quem resolve |
|---|---|
| cotar seguro auto, recotar, comparar ofertas, PDF da seguradora | **Multicálculo Auto** |
| proposta, beneficiário, campo de proposta, status, implantar a venda | **Cadastro** |
| comissão, evento de contrato, baixa, repasse, extrato, caixa, DRE, empréstimo, campanha | **Financeiro** |
| lead, retorno, venda, perda, renovação | **Vendas** |
| equipe, funil, origem, tag, motivo de perda, automação | **CRM** |
| número de WhatsApp, agente do cliente, bot, base de conhecimento, template | **Atendimento** |
| meu dia, e-mail, agenda, tarefa fora do Koter | **Secretário Geral** |
| conta nova, "não sei por onde começar" | **Implantação** (`/introducao`) |
| migrar de outro sistema, importar planilha, desfazer importação | **Migração** |
| cotar saúde | nenhum: não é aberto pelo MCP. O Atendimento configura o agente do KoterZap, que cota saúde no WhatsApp |

A frase tem sempre a mesma forma: **o que é, quem faz, e o que dizer a ele.**

> "Isso é funil, e funil é do especialista de CRM. Abre ele e diz 'quero uma etapa nova entre Proposta e Fechado'."

Se o especialista citado ainda não existe, diga isso: "esse ainda não montamos, quer que eu faça na mão e a gente anote para virar o próximo?"

## 8 · O Secretário Geral é outra coisa, e diga isso

Ele não carrega skill do Koter: e-mail, agenda e tarefa de fora não são do Koter. Tratá-lo como os outros é prometer integração que o plugin não tem.

O que ele tem de verdade é `crm_list_tasks` (`type: today | upcoming | pending`), a lista de retorno do corretor, e a **recomendação** de conectores da IA. Ele usa o toolset `crm`, que grava, então a escrita dele fica "Bloqueada" na IA.

> "O Secretário Geral não vem pronto: o Koter não guarda seu e-mail nem sua agenda. Ele já lê suas tarefas do Koter hoje. Para o resto, você conecta Gmail e Agenda na sua IA, e aí ele cruza as duas coisas. Monto assim mesmo?"

Nunca diga que conectou. Conectar é ato do corretor, na configuração da IA dele.

## 9 · Aplique e prove

Um só. Mostre a ficha preenchida com o que ele contou, entregue, conecte, aplique as permissões e faça ele trabalhar na frente do corretor.

| Entrega | A releitura |
|---|---|
| **A** | releia o arquivo, confira os **dez campos** e `name`, e peça para listar os agentes. Arquivo sem `name` é ignorado sem aviso |
| **S** | peça para abrir uma conversa nova e dizer a frase do assunto. Skill que não dispara: reveja a `description` |
| **B** | ele confirma que colou. Depois, conversa nova dentro do Projeto |
| **G** | "liste o que você guardou", e corrija |
| **C** | conversa nova com o texto colado |

A prova fecha a skill, com um caso real e conferindo no Koter:

> "Escreve só 'cota o gol do João' e confere o que ele pede. Se pedir tudo de uma vez, mostrar o espelho e esperar seu 'pode', está funcionando. Disse que criou? Abre o Koter e olha."

Disparar cotação gasta consulta, então essa prova pode parar no espelho. Em outro especialista, use uma tarefa real da dor que ele contou, na frase dele.

Configuração pronta e ninguém usando é onboarding que falhou. Para confiar de verdade, `koter-prova` monta a prova com casos dele. Para tirar mais do agente, `koter-superpoderes`.

**A confiança sobe por fluxo.** No primeiro mês, rascunho: o especialista prepara e o corretor faz. Depois, escrita com aprovação. "Sempre permitir" em escrita só fluxo a fluxo, depois da prova, e nunca nas portas de cuidado.

**Skill nasce do uso.** Corrigiu três coisas numa cotação? Diga "salve isso como skill". Toda correção vira linha de armadilha no campo 7.

## 10 · Depois, o próximo

Ofereça o próximo só quando o primeiro tiver passado na prova e o corretor tiver usado de novo por conta própria. Volte à resposta da pergunta 3: qual é a próxima dor? Monte da mesma forma, um por vez.

A cada novo especialista, reveja a conexão. Em Claude Code, recortes que se tocam (Secretário e Vendas, Cadastro e Financeiro) podem se revogar: se surgir 401, volte aos três pacotes.

## 11 · Rotina, se ele quiser

Só depois da prova, só em leitura. **Rotina agendada lê e entrega ao corretor.** Ela não envia nem grava.

- Primeira linha: "Antes de tudo, confirme que consegue ler o Koter. Se não conseguir, escreva só 'Koter fora' e pare."
- Nasce pausada, e o corretor liga uma a uma.
- Antes de agendar: quem é o dono, horário e fuso, de onde lê, o que entrega, e o que faz se a fonte faltar.
- Sem novidade, silêncio. Com novidade, poucas linhas: "Bom dia, 3 coisas hoje."
- Leva só a conexão dela, em hora quebrada (7:07).

Onde dá para agendar, por plano, está em `references/hospedeiros.md`.

## 12 · Estado

Grave em `.koter/onboarding.json` (`../introducao/references/estado.md`), no bloco da corretora:

```json
"especialistas": {
  "entrevista": { "ia": "claude", "plano": "pro", "dor": "cotar auto", "nunca": ["sinistro", "recusa"] },
  "criados": [
    { "nome": "multicalculo", "entrega": "S", "conexao": "venda", "provado": true }
  ],
  "proximo": "vendas",
  "recusados": ["secretario"],
  "conectores_sugeridos": ["gmail"],
  "em": "2026-11-03"
}
```

`entrega`: `A`, `S`, `B`, `G` ou `C`. `criados` são os que o corretor confirmou. **Recusado não se reoferece.** Nada de CPF, apólice ou valor aqui.

Ao reentrar, releia antes de recriar. Em A, o arquivo diz a verdade. Nas outras, o estado é tudo o que existe: pergunte em vez de afirmar.

## 13 · Onde esta skill encosta nas outras

| Ponte | O quê |
|---|---|
| `introducao` | dá o diagnóstico e o `porte`. Esta skill vem depois do ato 2, quando a pergunta vira "e agora, como eu uso isso todo dia?" |
| `koter-prova` | a prova antes de confiar |
| `koter-superpoderes` | como tirar mais do agente depois que ele roda |
| `koter-chatbot-ia` | o agente do cliente, que não é ficha deste catálogo |
| `references/catalogo.md` | as nove fichas e o campo 9 |
| `references/hospedeiros.md` | a sonda, a tabela por plano, as cinco entregas, as permissões por toolset e a rotina |

## Conferência

Nomes de tool, recortes e permissões conferidos no inventário e lidos no código do Koter em 03/11/2026, não executados. Formatos e planos das IAs vêm de páginas lidas na mesma data, sem teste em conta real.
Sem execução: a entrevista com corretor, as cinco entregas de ponta a ponta, o login a partir de `mcpServers`, a convivência de recortes que se tocam, o Koter no Grok Bot e a poda por cargo restrito.
O Secretário Geral nunca rodou com conector ligado. Indicadores e pontos de parada das fichas são sugestão, sem medição.
