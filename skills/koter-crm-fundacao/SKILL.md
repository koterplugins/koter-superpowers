---
name: koter-crm-fundacao
description: Monta equipes e funil do CRM do Koter. Use quando pedirem para configurar o CRM, criar etapa ou equipe, separar funil de renovação ou cross-sell, ou quando /introducao encaminhar.
---

# koter-crm-fundacao

A primeira etapa da trilha do CRM, e a única que muda a estrutura. **Ela termina com o funil aplicado e conferido no Koter, nunca com uma explicação de tela.**

## 0 · Pré-requisitos

Handshake: `admin_cargos_fetch_admin_roles_context` com `include: ["myPermissions"]`. Leia em `myPermissions`: `companyId` para o estado, `modules` para saber se `CRM` está contratado, `crmAccess` para saber se o próprio usuário entra no CRM. Quando o cargo não alcança `admin-cargos`, o plano B é `list_toolsets`, que mostra o que a conexão enxerga.

**`CRM` fora de `modules`, ou `crmAccess: false`:** não configure nada. Vá para as três saídas do passo 1b da `introducao` e registre a lacuna.

**Permissões:** criar e editar equipe, criar e editar etapa de funil. Faltando alguma, diga de quem depende e siga com o que dá.

## 1 · A regra que decide tudo: funil é por equipe

Não existe funil da corretora: `funnelStagesByTeam`, em `crm_config_fetch_crm_config_context`, vem agrupado por equipe, e cada equipe tem o seu conjunto de etapas. Na corretora de demonstração, Comercial e Cross Selling têm funis completamente diferentes.

> **"Funil separado" e "equipe separada" são a mesma coisa.** Quem quer funil de renovação cria equipe de renovação. Quem quer funil de benefícios cria equipe de benefícios.

Duas consequências práticas:

1. **Criar funil custa criar equipe**, e equipe implica pessoas. Numa corretora solo isso é peso morto: decida com o corretor, não por padrão (passo 3).
2. Mover lead de um funil para outro é `TRANSFER_LEAD` entre equipes, e a automação precisa dizer em que etapa ele entra. Sem `statusId`, ele cai no `PENDING` da equipe de destino.

## 2 · Detecção: uma leitura, com os detalhes ligados

`crm_config_fetch_crm_config_context` resolve tudo numa chamada, **desde que você peça os detalhes que esta skill precisa**:

| O que você precisa | Onde está no contexto |
|---|---|
| Equipes, tags, origens, motivos de perda, campos, interesses, usuários atribuíveis | as partes `teams`, `tags`, `origins`, `lossReasons`, `customFieldDefinitions`, `interests`, `assignableUsers` |
| `defaultType` e `isDefault` de cada etapa | `funnelStages` (em `funnelStagesByTeam`), junto com ícone, cor e exigências de faturamento |
| Gerente, membros, fila, horários e transbordo | `teams` com `teamDetails: true` (`managerId`, `sharedLeads`, `queueOverflow` e `members`, em ordem de fila); sem ele, só `id`, `name`, `category`, `active` |

**Leia tudo isso antes de escrever qualquer coisa.** Propor "criar Venda Faturada" numa equipe que já tem a etapa `INVOICED_SALES` com outro nome é o erro mais fácil de cometer aqui.

## 3 · As três etapas que o sistema cria sozinho, e que você renomeia, nunca recria

**Toda equipe nova nasce com um funil de três etapas**, sem ninguém pedir. Medido na corretora de demonstração: `crm_config_save_team` (sem `teamId`) com a equipe "Renovação" devolveu, na leitura seguinte, exatamente isto:

| Etapa | `defaultType` | `isDefault` | O que o sistema faz com ela |
|---|---|---|---|
| Pendente | `PENDING` | `true` | onde cai lead novo sem etapa definida, e destino de `TRANSFER_LEAD` sem `statusId` |
| Venda Faturada | `INVOICED_SALES` | `true` | etapa de venda |
| Venda Não Realizada | `SALE_NOT_COMPLETED` | `true` | para onde `crm_save_lead` com `outcome` `LOSS` **move o lead sozinho** |

**Renomear preserva o `defaultType`.** Medido: "Pendente" virou "A renovar" e continuou `PENDING`; "Venda Faturada" virou "Renovado" e continuou `INVOICED_SALES`; "Venda Não Realizada" virou "Cancelado" e continuou `SALE_NOT_COMPLETED`.

Daí a regra desta skill:

> **Adapte o funil renomeando as três etapas de sistema e inserindo as do meio. Nunca crie uma etapa paralela a uma que tem `defaultType`.**

Criar "Renovado" do lado de "Venda Faturada" deixa a corretora com duas etapas de fechamento, e só uma delas o motor entende como venda.

*(No Gestão o `defaultType` existe mas nasce nulo e precisa ser marcado com `gestao_config_save_management_status` (com `statusId`): ver `koter-gestao-fundacao`. No CRM os tipos vêm de graça; o trabalho é só dar o nome certo.)*

## 4 · Quantas equipes: a decisão estruturante

**Uma pergunta só, e o porte não é ela.** O porte da operação já foi respondido no passo 1 da `/introducao` e mora em `perfil.porte` no estado (`introducao/references/estado.md`); a `koter-gestao-vendedores` lê o mesmo campo. Leia de lá e **confirme afirmando**:

> "Você me disse que tem três vendedores, então monto `Comercial` e `Cross Selling` e deixo a renovação fora disso por enquanto. Confere?"

Só pergunte se `perfil.porte` não existir, e então grave a resposta lá, para as outras skills não perguntarem de novo. `gestao_config_list_sellers` e `assignableUsers` de `crm_config_fetch_crm_config_context` já dão um palpite bom o bastante para você confirmar em vez de perguntar.

A **única** pergunta desta skill é a que nenhuma outra faz e nenhuma leitura responde:

> **Renovação: quem cuida?** Mesmo vendedor / pessoa dedicada / ninguém ainda.

O que cada porte cria:

| `perfil.porte` | Equipes | Observação |
|---|---|---|
| `solo` | uma só, `SELLER` | **não crie mais nada.** Quatro equipes para uma pessoa é peso morto |
| `com_vendedores` (pequena) | `Comercial` + `Cross Selling`, ambas `SELLER` | é o padrão que a própria demonstração traz |
| `com_vendedores` (com operação própria) | acima + `Implantação` (`OPERATIONAL`) + `Renovação` | só com pessoas reais para cada uma |
| `assessoria` | acima + uma equipe por parceiro/subcorretor | a origem do parceiro amarra nela |

**Equipe de renovação só se a resposta for "pessoa dedicada".** Se for "mesmo vendedor" ou "ninguém ainda", não crie: a renovação vira rotina de tarefa no Gestão. É a `koter-crm-renovacao` que decide isso, e ela explica por quê.

### Armadilha de `sharedLeads`

`crm_config_save_team` aceita `sharedLeads`, **e a categoria decide o valor**. Medido: equipe `OPERATIONAL` criada com `sharedLeads: false` nasceu com `sharedLeads: true`. `OPERATIONAL` sempre compartilha, `SELLER` nunca. Não prometa ao corretor um comportamento que a categoria vai desfazer: escolha a categoria pelo comportamento que ele quer. A categoria só vale na criação e não muda depois.

Na criação, `name`, `category` e `members` são obrigatórios. `members` exige pelo menos um id, vindo de `assignableUsers` no contexto, e a ordem da lista é a ordem inicial da fila. Numa conta nova costuma haver só o dono.

### A equipe inteira cabe numa chamada

`crm_config_save_team` carrega a configuração toda e salva em passos, nesta ordem: cadastro, fila, transbordo, horários de cada membro e `active`. Se um passo falha, os seguintes não rodam e a mensagem começa com *"Salvo antes da falha:"*, dizendo o que já ficou gravado. Conte isso ao corretor, não repita a chamada inteira às cegas.

Na edição, mande só o que muda. **`members` na edição substitui a lista**: quem sai perde a configuração de fila e horários, e quem entra vai para o fim da fila, recebendo 1 lead por rodada, todos os dias, a qualquer hora.

Rodízio, limite por rodada, horários e transbordo são distribuição, e moram na `koter-crm-automacao`, passo 8.

## 5 · O funil de venda nova

O padrão do sistema é bom. **Duas inserções se pagam**, e são as duas únicas que esta skill propõe por conta própria:

```
Pendente → Prospecção → Qualificação → Proposta enviada → Negociação → Follow-up
  → Aguardando documentos      ←NOVA
  → Em análise na operadora    ←NOVA
  → Venda Faturada | Venda Não Realizada
```

Por que essas duas e não outras: são os dois lugares onde o lead fica parado **sem que ninguém saiba de quem é a bola**. Sem etapa separada, proposta travada por documento que o cliente não mandou fica misturada com proposta travada na operadora, e o corretor não enxerga qual das duas está matando o mês. Diga isso em uma frase quando propuser: a etapa só vale se ele entender o que ela mede.

**Se a corretora vende adesão**, insira `Elegibilidade confirmada` antes de `Proposta enviada`: sem vínculo com entidade não há venda, e descobrir isso depois da cotação é retrabalho garantido.

Numa conta com funil já cheio de leads, **revise, não recrie**. Aponte só o que falta.

### Funil de cross-sell

`Ofertar <produto A>` → `Ofertar <produto B>` → `Venda Não Realizada`, com os produtos lidos de `enabledInterests` e dos ramos que ele já vende. **Não pergunte de novo** o que a fundação do Gestão já respondeu.

## 6 · Criar e ordenar: a armadilha que não dá erro

`crm_config_save_lead_status` sem `leadStatusId` **sempre põe a etapa no fim do funil**, depois das etapas de fechamento. Medido: "Reajuste recebido" criada numa equipe de 3 etapas nasceu na posição 4, atrás de "Venda Não Realizada".

E aqui está a parte silenciosa:

> **`crm_config_save_lead_status` com `leadStatusId` e `position` não empurra as outras.** Medido na corretora de demonstração: "Aguardando documentos" movida para a posição 6 ficou empatada com "Follow-up", que continuou na 6. Duas etapas na mesma posição, ordem indefinida, e **nenhum erro**. Em etapa `isDefault`, `position` é ignorado.

Portanto, sempre, sem exceção:

1. crie todas as etapas novas (elas se empilham no fim);
2. renomeie as três de sistema, se for o caso;
3. chame `crm_config_reorder_lead_statuses` **com a lista inteira** da equipe em `positions`, posições **começando em 1** (ao contrário do Gestão, que começa em 0);
4. releia `funnelStages` com `crm_config_fetch_crm_config_context` (`funnelStageTeamIds` com a equipe).

`icon` e `theme` são obrigatórios na criação. `icon` é **um emoji**, não nome de ícone: "inbox" ou "file-text" aparecem como texto cru no funil. `theme` sai de: `default`, `navy`, `azure`, `violet`, `brightOrange`, `darkGreen`, `burgundy`, `darkSlate`.

Pares que funcionam: 🔍 azure (prospecção), 🎯 violet (qualificação), 📄 default (proposta), 🤝 darkGreen (negociação), 📎 brightOrange (documento), ⏳ navy (espera), 💰 darkGreen (faturado), ❌ burgundy (perdido).

## 7 · Duas etapas que cobram dado

`billingRequired` e `billingDateRequired` obrigam valor e data de faturamento quando o lead entra na etapa. Ligá-las na etapa de venda é o que garante que a corretora tenha número de vendas em vez de sensação, e é o que alimenta `billing` do lead.

**Mas ligar cobra de todo mundo, inclusive de quem está arrastando um card antigo.** Ofereça, explique o custo, e só ligue se ele disser que sim.

## 8 · Regras que não se quebram

- **Nunca apague etapa com lead dentro.** `crm_config_delete_crm_config_records` (`kind: "lead_status"`) só sob pedido explícito; o próprio sistema recusa etapa em uso por leads, então mova os leads antes e diga quantos eram.
- **Nunca tente apagar uma etapa `isDefault`.** O sistema recusa, e o motor depende dela: sem `SALE_NOT_COMPLETED`, o `outcome` `LOSS` de `crm_save_lead` não tem para onde mover o lead.
- **Renomear etapa é seguro para o motor**, porque o `defaultType` fica. O risco é condição de automação escrita com o nome da etapa em vez do id, e texto de template e relatório que citam o nome antigo. Nas automações, use sempre o `statusId`.
- **Equipe com gente em fila própria de integração não exclui.** A recusa vem como *"Esta equipe tem pessoas na fila própria das integrações …. Tire essas pessoas das filas antes de excluir a equipe."* Fila própria é passo de tela (ver `koter-crm-automacao`, passo 8).
- **Falhou uma, continue as outras.** Junte os erros e conte no fim.

## 9 · Validação: a skill não termina sem isso

Chame `crm_config_fetch_crm_config_context` **de novo**, com `funnelStages`, e compare equipe por equipe com o retrato do passo 2. Diga o que mudou, em números:

> "Pronto: funil comercial de 10 etapas, com 'Aguardando documentos' e 'Em análise na operadora' separando os dois lugares onde o lead trava, e uma equipe de Renovação com funil próprio de 7 etapas."

Confira também que **nenhuma posição ficou repetida**. Se ficou, refaça o `crm_config_reorder_lead_statuses`: é o sintoma do passo 6.

## 10 · Estado e próxima

Grave em `.koter/onboarding.json` (formato em `introducao/references/estado.md`): a etapa como `concluida`, as equipes e etapas criadas, e a resposta sobre quem cuida da renovação. A `koter-crm-automacao` e a `koter-crm-renovacao` vão precisar dela.

Depois ofereça a próxima em até 4 opções:

- **`koter-crm-origens-tags`**: de onde vem o lead e como ele é marcado *(recomendada: a origem precisa existir antes do primeiro lead, e antes de qualquer automação que filtre por ela)*
- `koter-crm-campos`: o que ele pergunta no primeiro contato e o Koter ainda não tem
- `koter-crm-lead`: cadastrar um lead agora e ver o funil de pé
- parar por aqui, retomo quando você voltar

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Etapa nova aparece depois de "Venda Não Realizada" | criar sempre põe no fim | `crm_config_reorder_lead_statuses` com a lista inteira |
| Duas etapas na mesma posição, sem erro | `crm_config_save_lead_status` com `position` não empurra as outras | `crm_config_reorder_lead_statuses` com a lista inteira |
| Corretora com duas etapas de fechamento | etapa nova criada ao lado de uma `isDefault` | renomeie a de sistema; apague a paralela só com pedido dele |
| Perda (`outcome` `LOSS`) cai numa etapa que o corretor não esperava | há uma etapa paralela à `SALE_NOT_COMPLETED`, e o lead vai para a de sistema | releia `funnelStages`, renomeie a de sistema e apague a paralela só com pedido dele |
| Equipe criada com `sharedLeads` diferente do pedido | a categoria decide: `OPERATIONAL` sempre compartilha | escolha a categoria pelo comportamento desejado |
| *"category só vale na criação: a categoria de um time não muda."* | tentou trocar a categoria | crie outra equipe |
| Ícone aparece como texto cru no funil | `icon` recebeu nome de ícone em vez de emoji | um único caractere emoji |
| Reordenar "funciona" mas a ordem sai errada | posições do CRM começam em **1**, não em 0 | primeira etapa = 1 |

## Conferência

Parâmetros, enums e mensagens conferidos contra o código de `crm-config` em 03/11/2026, por leitura, sem execução. As medições citadas vêm de ensaios anteriores na corretora de demonstração e não foram refeitas nesta revisão.
