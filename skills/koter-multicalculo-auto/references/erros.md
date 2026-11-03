# Erros do multicálculo auto

Mensagens literais lidas no código em 03/11/2026. `<x>` marca trecho variável. Nenhuma foi provocada em execução real.

## A pergunta que vem antes

**A cotação já existe?** Essa resposta decide tudo.

| Sinal | A cotação existe? | Conduta |
|---|---|---|
| `cotacao_auto_create_auto_quote` devolveu erro | Não | Corrija e chame de novo |
| Resposta com `dispatched: false` e `dispatchError` | **Sim** | Nunca recrie. Use o `quoteId` devolvido |
| Sem resposta | Não se sabe | `cotacao_auto_list_auto_quotes(search: "<nome>")` antes de qualquer escrita |
| `cotacao_auto_create_auto_quote_version` falhou no disparo | A versão ficou gravada | `cotacao_auto_dispatch_auto_quote` |

## Formato

- Um campo errado volta com a própria frase. Vários, na criação: `Revise os campos do formulário: <rótulos>.`. No disparo: `Faltam dados obrigatórios para cotar: <rótulos>.`
- Na criação, o erro é JSON com `message` e `fieldErrors` (`{ chave: frase }`).
- Em `cotacao_auto_dispatch_auto_quote` e `cotacao_auto_create_auto_quote_version`, é o mesmo JSON dentro do texto do erro.

## Status por seguradora

| `status` | Significado | Termina? |
|---|---|---|
| `PENDING` | Sem desfecho. Pode já ter ofertas | Não |
| `SUCCESS` | Respondeu. Pode vir sem ofertas | Sim, mas pode ser revisado |
| `FAILURE` | Recusou ou deu erro. Pode conservar ofertas | Sim |
| `UNAVAILABLE` | Fora do ar, tempo esgotado, ou marca sem oferta | Sim |

## `errorCode`

A lista abaixo é a que as telas conhecem. Pode haver outros. Código novo: repasse `message`, que vem em português, e não invente causa.

| `errorCode` | Como a tela chama | Recotar resolve? | Conduta |
|---|---|---|---|
| `CREDENCIAL_AUSENTE` | Sem credencial cadastrada | Não | Corretor cadastra na tela de credenciais |
| `CREDENCIAL_INVALIDA` | Credencial recusada | Não | Corretor atualiza a senha na tela de credenciais |
| `USUARIO_SEM_PERMISSAO` | Sem permissão para Auto | Não | Quem administra o portal da seguradora libera o produto para esse usuário. Não é recusa do cliente |
| `AUTH_EXPIRADA` | Credencial expirada | Sim | Recote essa seguradora. Voltou igual: tela de credenciais |
| `RECUSADO_POLITICA` | Restrição Técnica | Não, sem mudar o risco | Diga que a seguradora não aceitou o risco |
| `VEICULO_NAO_ENCONTRADO` | Veículo não encontrado | Só corrigindo | Ajuste o veículo com `origin: "FORM"` |
| `ERRO_INTERNO` | Erro na seguradora | Sim | Recote essa seguradora |

`needsUser` com `reason: "captcha"` mantém a linha em `PENDING`. Pare de esperar por ela, peça ao corretor para abrir o Koter Cowork e concluir a verificação na aba do navegador aberta para a cotação, e siga com as demais.

## Credencial

| Mensagem | Conduta |
|---|---|
| `Nenhuma credencial cadastrada para esta seguradora. Cadastre a credencial da corretora no Koter para cotar nela.` | Tela de credenciais |
| `Nenhuma credencial cadastrada para esta seguradora. Cadastre antes de tentar novamente.` | Idem, no resultado da seguradora |
| `A credencial padrão do Koter para esta seguradora está indisponível no momento. Cadastre a credencial da corretora para cotar nela.` | Idem |
| `Todas as credenciais desta seguradora estão suspensas. Atualize a senha no Koter.` | Atualizar senha |
| `O portal da seguradora recusou esta credencial. Atualize a senha.` | Idem |
| `A credencial está suspensa. Atualize os dados de acesso para reativá-la.` | Idem |

## Criação

| Mensagem | Conduta |
|---|---|
| `O condutor não é o segurado: informe <campos> do condutor.` | Peça só os campos citados |
| `Informe a placa ou o chassi do veículo (só o zero km dispensa os dois).` | Peça placa ou chassi, ou confirme zero km |
| `O ano do modelo não pode ser anterior ao de fabricação.` | Confira os anos |
| `Na renovação, informe a apólice atual em apoliceAnterior.` | Peça os dados da apólice |
| `Não encontrei a cidade do CEP <cep> no Koter. Confira o CEP.` | Confirme o CEP |
| `CEP inválido. Informe 8 dígitos.` | Idem |
| `CEP <cep> não encontrado.` | Idem |
| `Não foi possível consultar o CEP no momento. Tente novamente.` | Tente de novo em instantes |
| `Estas seguradoras não cotam este veículo: <ids>. Use os ids de get_auto_insurer_availability.` | Releia a disponibilidade do `vehicleType` certo |
| `<nomes> exige o telefone de contato, e o seu cadastro no Koter não tem telefone. Cadastre o telefone no seu perfil ou tire essas seguradoras.` | Tire essas seguradoras ou peça o cadastro do telefone do corretor. Nunca o do cliente |
| `Nenhuma seguradora pronta para cotar este veículo (<n> sem credencial, <n> com credencial suspensa, <n> fora no total). Cadastre ou atualize as credenciais no Koter.` | Pare. Tela de credenciais |
| `Modelo de coberturas não encontrado. Use um id de list_auto_coverage_templates.` | Releia os modelos |
| `Não foi possível consultar as seguradoras agora. Tente de novo em instantes.` | Tente de novo em instantes |
| `Recurso não encontrado.` | O `leadId` ou o `contactId` não vale para este usuário. A mensagem não diz qual: confira os dois |

Frases de campo que podem vir: `Informe o início da vigência.`, `O fim da vigência não pode ser antes do início.`, `Informe a seguradora anterior.`, `Informe a classe de bônus.`, `Informe o fim da vigência atual.`, `Informe um CPF válido para CPF do segurado.`, `Informe um CEP válido para CEP de pernoite.`, `Informe uma placa válida (ABC1D23 ou ABC-1234).`, `O chassi precisa ter 17 caracteres, sem I, O ou Q.`, `Informe o código FIPE no formato 000000-0.`, `Escolha uma opção válida para <rótulo>.`, `A classe de bônus vai de 0 a 10.`, `Quantidade de sinistros inválida.`, `Item inválido. Use um número a partir de 1.`, `Seguradora anterior inválida.`

## Disparo e redisparo

| Mensagem | Conduta |
|---|---|
| `Aguarde a busca atual terminar para cotar de novo.` | Há linha em `PENDING`. Espere ou resolva o captcha. Não insista |
| `A automação de cotação auto está indisponível no momento. Tente novamente em instantes.` | Espere e use `cotacao_auto_dispatch_auto_quote` com o mesmo `quoteId` |
| `A seguradora "<id>" não é uma seguradora de auto válida e ativa.` | Refaça a seleção pela disponibilidade |
| `A seguradora "<nome>" não cota <veículo>. Refaça a seleção de seguradoras.` | Idem |
| `A seguradora <nome> foi arquivada pelo Koter e não pode ser usada em um cadastro novo.` | Tire essa seguradora |
| `Esta cotação não é de seguro auto, então não pode ser despachada.` | O id é de outra cotação |

Dentro de `results.insurers[].message`, a linha que termina em `a resposta da automação se perdeu no caminho. Cote de novo.` pede redisparo só daquela seguradora. A linha `A <nome> não retornou oferta para este perfil.` é de marca sem oferta. As demais mensagens vêm da seguradora: repasse como estão.

## Cotação existente

| Mensagem | Conduta |
|---|---|
| `Cotação de auto não encontrada entre as suas nesta corretora.` | É de outra pessoa ou de outra corretora. Confira a corretora ativa |
| `Nenhuma das cotações de auto foi encontrada entre as suas nesta corretora.` | Idem |
| `Com ids não use search, leadId nem contactId.` | Tire os filtros |
| `version vale para um id só.` | Peça uma cotação por vez |
| `version só vale junto de ids.` | Passe `ids` |
| `A cotação não tem a versão <n>.` | Leia `versions` no detalhe |

## Recotação

| Mensagem | Conduta |
|---|---|
| `Informe franquiaModo e/ou franquia.` | Passe ao menos um |
| `Informe insuranceCompanyId e coberturas.` | Passe os dois |
| `Informe ao menos uma cobertura a trocar.` | `PRODUCT` ignora `false`. Para tirar adicional, use `FORM` |
| `Informe fieldChanges e/ou insuranceCompanyIds.` | Passe ao menos um |
| `Estas chaves não se alteram pelo MCP: <chaves>. A profissão vai sempre como "Outros" e o contato é o do corretor, como na tela.` | Tire essas chaves |
| `O tipo de veículo não muda numa recotação: crie outra cotação com create_auto_quote.` | Crie outra |
| `Nenhuma seguradora deu certo nesta versão, então não há o que recalcular com outra franquia. Recote as seguradoras que falharam antes de alterar a franquia.` | Redispare as que falharam |

## Veículo

| Mensagem | Conduta |
|---|---|
| `Informe a placa ou o chassi, um dos dois.` | Mande só um |
| `Placa inválida. Use o formato ABC1D23 ou ABC1234.` | Peça a placa de novo |
| `O chassi precisa ter 17 caracteres, sem as letras I, O e Q.` | Peça o chassi de novo |
| `Veículo não encontrado para esta consulta. Confira os dados ou preencha manualmente.` | Peça marca, modelo com versão, anos e combustível |
| `Consulta de veículo indisponível no momento. Preencha os dados manualmente.` | Idem |
| `O limite de consultas de placa foi atingido. Tente novamente em alguns minutos ou preencha os dados manualmente.` | Idem, ou espere |
| `A consulta de placa está sem crédito. Avise o suporte da Koter; enquanto isso, preencha os dados do veículo manualmente.` | Avise o corretor e peça os dados |
| `Informe os códigos em ordem: brandCode, depois modelCode, depois yearCode.` | Navegue na ordem |
| `Catálogo FIPE indisponível no momento. Preencha os dados do veículo manualmente.` | Peça os dados |
| `Valor FIPE não encontrado para esta combinação de marca, modelo e ano.` | Confira a combinação |

## Oferta e PDF

| Mensagem | Conduta |
|---|---|
| `Informe insuranceCompanyId e offerCode juntos, ou nenhum dos dois para limpar a escolha.` | Passe os dois |
| `Oferta não encontrada nesta cotação.` | Releia o detalhe. Oferta de versão antiga não vale |
| `PDF dessa seguradora ainda não está disponível.` | Confira `insurerPdfs`. Se persistir, abra pelo `url` |

## Limites e acesso

| Mensagem | Conduta |
|---|---|
| `Limite de 30 consultas de veículo por minuto atingido. Tente de novo em <n> segundos.` | Espere o tempo dito |
| `Limite de 10 disparos de cotação por minuto atingido. Tente de novo em <n> segundos.` | Idem |
| `Seu perfil não tem permissão para <ação> na corretora <nome>.` | Quem administra a corretora ajusta o cargo |
| `Seu perfil não tem mais permissão para usar esta conexão do Koter via MCP na corretora <nome>.` | Cargo ou módulo Auto da assinatura. Confira no Koter |
| `Nenhuma corretora ativa para este usuário. Selecione uma corretora no Koter e tente novamente.` | Selecione a corretora |

Os limites por conexão, de 60 escritas e 300 leituras por minuto, avisam com o tempo de espera na própria mensagem. Espere e repita: a recusa não conta no limite.
