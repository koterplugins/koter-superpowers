# A passada única — do primeiro "oi" à corretora funcionando

As três trilhas (`trilha-gestao.md`, `trilha-crm.md`, `trilha-koterzap.md`) dizem **a ordem dentro de cada módulo**. Este arquivo diz **a ordem entre elas**, e é ele que faz o corretor viver uma conversa só em vez de três onboardings encostados.

A regra que organiza tudo: **o que depende de outra pessoa sai na frente**, mesmo que o resto venha depois. Passo de tela e aprovação da Meta levam dias; configuração por MCP leva minutos. Entregar o passo de tela no começo é o que faz os dois relógios correrem juntos.

---

## Os quatro atos

```
ATO 0 · Handshake e diagnóstico           uma sessão, ~5 min, nenhuma escrita
ATO 1 · Gestão até a primeira proposta    koter-gestao-fundacao → -campos → koter-proposta
ATO 2 · CRM até o primeiro lead           koter-crm-fundacao → -origens-tags → -campos → koter-crm-lead
ATO 3 · O que roda sozinho                comissão, repasse, automação, KoterZap, chatbot
```

O corretor sai do ato 1 com **uma proposta cadastrada por ele**, e do ato 2 com **um lead cadastrado por ele**. Antes disso, nada do ato 3 é oferecido — configuração avançada em cima de uma ferramenta que ele nunca usou é o jeito mais confiável de perder o corretor.

### E quando ele já usou

Esse destino pressupõe conta nova, e **conta nova é a minoria**. Numa corretora que já rodou o ano inteiro, "a primeira proposta" e "o primeiro lead" aconteceram muito antes de o plugin existir, e pedir um cadastro de teste queima a credibilidade que o ato 0 acabou de ganhar.

O sinal é o volume que o ato 0 já leu — `crm_list_leads(pageSize: 1)` e `gestao_list_proposals(pageSize: 1)`, duas chamadas, o `total` de cada. **E ele é por módulo, não pela conta**: o caso mais comum medido numa corretora real em 22/09/2026 foi CRM com 274 leads e Gestão com 2 propostas, as duas rascunho. Um módulo em produção, o outro no começo, na mesma corretora e no mesmo dia.

| `total` do módulo | O ato daquele módulo |
|---|---|
| zero | o ato original: instalar até a primeira de verdade |
| baixo e recente | pule a instalação; vá direto à `koter-proposta` ou à `koter-crm-lead` |
| alto | **o ato vira leitura.** Abra o registro mais recente com ele, confira ali o que o 2c consertou, e siga |

E o caso que rende mais: **proposta presa em rascunho** (`gestao_list_proposals(draft: true)`). Não é cadastrar a primeira — é destravar a que ele já tentou, e a trava quase sempre é uma das duas da `koter-proposta`: beneficiário obrigatório, ou campo personalizado que virou obrigatório depois de a proposta existir.

Numa conta em uso, o ato 3 **pode ser oferecido antes**, porque o pré-requisito dele nunca foi a configuração: era o corretor ter usado a ferramenta. Ele já usou.

---

## Ato 0 · Handshake e diagnóstico

Uma sessão curta, e ela termina com **duas entregas**: o mapa de maturidade e **a lista de tarefas de tela dele**.

É aqui que entra a única mudança de ordem que esta revisão trouxe: **o diagnóstico do KoterZap (`koterzap_configuracao_list_whatsapp_instances`) roda no ato 0**, junto com o do Gestão e o do CRM — não lá na frente, quando a trilha do KoterZap chegar.

O motivo é concreto: conectar o número em Cloud API **não tem tool de MCP** e depende da Meta, não do plugin. Se o corretor descobre isso no ato 3, ele espera dias com tudo o mais pronto. Se descobre no ato 0, ele resolve em paralelo enquanto o Gestão é configurado. Uma leitura, zero escrita, e muda o cronograma dele.

**O que o ato 0 entrega, em voz alta:**

> "Seu Gestão está em branco, seu CRM já tem quatro automações ligadas de fábrica, e você não tem número de WhatsApp conectado. Três coisas só você pode fazer, e nenhuma depende de mim — vou te dar agora para você tocar em paralelo: *(lista)*. Enquanto isso, a gente monta o Gestão."

---

## A lista de tela — a única coisa que só o corretor faz

Ela está documentada na skill onde dói. Aqui ela aparece **cedo**, que é o que faltava.

| # | O que | Por que o plugin não faz | Quando dizer | Trava o quê |
|---|---|---|---|---|
| 1 | **Conectar o número em Cloud API** | não existe tool de MCP para criar instância de **nenhum** tipo | ato 0, se `list_whatsapp_instances` vier vazio ou só com Evolution | `SEND_WHATSAPP_TEMPLATE` nos dois motores de automação |

**Eram três até 21/09/2026**, e as outras duas saíram por motivos diferentes.

**Gerar as parcelas da proposta** deixou de ser passo de tela: `gestao_comissao_generate_proposal_installments` cria, `list_proposal_installments` mostra, e a baixa do recebível também é por MCP — o ciclo do dinheiro fecha inteiro dentro do plugin, medido de ponta a ponta na Koter Day (lote de R$ 1.470 pago). **Nada no ato 1 deve mais mandar o corretor à tela por causa de parcela.**

**Aprovar o template na Meta** saiu da `/introducao` por decisão de escopo, não porque virou tool. Ele continua sendo tarefa do corretor e continua sem tool — mas só passa a importar quando alguém for armar régua de mensagem, no ato 3, e o assunto inteiro pertence à `koter-zap-fundacao`. Na passada única ele é **uma frase de orientação junto da tarefa 1**, dita uma vez: nunca um item rastreado, nunca uma checagem, nunca uma volta para perguntar se saiu. Rastrear não rende nada — o plugin não cria o template, não acelera a Meta, e `list_meta_message_templates` só responde se já houver instância Cloud API, que é exatamente o que falta na conta em que a tarefa 1 apareceu.

**Os dois passos menores também caíram:** marcar `defaultType` de status agora é `edit_management_status` (`koter-gestao-fundacao`) e subir extrato é `import_bank_statement` (`koter-gestao-conciliacao`). Nenhum dos dois é passo de tela.

**A regra de tom:** diga o passo de tela **antes** de ele virar frustração, e diga o que ele destrava. "Isso é na tela" no fim de uma configuração soa a desculpa; no começo, soa a plano.

---

## Ato 1 · Gestão até a primeira proposta

`koter-gestao-fundacao` → `koter-gestao-campos` → **`koter-proposta`**.

Só três. `-vendedores`, `-comissoes`, `-financeiro` e o resto ficam para o ato 3, porque **`sellerId` é opcional no cadastro de proposta** (comprovado na Koter Day) — nada disso é pré-requisito para ele cadastrar a primeira venda.

O ato fecha com a proposta relida e as parcelas geradas na mesma frase:

> "Proposta da Maria cadastrada, 3 vidas, Amil 400. Já gerei as parcelas: a primeira é o agenciamento, R$ 1.350 de repasse para você, e depois R$ 60 por mês. Quer que eu marque a primeira como recebida quando a Amil pagar?"

---

## Ato 2 · CRM até o primeiro lead

`koter-crm-fundacao` → `koter-crm-origens-tags` → `koter-crm-campos` → **`koter-crm-lead`**.

`-automacao` e `-renovacao` ficam para o ato 3: a primeira depende da resposta da tarefa 1 da lista de tela, e a segunda depende de existir proposta com vigência — que só passou a existir no fim do ato 1.

**A ponte que fecha os dois atos**, e é ela que faz o corretor entender que é um produto só: o lead do ato 2, quando ganho, vira a proposta do ato 1 por `gestao_set_proposal_leads`. Mostre isso acontecendo uma vez. É o momento em que o Koter deixa de ser dois sistemas.

---

## Ato 3 · O que roda sozinho

Aqui a ordem deixa de ser fixa e passa a ser **a prioridade que ele deu no passo 1 da roteadora** ("comissão ou atendimento?").

| Se ele disse | A sequência |
|---|---|
| **Comissão** | `koter-gestao-vendedores` → `-comissoes` → `-repasse` → `-financeiro` → `-baixa-parcelas` → `-conciliacao` → `-campanhas` → `-emprestimos-antecipacao` |
| **Atendimento** | `koter-crm-automacao` → `koter-crm-renovacao` → `koter-zap-fundacao` → `koter-chatbot-fluxo` → `koter-zap-conhecimento` → `koter-chatbot-ia` |

**E o ato 3 tem uma saída que não é de configuração:** `koter-especialistas`, que monta os agentes especialistas dentro da IA dele. Ofereça **depois do ato 2** e antes do resto do ato 3, porque é ela que faz o corretor parar de recomeçar a cada conversa — e porque a partir daí quem conduz cada assunto é o especialista dele, não mais a roteadora. Corretora solo recebe cinco; corretora com vendedores, seis.

As duas convergem em `koter-gestao-automacao` (o que o Gestão já roda sozinho), que é rápida e fecha o assunto "o que acontece sem eu mandar".

Quem não escolheu nenhuma: comece por comissão. É o que o corretor mais erra sozinho e o que mais rende no primeiro mês.

**Ordem dentro do KoterZap, quando a tarefa 1 não foi feita:** `koter-chatbot-fluxo` antes de `koter-zap-fundacao`. O bot se monta, valida e simula inteiro **sem número conectado**, e fica pronto esperando. Diga o atalho em voz alta — "vou deixar o bot pronto antes do número, porque conectar o WhatsApp é na tela e não depende de mim".

---

## Onde uma trilha encosta na outra

Toda dependência entre módulos passa por aqui. Se uma skill filha precisar de algo desta tabela e não achar no estado, ela **lê do Koter**, nunca pergunta de novo.

| Da trilha | Para | O que atravessa | Onde nasce |
|---|---|---|---|
| KoterZap | CRM e Gestão | existe Cloud API? | `koter-zap-fundacao`; o diagnóstico do ato 0 já responde. O template da Meta **não** atravessa aqui: ele só é conferido no ato 3, quando a régua de mensagem for montada |
| CRM | Gestão | lead ganho → proposta (`gestao_set_proposal_leads`) | `koter-crm-lead` |
| Gestão | CRM | vigência → tarefa de renovação (gatilho `DATE_FIELD` sobre `coverageStart`) | `koter-crm-renovacao`, e só existe se houver proposta do ato 1 |
| Gestão | CRM e KoterZap | ramos e operadoras com que ele trabalha | `koter-gestao-fundacao`, passo 6 — vira estado, não cadastro |
| CRM | KoterZap | equipes e funil, que o `HANDOFF` e o `CREATE_LEAD` do bot usam | `koter-crm-fundacao` |
| Roteadora | todas | o **porte** da operação (solo, com vendedores, assessoria) | passo 1 da roteadora, perguntado **uma vez só** |

O porte é o que mais se repetia: três skills perguntavam a mesma coisa com palavras diferentes. Agora é da roteadora, mora em `perfil.porte`, e `koter-gestao-vendedores` e `koter-crm-fundacao` **confirmam em vez de perguntar**.

---

## Retomar do meio

O corretor volta dias depois, em outra IA, sem o arquivo de estado. A passada única tem que sobreviver a isso, e sobrevive porque **o diagnóstico do ato 0 é idempotente**: ele relê o Koter e reconstrói o mapa inteiro.

O que o arquivo guarda é só o que nenhuma leitura recupera — porte, prioridade, lacunas adiadas, a ferramenta que ele usa no lugar do módulo que não tem, e **se a tarefa de tela já foi oferecida**, com a data, para não oferecer duas vezes. O estado dela em si não se guarda: `list_whatsapp_instances` responde.

Ao reabrir, abra pelo que falta, não pelo que passou:

> "Você parou depois da primeira proposta. Faltam três passos para a comissão sair — e as parcelas da proposta da Maria já estão geradas, esperando a primeira baixa."
