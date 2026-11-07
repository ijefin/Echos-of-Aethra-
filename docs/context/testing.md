# Executar e verificar

Godot 4.7.2; caminho local em `project.yaml` (`engine.path`). Os scripts Windows
aceitam `-Godot <executável>` para outra instalação. Não é necessário gdUnit4.
Em um clone novo, abra o editor para importar os recursos ou execute uma vez
`godot --headless --editor --path . --import` antes dos testes.

## Jogo

```powershell
powershell -NoProfile -File tools/run_game.ps1
powershell -NoProfile -File tools/run_game.ps1 -Qa
```

Com Godot no PATH: `godot --path .`.
Use `--no_save --mute` em QA para não alterar saves e não emitir áudio.
Captura gráfica: `godot --path . -- --no_save --mute --shot=res://.scratch/qa.png --shot_delay=5`.
Abra a imagem produzida; executar a captura não equivale a inspecioná-la.

## Suítes

```powershell
powershell -NoProfile -File tools/test.ps1 -Suite unit
powershell -NoProfile -File tools/test.ps1 -Suite offline
powershell -NoProfile -File tools/test.ps1 -Suite world
powershell -NoProfile -File tools/test.ps1 -Suite network
powershell -NoProfile -File tools/test.ps1 -Suite all
python tools/check_structure.py
```

| Suíte | Cobertura |
|---|---|
| `unit` | `tests/unit/**/*_test.gd`, exceto `icon_baker_test.gd` (exige renderizador) |
| `offline` | 11 testes existentes em `src/game/tools/test_*.gd`, relacionados ao jogo offline |
| `world` | testes unitários de mundo + `tests/integration/world/world_module_test.gd` |
| `network` | integração com servidor local, dois clientes e reinício/persistência (`tools/net_session_test.ps1`) |
| `all` | unit + offline + integração de mundo + network; não inclui testes gráficos |

Saída 0 com ausência de falhas/erros de script é necessária. O runner mantém logs
em `.scratch/test-results/`, impõe timeout e retorna código diferente de zero em falha.
Para um teste isolado: `godot --headless --path . -s res://tests/unit/net/net_rules_test.gd`.

Testes gráficos separados (sem `--headless`):
- `godot --path . -s res://tests/unit/items/icon_baker_test.gd`
- `godot --path . -s res://tests/integration/first_adventure_playthrough.gd -- --no_save --mute`

Helpers Bash existentes continuam disponíveis em `tests/`, `src/game/tools/`
e `tools/net_*`. Não execute todos em uma correção pequena: selecione pela dependência.

## Servidor e exportação

Servidor local: `godot --headless --path . -s res://src/game/net/server_main.gd`.
Cliente: `godot --path . -- --connect=127.0.0.1:7777 --user=Nome --pass=senha --register`.
Consulte `server/README.md` antes de operações online. Não inclua credenciais reais
em tarefas, logs compartilhados ou comandos versionados.

Build Windows: `powershell -NoProfile -File tools/build_windows.ps1`.
Exportar localmente não autoriza publicar nem alterar a VPS.
