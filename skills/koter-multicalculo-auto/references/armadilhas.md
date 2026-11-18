# Armadilhas do multicálculo auto

O corpo da skill já cobre as que causam dano direto: recriar depois de falha no disparo, lista explícita de seguradoras, checagens de dado, vigência de renovação, combustível cru, versão no chute, assinatura contra anual e fidelidade. Aqui ficam as demais, por etapa.

## Antes do disparo

| Armadilha | Contorno |
|---|---|
| Lead esquecido | `leadId` e `contactId` só entram em `cotacao_auto_create_auto_quote`. Não há como vincular depois. Procure o lead antes |
| Cotação do mesmo cliente repetida | Busque por nome antes de criar. Cada criação nova é uma cotação a mais na lista do corretor |
| Limite gasto com dado ruim | O limite de 10 disparos por minuto conta depois das checagens de CPF, nascimento, vigência e anos, e antes de validar o CEP e as seguradoras. Na recotação, conta antes de todas as checagens. Na dúvida sobre um dado, crie com `dispatch: false`, que não gasta esse limite nem a cota do mês, e dispare depois com `cotacao_auto_dispatch_auto_quote` |
| Cota do mês gasta em recotação | Cada redisparo e cada versão gasta um dos 30 disparos do mês. Junte as mudanças do corretor numa versão só, e não recote quem deu `SUCCESS` sem preço ou `RECUSADO_POLITICA` sem mudar o risco |
| `coberturas: {}` | Objeto vazio já tira o modelo padrão. Sem pedido de cobertura, omita o campo |
| Pedido de `Sem assistência` por engano | Chave ausente fica com o padrão da automação. Valor `Sem assistência` pede a cobertura desligada. Só mande se o corretor pediu |
| Limite zero | Não mande zero em cobertura com valor sem o corretor pedir. Se ele pedir, confira na oferta o que cada seguradora devolveu |
| Moto ou caminhão sem placa | `cotacao_auto_get_fipe_catalog` é só carro. Usado sem placa nem chassi é recusado. Zero km: peça marca, modelo, anos e combustível, mande `zeroKm: true` e deixe `codigoFipe` ausente. Confira nas ofertas se cada seguradora cotou o veículo certo |
| Ano 32000 | A FIPE usa 32000 no lugar do ano em zero km. Troque pelo ano atual. Nunca mande 32000 em `anoModelo` |
| Marca de duas fontes | A FIPE e a placa escrevem a marca de jeitos diferentes. Use uma fonte só no pedido. O catálogo FIPE só entra quando a placa não resolveu |
| `Separado(a)` | Não existe no enum. Mande `Divorciado(a)` |
| Seguradora que exige contato | Se o corretor não tem telefone no perfil, ela sai em `skipped` ou dá erro quando vem na lista. Peça para cadastrar o telefone no perfil. Nunca peça o telefone do cliente |
| Número de seguradoras escrito de memória | Quem cota muda por veículo e por corretora. A resposta é sempre a disponibilidade |

## Durante o acompanhamento

| Armadilha | Contorno |
|---|---|
| `dispatched: true` tomado como prova | Seguradora sem credencial pode seguir em `dispatchedInsuranceCompanyIds` e virar `FAILURE` logo depois. Leia o resultado por seguradora |
| `anyPending: false` em cotação nunca disparada | Sem linhas, `anyPending` é `false`. Confira se `results.insurers` tem itens. Vazio: chame `cotacao_auto_dispatch_auto_quote` |
| Polling sem fim | `PENDING` parado há mais de 90 segundos vira "sem resposta até agora". Encerre a rodada. Com cerca de 15 minutos, o Koter fecha a linha como `FAILURE`, e a mensagem termina em `Cote de novo.`: redispare só ela. Se seguir presa, chame o suporte do Koter |
| Tentar redisparar para destravar | Com qualquer `PENDING`, `cotacao_auto_dispatch_auto_quote` e `cotacao_auto_create_auto_quote_version` são recusados. Isso inclui o captcha: resolva na tela primeiro |
| Ignorar oferta por causa do status | `PENDING` pode trazer ofertas parciais, e `FAILURE` pode conservar ofertas. Leia `offers` de toda linha e diga que ainda pode chegar mais |
| Marca sem oferta | Linha de marca cotada pelo login de outra seguradora pode voltar `UNAVAILABLE` com `não retornou oferta para este perfil` enquanto a principal trouxe ofertas. Não é erro de credencial |

## Na comparação e na escolha

| Armadilha | Contorno |
|---|---|
| Oferta muda depois de terminar | Uma seguradora pode revisar o resultado depois do `SUCCESS`, e não conte com o mesmo `code`. Releia o detalhe antes da recomendação do corretor e antes de marcar a escolha |
| Escolha aponta para oferta antiga | Oferta de versão anterior dá `Oferta não encontrada nesta cotação.`. Redisparar não limpa a escolha: confira `chosenOffer` depois de recotar |
| Seguro novo disfarçado de renovação | Sem o número da apólice, a seguradora da apólice pode cotar como seguro novo, com aviso na oferta. Leia `notes` e `fidelityNotes` |
| Bônus prometido | Não prometa que cada seguradora aplica classe, sinistros e congênere. Informe a classe atual e os sinistros, sem calcular classe nova |
| Lead com valor trocado | Toda escrita em cotação com `leadId` pode atualizar o negócio do lead, conforme o modo do negócio. Avise o corretor se ele cuida desse valor à mão |
| Prêmio de assinatura no CRM | O negócio do lead usa `totalPremium`, que em assinatura é o valor anualizado |
| PDF que não chega | Qualquer falha vira `PDF dessa seguradora ainda não está disponível.`, até `offerCode` ou `version` errados. Confira `insurerPdfs` antes. Se persistir, abra pelo `url` |

## Na recotação

| Armadilha | Contorno |
|---|---|
| Trocar placa só pela chave da placa | Ao trocar de carro, envie a identidade inteira: marca, modelo, anos, combustível, código e valor FIPE, chassi |
| Vigência velha | `cotacao_auto_dispatch_auto_quote`, `DEDUCTIBLE` e `PRODUCT` reusam a vigência gravada, mesmo vencida. `FORM` leva um início já vencido para hoje e o fim para um ano depois. Renovação: mande `vigencia_inicio` em `fieldChanges` |
| Estado civil pela metade | `segurado_estado_civil` e `condutor_estado_civil` são chaves separadas. Troque as duas |
| Tipo de uso | Não existe `veiculo_tipo_uso`. Troque `veiculo_categoria_uso` e `questionario_uso` juntas (tabela em `parametros.md`) |
| CEP que muda de UF | `FORM` com `questionario_cep_pernoite` novo: cidade e UF seguem o CEP, inclusive de outra UF. Não mande `endereco_cep`, `endereco_cidade` nem `endereco_uf`: dá `Cidade e UF saem do CEP: troque questionario_cep_pernoite.` |
| Incluir por versão seguradora que exige contato | Antes, confira se o corretor tem telefone no perfil. A descrição de `cotacao_auto_create_auto_quote` diz quais seguradoras exigem |
| Tirar um adicional com `PRODUCT` | Em opção, `Sem assistência`, `Sem carro reserva` ou `Sem cobertura` desliga só naquela seguradora. Em flag (`maxLatariaPintura`, `maxRodaPneuSuspensao`, `reparosRapidos`, `martelinhoOuro`, `isencaoFranquiaPrimeiroSinistro`), `PRODUCT` ignora `false`: use `FORM` com `false` ou `null` em `fieldChanges`, e avise que `FORM` redispara todas e descarta ajustes por seguradora |
| Opção fora da tela em `fieldChanges` | O campo é livre. Use só os enums de `parametros.md` |
| Trocar `segurado_nome` | A cotação segue com o nome antigo na listagem |
| Tipo de veículo | Não muda em recotação. Crie outra cotação |
| Resultados misturados | `DEDUCTIBLE` e `PRODUCT` deixam as outras seguradoras com o resultado anterior. Na mesma versão convivem pedidos diferentes: diga isso ao comparar |
| Versão criada e disparo falhou | A versão fica gravada. Não crie outra: use `cotacao_auto_dispatch_auto_quote` |

## Alcance

| Armadilha | Contorno |
|---|---|
| Cotação de outra pessoa | O agente alcança as cotações do próprio usuário. Gestor pedindo a de um vendedor recebe `Cotação de auto não encontrada entre as suas nesta corretora.` |
| Corretor em duas corretoras | A lista pode trazer as duas, e o detalhe só abre as da corretora ativa. Id em `notFoundIds`: troque a corretora ativa no Koter |
| Troca de corretora | A conexão segue a corretora ativa do usuário. Trocar lá muda o alcance aqui |

## O que fica só na tela

- Cadastrar, editar ou atualizar credencial e senha.
- Resolver captcha, pelo Koter Cowork.
- Criar, editar ou apagar modelo de cobertura, e definir o padrão.
- Marcar ou desmarcar seguradoras como preferência. Aqui ela é só lida.
- Preencher nome e nascimento a partir do CPF.
- Gerar o PDF comparativo com a marca da corretora.
- Editar o contato enviado à seguradora.
