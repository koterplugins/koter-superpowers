# Hospedeiros — a sonda de capacidade e os três caminhos

O plugin roda dentro da IA que o corretor escolheu, e **não dá para supor o que ela faz**. Uma cria arquivo de agente, outra tem Projetos, outra é um chat e nada mais. Este arquivo é o procedimento para descobrir isso sem perguntar o que ele não sabe responder, e o que entregar em cada caso.

**A regra que organiza tudo:** o corretor termina com os especialistas na mão nos três casos. O que muda é o suporte — arquivo, projeto ou texto —, nunca o conteúdo.

---

## A sonda, em três degraus

Desça os degraus na ordem. Pare no primeiro que responder.

### Degrau 1 · Você escreve arquivo?

Olhe as **suas próprias ferramentas**. Se não há nenhuma de escrever arquivo, o caminho A está fora e você desce sem tentar nada.

Se há, **teste escrevendo de verdade**, num caminho descartável, e releia. Permissão negada, disco só-leitura e sandbox sem projeto aberto são todos respostas legítimas — e todos levam ao degrau 3, sem drama e sem pedir desculpa.

### Degrau 2 · Que convenção existe aqui?

Procure, nesta ordem, na raiz do projeto aberto e no home:

| Caminho | Hospedeiro | Formato do arquivo |
|---|---|---|
| `.claude/agents/` | Claude Code | um `.md` por agente, com `name` e `description` no cabeçalho |
| `.claude/skills/` | Claude Code | uma pasta por skill, com `SKILL.md` dentro |
| `.cursor/rules/` | Cursor | um `.mdc` por regra, com `description` no cabeçalho |
| `.github/chatmodes/` | Copilot | um `.chatmode.md` por modo, com `description` no cabeçalho |
| `AGENTS.md` na raiz | convenção genérica | **arquivo único**: os especialistas viram seções, não arquivos |

**Pasta que existe manda.** Se houver mais de uma, use a que já tem conteúdo — é a que aquele corretor de fato usa. Se não houver nenhuma mas você escreve arquivo, **crie `.claude/agents/`**: é a convenção mais difundida e a que mais IAs leem.

> ⚠️ **Estas são as convenções conhecidas quando esta skill foi escrita, e nenhuma foi medida em campo.** Convenção nova aparece o tempo todo. Se você **sabe** que o seu hospedeiro usa outro caminho, use o dele — esta tabela é ponto de partida, não contrato. Se não sabe, não invente: desça para o degrau 3.

### Degrau 3 · Aí sim, uma pergunta — e só uma

Só aqui, e em escolha fechada, porque agora a resposta depende de algo que **só ele vê na tela dele**:

> "Sua IA tem 'Projetos', 'GPTs' ou 'Gems' — um lugar onde você guarda instruções fixas e abre conversas dentro?"
>
> - **Tem, e eu sei usar** → eu te dou o texto de cada especialista, um por vez, e você cola
> - **Tem, mas nunca usei** → eu te dou o texto e digo onde colar, passo a passo ← *recomendado*
> - **Não tem, é só conversa** → eu te dou os textos para você guardar e colar quando precisar

As duas primeiras são o caminho B. A terceira é o C.

---

## Caminho A · Agente de arquivo

Um arquivo por especialista, nomeado `koter-<assunto>` — `koter-financeiro`, `koter-cadastro`, `koter-vendas`, `koter-crm`, `koter-atendimento`, `koter-secretario`, `koter-implantacao`. O prefixo evita colisão com o que ele já tiver.

O molde, no formato de cabeçalho do hospedeiro detectado:

```
---
name: koter-financeiro
description: Comissão, repasse, baixa de parcela, caixa e DRE da corretora no Koter. Use quando o assunto for quanto entrou, quanto eu devo, fechamento do mês, extrato, empréstimo a vendedor ou campanha.
---

Você é o Especialista Financeiro do Koter, dentro da corretora de <nome>.

[campos 2 a 8 da ficha, na ordem do molde, com os títulos]
```

Três coisas que fazem a diferença entre um agente que dispara e um que fica esquecido:

1. **A `description` é o que faz a IA escolher esse agente.** Escreva-a com as palavras do corretor — "quanto eu devo", "fechamento do mês" —, não com o vocabulário do Koter. É a mesma regra das 22 skills do plugin.
2. **As skills vão pelo nome literal.** `koter-gestao-repasse`, não "a skill de repasse". O agente precisa conseguir carregá-la.
3. **O campo 8 vai inteiro em cada arquivo.** Referência cruzada entre agentes não sobrevive: cada um é lido sozinho.

**Depois de escrever, releia cada arquivo** e confira que os nove campos estão lá. Só então diga que existe, e diga o caminho completo:

> "Criei cinco, em `.claude/agents/`: `koter-cadastro.md`, `koter-vendas.md`, `koter-financeiro.md`, `koter-crm.md` e `koter-atendimento.md`. Abra o de vendas e escreva 'entrou um lead, Maria, 11 99000-0000, veio do Instagram'."

---

## Caminho B · Projeto na IA

Você não escreve no projeto dele — **ele cola**. Então o texto precisa ser colável: sem cabeçalho de YAML, sem marcação que só faça sentido em arquivo, e curto o bastante para caber no campo de instruções de um projeto.

**Um por vez.** Seis blocos de texto seguidos garantem que ele cole zero.

O formato, para cada especialista:

```
Você é o Especialista <nome> do Koter, na corretora <nome da corretora>.

Quando me chamar: <campo 1>

Skills do plugin Koter que eu carrego: <campo 2, nomes literais>

O que eu posso: <campo 3>

O que eu não posso, e quem faz: <campo 4 + as linhas de encaminhamento dos outros>

Pré-requisito que só você resolve: <campo 5>

As armadilhas do meu assunto: <campo 6>

Por onde eu começo: <campo 7>

As regras que eu herdo: <campo 8, inteiro>
```

E a instrução de onde colar, dita na língua da tela dele:

> "Cria um projeto chamado 'Financeiro Koter' e cola isso no campo de instruções. Toda conversa que você abrir dentro dele já começa sabendo. Me avisa quando colar que eu te mando o próximo."

**Confirme um por um.** Só mande o seguinte quando ele disser que o anterior está lá — e se ele parar no terceiro, pare também: três especialistas usados valem mais que seis colados pela metade.

---

## Caminho C · O especialista de bolso

Sem projeto e sem arquivo, o especialista é **o primeiro parágrafo de uma conversa nova**. Funciona igual: o que faz o especialista é o texto, não o suporte.

Duas entregas, nesta ordem:

**1 · Os textos, em blocos copiáveis.** O mesmo formato do caminho B, e diga onde guardar com palavras dele — notas do celular, arquivo no WhatsApp salvo, bloco de notas. Um por vez, como no B.

**2 · O modo vestido, aqui e agora.** Esta é a parte que só o caminho C tem, e é o que o torna útil imediatamente: nesta mesma conversa, **você passa a operar como um especialista por vez**, e diz em voz alta qual está ativo.

> "Agora estou no modo financeiro: comissão, repasse e caixa. Se você quiser falar de lead, é só dizer 'muda para vendas' que eu troco."

Duas travas que fazem o modo vestido não virar bagunça:

- **Diga a troca sempre**, na hora em que ela acontece. Especialista silencioso é só o assistente de sempre com outro nome.
- **Carregue as travas junto.** Vestir o financeiro e mexer no funil porque o corretor pediu de passagem desfaz a única coisa que a separação comprava.

---

## Quando a criação falha no meio

Acontece: três arquivos escritos e o quarto dá erro de permissão. **Não recomece e não pergunte o que fazer.**

1. Diga o que ficou pronto, com o caminho.
2. Entregue os que faltam **pelo caminho B ou C**, no mesmo fôlego.
3. Grave no estado o que de fato existe, com o `caminho` de cada um.

> "Três ficaram em arquivo. O de CRM e o de atendimento a pasta não deixou escrever, então vão como texto — cola no seu projeto ou guarda nas notas, funciona igual."

O corretor não tem como decidir isso melhor que você, e perguntar só transfere o problema.

---

## O que esta página não sabe

- **Nenhuma sonda foi medida em campo.** Os caminhos e formatos acima são as convenções conhecidas no momento da escrita. Um hospedeiro com convenção diferente cai em B ou C — que é o comportamento seguro, e por isso a sonda foi desenhada para falhar para baixo.
- **O campo de instruções de projeto tem limite de tamanho em algumas IAs**, e o limite não é o mesmo em todas. Se o texto não couber, corte primeiro o campo 6 (armadilhas) para as **três** mais caras do assunto — nunca o campo 4 nem o 8, que são as travas.
- **O modo vestido do caminho C não sobrevive a uma conversa nova.** É por isso que a entrega 1 vem antes da 2: o texto guardado é o que persiste.
