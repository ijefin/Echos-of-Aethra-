# Jogo 3D

Execute `project.godot` ou `powershell -NoProfile -File tools/run_game.ps1`.
Este diretório é o jogo oficial; os nomes `pixel3d_*` identificam o estilo de
renderização, não um experimento descartável.

## Pontos de entrada

- `pixel3d_demo.tscn` / `.gd`: montagem do mundo, câmera, personagem, input e combate.
- `pixel3d_adventure.gd`: progressão, missões, economia e ligação com jogo online.
- `adventure_hud.gd`, `adventure_chat.gd`, `world_labels_overlay.gd`: interface.
- `ai/`, `world/`, `shaders/`, `data/`: subsistemas e parâmetros.
- `net/`: cliente/servidor autoritativo; infraestrutura em `server/` na raiz.
- `tools/`: testes e ferramentas existentes; não são dependências de runtime.

## QA e comandos

`--no_save --mute` para execução de QA. Opções úteis existentes:
`--class=mage|warrior|archer`, `--hour=H`, `--at=x,z`, `--zoom=N`,
`--shot=res://.scratch/qa.png --shot_delay=5`.

Online: `--connect=127.0.0.1:7777 --user=Nome --pass=senha --register`.
Detalhes e testes: `docs/context/testing.md` e `server/README.md` na raiz.

Saves e IDs mantêm os nomes anteriores para compatibilidade. Os registros extensos
de implementação e capturas anteriores estão em `docs/history/game-3d-notes-2026-11-06.md`;
consulte apenas para uma investigação histórica específica.
