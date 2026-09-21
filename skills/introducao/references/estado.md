# Estado do onboarding

## Onde mora

Não existe tool no MCP que grave preferências ou progresso do onboarding. Enquanto não existir, o estado vive **no cliente**:

```
.koter/onboarding.json    (na pasta de trabalho, ou no home se não houver)
```

Uma chave por corretora, usando o `companyId` do handshake — a mesma máquina pode atender duas corretoras.

> ⚠️ **O `companyId` é chave, não garantia.** Uma conexão pode trocar de corretora no meio da sessão (aconteceu em 21/09/2026: `list_*` continuou respondendo, com os dados de outra conta). Antes de **aplicar** qualquer coisa, releia `admin_cargos_get_my_effective_permissions` e confira que o `companyId` é o mesmo do arquivo. Se mudou, pare e avise — não grave no bloco errado nem escreva na corretora errada.

## Por que perder o arquivo não é problema

O diagnóstico do passo 2 é **idempotente**: ele reconstrói o mapa de maturidade lendo o Koter, e o Koter é a verdade.

**Testado em 21/09/2026 na Koter Day**, escrevendo o arquivo, apagando e refazendo o diagnóstico. O resultado corrige o que esta página dizia antes: **a leitura recupera quase tudo.**

| Campo | A leitura recupera? | Como |
|---|---|---|
| `perfil.porte` | **quase sempre** | `gestao_config_list_sellers` com mais de um vendedor já diz `com_vendedores`. Só numa conta sem vendedor é que volta a ser pergunta — e aí é a pergunta normal do passo 1 |
| `perfil.prioridade` | **não** | comissão ou atendimento é preferência, não configuração |
| `pre_requisitos_de_tela.cloud_api_conectada` | **sim** | `list_whatsapp_instances` vazio ou só com `EVOLUTION` |
| ~~`pre_requisitos_de_tela.template_meta_aprovado`~~ | **saiu do arquivo** | template da Meta deixou de ser tarefa da `/introducao` em 21/09/2026. Vira uma frase de orientação no ato 0 e o assunto inteiro pertence à `koter-zap-fundacao`, que é onde `list_meta_message_templates(instanceId)` tem uso. Não guarde estado disso |
| ~~`pre_requisitos_de_tela.parcelas_geradas`~~ | **saiu do arquivo** | `list_proposal_installments(proposalId)` responde em uma chamada: `total: 0` é não gerada. Deixou de ser pergunta e de ser estado |
| `lacunas` e a ferramenta que ele usa no lugar | **não** | nunca esteve no Koter |
| `etapas.*.artefatos` | **sim** | `key` de campo, id de base de conhecimento e nome de tag saem todos de listagem |
| `usou_de_verdade` | **sim** | `list_proposals` e `list_leads` trazem `createdAt` |

**O que o arquivo de fato carrega, então, são três coisas:** a prioridade, as lacunas adiadas (com a ferramenta alternativa) e o registro de que a tarefa de tela foi oferecida, com a data. O único pré-requisito que sobrou — Cloud API conectada — se confere por leitura.

Isso é bom: significa que **um corretor que troca de IA perde quase nada**. O plugin reabre, relê o Koter, e a única coisa que precisa reperguntar é a prioridade.

Ao abrir, **sempre releia o Koter** e trate o arquivo como memória de conversa, nunca como verdade sobre a configuração. Artefato guardado que não bate com a leitura: vale a leitura.

## Formato

```json
{
  "versao": 2,
  "companyId": "<id-da-corretora>",
  "perfil": {
    "porte": "com_vendedores",
    "prioridade": "comissao",
    "modulos": ["SAUDE", "CRM", "KOTERZAP", "GESTAO"]
  },
  "pre_requisitos_de_tela": {
    "cloud_api_conectada": { "estado": "pendente", "oferecido_em": "2026-09-21" }
  },
  "lacunas": [
    { "modulo": "KOTERZAP", "decisao": "outra_ferramenta", "ferramenta": "Chatwoot", "em": "2026-09-21" }
  ],
  "etapas": {
    "koter-gestao-fundacao": {
      "estado": "concluida",
      "em": "2026-09-21",
      "aplicado": ["status:Implantada", "status:Cancelada", "entidade:Qualicorp"],
      "artefatos": { "opera_com": ["Saúde", "Odonto"], "operadoras": ["Amil", "SulAmérica"] }
    },
    "koter-gestao-campos": { "estado": "pendente" }
  },
  "usou_de_verdade": {
    "koter-proposta":  { "primeira_em": "2026-09-21" },
    "koter-crm-lead":  { "primeira_em": null }
  },
  "ultima_etapa": "koter-gestao-fundacao"
}
```

### Os campos, e quem os escreve

| Campo | Quem escreve | Quem lê |
|---|---|---|
| `perfil.porte` | **só a roteadora**, no passo 1 | `koter-gestao-vendedores` e `koter-crm-fundacao`, que **confirmam em vez de perguntar** |
| `perfil.prioridade` | só a roteadora, no passo 1 | a roteadora, para ordenar o ato 3 da passada única |
| `pre_requisitos_de_tela` | a roteadora oferece; a skill onde a tarefa dói atualiza | todas — é o que evita prometer o que não se cumpre |
| `etapas.*.artefatos` | cada skill filha, com o que a próxima precisa **literal** | a skill seguinte da trilha |
| `usou_de_verdade` | `koter-proposta` e `koter-crm-lead` | a roteadora, para saber se o onboarding chegou ao fim |

`porte`: `solo`, `com_vendedores`, `assessoria`.
`prioridade`: `comissao`, `atendimento`.
Estado de etapa: `pendente`, `em_andamento`, `concluida`, `pulada`, `bloqueada` (com `motivo`, tipicamente falta de permissão).
Estado de pré-requisito: `pendente`, `feito`, `nao_se_aplica`, `dispensado` (ele disse que não quer).

`koter-crm-lead` e `koter-proposta` **não são etapas**: rodam sempre. Elas escrevem em `usou_de_verdade`, não em `etapas`.

### Idempotência

Reentrar numa skill já `concluida` não pode duplicar nada. Por isso toda skill filha **detecta antes de criar** e casa por nome normalizado (sem acento, caixa dobrada) — `create_origin` não deduplica e `create_lead_tag` só dedupe em nome literal. Gravar a etapa como `concluida` é registro do que aconteceu, nunca autorização para pular a releitura.

Grave depois de **cada** skill filha, nunca só no fim. Corretor fecha a janela no meio — e deve reabrir de onde parou.

## Se um dia o Koter guardar isso

Vale trocar: o objetivo é o plugin funcionar em qualquer IA, e estado que mora na máquina torna o plugin específico da máquina. O contrato acima já está desenhado para virar um par de chamadas de leitura e escrita sem mudar nenhuma skill filha.
