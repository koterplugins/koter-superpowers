# Trilha do Gestão — ordem de dependência

> A ordem **entre** as três trilhas, e onde cada passo de tela é dito ao corretor, está em `passada-unica.md`. Este arquivo cobre só a ordem interna deste módulo.

Não é ordem de importância. É o que quebra se for feito fora de ordem.

| # | Skill | Resolve | Depende de | Estado |
|---|---|---|---|---|
| 1 | `koter-gestao-fundacao` | funil de status + entidades de adesão | — | ✅ rodada |
| 2 | `koter-gestao-campos` | campos personalizados: o que ele anota na planilha e o padrão não tem | 1 | ✅ rodada |
| 3 | `koter-gestao-vendedores` | vendedores, hierarquia, quem supervisiona quem | 1 | ✅ rodada |
| 4 | `koter-gestao-comissoes` | grades, tabelas, desvios, rotina de repasse — **o coração** | 1, 3 | ✅ rodada, com prova em número |
| 5 | `koter-gestao-financeiro` | plano de contas, contas bancárias, centros de custo, favorecidos | 1 | ✅ rodada |
| 6 | `koter-gestao-baixa-parcelas` | como dá baixa: uma, em lote, estorno | 5 | ✅ rodada |
| 7 | `koter-gestao-conciliacao` | importar o OFX, sugestões de conciliação, críticas | 5, 6 | ✅ rodada (`import_bank_statement`) |
| 8 | `koter-gestao-repasse` | gerar parcela, baixar o recebível, fechar o mês e pagar | 4 | ✅ ciclo fechado: lote de R$ 1.470 pago |
| 9 | `koter-gestao-emprestimos-antecipacao` | empréstimo ao vendedor e antecipação de repasse | 8 | ✅ rodada |
| 10 | `koter-gestao-campanhas` | metas e premiação | 4, 8 | ✅ rodada |
| 11 | `koter-gestao-automacao` | o que passa a rodar sozinho (os defaults vêm **ligados**) | 1 | ✅ rodada |
| 12 | `koter-proposta` | **cadastro de proposta — a do dia a dia** | 1, 2 | ✅ rodada |

Todas foram validadas contra a corretora de demonstração Koter Day em 21/09/2026, rodando as chamadas de verdade — não só lendo schema.

**Ramo, seguradora e categoria da corretora foram removidos do MCP** em 21/09/2026 — as 15 tools `*_management_segment/insurer/category` não existem mais. As skills trabalham só com o catálogo global. Entidade continua sendo da corretora — a proposta grava `entityId` a partir dela —, e `management_status`, `management_entity` e `management_automation` seguem valendo.

As 1 a 11 são "faça uma vez". A 12 é "faça todo dia", e é onde o onboarding termina.

**Vendedor não é pré-requisito da 12.** `sellerId` é opcional no cadastro de proposta (comprovado na Koter Day), então a 12 pode rodar logo depois da 1. A 3 só vira obrigatória quando entra comissão.

O roteiro de perguntas de cada skill mora na própria skill: abra a `SKILL.md` da etapa antes de perguntar qualquer coisa ao corretor.

## Atalhos legítimos

- Corretor que só quer **parar de errar comissão**: 1 → 3 → 4 → 8. Financeiro depois.
- Corretor que só quer **organizar o caixa**: 1 → 5 → 6 → 7.
- Consultor PF solo: pule 3 (ele é o único vendedor, criado em 1) e 10.

Diga o atalho em voz alta quando escolher um: "vou pular vendedores, porque você é o único".
