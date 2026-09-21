---
name: koter-gestao-conciliacao
description: Concilia o extrato bancário com os lançamentos no Koter e configura as críticas financeiras — divergência de valor, proposta cancelada com campanha, vendedor desligado com dívida. Use quando falarem de conciliação, extrato, OFX, bater o banco, divergência de valor ou críticas financeiras.
---

# koter-gestao-conciliacao

Sétima etapa. É a skill que transforma "acho que recebi" em "recebi, e bate".

## 0 · A importação começa aqui

```
gestao_financeiro_import_bank_statement(bankAccountId, fileName, content, encoding?)
    → { statementId, imported, duplicates, skipped, periodStart, periodEnd }
```

**Só OFX** — não PDF, não CSV, não planilha. `fileName` termina em `.ofx`, `content` é o texto do arquivo (`encoding: "base64"` só para OFX antigo fora de UTF-8), limite de 10 MB. **Reimportar o mesmo período é seguro**: transação já conhecida volta em `duplicates` e não entra de novo.

O que a skill pede ao corretor é o arquivo, não um passeio pela tela:

> "Me manda o OFX do mês da conta principal que eu importo e concilio daqui. Se você já importou pela tela, tudo bem também: eu leio o que entrou."

Depois da importação, `list_bank_statements` e `list_bank_transactions` mostram o que chegou. **Confirme lendo**, sempre — o número de `imported` é a prova, não a promessa.

## 1 · Conciliar

```
gestao_financeiro_list_bank_transactions(bankAccountId, ...)   → o que o banco diz
gestao_financeiro_get_reconcile_suggestions(transactionId)     → o que o Koter acha que casa
gestao_financeiro_reconcile_bank_transaction(...)              → casa
gestao_financeiro_unreconcile_bank_transaction(...)            → desfaz
```

Trabalhe pelas sugestões, não pela lista crua: o corretor não quer ler 200 linhas de extrato. Mostre as que casam com confiança alta, peça um "pode casar" para o bloco, e traga só as duvidosas uma a uma.

Transação que não casa com nada costuma ser: comissão que caiu junta de várias propostas, tarifa bancária, ou lançamento que ele nunca registrou. As três têm tratamento diferente — pergunte antes de forçar.

## 2 · As críticas — o que o Koter vigia sozinho

`gestao_financeiro_get_finance_issue_settings` devolve quatro tipos, e na Koter Day **os quatro nascem ligados com tolerância zero**:

| Tipo | O que pega |
|---|---|
| `PARCELA_VALOR_DIVERGENTE` | a operadora pagou diferente do previsto |
| `CONCILIACAO_VALOR_DIVERGENTE` | o extrato não bate com o lançamento conciliado |
| `CAMPANHA_PROPOSTA_CANCELADA` | premiação paga sobre venda que caiu |
| `VENDEDOR_DESLIGADO_COM_DIVIDA` | saiu devendo empréstimo ou adiantamento |

**Tolerância zero significa que um centavo vira crítica.** Operadora que arredonda e banco que cobra tarifa geram fila de críticas sem valor nenhum. É a única pergunta que vale fazer aqui:

> "Diferença de quanto você quer que eu ignore? Até R$ 1 / até R$ 5 / nenhuma, quero ver tudo"

`save_finance_issue_settings` grava a tolerância por tipo.

## 3 · Resolver

```
gestao_financeiro_list_finance_issues          → a fila, com openCount e openAmount
gestao_financeiro_get_finance_issue(issueId)   → esperado, real, diferença, origem e ações disponíveis
gestao_financeiro_resolve_finance_issue        → resolve
gestao_financeiro_ignore_finance_issue         → ignora
```

`get_finance_issue` já traz **as ações de resolução válidas para aquele tipo** — use o que ele oferece em vez de improvisar. E mostre sempre esperado, real e diferença juntos: é a diferença que explica, não o valor.

**Ignorar não é resolver.** Ignorada some da fila e o dinheiro continua errado. Só ofereça ignorar quando a diferença for irrelevante e recorrente — e aí a resposta melhor é ajustar a tolerância, não ignorar uma a uma.

## 4 · Validação e próxima

Feche com a fila, não com a configuração:

> "Extrato de setembro conciliado: 38 de 41 transações casadas, 3 críticas abertas somando R$ 84. Duas são arredondamento da operadora; subi a tolerância para R$ 1 e elas somem no próximo mês."

Depois:

- **`koter-gestao-repasse`** — pagar o time com o recebido conferido *(recomendada)*
- `koter-gestao-emprestimos-antecipacao` — adiantamentos
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| "Importei e não apareceu" | arquivo que não é OFX, ou período já importado | a resposta diz: `imported: 0` com `duplicates > 0` é reimportação, não falha |
| Enxurrada de críticas | tolerância zero, que é o default | `save_finance_issue_settings` por tipo |
| Transação não casa com nada | comissão agrupada, tarifa, ou lançamento inexistente | trate cada caso; não force o match |
| Crítica ignorada volta | ignorar não corrige a origem | resolva, ou ajuste a tolerância |
| Conciliou errado | match forçado | `unreconcile_bank_transaction` |
