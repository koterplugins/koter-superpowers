# Grok Bot: como os times são montados

Leia isto quando o corretor usar ou quiser usar Grok Bot. Base: páginas lidas em 03/11/2026, parte por resumo. **Ninguém conectou o Koter ao Grok Bot para escrever este texto.** Links em `fontes.md`.

## Antes de pôr dado real de segurado

Quatro fatos, ditos sem julgamento:

- O trabalho roda num computador na nuvem, nos Estados Unidos. Não há opção local.
- Nas páginas lidas não há confirmação oficial de disponibilidade no Brasil.
- App conectado vale para a conta inteira, para todos os Bots.
- Separar Bots não isola nada: todos os seus Bots dividem o mesmo computador, arquivos, sessões e credenciais.

Peça ao corretor que confirme disponibilidade e regra de dados antes de pôr dado real de segurado. LGPD não foi analisada aqui: isso é com o jurídico dele.

## Não existe ranking de "maior sucesso"

"Maior sucesso" aqui quer dizer "mais documentado". **Nenhum resultado abaixo tem auditoria.**

| Tipo de relato | Quem | O que vale | O que não vale |
|---|---|---|---|
| Fabricante falando de si | Suporte do fabricante: engatinhar, andar, correr. Só nota interna no começo, pessoa aprovando toda escrita, escopo crescendo aos poucos | O desenho | Os números, que são declaração sobre si |
| Fabricante falando de si | Vendas do fabricante: Bots individuais primeiro, de time depois. O Quote Bot mostra prévia antes de gravar, e ninguém aprova o próprio desconto | O desenho. É o análogo direto do multicálculo | Não tem métrica |
| Guias do fabricante | Pós-venda, SDR, vendas de fundador, jurídico, marketing, suporte | Padrões de montagem | São marketing, e o guia de suporte avisa que seus números são ilustrativos |
| Cliente na página do fabricante | Harper, corretora dos EUA: Team Bot feito em 24 horas para achar apólice caducada e ajudar a reativar | É a única corretora com caso público em Grok Bot, e a identidade da empresa bate com a imprensa | O ganho declarado não tem cálculo explicado nem auditoria |
| Pessoas de fora, em blog ou fórum | Relatos de uso com vários Bots | Alertas úteis. Um Bot de geração de leads não produziu nada na primeira semana. Outro abordou cerca de 40 fornecedores, sem venda fechada, com alto consumo | Amostra pequena e sem conferência |
| **Verificado por terceiro** | **Nenhum caso com resultado verificado** | | |

## Bot primário: padrão de uso, não recurso

O termo oficial é **Bot primário**: seu contato principal, que faz check-ins e coordena os outros. "Chief of Staff" e "coordenador" são padrões de uso, não recurso do produto. Modelo com esse nome costuma ser criado por terceiro: trate como software desconhecido.

- Você escolhe ou cria um Bot primário, e pode trocar depois. Bot compartilhado não pode ser primário.
- Grupos vão de 2 a 6 Bots, e a recomendação oficial é **um dono por etapa**.
- Conversa entre Bots consome uso, e não há botão para desligar.
- **Em grupo não aparecem cartões de aprovação, pedidos de senha nem rascunhos de e-mail.** Se a aprovação importa, a ação fica fora do grupo.

Quando entra o coordenador é ponto de divergência: um relato de fora manda começar por ele, um guia do fabricante manda adicionar quando a passagem de bastão pesar, e a documentação manda começar com um Bot dono de um resultado. Nossa leitura para corretor: prove um fluxo, e o coordenador entra com dois ou três. Em um guia do fabricante, um funcionário tentou tocar cerca de 20 Bots sozinho, sobrecarregou e consolidou tudo em uma porta só.

## Como os times documentados foram criados

Caminho da documentação oficial, mais o que os guias repetem:

1. Crie um Bot e descreva a função em termos operacionais: o que cuida, que dados olha, o que produz e o que nunca faz sem aprovação.
2. Dê uma tarefa concreta com fim claro.
3. Refine até a saída poder ser revisada sem você.
4. Salve como skill e teste num segundo caso.
5. Só então crie uma rotina, com falha e nova tentativa definidas.
6. Ações externas ficam atrás de aprovação.
7. Crie outro Bot quando o trabalho tiver objetivo, ferramentas, regra de aprovação ou horário próprios.

Pedido bem feito, pela fórmula oficial: resultado, fontes, restrições, entregável e pontos de parada.

## Memória

- É por Bot. O Bot decide sozinho o que salvar e nem sempre avisa. Para garantir, peça.
- Não há tela: você pergunta no chat, corrige ou pede para esquecer.
- **Memória não é autoridade.** Decisão importante confere a fonte atual, e regra de segurança se impõe com aprovação, não com memória.
- A revisão automática de segurança não cobre gravação de memória. Quem revisa é você.
- "Memória compartilhada do time" aparece em guias de terceiros. Na documentação, conhecimento de equipe só existe em Bot compartilhado.

No corretor: memória guarda preferência, nunca CPF, apólice ou valor. Uma vez por mês: "liste o que você guardou sobre meus clientes".

## Skills

- Skill é instrução reutilizável: quando usar, entradas, passos, como checar, o que devolver, o que exige aprovação.
- Crie pedindo ao Bot para salvar um processo já concluído.
- A skill precisa estar habilitada no Bot. "O Bot não acha a skill" costuma ser isso.
- Modelo compartilhado não leva servidor MCP personalizado: quem recebe precisa reconectar.

## Rotinas

- Disparam por horário ou evento, incluindo webhook.
- Antes de criar, confirme: Bot dono, horário e fuso, fonte de entrada, resultado esperado, limite de aprovação e o que fazer se a fonte faltar.
- **Test roda agora e faz trabalho real.**
- Cartão de aprovação de atividade em segundo plano expira em cerca de 30 minutos, e a ação não roda.

No corretor: rotina só lê e entrega a você. Primeira linha confere se o Koter respondeu. Nasce pausada. É a receita de abertura do dia.

## O que vale para o corretor

- Um Bot, um trabalho, um indicador, um ponto de parada.
- Baldes em vez de prosa: COTAR, FALTA DADO, HUMANO.
- Rascunho primeiro. Nada sai para cliente sem você.
- Compare rascunho com o que você enviou.
- Lista curta e silêncio quando não há novidade.
- Um Bot com tarefa curta antes de um grupo com tarefa vaga.

## O que não dá para isolar

| Você quer | Realidade |
|---|---|
| Um Bot sem acesso ao Koter | App conectado vale para todos os Bots da conta |
| Um Bot que só lê | Conexão do Koter nasce com escrita. Use regra **Ask first** para as escritas, e confira |
| Arquivos separados por Bot | Computador é um por usuário |
| Dividir a equipe com um Bot compartilhado | Apps e segredos do dono funcionam para os colegas no chat. Cada vendedor conecta o próprio Koter |
| Rastro de quem fez | Registro de auditoria é do plano Enterprise, e o Bot age como a pessoa logada |
| Página para o cliente ver | Link compartilhado fica público, sem login. Nunca publique carteira |

Regra de segurança não mora no texto do Bot. Use **Ask first** para o que alcança cliente, e dê atenção às portas de automação e chatbot da T11.

## Confirmado e o que falta

| Item | Situação |
|---|---|
| Grok Bot aceita servidor MCP remoto por URL | Confirmado na documentação oficial, não testado com o Koter |
| App conectado vale para a conta inteira | Confirmado na documentação oficial |
| Login do Koter por OAuth, com registro automático de cliente | Lido no código do Koter em 03/11/2026, não executado |
| Koter conclui a conexão no Grok Bot | **Falta testar** |
| Todos os Bots da conta enxergam o Koter na prática | **Falta testar**. A documentação indica que sim |
| Conector criado em `grok.com/connectors` aparece no Bot | **Falta testar**. As fontes divergem |
| Plugin funciona igual, e o que acontece com hooks | **Falta testar**. Só há afirmação de fornecedor |
| Automação do Koter disparando rotina por webhook | Existe `SEND_WEBHOOK` nas automações, com endpoint cadastrado fora da conexão. **Falta testar**, e o conteúdo vai para a nuvem do Bot |
| Disponibilidade no Brasil | **Sem confirmação oficial** nas páginas lidas |
| LGPD e dado de segurado | **Não analisado** |
| Plano | Grok Bot entra nos planos Premium, Super e Ultra, não em Plus nem Free. Team Bots estão em beta nos planos Teams e Enterprise. Confira na hora de assinar |
