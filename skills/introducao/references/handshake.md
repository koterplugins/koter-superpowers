# Handshake: o que a primeira chamada responde

```
admin_cargos_fetch_admin_roles_context(include: ["myPermissions"])
```

Peça **só** `myPermissions`. Sem `include`, a chamada traz também o catálogo inteiro de permissões e os limites de carteira, que o handshake não usa.

Formato da resposta (lido no código em 03/11/2026, não executado):

```json
{ "myPermissions": {
  "companyId": "<id-da-corretora>",
  "permissions": ["admin:access", "manage:sellers", "read:proposal:list", "create:proposal", "..."],
  "implicitPermissions": ["..."],
  "licensed": true,
  "crmAccess": true,
  "modules": ["SAUDE", "AUTO", "CRM", "KOTERZAP", "GESTAO"]
} }
```

## Como ler cada campo

| Campo | Uso |
|---|---|
| `modules` | Os módulos da corretora: `SAUDE`, `AUTO`, `CRM`, `KOTERZAP`, `GESTAO`. É o que sustenta a constatação "vi que você tem Gestão e CRM, mas não AUTO", e é `AUTO` que decide oferecer o multicálculo. `SAUDE` não abre cotação pelo MCP: ela é só master |
| `permissions` | O que essa pessoa pode fazer: o cargo, o que ele implica e o que todo membro já tem. Cheque **antes** de cada passo de escrita |
| `implicitPermissions` | A parte de `permissions` que todo membro tem sem depender de licença |
| `licensed` | Sem licença, boa parte da escrita vai falhar. Diga isso antes de tentar |
| `crmAccess` | Se `false`, não ofereça a trilha do CRM |
| `companyId` | Chave do arquivo de estado: é o que separa duas corretoras na mesma máquina. **Pode vir `null`**: não há corretora ativa, e nada segue até ele selecionar uma no Koter |

**A conexão segue a corretora ativa.** Quem troca de corretora no Koter leva a IA junto. Por isso reler o `companyId` a cada rodada de escrita é obrigação, não preciosismo.

## Permissões: sempre a lista granular

**Corretora nunca recebe `all`.** Se `permissions` vier com `all`, a conexão não é de corretora: pare e avise. Teste sempre pela permissão do passo.

Os grupos que importam na trilha. Estas chaves são as que a própria resposta traz em `permissions`:

| Área | Chaves que costumam decidir |
|---|---|
| Entrada dos módulos | `crm:access`, `management:access`, `mng:finance:access`, `admin:access` |
| Proposta e contrato | `read:proposal:list`, `read:proposal`, `create:proposal`, `update:proposal` (implantar e registrar evento pedem esta) |
| Campos personalizados | `manage:custom-fields`, `mng:custom-field-definition:create` |
| Vendedores | `manage:sellers`, `create:seller` |
| Comissão, configuração | `mng:commission-grade:manage`, `mng:commission-grade:publish-version` |
| Comissão, baixa e conferência | `mng:parcela:generate` (o nome é antigo, a chave cobre toda escrita de baixa) |
| Repasse | `mng:payout-batch:pay` |
| Financeiro | `mng:finance-entry:settle`, `mng:bank-statement:import` |
| Automação do Gestão | `manage:management-automations` |
| KoterZap | `manage:chatbots`, `conversation:read` |
| Multicálculo auto | `app:auto-quote:create` |
| Convites e usuários (**só admin**) | `manage:users`, `create:invitation` |

Regra ao faltar permissão:

- Antes de um passo de escrita, verifique a permissão correspondente.
- Faltando, **não tente e falhe**. Diga o que falta e de quem depende:
  > "Convidar vendedor e mexer em cargo é coisa de quem administra a corretora. Eu deixo o resto pronto e te dou o texto para mandar a quem administra. Quer?"
- Registre a lacuna no estado e siga com o que dá para fazer. Parar o onboarding inteiro por um passo bloqueado é desperdício.

As áreas que mais dependem de permissão de administrador: convites (`admin_usuarios_send_invitations`), cargos (`admin_cargos_*`) e hierarquia de pessoas.

## Quem não alcança o handshake: plano B

**Este passo não é universal.** `admin_cargos_fetch_admin_roles_context` só existe na conexão com `admin-cargos`, e essa área só abre para quem tem acesso de administrador e pode criar, editar ou excluir cargo. A URL também precisa incluí-la. Vendedor e consultor não fazem este handshake.

Sem a ferramenta, chame:

```
list_toolsets
```

Ele diz, por toolset, o que aquele cargo vê (`toolsCount`). É o substituto mais barato, com dois limites:

| Falta | Como resolver |
|---|---|
| `companyId` | `gestao_list_proposals(pageSize: 1)` traz `proposals[].company`, ou `crm_config_fetch_crm_config_context` traz `tags[].companyId` |
| `modules` e `permissions` | deduza pelo que `list_toolsets` mostra: toolset com `toolsCount` acima de zero está aberto. `cotacao-auto` presente é o sinal de que dá para cotar auto |

Diga que o retrato é parcial, e monte a trilha só com o que apareceu:

> "Seu cargo enxerga CRM e Multicálculo auto. O Gestão e a administração não aparecem para você, então vou cuidar só do que está na sua mão."

## Quando o handshake falha

| Sintoma | Leitura | O que dizer |
|---|---|---|
| Nenhuma tool do Koter disponível | MCP não conectado | Peça para conectar `https://api.koter.app/mcp-user/koter` e ofereça retomar |
| Só aparecem `list_toolsets`, `enable_toolset`, `disable_toolset` | URL com `?toolsets=none`, ou corretora tirada há menos de 5 minutos (depois disso vem 403) | Selecione uma corretora no Koter. Se a URL tiver `none`, troque a URL |
| **400** ao chamar qualquer coisa | A URL pede um toolset que a conexão não concedeu. A mensagem lista os disponíveis | Tire o toolset da URL ou reconecte marcando a área |
| **401** | Conexão inválida, revogada ou vencida. Pode ter sido derrubada por outra conexão que divide área com ela | A IA refaz o login. Se voltar a cair, veja os pacotes sem sobreposição em `conexao-por-modulo.md` |
| **403** com `Seu perfil não tem mais permissão` | A conexão vale, mas o cargo ou o módulo não alcança mais a área naquela corretora. Reconectar não resolve | Peça para quem administra conferir o cargo, e confira a corretora ativa |
| `Nenhuma corretora ativa para este usuário.` | Sem corretora selecionada | Selecione uma no Koter e tente de novo |
| `Limite de 60 chamadas de escrita por minuto` e parecidas | Limite por minuto | Espere o tempo da mensagem e repita. A recusa não conta |
| `modules` vazio | Conta sem módulo contratado | Só o passo 1b faz sentido; não monte trilha |

A tabela inteira de erros e limites está em `conexao-por-modulo.md`.

Nunca siga adiante "no escuro": sem handshake nem plano B, toda pergunta seguinte vira formulário.
