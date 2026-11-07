# Echos of Aethra

Action MMORPG **3D com visual de pixel art**, desenvolvido em Godot 4.7.2
(GDScript, Forward+). O 3D foi adotado como jogo oficial.

## Começar

- Abra `project.godot` no Godot e pressione F5.
  A cena principal é `src/game/pixel3d_demo.tscn`.
- No Windows: `powershell -NoProfile -File tools/run_game.ps1`.
- Testes: `powershell -NoProfile -File tools/test.ps1 -Suite unit`.
- Agentes (Codex, Antigravity, GPT ou Claude): comece por [AGENTS.md](AGENTS.md).
  Em chats sem acesso ao repositório, forneça esse arquivo e apenas as referências
  da tarefa; não envie o acervo inteiro.

## Onde trabalhar

| Área | Caminho |
|---|---|
| Jogo, interface, IA, combate e dados 3D | `src/game/` |
| Servidor e cliente online | `src/game/net/` |
| Inventário e utilitários compartilhados | `src/core/` |
| Módulo reutilizável de mundo | `src/world/`, `assets/world/`, `data/world/` |
| Catálogo, modelos e ícones de itens | `src/items/`, `assets/items/`, `assets/data/items.json` |
| Hospedagem (ainda depende de autorização) | `server/` |
| Tarefas e critérios de conclusão | [production/tasks.md](production/tasks.md) |

[Mapa de contexto](docs/context/index.md) · [Estado atual](docs/context/current-state.md) ·
[Execução e testes](docs/context/testing.md) · [Direção do jogo](design/game-brief.md)

O 2D e experimentos anteriores estão em `legacy/`, fora da importação do Godot.
O framework genérico de estúdio está arquivado em `tools/studio/`.
Esses diretórios não são necessários ao desenvolvimento cotidiano.
