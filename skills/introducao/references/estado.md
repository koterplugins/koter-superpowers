# Estado do onboarding

## Onde mora

Não existe tool no MCP que grave preferências ou progresso do onboarding. Enquanto não existir, o estado vive **no cliente**:

```
.koter/onboarding.json    (na pasta de trabalho, ou no home se não houver)
```

Uma chave por corretora, usando o `companyId` do handshake: a mesma máquina pode atender duas corretoras. Sem handshake, o `companyId` sai do plano B de `handshake.md`.

> ⚠️ **O `companyId` é chave, não garantia.** A conexão segue a corretora ativa da pessoa: trocar de corretora no Koter leva a IA junto, e `list_*` continua respondendo, com os dados da outra conta. Antes de **aplicar** qualquer coisa, releia o handshake (`admin_cargos_fetch_admin_roles_context` com `include: ["myPermissions"]`) e confira que o `companyId` é o mesmo do arquivo. Se mudou, pare e avise: não grave no bloco errado nem escreva na corretora errada.

## Por que perder o arquivo não é problema

O diagnóstico do passo 2 é **idempotente**: ele reconstrói o mapa de maturidade lendo o Koter, e o Koter é a verdade.

Testado em 21/09/2026 na corretora de demonstração, escrevendo o arquivo, apagando e refazendo o diagnóstico: **a leitura recupera quase tudo.**

| Campo | A leitura recupera? | Como |
|---|---|---|
| `perfil.porte` | **quase sempre** | `gestao_config_list_sellers` com mais de um vendedor já diz `com_vendedores`. Só numa conta sem vendedor é que volta a ser pergunta, e aí é a pergunta normal do passo 1 |
| `perfil.prioridade` | **não** | comissão ou atendimento é preferência, não configuração |
| `pre_requisitos_de_tela.cloud_api_conectada` | **sim** | `whatsappInstances` de `koterzap_configuracao_fetch_koterzap_config_context` vazio ou só com `EVOLUTION` |
| `pre_requisitos_de_tela.credencial_auto` | **sim** | `summary` de `cotacao_auto_get_auto_insurer_availability`, com `AUTO` em `modules` |
| acompanhamento de comissão e pendências | **sim, e não se guarda** | `commissionTrackedSince` em `gestao_comissao_get_commission_settings` e `openCountByType` em `gestao_comissao_list_commission_pendencies` |
| contrato implantado | **sim, e não se guarda** | `gestao_contratos_list_contracts` e o filtro `hasContract` de `gestao_list_proposals` |
| `lacunas` e a ferramenta que ele usa no lugar | **não** | nunca esteve no Koter |
| `etapas.*.artefatos` | **sim** | `key` de campo, id de base de conhecimento e nome de tag saem todos de listagem |
| `usou_de_verdade` | **sim** | `gestao_list_proposals`, `gestao_contratos_list_contracts`, `crm_list_leads` e `cotacao_auto_list_auto_quotes` trazem o que foi feito e quando |
| volume da conta (nova ou em uso) | **sim, e nunca se guarda** | `crm_list_leads(pageSize: 1)` e `gestao_list_proposals(pageSize: 1)` devolvem o `total` em duas chamadas. Volume muda toda semana: guardar é garantir ficar errado. **Leia sempre**: é ele que decide o destino dos atos 1 e 2 |

**O que o arquivo de fato carrega, então, são três coisas:** a prioridade, as lacunas adiadas (com a ferramenta alternativa) e o registro de que cada tarefa de tela foi oferecida, com a data. Os dois pré-requisitos, Cloud API e credencial de auto, se conferem por leitura. O template da Meta não se guarda: é uma frase de orientação do ato 0, e o assunto é da `koter-zap-fundacao`.

Isso é bom: significa que **um corretor que troca de IA perde quase nada**. O plugin reabre, relê o Koter, e a única coisa que precisa reperguntar é a prioridade.

Ao abrir, **sempre releia o Koter** e trate o arquivo como memória de conversa, nunca como verdade sobre a configuração. Artefato guardado que não bate com a leitura: vale a leitura.

## Formato

```json
{
  "versao": 3,
  "companyId": "<id-da-corretora>",
  "perfil": {
    "porte": "com_vendedores",
    "prioridade": "comissao",
    "modulos": ["SAUDE", "AUTO", "CRM", "KOTERZAP", "GESTAO"]
  },
  "pre_requisitos_de_tela": {
    "cloud_api_conectada": { "estado": "pendente", "oferecido_em": "2026-11-03" },
    "credencial_auto": { "estado": "nao_se_aplica" }
  },
  "lacunas": [
    { "modulo": "KOTERZAP", "decisao": "outra_ferramenta", "ferramenta": "<nome da ferramenta>", "em": "2026-11-03" }
  ],
  "etapas": {
    "koter-gestao-fundacao": {
      "estado": "concluida",
      "em": "2026-11-03",
      "aplicado": ["status:Implantada", "status:Cancelada", "entidade:<nome da entidade>"],
      "artefatos": { "opera_com": ["Saúde", "Odonto"], "operadoras": ["<operadora>"] }
    },
    "koter-gestao-campos": { "estado": "pendente" },
    "koter-importacao": {
      "estado": "em_andamento",
      "em": "2026-11-03",
      "artefatos": { "sourceSystem": "<nome do sistema de origem>" }
    }
  },
  "usou_de_verdade": {
    "koter-proposta":  { "primeira_em": "2026-11-03" },
    "koter-contrato":  { "primeira_em": "2026-11-03" },
    "koter-crm-lead":  { "primeira_em": null },
    "koter-multicalculo-auto": { "primeira_em": null }
  },
  "ultima_etapa": "koter-gestao-fundacao"
}
```

### Os campos, e quem os escreve

| Campo | Quem escreve | Quem lê |
|---|---|---|
| `perfil.porte` | **só a roteadora**, no passo 1 | `koter-gestao-vendedores` e `koter-crm-fundacao`, que **confirmam em vez de perguntar** |
| `perfil.prioridade` | só a roteadora, no passo 1 | a roteadora, para ordenar o ato 3 da passada única |
| `pre_requisitos_de_tela` | a roteadora oferece; a skill onde a tarefa dói atualiza | todas: é o que evita prometer o que não se cumpre |
| `etapas.*.artefatos` | cada skill filha, com o que a próxima precisa **literal** | a skill seguinte da trilha |
| `etapas.koter-importacao.artefatos.sourceSystem` | `koter-importacao` | a própria skill. A identidade da linha importada usa esse nome: reimportar com outro duplica |
| `usou_de_verdade` | `koter-proposta`, `koter-contrato`, `koter-crm-lead` e `koter-multicalculo-auto` | a roteadora, para saber se o onboarding chegou ao fim |

`porte`: `solo`, `com_vendedores`, `assessoria`.
`prioridade`: `comissao`, `atendimento`.
Estado de etapa: `pendente`, `em_andamento`, `concluida`, `pulada`, `bloqueada` (com `motivo`, tipicamente falta de permissão).
Estado de pré-requisito: `pendente`, `feito`, `nao_se_aplica`, `dispensado` (ele disse que não quer).

`koter-proposta`, `koter-contrato`, `koter-crm-lead` e `koter-multicalculo-auto` **não são etapas**: rodam sempre. Elas escrevem em `usou_de_verdade`, não em `etapas`. `koter-multicalculo-auto` só aparece com `AUTO` em `modules`.

### Idempotência

Reentrar numa skill já `concluida` não pode duplicar nada. Por isso toda skill filha **detecta antes de criar** e casa por nome normalizado (sem acento, caixa dobrada). O Koter ajuda: criar origem (`crm_config_save_origin` sem `originId`) **recusa** nome que já existe, e `crm_config_save_lead_tag` sem `tagId` devolve a tag de mesmo nome no escopo. Mas ajuda só na criação nova: **o par antigo continua separado**, e é isso que a checagem 1 do passo 2c acha em conta com histórico. `crm_config_save_loss_reason` não deduplica de jeito nenhum (checagem 7). Gravar a etapa como `concluida` é registro do que aconteceu, nunca autorização para pular a releitura.

Grave depois de **cada** skill filha, nunca só no fim. Corretor fecha a janela no meio, e deve reabrir de onde parou.

## Se um dia o Koter guardar isso

Vale trocar: o objetivo é o plugin funcionar em qualquer IA, e estado que mora na máquina torna o plugin específico da máquina. O contrato acima já está desenhado para virar um par de chamadas de leitura e escrita sem mudar nenhuma skill filha.
