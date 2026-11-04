#!/bin/bash
# Roda os testes do módulo de itens. Uso: GODOT=/caminho/godot bash tests/run_item_tests.sh
cd "$(dirname "$0")/.."
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
rc=0
for t in tests/unit/items/*_test.gd; do
	out=$("$G" --headless --path . -s "res://$t" 2>&1)
	code=$?
	echo "$out" | grep -E "FALHOU|: OK|SCRIPT ERROR|Parse Error"
	[ $code -ne 0 ] && { echo "FALHOU: $t"; rc=1; }
done
exit $rc
