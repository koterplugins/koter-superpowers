---
name: koter-gestao-comissoes
description: Configura a comissão da corretora no Koter — tabela de recebimento por operadora, tabela de repasse ao vendedor, variantes, override de liderança e a rotina financeira — e prova o resultado simulando o repasse de uma venda real. Use quando falarem de comissão, agenciamento, percentual da seguradora, quanto o vendedor ganha, tabela de comissionamento, override de gerente ou repasse.
---

# koter-gestao-comissoes

O coração do módulo. **Termina em prova, não em promessa:** a skill monta a regra, roda o preview sobre uma venda que o corretor já comissionou na mão, e mostra o número que o Koter pagaria. Bate, acabou. Não bate, a diferença aponta o campo errado.

## 0 · Pré-requisitos

Fundação (operadoras cadastradas) e vendedores, **se ele repassa**. Corretor que não repassa configura só o recebimento e pula metade da skill.

## 1 · O vocabulário que evita configurar errado com número certo

Em saúde e odonto existem **duas remunerações na mesma venda**, e o corretor costuma falar só de uma:

| | O que é | Faixa típica em saúde PME |
|---|---|---|
| **Agenciamento** | pagamento de entrada, múltiplo da primeira mensalidade, uma vez só | 150% a 200% |
| **Comissão recorrente** | percentual da mensalidade, mês a mês | 3% a 10% |

Perguntar "qual o seu percentual de comissão?" e receber "8%" configura **errado com número certo**: some o agenciamento, que é a maior parte do dinheiro da venda.

Três formatos de recorrente, todos comuns: **vitalícia**, **prazo fixo** (12 ou 24 meses) e **não existe** (só agenciamento). **Nunca assuma vitalícia** — é a suposição que gera projeção de receita errada.

Cuidado com o **agenciamento diluído**: operadora que paga 30% extra da 1ª à 12ª parcela parece recorrente alta e não é, acaba na 12ª.

No Koter isso é nativo: cada linha de parcela carrega `commissionType` com `AGENCIAMENTO`, `COMISSAO`, `MISTO` ou `ANGARIACAO`, e `isLifetime` marca a parcela vitalícia. **Parcelas fixas e vitalícias formam conjuntos de numeração separados** — as duas podem ser `installmentNumber: 1`.

> ⚠️ **`AGENCIAMENTO` e `ANGARIACAO` não são sinônimos no motor.** Uma linha marcada `ANGARIACAO` gera parcela com **zero dos dois lados** e é **excluída do lote de repasse** — no código, `isAcquisition = commissionType === ANGARIACAO`, e o lote filtra por `isAcquisition: false` (`installment-generation.service.ts:1088`, `prisma-installments-repository.ts:827`). `AGENCIAMENTO` não tem nada disso: entra com o percentual cheio e é coletada normalmente.
>
> Ou seja, **o múltiplo da primeira mensalidade se configura como `AGENCIAMENTO`**. Marcá-lo `ANGARIACAO` zera silenciosamente a maior parte do dinheiro da venda. `MISTO` tem efeito próprio: faz as camadas fixa e vitalícia rodarem **em paralelo** a partir da parcela 1, em vez de a vitalícia começar depois da última fixa.

## 2 · Detecção — antes da primeira pergunta

```
gestao_config_fetch_gestao_config_context          → operadoras e vendedores
gestao_comissao_list_commission_grades             → grades existentes (e o overrideSplitMode de cada uma)
gestao_comissao_get_commission_financial_settings  → cadência, prazo, deságio, profundidade de override
gestao_comissao_list_commission_campaigns          → campanhas já criadas
gestao_config_list_sellers                         → se repassa ou não
```

## 3 · O roteiro — seis perguntas, o resto se deduz

Cada uma como card de decisão de 2 a 4 opções, consequência em uma linha, recomendação marcada.

**P1 · Você repassa comissão para alguém?** → *dedutível*: se há vendedores cadastrados, confirme em vez de perguntar. **"Não repassa" encerra o roteiro em P5 e vai direto para a prova.**

**P2 · Com quais operadoras, e qual é a maior?** → *dedutível*: as operadoras já estão cadastradas; a maior sai do volume de propostas. **Configure a maior primeiro e use como modelo.**

**P3 · O que a operadora te paga na entrada?**
> Um múltiplo da primeira mensalidade (agenciamento) / Só o percentual mensal / Os dois / Não sei, vou olhar o contrato

**A pergunta mais valiosa do roteiro.** Nenhuma leitura responde.

**P4 · E o percentual mensal, dura quanto tempo?**
> Enquanto o cliente pagar / 12 meses / 24 meses / Não tem mensal

Vira `isLifetime` ou parcelas fixas numeradas.

**P5 · Quanto a operadora demora para pagar?** → vira `receivableDelayDaysDefault` (ou `save_insurer_payment_term` por operadora). *Parcialmente dedutível* da média real das parcelas já recebidas.

**P6 · O vendedor ganha quando você fatura ou quando você recebe?**
> Quando eu recebo *(recomendado)* / Quando a venda é implantada, eu banco o intervalo

**O Koter é "sobre o recebido" por construção** — o lote só coleta parcela com recebível resolvido. Quem paga antes usa **antecipação** (`schedule_installment_payout_advance`), que re-data a parcela e abate um deságio. Isso é resposta, não limitação: *"Você paga antes de receber? Então sua ferramenta é a antecipação, e dá para configurar um deságio padrão."*

**P7 · Todos ganham igual?** → Sim: só Padrão. Categorias: variantes. Caso a caso: **resista** e proponha Padrão + desvios. *Dedutível* se já existem variantes.

**P8 · Quanto o vendedor leva, do que você recebe?** → pode vir como "metade do que eu recebo"; converta.

**P9 · Supervisor ou gerente ganha sobre a venda do time?** → *pulável* quando não há liderança no organograma.

**P9b · (só se alguém tiver mais de um líder do mesmo tipo)** os dois ganham? → `overrideSplitMode`. **Totalmente dedutível**: só pergunte se a hierarquia mostrar o caso.

**P10 · Quando você paga o time?** → `payoutFrequency`: `DAILY`, `WEEKLY` (exige `payoutWeekdays`) ou `MONTHLY` (exige `payoutDayOfMonth`). **P10b · piso?** → `payoutMinimumAmount`; lote abaixo do piso é **DIFERIDO**, não pago.

**P11 · Imposto: desconta do vendedor ou a casa absorve?** → `passTaxToSeller` por vendedor, `taxPercent` por parcela, `defaultTaxPercent` por tabela. Origem silenciosa de divergência no extrato.

**P12 · Tem meta ou campanha?** → **meta é campanha, nunca tabela.** Se ele descrever meta enquanto fala de percentual, separe as duas coisas em voz alta, senão ele embute a meta na grade e o número sai errado. Fica com `koter-gestao-campanhas`.

**P13 · A prova.** Ver passo 6.

## 4 · Aplicação

**Ordem que economiza trabalho:** rotina financeira → recebimento da maior operadora → repasse Padrão → variantes como exceção. **A variante nasce vazia e herda o Padrão**, então configurar vendedor por vendedor desde o começo é trabalho jogado fora.

```
gestao_comissao_save_commission_financial_settings
  receivableDelayDaysDefault, payoutFrequency, payoutWeekdays, payoutDayOfMonth  (os quatro obrigatórios)
  overrideMaxDepth, payoutMinimumAmount, advanceDiscountPercent, invoiceEmail
```

```
gestao_comissao_publish_commission_table_version
  target: { kind: "RECEIVABLE",      insuranceCompanyId }      ← a margem da casa, visível só a gestor
        | { kind: "PAYOUT_DEFAULT",  insuranceCompanyId }      ← tabela Padrão de repasse
        | { kind: "PAYOUT_VARIANT",  gradeId, insuranceCompanyId }
  rows: [ { sequence, installmentNumber, commissionPercent, commissionType, isLifetime,
            taxPercent, supervisorPercent, managerPercent, directorPercent } ]
  validFrom   ← no futuro, agenda a versão
```

**`insuranceCompanyId` aqui é o id do catálogo global**, o mesmo que a proposta grava. A seguradora da corretora saiu do MCP em 21/09/2026 — só existe o catálogo global. A modalidade é derivada da operadora no servidor; você não a informa.

Publicar encerra a versão vigente e põe a nova em vigor numa transação só. **A primeira publicação de `PAYOUT_DEFAULT` cria a grade "Padrão" sozinha** — não crie grade antes.

Variantes: `create_payout_variant(modalityGroupId, name, sellerIds)`, depois `add_seller_to_commission_grade` / `remove_seller_from_commission_grade`, e `apply_seller_deviation` com `preview_seller_deviation` antes.

### Exemplo real, publicado na Koter Day

Saúde PME, Amil, agenciamento de 180% e recorrente vitalícia de 8%, repassando metade ao vendedor e 10% de override ao gerente:

```
RECEIVABLE:     [ {seq 1, parcela 1, 180%, AGENCIAMENTO, isLifetime false},
                  {seq 2, parcela 1,   8%, COMISSAO,     isLifetime true } ]
PAYOUT_DEFAULT: [ {seq 1, parcela 1,  90%, AGENCIAMENTO, isLifetime false, managerPercent 10},
                  {seq 2, parcela 1,   4%, COMISSAO,     isLifetime true,  managerPercent  1} ]
```

## 5 · O `overrideSplitMode` que vem ligado no pior valor

A grade Padrão nasce com **`overrideSplitMode: "INTEGRAL"`** — confirmado na Koter Day. Integral significa que, se o vendedor tem dois gerentes, **cada um recebe o percentual inteiro e a casa paga duas vezes**. É a configuração que faz a corretora pagar mais do que recebeu e só descobrir no fechamento.

Quando houver alguém com mais de um líder do mesmo tipo, mostre as três opções e recomende `PRINCIPAL`: `gestao_comissao_set_commission_grade_override_split_mode`. Quando não houver, não gaste a pergunta — mas **registre que ficou em INTEGRAL**, para reoferecer quando a equipe crescer.

`overrideMaxDepth` (1 a 10) decide quantos níveis o override sobe; vazio vale o teto de 10.

## 6 · A prova — o passo que encerra a skill

> "Me conta uma venda que você comissionou na mão recentemente."

Cadastre-a (ou use uma já cadastrada) e rode:

```
gestao_preview_proposal_payout(proposalId, payoutSellers: [{ sellerId }])
```

**O preview simula; ele não gera parcela.** É prova de que a regra está certa, não de que o dinheiro existe. Quem cria parcela é `gestao_comissao_generate_proposal_installments`, e daí em diante o ciclo é todo por MCP (ver `koter-gestao-repasse`).

**Para vir número, a proposta precisa de `pricing.value`.** `proposalValue` sozinho não basta: na Koter Day, o preview devolveu `payoutTotal: null` com valor de proposta preenchido, e só passou a calcular depois que `pricing.value` (a mensalidade) foi informado. Se o preview vier vazio, é quase sempre isso — ou vendedor comissionado ausente, ou grade inexistente.

O resultado da configuração acima, numa venda de R$ 1.500/mês:

| Parcela | Recebe | Repassa | Margem |
|---|---|---|---|
| 1 (agenciamento) | 2.700 | 1.350 | 1.350 |
| 2 em diante (vitalícia) | 120 | 60 | 60 |

`hasNegativeMargin` acusa quando a soma dos repasses passa do recebimento — **margem negativa é permitida no Koter** e fica visível ao gestor, então não trate como erro: pergunte se é intencional.

Mostre esses números e pergunte: **bate com o que você pagou?** Se não bate, a diferença aponta o campo: valor errado na parcela 1 é agenciamento; valor errado na cauda é a recorrente ou sua duração; total certo mas data errada é prazo de recebimento.

## 7 · Estado e próxima

Grave o que foi publicado, por operadora, e o que ficou pendente (operadoras sem tabela, `overrideSplitMode` em INTEGRAL, ausência de piso). Depois:

- **`koter-gestao-repasse`** — transformar isso em dinheiro pago *(recomendada: comissão configurada e ninguém pago não fechou o ciclo)*
- `koter-gestao-campanhas` — metas e premiação
- `koter-gestao-financeiro` — plano de contas e caixa
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Preview devolve tudo `null` | falta `pricing.value`, comissionado ou grade | preencha a mensalidade em `pricing.value` |
| Receita projetada alta demais | recorrente assumida vitalícia | P4, sempre |
| Falta o dinheiro da entrada | só a recorrente foi configurada | P3, sempre |
| Casa paga duas vezes o override | `overrideSplitMode: INTEGRAL`, que é o default | `set_commission_grade_override_split_mode` para `PRINCIPAL` |
| Meta embutida na grade | meta é campanha | separe explicitamente; `koter-gestao-campanhas` |
| Tabela publicada não aparece na proposta | `insuranceCompanyId` do cadastro legado da corretora em vez do catálogo | use o id do catálogo global |
| Vendedor reclama de valor que mudou | imposto ou prazo alterado não regenera parcela antiga | mudanças valem para geração futura |
