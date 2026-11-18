# Segurança

## Como reportar

**Não abra issue pública para falha de segurança.** Use o reporte privado do GitHub: aba **Security** do repositório, **Report a vulnerability**. Se não conseguir, escreva para **suporte@koter.app** com o assunto "Segurança: plugin".

Inclua o que você encontrou, como reproduzir e o impacto que você vê. Respondemos pelo mesmo canal e combinamos com você a data de divulgação depois da correção.

## O que entra

- **Skill ou comando que leva a IA a um efeito indevido:** mandar mensagem a cliente sem aprovação, gravar ou apagar dado fora do pedido, expor dado de uma corretora a outra, ou passar por cima da permissão do cargo.
- **Dado sensível publicado neste repositório:** CPF, contato de cliente, credencial, token ou id de produção, inclusive no histórico.
- **Falha na conexão MCP ou no login OAuth do Koter** (`api.koter.app`) que você tenha encontrado usando o plugin. O plugin é só texto, mas o reporte chega ao mesmo time.

## O que não entra

- Comportamento da IA que você escolheu (Claude, ChatGPT, Grok) fora do que a skill instrui. Reporte ao fornecedor dela.
- Pedido de recurso ou erro de texto sem efeito de segurança. Use as issues normais.

## Versões cobertas

Só a versão mais recente da branch `main` recebe correção.
