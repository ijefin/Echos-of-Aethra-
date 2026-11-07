# Framework de estúdio — snapshot opcional

Preserva os 49 agentes, 74 skills, regras, scripts, hooks, testes e documentos do
framework original. Não é carregado pelo projeto principal. `.gdignore` impede
que scripts de testes e ferramentas deste snapshot entrem no importador do jogo.

O jogo usa `AGENTS.md` na raiz e `docs/context/`. Para especialização, consulte
somente a seção técnica de um perfil em `.claude/agents/`, quando necessário.

Os arquivos aqui mantêm convenções, caminhos e protocolos históricos. Não execute
hooks ou workflows apontando-os para o projeto principal sem adaptação e revisão.
Não restaure todo o framework para resolver uma tarefa localizada.

`README-framework.md` e `CLAUDE-framework.md` preservam as entradas antigas.
`studio-tests/` testa o framework original, não o jogo. Sua adaptação é opcional e
separada das suítes atuais em `tests/` e `src/game/tools/`.
