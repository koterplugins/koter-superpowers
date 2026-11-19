# Plugin Koter

**Configure e toque a sua corretora conversando com a sua IA.**

[![Licença Apache 2.0](https://img.shields.io/badge/licen%C3%A7a-Apache%202.0-blue.svg)](LICENSE) [![Versão](https://img.shields.io/github/v/tag/koterplugins/koter-superpowers?sort=semver&label=vers%C3%A3o&color=informational)](CHANGELOG.md) [![Koter](https://img.shields.io/badge/Koter-koter.app-0a7cff.svg)](https://koter.app/ia)

[Koter](https://koter.app) é a plataforma de CRM e gestão para corretoras de seguros no Brasil, e este é o plugin oficial. São 30 skills e 5 comandos que, pela conexão MCP do Koter, configuram a corretora com você e tocam o dia a dia: configuração guiada, multicálculo auto, comissão, CRM, KoterZap e agentes especialistas.

**O guia completo está em [`plugins/koter/README.md`](plugins/koter/README.md)**: os comandos, a segurança, que dados saem e para onde e os especialistas. Ele abre com um resumo em inglês.

## Instalação

| Sua IA | Como |
|---|---|
| **Claude** (planos pagos: claude.ai, Desktop, Cowork) | Customizar > Plugins > adicionar o marketplace `koterplugins/koter-superpowers` e instalar `koter` |
| **Claude Code** | `/plugin marketplace add koterplugins/koter-superpowers` e depois `/plugin install koter@koter` |
| **Claude Free** | Não instala plugin. Adicione a conexão em Customizar > Conectores > Adicionar conector personalizado, com a URL abaixo |
| **ChatGPT** | Configurações > Conectores, com o modo de desenvolvedor, nos planos que liberam conector próprio, e cole a URL abaixo. O pacote com as skills está na [release](https://github.com/koterplugins/koter-superpowers/releases) de cada versão |
| **Grok** | grok.com/connectors > New Connector > Custom, e cole a URL abaixo. O Grok não tem skills |

No Claude e no Claude Code, o plugin traz as skills e a conexão juntas. Nas outras IAs, é uma conexão só, com esta URL:

```
https://api.koter.app/mcp-user/koter
```

No primeiro uso, entre com o seu login do Koter e digite `/introducao`.

## O que há neste repositório

| Caminho | O que é |
|---|---|
| [`plugins/koter/`](plugins/koter) | O plugin: skills, comandos, a conexão MCP e o ícone |
| [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) | O marketplace `koter`, que aponta para o plugin |
| [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) | Como as skills se organizam, para quem vai escrever ou revisar |
| `scripts/` e `.github/` | O pacote do ChatGPT, as checagens do CI e as releases |

## Contribuir, segurança e licença

- **Contribuir:** [CONTRIBUTING.md](CONTRIBUTING.md). Quem participa segue o [Código de conduta](CODE_OF_CONDUCT.md).
- **Falha de segurança:** em privado, pelo [SECURITY.md](SECURITY.md). Nunca em issue pública.
- **O que mudou em cada versão:** [CHANGELOG.md](CHANGELOG.md).
- **Licença:** Apache 2.0, veja [LICENSE](LICENSE) e [NOTICE](NOTICE). A licença não inclui a marca: "Koter", "KoterZap" e o logo seguem o [TRADEMARKS.md](TRADEMARKS.md).
