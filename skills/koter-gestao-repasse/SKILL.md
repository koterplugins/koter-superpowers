---
name: koter-gestao-repasse
description: Fecha o mês e paga os vendedores no Koter — monta o lote de repasse, aplica ajustes e créditos, registra a nota fiscal e efetua o pagamento, com estorno quando preciso. Use quando falarem de fechar o mês, pagar comissão do vendedor, lote de repasse, extrato do vendedor, adiantamento ou estorno de pagamento.
---

# koter-gestao-repasse

A peça que transforma comissão configurada em dinheiro pago. Sem ela, a skill de comissões termina numa planilha bonita e ninguém recebe.

**Nada aqui é automático: o pagamento é sempre um ato manual**, e é assim de propósito.

## 0 · Pré-requisitos, e o que precisa existir antes

Comissão configurada (`koter-gestao-comissoes`) e vendedores cadastrados. E, acima de tudo, **parcelas geradas e com o recebível baixado**: o lote coleta parcela com *repasse pendente, recebível resolvido ou antecipação agendada*. Sem isso, o lote nasce zerado.

**O ciclo inteiro agora é por MCP** — não há mais passo de tela no meio, e a skill não pergunta mais ao corretor se as parcelas foram geradas: ela olha.

```
gestao_comissao_list_proposal_installments(proposalId)
    → { canViewReceivable, total, installments }
    → total 0 = as parcelas ainda não existem
gestao_comissao_generate_proposal_installments(proposalId)
    → único caminho que cria parcela do zero
gestao_comissao_set_installment_receivable_status(installmentId, "RECEBIDA" | "ANTECIPADA", date?)
gestao_comissao_mark_installments_received(installmentIds, date?)   → a mesma baixa, em lote
gestao_comissao_create_payout_batch(sellerId, roundDate?)
```

`generate` exige na proposta início de vigência, valor e uma tabela que resolva para a seguradora e a modalidade; a mensagem de falha diz o que falta. Não precisa de `pricing.value`: comprovado na Koter Day com `pricing: null` e `proposalValue: 1500`, gerou as 25 parcelas.

### O ciclo fechado, medido na Koter Day em 21/09/2026

Proposta Amil PME, R$ 1.500/mês, vigência 01/10/2026, vendedor Walter Gama:

| Passo | Resultado |
|---|---|
| `generate_proposal_installments` | 25 parcelas; a 1ª `AGENCIAMENTO` 180% (recebível 2.700, repasse 1.350), as 24 seguintes `COMISSAO` 8% (120 / 60) |
| `set_installment_receivable_status` na parcela 1 | `receivableStatus: RECEBIDA` |
| `mark_installments_received` nas parcelas 2 e 3 | as duas `RECEBIDA` de uma vez |
| `create_payout_batch(roundDate: 2026-10-10)` | lote `ABERTO` com 3 itens, `grossAmount: 1470` |
| `pay_payout_batch` | `outcome: "PAGO"`, as três parcelas com `payoutStatus: PAGA` |

**A baixa re-ancora a data do repasse.** As três parcelas tinham `payoutExpectedAt` em 10/11, 10/12 e 10/01; depois da baixa, as três foram para **10/10/2026**, a próxima data da cadência depois do recebimento. É por isso que uma rodada só colhe o que já foi baixado — e por que não adianta escolher `roundDate` pelo vencimento da parcela: escolha pela cadência seguinte à baixa.

**Parcela de angariação nunca entra no lote.** O filtro é `isAcquisition: false`, e `isAcquisition` marca só as linhas `ANGARIACAO` — as de `AGENCIAMENTO` entram normalmente.

## 0.1 · Quando o prêmio muda, e quando se erra a baixa

```
gestao_comissao_settle_installment(installmentId, actualGross, date?)
gestao_comissao_edit_installment_due_date(installmentId, dueDate)
gestao_comissao_reset_installment_status(installmentId, track: "receivable" | "payout")
```

- **`actualGross` é o prêmio real do mês, não a comissão.** Medido: uma parcela de 8% sobre 1.500 baixada com `actualGross: 1800` virou `BAIXADA` com `amountReceivable: 144`, `hasDiscrepancy: true` — e **as parcelas seguintes em aberto foram regeneradas** valendo 1.800. Use só quando o prêmio mudou de verdade; prêmio igual ao previsto é `set_installment_receivable_status`.
- **`edit_installment_due_date` aproveita só o dia.** O dia informado vira o dia de vencimento da proposta e re-ancora todas as parcelas ainda em aberto; o mês de cada uma não muda. Medido: dia 20 moveu 5 a 25 de `2027-02-10` para `2027-02-20` e seguintes, e as parcelas já baixadas ou pagas ficaram congeladas.
- **`reset_installment_status` regenera, não "desfaz".** Medido: resetar o recebível da parcela 4 **recriou as parcelas 4 a 25 com ids novos**. Qualquer id de parcela igual ou posterior à resetada que a skill tenha em mãos deixa de existir depois do reset — **releia com `list_proposal_installments` antes do próximo passo**. E confirme com o corretor antes: parcela cujo repasse já foi pago em lote é recusada, com a mensagem apontando o lote a estornar.

## 1 · A rodada

```
gestao_comissao_create_payout_batch(sellerId, roundDate?)
```

Um lote agrupa as parcelas elegíveis de **um** vendedor em **uma** rodada. Omitindo `roundDate`, a data sai da cadência da corretora — na Koter Day, com `MONTHLY` e dia 10, o lote nasceu com `roundDate` no dia 10 do mês seguinte.

**Só existe um lote aberto por vendedor por rodada**; tentar criar outro dá erro. Se já existe, use o que existe.

Origem do lote: `AUTO` (varredura da cadência), `MANUAL` (este caminho) ou `AD_HOC` (legado).

## 2 · O ciclo

```
create_payout_batch          → coleta parcelas, retenções por crítica e ajustes tipados
refresh_payout_batch         → recoleta; obrigatório depois de mudar qualquer regra
update_payout_batch_items    → mexe nos itens coletados
add_payout_batch_adjustment  → crédito ou débito manual
register_payout_batch_invoice→ a nota fiscal do corretor PJ
pay_payout_batch             → o ato manual que paga
revert_payout_batch          → desfaz um lote pago
```

**Ajuste tipado ≠ ajuste manual.** Campanha, crítica, empréstimo e arrasto de diferimento nascem dos coletores automáticos e **não podem ser criados à mão**. Só o ajuste genérico é manual — e é o que você usa para "combinei um extra com ele esse mês".

## 3 · Piso, diferimento e o que o corretor não espera

`payoutMinimumAmount` na rotina financeira é o piso da rodada. **Lote com líquido abaixo do piso é DIFERIDO, não pago** — o valor não some, acumula para a próxima rodada e aparece no extrato como "acumulando para o piso". Explique isso antes de fechar, senão vira ligação do vendedor.

Status possíveis: `ABERTO` (editável), `PAGO`, `DIFERIDO`, `ESTORNADO`.

Bloqueios por vendedor, que vêm de `payoutRules` e travam o pagamento: `payoutBlocked` recusa pagar o lote; `requiresInvoice` recusa pagar sem nota registrada. Quando o pagamento for recusado, é quase sempre um dos dois — diga qual, não "deu erro".

## 4 · Antecipação e empréstimo — nomes diferentes para coisas diferentes

O vendedor fala "me adianta aí" para as duas, e o tratamento é outro:

| | O que é | Tools |
|---|---|---|
| **Antecipação de repasse** | pagar hoje uma parcela que cairia depois; a parcela continua pendente, só é re-datada, e o deságio é abatido no item do lote | `schedule_installment_payout_advance`, `cancel_installment_payout_advance` |
| **Empréstimo ao vendedor** | dinheiro que não é comissão, amortizado nos lotes seguintes | `create_seller_loan`, `register_seller_loan_payment`, `forgive_seller_loan`, `set_seller_loan_suspension`, `cancel_seller_loan` |

Antecipação nunca é paga por fora: ela **entra no lote**. O deságio é congelado na parcela no momento do agendamento; re-marcar atualiza data e deságio.

`allowsPayoutAdvance` por vendedor diz quem pode antecipar.

## 5 · O extrato — o que encerra a discussão

```
gestao_comissao_get_seller_payout_statement(sellerId, from, to)
```

Cada linha é rastreável à origem: parcela por chave natural, crédito de campanha, débito de crítica, amortização de empréstimo, arrasto de diferimento, ajuste manual. É o documento que resolve "por que esse mês veio menor" sem ninguém abrir planilha.

`export_payout_preview` dá a prévia antes de fechar.

## 6 · Regras de segurança desta skill

- **Pagar é irreversível na prática.** `pay_payout_batch` só depois de mostrar o líquido, os débitos e a quem se refere, e receber o "pode pagar" na mesma conversa.
- **`revert_payout_batch` existe**, mas desfazer pagamento gera ruído com o vendedor. Não trate como Ctrl+Z.
- **Mudou regra? `refresh_payout_batch` antes de pagar.** Lote aberto não se atualiza sozinho.
- **Nunca pague em lote vários vendedores sem listar antes** quem entra, quanto cada um leva e quanto some por piso.

## 7 · Validação e próxima

Releia o lote e o extrato do vendedor e diga, em números, o que foi pago, o que ficou diferido e por quê. Depois:

- **`koter-gestao-financeiro`** — o pagamento precisa aparecer no caixa *(recomendada)*
- `koter-gestao-emprestimos-antecipacao` — adiantamentos e empréstimos
- `koter-gestao-campanhas` — metas que viram crédito no lote
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Lote nasce zerado | parcelas não geradas, ou geradas e recebível não baixado | `list_proposal_installments` diz qual dos dois; resolva na hora com `generate` e `mark_installments_received` |
| Parcela de angariação não aparece | `ANGARIACAO` nasce com valor zero e é excluída do lote | só `ANGARIACAO`; `AGENCIAMENTO` entra normal |
| "já existe lote aberto" | um lote por vendedor por rodada | use o que existe |
| Valor não bate depois de mudar a tabela | lote aberto não recoleta sozinho | `refresh_payout_batch` |
| Lote fechado e nada pago | líquido abaixo de `payoutMinimumAmount` | é `DIFERIDO`; acumula para a próxima |
| Pagamento recusado | `payoutBlocked` ou `requiresInvoice` | diga qual dos dois |
| Ajuste de campanha não deixa criar | ajustes tipados vêm dos coletores | só o ajuste manual é criável |

## O preview mostra dinheiro que ainda não existe

Comprovado na Koter Day em 21/09/2026, na proposta `Cliente Teste` (Amil PME, R$ 1.500, 2 vidas), **sem nenhuma parcela gerada**:

`gestao_preview_proposal_payout` devolveu o cronograma inteiro — 25 parcelas, `receivableTotal: 5580`, `payoutTotal: 2790`, margem 2.790 — resolvendo pela grade **Padrão** com `source: "default"` e `sellerIds` vazio.

Duas consequências, e as duas importam no onboarding:

1. **Dá para mostrar a comissão da primeira venda sem passo de tela nenhum.** O corretor vê o número real da tabela dele logo depois de cadastrar a proposta — é a prova que fecha o ato 1, e ela não depende da geração de parcelas.
2. **E é simulação, não caixa.** O lote de repasse continua nascendo vazio até as parcelas existirem e o recebível virar RECEBIDA/ANTECIPADA/BAIXADA. Diga as duas coisas na mesma frase, e já ofereça o passo seguinte, que agora é seu:

> "Nessa venda sua comissão é R$ 2.790, sendo R$ 1.350 no agenciamento e R$ 60 por mês. Isso é o cálculo da sua tabela. Quer que eu já gere as parcelas para virar repasse de verdade?"

**A grade Padrão vale para todos**, mesmo com `sellerIds: []`. Grade com `sellerIds` vazio só é sinal de problema quando **não** é a padrão.
