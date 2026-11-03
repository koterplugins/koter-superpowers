---
name: koter-multicalculo-auto
description: Cota seguro auto de pessoa física em várias seguradoras pelo Koter e compara as ofertas. Use quando o corretor pedir para cotar carro, moto ou caminhão, renovar seguro auto ou recotar.
---

# koter-multicalculo-auto

Manual do agente que cota auto para o corretor, do pedido solto ao texto pronto para o cliente. Disparar gasta consulta paga, login da corretora nos portais e limite de disparo, e a criação não se desfaz. Por isso a ordem abaixo importa.

O detalhe mora em três arquivos: `references/parametros.md` (parâmetros, enums, mapa do veículo, chaves de recotação), `references/armadilhas.md` (o que dá errado em silêncio) e `references/erros.md` (cada mensagem, cada `errorCode`, a conduta).

## 0 · Limites que valem sempre

- **Você fala com o corretor, nunca com o segurado.** Nenhuma tool manda mensagem a cliente, e o agente de WhatsApp do KoterZap não tem ferramenta de auto. Não prometa envio nem multicálculo no WhatsApp.
- **Só pessoa física.** A cotação auto do Koter só aceita CPF, na tela e aqui. Com CNPJ, diga isso na hora e pare: esse caso fica no portal da seguradora.
- **A cotação termina na oferta escolhida.** Não há emissão, proposta, cancelamento de busca nem exclusão de cotação.
- **O `url` da cotação é tela interna.** Serve ao corretor. Nunca vai para o segurado.
- **Quem recomenda é o corretor.** Você compara e aponta diferenças. Não diga "a melhor".
- **Dado de segurado.** CPF, nascimento e placa passam pela conversa da IA, pelo Koter e pelos portais. Não grave CPF, apólice nem valor em memória ou skill. Confira a regra de dados do seu plano de IA antes de usar dado real.

Conexão: precisa do toolset `cotacao-auto`. Se a tool não aparecer, rode `list_toolsets`. Deixe na IA como "Precisa de aprovação": `cotacao_auto_create_auto_quote`, `cotacao_auto_dispatch_auto_quote` e `cotacao_auto_create_auto_quote_version`.

## 1 · Comece por quem cota

```
cotacao_auto_get_auto_insurer_availability(vehicleType: "CAR" | "MOTORCYCLE" | "TRUCK")
```

| `credentialStatus` | O que fazer |
|---|---|
| `READY`, `NOT_LINKED` | Entram na cotação |
| `MISSING`, `SUSPENDED` | Ficam de fora. Repita o `reason` ao corretor. Credencial se resolve na tela de credenciais do Koter |

Nenhuma pronta: pare aqui, antes de pedir dado ao corretor. Depois, duas leituras antes de perguntar qualquer coisa:

- `crm_list_leads(search: "<nome>")`, se a conexão tiver `crm`. O `leadId` só entra na criação; depois não dá para vincular. Mais de um João: pergunte qual.
- `cotacao_auto_list_auto_quotes(search: "<nome>")`. Se o cliente já tem cotação, ofereça recotar em vez de criar outra.

## 2 · Peça tudo em bloco, uma vez

Uma mensagem só, sem questionário. Quem já trouxe o dado não é perguntado de novo.

> Para cotar, me manda de uma vez:
> - CPF, nome completo, nascimento, sexo e estado civil do segurado
> - CEP onde o carro dorme
> - placa (ou chassi)
> - seguro novo ou renovação. Se renovação: seguradora atual, classe de bônus, vencimento e sinistros na vigência

**Nunca pergunte:** profissão, e-mail, telefone, cidade, UF ou código SUSEP. A profissão vai como `Outros`. Quando uma seguradora exige contato, vão o e-mail e o telefone do corretor. Cidade e UF saem do CEP. O corretor diz a seguradora pelo nome, e você acha o SUSEP em `cotacao_auto_list_auto_previous_insurers(search: "<nome>")`.

Se faltar algo na resposta, peça só o que faltou, junto do espelho. O que não for pedido segue o padrão da tela, e o espelho mostra esse padrão. Só pergunte mais quando aplica: condutor que não é o segurado, residente de 18 a 25 que dirige, kit gás, blindagem.

Em renovação, número da apólice é opcional. Peça se tiver à mão e nunca trave por ele: ignore `policyNumberRequired`. Sem o número, a seguradora da apólice pode cotar como seguro novo.

## 3 · Veículo: `cotacao_auto_find_vehicle` uma vez

```
cotacao_auto_find_vehicle(plate: "<placa>")   ou   (chassis: "<17 caracteres>")
```

Cada consulta passa por serviço pago e pelos portais. Guarde o resultado e não repita para a mesma placa. Depois:

- **Várias versões:** com mais de um `fipeCode` em `fipeMatches`, ou `chassisAmbiguous: true`, o topo é palpite e `model`, `fipeCode` e `fipeValue` podem vir nulos. Mostre as opções, o corretor escolhe, e você usa o `model`, o `fipeCode` e o `value` da opção.
- **Combustível:** `fuel` vem do Detran e não entra cru. `ÁLCOOL/GASOLINA` é `Flex`. A regra está em `references/parametros.md`.
- **Restrição no registro:** `statusCode` diferente de `'0'` é veículo irregular. Mostre `status` e `restrictions` antes de seguir, para o corretor não descobrir na recusa.
- **`null` não é "não".** Em `hasLien`, `remarkedChassis` e `isZeroKm`, `null` é não informado.
- **Falhou:** peça marca, modelo com versão, anos e combustível. Zero km sem placa nem chassi: `cotacao_auto_get_fipe_catalog`, que só tem carro.

## 4 · Valide antes de confirmar

A tela faz estas checagens. Por aqui, quem faz é você. Dado que passar errado gasta um disparo.

| Campo | Regra | Diga ao corretor |
|---|---|---|
| CPF do segurado e do condutor | Dígitos verificadores certos, nem todos iguais (conta em `references/parametros.md`) | `CPF inválido.` |
| CPF do condutor | Diferente do CPF do segurado | `Este é o CPF do próprio segurado. Se ele é quem dirige, escolha "Mesmo que o segurado".` |
| Nascimento | Não está no futuro, idade de 18 a 100 anos | `O segurado precisa ter pelo menos 18 anos.` |
| Vigência | Não começa antes de hoje | `A vigência não pode começar em uma data passada.` |
| Anos do veículo | De 1980 ao ano que vem; modelo igual ao de fabricação ou um ano depois | `O ano do modelo é, no máximo, um ano após o de fabricação.` |

**Renovação:** envie `vigenciaInicio` igual ao `vencimento` da apólice e deixe `vigenciaFim` ausente, que vira um ano depois. O padrão é hoje, e vigência curta pode ser recusada. Apólice já vencida: a vigência não pode começar no passado, então confirme com o corretor e use hoje. Não calcule classe nova de bônus, e não prometa bônus aplicado em cada seguradora.

## 5 · Confirme o espelho

`cotacao_auto_create_auto_quote` não é idempotente: duas chamadas viram duas cotações. Mostre tudo de uma vez, como no exemplo do fim, e só dispare com um sim claro: segurado (CPF só com o final), condutor, veículo, CEP, modalidade, vigência, coberturas, padrões usados, seguradoras que entram e que ficam de fora, e lead vinculado.

Para o nome do modelo, leia `cotacao_auto_list_auto_coverage_templates` uma vez e use o que tem `isDefault: true`. Sem modelo padrão, avise que vai só FIPE 100%.

## 6 · Dispare uma vez só

Monte o pedido com `references/parametros.md`. Dois cuidados:

- **`insuranceCompanyIds`:** omita, e o Koter usa o padrão da tela e devolve as cortadas em `skipped`. Só envie se o corretor escolheu seguradoras, e tire antes as `MISSING` e `SUSPENDED`: lista explícita passa por cima desse filtro e gasta linha com falha certa.
- **`coberturas`:** omita se não há pedido. `coberturas: {}` apaga o modelo padrão.

| Resposta | O que significa | Conduta |
|---|---|---|
| `dispatched: true` | Disparou | Vá para o passo 7. Isso não prova que cada seguradora foi acionada |
| `dispatched: false` com `dispatchError` | **A cotação existe** | Nunca recrie. Resolva o que a mensagem pede e chame `cotacao_auto_dispatch_auto_quote(quoteId)`. Campo errado: `cotacao_auto_create_auto_quote_version` com `origin: "FORM"` |
| Erro com `fieldErrors` ou mensagem | Nada foi criado | Corrija e chame de novo |
| Sem resposta, conexão caiu | Não se sabe | `cotacao_auto_list_auto_quotes(search: "<nome>")` antes de qualquer nova escrita |

Guarde `quoteId`, `url`, `targets` e `skipped`. Diga ao corretor quantas seguradoras saíram e quais ficaram de fora.

## 7 · Acompanhe por seguradora

```
cotacao_auto_list_auto_quotes(ids: ["<quoteId>"])
```

Consulte de novo em 30 a 60 segundos enquanto `results.anyPending` for `true`. Não consulte mais rápido: a resposta é pesada.

- **Onde a IA sabe esperar** (Claude Code, por exemplo): siga até terminar.
- **Em chat comum**, esperar de verdade não está comprovado. Faça 2 ou 3 consultas, mostre o que tem, diga quantas seguem pendentes e peça ao corretor para dizer "ver" depois.
- **Terminou** quando `anyPending` é `false` e `results.insurers` não está vazio. Lista vazia é cotação nunca disparada.
- **`PENDING` com `updatedAt` parado há mais de 90 segundos:** diga "sem resposta até agora" e encerre a rodada. Sem loop. Redisparo fica recusado enquanto houver `PENDING`.

Leia linha a linha:

| O que veio | O que é | Conduta |
|---|---|---|
| `SUCCESS` com `offers` | Respondeu | Entra na comparação |
| `SUCCESS` sem `offers` | `A consulta funcionou, mas a seguradora não apresentou preço para este perfil.` | Não é falha. Não recote |
| `PENDING` com `offers` | Parcial | Mostre, e avise que pode chegar mais |
| `needsUser.reason: "captcha"` | Só a tela resolve | Peça ao corretor para abrir o Koter Cowork e concluir a verificação na aba do navegador aberta para a cotação. Siga com as demais |
| `FAILURE` com `CREDENCIAL_AUSENTE` ou `CREDENCIAL_INVALIDA` | Credencial | Recotar não resolve. Tela de credenciais do Koter |
| `FAILURE` com `RECUSADO_POLITICA` | Restrição Técnica | Sem mudar o risco, recotar não muda nada |
| Outro `FAILURE`, `UNAVAILABLE` | Depende do código | `references/erros.md` |

Você nunca recebe senha nem resolve captcha. Leia `offers` de toda linha: `FAILURE` também pode trazer oferta.

## 8 · Compare além do preço

Releia o detalhe antes de apresentar, porque oferta pode ser revisada depois de terminar. Mostre uma tabela:

| Coluna | Campo | Cuidado |
|---|---|---|
| Preço | `totalPremium`, `installments`, `paymentOptions` | Com `billingRegime: "subscription"`, o preço é `monthlyPremium`. O `totalPremium` é anualizado e só serve para ordenar. Não compare assinatura com anual pelo mesmo número |
| Franquia | `deductible`, `deductibleDescription`, `deductibleValue` | Oferta mais barata com franquia maior não é a mesma oferta |
| Cobertura | `coverageType`, `coverages` | Compare assistência, vidros, carro reserva e limites de terceiros |
| O que não honrou | `fidelityNotes`, `notes` | Mostre junto do preço, nunca em rodapé |

Não use `bestPremium` da listagem como resposta: ele mistura regimes.

## 9 · Entregue o texto e registre a escolha

Entregue um texto pronto para o corretor mandar, como no exemplo do fim: uma linha por oferta, com preço, franquia e o que inclui. Sem CPF, sem `url`, sem "a melhor", e com o aviso de que os valores são desta cotação e dependem da aceitação da seguradora.

- **PDF da seguradora:** só para quem aparece em `insurerPdfs`, com `cotacao_auto_get_auto_quote_insurer_pdf`. Vem em base64 e o tamanho não foi medido. Se a IA engasgar, mande o corretor abrir pelo `url`. O comparativo com a marca da corretora só existe na tela.
- **Escolha:** só com a decisão real do cliente. Releia o detalhe e chame `cotacao_auto_set_auto_quote_chosen_offer(quoteId, insuranceCompanyId, offerCode)`. Isso não fecha venda nem emite apólice. Marcar a venda é outro passo, em `crm_save_lead` com `outcome` (veja `koter-crm-lead`).

## 10 · Depois do resultado

| O corretor quer | Tool | Observação |
|---|---|---|
| Recotar quem falhou, mesmo pedido | `cotacao_auto_dispatch_auto_quote(quoteId, insuranceCompanyIds)` | Recusado enquanto houver `PENDING` |
| Mudar dado do pedido ou seguradoras | `cotacao_auto_create_auto_quote_version`, `origin: "FORM"` | Redispara todas. Confirme antes |
| Mudar só a franquia | Idem, `origin: "DEDUCTIBLE"` | Só as que deram `SUCCESS` |
| Mudar coberturas de uma seguradora | Idem, `origin: "PRODUCT"` | Só ela. Para tirar adicional, use `FORM` |

Recotar dias depois: use `FORM` com vigência nova, porque `cotacao_auto_dispatch_auto_quote` reusa a gravada. Os casos de versão estão em `references/armadilhas.md`.

## Exemplo: o corretor apressado

Dados, seguradoras e nomes fictícios. Preço aparece como `R$ X.XXX,XX`, e o CPF foi omitido de propósito.

```
Corretor: cota o gol do joão

  cotacao_auto_get_auto_insurer_availability(vehicleType: "CAR")
    → A, B, C e E READY. D MISSING
  crm_list_leads(search: "joão")                     → 1 lead: João Pereira
  cotacao_auto_list_auto_quotes(search: "joão")       → total 0

Agente: Achei o lead João Pereira e vou vincular a cotação a ele.
A, B, C e E estão prontas. A D fica de fora: sem credencial cadastrada.
Me manda de uma vez:
- CPF, nome completo, nascimento, sexo e estado civil
- CEP onde o carro dorme
- placa
- novo ou renovação. Se renovação: seguradora atual, classe de bônus,
  vencimento e sinistros na vigência

Corretor: joão pereira da silva, <CPF>, 14/03/1985, casado. abc1d23.
41820-000. renova na B, bonus 5, vence dia 20, sem sinistro

  (CPF confere, idade confere. "Dia 20" é 20/11/2026: confirmar no espelho.
   Sexo faltou: não deduzo pelo nome)
  cotacao_auto_find_vehicle(plate: "ABC1D23")
    → VW/VOLKSWAGEN, 2021/2020, fuel "ÁLCOOL/GASOLINA" (vira Flex),
      statusCode "0", hasLien true, dois fipeCode em fipeMatches, model nulo
  cotacao_auto_list_auto_previous_insurers(search: "B")  → SUSEP da B
  cotacao_auto_list_auto_coverage_templates()            → padrão: "Essencial"

Agente: Falta pouco. Duas respostas e eu disparo:
1. Sexo do segurado?
2. Qual versão? (a) Gol 1.0 Flex, FIPE R$ XX.XXX,XX
                 (b) Gol 1.6 Flex, FIPE R$ XX.XXX,XX

Confere o resto:
Segurado: João Pereira da Silva, CPF final 00, 14/03/1985, casado
Condutor: o próprio segurado
Veículo: VW Gol, 2021/2020, Flex, placa ABC1D23, alienado
Pernoite: CEP 41820-000
Modalidade: renovação da B, classe 5, vence 20/11/2026, sem sinistro
Vigência: 20/11/2026 a 20/11/2027
Coberturas: modelo Essencial
Padrões: portão manual, uso particular, até 500 km por mês, casa,
sem residente de 18 a 25 dirigindo
Seguradoras: A, B, C e E. De fora: D (sem credencial)
Posso disparar?

Corretor: masculino, a. manda

  cotacao_auto_create_auto_quote(cepPernoite, segurado, veiculo,
    modalidade: "renovacao", vigenciaInicio: "2026-11-20",
    apoliceAnterior: { seguradoraSusep, classeBonus: 5, vencimento: "2026-11-20",
    sinistros: 0 }, leadId)
    → quoteId, url, dispatched: true, skipped: [D]

Agente: Disparei em 4 seguradoras. A D ficou de fora. Vou acompanhar.

  (30 a 60 segundos)
  cotacao_auto_list_auto_quotes(ids: [quoteId])
    → A SUCCESS, B PENDING com ofertas, C PENDING com needsUser captcha,
      E FAILURE CREDENCIAL_INVALIDA

Agente: Até aqui: A respondeu e B já mostra ofertas.
A C pediu captcha: abre o Koter Cowork e conclui a verificação na aba
do navegador que foi aberta. Depois me diz "ver".
A E recusou o login. Atualiza a senha na tela de credenciais do Koter.
Isso não se resolve recotando.

Corretor: ver

  cotacao_auto_list_auto_quotes(ids: [quoteId])
    → A SUCCESS, B SUCCESS, C SUCCESS, E FAILURE. anyPending false

Agente:
A: R$ X.XXX,XX, franquia R$ X.XXX,XX, carro reserva de 7 dias.
B: R$ X.XXX,XX, franquia R$ X.XXX,XX. Atenção: não honrou a assistência pedida.
C: R$ XXX,XX por mês, franquia R$ X.XXX,XX. É assinatura: não compare com o
anual pelo mesmo número.
A escolha é sua. Texto para mandar ao João, sem link:

João, cotei o seguro do seu Gol em 3 seguradoras:
• A: R$ X.XXX,XX à vista ou 10x de R$ XXX,XX. Franquia de R$ X.XXX,XX.
  Inclui carro reserva de 7 dias.
• B: R$ X.XXX,XX à vista ou 10x de R$ XXX,XX. Franquia de R$ X.XXX,XX.
• C: R$ XXX,XX por mês (assinatura). Franquia de R$ X.XXX,XX.
Valores desta cotação, sujeitos à aceitação da seguradora. Me diz qual
faz mais sentido para você que eu explico as diferenças.

Corretor: ele fechou na A

  cotacao_auto_list_auto_quotes(ids: [quoteId])      → oferta da A segue igual
  cotacao_auto_set_auto_quote_chosen_offer(quoteId, insuranceCompanyId, offerCode)

Agente: Marquei a oferta da A na cotação. Isso não fecha a venda nem emite
a apólice: emissão é no portal da seguradora. Quer que eu marque a venda no
lead do João?
```

## Conferência

Parâmetros, enums, mensagens e fluxo lidos no código da API e das telas de auto em 03/11/2026, não executados. Nenhuma cotação real foi rodada para escrever esta skill.

Sem prova: espera em chat comum, tamanho da resposta de `cotacao_auto_list_auto_quotes` e do PDF, lista completa de `errorCode`, comportamento de cada portal e quais seguradoras aplicam o bônus.
