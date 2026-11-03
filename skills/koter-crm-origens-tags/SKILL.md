---
name: koter-crm-origens-tags
description: Configura origens de lead, tags e motivos de perda no CRM do Koter. Use quando pedirem para cadastrar canal de aquisição, criar tags, arrumar motivos de perda ou medir de onde vem o cliente.
---

# koter-crm-origens-tags

A etapa barata e de retorno alto: três listas curtas que decidem o que a corretora consegue medir depois. **Termina com as listas aplicadas e conferidas, nunca com uma explicação de tela.**

## 0 · Pré-requisitos

`koter-crm-fundacao` rodada: origem tem times permitidos, então as equipes precisam existir antes.

Permissões: criar e editar origem, tag e motivo de perda.

## 1 · A separação que evita metade da bagunça

| Conceito | Responde | Quantos por lead | Muda com o tempo |
|---|---|---|---|
| **Origem** | de onde ele veio | um | não |
| **Tag** | o que ele é agora | vários | sim |
| **Etapa** | onde ele está no processo | uma | sim |

Se uma tag responde "em que ponto está", ela devia ser etapa. Se responde "de onde veio", devia ser origem. Diga isso ao corretor uma vez, no começo, e a lista de tags dele encolhe sozinha.

## 2 · Detecção

```
crm_config_fetch_crm_config_context
```

Traz `origins` (com `allowedTeams` e **`leadsCount`**), `tags`, `lossReasons` e `enabledInterests`.

`leadsCount` é o dado mais útil da tela: origem cadastrada com 0 lead há meses é origem que ninguém usa, e provavelmente não devia existir. Mas **`leadsCount` mede o passado, não a intenção**: origem zerada pode ser canal que ele vai ligar semana que vem. Mostre o número, não conclua sozinho.

## 3 · Origens: o conjunto que se paga

**Origem serve para uma coisa só: decidir onde gastar dinheiro e tempo.** Duas origens que nunca vão levar a decisões diferentes são uma origem só.

| Origem | Por que existe separada |
|---|---|
| **Indicação** | costuma ser o canal que mais converte; nunca entra em régua fria |
| **Carteira / Cross-sell** | já é cliente; outro produto, outro ciclo |
| **Tráfego pago** | tem custo por lead mensurável; exige resposta em minutos |
| **Site / orgânico** | intenção maior que tráfego pago, volume menor |
| **WhatsApp** | chegou pelo número da corretora sem campanha |
| **Parceiro / assessoria** | tem repasse de comissão: muda a economia da venda |
| **Prospecção própria** | trabalho do vendedor, não custo de mídia |

**Corretora solo e pequena** vive de indicação e carteira, e muitas vezes não tem tráfego pago nenhum. Não cadastre canal que ele não usa: origem vazia na lista é ruído no formulário de todo lead novo.

Só duas perguntas, em opções:

- **Você paga por lead hoje?** Tráfego pago / só indicação e carteira / os dois.
- **Tem parceiro ou subcorretor que te manda cliente?** Cria `Parceiro`, e na assessoria amarra uma equipe a ela.

`crm_config_save_origin` (sem `originId`) **exige** `name` e `teamIds` na criação; **lista vazia = todas as equipes**. Na edição, `name` e `teamIds` vão juntos e a lista substitui a atual inteira; repita o que não muda. `active: false` tira a origem das opções de lead novo sem apagar nada. Renomear leva junto os leads que já usavam o nome antigo. Restringir origem a uma equipe é o jeito de separar lead de parceiro do lead do comercial.

### Origem duplicada é recusada

> **`crm_config_save_origin` deduplica.** Medido na corretora de demonstração em 21/09/2026: com "Tráfego pago" já existindo, criar `"tráfego  Pago"` (caixa diferente, acento diferente, espaço a mais) foi **recusado**. A mensagem atual tem esta forma: *"Já existe uma origem equivalente a "tráfego  Pago": "Tráfego pago" (<id>). Use a existente: maiúsculas, acentos e espaços não diferenciam origens."*

A mensagem entrega o nome **e o id** da origem que já existe. Então, ao receber essa recusa, **não crie nada e não invente nome novo: use o id que veio no erro.**

E o lead grava o **nome canônico do catálogo**, não o que você digitou. Medido: um lead criado com `origin: "trafego pago"` nasceu com `origin: "Tráfego pago"` no histórico.

## 4 · Tags: poucas e úteis

Por família, e só as aplicáveis:

- **Produto**: lidos de `enabledInterests` e dos ramos que ele já vende. **Não pergunte** o que a fundação do Gestão já respondeu.
- **Contratação**: `PME`, `Adesão`, `Individual`, `Empresarial 30+`.
- **Relacionamento**: `Cliente`, `Ex-cliente`, `Indicador`. "Ex-cliente" é a tag mais subestimada da corretora: é a lista de recuperação mais barata que ela tem.
- **Bloqueio**: `Aguardando documento`, `Sem contato`.

**Não crie tag de temperatura.** O lead já tem percepção nativa `COLD` / `WARM` / `HOT`, e a automação já sabe mudá-la com `CHANGE_PERCEPTION`. Tag "quente/morno/frio" duplica um campo que existe e que o funil já mostra.

**Não crie tag que duplica origem**, com uma exceção, e ela é deliberada: quem passou pelo assistente de CRM na tela pode ter a origem "Tráfego pago" **e** a tag "Tráfego Pago", mantidas em sincronia pela automação "Rastrear tráfego pago". Isso é espelho, não duplicata, e existe porque a tag aparece onde a origem não aparece. Se encontrar esse par, **não proponha eliminar sem olhar as automações**: pode ser de propósito.

### Três coisas sobre nome de tag

1. **`crm_config_save_lead_tag` (sem `tagId`) devolve a tag existente** quando o nome bate no mesmo escopo. Medido: criar "Saúde" de novo devolveu o mesmo id, sem duplicar. É seguro repetir.
2. **A comparação ignora caixa, mas não acento.** Medido: "saude" criou uma tag nova ao lado de "Saúde". Normalize o acento antes de criar.
3. **`Transbordo` é do sistema.** Não se cria nem se renomeia tag com esse nome, e ela não sai por `crm_config_delete_crm_config_records`. Ela serve de condição de automação; quem a coloca é o transbordo da fila (ver `koter-crm-automacao`).

E o aviso que salva automação:

> **`ADD_TAG` e `REMOVE_TAG` recebem o NOME da tag, não o id.** Renomear uma tag quebra em silêncio toda automação que a use.

Ao criar tag que vai virar gatilho, evite acento e caixa inconsistente no nome, e diga ao corretor que aquele nome virou contrato.

## 5 · Motivos de perda: só valem se mudam uma decisão

Lista mínima útil, com o problema que cada um denuncia:

| Motivo | Problema que ele revela |
|---|---|
| Preço acima do orçamento | qualificação |
| Fechou com concorrente | proposta ou velocidade |
| Sem retorno do cliente | follow-up |
| Fora do perfil / sem elegibilidade | origem |
| **Desistiu de contratar** | não é perda para concorrência: não confunda com as de cima |
| **Documentação não entregue** | **perda evitável, e a mais importante de medir** |

A demonstração já vem com os quatro primeiros. **Acrescentar os dois últimos custa duas chamadas e é o que torna o gargalo nº 1 visível**: sem "Documentação não entregue", essas perdas viram "sem retorno do cliente" e o problema fica invisível para sempre. Medido na corretora de demonstração: criados com `crm_config_save_loss_reason`, e usados logo depois no `outcome` `LOSS` de `crm_save_lead`, que gravou `SALE_NOT_COMPLETED` com o motivo no histórico do lead.

Motivo de perda é da corretora inteira, não tem equipe nem escopo. E agora ele também dispara automação: gatilho `SALE_NOT_COMPLETED` com condição em `saleNotCompletedReasonId`, na `koter-crm-automacao`. O id do motivo vira contrato dessa automação, e `crm_config_delete_crm_config_records` com `kind: "loss_reason"` remove em definitivo.

### Em conta com histórico, o problema é o oposto: sobra motivo

**`crm_config_save_loss_reason` não deduplica de jeito nenhum**, nem de caixa, como origem e tag fazem. Então lista de motivo em corretora antiga cresce por acúmulo, e o estrago é de relatório: o gargalo nº 1 fica partido em dois e nenhum dos dois parece grande o bastante para alguém agir.

Medido numa corretora real em 22/09/2026: **18 motivos, com quatro pares sobrepostos.**

| O par | Por que passou despercebido |
|---|---|
| "Não tem interesse" × "Não tem interesse" | **texto idêntico, ids diferentes**: só se enxerga comparando a lista com ela mesma |
| "Desistência" × "Desistência do cliente" | sinônimo, não duplicata de caixa |
| "Valor alto" × "Preço muito alto" | idem |
| "Cliente não atende telefone" × "Sem contato/Não atende" | idem |

**Procure sinônimo, não só caixa.** É a checagem 7 do passo 2c da `/introducao`, e é a única das sete que a normalização do backend não pega.

**E não conserte sozinho.** Apagar um motivo deixa sem motivo os leads que o usavam, e nenhuma tool junta dois motivos; `crm_list_leads` também não filtra por motivo (lido no código em 03/11/2026, não executado). Vale a regra 4 inteira: mostre os pares ao corretor e deixe ele mandar.

> "Você tem 18 motivos de perda e quatro pares dizem a mesma coisa, como 'Valor alto' e 'Preço muito alto'. Separados, nenhum dos dois mostra o tamanho do problema. Daqui para frente, qual nome a equipe usa?"

## 6 · Validação

Releia `crm_config_fetch_crm_config_context` e mostre o antes e depois em números:

> "Suas origens agora são 6, sem duplicata; 9 tags em 4 famílias; e 6 motivos de perda, com 'Documentação não entregue', que é o que vai te mostrar quanto você perde por papel que o cliente não mandou."

Confira especificamente que **não sobrou par de nomes que só diferem por acento**. É o único erro desta skill que passa despercebido.

## 7 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, as listas aplicadas, e os nomes de tag que viraram gatilho de automação (a `koter-crm-automacao` precisa deles literais).

Próxima, em até 4 opções:

- **`koter-crm-campos`**: o que ele pergunta no primeiro contato e o Koter ainda não guarda *(recomendada: o campo precisa existir antes do primeiro lead)*
- `koter-crm-lead`: cadastrar um lead agora e ver o funil de pé
- `koter-crm-automacao`: o que passa a rodar sozinho
- parar por aqui

## Unificar duas origens, sem perder o histórico

Conta antiga ainda pode ter duas origens quase iguais, criadas antes da normalização. Dá para juntá-las de verdade:

```
crm_config_delete_crm_config_records(kind: "origin", id: <a que sai>, confirm: true, moveLeadsToOriginId: <a que fica>)
    → { movedLeads: n }
```

**Origem com lead só sai se você disser para onde os leads vão.** Sem `moveLeadsToOriginId`, a remoção é recusada. `confirm: true` é obrigatório, e só vai depois de o corretor confirmar.

**Antes de escolher qual sobrevive, descubra qual nome a automação usa.** Leia `crm_automation_list_automations` e procure os passos `CONDITION` com `field: "origin"`. Condição que guarda o id da origem removida é reapontada sozinha para a que fica; condição escrita com o nome não é, então a origem que fica é a que esse `value` já cita.

E dá para olhar os leads de uma origem antes de mexer:

```
crm_list_leads(origins: ["Tráfego pago"])   → filtro pelo nome exato como está em origins do contexto
```

Todo lead devolvido traz `origin`, então a conferência depois da unificação é uma chamada só.

Diga ao corretor o que aconteceu, com o número:

> "Juntei as duas 'Tráfego pago' numa só: os 2 leads da duplicada foram para a que a sua régua já usa. Agora todo mundo que entra por tráfego dispara o follow-up de 15 minutos."

Tag duplicada é outra conversa: `crm_config_delete_crm_config_records` com `kind: "lead_tag"` não remaneja nada, e apagar a tag que uma automação escreve com `ADD_TAG` quebra a automação. Confira antes.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Duas origens quase iguais no relatório | criadas antes da normalização | `crm_config_delete_crm_config_records` (`kind: "origin"`) com `moveLeadsToOriginId` junta as duas e devolve `movedLeads` |
| `crm_config_save_origin` recusado na criação | já existe origem equivalente | use o id que a própria mensagem entrega |
| Tag duplicada só por acento | a comparação de tag ignora caixa, mas não acento | normalize o acento antes de criar |
| Automação parou de disparar depois de arrumar nomes | `ADD_TAG`/`REMOVE_TAG` guardam o nome | releia as automações e reescreva o nome nelas |
| Recusa ao criar ou editar tag `Transbordo` | o nome é reservado do sistema | escolha outro nome; use `Transbordo` só como condição |
| Origem com `leadsCount: 0` | pode ser canal novo, não canal morto | mostre o número, não conclua |
| Formulário de lead cheio de origem que ninguém usa | canais cadastrados "por garantia" | só o que ele usa de verdade |
| Tag de temperatura convivendo com percepção | duplica campo nativo | use `CHANGE_PERCEPTION` |

## Conferência

Parâmetros e mensagens conferidos contra o código de `crm-config` em 03/11/2026, por leitura, sem execução; a recusa de origem usa hoje aspas retas, não as angulares do ensaio. As medições citadas vêm de ensaios anteriores e não foram refeitas.
