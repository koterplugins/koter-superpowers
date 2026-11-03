---
name: koter-gestao-vendedores
description: Cadastra vendedores no Koter, com pessoas, gestores e hierarquia, e aponta a sujeira do cadastro. Use quando pedirem para cadastrar vendedor, definir quem lidera quem ou convidar alguém.
---

# koter-gestao-vendedores

Terceira etapa da trilha. **Não é pré-requisito da proposta**: `sellerId` é opcional no cadastro. É pré-requisito da **comissão**: sem vendedor não há repasse, e sem repasse metade do módulo não faz sentido.

## 0 · Pré-requisitos e o que decide se a skill inteira existe

Precisa da fundação (passo 1 da trilha). E comece pelo **porte da operação**, porque ele decide se a skill inteira existe.

**Não pergunte: leia.** O porte já foi respondido uma vez, no passo 1 da `/introducao`, e mora em `perfil.porte` no estado (`introducao/references/estado.md`). Perguntar de novo é a repetição mais cara do plugin, porque a `koter-crm-fundacao` também precisa da mesma resposta.

| `perfil.porte` | O que esta skill faz |
|---|---|
| `solo` | cadastre **apenas ele** como vendedor e encerre. Nada de hierarquia, override, categorias ou convite: metade do esforço de configuração desaparece aqui |
| `com_vendedores` | siga a skill inteira |
| `assessoria` | siga a skill inteira, e leia o passo 3 (PJ) com atenção |

**Ordem de precedência quando as fontes discordam:**

1. **Detecção primeiro.** Se `gestao_config_list_sellers` já devolve gente, ela manda: confirme e siga: *"Vi 6 vendedores cadastrados, então você repassa; certo?"*
2. **Depois o estado.** Sem vendedores cadastrados, use `perfil.porte` e **confirme numa frase**, sem devolver a pergunta: *"Você me disse que só você vende, então cadastro você como vendedor e encerro por aqui; certo?"*
3. **Só se as duas faltarem**, pergunte, e grave a resposta em `perfil.porte`, para a `koter-crm-fundacao` não perguntar de novo:
   > **"Você repassa comissão para alguém, ou o dinheiro fica na casa?"**

## 1 · Detecção

```
gestao_config_list_sellers                    → quem já é vendedor
admin_usuarios_list_company_people            → pessoas da corretora (cada uma traz sellerId: null quando ainda não é vendedor)
admin_usuarios_list_users                     → quem tem conta, cargo, licença (isOwner marca o dono)
gestao_config_fetch_gestao_config_context(include: ["sellerCategories"])
                                              → slugs válidos de categoria, PF e PJ
admin_usuarios_list_company_people(ids, include: ["hierarchy"])
                                              → quem lidera quem
```

Na corretora de demonstração, em 21/09/2026, isso devolveu uma pessoa só, o dono, com `sellerId: null`: **o dono da corretora não era vendedor de si mesmo**. É o caso comum numa conta nova e a primeira coisa a resolver: ele vende, então tem que existir como vendedor, senão a comissão dele não tem onde cair.

## 2 · Todo vendedor paga uma PESSOA

O modelo do Koter não é "vendedor solto": todo vendedor aponta para uma pessoa da corretora. São dois caminhos, e escolher o errado duplica cadastro:

| Caminho | Quando | Como |
|---|---|---|
| `personId` | a pessoa já existe (é membro, ou já foi cadastrada) | pegue o `id` de `admin_usuarios_list_company_people`: **é um UUID**, diferente dos ids curtos do resto do Koter |
| `person: { name, document }` | ninguém com conta, e não existe cadastro | cria a pessoa junto, **sem conta no Koter** |

**`document` igual ao de outra pessoa não junta os cadastros**: o schema avisa. Procure em `admin_usuarios_list_company_people` antes de criar, e quando achar duplicata use `admin_usuarios_merge_company_people` (recusado quando as duas pessoas têm conta ou as duas têm vendedor).

`managerUserIds` é **obrigatório, mínimo 1**, e são **userIds** (de `admin_usuarios_list_users`), não personIds. Numa corretora de um dono só, é ele mesmo.

```
gestao_config_save_seller                (sem sellerId = cria)
  type: "PF" | "PJ"
  personId | person: { name, document }
  categorySlug: <slug de sellerCategories>     ← ex.: vendedor-interno, afiliado
  managerUserIds: [ userId, ... ]
```

O cadastro **puxa sozinho os contatos da pessoa** (e-mail e celular) quando ela é membro. Não peça o que já está lá.

Para lote de quem já é usuário, `gestao_config_import_sellers`, a partir dos cargos (padrão: Consultor). Usuário já vendedor é ignorado. Migrando de outro sistema, o alvo `SELLERS` da `koter-importacao` é melhor: guarda o `externalId` e as propostas apontam para ele.

**Editar regrava o cadastro.** `gestao_config_save_seller` com `sellerId` substitui `contacts`, `bankAccounts`, `members`, `managerUserIds`, `address`, `avatarId` e `categorySlug` pelo que você mandar: omitir um deles **apaga** o que está salvo. Leia antes com `gestao_config_list_sellers(ids: [sellerId])` e reenvie o que deve ficar. `payoutRules`, `fiscal`, `passTaxToSeller`, `payoutMinimumOverride`, `chargebackRecoveryCapPercent`, `hierarchy` e a pessoa, quando omitidos, ficam como estão. E `type: "PF"` num vendedor PJ apaga `members` e o bloco `fiscal`.

## 3 · PJ é outra conversa

Vendedor PJ (sub-corretora, corretor com CNPJ) exige `fiscal` com **razão social e regime tributário** (`MEI`, `SIMPLES_NACIONAL`, `LUCRO_PRESUMIDO`, `LUCRO_REAL`), e `members` com os usuários e a categoria organizacional de cada um. Pergunte o regime: é ele que decide retenção depois.

## 4 · Retenções e regras de pagamento, onde mora a divergência de extrato

`payoutRules` nasce com defaults que **ninguém lembra de conferir** e que aparecem no extrato do vendedor:

| Campo | Default | O que significa |
|---|---|---|
| `allowsPayoutAdvance` | `true` | ele pode pedir antecipação |
| `allowsNegativeBalance` | `false` | débito que não coube no lote **não** vira dívida para o próximo |
| `requiresInvoice` | `false` | não bloqueia repasse sem nota |
| `payoutBlocked` | `false` | não bloqueia o pagamento. Ligado, pagar o lote dele é recusado |
| `irWithholdingPercent` / `issWithholdingPercent` | nulos | sem retenção. Incidem sobre o valor da nota: bruto mais créditos, menos a recuperação de estorno |
| `taxExemptInsuranceCompanyIds` | `[]` | operadoras em que a taxa não é descontada dele |

A pergunta que vale fazer, uma só, em opções: **"Imposto: desconta do vendedor ou a casa absorve?"** As outras, confirme pelo default.

Fora de `payoutRules`, só na edição:

| Campo | O que faz |
|---|---|
| `passTaxToSeller` | nasce `true`: o imposto é descontado do vendedor. `false` = a casa absorve |
| `payoutMinimumOverride` | piso de repasse deste vendedor. Nulo volta ao da corretora |
| `chargebackRecoveryCapPercent` | quanto do bruto de cada lote pode ir para recuperar estorno, de 0 a 100. Nulo segue o da corretora. Sem teto, a dívida inteira entra no lote seguinte |

Mudança em massa: `gestao_config_bulk_set_sellers_pass_tax`, e o schema avisa que **não refaz o que já foi gerado**, só o que vier depois. Diga isso antes de rodar. É diferente do imposto da seguradora, `insurerTaxPercent`, que recalcula o que não foi pago.

## 5 · Hierarquia, só se houver

`hierarchy` define os líderes da pessoa: `supervisorPersonIds`, `managerPersonIds`, `directorPersonIds` e `primaryLeaders`. São **personIds**, não userIds nem sellerIds.

**Não pergunte hierarquia se todo mundo está no mesmo nível.** Ela só importa quando houver override de liderança na comissão, e aí é a `koter-gestao-comissoes` que decide os percentuais, não esta.

Uma pergunta que só faz sentido quando a leitura pede: se alguém tiver **mais de um líder do mesmo tipo**, pergunte como se divide o override (`overrideSplitMode`, na `koter-gestao-comissoes`). Quando ninguém tem, pular essa pergunta é o que faz a skill parecer inteligente.

## 5.1 · Cocorretor, indicador e estipulante de fora não são vendedores

Quem recebe por uma venda e não é da casa não precisa de cadastro aqui. Entra no contrato como participante externo, com `gestao_contratos_save_contract_participants` (`koter-contrato`). Não crie vendedor só para pagar um indicador avulso.

## 6 · Convite e cargo, normalmente bloqueados

`admin_usuarios_send_invitations`, `admin_usuarios_update_user_membership` (troca de cargo) e as tools de `admin-cargos` exigem permissão de administração. Corretor comum não tem. Convite é e-mail a colega, nunca a cliente.

Faltando: **não tente e falhe.** Diga de quem depende e ofereça o texto pronto para ele mandar a quem administra. Registre a lacuna no estado e siga.

## 7 · Sujeira de cadastro: aponte, não conserte sozinho

Procure ativamente e traga junto com o diagnóstico:

- **Pessoas duplicadas** (dois cadastros com o mesmo nome ou documento) → `admin_usuarios_merge_company_people`, **só com o "pode juntar" dele**: o schema é explícito, nunca junte só porque o CPF coincide, e a junção apaga a outra pessoa sem volta.
- **Membro da corretora que vende e não é vendedor** (`sellerId: null` em quem tem conta e cargo comercial) → é o caso do dono.
- **Vendedor sem dado bancário.** O Koter não recusa o pagamento por isso, mas a prévia de pagamento do lote sai sem banco, conta e PIX, e quem paga fica sem para onde mandar.

## 8 · Validação e próxima

Releia `gestao_config_list_sellers` e diga o que mudou, em números e nomes. Depois:

- **`koter-gestao-comissoes`**: quanto cada um leva *(recomendada: é o que dá sentido ao cadastro que você acabou de fazer)*
- `koter-gestao-campos`: o que ele anota e o Koter ainda não tem
- `koter-proposta`: cadastrar uma proposta agora
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `gestao_config_save_seller` recusa na criação | `managerUserIds` faltando ou com personId no lugar de userId | são **userIds**, de `admin_usuarios_list_users`, mínimo 1 |
| Vendedor perdeu conta bancária ou contato depois de editar | `gestao_config_save_seller` com `sellerId` regrava os conjuntos omitidos | leia com `gestao_config_list_sellers(ids)` e reenvie tudo que deve ficar |
| Pessoa cadastrada duas vezes | documento igual não junta cadastros | procure em `admin_usuarios_list_company_people` antes; `admin_usuarios_merge_company_people` depois |
| `personId` recusado | é UUID, não id curto | copie de `admin_usuarios_list_company_people` |
| Comissão do dono não cai | o dono não é vendedor de si mesmo | cadastre-o como vendedor |
| Imposto muda mas extrato antigo não | `gestao_config_bulk_set_sellers_pass_tax` não refaz o gerado | vale só para o que vier depois |
| "O pagamento de comissão deste vendedor está bloqueado no cadastro dele. Desmarque "Bloqueia pagamento de comissão" para pagar." | `payoutBlocked` ligado | decida com o corretor; `payoutRules.payoutBlocked` |
| "Este vendedor só recebe com nota fiscal. Registre a nota do lote antes de pagar." | `requiresInvoice` ligado | `koter-gestao-repasse` |
| "passTaxToSeller, payoutMinimumOverride e chargebackRecoveryCapPercent só valem na edição ..." | mandou na criação | crie e edite depois |
| Convite falha | falta permissão de administração | peça a quem administra a corretora |

## Conferência

Tools, `payoutRules`, padrões e mensagens conferidos no inventário e lidos no código em 03/11/2026, não executados.
O retrato do dono sem cadastro de vendedor foi medido em 21/09/2026 na corretora de demonstração.
