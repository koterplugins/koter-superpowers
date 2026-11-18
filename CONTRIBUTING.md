# Como contribuir

Obrigado por querer melhorar o plugin do Koter. Este repositório é só texto: skills, comandos e manifestos. Quem executa é a IA do corretor, pela conexão MCP do Koter. Por isso, **uma frase errada aqui vira uma ação errada na corretora de alguém**, e a régua de revisão é alta.

## Antes de abrir uma PR

- **Skill desatualizada ou errada:** abra uma issue com o modelo "Skill diverge do Koter". Diga a skill, a frase e o que o Koter respondeu de fato.
- **Falha de segurança:** não abra issue pública. Siga o [SECURITY.md](SECURITY.md).
- **Mudança grande** (skill nova, mudar o fluxo da `/introducao`, regra que vale para todas as skills): abra uma issue antes, para combinar o desenho.

## Regras de conteúdo

1. **Toda afirmação sobre o Koter é conferida.** Nome de ferramenta, parâmetro, valor de enum, limite, mensagem de erro e efeito, sempre contra a conexão real ou o código do Koter, e nunca deduzidos pelo nome. O que não deu para conferir não entra.
2. **O que alcança o cliente final é dito, sempre.** Mensagem de WhatsApp, e-mail, convite de agenda, chatbot ligado e webhook entram na porta de cuidado da skill e em "Precisa de aprovação".
3. **Nada de dado real.** Sem CPF, CNPJ, telefone, e-mail, nome de cliente ou de corretora real, nem id de registro de produção. Use exemplos fictícios, como `(11) 99000-0000`.
4. **Nada de detalhe interno do Koter.** Sem caminho de arquivo, nome de classe ou linha de código. A skill descreve o comportamento que a conexão mostra.
5. **Na descrição da PR, diga como cada afirmação nova foi conferida**; isso não vai para o texto da skill.
6. **Mesmo estilo das skills que existem:** português do Brasil, frases curtas, tabelas para opção e limite, uma pergunta por vez com 2 a 4 escolhas. O contrato de toda skill filha e as seis regras estão na [arquitetura do plugin](docs/ARQUITETURA.md).

## Como testar localmente

No Claude Code, aponte para a sua cópia do repositório:

```
/plugin marketplace add /caminho/para/koter-superpowers
/plugin install koter@koter
```

Conecte o Koter (`https://api.koter.app/mcp-user/koter`) com uma conta de teste e rode a skill que você mudou. **Nunca teste escrita numa corretora com cliente de verdade.**

## Commits e PRs

Os commits seguem o [Conventional Commits](https://www.conventionalcommits.org/pt-br/v1.0.0/), em inglês:

```
<tipo>(<escopo>): <resumo no imperativo, minúsculo, sem ponto final>
```

| Tipo | Quando |
|---|---|
| `fix` | A skill dizia algo errado sobre o Koter |
| `feat` | Skill, comando ou seção nova |
| `docs` | README, guias e textos que não mudam o comportamento da IA |
| `refactor` | Reorganizar skill sem mudar o que ela faz |
| `chore` | Manifesto, CI, modelos do GitHub |

O escopo é o nome da skill sem o prefixo (`crm-lead`, `gestao-comissoes`, `multicalculo-auto`), ou a área (`skills`, `readme`, `plugin`, `github`), quando a mudança cruza várias. Exemplos:

```
fix(crm-lead): say that task actions message the customer
feat(formularios): add the capture form skill
docs(readme): add the English summary
```

Uma PR por assunto. Na descrição, diga o que mudou, como foi conferido (conexão ou código, e a data) e o que ficou sem verificar. A PR atualiza o [CHANGELOG](CHANGELOG.md) em `Unreleased`.

## Código de conduta

Quem participa segue o [Código de conduta](CODE_OF_CONDUCT.md).

## Licença

Ao contribuir, a sua contribuição sai sob a [licença Apache 2.0](LICENSE) do projeto (seção 5). A marca Koter segue o [TRADEMARKS.md](TRADEMARKS.md).
