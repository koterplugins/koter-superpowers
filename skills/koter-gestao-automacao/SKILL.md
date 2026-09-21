---
name: koter-gestao-automacao
description: Mostra o que já roda sozinho no módulo Gestão do Koter e cria automações próprias por evento ou data — avisos de conta vencida, repasse pendente, tarefas automáticas. Use quando falarem de automação, lembrete automático, aviso de vencimento, tarefa automática ou "o sistema podia me avisar".
---

# koter-gestao-automacao

Décima primeira etapa. **Comece mostrando o que já roda**, porque quase sempre é mais do que o corretor imagina.

## 1 · Os defaults vêm LIGADOS

```
gestao_automacao_list_system_automation_catalog
```

Na Koter Day, uma conta recém-criada, três automações de sistema já vinham `enabled: true`, `forked: false`:

| Automação | Dispara | O que faz |
|---|---|---|
| **Conta a vencer em 3 dias** | `dueDate` de lançamento, 3 dias antes | notificação |
| **Conta vencida** | `dueDate`, 1 dia depois, se ainda `PENDENTE` | **cria tarefa** de prioridade alta |
| **Repasse pendente há 7 dias** | `receivedAt` da parcela, 7 dias depois, se o recebimento saiu e o repasse não | notificação |

**O modelo é opt-out.** Abrir a skill propondo criar automação, sem mostrar isso, é o jeito mais rápido de duplicar aviso — ele vai receber dois lembretes da mesma conta e achar que o sistema está quebrado.

Então a abertura é:

> "Três coisas já rodam sozinhas aqui: aviso de conta a vencer, tarefa de conta vencida, e cobrança de repasse parado há 7 dias. Quer manter as três?"

`set_system_automation_state` liga e desliga. `fork_system_automation` **cria uma cópia editável** — é o caminho para "quero esse aviso, mas com 5 dias em vez de 3": forka e ajusta, em vez de desligar e criar do zero.

## 2 · Criar automação própria

```
gestao_automacao_list_management_automation_triggers   → o que pode disparar
gestao_automacao_list_management_automation_actions    → o que pode acontecer
gestao_automacao_create_management_automation
gestao_automacao_validate_management_automation        → SEMPRE antes de ativar
gestao_automacao_set_management_automation_active
```

Uma automação é um **gatilho** mais uma lista de `steps`, cada um `CONDITION` ou `ACTION`. O gatilho `DATE_FIELD` tem `dateField` com `source` (`PROPOSAL`, `INSTALLMENT`, `FINANCE_ENTRY`), `field`, `offsetDays` (positivo = antes, negativo = depois), `recurrence` e `dayHandling` (`CLIP_TO_LAST_DAY` resolve o dia 31 em fevereiro).

**Sempre `validate` antes de `set_active`.** Automação inválida ativada é erro que só aparece quando devia disparar — e ninguém percebe que não disparou.

## 2.1 · A proposta pode virar card ou contato no CRM

Duas ações fazem a ponte do Gestão para o CRM. As duas exigem **proposta no contexto do gatilho** e são recusadas em automação padrão da Koter:

| Ação | Para que serve | Parâmetros |
|---|---|---|
| `CREATE_LEAD` | abre um card no funil — é a ponte vigência → renovação, com `DATE_FIELD` sobre `coverageStart` | `teamId` (obrigatório), `statusId`, `title`, `origin`, `tags`, `assigneeType` (`PROPOSAL_OWNER`/`SPECIFIC_USER`), `assigneeUserId` |
| `CREATE_CONTACT` | garante um contato vinculado à proposta, reaproveitando o de mesmo e-mail — é o caminho da produção antiga/importada, que deve virar **contato** e não card | `teamId`, `assigneeType`, `assigneeUserId` (todos opcionais) |

`CREATE_LEAD` reaproveita o contato da proposta (cria um se faltar), vincula o lead de volta à proposta e **não duplica**: se a proposta já tem lead aberto naquele time, o passo é sucesso sem criar outro.

> ⚠️ **Defeito medido na Koter Day em 21/09/2026.** Na primeira execução, `CREATE_LEAD` criou o lead e o contato mas a execução terminou `FAILED` com `Invalid prisma.proposal.update() invocation: Unique constraint failed on the fields: (id)` — o vínculo do lead de volta à proposta não gravou. E como a dedupe é feita por esse vínculo, **o disparo seguinte criou um segundo card**. Do terceiro disparo em diante, com o vínculo gravado, não duplicou mais. Enquanto isso não for corrigido: **depois de criar uma automação com `CREATE_LEAD`, leia `get_management_automation_logs` e confira o funil** — um `FAILED` ali significa card órfão e duplicata no próximo disparo.

**Os nomes dos campos de contexto mentem, e o próprio MCP avisa.** `list_management_automation_triggers` e `fetch_management_automation_context` trazem `contextFieldNotes`, que traduz as três chaves históricas do contexto de proposta:

| Chave da condição | O que ela guarda de verdade |
|---|---|
| `insuranceId` | o **ramo** (`segments` de `fetch_gestao_context`) |
| `segmentId` | a **modalidade** (`groupId` de `modalities`) |
| `planId` | a **seguradora** do catálogo global (`list_segment_insurance_companies`) |

Monte condição lendo `contextFieldNotes`, nunca pelo nome do campo. E o campo de data da vigência é `coverageStart` no `dateField`, embora a lista de condições do gatilho chame o mesmo dado de `vigencia`.

## 3 · Antes de propor qualquer coisa nova

Três perguntas de bom senso, nessa ordem:

1. **Isso já roda?** Confira o catálogo. Forkar é melhor que criar.
2. **Quem recebe?** Notificação para quem não decide nada vira ruído, e ruído faz o corretor desligar tudo.
3. **O que acontece se disparar errado?** Notificação errada é chata; tarefa errada polui a lista; mudança de status errada bagunça relatório.

Mudança de status de proposta **dispara as automações vinculadas àquele status** — cuidado ao combinar automação com `set_proposal_status` em lote.

## 4 · Mensagem automática depende de instância oficial

Automação que **manda mensagem** só funciona com instância oficial Cloud API e template aprovado pela Meta. Antes de propor régua de mensagem, confira que existe (`koterzap_configuracao_list_whatsapp_instances`) — prometer lembrete por WhatsApp para quem não tem número oficial é promessa que não se cumpre.

## 5 · Acompanhar

`get_management_automation_logs` e `get_system_automation_logs` mostram o que disparou. Quando o corretor disser "não recebi aviso", é aqui que se responde.

## 6 · Validação e próxima

Liste o que ficou ligado e o que cada uma faz, em uma linha cada. Esta skill é a convergência do ato 3 da passada única: as duas prioridades, comissão e atendimento, terminam aqui.

Depois, em até 4 opções:

- **`koter-crm-lead`** ou **`koter-proposta`** — usar o que foi configurado *(recomendada: configuração sem uso não fecha onboarding)*
- `koter-crm-fundacao` — se a trilha do CRM ainda não foi feita
- `koter-zap-fundacao` — se ainda não há canal de WhatsApp
- parar por aqui

Antes de sugerir, **leia o estado**: ofereça a trilha que ainda está `pendente`, não a que ele acabou de fazer.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Aviso duplicado | automação nova sobre um default ligado | veja o catálogo antes; forke |
| "Desliguei tudo, era muito aviso" | notificação para quem não decide | reveja o destinatário, não o aviso |
| Automação não dispara | ativada sem validar | `validate_management_automation` |
| Dia 31 em fevereiro | `dayHandling` | `CLIP_TO_LAST_DAY` |
| Mudança de status em lote disparou coisa demais | status vinculado a automação | avise antes de mover em lote |
| Mensagem automática não sai | sem instância oficial ou template aprovado | `list_meta_message_templates` diz se há template `APPROVED` |
| Dois cards de renovação da mesma proposta | execução `FAILED` deixou o primeiro lead sem vínculo | leia os logs depois de criar; apague o card órfão |
| Condição por seguradora não casa nunca | `segmentId` na condição é a modalidade, não o ramo | leia `contextFieldNotes`: a seguradora é `planId` |
