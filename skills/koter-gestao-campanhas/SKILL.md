---
name: koter-gestao-campanhas
description: Cria campanhas de premiação de comissão no Koter — metas por vidas, propostas ou prêmio, com faixas em degrau ou progressivo — e acompanha a apuração. Use quando falarem de meta, campanha, premiação, bônus por volume, concurso de vendas ou incentivo para o time.
---

# koter-gestao-campanhas

Décima etapa. Existe por uma razão específica: **meta é campanha, nunca tabela de comissão.**

## 1 · A confusão que esta skill evita

O corretor descreve meta enquanto fala de percentual: *"quem vender 50 vidas leva 10% em vez de 5%"*. Se isso for parar na grade de comissão, o número sai errado para todo mundo e o erro só aparece no fechamento.

**Separe em voz alta, na hora:** o percentual base fica na tabela (`koter-gestao-comissoes`); o extra por atingir meta é campanha, e entra no lote como **crédito**, não como comissão maior.

## 2 · Detecção

```
gestao_comissao_list_commission_campaigns        → confirme em vez de perguntar
gestao_comissao_get_commission_campaign_accrual  → como está a apuração de cada uma
```

Se já existem campanhas, a pergunta "tem meta?" não se faz — confirme e pergunte se mudou.

## 3 · Criar

```
gestao_comissao_create_commission_campaign
  name, payer, metric, tierMode, startDate, endDate, tiers
  insurerIds, modalityIds, sellerIds, proposalIds   ← vazio = todos
  minLivesPerProposal, creditRelease
```

**`insurerIds` são ids do catálogo global**, de `gestao_list_segment_insurance_companies` — e **um id vale pela marca inteira**, em todas as modalidades e administradoras. Para restringir a campanha, use `modalityIds` (o `groupId` de `fetch_gestao_context.modalities`), nunca várias linhas da mesma seguradora. Comprovado na Koter Day em 21/09/2026: campanha criada com o id global da Amil e o `groupId` de PME voltou com `insurerNames: ["Amil"]` e `modalityNames: ["PME"]`.

**`metric`** — `VIDAS` implantadas, `PROPOSTAS` implantadas ou `PREMIO` (R$ vendido). Pergunte assim: *"a meta é por vidas, por contratos fechados ou por valor vendido?"*

**`tierMode`** — a pergunta que muda o valor pago:

- `DEGRAU`: a maior faixa atingida **substitui** as anteriores. Vendeu 60 com faixas em 20 e 50, leva o prêmio dos 50 e só ele.
- `PROGRESSIVO`: os marcos **somam**.

**`tiers`** — limiares únicos e crescentes, cada um com `rewardType`: `FIXA` (valor cheio) ou `POR_UNIDADE` (valor × unidades). Dá para misturar: faixas fixas embaixo e por unidade no topo.

**`payer`** — `COMPANY` (a corretora paga do bolso) ou `SEGURADORA`. Quando é a seguradora, **`creditRelease` é obrigatório**:

- `NA_APURACAO` — a corretora adianta o prêmio assim que a meta bate;
- `APOS_RECEBIMENTO` — só credita quando o a-receber da seguradora liquidar.

Essa é a pergunta que protege o caixa: *"a seguradora paga esse prêmio — você adianta para o vendedor ou espera cair?"*

**Premiação pontual de uma venda** é uma campanha com aquela `proposalIds` e uma faixa "a partir de 1, valor fixo". Não invente ajuste manual no lote para isso.

## 4 · Como o prêmio vira dinheiro

A apuração acompanha **propostas IMPLANTADAS dentro da vigência**, e o prêmio entra no lote de repasse como **crédito por delta**: subiu de faixa, o próximo lote credita a diferença. Não é um pagamento único no fim.

Duas consequências que o corretor precisa ouvir:

- **Proposta que cai depois de premiada gera a crítica `CAMPANHA_PROPOSTA_CANCELADA`** — o sistema avisa, mas quem decide o que fazer é ele.
- `recompute_commission_campaign` reprocessa quando a regra ou o histórico mudam. Rode depois de mexer em faixa.

## 5 · Validação e próxima

Feche com a simulação, não com a configuração:

> "Campanha de outubro criada: 20 vidas pagam R$ 500, 50 vidas pagam R$ 1.500, e acima de 100 é R$ 20 por vida. Em degrau — quem fizer 60 leva R$ 1.500, não R$ 2.000."

Repetir a consequência do `tierMode` com número é o que evita a discussão no fim do mês.

Depois: `koter-gestao-repasse` para ver o crédito no lote, ou `koter-gestao-automacao`.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Comissão de todo mundo saiu errada | meta embutida na tabela | meta é campanha |
| Vendedor achou que somava | `DEGRAU` explicado como progressivo | diga a consequência com número |
| Prêmio pago e a venda caiu | proposta cancelada depois | crítica `CAMPANHA_PROPOSTA_CANCELADA` |
| Corretora pagou prêmio que a seguradora não pagou | `creditRelease: NA_APURACAO` | `APOS_RECEBIMENTO` protege o caixa |
| Faixa mudou e o valor não | apuração não reprocessa sozinha | `recompute_commission_campaign` |
| Campanha não conta a venda | proposta não está IMPLANTADA ou está fora da vigência | confira status e datas |
