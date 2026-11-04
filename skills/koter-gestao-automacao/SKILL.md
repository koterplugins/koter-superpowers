---
name: koter-gestao-automacao
description: Mostra o que já roda sozinho na Gestão do Koter e cria automações por evento ou data. Use quando falarem de automação, lembrete, aviso de vencimento, inadimplência, fim de vigência ou tarefa.
---

# koter-gestao-automacao

Décima primeira etapa. **Comece mostrando o que já roda**, porque quase sempre é mais do que o corretor imagina.

## 1 · Os defaults vêm LIGADOS

```
gestao_automacao_fetch_management_automation_context   → systemAutomations
```

Três automações padrão do Koter já vêm `enabled: true`, `forked: false`:

| Automação | Dispara | O que faz |
|---|---|---|
| **Conta a vencer em 3 dias** | `dueDate` de lançamento, 3 dias antes, se `PENDENTE` | notificação |
| **Conta vencida** | `dueDate`, 1 dia depois, se `PENDENTE` | **cria tarefa** de prioridade alta |
| **Repasse pendente há 7 dias** | `payableAt` do repasse, 7 dias depois, se ainda a pagar | notificação |

**O modelo é opt-out.** Abrir a skill propondo criar automação, sem mostrar isso, é o jeito mais rápido de duplicar aviso: ele vai receber dois lembretes da mesma conta e achar que o sistema está quebrado.

Então a abertura é:

> "Três coisas já rodam sozinhas aqui: aviso de conta a vencer, tarefa de conta vencida, e cobrança de repasse parado há 7 dias. Quer manter as três?"

`gestao_automacao_set_system_automation_state` (com o `versionGroupId` do default) liga e desliga. `gestao_automacao_fork_system_automation` **cria uma cópia editável**, o caminho para "quero esse aviso, mas com 5 dias em vez de 3". A cópia nasce **desativada**, não recebe atualizações do default e já o desliga; depois de ajustar, ative com `gestao_automacao_save_management_automation` (`automationId` da cópia + `active: true`).

## 2 · Criar automação própria

```
gestao_automacao_fetch_management_automation_context   → triggers, actions, dateFieldsBySource, contextFieldsBySource, statuses
gestao_automacao_validate_management_automation        → SEMPRE antes de gravar
gestao_automacao_save_management_automation            → sem automationId cria (nasce PUBLICADA e ATIVA)
```

**Porta de cuidado.** `gestao_automacao_save_management_automation` não sai marcada como destrutiva e nasce ligada. Deixe sempre em "Precisa de aprovação" na IA. Pelo schema ela não grava passo de WhatsApp ou webhook, mas `active: true` religa uma automação feita na tela que tenha esses passos, e aí a mensagem chega ao cliente.

Uma automação é um **gatilho** mais uma lista de `steps`, na ordem. Todo passo leva um `id` único.

| `kind` | Campos | Regra |
|---|---|---|
| `CONDITION` | `field`, `operator`, `value`, `onFalse?` | Falsa, para ali. Com `onFalse: { goto: id }` pula para um passo adiante, o "se / senão" |
| `WAIT` | `amount`, `unit` (`MINUTES`, `HOURS`, `DAYS`), `maxAmount?`, `window?`, `pace?` | Não pode ser o último passo nem vir colada em outra espera. Soma de esperas até 90 dias |
| `ACTION` | `type`, `params` | Precisa de ao menos uma |
| `END` | | Fecha o lado "sim" de uma condição. Não pode vir logo depois de espera |

`maxAmount` sorteia a espera entre `amount` e ele. `window` limita o horário em que a espera termina (`startMinutes`, `endMinutes`, `weekdays?`, em minutos desde a meia-noite). `pace` dá o ritmo (`maxRuns` a cada `everyMinutes`).

### Gatilhos

| `trigger` | Dispara quando |
|---|---|
| `PROPOSAL_STATUS_CHANGED` | muda o status da proposta |
| `DATE_FIELD` | varredura diária sobre um campo de data. Exige `dateField` |
| `ATTACHMENT_ADDED` | anexam arquivo a uma proposta. O contexto é o anexo |
| `FINANCE_ENTRY_SETTLED` | lançamento recebe baixa, manual ou por conciliação |
| `CONTRACT_IMPLANTED` | contrato é implantado, uma vez por contrato |
| `CONTRACT_CANCELLED` | contrato é cancelado |
| `CONTRACT_DEFAULT_STARTED` | contrato entra em inadimplência, pelo extrato, à mão ou pela varredura. Traz `defaultStartedAt` e `defaultSource` (`STATEMENT`, `MANUAL`, `SWEEP`) |
| `COMMISSION_UNSETTLED_PAST_DUE` | comissão não recebida com a parcela do prêmio além do prazo de inadimplência |
| `COMMISSION_RECEIPT_OVERDUE` | comissão não recebida, no dia seguinte à data prevista de recebimento |
| `COMMISSION_RECEIVED` | baixa de comissão. Uma vez por baixa: recebida em duas parcelas, dispara duas vezes |
| `CHARGEBACK_CONFIRMED` | estorno confirmado |

**Nenhum gatilho de contrato ou comissão dispara na importação histórica.** E mudar status continua sendo só funil: para reagir à venda implantada de verdade, o gatilho é `CONTRACT_IMPLANTED`, não `PROPOSAL_STATUS_CHANGED`.

### Datas: `DATE_FIELD`

```
dateField: { source, field, recurrence, offsetDays, dayHandling }
```

| `source` | `field` |
|---|---|
| `CONTRACT` | `endsAt` (fim da vigência), `startsAt` (início; com `YEARLY`, o aniversário). Só contratos vivos |
| `PROPOSAL` | `coverageStart`, `billDueDate`, `implantationDate`, `proposalDate`, `clientBirthDate` |
| `COMMISSION_EXPECTATION` | `premiumDueDate`, `expectedReceiptAt`, `expectedPayoutAt`, `settledAt` |
| `PAYOUT_SHARE` | `payableAt` |
| `FINANCE_ENTRY` | `dueDate` |

Mesmo assim, leia o catálogo em `dateFieldsBySource` antes de gravar, e os campos de condição de cada fonte em `contextFieldsBySource`. Condição com campo fora da lista nunca casa.

`offsetDays` positivo é antes, negativo é depois, até 3650. `recurrence`: `ONCE`, `MONTHLY`, `YEARLY`. `dayHandling`: `CLIP_TO_LAST_DAY` resolve o dia 31 em fevereiro, `SKIP` pula.

**Avisar 30 dias antes do fim da vigência:**

```
trigger: DATE_FIELD
dateField: { source: "CONTRACT", field: "endsAt", recurrence: "ONCE", offsetDays: 30, dayHandling: "CLIP_TO_LAST_DAY" }
steps: [ação CREATE_TASK ou CREATE_LEAD]
```

Contrato sem `endsAt` não entra: `gestao_contratos_list_contracts(missingTerm: true)` mostra as apólices incompletas.

### Ações

| `type` | Parâmetros | Faz |
|---|---|---|
| `CREATE_TASK` | `title`, `assigneeType` (`PROPOSAL_OWNER`, `SPECIFIC_USER`), `assigneeUserId`, `priority`, `dueInDays` ou `delayMinutes`, `scheduleType`, `dueDateTime`, `reminderMinutesBefore`, `description` | tarefa ligada à proposta |
| `SEND_NOTIFICATION` | `title`, `message` | aviso dentro do Koter. Vai ao responsável do lançamento, senão a quem vê lançamentos |
| `CHANGE_PROPOSAL_STATUS` | `statusId` | só mexe no funil: nunca implanta nem encerra contrato |
| `MARK_OVERDUE` | `statusId` | move a proposta para um status. Não calcula inadimplência |
| `IMPLANT_CONTRACT` | `statusId?` | implanta a proposta sem contrato. Já tem contrato: só move |
| `CREATE_LEAD`, `CREATE_CONTACT` | abaixo | ponte para o CRM |

Ação que vem em `actions` do contexto com `configurableHere: false` só se configura na tela do Koter.

**Sempre `gestao_automacao_validate_management_automation` antes do `save`.** `gestao_automacao_save_management_automation` sem `automationId` já grava a automação ligada. Automação inválida é erro que só aparece quando devia disparar, e ninguém percebe que não disparou. Pausar e reativar é `active: false` ou `true`, sem mexer na configuração. `publish: true` publica um rascunho. Na edição, `steps` substitui a sequência inteira; e pausar, ou mandar `trigger` ou `steps` novos, **cancela as execuções paradas numa espera**. A configuração atual vem de `gestao_automacao_list_management_automations(ids)`.

## 2.1 · A proposta pode virar card ou contato no CRM

Duas ações fazem a ponte do Gestão para o CRM. As duas exigem **proposta no contexto do gatilho**:

| Ação | Para que serve | Parâmetros |
|---|---|---|
| `CREATE_LEAD` | abre um card no funil: é a ponte fim de vigência → renovação | `teamId` (obrigatório), `statusId`, `title`, `origin`, `tags`, `assigneeType`, `assigneeUserId` |
| `CREATE_CONTACT` | garante um contato vinculado à proposta: é o caminho da produção antiga, que deve virar **contato** e não card | `teamId`, `assigneeType`, `assigneeUserId` (todos opcionais) |

`CREATE_LEAD` reaproveita o contato da proposta (cria um se faltar), vincula o lead de volta e **não duplica**: se a proposta já tem lead aberto naquele time, o passo é sucesso sem criar outro. Medido em 22/09/2026 na corretora de demonstração.

`CREATE_CONTACT` com proposta já vinculada reaproveita e não cria nada. Sem contato, cria um `CUSTOMER` só com o nome do cliente, sem deduplicação por e-mail.

**Para condição, leia `contextFieldNotes`.** `insuranceCompanyId` é a seguradora, `segmentCategoryId` a categoria, `segmentId` o segmento, `status` e `kind` mudam de significado por fonte, `daysOverdue`, `receiptDaysOverdue` e `daysPayable` contam dias. Nunca escreva de memória.

## 3 · Antes de propor qualquer coisa nova

Três perguntas de bom senso, nessa ordem:

1. **Isso já roda?** Confira o catálogo. Forkar é melhor que criar.
2. **Quem recebe?** Notificação para quem não decide nada vira ruído, e ruído faz o corretor desligar tudo.
3. **O que acontece se disparar errado?** Notificação errada é chata; tarefa errada polui a lista; mudança de status errada bagunça relatório; `IMPLANT_CONTRACT` errada cria contrato de verdade.

Mudança de status de proposta **dispara as automações vinculadas àquele status**: cuidado ao combinar automação com `gestao_set_proposal_status` em lote.

**Recuperação com o corretor no comando.** Para cobrança e inadimplência, use `CONTRACT_DEFAULT_STARTED` e `COMMISSION_RECEIPT_OVERDUE` com `CREATE_TASK`. A tarefa chega ao corretor, e ele decide o que falar. `gestao_contratos_list_contracts(statuses: ["SUSPENDED"])` dá a lista.

## 4 · Mensagem automática depende de instância oficial

**Por MCP, a automação de Gestão não manda mensagem**: as ações que `gestao_automacao_save_management_automation` aceita são as da tabela acima, e o aviso por aqui é `SEND_NOTIFICATION`, dentro do Koter. O contexto lista `SEND_WHATSAPP_TEMPLATE` e `SEND_WEBHOOK` com `configurableHere: false`: existem, mas são de tela, e uma automação que usa esses passos tem os passos editados só pela tela.

`SEND_WHATSAPP_TEMPLATE` exige instância oficial Cloud API e template aprovado pela Meta, e falha o passo em proposta sem contato vinculado. Antes de propor régua de mensagem, confira (`koterzap_configuracao_fetch_koterzap_config_context` com `include: ["whatsappInstances"]`, olhando `isCloudApi`). Prometer lembrete por WhatsApp para quem não tem número oficial é promessa que não se cumpre.

## 5 · Acompanhar

`gestao_automacao_list_automation_logs` mostra o que disparou: com `automationId` para uma automação da corretora, ou com `versionGroupId` para um default do Koter. Status: `SUCCESS`, `FAILED`, `CONDITION_NOT_MET`, `WAITING`, `CANCELLED`. Quando o corretor disser "não recebi aviso", é aqui que se responde.

## 6 · Validação e próxima

Liste o que ficou ligado e o que cada uma faz, em uma linha cada. Esta skill é a convergência do ato 3 da passada única: as duas prioridades, comissão e atendimento, terminam aqui.

Depois, em até 4 opções:

- **`koter-crm-lead`** ou **`koter-proposta`**: usar o que foi configurado *(recomendada: configuração sem uso não fecha onboarding)*
- `koter-crm-fundacao`: se a trilha do CRM ainda não foi feita
- `koter-zap-fundacao`: se ainda não há canal de WhatsApp
- parar por aqui

Antes de sugerir, **leia o estado**: ofereça a trilha que ainda está `pendente`, não a que ele acabou de fazer.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Aviso duplicado | automação nova sobre um default ligado | veja o catálogo antes; forke |
| "Desliguei tudo, era muito aviso" | notificação para quem não decide | reveja o destinatário, não o aviso |
| Automação não dispara | gravada sem validar | `gestao_automacao_validate_management_automation` antes do `save` |
| Gatilho antigo de parcela recusado | saiu | `COMMISSION_UNSETTLED_PAST_DUE`, ou `DATE_FIELD` com `COMMISSION_EXPECTATION` |
| Automação de "venda fechada" não dispara | mudar status não implanta | `CONTRACT_IMPLANTED`, depois de `gestao_contratos_save_contract` |
| Aviso de vigência não sai | contrato sem `endsAt` | `gestao_contratos_list_contracts(missingTerm: true)` |
| Dia 31 em fevereiro | `dayHandling` | `CLIP_TO_LAST_DAY` |
| Mudança de status em lote disparou coisa demais | status vinculado a automação | avise antes de mover em lote |
| Mensagem automática não sai | sem instância oficial ou template aprovado | `koterzap_configuracao_list_meta_message_templates` diz se há template `APPROVED` |
| "Ação ignorada: CREATE_LEAD exige uma proposta no contexto." | fonte sem proposta | use fonte com proposta, como `CONTRACT` |
| Condição não casa nunca | campo fora da lista da fonte | leia `contextFieldsBySource` e `contextFieldNotes` |

## Conferência

Gatilhos, fontes, ações, defaults e parâmetros conferidos no inventário e lidos no código em 03/11/2026, não executados.
Os gatilhos de contrato e comissão e a fonte `CONTRACT` nunca foram disparados a partir desta skill.
A não duplicação de `CREATE_LEAD` foi medida em 22/09/2026 na corretora de demonstração e não refeita.
