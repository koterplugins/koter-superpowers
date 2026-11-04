# Trilha do Gestão: ordem de dependência

> A ordem **entre** as trilhas, e onde cada passo de tela é dito ao corretor, está em `passada-unica.md`. Este arquivo cobre só a ordem interna deste módulo.

Não é ordem de importância. É o que quebra se for feito fora de ordem.

## O caminho do dinheiro

**A proposta não carrega dinheiro.** O dinheiro só lê o contrato, e parcela de comissão não existe mais: o motor monta sozinho o que é previsto.

```
proposta → contrato → expectativa e repasse previstos → recebimento →
alocação → lote de conciliação → conferência → a pagar → lote de repasse
```

| Etapa | O que acontece | Tool principal | Skill |
|---|---|---|---|
| 0 · Ligar | sem `commissionTrackedSince`, nada é gerado e nenhuma pendência abre. Depois vêm as regras de recebimento e repasse | `gestao_comissao_save_commission_settings`, `gestao_comissao_publish_commission_table` | `koter-gestao-comissoes` |
| 1 · Proposta | não cria comissão nem contrato | `gestao_save_proposal` | `koter-proposta` |
| 2 · Contrato | **só nasce por aqui.** Mudar status nunca implanta | `gestao_contratos_save_contract` com `proposalId` | `koter-contrato` |
| 3 · Expectativa | sai sozinha, numa fila: logo depois de implantar, a lista pode vir vazia | `gestao_comissao_list_commission_expectations`, `gestao_comissao_get_contract_commission_status` | `koter-contrato` |
| 4 · Recebimento | quatro entradas: extrato do pagador, valor de comissão, baixa pelo esperado, prêmio pago. Prêmio não é comissão | `gestao_comissao_save_commission_statement`, `gestao_comissao_save_commission_receipt`, `gestao_comissao_save_commission_allocation`, `gestao_comissao_save_premium_settlement` | `koter-gestao-baixa-parcelas` |
| 5 · Lote de conciliação | toda baixa cai num lote | `gestao_comissao_save_settlement_lot` | `koter-gestao-baixa-parcelas` |
| 6 · Conferência | **toda baixa nasce não conferida.** Sem conferir, o repasse não vira a pagar | `gestao_comissao_save_lot_conference` | `koter-gestao-baixa-parcelas` |
| 7 · Repasse | conferido, vira a pagar na data da rotina. Olhe `pendingConference` antes de pagar | `gestao_comissao_save_payout_batch`, `gestao_comissao_pay_payout_batch` | `koter-gestao-repasse` |

Toda tool que move dinheiro exige `idempotencyKey`: uma por lançamento, a mesma na repetição. Desfazer vai do mais recente para o mais antigo, e isso mora nas skills de baixa e repasse.

O que travou aparece em `gestao_comissao_list_commission_pendencies`. **"Dei baixa e o vendedor não recebeu"** quase sempre é a etapa 6.

## A ordem

| # | Skill | Resolve | Depende de |
|---|---|---|---|
| 1 | `koter-gestao-fundacao` | funil de status, com os papéis `IMPLANTED` e `CANCELLED`, e entidades de adesão | nada |
| 2 | `koter-gestao-campos` | campos personalizados: o que ele anota na planilha e o padrão não tem | 1 |
| 3 | `koter-gestao-vendedores` | vendedores, hierarquia, quem supervisiona quem | 1 |
| 4 | `koter-gestao-comissoes` | **o coração:** acompanhamento, regras de recebimento e repasse, pagadores, estorno, rotina | 1, 3 |
| 5 | `koter-proposta` | **cadastro de proposta, a do dia a dia** | 1, 2 |
| 6 | `koter-contrato` | **implantar, registrar evento, trocar vendedor, prévia de comissão** | 1, 5. Para gerar comissão, também 4 |
| 7 | `koter-gestao-financeiro` | plano de contas, contas bancárias, centros de custo, favorecidos | 1 |
| 8 | `koter-gestao-baixa-parcelas` | receber: extrato, baixa, lote, conferência, estorno | 4, 6, 7 |
| 9 | `koter-gestao-conciliacao` | importar o OFX, sugestões de conciliação, críticas | 7, 8 |
| 10 | `koter-gestao-repasse` | fechar o mês e pagar o vendedor | 4, 8 |
| 11 | `koter-gestao-emprestimos-antecipacao` | empréstimo ao vendedor e antecipação de repasse | 10 |
| 12 | `koter-gestao-campanhas` | metas e premiação | 4, 6 |
| 13 | `koter-gestao-automacao` | o que passa a rodar sozinho (os defaults vêm **ligados**) | 1 |
| 14 | `koter-importacao` | trazer carteira de planilha ou de outro sistema, sem pagar o passado de novo | 1, 3. Com comissão no histórico, também 4 |

A 5 e a 6 são "faça todo dia", e é onde o onboarding termina. As outras são "faça uma vez". A 14 é sob demanda, e a ordem dela está em `passada-unica.md`.

**A 4 aparece antes da 5 na dependência, não no onboarding.** A passada única cadastra a primeira venda antes, porque `koter-proposta` e `koter-contrato` não precisam de comissão para rodar. Só a expectativa precisa. Implantar sem acompanhamento funciona; o dinheiro aparece depois.

**Vendedor não é pré-requisito da 5.** `sellerId` é opcional no cadastro de proposta. A 3 só vira obrigatória quando entra comissão.

**Só o contrato conta como venda.** Em relatório, campanha e renovação, vale o contrato, não o status da proposta. Os papéis `IMPLANTED` e `CANCELLED` só dizem para onde a proposta vai quando a ação não informa destino. Corretora com vendas antigas sem contrato: checagem 8 da roteadora.

**Segmento, seguradora e categoria não são da corretora.** As skills trabalham só com o catálogo global. Entidade continua sendo da corretora: a proposta grava `entityId` a partir dela.

**Skill de dinheiro confere a conexão antes.** Chame `list_toolsets`. Sem `gestao-contratos`, pare e peça reconexão.

O roteiro de perguntas de cada skill mora na própria skill: abra a `SKILL.md` da etapa antes de perguntar qualquer coisa ao corretor.

## Atalhos legítimos

- Corretor que só quer **parar de errar comissão**: 1 → 3 → 4 → 6 → 8 → 10. Financeiro depois.
- Corretor que só quer **organizar o caixa**: 1 → 7 → 8 → 9.
- Consultor PF solo: pule 3 (ele é o único vendedor) e 12.
- Corretora que **vem de outro sistema**: 1 → 3 → 4 → 14, e só então o resto.

Diga o atalho em voz alta quando escolher um: "vou pular vendedores, porque você é o único".
