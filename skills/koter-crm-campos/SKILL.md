---
name: koter-crm-campos
description: Cria campos personalizados de lead e contato no CRM do Koter. Use quando pedirem para guardar no lead um dado que o Koter não tem (vidas, CNPJ, operadora atual) ou organizar o formulário do lead.
---

# koter-crm-campos

O que o corretor anota no caderno e o CRM ainda não guarda. **Termina com o campo criado, preenchido num lead de verdade e conferido na leitura.**

## 0 · Pré-requisitos

`koter-crm-fundacao` rodada, se algum campo for de escopo de equipe.

Permissões: criar e editar campo personalizado do CRM.

## 1 · O limite do produto, e ele muda o desenho

```
crm_config_fetch_crm_config_context → enums.customFieldTypes
```

Devolve **quatro tipos**, para lead e para contato:

| Tipo | Serve para | Não serve para |
|---|---|---|
| `TEXT` | texto livre que ninguém vai filtrar | ordenar, somar, comparar |
| `SELECT` | valores conhecidos | valor que o corretor inventa na hora |
| `REFERENCE` | vínculo com um catálogo do Koter (idade, profissão, cidade…) | **exige `template`** e não serve de condição de automação: ver o passo 5 |
| `DATE` | uma data (`AAAA-MM-DD`) do lead ou do contato: aniversário, data combinada | número ou faixa. Não tem `options` nem `template` |

**O CRM tem tipo data, mas não tem tipo número.** Duas consequências que decidem esta skill inteira:

1. **Data do lead ou do contato vira campo `DATE`, nunca `TEXT`.** Texto não dispara automação por data. O campo `DATE` ancora uma automação agendada do CRM: gatilho `SCHEDULED` com `dateField` em `extra.<chave>`, que roda em cada lead ou contato no dia da data, ou com antecedência, uma vez, todo mês ou todo ano (ver `koter-crm-automacao`). Data que já mora no contrato, como o fim de vigência, fica no Gestão, com `DATE_FIELD`: não copie para o lead (ver `koter-crm-renovacao`).
2. **Número de vidas não vira `TEXT`.** Como texto ele é legível e nada mais: não dá para pedir "leads acima de 30 vidas". Vira `SELECT` com faixas. O template `QUOTE_LIVES` não substitui: ele guarda as vidas por faixa etária de uma cotação de saúde, é `REFERENCE` e não serve de condição. Toda corretora já tem a pergunta pronta, `cotacao_vidas`, nos formulários de captura (`koter-formularios`).

> **Prefira `SELECT` sempre que os valores forem conhecidos.** É o único tipo que relatório e segmentação usam bem, e é o único que impede o mesmo dado de ser escrito de cinco jeitos.

## 2 · O mínimo que se paga

Ofereça só o que os produtos da corretora justificam: cada campo a mais é uma linha a mais no formulário de todo lead novo.

| Campo | Tipo | Quando criar |
|---|---|---|
| Tipo de contratação | `SELECT` (PME / Adesão / Individual / Empresarial 30+) | quase sempre: muda o roteiro de qualificação inteiro |
| Faixa de vidas | `SELECT` (2-9 / 10-29 / 30-99 / 100+) | se vende coletivo |
| CNPJ | `TEXT` com `template: "CNPJ"` | se vende PME |
| Profissão / entidade | `TEXT` | **só se vende adesão**: é a trava de elegibilidade |
| Operadora atual | `SELECT` com as operadoras dele, ou `TEXT` | só se trabalha portabilidade |

As três últimas linhas são condicionais de verdade: pergunte **uma** vez ("você vende adesão?") em vez de criar os cinco campos e deixar o corretor apagar depois.

Leia os ramos e `enabledInterests` antes de perguntar: o que a fundação do Gestão já respondeu não se pergunta de novo.

## 3 · Criar

```
crm_config_save_custom_field_definition   (sem definitionId)
```

- `entityType`: `LEAD` ou `CONTACT`. Na dúvida, `LEAD`: é onde a venda acontece. `CONTACT` serve para dado da pessoa que sobrevive ao negócio (aniversário, preferência de contato).
- `label` é o que aparece; **`key` é derivada dele se você omitir** (ex.: "Faixa de vidas" → `faixa_de_vidas`). A `key` é o que `crm_save_lead` usa em `extra`: anote-a. **`key` que comece com `cotacao_`, informada ou derivada do `label`, é recusada**: o prefixo é dos campos de cotação do sistema (id `sys-`), que toda corretora já tem e que não se editam, desativam nem excluem.
- `type: SELECT` sem `template` **exige** `options`, cada uma `{ value, label }`. `value` é o que fica gravado, `label` o que o corretor vê. Use `value` curto e estável ("10-29"), porque mudar `value` depois deixa os leads antigos apontando para opção que não existe mais.
- `teamId` omitido = campo **global**; preenchido = só daquela equipe. Global é o padrão certo: campo por equipe some do formulário quando o lead é transferido.
- `categoryId` omitido = a categoria interna padrão da corretora. Não crie categoria nova sem motivo.
- `groupId` põe o campo num grupo visual da tela do lead ou do contato (passo 6).
- `formOnly: true` cria campo **só de formulário**: perguntado nos formulários de captura, guardado na resposta e nunca no lead. Exige `LEAD`, sem `teamId` e sem `categoryId`. É assunto da `koter-formularios`.
- `helpText` é o lugar de explicar a regra ao corretor dentro do produto. Use: é a única documentação que ele vai ler.
- `template` fixa o comportamento, o `type` e as opções do campo, e não muda depois: `CPF`, `CNPJ`, `DEPENDENTS`, `MONTHLY_BUDGET`, `CEP` (guarda os 8 dígitos) e `VEHICLE_PLATE` (placa antiga ou Mercosul, sem hífen) para `TEXT`; `PERSON_TYPE`, `MARITAL_STATUS` e `GENDER` para `SELECT` com opções fixas; os de `REFERENCE` no passo 5.

Categoria, entidade, equipe, `key`, `type`, `template` e `formOnly` só valem na criação. Na edição dá para mudar `label`, `groupId` (`null` tira do grupo), `options` (só `SELECT` sem template), `placeholder`, `helpText`, `position` e `active`.

Exemplo: "Faixa de vidas" e "Tipo de contratação", criados como `SELECT` global, se preenchem na criação de um lead com `extra: { "faixa_de_vidas": "10-29", "tipo_de_contratacao": "pme" }` e voltam iguais em `crm_list_leads` (com `ids`).

## 4 · Onde o campo aparece, e como vira condição de automação

O campo personalizado **serve de condição de automação**, com uma ressalva por tipo. `crm_automation_fetch_automation_context` devolve `customFields` com o `conditionField` de cada um (`extra.<key>`), que é o `field` a usar num passo `CONDITION`, o mesmo caminho que o chatbot lê em `crm.lead.extra.<key>`:

| Tipo | Como condiciona |
|---|---|
| `SELECT` | compare com o `value` da opção, nunca com o `label` (`extra.faixa_de_vidas` `IN` `["30-99","100+"]`) |
| `TEXT` | comparação de texto (`EQUALS`, `CONTAINS`, `IS_EMPTY`…); não ordena nem compara número |
| `REFERENCE` | **não condiciona**: vem com `conditionField: null` |

Então a automação que reage a "PME acima de 30 vidas" condiciona direto nos dois `SELECT` do passo 2: é mais um motivo para faixa de vidas ser `SELECT` e não `TEXT`. Tag continua sendo o caminho quando o dado não está em campo nenhum.

Diga isso na hora de criar o campo: o `value` que ele escolher agora vira contrato das automações que vierem depois.

## 5 · `REFERENCE`: cria por MCP, com `template`

Campo de referência **exige `template`**, que é o que diz o que ele referencia: `AGE`, `PROFESSION`, `STATE_CITY`, `MARKET_PRODUCTS`, `PREFERRED_OPERATOR` ou `QUOTE_LIVES` (vidas por faixa etária de uma cotação de saúde, respondidas em formulário). Sem `template`, a criação é recusada.

Em `crm_config_save_custom_field_definition`: `type: "REFERENCE"` com `template: "AGE"` (por exemplo). O campo nasce `REFERENCE`/`AGE`, `GLOBAL`, na categoria padrão, e sai com `crm_config_delete_crm_config_records`. O `template` fixa o tipo e não muda depois; se precisar de outro, crie outro campo.

Confira relendo `customFieldDefinitions` em `crm_config_fetch_crm_config_context`. E lembre: campo `REFERENCE` **não serve de condição de automação**, porque vem com `conditionField: null`.

## 6 · Grupos, categorias e a ordem na tela

Três coisas diferentes: grupo e ordem são o que a tela do lead e do contato mostra; categoria organiza as definições.

| | O que é | Ferramenta |
|---|---|---|
| **Grupo** | título que reúne campos na tela do lead ou do contato. Só visual | `crm_config_list_custom_field_groups` lê; `crm_config_save_custom_field_group` cria (`entityType` e `label`) ou renomeia (`groupId`) |
| **Ordem** | a sequência dos grupos e dos campos dentro de cada um | `crm_config_save_custom_field_layout` |
| **Categoria** | agrupador das definições, de `LEAD` e/ou `CONTACT`, com subcategoria de um nível | `crm_config_save_custom_field_category` |

- Campo entra num grupo por `groupId` em `crm_config_save_custom_field_definition`, ou pelo layout. Campo sem grupo aparece primeiro.
- **`crm_config_save_custom_field_layout` grava a entidade inteira** em `sections`: uma seção por grupo (`groupId: null` para os campos sem grupo), com os `definitionIds` na ordem. Cada campo listado passa para o grupo da seção em que veio. Campo ou grupo que ficar de fora mantém o que tinha, então liste todos. Um `groupId` que não é da entidade recusa a chamada inteira.
- Apagar grupo (`crm_config_delete_crm_config_records`, `kind: "custom_field_group"`) não apaga campo: os campos dele ficam sem grupo.
- **Não crie categoria para organizar a tela**: isso é grupo. O `slug` da categoria é único na corretora, contando as excluídas, e não muda. Apagar categoria é recusado enquanto ela tiver definição ativa ou subcategoria, e em categoria do sistema.

Leia antes de mexer: `crm_config_list_custom_field_groups` (com `entityType`) e `customFieldDefinitions` em `crm_config_fetch_crm_config_context`, que traz o `groupId` de cada campo.

## 7 · Mexer em campo que já tem dado

- **Desativar preserva o dado.** `crm_config_save_custom_field_definition` com `definitionId` e `active: false` tira o campo do formulário sem apagar o que já foi preenchido. É o que fazer com campo que o corretor não usa mais.
- **Apagar é outra decisão.** `crm_config_delete_crm_config_records` com `kind: "custom_field_definition"` só sob pedido explícito. A exclusão é lógica e os valores já preenchidos nos leads ficam, mas o campo sai do formulário; criar de novo com a mesma `key`, na mesma categoria, entidade, `type` e `template`, reativa aquele campo.
- **Tirar uma opção de `SELECT`** deixa os leads que a usavam apontando para um valor órfão. Prefira acrescentar e desativar o campo inteiro a podar opções.
- **Campo `isSystem: true` não se mexe.**

## 8 · Validação: no lead, não na definição

A definição existir não prova nada. **Preencha o campo num lead de verdade** (o mesmo que a `koter-crm-lead` vai usar, ou um lead existente) com `crm_save_lead` (com `leadId`) passando `extra`, que substitui todos os campos personalizados do lead, então repita os que já estavam. Releia com `crm_list_leads` (com `ids`):

> "Criei 'Faixa de vidas' e 'Tipo de contratação'. Marquei a Padaria Pão Quente como PME, 10 a 29 vidas, e o Koter me devolveu isso de volta, então está gravando."

Se a releitura não trouxer o valor, o problema é quase sempre a `key`: `extra` usa a `key`, nunca o `label`.

## 9 · Estado e próxima

Grave em `.koter/onboarding.json`: etapa `concluida`, e **as `key` de cada campo criado**. A `koter-crm-lead` e qualquer skill que preencha lead vão precisar delas.

Próxima, em até 4 opções:

- **`koter-crm-lead`**: cadastrar um lead de verdade e ver a roda girar *(recomendada: é o que prova que a configuração serve para alguma coisa)*
- `koter-crm-automacao`: o que passa a rodar sozinho
- `koter-crm-renovacao`: a rotina que segura carteira
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `extra` não grava | a chave usada foi o `label`, não a `key` | leia a `key` em `customFieldDefinitions` do contexto |
| Não consigo filtrar "acima de 30 vidas" | o campo virou `TEXT`, ou `REFERENCE` com `QUOTE_LIVES` | `SELECT` com faixas |
| `key` recusada sem motivo aparente | começa com `cotacao_`, informada ou derivada do `label` | outro `label` ou `key` explícita |
| A ordem da tela saiu pela metade | o layout foi gravado sem todos os campos e grupos | `crm_config_save_custom_field_layout` com a entidade inteira |
| Data gravada não dispara automação | o campo foi criado `TEXT` | crie um campo `DATE` (o tipo só se escolhe na criação) e use `extra.<chave>` em `dateField` |
| `REFERENCE` recusado | falta `template` | mande `template` com um dos seis de referência |
| Automação não consegue condicionar pelo campo | campo `REFERENCE` (`conditionField: null`), ou `SELECT` comparado pelo `label` | use o `value`; em `REFERENCE`, use tag |
| Campo sumiu quando o lead mudou de equipe | campo com `teamId` | crie global |
| Leads antigos com valor órfão no `SELECT` | uma opção foi removida | acrescente em vez de podar |
