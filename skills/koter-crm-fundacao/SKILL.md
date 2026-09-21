---
name: koter-crm-fundacao
description: Configura a fundação do CRM do Koter — as equipes e o funil de cada equipe. Use quando pedirem para configurar o CRM, criar ou arrumar o funil de vendas, criar etapa de funil, criar equipe, separar funil de renovação ou de cross-sell, ou quando /introducao encaminhar para a primeira etapa da trilha do CRM.
---

# koter-crm-fundacao

A primeira etapa da trilha do CRM, e a única que muda a estrutura. **Ela termina com o funil aplicado e conferido no Koter, nunca com uma explicação de tela.**

## 0 · Pré-requisitos

Handshake (`admin_cargos_get_my_effective_permissions`): `companyId` para o estado, `modules` para saber se `CRM` está contratado, `crmAccess` para saber se o próprio usuário entra no CRM.

**`CRM` fora de `modules`, ou `crmAccess: false`:** não configure nada. Vá para as três saídas do passo 1b da `introducao` e registre a lacuna.

**Permissões:** `create:team`, `create:lead-status`, `manage:lead-statuses`, `update:lead-status`. Faltando, diga de quem depende e siga com o que dá.

## 1 · A regra que decide tudo: funil é por equipe

`crm_config_list_lead_statuses` **exige** `teamId`, e cada equipe tem o seu conjunto de etapas. Na Koter Day, Comercial e Cross Selling têm funis completamente diferentes.

> **"Funil separado" e "equipe separada" são a mesma coisa.** Quem quer funil de renovação cria equipe de renovação. Quem quer funil de benefícios cria equipe de benefícios.

Duas consequências práticas:

1. **Criar funil custa criar equipe**, e equipe implica pessoas. Numa corretora solo isso é peso morto — decida com o corretor, não por padrão (passo 3).
2. Mover lead de um funil para outro é `TRANSFER_LEAD` entre equipes, e a automação precisa dizer em que etapa ele entra; sem `statusId` ele cai no `PENDING` da equipe de destino.

## 2 · Detecção — três leituras, não uma

`crm_config_fetch_crm_config_context` resolve quase tudo numa chamada, **mas esconde duas coisas que esta skill precisa**:

| O que você precisa | Onde está | Por que o contexto não serve |
|---|---|---|
| Equipes, funis por equipe, tags, origens, motivos de perda, campos, interesses, usuários atribuíveis | `crm_config_fetch_crm_config_context` | — |
| `defaultType` e `isDefault` de cada etapa | `crm_config_list_lead_statuses` por equipe | `funnelStagesByTeam` devolve só `id`, `name` e `position` |
| Membros da equipe e fila de distribuição | `crm_config_list_teams` | o contexto devolve só `id`, `name`, `category`, `active` |

**Leia as três antes de escrever qualquer coisa.** Propor "criar Venda Faturada" numa equipe que já tem a etapa `INVOICED_SALES` com outro nome é o erro mais fácil de cometer aqui.

## 3 · As três etapas que o sistema cria sozinho — e que você renomeia, nunca recria

**Toda equipe nova nasce com um funil de três etapas**, sem ninguém pedir. Comprovado na Koter Day: `crm_config_create_team` com a equipe "Renovação" devolveu, na leitura seguinte, exatamente isto:

| Etapa | `defaultType` | `isDefault` | O que o sistema faz com ela |
|---|---|---|---|
| Pendente | `PENDING` | `true` | onde cai lead novo sem etapa definida, e destino de `TRANSFER_LEAD` sem `statusId` |
| Venda Faturada | `INVOICED_SALES` | `true` | etapa de venda |
| Venda Não Realizada | `SALE_NOT_COMPLETED` | `true` | para onde `crm_mark_lead_loss` **move o lead sozinho** |

**Renomear preserva o `defaultType`.** Comprovado: "Pendente" virou "A renovar" e continuou `PENDING`; "Venda Faturada" virou "Renovado" e continuou `INVOICED_SALES`; "Venda Não Realizada" virou "Cancelado" e continuou `SALE_NOT_COMPLETED`.

Daí a regra desta skill:

> **Adapte o funil renomeando as três etapas de sistema e inserindo as do meio. Nunca crie uma etapa paralela a uma que tem `defaultType`.**

Criar "Renovado" do lado de "Venda Faturada" deixa a corretora com duas etapas de fechamento, e só uma delas o motor entende como venda.

*(No Gestão o `defaultType` existe mas nasce nulo e precisa ser marcado com `edit_management_status` — ver `koter-gestao-fundacao`. No CRM os tipos vêm de graça; o trabalho é só dar o nome certo.)*

## 4 · Quantas equipes — a decisão estruturante

**Uma pergunta só, e o porte não é ela.** O porte da operação já foi respondido no passo 1 da `/introducao` e mora em `perfil.porte` no estado (`introducao/references/estado.md`); a `koter-gestao-vendedores` lê o mesmo campo. Leia de lá e **confirme afirmando**:

> "Você me disse que tem três vendedores, então monto `Comercial` e `Cross Selling` e deixo a renovação fora disso por enquanto. Confere?"

Só pergunte se `perfil.porte` não existir — e então grave a resposta lá, para as outras skills não perguntarem de novo. `gestao_config_list_sellers` e `crm_config_list_assignable_users` já dão um palpite bom o bastante para você confirmar em vez de perguntar.

A **única** pergunta desta skill é a que nenhuma outra faz e nenhuma leitura responde:

> **Renovação: quem cuida?** — mesmo vendedor / pessoa dedicada / ninguém ainda.

O que cada porte cria:

| `perfil.porte` | Equipes | Observação |
|---|---|---|
| `solo` | uma só, `SELLER` | **não crie mais nada.** Quatro equipes para uma pessoa é peso morto |
| `com_vendedores` (pequena) | `Comercial` + `Cross Selling`, ambas `SELLER` | é o padrão que a própria demonstração traz |
| `com_vendedores` (com operação própria) | acima + `Implantação` (`OPERATIONAL`) + `Renovação` | só com pessoas reais para cada uma |
| `assessoria` | acima + uma equipe por parceiro/subcorretor | a origem do parceiro amarra nela |

**Equipe de renovação só se a resposta 2 for "pessoa dedicada".** Se for "mesmo vendedor" ou "ninguém ainda", não crie: a renovação vira rotina de tarefa no Gestão — é a `koter-crm-renovacao` que decide isso, e ela explica por quê.

### Armadilha de `sharedLeads`

`crm_config_create_team` aceita `sharedLeads`, **e a categoria sobrescreve**. Comprovado: equipe `OPERATIONAL` criada com `sharedLeads: false` nasceu com `sharedLeads: true`. `OPERATIONAL` sempre compartilha, `SELLER` nunca. Não prometa ao corretor um comportamento que a categoria vai desfazer — escolha a categoria pelo comportamento que ele quer.

`members` exige pelo menos um id, vindo de `crm_config_list_assignable_users`. Numa conta nova costuma haver só o dono.

## 5 · O funil de venda nova

O padrão do sistema é bom. **Duas inserções se pagam**, e são as duas únicas que esta skill propõe por conta própria:

```
Pendente → Prospecção → Qualificação → Proposta enviada → Negociação → Follow-up
  → Aguardando documentos      ←NOVA
  → Em análise na operadora    ←NOVA
  → Venda Faturada | Venda Não Realizada
```

Por que essas duas e não outras: são os dois lugares onde o lead fica parado **sem que ninguém saiba de quem é a bola**. Sem etapa separada, proposta travada por documento que o cliente não mandou fica misturada com proposta travada na operadora, e o corretor não enxerga qual das duas está matando o mês. Diga isso em uma frase quando propuser — a etapa só vale se ele entender o que ela mede.

**Se a corretora vende adesão**, insira `Elegibilidade confirmada` antes de `Proposta enviada`: sem vínculo com entidade não há venda, e descobrir isso depois da cotação é retrabalho garantido.

Numa conta com funil já cheio de leads, **revise, não recrie**. Aponte só o que falta.

### Funil de cross-sell

`Ofertar <produto A>` → `Ofertar <produto B>` → `Venda Não Realizada`, com os produtos lidos de `enabledInterests` e dos ramos que ele já vende — **não pergunte de novo** o que a fundação do Gestão já respondeu.

## 6 · Criar e ordenar — a armadilha que não dá erro

`crm_config_create_lead_status` **sempre põe a etapa no fim do funil**, depois das etapas de fechamento. Comprovado: "Reajuste recebido" criada numa equipe de 3 etapas nasceu na posição 4, atrás de "Venda Não Realizada".

E aqui está a parte silenciosa:

> **`crm_config_update_lead_status` com `position` não empurra as outras.** Comprovado na Koter Day: "Aguardando documentos" movida para a posição 6 ficou empatada com "Follow-up", que continuou na 6. Duas etapas na mesma posição, ordem indefinida, e **nenhum erro**.

Portanto, sempre, sem exceção:

1. crie todas as etapas novas (elas se empilham no fim);
2. renomeie as três de sistema, se for o caso;
3. chame `crm_config_reorder_lead_statuses` **com a lista inteira** da equipe, posições **começando em 1** (ao contrário do Gestão, que começa em 0);
4. releia com `crm_config_list_lead_statuses`.

`icon` e `theme` são obrigatórios na criação. `icon` é **um emoji**, não nome de ícone — "inbox" ou "file-text" aparecem como texto cru no funil. `theme` sai de: `default`, `navy`, `azure`, `violet`, `brightOrange`, `darkGreen`, `burgundy`, `darkSlate`.

Pares que funcionam: 🔍 azure (prospecção), 🎯 violet (qualificação), 📄 default (proposta), 🤝 darkGreen (negociação), 📎 brightOrange (documento), ⏳ navy (espera), 💰 darkGreen (faturado), ❌ burgundy (perdido).

## 7 · Duas etapas que cobram dado

`billingRequired` e `billingDateRequired` obrigam valor e data de faturamento quando o lead entra na etapa. Ligá-las na etapa de venda é o que garante que a corretora tenha número de vendas em vez de sensação — e é o que alimenta `billing` do lead.

**Mas ligar cobra de todo mundo, inclusive de quem está arrastando um card antigo.** Ofereça, explique o custo, e só ligue se ele disser que sim.

## 8 · Regras que não se quebram

- **Nunca apague etapa com lead dentro.** `crm_config_delete_lead_status` só sob pedido explícito, e diga antes quantos leads estão nela.
- **Nunca apague uma etapa `isDefault`.** O motor depende dela: sem `SALE_NOT_COMPLETED`, `crm_mark_lead_loss` não tem para onde mover o lead.
- **Renomear etapa é seguro para o motor** (o `defaultType` fica), **mas quebra automação que condiciona por nome.** As condições do motor guardam `statusId`, então renomear é seguro ali; o risco é texto de template e relatório que citam o nome antigo.
- **Falhou uma, continue as outras.** Junte os erros e conte no fim.

## 9 · Validação — a skill não termina sem isso

Chame `crm_config_list_lead_statuses` **de novo, por equipe** e compare com o retrato do passo 2. Diga o que mudou, em números:

> "Pronto: funil comercial de 10 etapas, com 'Aguardando documentos' e 'Em análise na operadora' separando os dois lugares onde o lead trava, e uma equipe de Renovação com funil próprio de 7 etapas."

Confira também que **nenhuma posição ficou repetida**. Se ficou, refaça o `reorder` — é o sintoma do passo 6.

## 10 · Estado e próxima

Grave em `.koter/onboarding.json` (formato em `introducao/references/estado.md`): a etapa como `concluida`, as equipes e etapas criadas, e as respostas das duas perguntas do passo 4 — a `koter-crm-automacao` e a `koter-crm-renovacao` vão precisar delas.

Depois ofereça a próxima em até 4 opções:

- **`koter-crm-origens-tags`** — de onde vem o lead e como ele é marcado *(recomendada: a origem precisa existir antes do primeiro lead, e antes de qualquer automação que filtre por ela)*
- `koter-crm-campos` — o que ele pergunta no primeiro contato e o Koter ainda não tem
- `koter-crm-lead` — cadastrar um lead agora e ver o funil de pé
- parar por aqui, retomo quando você voltar

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `crm_config_list_lead_statuses` recusa a chamada | `teamId` é obrigatório: não existe funil da corretora | liste as equipes primeiro |
| Etapa nova aparece depois de "Venda Não Realizada" | `create` sempre põe no fim | `reorder_lead_statuses` com a lista inteira |
| Duas etapas na mesma posição, sem erro | `update_lead_status` com `position` não empurra as outras | `reorder_lead_statuses` com a lista inteira |
| Corretora com duas etapas de fechamento | etapa nova criada ao lado de uma `isDefault` | renomeie a de sistema; apague a paralela só com pedido dele |
| `crm_mark_lead_loss` falha ou move para lugar estranho | a etapa `SALE_NOT_COMPLETED` foi apagada ou duplicada | releia `list_lead_statuses` e restaure a etapa de sistema |
| Equipe criada com `sharedLeads` diferente do pedido | a categoria sobrescreve: `OPERATIONAL` sempre compartilha | escolha a categoria pelo comportamento desejado |
| Ícone aparece como texto cru no funil | `icon` recebeu nome de ícone em vez de emoji | um único caractere emoji |
| `reorder` "funciona" mas a ordem sai errada | posições do CRM começam em **1**, não em 0 | primeira etapa = 1 |
