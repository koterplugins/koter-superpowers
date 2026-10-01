---
name: koter-gestao-fundacao
description: Configura a fundação do módulo Gestão do Koter — o funil de status da proposta e as entidades de adesão — e confirma com o corretor os ramos e operadoras com que ele trabalha, lidos do catálogo global. Use quando pedirem para configurar o Gestão, ajustar as etapas/status da proposta, cadastrar entidade ou convênio de adesão, ou quando /introducao encaminhar para a primeira etapa da trilha do Gestão.
---

# koter-gestao-fundacao

A primeira etapa da trilha, e ela é **curta de propósito**. Numa corretora nova, quase tudo que a proposta precisa já existe no catálogo global do Koter: ramos, categorias (PF, PME, Adesão), operadoras e planos. O que a corretora cria é pouco — e é isso que esta skill faz.

**Ela termina com a configuração aplicada e conferida no Koter, nunca com uma explicação de tela.**

## 0 · Pré-requisitos

Handshake (`admin_cargos_fetch_admin_roles_context` com `include: ["myPermissions"]`), lendo em `myPermissions`: `companyId` para o estado, `modules` para saber se `GESTAO` está contratado.

**`GESTAO` fora de `modules`:** não configure nada. Vá para as três saídas do passo 1b da `introducao` e registre a lacuna.

**Permissões:** cheque `create:management-status`, `manage:management-status` e `create:management-entity` antes de escrever.

## 1 · Tudo que a proposta usa vem do catálogo global

Uma proposta grava ramo, categoria e operadora do **catálogo global do Koter** — comprovado com uma proposta real na Koter Day, que gravou ramo "Saúde", categoria "PME" e seguradora "Amil", todos do catálogo. O schema de `list_segment_catalog` confirma: as `insuranceCompanies` do ramo são *"o único conjunto válido para o insuranceCompanyId de save_proposal (a proposta tira segmento e categoria da seguradora)"*. O que antes se chamava modalidade (PF, PME, Adesão) hoje é a **categoria** do ramo, `segmentCategoryId`.

```
gestao_fetch_gestao_context                       → segments (27 globais), categories (lista plana, com segmentId), proposalFields
gestao_fetch_gestao_context(segmentId: <global>)  → proposalFields e campos personalizados daquele ramo
gestao_list_segment_catalog(segmentId)            → categories do ramo
gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"],
  segmentCategoryId | insuranceCompanySearch)     → seguradoras (um dos dois filtros é obrigatório)
```

> **O catálogo de seguradoras saiu do contexto.** Medido na Koter Day em 21/09/2026, depois da mudança: `gestao_fetch_gestao_context` devolve **42.525 caracteres**, contra 173.211 antes — as chaves `insuranceCompanies` e `insurers` não existem mais na resposta. Naquela medição o que pesava era a lista de modalidades (19.417 caracteres, 123 itens, 46% do total); em 30/09/2026 ela deu lugar a `categories`, a lista plana das categorias de todos os ramos, e o tamanho precisa ser medido de novo. Ainda não é uma tool de diagnóstico: chame quando for montar proposta ou resolver ids de ramo, não no retrato da conta.
>
> **A operadora se resolve pelo ramo**, sempre: `gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"], insuranceCompanySearch)`. A resposta é compacta — `{ id, name, segmentCategoryId }`, ~128 caracteres por item, com a paginação em `insuranceCompaniesPaging`. Em Saúde são **571 operadoras**: a 1ª página de 100 são 12.845 caracteres e a lista inteira daria ~71 KB. **Desde 01/10/2026 a lista exige `segmentCategoryId` ou `insuranceCompanySearch`** — sem nenhum dos dois, pedir `insuranceCompanies` é recusado (conferido na Koter Day em 01/10/2026: *"Para listar as seguradoras informe segmentCategoryId … ou insuranceCompanySearch"*; "amil" em Saúde trouxe só as 3 linhas Amil, sem São Camilo), e as páginas vão até 100. Prefira a busca, e `includeInsuranceCompanyImages: true` só se precisar do logo (com imagens são ~1.440 caracteres por item, ~800 KB a lista de Saúde — é a resposta de 854 KB de antes).
>
> ⚠️ **A busca ordena por relevância, mas ainda pode cair no meio da palavra.** Vem primeiro o nome exato, depois os nomes com alguma palavra começando pelo termo; só quando nada disso existe entram os que apenas contêm o termo ("São C**amil**o" contém "amil"). Não diferencia caixa nem acento — o que ajuda —, mas **mostre as opções ao corretor em vez de escolher a primeira**.

> ⚠️ **Ramo, seguradora e categoria da corretora não existem mais no MCP.** As tools de cadastro de ramo, seguradora e categoria da corretora, e as de vínculo entre a seguradora da corretora e a do catálogo, **foram removidas** em 21/09/2026, e `fetch_gestao_config_context` não devolve mais `segments`, `insurers` nem `categories`. Não procure por elas e não diagnostique "você já tem N operadoras" por esse caminho.
>
> **`management_` não quer dizer legado:** `management_status`, `management_entity` e `management_automation` continuam valendo e são o coração desta skill. Quem cortar pelo prefixo quebra o módulo.
>
> Consequência prática boa: sumiu o passo mais caro da fundação antiga, que fazia o corretor recadastrar operadora que o catálogo já tinha.

**Atenção ao espaço do id.** O `segmentId` das tools acima é sempre o **ramo global**. Se uma leitura vier vazia quando você esperava conteúdo, é quase sempre id do espaço errado — e o Koter devolve lista vazia em vez de erro.

## 2 · Detecção

```
gestao_config_fetch_gestao_config_context(include: ["statuses", "entities"])
```

Leia dela **duas coisas**:

| Campo | O que extrair |
|---|---|
| `statuses` | `name`, `position`, `default`, `defaultType` (`REVIEW` / `PENDING` / `IMPLANTED`) |
| `entities` | a contagem — pode ter centenas |

`segments`, `insurers` e `categories` não vêm mais neste contexto: eram o legado.

**Não confunda `categories` com `customFieldCategories`.** `categories` (em `fetch_gestao_context` e `list_segment_catalog`) são as categorias do ramo no catálogo global — PF, PME, Adesão. `customFieldCategories` é o agrupador dos campos no formulário e já vem preenchida pelo sistema mesmo numa conta zerada. Nenhuma das duas é assunto desta skill.

## 3 · Diagnóstico — em duas linhas

> "Seu Gestão hoje: **nenhum status de proposta cadastrado**. O resto — ramos, operadoras, planos — já vem pronto do catálogo do Koter. Então é montar seu funil e você já cadastra uma proposta."

- **Vazio** → modo criação.
- **Começado** → modo revisão. **Não proponha recriar o que existe.** Aponte só o que está torto.
- **Pronto** → confirme em uma frase e siga para `koter-gestao-campos`.

## 4 · O funil de status — o coração desta skill

É o que a proposta grava e o que muda de corretora para corretora.

Numa conta já rodando, os status padrão trazem `defaultType`: `REVIEW`, `PENDING`, `IMPLANTED` — o sistema usa em automação e relatório, então **nunca renomeie nem apague um `defaultType`**. A pergunta útil é concreta:

> "Quando uma proposta é recusada pela operadora, para onde ela vai hoje?"

### Conta zerada e conta com carteira são duas conversas

Numa conta zerada (`statuses: []`, o caso da Koter Day) o funil inteiro é seu para criar:

> "Da cotação até o cliente com carteirinha na mão, por quantas etapas a proposta passa aí?"

Crie na ordem em que ele falar com `gestao_config_save_management_status` sem `statusId` (só `name`; cada uma entra no fim da fila). Depois `gestao_config_reorder_management_statuses`, passando `order` como a **lista inteira** de `{ "id": ..., "position": n }`, com `position` começando em 0.

**Duas etapas que valem ser oferecidas por padrão:** *"Aguardando documentos"* e *"Em análise na operadora"*. Sem elas, proposta parada por documento que o cliente não mandou fica misturada com proposta parada na operadora, e o corretor não enxerga qual das duas está matando o mês. Nomes que também costumam faltar: *Cancelada*, *Recusada pela operadora*, *Vigente*.

**Marcar o papel do status é o passo que fecha o funil.** Na criação, `save_management_status` aceita só `name`; `defaultType` só vale na edição, então o papel vem depois:

```
gestao_config_save_management_status(statusId, name, defaultType: "REVIEW" | "PENDING" | "IMPLANTED" | null)
```

`name` é obrigatório — **repita o nome atual para não renomear sem querer**. Só um status por papel em cada corretora: comprovado na Koter Day, marcar `IMPLANTED` num segundo status foi recusado com *"O papel IMPLANTED já pertence ao status «Implantada» (<id>). Remova o papel dele antes de atribuir a outro."* — a mensagem entrega o nome e o id de quem tem, então **não adivinhe: leia o erro e conte ao corretor**.

**Funil sem `IMPLANTED` não conta venda em lugar nenhum** — nem em analytics, nem na apuração de campanha, nem na renovação. Desde 01/10/2026 `fetch_gestao_config_context` avisa isso em `notes`: *"Nenhum status tem o papel IMPLANTED: o funil não conta nenhuma venda…"*. Depois de criar o funil, pergunte qual etapa significa "vendido de verdade" e marque:

> "Qual dessas etapas quer dizer que a venda entrou mesmo? É ela que vai contar no relatório e puxar a renovação."

### Numa conta que já tem proposta, mexer no funil é mexer no histórico

Meça antes de propor qualquer coisa: `gestao_list_proposals(pageSize: 1)` devolve o `total` em uma chamada, e com `statusIds` devolve quantas estão em cada etapa. **Diga o número antes de tocar** — é a regra 5 do plugin.

| O que ele quer | O que de fato acontece | O que fazer |
|---|---|---|
| **renomear etapa** | renomeia para todo mundo, inclusive no histórico das propostas antigas. "Em análise" vira "Na operadora" também nas de janeiro | tudo bem na maioria dos casos, mas **diga** que vale para trás |
| **apagar etapa** | é onde mora a proposta de alguém. Existe `gestao_config_transfer_proposals_status`, e é essa tool existir que diz o caminho: **transfira antes, apague depois** (`gestao_config_delete_gestao_config_records` com `kind: "status"` recusa status com proposta, o status padrão e status que uma automação usa) | conte quantas estão lá, pergunte para onde vão, transfira, então apague |
| **reordenar** | seguro: posição é visual | pode |
| **acrescentar etapa** | seguro, e é quase sempre a resposta certa | prefira isto a renomear |

**A saída boa é quase sempre acrescentar, não renomear.** Funil de corretora que roda há dois anos reflete como ela trabalha, e o corretor que vê o histórico mudar de nome debaixo dele perde a confiança no que você fizer depois. O que **sempre** vale conferir, mesmo em conta madura, é o `defaultType`: funil sem `IMPLANTED` não conta venda em lugar nenhum, e isso é conserto, não reforma.


## 5 · Entidades — só para quem vende adesão

Entidade é o convênio ou associação da venda por adesão, e **é da corretora mesmo**: `save_proposal` grava `entityId` a partir da lista dela.

> "Você vende por adesão? Por quais entidades?"

`gestao_config_save_management_entity` sem `entityId` (só `name`). **Se ele não vende adesão, pule e diga que pulou.** Com centenas já cadastradas, não pergunte nada — só confirme que está lá.

## 6 · Com quem ele trabalha — pergunte, mas não cadastre

> "Você vende o quê hoje — saúde, odonto? E com quais operadoras você fecha negócio?"

**Isso não vira cadastro: vira estado.** A `koter-proposta` usa essa resposta para filtrar o catálogo na hora de escolher a operadora, e a `koter-gestao-comissoes` para saber por qual tabela começar. Guarde os nomes no `.koter/onboarding.json` e siga.

Dois cuidados ao casar os nomes dele com o catálogo, mais tarde:

- **O catálogo é grande, a resposta não precisa ser.** São 571 operadoras em Saúde. Com `insuranceCompanySearch` você lê 1 KB; sem ele, 12,8 KB por página; com `includeInsuranceCompanyImages: true`, 800 KB. Peça imagem só quando for mostrar logo.
- **Busca por pedaço do nome ainda pode mentir.** A busca põe o nome exato primeiro, mas quando nada começa pelo termo ela cai em quem só o contém ("São C**amil**o"). Compare nome inteiro, normalizando acento e caixa.

## 7 · Regras que não se quebram

- **Nome é único por empresa** em status e entidade. Antes de criar, procure na lista do passo 2.
- **Nunca apague sem ele mandar.** `gestao_config_transfer_proposals_status` move **todas** as propostas de um status para outro (a própria tool se marca "IMPACTO ALTO") — só com pedido explícito, e diga quantas vão se mover **antes**.
- **Falhou uma, continue as outras.** Junte os erros e conte no fim.

## 8 · Validação — a skill não termina sem isso

Chame `gestao_config_fetch_gestao_config_context` **de novo** e compare com o retrato do passo 3:

> "Pronto: funil de 7 etapas, de Cotação a Cancelada, com Aguardando documentos e Em análise na operadora separadas."

Algo não apareceu na releitura: **diga**. Não dê por feito o que você não viu.

## 9 · Estado e próxima

Grave em `.koter/onboarding.json`: a etapa como `concluida`, o funil criado, os ramos e operadoras que ele citou (a `koter-proposta` e a `koter-gestao-comissoes` vão precisar) e qual status ficou com `defaultType: IMPLANTED`.

Depois ofereça a próxima em até 4 opções:

- **`koter-gestao-campos`** — o que ele anota na planilha e o Koter ainda não tem *(recomendada: o campo precisa existir antes da primeira proposta)*
- `koter-proposta` — cadastrar uma proposta agora e ver de pé
- `koter-gestao-vendedores` — quem vende e quem lidera quem
- parar por aqui, retomo quando você voltar

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Leitura volta vazia sem dar erro | `segmentId` do espaço errado | use o ramo global do `fetch_gestao_context` |
| Skill manda cadastrar operadora | procurou as tools de seguradora da corretora, que sumiram | a operadora vem do catálogo; não cadastre |
| Status novo aparece no lugar errado | criar sempre põe no fim | `reorder_management_statuses` com a lista inteira |
| Funil montado por MCP sem REVIEW/PENDING/IMPLANTED | `save_management_status` sem `statusId` só cria com nome | `save_management_status` com `statusId` e `defaultType`, repetindo o `name` atual |
| "Não consigo marcar IMPLANTED" | o papel já é de outro status | o erro diz o nome e o id; tire de lá primeiro |
| Relatório sem a etapa de recusa | falta status de recusa | crie e reordene |
| Confundiu categoria do ramo com categoria de campo | `categories` é PF/PME/Adesão do catálogo; `customFieldCategories` agrupa campos | nenhuma das duas é desta skill |
