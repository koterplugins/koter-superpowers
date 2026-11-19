---
description: Cota seguro auto de pessoa física no Koter e entrega o comparativo e o texto para você mandar ao cliente.
---

Use a skill `koter-multicalculo-auto` do plugin Koter.

Argumentos (opcionais): $ARGUMENTS

- Sem argumentos: comece por `cotacao_auto_get_auto_insurer_availability` e peça os dados em bloco, uma vez.
- Pedido solto (ex.: `cota o gol do joão`): trate como início da cotação. Use o que veio e peça só o que falta.
- `ver`: retome a cotação em andamento com `cotacao_auto_list_auto_quotes`, sem criar outra.
- Nome de um cliente com cotação já feita (ex.: `recotar joão`): procure a cotação dele e use recotação, sem criar outra.

Só dispare depois de mostrar o espelho e ouvir um sim claro. Este agente fala com o corretor, nunca com o segurado.
