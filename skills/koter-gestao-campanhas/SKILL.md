---
name: koter-gestao-campanhas
description: Cria campanhas de premiação no Koter, por vidas, propostas ou prêmio, e acompanha a apuração. Use quando falarem de meta, campanha, bônus por volume, concurso de vendas ou incentivo para o time.
---

# koter-gestao-campanhas

Décima etapa. Existe por uma razão específica: **meta é campanha, nunca tabela de comissão.**

## 1 · A confusão que esta skill evita

O corretor descreve meta enquanto fala de percentual: *"quem vender 50 vidas leva 10% em vez de 5%"*. Se isso for parar na grade de comissão, o número sai errado para todo mundo e o erro só aparece no fechamento.

**Separe em voz alta, na hora:** o percentual base fica na tabela (`koter-gestao-comissoes`); o extra por atingir meta é campanha, e entra no lote como **crédito**, não como comissão maior.

**Pré-requisito:** a campanha conta contratos. Venda sem implantação não entra (`koter-contrato`).

## 2 · Detecção

```
gestao_comissao_list_commission_campaigns                     → apurado, creditado e delta de cada uma
gestao_comissao_get_commission_campaign_accrual(campaignId)   → ranking por vendedor e as propostas que contaram
```

Se já existem campanhas, a pergunta "tem meta?" não se faz: confirme e pergunte se mudou.

## 3 · Criar

```
gestao_comissao_save_commission_campaign          (sem campaignId = cria)
  name, payer, metric, tierMode, startDate, endDate, tiers
  insurerIds, segmentCategoryIds, sellerIds, proposalIds   ← vazio = todos
  minLivesPerProposal, creditRelease
```

Com `campaignId` edita só o que for enviado (`tiers` e cada lista de elegibilidade enviada substituem a atual inteira); `active: false` arquiva. **Reduzir faixas ou elegibilidade depois de crédito pago não estorna nada**: o schema avisa que o delta fica em 0 e a diferença paga a maior só sai por crítica ou débito manual. Diga isso antes de encolher uma campanha em andamento. Excluir de vez (`gestao_comissao_delete_commission_campaign`) só passa quando nenhum crédito foi pago e não há a-receber ativo; fora disso, arquive.

**`insurerIds` são ids do catálogo global**, de `insuranceCompanies` em `gestao_list_segment_catalog(segmentId, segmentCategoryId)`, e **cada id é uma linha** (seguradora × categoria × administradora), a mesma que a proposta grava. Para premiar a marca em várias categorias, informe a linha de cada uma; para premiar uma categoria inteira (PF, PME, Adesão), sem escolher seguradora, use `segmentCategoryIds` (o `id` de `categories` em `gestao_list_segment_catalog`) e deixe `insurerIds` vazio.

**`metric`**: `VIDAS` implantadas, `PROPOSTAS` implantadas ou `PREMIO` (R$ vendido). Pergunte assim: *"a meta é por vidas, por contratos fechados ou por valor vendido?"*

**`tierMode`**, a pergunta que muda o valor pago:

- `DEGRAU`: a maior faixa atingida **substitui** as anteriores. Vendeu 60 com faixas em 20 e 50, leva o prêmio dos 50 e só ele.
- `PROGRESSIVO`: os marcos **somam**.

**`tiers`**: limiares únicos e crescentes, cada um com `rewardType`: `FIXA` (valor cheio) ou `POR_UNIDADE` (valor × unidades). Dá para misturar: faixas fixas embaixo e por unidade no topo.

**`payer`**: `COMPANY` (a corretora paga do bolso) ou `SEGURADORA`. Quando é a seguradora, **`creditRelease` é obrigatório** (e com `COMPANY` ele tem que ir `null`):

- `NA_APURACAO`: a corretora adianta o prêmio assim que a meta bate;
- `APOS_RECEBIMENTO`: só credita quando o a-receber da seguradora liquidar.

Essa é a pergunta que protege o caixa: *"a seguradora paga esse prêmio: você adianta para o vendedor ou espera cair?"* O a-receber da seguradora nasce com `gestao_comissao_create_campaign_receivable(campaignId, dueDate)`, que vira um lançamento a receber comum do financeiro; em `APOS_RECEBIMENTO`, o crédito ao vendedor só é liberado até o que já foi recebido.

**Premiação pontual de uma venda** é uma campanha com aquela `proposalIds` e uma faixa "a partir de 1, valor fixo". Não invente ajuste manual no lote para isso.

## 4 · Como o prêmio vira dinheiro

A apuração acompanha **contratos vivos** (ativos ou inadimplentes) de propostas fora do rascunho, com a data de implantação da proposta dentro da vigência da campanha. Proposta sem essa data só entra enquanto a campanha estiver em vigência. **Implantada quer dizer que tem contrato, em qualquer status do funil.** Mover para "Implantada" sem implantar não conta, e a campanha fica zerada sem dar erro: `gestao_list_proposals(hasContract: false)` acha quem ficou de fora. O prêmio entra no lote de repasse como **crédito por delta**: subiu de faixa, o próximo lote credita a diferença. Não é um pagamento único no fim.

Duas consequências que o corretor precisa ouvir:

- **Contrato que cai depois de premiado gera a crítica `CAMPANHA_PROPOSTA_CANCELADA`** e suspende o par campanha e vendedor até alguém decidir. O sistema avisa, mas quem decide é ele: `KEEP_CREDIT`, `DEBIT_NEXT_BATCH` ou `MANUAL_ADJUSTMENT`, em `gestao_financeiro_resolve_finance_issue` (`koter-gestao-conciliacao`).
- A apuração reage a implantar, cancelar, transferir, reativar e desfazer implantação, nunca a mudança de status. Ela também se refaz na gravação da campanha, numa varredura diária e na preparação de cada lote. `gestao_comissao_recompute_commission_campaign` é para a **conferência imediata**, quando ele quer ver o número agora.

## 5 · Validação e próxima

Feche com a simulação, não com a configuração:

> "Campanha de outubro criada: 20 vidas pagam R$ 500, 50 vidas pagam R$ 1.500, e acima de 100 é R$ 20 por vida. Em degrau: quem fizer 60 leva R$ 1.500, não R$ 2.000."

Repetir a consequência do `tierMode` com número é o que evita a discussão no fim do mês.

Depois: `koter-gestao-repasse` para ver o crédito no lote, ou `koter-gestao-automacao`. Meta para o time não dispensa o texto: a IA rascunha o aviso, quem manda é o corretor.

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| Comissão de todo mundo saiu errada | meta embutida na tabela | meta é campanha |
| Vendedor achou que somava | `DEGRAU` explicado como progressivo | diga a consequência com número |
| Prêmio pago e a venda caiu | contrato cancelado depois | crítica `CAMPANHA_PROPOSTA_CANCELADA` |
| Corretora pagou prêmio que a seguradora não pagou | `creditRelease: NA_APURACAO` | `APOS_RECEBIMENTO` protege o caixa |
| Proposta mudou e o valor da campanha não | a apuração se refaz com os fatos do contrato, na varredura e no lote | `gestao_comissao_recompute_commission_campaign` para ver agora |
| Campanha não conta a venda | proposta sem contrato, sem vendedor, ou data de implantação fora da vigência | `gestao_contratos_save_contract(proposalId)`, e confira vendedor e datas |
| Crédito não veio para um vendedor | par suspenso por crítica aberta | `gestao_comissao_get_commission_campaign_accrual` mostra; resolva a crítica |

## Conferência

Tools, parâmetros e a regra de elegibilidade por contrato vivo conferidos no inventário e lidos no código em 03/11/2026, não executados.
Nenhuma campanha foi criada ou apurada com o motor atual de comissão. Os valores de exemplo são ilustrativos.
