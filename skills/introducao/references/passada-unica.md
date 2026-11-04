# A passada única: do primeiro "oi" à corretora funcionando

As trilhas (`trilha-gestao.md`, `trilha-crm.md`, `trilha-koterzap.md`) dizem **a ordem dentro de cada módulo**. Este arquivo diz **a ordem entre elas**, e é ele que faz o corretor viver uma conversa só em vez de três onboardings encostados.

A regra que organiza tudo: **o que depende de outra pessoa sai na frente**, mesmo que o resto venha depois. Passo de tela e aprovação da Meta levam dias; configuração por MCP leva minutos. Entregar o passo de tela no começo é o que faz os dois relógios correrem juntos.

---

## Os atos

```
ATO 0 · Handshake e diagnóstico           uma sessão, nenhuma escrita
ATO 1 · Gestão até a primeira venda       koter-gestao-fundacao → -campos → koter-proposta → koter-contrato
ATO 2 · CRM até o primeiro lead           koter-crm-fundacao → -origens-tags → -campos → koter-crm-lead
PONTO AUTO · Primeira cotação             koter-multicalculo-auto, só com AUTO em modules
ATO 3 · O que roda sozinho                comissão, recebimento, repasse, automação, KoterZap, chatbot
```

O corretor sai do ato 1 com **uma proposta cadastrada por ele e implantada**, e do ato 2 com **um lead cadastrado por ele**. Antes disso, nada do ato 3 é oferecido: configuração avançada em cima de uma ferramenta que ele nunca usou é o jeito mais confiável de perder o corretor.

### E quando ele já usou

Esse destino pressupõe conta nova, e **conta nova é a minoria**. Numa corretora que já rodou o ano inteiro, "a primeira proposta" e "o primeiro lead" aconteceram muito antes de o plugin existir, e pedir um cadastro de teste queima a credibilidade que o ato 0 acabou de ganhar.

O sinal é o volume que o ato 0 já leu: `crm_list_leads(pageSize: 1)` e `gestao_list_proposals(pageSize: 1)`, duas chamadas, o `total` de cada. **E ele é por módulo, não pela conta**: o caso mais comum medido numa corretora real em 22/09/2026 foi CRM com centenas de leads e Gestão com duas propostas, as duas rascunho. Um módulo em produção, o outro no começo.

| `total` do módulo | O ato daquele módulo |
|---|---|
| zero | o ato original: instalar até a primeira de verdade |
| zero, e ele traz carteira de planilha ou de outro sistema | fundação, depois `koter-importacao`. Ver "Quem vem de outro sistema" |
| baixo e recente | pule a instalação; vá direto à `koter-proposta` ou à `koter-crm-lead` |
| alto | **o ato vira leitura.** Abra o registro mais recente com ele, confira ali o que o 2c consertou, e siga |

E o caso que rende mais: **proposta presa em rascunho** (`gestao_list_proposals(draft: true)`). Não é cadastrar a primeira, é destravar a que ele já tentou, e a trava quase sempre é uma das duas da `koter-proposta`: beneficiário obrigatório, ou campo personalizado que virou obrigatório depois de a proposta existir.

Numa conta em uso, o ato 3 **pode ser oferecido antes**, porque o pré-requisito dele nunca foi a configuração: era o corretor ter usado a ferramenta. Ele já usou.

---

## Ato 0 · Handshake e diagnóstico

Uma sessão curta, e ela termina com **duas entregas**: o mapa de maturidade e **a lista de tarefas de tela dele**.

**O diagnóstico do KoterZap (`whatsappInstances` em `koterzap_configuracao_fetch_koterzap_config_context`) roda no ato 0**, junto com o do Gestão e o do CRM, não lá na frente, quando a trilha do KoterZap chegar. Com `AUTO` em `modules`, a leitura de `cotacao_auto_get_auto_insurer_availability` entra na mesma rodada.

O motivo é concreto: conectar o número em Cloud API **não tem tool de MCP** e depende da Meta, não do plugin. Se o corretor descobre isso no ato 3, ele espera dias com tudo o mais pronto. Se descobre no ato 0, ele resolve em paralelo enquanto o Gestão é configurado. Uma leitura, zero escrita, e muda o cronograma dele.

**O que o ato 0 entrega, em voz alta:**

> "Seu Gestão está em branco, seu CRM já tem automações ligadas de fábrica, e você não tem número de WhatsApp conectado. Isso só você pode fazer e não depende de mim, então vou te dar agora para você tocar em paralelo: *(lista)*. Enquanto isso, a gente monta o Gestão."

---

## A lista de tela: só o corretor faz

Ela está documentada na skill onde dói. Aqui ela aparece **cedo**, que é o que faltava.

| # | O que | Por que o plugin não faz | Quando dizer | Trava o quê |
|---|---|---|---|---|
| 1 | **Conectar o número em Cloud API** | não existe tool de MCP para criar instância de **nenhum** tipo | ato 0, se `whatsappInstances` vier vazio ou só com Evolution | `SEND_WHATSAPP_TEMPLATE` nos dois motores de automação |
| 2 | **Cadastrar credencial de seguradora de auto** | credencial não se cria nem se edita por MCP, e captcha também é só na tela | ato 0, com `AUTO` em `modules` e seguradora que ele usa em `MISSING` ou `SUSPENDED` | cotar auto naquela seguradora |

**Parcela de comissão não é tarefa.** O motor monta sozinho a expectativa de comissão depois do contrato e do acompanhamento ligado. Nada no ato 1 deve mandar o corretor gerar nada, nem por tela nem por tool.

**Aprovar o template na Meta** continua sendo tarefa do corretor e continua sem tool, mas só passa a importar quando alguém for armar régua de mensagem, no ato 3, e o assunto inteiro pertence à `koter-zap-fundacao`. Na passada única ele é **uma frase de orientação junto da tarefa 1**, dita uma vez: nunca um item rastreado, nunca uma checagem, nunca uma volta para perguntar se saiu.

**Outros dois passos também não são de tela.** Marcar `defaultType` de status é `gestao_config_save_management_status` com `statusId` (`koter-gestao-fundacao`), e subir extrato é `gestao_financeiro_import_bank_statement` (`koter-gestao-conciliacao`).

**A regra de tom:** diga o passo de tela **antes** de ele virar frustração, e diga o que ele destrava. "Isso é na tela" no fim de uma configuração soa a desculpa; no começo, soa a plano.

---

## Ato 1 · Gestão até a primeira venda

`koter-gestao-fundacao` → `koter-gestao-campos` → **`koter-proposta`** → **`koter-contrato`**.

Só quatro. `-vendedores`, `-comissoes`, `-financeiro` e o resto ficam para o ato 3, porque **`sellerId` é opcional no cadastro de proposta**: nada disso é pré-requisito para ele cadastrar a primeira venda.

**A proposta não carrega dinheiro, e mudar o status não implanta.** O contrato nasce só por `gestao_contratos_save_contract` com `proposalId`, e é dele que tudo o que é dinheiro lê. Por isso o ato fecha na implantação, não no cadastro. Implantar é ato real: diga isso antes. Sem movimento, ainda se desfaz com `gestao_contratos_reverse_contract_implantation`.

O ato fecha com a proposta relida e o contrato conferido na mesma frase:

> "Proposta da Maria cadastrada, *(N)* vidas, *(plano)*. Implantei: o contrato existe e a venda já conta. A comissão ainda não aparece porque o acompanhamento não está ligado. É o primeiro passo quando a gente for para o dinheiro."

Sem conexão com `gestao-contratos`, pare e peça reconexão. Sem contrato não há comissão.

---

## Ato 2 · CRM até o primeiro lead

`koter-crm-fundacao` → `koter-crm-origens-tags` → `koter-crm-campos` → **`koter-crm-lead`**.

`-automacao` e `-renovacao` ficam para o ato 3: a primeira depende da resposta da tarefa 1 da lista de tela, e a segunda depende de existir contrato com vigência, que só passou a existir no fim do ato 1.

**A ponte que fecha os dois atos**, e é ela que faz o corretor entender que é um produto só: o lead do ato 2, quando ganho, se liga à proposta do ato 1 por `gestao_set_proposal_links` (`leads`). Mostre isso acontecendo uma vez. É o momento em que o Koter deixa de ser dois sistemas.

---

## Ponto AUTO · A primeira cotação de auto

**Só para quem tem `AUTO` em `modules`** e enxerga `cotacao-auto` em `list_toolsets`. Sem isso, este ponto não existe na conversa. Quem cuida é a `koter-multicalculo-auto`, e o comando é `/multicalculo`.

Vem depois do ato 2, por dois motivos: é uma cotação real com CPF de um cliente de verdade, e ela vincula ao lead (`leadId`) só na criação. Se o corretor chegou aqui por causa de auto, pode vir logo depois do ato 0: quem vende auto não precisa esperar o Gestão para cotar.

| Antes de oferecer | Como conferir |
|---|---|
| Módulo e permissão | `AUTO` em `modules`, `app:auto-quote:create` em `permissions`, ou `cotacao-auto` em `list_toolsets` |
| A conexão mostra as ferramentas | conexão antiga não ganha área nova sozinha: reconecte marcando Multicálculo auto |
| Alguma seguradora dá para cotar | `summary` de `cotacao_auto_get_auto_insurer_availability`. Tudo `MISSING` ou `SUSPENDED` é a tarefa 2 da lista de tela |

O ponto fecha com um comparativo entregue **ao corretor**, por seguradora, e nada enviado ao cliente:

> "Cotei o *(veículo)* do João em *(N)* seguradoras. *(N)* responderam, *(N)* ainda sem resposta. O comparativo está aqui, para você mandar. Quem escolhe a oferta é você."

Três coisas a não dizer: que dá para cotar auto pelo WhatsApp (o agente do KoterZap não tem ferramenta de auto), que o link da cotação vai ao segurado (é tela interna), e que dá para cotar saúde por aqui (saúde pelo MCP não é aberta à corretora).

---

## Ato 3 · O que roda sozinho

Aqui a ordem deixa de ser fixa e passa a ser **a prioridade que ele deu no passo 1 da roteadora** ("comissão ou atendimento?").

| Se ele disse | A sequência |
|---|---|
| **Comissão** | `koter-gestao-vendedores` → `-comissoes` → `-financeiro` → `-baixa-parcelas` → `-repasse` → `-conciliacao` → `-campanhas` → `-emprestimos-antecipacao` |
| **Atendimento** | `koter-crm-automacao` → `koter-crm-renovacao` → `koter-zap-fundacao` → `koter-chatbot-fluxo` → `koter-zap-conhecimento` → `koter-chatbot-ia` |

**A sequência de comissão segue o caminho do dinheiro**, que está em `trilha-gestao.md`: ligar o acompanhamento e publicar as regras, receber, conferir, pagar. Numa corretora com vendas já implantadas, ligar o acompanhamento mexe na carteira: a `koter-gestao-comissoes` escolhe a data com ele.

**E o ato 3 tem uma saída que não é de configuração:** `koter-especialistas`, que monta um agente especialista dentro da IA dele. Ofereça **depois do ato 2** e antes do resto do ato 3, porque é ela que faz o corretor parar de recomeçar a cada conversa. **Comece por um especialista**, no assunto que dói toda semana: provar um fluxo vem antes de montar time.

As duas sequências convergem em `koter-gestao-automacao` (o que o Gestão já roda sozinho), que é rápida e fecha o assunto "o que acontece sem eu mandar".

Quem não escolheu nenhuma: comece por comissão. É o que o corretor mais erra sozinho e o que mais rende no primeiro mês.

**Ordem dentro do KoterZap, quando a tarefa 1 não foi feita:** `koter-chatbot-fluxo` antes de `koter-zap-fundacao`. O bot se monta, valida e simula inteiro **sem número conectado**, e fica pronto esperando. Diga o atalho em voz alta: "vou deixar o bot pronto antes do número, porque conectar o WhatsApp é na tela e não depende de mim".

---

## Quem vem de outro sistema

A `koter-importacao` traz o passado em dois atos: planeja sem gravar, depois confirma. Grava em silêncio, sem automação nem aviso, e mantém as datas originais. Ela não é etapa de todo mundo: entra quando o corretor traz carteira de planilha ou de outro sistema.

**A ordem é de dependência:**

1. Antes: `koter-gestao-fundacao`, e os vendedores que vão aparecer nas propostas.
2. Para trazer comissão junto: `koter-gestao-comissoes` antes, com regra publicada e acompanhamento ligado. Sem isso, as parcelas de prêmio entram e as comissões não: a própria linha avisa.
3. A importação segue a ordem do próprio Koter: `SELLERS`, depois `CONTACTS` e `LEADS`, depois `PROPOSALS`, com `FINANCE_ENTRIES` por último.
4. Depois: ato 3, com a carteira já dentro.

**Quando não usar:** venda nova é `koter-proposta` mais `koter-contrato`, e extrato de comissão da seguradora é `koter-gestao-baixa-parcelas`.

---

## Onde uma trilha encosta na outra

Toda dependência entre módulos passa por aqui. Se uma skill filha precisar de algo desta tabela e não achar no estado, ela **lê do Koter**, nunca pergunta de novo.

| Da trilha | Para | O que atravessa | Onde nasce |
|---|---|---|---|
| KoterZap | CRM e Gestão | existe Cloud API? | `koter-zap-fundacao`; o diagnóstico do ato 0 já responde. O template da Meta **não** atravessa aqui: ele só é conferido no ato 3, quando a régua de mensagem for montada |
| CRM | Gestão | lead ganho → proposta (`gestao_set_proposal_links`) | `koter-crm-lead` |
| Gestão | Dinheiro | proposta → contrato (`gestao_contratos_save_contract`) | `koter-contrato` |
| Gestão | CRM | fim de vigência → tarefa de renovação (`DATE_FIELD`, fonte `CONTRACT`, campo `endsAt`) | `koter-crm-renovacao`, e só existe se houver contrato do ato 1 |
| Gestão | CRM e KoterZap | segmentos e operadoras com que ele trabalha | `koter-gestao-fundacao`, passo 6: vira estado, não cadastro |
| CRM | KoterZap | equipes e funil, que o `HANDOFF` e o `CREATE_LEAD` do bot usam | `koter-crm-fundacao` |
| CRM | Auto | `leadId` e `contactId` da cotação, só na criação | `koter-multicalculo-auto` |
| Roteadora | todas | o **porte** da operação (solo, com vendedores, assessoria) | passo 1 da roteadora, perguntado **uma vez só** |

O porte é da roteadora, mora em `perfil.porte`, e `koter-gestao-vendedores` e `koter-crm-fundacao` **confirmam em vez de perguntar**.

---

## Retomar do meio

O corretor volta dias depois, em outra IA, sem o arquivo de estado. A passada única sobrevive a isso porque **o diagnóstico do ato 0 é idempotente**: ele relê o Koter e reconstrói o mapa inteiro.

O que o arquivo guarda é só o que nenhuma leitura recupera: prioridade, lacunas adiadas, a ferramenta que ele usa no lugar do módulo que não tem, e **a data em que cada tarefa de tela foi oferecida**, para não oferecer duas vezes. O estado delas em si não se guarda: `whatsappInstances` e `cotacao_auto_get_auto_insurer_availability` respondem.

Ao reabrir, abra pelo que falta, não pelo que passou:

> "Você parou depois da primeira venda. O contrato da Maria está implantado, e faltam três passos para a comissão dele aparecer."
