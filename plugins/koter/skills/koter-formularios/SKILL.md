---
name: koter-formularios
description: "Monta o formulário de captura do Koter: perguntas, condições, publicação e respostas. Use quando pedirem formulário de captura, formulário para o site ou lead e pedido de cotação vindos de formulário."
---

# koter-formularios

O formulário que o visitante preenche num link público, e que pode virar lead e rascunho de cotação. **Termina com o formulário salvo, conferido na releitura e publicado só se o corretor pedir**: publicar põe o link no ar para qualquer pessoa.

## 0 · Pré-requisitos

- Toolset `formularios` na conexão. Ele fica fora dos pacotes (ver `../introducao/references/conexao-por-modulo.md`) e é do módulo CRM.
- `koter-crm-fundacao` rodada: todo formulário pertence a uma equipe, e é ela que recebe os leads.
- Permissões: "Ver páginas de captura", "Criar página de captura", "Editar página de captura" e "Excluir página de captura". Criar pergunta pede a de criar campo personalizado do CRM.

## 1 · Detecção

```
formularios_fetch_form_context   ← o que um formulário pode perguntar, equipes, limites
formularios_list_forms           ← os formulários que já existem
```

| Parte de `formularios_fetch_form_context` | O que traz |
|---|---|
| `nativeQuestions` | os dados básicos do lead: `name`, `whatsapp`, `phone`, `email`, `age`, `interest` |
| `customQuestions` | os campos de lead que um formulário pode perguntar, com `type`, `template`, `options`, `formOnly` e `quoteKind` |
| `teams` | as equipes; todo formulário é de uma |
| `limits` | até 30 passos e 60 perguntas |

A `key` de cada pergunta é o que vai em `steps[].fields[].key` de `formularios_save_form`. `formularios_list_forms` mostra `active`, `createsLead`, `quoteDraftKind` e `responsesCount` de cada um. **Formulário que já existe se edita, não se recria.** Página de captura (tipo `PAGE`) é só de tela e não aparece em `formularios_list_forms`: não crie formulário no lugar dela.

## 2 · Para onde vai cada resposta

Toda resposta fica guardada no formulário. O resto é escolha, feita em `formularios_save_form`:

| Opção | Efeito de cada resposta | Padrão |
|---|---|---|
| `createsLead: true` | também vira lead na equipe do formulário | sim |
| `createsLead: false` | fica só no formulário | não |
| `quoteDraft: "HEALTH"` ou `"AUTO"` | também abre um rascunho de cotação, que o corretor termina na tela de nova cotação | não |

**O que uma resposta dispara:**

- O lead nasce **sem dono**, na etapa Pendente da equipe do formulário, e **não passa pela fila** de distribuição. O contato é achado pelo telefone, depois pelo e-mail, ou criado.
- Ele dispara as automações `LEAD_CREATED` da equipe, e vai para as integrações de lead que a corretora tiver ligadas, como qualquer lead novo. A automação que cria tarefa para o dono do lead **falha em lead sem dono** (ver `koter-crm-automacao`, passo 2). Antes de publicar, confira as automações da equipe e, se for o caso, proponha um `ASSIGN_AGENT` com `assignmentType: "TEAM_QUEUE"` antes da tarefa.
- Visitante que marcou o aceite gera lead com `lgpd` `CONSENT`; sem aceite, `NOT_PROVIDED`.
- As respostas vão para `extra` do lead, menos as perguntas só de formulário (`formOnly`), que ficam só na resposta.
- O rascunho de cotação **não cota nada e não aciona seguradora**. Ele é preenchido só pelas perguntas de cotação do sistema (`quoteKind` `HEALTH`, `AUTO` ou `BOTH`, `key` `cotacao_*`): use as do tipo escolhido e as `BOTH`.

**Publicar não cria lead.** O que dispara é cada resposta que chega depois.

## 3 · Montar

`formularios_save_form` sem `formId` cria com `name` (interno: o visitante nunca vê) e `teamId`, **em rascunho**. Mande `form` junto para nascer com as perguntas.

| Campo de `form` | O que faz |
|---|---|
| `layout` | `steps` (uma tela por passo) ou `inline` (tudo numa tela) |
| `title` | o que o visitante vê no topo e no link compartilhado |
| `steps[].fields[]` | `key`, `required`, `label` como o visitante lê, `placeholder`, `helpText`, `width` (só `inline`) |
| `showIf` | mostra a pergunta, ou o passo, só quando uma pergunta **anterior** vale `equals`, `not_equals`, `filled` ou `empty` |
| `ending` | a tela depois do envio, quando não há `redirectUrl` |
| `lgpd` | aceite LGPD (`enabled`, `text`), ligado por padrão |

- **`form` substitui o formulário inteiro.** Para mudar uma pergunta: `formularios_list_forms` com `ids`, altere e mande tudo de volta.
- Em pergunta de escolha, `showIf` compara com o `value` da opção, não com o rótulo.
- A recusa traz a lista do que corrigir: `key` fora do contexto, `key` repetida, `showIf` que lê pergunta posterior.
- Leia `warnings` na resposta. Formulário que cria lead sem perguntar `whatsapp`, `phone` nem `email` gera **lead sem contato**.

### A pergunta que não existe

1. Procure em `nativeQuestions` e `customQuestions`: não duplique.
2. A resposta precisa ficar na ficha do lead? É campo personalizado comum, com `crm_config_save_custom_field_definition` (ver `koter-crm-campos`).
3. Só no formulário? `formularios_create_form_question` cria pergunta só de formulário: `TEXT`, `SELECT` ou `DATE`, com as máscaras de `template` (`CPF`, `CNPJ`, `CEP`, `VEHICLE_PLATE` e outras). Editar, desativar ou apagar a pergunta depois é pelo `crm-config`.

As perguntas de cotação já existem em toda corretora e não se criam: `key` com o prefixo `cotacao_` é recusada. Vidas por faixa etária é a `cotacao_vidas`.

## 4 · Publicar e o link

- `active: true` publica, e `false` volta a rascunho e tira o link do ar. Publicar exige ao menos uma pergunta. **Só publique quando o corretor pedir.**
- O link é o `publicPath` no domínio de captura da corretora (`proteger.vc`). Com `?embed=1`, o mesmo link vira iframe no site dele.
- `slug` é o final do link (`/lp/<slug>`), único no Koter inteiro e gerado do nome quando omitido. **Trocar o slug de um formulário publicado quebra os links já divulgados.**
- `redirectUrl` (http ou https) leva o visitante a outra página depois de enviar, no lugar da tela final.

## 5 · As respostas

```
formularios_list_form_responses   formId
```

Da mais recente para a mais antiga. Cada uma traz `answers` (`key`, `label`, `value`), `lgpdConsent`, `leadId` e `contactId` (null quando não virou lead, ou o lead foi apagado), `metadata` (`utm`, `referrer`, `embedded`) e `quoteDraft` (`status` `OPEN`, `CONVERTED` ou `DISCARDED`, e o `quoteId` em que virou).

**São dados pessoais de visitantes.** Leia só o que o corretor pediu, e nada disso vai para memória, skill ou estado.

## 6 · Tirar do ar e excluir

- Tirar do ar e manter tudo: `formularios_save_form` com `active: false`.
- `formularios_delete_form` exclui: o link sai do ar na hora, o formulário some das listas e as respostas deixam de ser lidas por aqui. Os leads que ele criou ficam no CRM. Não há como desfazer por este toolset: só com pedido explícito, e diga quantas respostas ele tinha (`responsesCount`).

## 7 · Validação

Releia com `formularios_list_forms` (com `ids`) e confira as perguntas, `createsLead`, `quoteDraftKind`, `active` e `publicPath`. Diga em uma frase o que cada resposta vai fazer:

> "O formulário 'Cotação PME' está em rascunho, na equipe Comercial. Cada resposta vira lead sem dono na etapa Pendente e abre um rascunho de cotação de saúde. Sua automação 'Cobrar o primeiro contato' cria tarefa para o dono e vai falhar nesses leads: quer que eu ponha a distribuição pela fila antes?"

Nenhuma tool envia resposta ao formulário público. Para ver funcionando, publique só com o sim, peça ao corretor uma resposta de teste pelo link, e confira em `formularios_list_form_responses` e no lead com `crm_list_leads`.

## 8 · Estado e próxima

Esta skill não é etapa da trilha e não grava em `.koter/onboarding.json`: o formulário se relê com `formularios_list_forms`.

Próxima, em até 4 opções:

- **`koter-crm-automacao`**: o que acontece com o lead que o formulário cria *(recomendada)*
- `koter-crm-campos`: pergunta que precisa ficar na ficha do lead
- `koter-crm-lead`: tocar os leads que chegarem
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Leads do formulário chegam sem contato | o formulário não pergunta `whatsapp`, `phone` nem `email` | acrescente um dos três; `warnings` avisa |
| Automação de tarefa falha nos leads do formulário | o lead nasce sem dono | `ASSIGN_AGENT` com `TEAM_QUEUE` antes do `CREATE_TASK`, ou `SPECIFIC_USER` |
| Lead do formulário não entra no rodízio | a fila não distribui lead de formulário | automação `LEAD_CREATED` com `TEAM_QUEUE` |
| Pergunta sumiu depois de editar | `form` substitui o formulário inteiro | leia com `ids` e mande tudo |
| `showIf` recusado | a condição lê uma pergunta posterior | só pergunta anterior |
| Condição em pergunta de escolha nunca vale | comparou com o rótulo | compare com o `value` |
| Rascunho de cotação sai vazio | faltam as perguntas de cotação do tipo escolhido | `cotacao_*` com o `quoteKind` certo, e as `BOTH` |
| "O rascunho não cotou" | o rascunho não cota | o corretor termina na tela de nova cotação |
| `key` recusada | o prefixo `cotacao_` é reservado | outra `key` |
| Links divulgados pararam | `slug` trocado depois de publicar | volte o `slug` antigo |
| Resposta que devia ir para a ficha do lead não aparece lá | a pergunta foi criada com `formularios_create_form_question`, que é só de formulário | campo comum em `crm_config_save_custom_field_definition` |
