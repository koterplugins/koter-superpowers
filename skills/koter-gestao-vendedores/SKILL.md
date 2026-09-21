---
name: koter-gestao-vendedores
description: Cadastra os vendedores da corretora no módulo Gestão do Koter — pessoas, categorias, gestores e hierarquia — e aponta a sujeira do cadastro. Use quando pedirem para cadastrar vendedor, corretor ou consultor, definir quem supervisiona quem, convidar alguém para o sistema, ou quando /introducao chegar na etapa de equipe da trilha do Gestão.
---

# koter-gestao-vendedores

Terceira etapa da trilha. **Não é pré-requisito da proposta** — `sellerId` é opcional no cadastro (comprovado na Koter Day). É pré-requisito da **comissão**: sem vendedor não há repasse, e sem repasse metade do módulo não faz sentido.

## 0 · Pré-requisitos e o que decide se a skill inteira existe

Precisa da fundação (passo 1 da trilha). E comece pelo **porte da operação**, porque ele decide se a skill inteira existe.

**Não pergunte: leia.** O porte já foi respondido uma vez, no passo 1 da `/introducao`, e mora em `perfil.porte` no estado (`introducao/references/estado.md`). Perguntar de novo é a repetição mais cara do plugin, porque a `koter-crm-fundacao` também precisa da mesma resposta.

| `perfil.porte` | O que esta skill faz |
|---|---|
| `solo` | cadastre **apenas ele** como vendedor e encerre. Nada de hierarquia, override, categorias ou convite — metade do esforço de configuração desaparece aqui |
| `com_vendedores` | siga a skill inteira |
| `assessoria` | siga a skill inteira, e leia o passo 3 (PJ) com atenção |

**Ordem de precedência quando as fontes discordam:**

1. **Detecção primeiro.** Se `gestao_config_list_sellers` já devolve gente, ela manda — confirme e siga: *"Vi 6 vendedores cadastrados, então você repassa; certo?"*
2. **Depois o estado.** Sem vendedores cadastrados, use `perfil.porte` e **confirme numa frase**, sem devolver a pergunta: *"Você me disse que só você vende, então cadastro você como vendedor e encerro por aqui; certo?"*
3. **Só se as duas faltarem**, pergunte — e grave a resposta em `perfil.porte`, para a `koter-crm-fundacao` não perguntar de novo:
   > **"Você repassa comissão para alguém, ou o dinheiro fica na casa?"**

## 1 · Detecção

```
gestao_config_list_sellers                    → quem já é vendedor
admin_usuarios_list_company_people            → pessoas da corretora (cada uma traz sellerId: null quando ainda não é vendedor)
admin_usuarios_list_users                     → quem tem conta, cargo, licença (isOwner marca o dono)
gestao_config_list_seller_categories(scope)   → slugs válidos de categoria, PF e PJ
admin_usuarios_get_person_hierarchy           → quem lidera quem
```

Na Koter Day isso devolveu uma pessoa só, o dono, com `sellerId: null` — ou seja, **o dono da corretora não era vendedor de si mesmo**. É o caso mais comum numa conta nova e a primeira coisa a resolver: ele vende, então tem que existir como vendedor, senão a comissão dele não tem onde cair.

## 2 · Todo vendedor paga uma PESSOA

O modelo do Koter não é "vendedor solto": todo vendedor aponta para uma pessoa da corretora. São dois caminhos, e escolher o errado duplica cadastro:

| Caminho | Quando | Como |
|---|---|---|
| `personId` | a pessoa já existe (é membro, ou já foi cadastrada) | pegue o `id` de `list_company_people` — **é um UUID**, diferente dos ids curtos do resto do Koter |
| `person: { name, document }` | ninguém com conta, e não existe cadastro | cria a pessoa junto, **sem conta no Koter** |

**`document` igual ao de outra pessoa não junta os cadastros** — o schema avisa. Procure em `list_company_people` antes de criar, e quando achar duplicata use `admin_usuarios_merge_company_people`.

`managerUserIds` é **obrigatório, mínimo 1**, e são **userIds** (de `list_users`), não personIds. Numa corretora de um dono só, é ele mesmo.

```
gestao_config_create_seller
  type: "PF" | "PJ"
  personId | person: { name, document }
  categorySlug: "vendedor-interno" | "vendedor-externo" | "afiliado" | "parceiro-indicador" | "cliente-indicador"
  managerUserIds: [ userId, ... ]
```

O cadastro **puxa sozinho os contatos da pessoa** (e-mail e celular) quando ela é membro. Não peça o que já está lá.

Para lote, `gestao_config_import_sellers`.

## 3 · PJ é outra conversa

Vendedor PJ (sub-corretora, corretor com CNPJ) exige `fiscal` com **razão social e regime tributário** (`MEI`, `SIMPLES_NACIONAL`, `LUCRO_PRESUMIDO`, `LUCRO_REAL`), e `members` com os usuários e a categoria organizacional de cada um. Pergunte o regime — é ele que decide retenção depois.

## 4 · Retenções e regras de pagamento — onde mora a divergência de extrato

`payoutRules` nasce com defaults que **ninguém lembra de conferir** e que aparecem no extrato do vendedor:

| Campo | Default | O que significa |
|---|---|---|
| `passTaxToSeller` | `true` | o imposto é descontado do vendedor; `false` = a casa absorve |
| `allowsPayoutAdvance` | `true` | ele pode pedir antecipação |
| `allowsNegativeBalance` | `false` | débito que não coube no lote **não** vira dívida para o próximo |
| `requiresInvoice` | `false` | não bloqueia repasse sem nota |
| `irWithholdingPercent` / `issWithholdingPercent` | nulos | sem retenção |
| `taxExemptInsuranceCompanyIds` | `[]` | operadoras em que a taxa não é descontada dele |

A pergunta que vale fazer, uma só, em opções: **"Imposto: desconta do vendedor ou a casa absorve?"** As outras, confirme pelo default.

Mudança em massa: `gestao_config_bulk_set_sellers_pass_tax` — e o schema avisa que **não regenera parcelas já existentes**, só a geração futura. Diga isso antes de rodar.

## 5 · Hierarquia — só se houver

`hierarchy` define os líderes da pessoa: `supervisorPersonIds`, `managerPersonIds`, `directorPersonIds` e `primaryLeaders`. São **personIds**, não userIds nem sellerIds.

**Não pergunte hierarquia se todo mundo está no mesmo nível.** Ela só importa quando houver override de liderança na comissão — e aí é a skill 4 que decide os percentuais, não esta.

Uma pergunta que só faz sentido quando a leitura pede: se alguém tiver **mais de um líder do mesmo tipo**, pergunte como se divide o override (`overrideSplitMode`, na skill 4). Quando ninguém tem, pular essa pergunta é o que faz a skill parecer inteligente.

## 6 · Convite e cargo — normalmente bloqueados

`admin_usuarios_send_invitations`, `set_user_role` e os `admin_cargos_*` exigem permissão de administração (`manage:users`, `create:invitation`, `admin:access`). Corretor comum não tem.

Faltando: **não tente e falhe.** Diga de quem depende e ofereça o texto pronto para ele mandar a quem administra. Registre a lacuna no estado e siga.

## 7 · Sujeira de cadastro — aponte, não conserte sozinho

Procure ativamente e traga junto com o diagnóstico:

- **Pessoas duplicadas** (dois cadastros com o mesmo nome ou documento) → `admin_usuarios_merge_company_people`, **só com o "pode juntar" dele**.
- **Membro da corretora que vende e não é vendedor** (`sellerId: null` em quem tem conta e cargo comercial) → é o caso do dono na Koter Day.
- **Vendedor sem gestor** ou sem dado bancário, que trava o repasse depois.

## 8 · Validação e próxima

Releia `gestao_config_list_sellers` e diga o que mudou, em números e nomes. Depois:

- **`koter-gestao-comissoes`** — quanto cada um leva *(recomendada: é o que dá sentido ao cadastro que você acabou de fazer)*
- `koter-gestao-campos` — o que ele anota e o Koter ainda não tem
- `koter-proposta` — cadastrar uma proposta agora
- parar por aqui

## Armadilhas conhecidas

| Sintoma | Causa | Conserto |
|---|---|---|
| `create_seller` recusa | `managerUserIds` faltando ou com personId no lugar de userId | são **userIds**, de `list_users`, mínimo 1 |
| Pessoa cadastrada duas vezes | documento igual não junta cadastros | procure em `list_company_people` antes; `merge_company_people` depois |
| `personId` recusado | é UUID, não id curto | copie de `list_company_people` |
| Comissão do dono não cai | o dono não é vendedor de si mesmo | cadastre-o como vendedor |
| Imposto muda mas extrato antigo não | `bulk_set_sellers_pass_tax` não regenera parcelas | vale só para geração futura |
| Convite falha | falta `manage:users` / `create:invitation` | peça a quem administra a corretora |
