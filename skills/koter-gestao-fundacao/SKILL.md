---
name: koter-gestao-fundacao
description: Configura a fundação da Gestão no Koter, com funil de status da proposta e entidades de adesão. Use quando pedirem para configurar o Gestão, ajustar etapas da proposta ou cadastrar entidade.
---

# koter-gestao-fundacao

A primeira etapa da trilha, e ela é **curta de propósito**. Numa corretora nova, quase tudo que a proposta precisa já existe no catálogo global do Koter: segmentos, categorias (PF, PME, Adesão), operadoras e planos. O que a corretora cria é pouco, e é isso que esta skill faz.

**Ela termina com a configuração aplicada e conferida no Koter, nunca com uma explicação de tela.**

## 0 · Pré-requisitos

Handshake (`admin_cargos_fetch_admin_roles_context` com `include: ["myPermissions"]`), lendo em `myPermissions`: `companyId` para o estado, `modules` para saber se `GESTAO` está contratado. Se o cargo não alcança `admin-cargos`, o plano B é `list_toolsets`.

**`GESTAO` fora de `modules`:** não configure nada. Vá para as três saídas do passo 1b da `introducao` e registre a lacuna.

**Permissões:** criar e editar status e entidade pede cargo que gerencia a Gestão. Se a escrita for recusada, diga de quem depende.

## 1 · Tudo que a proposta usa vem do catálogo global

Uma proposta grava segmento, categoria e operadora do **catálogo global do Koter**. O schema de `gestao_list_segment_catalog` confirma: as `insuranceCompanies` do segmento são *"o único conjunto válido para o insuranceCompanyId de save_proposal"*. O que antes se chamava modalidade (PF, PME, Adesão) hoje é a **categoria** do segmento, `segmentCategoryId`.

```
gestao_fetch_gestao_context                       → segments, categories (lista plana, com segmentId), proposalFields
gestao_fetch_gestao_context(segmentId: <global>)  → proposalFields e campos personalizados daquele segmento
gestao_list_segment_catalog(segmentId)            → categories do segmento
gestao_list_segment_catalog(segmentId, include: ["insuranceCompanies"],
  segmentCategoryId, insuranceCompanySearch?)     → seguradoras da categoria (segmentCategoryId obrigatório)
```

> `gestao_fetch_gestao_context` não é tool de diagnóstico: chame ao montar proposta ou resolver ids de segmento, não no retrato da conta. As seguradoras não vêm nele.
>
> **A operadora se resolve pelo segmento**, sempre, com a categoria antes: sem ela volta *"Para listar as seguradoras informe segmentCategoryId (o id de uma categoria de categories); insuranceCompanySearch só afina a busca dentro dela."* A resposta é compacta, `{ id, name, managerName, segmentCategoryId }`, com a paginação em `insuranceCompaniesPaging`, até 100 por página. A mesma operadora pode aparecer duas vezes na mesma categoria, uma por administradora: `managerName` separa as duas, então **mostre a administradora ao corretor**. Use `includeInsuranceCompanyImages: true` só se precisar do logo.
>
> **A busca ordena por relevância, mas ainda pode cair no meio da palavra.** Vem primeiro o nome exato, depois os nomes com alguma palavra começando pelo termo; só quando nada disso existe entram os que apenas contêm o termo ("São C**amil**o"). **Mostre as opções ao corretor em vez de escolher a primeira.**

> **Segmento, seguradora e categoria da corretora não existem mais no MCP.** `gestao_config_fetch_gestao_config_context` não devolve `segments`, `insurers` nem `categories`. Não procure por elas.
>
> **`management_` não quer dizer legado:** `management_status`, `management_entity` e `management_automation` continuam valendo e são o coração desta skill.

**Atenção ao espaço do id.** O `segmentId` das tools acima é sempre o **segmento global**. Se uma leitura vier vazia quando você esperava conteúdo, é quase sempre id do espaço errado, e o Koter devolve lista vazia em vez de erro.

## 2 · Detecção

```
gestao_config_fetch_gestao_config_context(include: ["statuses", "entities"])
```

| Campo | O que extrair |
|---|---|
| `statuses` | `name`, `position`, `default`, `defaultType` (`REVIEW`, `PENDING`, `IMPLANTED`, `CANCELLED`) |
| `entities` | a contagem, que pode ter centenas |

**Não confunda `categories` com `customFieldCategories`.** `categories` (em `gestao_fetch_gestao_context` e `gestao_list_segment_catalog`) são as categorias do segmento no catálogo global. `customFieldCategories` é o agrupador dos campos no formulário. Nenhuma das duas é assunto desta skill.

## 3 · Diagnóstico, em duas linhas

> "Seu Gestão hoje tem **os quatro status que o Koter cria**: Em análise, Pendente, Implantada e Cancelada. O resto, segmentos, operadoras, planos, já vem pronto do catálogo. Então é ajustar seu funil e você já cadastra uma proposta."

- **Só os quatro** → modo criação: acrescente as etapas dele.
- **Começado** → modo revisão. **Não proponha recriar o que existe.** Aponte só o que está torto.
- **Pronto** → confirme em uma frase e siga para `koter-gestao-campos`.

## 4 · O funil de status, o coração desta skill

É o que a proposta grava e o que muda de corretora para corretora.

Toda corretora nasce com um status por papel, e `default` marca os criados pelo sistema, que não podem ser excluídos. A pergunta útil é concreta:

> "Quando uma proposta é recusada pela operadora, para onde ela vai hoje?"

### O que o papel faz, e o que não faz

| `defaultType` | Papel |
|---|---|
| `REVIEW` | entrada, em análise |
| `PENDING` | pendência |
| `IMPLANTED` | destino padrão de Implantar e de Reativar |
| `CANCELLED` | destino padrão de Cancelar e de Transferir para outra corretora |

**Nenhum status, com papel ou sem, implanta ou encerra contrato.** Venda contada é contrato, não etapa: relatório, campanha e renovação leem o contrato. Proposta implantada é a que tem contrato, em qualquer status. Quem implanta é `gestao_contratos_save_contract`, na `koter-contrato`. Esta é a confusão mais cara do módulo: diga em voz alta.

O papel ainda importa como atalho: se a ação não informar outro destino, a proposta vai para o status com o papel dela.

### Montar as etapas

> "Da cotação até o cliente com carteirinha na mão, por quantas etapas a proposta passa aí?"

Crie na ordem em que ele falar com `gestao_config_save_management_status` sem `statusId` (só `name`; cada uma entra no fim da fila). Depois `gestao_config_reorder_management_statuses`, passando `order` como a **lista inteira** de `{ "id": ..., "position": n }`, com `position` começando em 0.

**Duas etapas que valem ser oferecidas por padrão:** *"Aguardando documentos"* e *"Em análise na operadora"*. Sem elas, proposta parada por documento que o cliente não mandou fica misturada com proposta parada na operadora. Nomes que também costumam faltar: *Recusada pela operadora*, *Vigente*.

**Trocar o papel de lugar.** Na criação, `gestao_config_save_management_status` aceita só `name`; `defaultType` só vale na edição:

```
gestao_config_save_management_status(statusId, name, defaultType: "REVIEW" | "PENDING" | "IMPLANTED" | "CANCELLED" | null)
```

`name` é obrigatório: **repita o nome atual para não renomear sem querer**. Um status por papel em cada corretora. Tentar marcar um segundo falha com *"O papel IMPLANTED já pertence ao status "Implantada" (<id>). Remova o papel dele antes de atribuir a outro."*: a mensagem entrega o nome e o id de quem tem, então **leia o erro e conte ao corretor**. Trocar ou tirar um papel nunca é recusado por causa de contratos.

### Numa conta que já tem proposta, mexer no funil é mexer no histórico

Meça antes de propor qualquer coisa: `gestao_list_proposals(pageSize: 1)` devolve o `total` em uma chamada, e com `statusIds` devolve quantas estão em cada etapa. **Diga o número antes de tocar.**

| O que ele quer | O que de fato acontece | O que fazer |
|---|---|---|
| **renomear etapa** | renomeia para todo mundo, inclusive no histórico das propostas antigas | tudo bem na maioria dos casos, mas **diga** que vale para trás |
| **apagar etapa** | `gestao_config_delete_gestao_config_records` com `kind: "status"` recusa status com proposta, o status padrão e status que uma automação usa | conte quantas estão lá, pergunte para onde vão, transfira com `gestao_config_transfer_proposals_status`, então apague |
| **reordenar** | seguro: posição é visual | pode |
| **acrescentar etapa** | seguro, e é quase sempre a resposta certa | prefira isto a renomear |

**A saída boa é quase sempre acrescentar, não renomear.** Funil de corretora que roda há dois anos reflete como ela trabalha.

## 5 · Entidades, só para quem vende adesão

Entidade é o convênio ou associação da venda por adesão, e **é da corretora mesmo**: `gestao_save_proposal` grava `entityId` a partir da lista dela.

> "Você vende por adesão? Por quais entidades?"

`gestao_config_save_management_entity` sem `entityId` (só `name`). **Se ele não vende adesão, pule e diga que pulou.** Com centenas já cadastradas, não pergunte nada: só confirme que está lá.

## 6 · Com quem ele trabalha: pergunte, mas não cadastre

> "Você vende o quê hoje: saúde, odonto? E com quais operadoras você fecha negócio?"

**Isso não vira cadastro: vira estado.** A `koter-proposta` usa essa resposta para filtrar o catálogo, e a `koter-gestao-comissoes` para saber por qual tabela começar. Guarde os nomes no `.koter/onboarding.json` e siga.

Dois cuidados ao casar os nomes dele com o catálogo, mais tarde:

- **O catálogo é grande, a resposta não precisa ser.** Com `segmentCategoryId` e `insuranceCompanySearch` a leitura é pequena; com `includeInsuranceCompanyImages: true`, enorme. Peça imagem só quando for mostrar logo.
- **Busca por pedaço do nome ainda pode mentir.** Compare nome inteiro, normalizando acento e caixa.

## 7 · Regras que não se quebram

- **Nome é único por empresa** em status e entidade. Antes de criar, procure na lista do passo 2.
- **Nunca apague sem ele mandar.** `gestao_config_transfer_proposals_status` move **todas** as propostas de um status para outro (a própria tool se marca "IMPACTO ALTO"): só com pedido explícito, e diga quantas vão se mover **antes**.
- **Falhou uma, continue as outras.** Junte os erros e conte no fim.

## 8 · Validação: a skill não termina sem isso

Chame `gestao_config_fetch_gestao_config_context` **de novo** e compare com o retrato do passo 3:

> "Pronto: funil de 7 etapas, de Cotação a Cancelada, com Aguardando documentos e Em análise na operadora separadas."

Algo não apareceu na releitura: **diga**.

## 9 · Estado e próxima

Grave em `.koter/onboarding.json`: a etapa como `concluida`, o funil criado, os segmentos e operadoras que ele citou (a `koter-proposta` e a `koter-gestao-comissoes` vão precisar) e qual status ficou com `defaultType: IMPLANTED`.

Depois ofereça a próxima em até 4 opções:

- **`koter-gestao-campos`**: o que ele anota na planilha e o Koter ainda não tem *(recomendada: o campo precisa existir antes da primeira proposta)*
- `koter-proposta`: cadastrar uma proposta agora e ver de pé
- `koter-gestao-vendedores`: quem vende e quem lidera quem
- parar por aqui, retomo quando você voltar

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Leitura volta vazia sem dar erro | `segmentId` do espaço errado | use o segmento global de `gestao_fetch_gestao_context` |
| Skill manda cadastrar operadora | procurou as tools de seguradora da corretora, que sumiram | a operadora vem do catálogo; não cadastre |
| Status novo aparece no lugar errado | criar sempre põe no fim | `gestao_config_reorder_management_statuses` com a lista inteira |
| Moveu para "Implantada" e a venda não contou | status não implanta | `gestao_contratos_save_contract(proposalId)`. Veja `koter-contrato` |
| "Não consigo marcar IMPLANTED" | o papel já é de outro status | o erro diz o nome e o id; tire de lá primeiro |
| Relatório sem a etapa de recusa | falta status de recusa | crie e reordene |
| Confundiu categoria do segmento com categoria de campo | `categories` é PF, PME, Adesão; `customFieldCategories` agrupa campos | nenhuma das duas é desta skill |

## Conferência

Tools, parâmetros e mensagens conferidos no inventário e lidos no código em 03/11/2026, não executados.
Os quatro status de papel de toda corretora nova e a leitura de "implantada" pelo contrato vêm do código, não de execução.
Numa conta criada antes dessa regra, leia o que `gestao_config_fetch_gestao_config_context` devolver.
