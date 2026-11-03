---
name: koter-importacao
description: Migra o histórico de outro sistema para o Koter em dois atos, planejar e confirmar. Use quando falarem de migrar, importar planilha, trazer carteira de ERP ou desfazer uma importação.
---

# koter-importacao

Traz o passado de outro sistema para o Koter sem disparar nada. **Nada é gravado no primeiro ato.** `importacao_submit_import` valida e planeja. Só `importacao_confirm_import` grava.

A escrita é silenciosa e mantém as datas originais: sem automação, sem sincronização, sem distribuição, sem WhatsApp, sem notificação. Isso é o que torna seguro trazer anos de histórico, e também o motivo de nenhum aviso sair para o corretor: confira lendo.

## Quando usar

| Situação | Caminho |
|---|---|
| Migrar de ERP ou planilha com histórico | **esta skill** |
| Trazer carteira com comissão recebida e repasse pago, sem pagar de novo | **esta skill**, alvo `PROPOSALS` com `installments` |
| Carteira antiga, sem precisar do passado de comissão | `commissionTrackedSince` e `gestao_comissao_save_contract_tracked_from` (`koter-contrato`) |
| Uma venda nova | `koter-proposta`, depois `koter-contrato` |
| Extrato do banco | alvo `BANK_STATEMENTS`, ou `gestao_financeiro_import_bank_statement` (`koter-gestao-conciliacao`) |
| Extrato de comissão da seguradora | `gestao_comissao_save_commission_statement`, **não** importação |

## 0 · Pré-requisitos

1. **Conexão.** `importacao` é categoria própria: conexão antiga não a ganha sozinha. Chame `list_toolsets` e, se faltar, peça para reconectar.
2. **Permissão por alvo.** `importacao_fetch_import_context` diz, alvo a alvo, `available` e `unavailableReason`. Importar exige o mesmo cargo que criar aquele registro, e o módulo contratado.
3. **Comissão ligada antes.** Para trazer parcelas com comissão, a regra de recebimento precisa estar publicada e `commissionTrackedSince` ligado **antes** de importar. Sem isso, as parcelas de prêmio entram e as comissões não: a linha avisa. Veja `koter-gestao-comissoes`.
4. **Funil pronto.** `statusId` é o status **atual** no Koter. Monte o funil antes (`koter-gestao-fundacao`).
5. **A corte do passado.** Pergunte: *"Até que data já está tudo acertado com o vendedor?"* Essa é a `settledBefore`, a defesa contra pagar o passado de novo.

**Dados pessoais:** as linhas trazem CPF, valor e apólice. Use na hora e não guarde nada disso em memória nem em skill.

## 1 · Os dois atos

```
importacao_fetch_import_context()                          → alvos, limites, importações recentes
importacao_get_import_schema(target, segmentId?)           → rowSchema, orientações, exemplo, references

ATO 1, sem gravar:
importacao_submit_import(target, sourceSystem, rows, options?)   → importId, summary, pendingDecisions

ATO 2, grava:
importacao_confirm_import(importId, decisions?, undecided?)
importacao_get_import_status(importId, onlyFailed?)        → até COMPLETED ou FAILED
```

**Mostre o plano antes do ato 2.** O plano vale 24 horas, e um novo `importacao_submit_import` substitui o anterior. Se alguma linha for inválida, nada é planejado: os erros vêm por linha, contadas a partir de 0, com até 50 problemas de uma vez. Corrija e reenvie o lote.

## 2 · A ordem de um ERP

1. `SELLERS`
2. `CONTACTS` e `LEADS`
3. `PROPOSALS`, que apontam para os vendedores pelo `externalId`
4. `FINANCE_ENTRIES` por último

## 3 · Alvos e limites

| `target` | Cria | Máximo por importação |
|---|---|---|
| `SELLERS` | vendedor | 500 |
| `CONTACTS` | contato, nunca duplica | 1000 |
| `LEADS` | lead, com venda ou perda na data real | 1000 |
| `PROPOSALS` | proposta. Com parcelas, também contrato, prêmio e comissões | 500, e até 600 `installments` por linha |
| `FINANCE_ENTRIES` | lançamento, já liquidado ou cancelado quando assim terminou | 1000 |
| `BANK_STATEMENTS` | extrato OFX, um arquivo por linha | 5 |

Acima do limite, divida em várias importações. Segmentos diferentes em `PROPOSALS`: uma importação por segmento, porque os campos obrigatórios mudam.

Uma importação ou desfazer na fila por usuário, três por corretora. Só quem enviou enxerga a importação.

## 4 · Montar as linhas

- **`sourceSystem`** é o nome do sistema de origem (o sistema antigo, ou `PLANILHA`), **igual em toda importação dele**. Com o `externalId`, é o que reconhece o mesmo registro.
- **`externalId`** é o id no sistema de origem. Mande sempre que houver: reimportar atualiza em vez de duplicar. Sem ele, só o reenvio idêntico é reconhecido.
- **Ids vêm de `references`** de `importacao_get_import_schema`. Troque nome por id, nunca invente. Faltou valor obrigatório: pergunte.
- **Propostas:** `importacao_get_import_schema` com `segmentId`, senão o catálogo não vem. Seguradoras saem de `gestao_list_segment_catalog` com `segmentCategoryId`, obrigatório; `insuranceCompanySearch` só afina dentro da categoria.
- **Datas estritas.** Um dia (vencimento, nascimento, vigência) vai só como `AAAA-MM-DD`, sem hora. Um momento (`createdAt`, pagamento, nota) aceita hora.
- **Campo fora do `rowSchema` é recusado.** Omita o opcional sem valor, em vez de mandar texto vazio.
- **Vendedor na linha:** `seller` e `payoutSellers` por `id`, `externalId` ou `document`, um só. O repasse sai das grades do Koter, não da linha.
- **Cliente que já comprou e não negocia é contato**, não lead.

| `options` | Para quê |
|---|---|
| `settledBefore` (`AAAA-MM-DD`) | parcela sem informação de recebimento ou repasse, vencida antes dela, conta como comissão recebida e repasse pago |
| `overwrite` | ao unificar, substitui os campos que a linha traz. Padrão: só preenche o vazio |
| `allowIncompleteHistory` | aceita registro antigo sem campo que hoje é obrigatório. **Só com o aval do corretor** |

## 5 · Parcelas: três valores, nunca confundir

```
installments: [{ number, dueDate, value,
                 receivable: { received?, amount?, at? },
                 payout: { paid?, at? } }]
```

| Campo | É o quê | Vira |
|---|---|---|
| `value` | **prêmio** do cliente no mês | parcela de prêmio importada |
| `receivable` | **comissão** que a corretora recebeu do pagador | baixa num lote de importação histórica |
| `payout` | **repasse** pago aos vendedores | pagamento em lote histórico |

Trocar um pelo outro gera número errado sem recusa. Confirme com o corretor qual coluna da planilha é qual antes de montar.

- `number` 1 é o mês da vigência. Parcelas exigem `coverageStart`.
- Linha com parcelas, ou em status com o papel `IMPLANTED`, nasce com contrato.
- Sem `receivable.amount`, vale o que a tabela prevê.
- `payout.paid` exige comissão recebida.
- Repasse não pago fica a pagar no próximo lote do vendedor.
- Depois da última parcela importada, o Koter prevê o resto pela tabela.
- Parcela vencida na importação não faz o contrato cair em inadimplência.

**Único caso que nasce conferido:** o lote de baixa da importação histórica já vem fechado e conferido. Todo resto no Koter precisa de conferência.

**Dupla contagem:** comissão importada nas parcelas de `PROPOSALS`, ou dinheiro que veio em OFX, não entra de novo como lançamento em `FINANCE_ENTRIES`.

## 6 · Decidir as linhas suspeitas

Proposta repetida é detectada por CPF ou CNPJ do cliente, segmento e seguradora. Renovações caem aqui. Vendedor e lançamento também perguntam.

```
importacao_confirm_import(importId, decisions: [{ row, action, recordId? }])
importacao_confirm_import(importId, undecided: "SKIP" | "CREATE")
```

| `action` | Faz |
|---|---|
| `SKIP` | pula |
| `MERGE` | unifica com o registro existente, preenchendo o que falta |
| `LINK` | só vincula ao existente |
| `CREATE` | cria mesmo assim |

`SELLERS` e `FINANCE_ENTRIES` não aceitam `MERGE`: veja `allowedActions` na resposta. `recordId` é um dos `candidates` da linha. Linha que repete outra do lote (`IN_BATCH`) só pode ser pulada. `undecided` decide todas de uma vez: só com o aval do corretor.

**Merge nunca implanta**, e só baixa parcela cujo mês bate e que ainda está prevista. Avisos que podem voltar:

- `Parcela N: o vencimento não confere com o do contrato; não foi baixada na mescla.`
- `Parcela N: não existe no contrato; não foi acrescentada na mescla.`

## 7 · Acompanhar

```
importacao_get_import_status(importId)                    → status, progresso, results por linha
importacao_get_import_status(importId, onlyFailed: true)  → só o que falhou
importacao_get_import_status(sourceSystem: "PLANILHA")    → o placar do que já veio daquele sistema
```

Status: `PLANNED`, `PENDING`, `PROCESSING`, `COMPLETED`, `FAILED`. `outcome` por linha: `CREATED`, `UPDATED`, `LINKED`, `SKIPPED`, `FAILED`. Enquanto estiver na fila, consulte de novo em alguns segundos.

Linhas `FAILED`: corrija e **reenvie só elas**. O que já entrou é reconhecido e pulado. Mudança de cargo ou conexão revogada para a importação no meio, com o motivo.

Com parcelas, confira uma amostra: `gestao_comissao_get_contract_commission_status(contractId)`, e a pendência `HISTORICAL_PAYOUT_UNRECORDED` em `gestao_comissao_list_commission_pendencies`, que abre quando um repasse pago não pôde ser marcado.

## 8 · Desfazer

```
importacao_preview_import_undo(importId)                  → sem gravar: o que sai e o que fica
importacao_undo_import(importId, confirm: true)           → só depois do aval
importacao_get_import_status(importId)                    → acompanhe em undo
```

| Resultado | Quer dizer |
|---|---|
| `DELETED` | sai o registro que a linha criou |
| `REVERTED` | sai de um registro existente o que a linha acrescentou |
| `UNBOUND` | só desfaz o vínculo |
| `SKIPPED` | fica: houve movimento depois, está fora do que o cargo exclui, ou outra importação usa o registro |
| `NOT_UNDOABLE` | não tem como desfazer |
| `NOTHING` | não gravou nada |

**Exclusão definitiva, sem lixeira e sem volta.** Por isso o `importacao_preview_import_undo` vem sempre antes, e o corretor vê o resultado.

- Só quem enviou, com a permissão de excluir aquele tipo de registro.
- Uma vez por importação. Um desfazer que parou no meio continua de onde parou.
- Campos preenchidos por unificação ficam (`fieldsKept`).
- Recebimentos lançados num contrato que já existia ficam.
- Reimportar as mesmas linhas depois cria de novo.
- O lote de pagamento da importação histórica não se estorna por `gestao_comissao_undo_payout_batch`: só o desfazer da importação o remove.

## 9 · Validação e próxima

Compare com a origem, em números:

> "Vieram 412 de 412 propostas da planilha, 380 com contrato. Três linhas falharam por seguradora fora do segmento e estão listadas. Nada foi avisado a ninguém."

Depois, em até 4 opções:

- **`koter-contrato`** para olhar uma venda importada *(recomendada)*
- `koter-gestao-repasse` para o próximo lote, que paga só o que ficou em aberto
- mais um alvo da migração
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Comissões não entraram | sem tabela, ou `commissionTrackedSince` nulo | ligue antes e reimporte. A linha avisa |
| Vendedor recebeu o passado de novo | sem `settledBefore`, sem `payout` | defina a corte antes do ato 1 |
| Número de comissão absurdo | `value` e `receivable.amount` trocados | `value` é prêmio |
| Dinheiro dobrado no financeiro | comissão também lançada em `FINANCE_ENTRIES` | leia a dupla contagem no passo 5 |
| Registro duplicado na segunda rodada | `sourceSystem` escrito diferente, ou sem `externalId` | mesmo nome sempre |
| Vendedor não encontrado na proposta | `SELLERS` não importado antes, ou de outro `sourceSystem` | respeite a ordem |
| Plano sumiu | passou de 24 horas, ou houve novo `importacao_submit_import` | planeje de novo |
| Data recusada | hora num campo de dia, ou célula vazia como texto | `AAAA-MM-DD`, ou omita o campo |
| Importação não entra na fila | já existe uma sua, ou três na corretora | acompanhe a ativa e espere |
| Desfazer deixou registros | houve movimento depois | leia o motivo de cada `SKIPPED` |

## Conferência

Tools, alvos, limites e opções conferidos no inventário e lidos no código em 03/11/2026, não executados.
Nenhuma importação real foi planejada, confirmada ou desfeita por esta skill, e os números de exemplo são ilustrativos.
Se as referências de `importacao_get_import_schema` funcionam sem os outros toolsets na conexão não foi comprovado.
