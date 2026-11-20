# Plugin Koter

**Configure e toque a sua corretora conversando com a sua IA.**

[![Licença Apache 2.0](https://img.shields.io/badge/licen%C3%A7a-Apache%202.0-blue.svg)](LICENSE) [![Versão](https://img.shields.io/github/v/tag/koterplugins/koter-superpowers?sort=semver&label=vers%C3%A3o&color=informational)](CHANGELOG.md) [![Koter](https://img.shields.io/badge/Koter-koter.app-0a7cff.svg)](https://koter.app/ia)

[Koter](https://koter.app) é a plataforma de CRM e gestão para corretoras de seguros no Brasil, e este é o plugin oficial. São 30 skills e 5 comandos que, pela conexão MCP do Koter, configuram a corretora com você e tocam o dia a dia: configuração guiada, multicálculo auto, comissão, CRM, KoterZap e agentes especialistas.

**O guia completo está em [`plugins/koter/README.md`](plugins/koter/README.md)**: os comandos, a segurança, que dados saem e para onde e os especialistas. Ele abre com um resumo em inglês.

## Use na sua IA

| Sua IA | Conexão | Skills |
|---|---|---|
| **Claude** (planos pagos: claude.ai, Desktop, Cowork) | Vem com o plugin | Customizar > Plugins > adicionar o marketplace `koterplugins/koter-superpowers` e instalar `koter`. Quando o Koter for publicado no diretório de plugins do Claude, dá para instalar por lá também |
| **Claude Code** | Vem com o plugin | `/plugin marketplace add koterplugins/koter-superpowers` e depois `/plugin install koter@koter` |
| **Claude Free** | Customizar > Conectores > Adicionar conector personalizado, com a URL abaixo | Uma skill avulsa (a pasta dela, com o `SKILL.md`) em Customizar > Skills |
| **ChatGPT** | Vem com o pacote. Sem ele: em chatgpt.com/plugins, botão **+** > Add custom MCP server, com a URL abaixo, no ChatGPT web e nos planos que liberam servidor MCP próprio | O pacote `koter-openai-x.y.z.zip` da [release](https://github.com/koterplugins/koter-superpowers/releases/latest), enviado em Plugins por quem tem permissão de enviar plugin. Nos planos com Skills, uma skill avulsa sobe em Skills > Create > Upload from your computer |
| **Grok** (inclusive o gratuito) | Configurações > Connect Apps > Add a custom connector, com um nome e a URL abaixo | Configurações > **Habilidades** > **Nova Habilidade**, com o pacote `koter-grok-x.y.z.zip` da [release](https://github.com/koterplugins/koter-superpowers/releases/latest) |
| **Outras IAs com MCP** (Cursor e outras) | Servidor MCP remoto com a URL abaixo | Os `SKILL.md` de [`plugins/koter/skills/`](plugins/koter/skills) como instruções, no recurso de regras ou de skills da IA |

No Claude, no Claude Code e com o pacote do ChatGPT, as skills e a conexão vêm juntas. Nas outras IAs, a conexão usa esta URL:

```
https://api.koter.app/mcp-user/koter
```

O passo a passo do Grok, com os dois jeitos de criar a habilidade, está no [guia do plugin](plugins/koter/README.md). O Grok grava e exclui sem pedir confirmação: peça sempre que ele mostre o que vai gravar antes.

No primeiro uso, entre com o seu login do Koter e digite `/introducao`.

## O que há neste repositório

| Caminho | O que é |
|---|---|
| [`plugins/koter/`](plugins/koter) | O plugin: skills, comandos, a conexão MCP e o ícone |
| [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) | O marketplace `koter`, que aponta para o plugin |
| [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md) | Como as skills se organizam, para quem vai escrever ou revisar |
| `scripts/` e `.github/` | Os pacotes do ChatGPT e do Grok, as checagens do CI e as releases |

## Contribuir, segurança e licença

- **Contribuir:** [CONTRIBUTING.md](CONTRIBUTING.md). Quem participa segue o [Código de conduta](CODE_OF_CONDUCT.md).
- **Falha de segurança:** em privado, pelo [SECURITY.md](SECURITY.md). Nunca em issue pública.
- **O que mudou em cada versão:** [CHANGELOG.md](CHANGELOG.md).
- **Licença:** Apache 2.0, veja [LICENSE](LICENSE) e [NOTICE](NOTICE). A licença não inclui a marca: "Koter", "KoterZap" e o logo seguem o [TRADEMARKS.md](TRADEMARKS.md).
