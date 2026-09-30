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
gestao_comissao_save_commission_campaign          (sem campaignId = cria)
  name, payer, metric, tierMode, startDate, endDate, tiers
  insurerIds, segmentCategoryIds, sellerIds, proposalIds   ← vazio = todos
  minLivesPerProposal, creditRelease
```

Com `campaignId` edita só o que for enviado (`tiers` e cada lista de elegibilidade enviada substituem a atual inteira); `active: false` arquiva. **Reduzir faixas ou elegibilidade depois de crédito pago não estorna nada** — o schema avisa que o delta fica em 0 e a diferença paga a maior só sai por crítica ou débito manual; diga isso antes de encolher uma campanha em andamento. Excluir de vez (`gestao_comissao_delete_commission_campaign`) só passa quando nenhum crédito foi pago e não há a-receber ativo; fora disso, arquive.

**`insurerIds` são ids do catálogo global**, de `insuranceCompanies` em `gestao_list_segment_catalog(segmentId, segmentCategoryId)` — e **cada id é uma linha** (seguradora × categoria × administradora), a mesma que a proposta grava. Para premiar a marca em várias categorias, informe a linha de cada uma; para premiar uma categoria inteira (PF, PME, Adesão), sem escolher seguradora, use `segmentCategoryIds` (o `id` de `categories` em `list_segment_catalog`) e deixe `insurerIds` vazio. O contrato mudou desde a Koter Day de 21/09/2026, quando o id global da Amil parecia valer pela marca inteira: siga a descrição atual da tool.

**`metric`** — `VIDAS` implantadas, `PROPOSTAS` implantadas ou `PREMIO` (R$ vendido). Pergunte assim: *"a meta é por vidas, por contratos fechados ou por valor vendido?"*

**`tierMode`** — a pergunta que muda o valor pago:

- `DEGRAU`: a maior faixa atingida **substitui** as anteriores. Vendeu 60 com faixas em 20 e 50, leva o prêmio dos 50 e só ele.
- `PROGRESSIVO`: os marcos **somam**.

**`tiers`** — limiares únicos e crescentes, cada um com `rewardType`: `FIXA` (valor cheio) ou `POR_UNIDADE` (valor × unidades). Dá para misturar: faixas fixas embaixo e por unidade no topo.

**`payer`** — `COMPANY` (a corretora paga do bolso) ou `SEGURADORA`. Quando é a seguradora, **`creditRelease` é obrigatório** (e com `COMPANY` ele tem que ir `null`):

- `NA_APURACAO` — a corretora adianta o prêmio assim que a meta bate;
- `APOS_RECEBIMENTO` — só credita quando o a-receber da seguradora liquidar.

Essa é a pergunta que protege o caixa: *"a seguradora paga esse prêmio — você adianta para o vendedor ou espera cair?"* O a-receber da seguradora nasce com `gestao_comissao_create_campaign_receivable(campaignId, dueDate)`, que vira um lançamento a receber comum do financeiro; em `APOS_RECEBIMENTO`, o crédito ao vendedor só é liberado até o que já foi recebido.

**Premiação pontual de uma venda** é uma campanha com aquela `proposalIds` e uma faixa "a partir de 1, valor fixo". Não invente ajuste manual no lote para isso.

## 4 · Como o prêmio vira dinheiro

A apuração acompanha **propostas IMPLANTADAS dentro da vigência** — implantada quer dizer no status que tem o papel `IMPLANTED` no funil (`koter-gestao-fundacao`). **Funil sem `IMPLANTED` não conta venda nenhuma**, e a campanha fica zerada sem dar erro. O prêmio entra no lote de repasse como **crédito por delta**: subiu de faixa, o próximo lote credita a diferença. Não é um pagamento único no fim.

Duas consequências que o corretor precisa ouvir:

- **Proposta que cai depois de premiada gera a crítica `CAMPANHA_PROPOSTA_CANCELADA`** — o sistema avisa, mas quem decide o que fazer é ele.
- A apuração é recalculada a cada gravação da campanha (`save_commission_campaign`), por uma varredura diária e na preparação de cada lote. `recompute_commission_campaign` é para a **conferência imediata**, quando o histórico acabou de mudar — proposta implantada, cancelada ou movida de status — e ele quer ver o número agora.

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
| Proposta mudou e o valor da campanha não | a apuração se refaz na gravação, na varredura diária e no lote, não na hora | `recompute_commission_campaign` para ver agora |
| Campanha não conta a venda | proposta não está no status `IMPLANTED`, o funil não tem esse papel, ou está fora da vigência | confira `defaultType` dos status e as datas |
