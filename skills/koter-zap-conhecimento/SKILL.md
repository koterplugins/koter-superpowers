---
name: koter-zap-conhecimento
description: Monta a base de conhecimento que o agente de IA do WhatsApp consulta para responder — carências, coparticipação, documentos, regras das operadoras — e confere se a pergunta do cliente encontra o trecho certo. Use quando pedirem para ensinar o bot, alimentar a IA, parar de responder as mesmas dúvidas, ou quando /introducao encaminhar para a base de conhecimento do KoterZap.
---

# koter-zap-conhecimento

A etapa em que o agente de IA deixa de inventar. **Termina com uma base indexada e com a busca conferida**: a pergunta que o cliente faria, digitada de verdade, trazendo o trecho certo.

É a única skill do KoterZap que **não depende de número conectado**. Dá para fazer inteira antes de existir WhatsApp.

## 0 · Pré-requisitos

Módulo `KOTERZAP`. Permissão `manage:chatbots`.

Faça **antes** de `koter-chatbot-ia`: a base entra na etapa de IA por id, e agente de IA sem base é agente que responde de cabeça — que é o defeito que esta skill existe para evitar.

## 1 · Detecção

```
koterzap_configuracao_list_knowledge_bases
koterzap_configuracao_list_knowledge_sources   (por base, se houver)
```

Na corretora nova vem `{ bases: [], total: 0 }` (comprovado na Koter Day). Não há base de fábrica.

## 2 · Quantas bases, e por que não uma só

A tentação é criar uma base chamada "Tudo". Não faça.

**A descrição da base é o que o agente lê para decidir se vai buscar ali.** Uma etapa de IA aceita até 10 bases, e o agente escolhe entre elas pela descrição. Base chamada "Informações gerais da corretora" nunca é consultada, porque nenhuma pergunta parece ser sobre isso.

O corte que funciona é **por pergunta que o cliente faz**, não por assunto interno:

| Base | Descrição que faz o agente buscar |
|---|---|
| Regras de planos e carências | "Carências, coparticipação, documentos e prazos... consulte quando o cliente perguntar quanto tempo até poder usar, o que cobre de início, se tem coparticipação" |
| Rede credenciada | "Hospitais, laboratórios e clínicas de cada operadora por cidade... consulte quando perguntarem se determinado hospital atende" |
| Pós-venda | "Segunda via de boleto, carteirinha, reembolso, inclusão de dependente... consulte quando quem fala já é cliente" |

**Comece com uma só**, a de carências e regras — é onde mora a maior parte das dúvidas repetidas. As outras nascem quando o corretor reclamar de uma pergunta que o bot errou.

## 3 · As três formas de alimentar

| Tool | Para quê | Limite |
|---|---|---|
| `upsert_knowledge_faq` | pergunta e resposta curtas, do jeito que o cliente pergunta | 500 caracteres na pergunta, 20 mil na resposta |
| `add_knowledge_text` | documento: tabela de carências, política, roteiro | 2 milhões de caracteres |
| `import_knowledge_url` | página pública da operadora | — |

Arquivo PDF e afins **só pela tela**; o MCP não sobe arquivo.

### FAQ primeiro, sempre

A FAQ é chaveada **pela pergunta**: repetir a mesma pergunta atualiza a resposta em vez de criar outra entrada (`created: false`). Isso faz dela a forma mais segura de alimentar, porque rodar a skill duas vezes não duplica nada.

Escreva a pergunta **como o cliente escreveria no WhatsApp**, não como o corretor a classificaria:

- ✅ "Quanto tempo depois de contratar eu já posso usar o plano?"
- ❌ "Prazos de carência contratual"

A busca é híbrida, vetorial e por texto. Pergunta escrita em linguagem de cliente casa com pergunta de cliente.

### No texto, separe os assuntos

`add_knowledge_text` aceita `<!-- quebra -->` para cortar o conteúdo em trechos. **Use em toda mudança de assunto.** Sem isso, um texto longo vira trechos cortados no meio de uma tabela, e o agente cita meia regra.

Tabela Markdown sobrevive bem à indexação e é o melhor formato para prazo, valor e faixa.

## 4 · A armadilha do relógio

> **Fonte gravada não está pesquisável na mesma hora.** Comprovado na Koter Day: `add_knowledge_text` e `upsert_knowledge_faq` devolvem a fonte com `status: "QUEUED"` e `indexPending: true`. `test_knowledge_search` **só enxerga versão já indexada**.

Quem grava e testa na sequência vê zero resultado e conclui que escreveu errado o conteúdo. Não escreveu: ainda está na fila.

**O jeito certo:** grave tudo, releia `list_knowledge_sources` até `indexPending: false`, e só então teste. Se ainda estiver na fila quando o corretor estiver esperando, diga que a indexação é assíncrona e ofereça conferir depois — não fique repetindo a busca.

`status` também pode vir com `errorCode`: fonte que falhou na extração não é fonte vazia, é fonte quebrada, e precisa de `reextract_knowledge_source`.

## 5 · Validação — a parte que ninguém faz

```
koterzap_configuracao_test_knowledge_search
```

Roda **a mesma busca que o agente faz**, e devolve os trechos com `score`, `sourceTitle` e `headingPath`.

**Teste com três perguntas que o corretor de fato recebe**, escritas como o cliente escreve. Não teste com o título da fonte — isso sempre acha, e não prova nada.

O que ler no resultado:

- **Trecho certo no topo** → pronto.
- **Trecho certo em quarto lugar** → o agente recebe 5 por padrão, então ainda funciona, mas o conteúdo está diluído. Corte o texto em mais trechos.
- **Nada, ou o trecho errado** → o conteúdo não cobre a pergunta. Adicione uma FAQ com a pergunta exata; é o conserto mais rápido que existe.

Cada chamada consome um embedding, então teste três perguntas, não trinta.

> Mostre o resultado ao corretor: "Perguntei 'quanto tempo até poder usar o plano' e ele achou a tabela de carências em primeiro lugar." É isso que transforma "alimentei a IA" em algo que ele acredita.

## 6 · O que não pôr na base

A base é lida por um robô que fala com cliente. Vale a mesma régua do canal:

1. **Tabela de comissão, margem, acordo com operadora.** O agente pode citar. Isso é informação interna, e vazar margem para o cliente é problema comercial de verdade.
2. **Dado de cliente.** Nome, CPF, condição de saúde. Base de conhecimento não é CRM.
3. **Preço fechado.** Valor muda por idade, cidade e mês. O agente tem ferramenta de cotação para isso — preço escrito na base é preço errado daqui a trinta dias.
4. **Promessa de cobertura.** "Cobre tudo", "sem carência" — o agente repete como se fosse regra, e vira problema de contrato.

**Regra prática:** se o texto não pode ser impresso e entregue a um cliente, não entra na base.

## 7 · Manutenção

A base envelhece, e envelhece calada. Duas rotinas que valem:

- **Versionamento existe.** `list_knowledge_source_versions` e `restore_knowledge_source_version` — dá para voltar atrás sem reescrever.
- **`write_knowledge_source_markdown` corrige uma fonte existente**; `add_knowledge_text` sempre cria outra. Confundir os dois enche a base de versões paralelas do mesmo texto, e a busca passa a devolver as duas.

Quando o reajuste anual mudar as regras, é `write_knowledge_source_markdown` na fonte que já existe — não uma fonte nova chamada "Carências 2027".

## 8 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, os ids das bases criadas e as perguntas que foram testadas com sucesso. A `koter-chatbot-ia` lê os ids para ligar na etapa de IA.

Próxima, em até 4 opções:

- **`koter-chatbot-ia`** — ligar a base num agente que atende *(recomendada)*
- `koter-chatbot-fluxo` — se o fluxo ainda não existe
- `koter-zap-fundacao` — se ainda não há número conectado
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Busca não acha o que acabou de ser gravado | indexação é assíncrona (`indexPending: true`) | esperar `false` em `list_knowledge_sources` |
| O agente nunca consulta a base | descrição genérica demais | descrição diz **quando** consultar, com as palavras do cliente |
| Trecho cortado no meio da tabela | texto longo sem `<!-- quebra -->` | separar por assunto |
| A mesma fonte aparece duplicada | `add_knowledge_text` usado para corrigir | `write_knowledge_source_markdown` |
| Fonte vazia na busca | falhou na extração, tem `errorCode` | `reextract_knowledge_source` |
| Resposta do bot está desatualizada | fonte nova criada ao lado da velha | apagar a velha, ou versionar a certa |
| Trecho certo descartado por "score baixo" | o `score` não é confiança de 0 a 1 — o melhor acerto veio 0,032 | ler pela **ordem**, nunca por corte de nota |

## Provado na Koter Day

Rodado em 21/09/2026 (na corretora de demonstração), na base "Regras de planos e carências", com a indexação já concluída.

**A indexação termina sozinha, e há como saber.** As duas fontes gravadas como `QUEUED` voltaram `status: "READY"`, `indexPending: false` e `indexedVersionId` igual ao `currentVersionId`. **É essa igualdade que diz que a busca já enxerga a versão atual** — `status: READY` com `indexedVersionId` atrasado significa que ela ainda responde pelo texto velho.

**`test_knowledge_search` achou.** "Quanto tempo de carência para parto?" devolveu 4 trechos, com `sourceTitle`, `headingPath`, `ordinal` e o conteúdo. O FAQ veio em primeiro, à frente da tabela — confirmando o "FAQ primeiro, sempre" do passo 3.

**O `<!-- quebra -->` funcionou.** A fonte de texto voltou como três trechos distintos, cada um com seu `headingPath` ("Carências padrão", "Redução e compra de carência", "Coparticipação"). A tabela de carências não foi cortada no meio.

**⚠️ O `score` não é uma nota de 0 a 1.** O melhor acerto veio `0.0325` e os outros `0.016`, `0.0159` e `0.0156`. São números pequenos mesmo quando a resposta está certa. **Nunca escreva uma regra do tipo "descartar abaixo de 0,5"** — leia pela ordem em que vieram, e julgue pelo texto.

**A resposta vem com aviso de conteúdo.** O retorno abre com um `notice` dizendo que o conteúdo foi enviado pela corretora ou importado de fora, e que é material de referência, nunca instrução. Vale como lembrete ao corretor de que a base é lida por um modelo: o que ele colar ali será lido como texto, não como ordem.
