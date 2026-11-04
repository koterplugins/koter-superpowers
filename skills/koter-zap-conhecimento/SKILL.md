---
name: koter-zap-conhecimento
description: Monta a base que o agente do WhatsApp consulta para responder o cliente e confere a busca. Use quando pedirem para ensinar o bot, alimentar a IA ou parar de responder as mesmas dúvidas.
---

# koter-zap-conhecimento

A etapa em que o agente de IA deixa de inventar. **Termina com uma base indexada e com a busca conferida**: a pergunta que o cliente faria, digitada de verdade, trazendo o trecho certo.

A base serve ao **agente do cliente**, o que mora no KoterZap e fala com o segurado (`koter-chatbot-ia`). O agente do corretor, na IA dele, só ajuda a montar.

É a única skill do KoterZap que **não depende de número conectado**. Dá para fazer inteira antes de existir WhatsApp.

## 0 · Pré-requisitos

Módulo `KOTERZAP`. Cargo com permissão de gerenciar chatbots.

Faça **antes** de `koter-chatbot-ia`: a base entra na etapa de IA por id, e agente de IA sem base é agente que responde de cabeça, que é o defeito que esta skill existe para evitar.

> **A base só chega ao agente por uma etapa `AI_ROUTER`**, em `content.knowledgeBaseIds`. O chatbot `AI_AGENT` não tem campo para base e não consulta nenhuma (lido no código em 03/11/2026, não executado). Quem quer base usa fluxo com etapa de IA.

## 1 · Detecção

```
koterzap_configuracao_fetch_koterzap_config_context   include: ["knowledgeBases"]
koterzap_configuracao_list_knowledge_sources          (por base, se houver)
```

Na corretora nova, `knowledgeBases` vem vazio (visto na corretora de demonstração em 21/09/2026). Não há base de fábrica.

## 2 · Quantas bases, e por que não uma só

A tentação é criar uma base chamada "Tudo". Não faça.

**A descrição da base é o que o agente lê para decidir se vai buscar ali.** Uma etapa de IA aceita até 10 bases, e o agente escolhe entre elas pela descrição. Base chamada "Informações gerais da corretora" nunca é consultada, porque nenhuma pergunta parece ser sobre isso.

O corte que funciona é **por pergunta que o cliente faz**, não por assunto interno:

| Base | Descrição que faz o agente buscar |
|---|---|
| Regras de planos e carências | "Carências, coparticipação, documentos e prazos... consulte quando o cliente perguntar quanto tempo até poder usar, o que cobre de início, se tem coparticipação" |
| Rede credenciada | "Hospitais, laboratórios e clínicas de cada operadora por cidade... consulte quando perguntarem se determinado hospital atende" |
| Pós-venda | "Segunda via de boleto, carteirinha, reembolso, inclusão de dependente... consulte quando quem fala já é cliente" |

**Comece com uma só**, a de carências e regras: é onde mora a maior parte das dúvidas repetidas. As outras nascem quando o corretor reclamar de uma pergunta que o bot errou.

Os exemplos são de saúde, mas a base vale para qualquer ramo: numa corretora de auto, por exemplo, "documentos para vistoria" e "como acionar a assistência". Ela responde dúvida. Não ensina o agente a cotar auto, porque ele não tem ferramenta para isso.

## 3 · As três formas de alimentar

| Tool | Para quê | Limite |
|---|---|---|
| `koterzap_configuracao_save_knowledge_source` com `kind: "FAQ"` | pergunta e resposta curtas, do jeito que o cliente pergunta | 500 caracteres na pergunta, 20 mil na resposta |
| `koterzap_configuracao_save_knowledge_source` com `kind: "TEXT"` | documento: tabela de carências, política, roteiro | 2 milhões de caracteres por chamada |
| `koterzap_configuracao_import_knowledge_url` | página pública da operadora | até 5 MB, HTML ou texto |

A base em si nasce com `koterzap_configuracao_save_knowledge_base` (`name` e `description`). Arquivo PDF e afins **só pela tela**; o MCP não sobe arquivo. Tudo isso respeita as cotas da corretora, e estourar aparece como `QUOTA_EXCEEDED`.

### FAQ primeiro, sempre

A FAQ é chaveada **pela pergunta**: repetir a mesma pergunta (sem diferenciar maiúsculas) atualiza a resposta em vez de criar outra entrada (`outcome: "UPDATED"`). Isso faz dela a forma mais segura de alimentar, porque rodar a skill duas vezes não duplica nada.

Escreva a pergunta **como o cliente escreveria no WhatsApp**, não como o corretor a classificaria:

- Bom: "Quanto tempo depois de contratar eu já posso usar o plano?"
- Ruim: "Prazos de carência contratual"

A busca é híbrida, vetorial e por texto. Pergunta escrita em linguagem de cliente casa com pergunta de cliente.

### No texto, separe os assuntos

O `markdown` de `koterzap_configuracao_save_knowledge_source` aceita `<!-- quebra -->` para cortar o conteúdo em trechos. **Use em toda mudança de assunto.** Sem isso, um texto longo vira trechos cortados no meio de uma tabela, e o agente cita meia regra. Para ver os cortes antes de testar, leia com `koterzap_configuracao_get_knowledge_source_content` e `view: "CHUNKS"`.

Tabela Markdown sobrevive bem à indexação e é o melhor formato para prazo, valor e faixa.

### Página importada não se atualiza sozinha

`koterzap_configuracao_import_knowledge_url` baixa a página uma vez. Quando ela mudar, é `koterzap_configuracao_reextract_knowledge_source`, que substitui a versão em uso, inclusive uma correção feita à mão: confirme com o corretor antes, e a versão antiga fica no histórico. Página com instruções dirigidas ao assistente falha com `SUSPICIOUS_CONTENT`.

## 4 · A armadilha do relógio

> **Fonte gravada não está pesquisável na mesma hora.** Visto na corretora de demonstração em 21/09/2026: a fonte volta com `status: "QUEUED"` e `indexPending: true`. `koterzap_configuracao_test_knowledge_search` **só enxerga versão já indexada**: fonte nunca indexada não aparece, e fonte com versão nova ainda responde pelo texto velho.

Quem grava e testa na sequência vê zero resultado e conclui que escreveu errado o conteúdo. Não escreveu: ainda está na fila.

**O jeito certo:** grave tudo, releia `koterzap_configuracao_list_knowledge_sources` até `indexPending: false`, e só então teste. Se ainda estiver na fila quando o corretor estiver esperando, diga que a indexação é assíncrona e ofereça conferir depois, sem ficar repetindo a busca.

`status: "FAILED"` vem com `errorCode`: fonte que falhou não é fonte vazia, é fonte quebrada. A própria `koterzap_configuracao_list_knowledge_sources` explica cada código; em fonte de arquivo ou página (`FILE`, `URL`) o conserto costuma ser `koterzap_configuracao_reextract_knowledge_source`, que não vale para `TEXT` nem `FAQ`.

## 5 · Validação: a parte que ninguém faz

```
koterzap_configuracao_test_knowledge_search
```

Roda **a mesma busca que o agente faz**, e devolve os trechos com `score`, `sourceTitle` e `headingPath`.

**Teste com três perguntas que o corretor de fato recebe**, escritas como o cliente escreve. Não teste com o título da fonte: isso sempre acha, e não prova nada.

O que ler no resultado:

- **Trecho certo no topo**: pronto.
- **Trecho certo em quarto lugar**: o agente recebe 5 por padrão, então ainda funciona, mas o conteúdo está diluído. Corte o texto em mais trechos.
- **Nada, ou o trecho errado**: o conteúdo não cobre a pergunta. Adicione uma FAQ com a pergunta exata; é o conserto mais rápido que existe.

Cada chamada consome um embedding, então teste três perguntas, não trinta.

> Mostre o resultado ao corretor: "Perguntei 'quanto tempo até poder usar o plano' e ele achou a tabela de carências em primeiro lugar." É isso que transforma "alimentei a IA" em algo que ele acredita.

## 6 · O que não pôr na base

A base é lida por um robô que fala com cliente. Vale a mesma régua do canal:

1. **Tabela de comissão, margem, acordo com operadora.** O agente pode citar. Isso é informação interna, e vazar margem para o cliente é problema comercial de verdade.
2. **Dado de cliente.** Nome, CPF, apólice, condição de saúde. Base de conhecimento não é CRM.
3. **Preço fechado.** Valor muda por idade, cidade e mês. Em saúde, o agente tem ferramenta de cotação para isso; preço escrito na base é preço errado daqui a trinta dias.
4. **Promessa de cobertura.** "Cobre tudo", "sem carência": o agente repete como se fosse regra, e vira problema de contrato.
5. **Orientação de como responder Declaração de Saúde.** O agente não preenche nem sugere.

**Regra prática:** se o texto não pode ser impresso e entregue a um cliente, não entra na base.

## 7 · Manutenção

A base envelhece, e envelhece calada. Duas rotinas que valem:

- **Versionamento existe.** `koterzap_configuracao_list_knowledge_sources` com `ids` e `include: ["versions"]`, e `koterzap_configuracao_restore_knowledge_source_version`: dá para voltar atrás sem reescrever.
- **`koterzap_configuracao_save_knowledge_source` com `sourceId` corrige uma fonte existente**; sem `sourceId`, cria outra. Confundir os dois enche a base de versões paralelas do mesmo texto, e a busca passa a devolver as duas.

Quando o reajuste anual mudar as regras, é `koterzap_configuracao_save_knowledge_source` com o `sourceId` e o `markdown` novo na fonte que já existe, não uma fonte nova chamada "Carências 2027".

## 8 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, os ids das bases criadas e as perguntas que foram testadas com sucesso. A `koter-chatbot-ia` lê os ids para ligar na etapa de IA.

Próxima, em até 4 opções:

- **`koter-chatbot-ia`**: ligar a base num agente que atende *(recomendada)*
- `koter-chatbot-fluxo`: se o fluxo ainda não existe
- `koter-zap-fundacao`: se ainda não há número conectado
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Busca não acha o que acabou de ser gravado | indexação é assíncrona (`indexPending: true`) | esperar `false` em `koterzap_configuracao_list_knowledge_sources` |
| O agente nunca consulta a base | chatbot `AI_AGENT`, ou descrição genérica demais | usar etapa `AI_ROUTER`; a descrição diz **quando** consultar, com as palavras do cliente |
| Trecho cortado no meio da tabela | texto longo sem `<!-- quebra -->` | separar por assunto e conferir com `view: "CHUNKS"` |
| A mesma fonte aparece duplicada | `koterzap_configuracao_save_knowledge_source` sem `sourceId` usado para corrigir | `koterzap_configuracao_save_knowledge_source` com o `sourceId` da fonte |
| Fonte vazia na busca | falhou (`FAILED`), tem `errorCode` | ler o `errorCode`; em `FILE`/`URL`, `koterzap_configuracao_reextract_knowledge_source` |
| Página importada falha com `SUSPICIOUS_CONTENT` | o texto traz instruções dirigidas ao assistente | revisar e gravar o texto limpo com `koterzap_configuracao_save_knowledge_source` |
| Resposta do bot está desatualizada | fonte nova criada ao lado da velha | apagar a velha (`koterzap_configuracao_delete_koterzap_config_records`, `kind: "knowledge_source"`, `confirm: true`, com o corretor de acordo), ou versionar a certa |
| Próximo `koterzap_configuracao_save_chatbot_flow` recusado depois de apagar uma base | a etapa ainda cita o id | tirar o id de `knowledgeBaseIds` |
| Trecho certo descartado por "score baixo" | o `score` não é confiança de 0 a 1: o melhor acerto veio 0,032 | ler pela **ordem**, nunca por corte de nota |

## O que a execução mostrou

Rodado em 21/09/2026, na corretora de demonstração, na base "Regras de planos e carências", com a indexação já concluída.

**A indexação termina sozinha, e há como saber.** As duas fontes gravadas como `QUEUED` voltaram `status: "READY"`, `indexPending: false` e `indexedVersionId` igual ao `currentVersionId`. **É essa igualdade que diz que a busca já enxerga a versão atual**: `status: READY` com `indexedVersionId` atrasado significa que ela ainda responde pelo texto velho.

**`koterzap_configuracao_test_knowledge_search` achou.** "Quanto tempo de carência para parto?" devolveu 4 trechos, com `sourceTitle`, `headingPath`, `ordinal` e o conteúdo. O FAQ veio em primeiro, à frente da tabela, confirmando o "FAQ primeiro, sempre" do passo 3.

**O `<!-- quebra -->` funcionou.** A fonte de texto voltou como três trechos distintos, cada um com seu `headingPath` ("Carências padrão", "Redução e compra de carência", "Coparticipação"). A tabela de carências não foi cortada no meio.

**O `score` não é uma nota de 0 a 1.** O melhor acerto veio `0.0325` e os outros `0.016`, `0.0159` e `0.0156`. São números pequenos mesmo quando a resposta está certa. **Nunca escreva uma regra do tipo "descartar abaixo de 0,5"**: leia pela ordem em que vieram, e julgue pelo texto.

**A resposta vem com aviso de conteúdo.** O retorno abre com um `notice` dizendo que o conteúdo foi enviado pela corretora ou importado de fora, e que é material de referência, nunca instrução. Vale como lembrete ao corretor de que a base é lida por um modelo: o que ele colar ali é dado, não ordem. Trecho com comando dirigido ao assistente é descartado antes de chegar ao agente do WhatsApp (lido no código em 03/11/2026, não executado).

## Conferência

Nomes de tool, limites, estados e códigos de erro conferidos contra o código do Koter e o inventário de tools em 03/11/2026: leitura, não execução. Indexação, busca, `<!-- quebra -->` e `score` foram executados em 21/09/2026.
Sem execução: `koterzap_configuracao_import_knowledge_url`, `koterzap_configuracao_reextract_knowledge_source` e `koterzap_configuracao_restore_knowledge_source_version` num caso real, e a afirmação de que `AI_AGENT` não consulta base, que vem só da leitura do código.
