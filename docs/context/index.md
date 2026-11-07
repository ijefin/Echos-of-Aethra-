# Mapa do jogo 3D

Leia a linha da tarefa, depois os símbolos e seções pertinentes. Não é uma lista
de leitura obrigatória. `AGENTS.md` contém as instruções comuns aos agentes.

| Tarefa | Código/dados | Referência e verificação |
|---|---|---|
| Inicialização, câmera, input | `src/game/pixel3d_demo.gd` | `src/game/README.md`, execução gráfica |
| Combate e vocações | `src/game/vocations.gd`, `data/classes.json`, `ai/` dentro de `src/game/` | testes offline `mage_combat`, `vocations`, `enemy_ai` |
| Missões, progressão e economia | `src/game/pixel3d_adventure.gd`, `first_adventure_state.gd`, `quests.gd`, `economy.gd`, `src/game/data/` | testes de primeira aventura, `quests`, `shop`, `equip` |
| Interface | `src/game/adventure_hud.gd`, `adventure_chat.gd`, `world_labels_overlay.gd` | screenshot inspecionado; validar fluxo afetado |
| Rede, autoridade, persistência, troca | `src/game/net/`, `tests/unit/net/`, `tools/net_*` | `server/README.md`, integração local de rede |
| Cenário atual e colisão online | `src/game/world/`, `pixel3d_*.gd`, `net/tools/export_collision.gd` | testes `world_reach`, `floors`, `tests/unit/net/collision_export_test.gd` |
| Módulo reutilizável de mundo | `src/world/`, `assets/world/`, `data/world/` | ADR-0001, `docs/world/`, testes unitários e integração de mundo |
| Inventário e catálogo de itens | `src/core/inventory.gd`, `src/items/`, `assets/data/items.json` | `docs/items/item-pipeline.md`, testes de inventário/itens e consumidores online |
| Modelos e ícones | `assets/items/item_models.json`, `src/items/tools/`, `tools/items/` | `docs/items/item-pipeline.md`, teste gráfico `icon_baker_test.gd` |
| Visual, luz, shaders | `src/game/shaders/`, `pixel3d_sky.gd`, gerador afetado | `design/art/pixel3d-style-guide.md`, captura antes/depois |

- Comandos e suítes: `testing.md`. Limites de integração: `current-state.md`.
- Perfis por domínio: `agents.md`; só consultar o necessário.
- Referência de engine: `docs/engine-reference/godot/modules/<domínio>.md`, sob demanda.
- `docs/history/`, `legacy/` e `tools/studio/`: somente pesquisa histórica explícita.
