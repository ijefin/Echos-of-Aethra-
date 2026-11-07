# Estado do jogo

Verificado na reorganização de 2026-11-06. Este documento registra fronteiras,
não duplica o catálogo de recursos nem funciona como diário de sessão.

- O jogo adotado é o 3D em `src/game/`; `project.godot` abre sua cena principal.
  Os nomes `pixel3d_*` foram mantidos para evitar renomeações sem ganho funcional.
- Existem jogo offline e cliente online. A rede autoritativa está em `src/game/net/`;
  a infraestrutura está em `server/`. Hospedagem externa continua sem autorização.
- O cenário jogável ainda é gerado pelo código do jogo. O módulo editável de regiões
  em `src/world/` existe, tem ADR e testes, mas sua adoção pelo cenário atual é
  trabalho futuro. Não apresentar essa integração como concluída.
- Inventário e utilitários em `src/core/` são código atual. O catálogo/pipeline de
  itens em `src/items/` é independente do cenário e preserva o formato compartilhado.
- Saves existentes mantêm nome de projeto `meu-mmorpg` e identificadores
  `pixel3d-*`; a reorganização não migra nem apaga dados de jogadores.
- Testes são scripts Godot `SceneTree`; gdUnit4 não é dependência instalada.
- O estilo 3D foi aprovado. Valores de tuning devem ser conferidos no código/dados
  do sistema, pois registros históricos podem refletir versões anteriores.

O 2D foi isolado em `legacy/2d/`; experimentos anteriores em `legacy/experiments/`.
Ambos ficam fora do importador e da contextualização rotineira.
O framework de estúdio original foi preservado em `tools/studio/` sem hooks,
skills ou agentes ativos no projeto principal. Consultá-lo é opcional.

Progresso e pendências concretas: `production/tasks.md`.
