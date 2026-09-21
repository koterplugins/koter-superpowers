# Handshake — o que a primeira chamada responde

```
admin_cargos_get_my_effective_permissions
```

Resposta real (corretora de demonstração **Koter Day**, 18/09/2026):

```json
{
  "companyId": "<id-da-corretora>",
  "permissions": ["admin:access", "manage:sellers", "mng:commission-grade:create",
                  "read:proposal:list", "create:proposal", "..."],
  "licensed": true,
  "crmAccess": true,
  "modules": ["SAUDE", "CRM", "KOTERZAP", "GESTAO"]
}
```

## Como ler cada campo

| Campo | Uso |
|---|---|
| `modules` | Os módulos contratados. É o que sustenta a constatação "vi que você tem Gestão e CRM, mas não AUTO". |
| `permissions` | O que essa pessoa pode fazer. Cheque **antes** de cada passo de escrita. |
| `licensed` | Sem licença, boa parte da escrita vai falhar. Diga isso antes de tentar. |
| `crmAccess` | Se `false`, não ofereça a trilha do CRM. |
| `companyId` | Chave do arquivo de estado — é o que separa duas corretoras na mesma máquina. |

## Permissões: a lista é granular, não um "all"

Uma conta de dono pode voltar com `"all"`, mas **o caso normal é a lista granular** — a Koter Day, que é conta de administrador, já volta com ~280 permissões nomeadas e **sem** `"all"`. Nunca teste por `"all"`: teste pela permissão do passo.

Os prefixos que importam na trilha do Gestão:

| Prefixo | Cobre | Exemplos |
|---|---|---|
| `manage:management-*`, `create/update/delete:management-*` | fundação: seguradora, ramo, categoria, entidade, status | `create:management-segment`, `manage:management-status` |
| `manage:custom-fields`, `mng:custom-field-*` | campos personalizados | `mng:custom-field-definition:create` |
| `manage:sellers`, `create/update/delete:seller` | vendedores | `create:seller` |
| `mng:commission-*`, `mng:payout-batch:*` | comissão e repasse | `mng:commission-grade:publish-version`, `mng:payout-batch:pay` |
| `mng:finance-*`, `mng:bank-*` | financeiro e conciliação | `mng:finance-entry:settle`, `mng:bank-statement:import` |
| `manage:management-automations` | automações do Gestão | — |
| `manage:users`, `create:invitation` | convites e cargos (**só admin**) | `admin:access` |

Regra ao faltar permissão:

- Antes de um passo de escrita, verifique a permissão correspondente.
- Faltando, **não tente e falhe**. Diga o que falta e de quem depende:
  > "Convidar vendedor e mexer em cargo é coisa de quem administra a corretora. Eu deixo o resto pronto e te dou o texto para mandar a quem administra — quer?"
- Registre a lacuna no estado e siga com o que dá para fazer. Parar o onboarding inteiro por um passo bloqueado é desperdício.

As áreas que mais dependem de permissão de administrador: convites (`admin_usuarios_send_invitations`), cargos (`admin_cargos_*`) e hierarquia de pessoas.

## Quando o handshake falha

| Sintoma | Leitura | O que dizer |
|---|---|---|
| Nenhuma tool do Koter disponível | MCP não conectado | Peça para conectar `https://api.koter.app/mcp-user/koter` e ofereça retomar |
| Tools aparecem mas a chamada dá erro de auth | Vínculo expirado | Peça para revincular |
| `modules` vazio | Conta sem módulo contratado | Só o passo 1b faz sentido; não monte trilha |

Nunca siga adiante "no escuro": sem handshake, toda pergunta seguinte vira formulário.
