#!/usr/bin/env bash
# Gera os ícones da bolsa a partir dos modelos 3D e liga o campo "icon" em items.json.
#   bash tools/bake_item_icons.sh                 # tudo (itens + vitrine de modelos)
#   bash tools/bake_item_icons.sh --missing       # só o que ainda não tem PNG
#   bash tools/bake_item_icons.sh --items axe_1h  # só esses itens
# Precisa de janela (abre o Godot por alguns segundos). Ver docs/items/item-pipeline.md.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
"$G" --headless --path "$ROOT" --import > /dev/null 2>&1   # modelos/classes novos
"$G" --path "$ROOT" -s res://src/items/tools/bake_item_icons.gd -- "$@" 2>&1 | grep -E "bake_item_icons|ERROR|SCRIPT ERROR"
rc=${PIPESTATUS[0]}
python "$ROOT/tools/items/sync_icon_fields.py" "$ROOT" || rc=1
"$G" --headless --path "$ROOT" --import > /dev/null 2>&1   # importa os PNGs gerados
exit $rc
