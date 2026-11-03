# Parâmetros do multicálculo auto

Lido no código em 03/11/2026, não executado. Parâmetro desconhecido é erro de validação, inclusive dentro de objeto. Os enums são literais: não traduza nem troque acento.

## Tools

| Tool | Escreve | Limite por usuário | Para quê |
|---|---|---|---|
| `cotacao_auto_get_auto_insurer_availability` | não | | Quem cota o veículo e como está a credencial |
| `cotacao_auto_find_vehicle` | não | 30 por minuto | Veículo por placa ou chassi |
| `cotacao_auto_get_fipe_catalog` | não | | Navega a FIPE de carros |
| `cotacao_auto_list_auto_coverage_templates` | não | | Modelos de cobertura da corretora |
| `cotacao_auto_list_auto_previous_insurers` | não | | SUSEP da seguradora anterior |
| `cotacao_auto_create_auto_quote` | sim | 10 disparos por minuto, só com `dispatch: true` | Cria e dispara |
| `cotacao_auto_list_auto_quotes` | não | | Lista e detalhe |
| `cotacao_auto_dispatch_auto_quote` | sim | 10 disparos por minuto | Redispara com o mesmo pedido |
| `cotacao_auto_create_auto_quote_version` | sim | 10 disparos por minuto | Recota com pedido alterado |
| `cotacao_auto_set_auto_quote_chosen_offer` | sim | | Marca ou limpa a oferta escolhida |
| `cotacao_auto_get_auto_quote_insurer_pdf` | não | | PDF gerado pela seguradora |

## Disponibilidade

`vehicleType`: `CAR` (padrão), `MOTORCYCLE` ou `TRUCK`.

Devolve `summary` (`total`, `ready`, `missing`, `suspended`, `notLinked`, e `summary.logins` com os mesmos totais por login) e `insuranceCompanies[]`: `id`, `name`, `automationCode`, `brand`, `credentialStatus`, `credentialSource`, `credentialCount`, `suspendedCount`, `loginRefusedCount`, `reason`, `ownRenewal`.

`ownRenewal` traz `policyNumberHint` (ajuda sobre o número da apólice), `asksPolicyItem` e `policyNumberRequired`. Ignore `policyNumberRequired`: número da apólice nunca é obrigatório. Linha de marca, cotada pelo login de outra seguradora, vem com `ownRenewal: null` e repete o status da principal.

## Do `cotacao_auto_find_vehicle` para `veiculo`

Passe `plate` (7 a 8 caracteres) ou `chassis` (17), nunca os dois. O resultado vem dentro de `vehicle`.

| Resultado | Vai para | Regra |
|---|---|---|
| `brand` | `marca` | Direto |
| `model` | `modelo` | Com mais de um `fipeCode` em `fipeMatches`, use o da opção escolhida |
| `modelYear`, `manufactureYear` | `anoModelo`, `anoFabricacao` | Direto |
| `fuel` | `combustivel` | Normalize (abaixo) |
| `fipeCode`, `fipeValue` | `codigoFipe`, `valorFipe` | Só com versão decidida. O código precisa ser `000000-0`. O valor da opção está em `value` |
| `brandLogo` | `marcaLogo` | Direto, só `https` |
| `chassis` | `chassi` | Só com 17 caracteres, sem I, O e Q |
| `plate`, numa busca por chassi | `placa` | Use a devolvida |
| `hasLien` | `alienado` | `null` é não informado |
| `remarkedChassis` | `chassiRemarcado` | `null` é não informado |
| `isZeroKm` | `zeroKm` | `null` é não informado |

Outros campos úteis: `status`, `statusCode`, `restrictions`, `chassisVersions`, `chassisAmbiguous`, `versionConfidence`, `registrationCity`, `registrationUf`.

### Combustível

Tire acento e caixa do `fuel` e aplique na ordem:

1. contém `flex`: `Flex`
2. tem gasolina e também álcool ou etanol: `Flex`
3. contém `hibrido`: `Híbrido`
4. contém `eletrico`: `Elétrico`
5. contém `diesel`: `Diesel`
6. tem álcool ou etanol: `Álcool`
7. tem gasolina: `Gasolina`
8. senão, pergunte

## `cotacao_auto_get_fipe_catalog`

Só carro. `brandCode`, depois `modelCode`, depois `yearCode`, nessa ordem. `search` filtra marcas ou modelos.

Sem códigos devolve `brands[]`. Com marca, `models[]`. Com marca e modelo, `years[]` (`code`, `label`, `year`, `fuel`). Com os três, `price` (`fipeCode`, `value`, `referenceMonth`).

## `cotacao_auto_create_auto_quote`

| Parâmetro | Obrigatório | Padrão | Observação |
|---|---|---|---|
| `cepPernoite` | sim | | `00000-000`. Também é o endereço. Cidade e UF saem dele |
| `segurado` | sim | | Objeto abaixo |
| `veiculo` | sim | | Objeto abaixo |
| `vehicleType` | não | `CAR` | |
| `insuranceCompanyIds` | não | padrão da tela | Ids da disponibilidade |
| `modalidade` | não | `novo` | `novo` ou `renovacao` |
| `vigenciaInicio` | não | hoje | `AAAA-MM-DD` |
| `vigenciaFim` | não | início + 1 ano | `AAAA-MM-DD` |
| `condutor` | não | o segurado | Objeto abaixo |
| `questionario` | não | padrões da tela | Objeto abaixo |
| `coverageTemplateId` | não | modelo padrão | Id de `cotacao_auto_list_auto_coverage_templates` |
| `coberturas` | não | modelo padrão | Ver "Coberturas" |
| `apoliceAnterior` | só em `renovacao` | | Objeto abaixo |
| `leadId`, `contactId` | não | | Só na criação |
| `hideContact` | não | preferência da tela | Esconde o contato do corretor na página pública. Só com pedido dele |
| `dispatch` | não | `true` | `false` só cria |

**`segurado`:** `cpf`, `nome`, `dataNascimento`, `sexo`, `estadoCivil` obrigatórios. `nomeSocial` opcional.

**`condutor`:** `relacaoComSegurado` obrigatório no objeto. Com relação diferente de `Próprio`, exige `cpf`, `nome`, `dataNascimento` e `sexo`. `estadoCivil` ausente usa o do segurado.

**`veiculo`:** `marca`, `modelo` (com a versão), `anoModelo`, `anoFabricacao`, `combustivel` obrigatórios. `placa` ou `chassi` obrigatório, salvo `zeroKm: true`. Opcionais: `codigoFipe`, `valorFipe`, `marcaLogo`, `alienado`, `antifurto`, `chassiRemarcado`, `kitGas`, `kitGasValor`, `blindado`, `blindagemValor`, `tipoUso` (padrão `Particular`).

**`questionario`** (tudo opcional): `garagemResidencia` (`Sim, sem portão eletrônico`), `garagemTrabalho` (`Não utiliza para trabalhar`), `garagemEstudo` (`Não utiliza para estudar`), `tipoResidencia` (`Casa`), `kmMensal` (500), `menores26` (`Não residem`), `idadeCondutorSecundario` (sem padrão), `isencaoFiscal` (`Sem isenção`). A tela oferece km de 500, 800, 1500 e 2000.

**`apoliceAnterior`:** `seguradoraSusep` obrigatório. `classeBonus` (0 a 10) e `vencimento` são exigidos quando outra seguradora cota como congênere: peça os dois sempre. `sinistros` (0 a 20, padrão 0). `numero` e `item` (a partir de 1) são opcionais e só viajam quando a seguradora da apólice está entre os alvos. `item` só se `asksPolicyItem`.

Em renovação, o pedido vai para todos os alvos: a seguradora da apólice renova a própria, e as demais cotam como congênere.

**Resposta:** `quoteId`, `url`, `skipped[]` (`insuranceCompanyId`, `reason`), `targets[]`, `dispatched`, `dispatchedInsuranceCompanyIds`, `message`. Com disparo que falhou: `dispatched: false`, `dispatchError`, `fieldErrors`.

### Coberturas

| Você manda | Resultado |
|---|---|
| Nada | Modelo padrão da corretora. Sem modelo padrão, só FIPE 100% |
| `coverageTemplateId` | Esse modelo |
| `coverageTemplateId` e `coberturas` | `coberturas` por cima do modelo |
| `coberturas` sem modelo | Nenhum modelo aplicado |

Chaves de `coberturas`, todas opcionais: `tipo`, `franquia`, `franquiaModo`, `fipePercent` (50 a 120; a tela oferece 90, 100 e 110), `assistencia24h`, `vidros`, `carroReservaDias`, `carroReservaPerfil`, `reposicaoZeroKm`, `custosDefesa`, `rcfvDanosMateriais`, `rcfvDanosCorporais`, `rcfvDanosMorais`, `appMorteInvalidez`, `despesasExtraordinarias`, `despesasMedicas`, `maxLatariaPintura`, `maxRodaPneuSuspensao`, `reparosRapidos`, `martelinhoOuro`, `isencaoFranquiaPrimeiroSinistro`.

- Valor em reais vai como número (`100000`).
- Chave ausente fica com o padrão da automação. Mandar `Sem assistência` pede a cobertura desligada.
- `false` em flag desliga o que o modelo ligou.
- `franquiaModo: "ambas"` cota normal e reduzida. Cada franquia chega como oferta própria.
- Não mande limite zero sem o corretor pedir.

## Enums

| Campo | Valores |
|---|---|
| `sexo` | `Masculino`, `Feminino` |
| `estadoCivil` | `Solteiro(a)`, `Casado(a) ou união estável`, `Divorciado(a)`, `Viúvo(a)` |
| `relacaoComSegurado` | `Próprio`, `Filho(a)`, `Pai/Mãe`, `Cônjuge`, `Outros` |
| `combustivel` | `Álcool`, `Diesel`, `Elétrico`, `Flex`, `Híbrido`, `Gasolina` |
| `tipoUso` | `Particular`, `Profissional`, `Motorista de App`, `Táxi` |
| `garagemResidencia` | `Sim, com portão eletrônico`, `Sim, sem portão eletrônico`, `Não possui`, `Não deixa em garagem` |
| `garagemTrabalho` | `Sim, possui`, `Não possui`, `Não trabalha`, `Não deixa em garagem`, `Não utiliza para trabalhar` |
| `garagemEstudo` | `Sim, possui`, `Não possui`, `Não estuda`, `Não deixa em garagem`, `Não utiliza para estudar` |
| `tipoResidencia` | `Casa`, `Apartamento`, `Casa em Condomínio`, `Chácara`, `Outros` |
| `menores26` | `Não residem`, `Sim, do sexo feminino`, `Sim, do sexo masculino`, `Sim, de ambos os sexos`, `Sim, mas não utilizam o veículo` |
| `idadeCondutorSecundario` | `De 18 a 24 anos`, `25 anos` |
| `isencaoFiscal` | `Sem isenção`, `PCD com isenção`, `PCD sem isenção` |
| `tipo` | `Compreensiva (Completa)`, `Exclusiva (Incêndio e Roubo)`, `RCF (Somente Terceiros)` |
| `franquia` | `Reduzida (25%)`, `Reduzida (50%)`, `Reduzida (75%)`, `Normal`, `Facultativa (50%)`, `Facultativa (100%)` |
| `franquiaModo` | `normal`, `reduzida`, `ambas` |
| `assistencia24h` | `Sem assistência`, `Oficina Referenciada - Até 200km`, `Oficina Referenciada - Até 500km`, `Oficina Referenciada - Até 1000km` |
| `vidros` | `Sem assistência`, `Oficina Referenciada - Básico`, `Oficina Referenciada - Completo` |
| `carroReservaDias` | `Sem carro reserva`, `Oficina Referenciada - 07 Dias`, `Oficina Referenciada - 15 Dias`, `Oficina Referenciada - 30 Dias` |
| `carroReservaPerfil` | `Popular manual (com AR)`, `Popular manual (sem AR)` |
| `reposicaoZeroKm` | `Sem cobertura`, `06 meses`, `12 meses` |
| `custosDefesa` | `Sem cobertura`, `R$ 5.000,00`, `R$ 10.000,00`, `R$ 15.000,00`, `R$ 20.000,00` |

`Separado(a)` não existe no enum: mande `Divorciado(a)`.

Como o corretor fala: `Sim, sem portão eletrônico` é "portão manual". `Não utiliza para trabalhar` é "não usa para esse fim". Assistência de 200, 500 e 1000 km é "básica", "intermediária" e "completa". `Exclusiva (Incêndio e Roubo)` é "roubo e furto".

## Checagens locais

**CPF.** Tire a pontuação. Precisa ter 11 dígitos, nem todos iguais. Para o 10º dígito: multiplique os 9 primeiros por 10, 9, 8 e assim até 2, some, multiplique por 10 e pegue o resto da divisão por 11 (resto 10 vale 0). Para o 11º: faça o mesmo com os 10 primeiros, de 11 até 2.

**Idade.** Mínimo 18, máximo 100, para segurado e condutor.

**Ano.** De 1980 até o ano atual + 1. `anoModelo` igual a `anoFabricacao` ou um ano depois.

**Formato.** Data `AAAA-MM-DD`. Placa `ABC1D23` ou `ABC1234`. CEP com 8 dígitos. Código FIPE `000000-0`.

## `cotacao_auto_list_auto_quotes`

| Parâmetro | Regra |
|---|---|
| `ids` | De 1 a 5. Devolve o detalhe. Não combina com `search`, `leadId` nem `contactId` |
| `version` | Só com um id. Lê os resultados congelados daquela versão |
| `search` | Nome do cliente. Só letras, números e espaços |
| `leadId`, `contactId` | Filtro |
| `page`, `pageSize` | Padrão 1 e 20. Máximo 50 por página |

**Linha da lista:** `id`, `slug`, `client`, `url`, `createdAt`, `vehicleType`, `insurerCount`, `offerCount`, `vehicleLabel`, `bestPremium`, `pendingCount`, `chosenOffer`.

**Detalhe:** o que vem na linha, mais `leadId`, `contactId`, `fields`, `targets[]`, `results`, `versions[]`, `insurerPdfs[]`. No topo, `notFoundIds`.

- `results`: `anyPending`, `byStatus`, `insurers[]`.
- `insurers[]`: `insuranceCompanyId`, `insuranceCompanyName`, `status`, `currentStep`, `needsUser`, `errorCode`, `message`, `quoteNumber`, `updatedAt`, `offers[]`.
- `offers[]`: `code`, `name`, `brand`, `billingRegime`, `totalPremium`, `monthlyPremium`, `netPremium`, `iof`, `installments`, `paymentOptions[]`, `deductible`, `deductibleDescription`, `deductibleValue`, `coverageType`, `coverages[]` (`name`, `value`, `limit`, `deductible`), `notes`, `fidelityNotes[]`.
- `versions[]`: `id`, `number`, `origin`, `summary`, `basedOnNumber`, `dispatchedInsuranceCompanyIds`, `createdBy`, `createdAt`, `isCurrent`.
- `insurerPdfs[]`: `insuranceCompanyId`, `offerCodes` (`null` é PDF único).

## `cotacao_auto_dispatch_auto_quote`

`quoteId` obrigatório. `insuranceCompanyIds` opcional: só seguradoras que já estão na cotação. Ausente, redispara todas.

## `cotacao_auto_create_auto_quote_version`

| `origin` | Parâmetros | Dispara | Observação |
|---|---|---|---|
| `FORM` | `fieldChanges` e/ou `insuranceCompanyIds` | Todas | Descarta os ajustes por seguradora |
| `DEDUCTIBLE` | `franquiaModo` e/ou `franquia` | Só as `SUCCESS` | |
| `PRODUCT` | `insuranceCompanyId` e `coberturas` | Só ela | Só acrescenta. Ajustes se acumulam |

`fieldChanges` usa as chaves de `fields` do detalhe. Valor `null` remove a chave. As mais usadas:

- Veículo: `veiculo_placa`, `veiculo_chassi`, `veiculo_marca`, `veiculo_modelo`, `veiculo_codigo_fipe`, `veiculo_valor_fipe`, `veiculo_ano_modelo`, `veiculo_ano_fabricacao`, `veiculo_combustivel`.
- Pessoas: `segurado_estado_civil`, `condutor_estado_civil`, `condutor_relacao_com_segurado`, `condutor_cpf`, `condutor_nome`, `condutor_data_nascimento`, `condutor_sexo`.
- Risco: `questionario_cep_pernoite`, `questionario_garagem_residencia`, `questionario_km_mensal`, `questionario_menores_26`.
- Vigência: `vigencia_inicio`, `vigencia_fim`.

Tipo de uso muda em duas chaves:

| Uso | `veiculo_categoria_uso` | `questionario_uso` |
|---|---|---|
| Particular | `Particular` | `Locomoção diária` |
| Profissional | `Particular` | `Locomoção diária e uso comercial` |
| Motorista de App | `Transporte por APP` | `Uso comercial` |
| Táxi | `Taxi` | `Uso comercial` |

Não se alteram por aqui: `segurado_profissao`, `condutor_profissao`, `segurado_email`, `segurado_telefone`.

## `cotacao_auto_set_auto_quote_chosen_offer`

`quoteId` obrigatório. `insuranceCompanyId` e `offerCode` juntos marcam. Os dois ausentes limpam.

## `cotacao_auto_get_auto_quote_insurer_pdf`

`quoteId` e `insuranceCompanyId` obrigatórios. `offerCode` e `version` opcionais. Com `offerCodes: null` no detalhe, o PDF é único. Com lista, há um PDF por oferta, e você passa `offerCode`. O PDF de uma versão não aparece em outra.
