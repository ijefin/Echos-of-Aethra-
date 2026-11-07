#!/usr/bin/env bash
# Roda os testes headless do protótipo (mundo + regressões). Uso: bash src/game/tools/run_world_tests.sh
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/../../.."
for t in ${@:-test_world_reach test_mage_combat test_floors test_day_night test_core_light}; do
	echo "== $t"
	"$G" --headless --path . -s "res://src/game/tools/$t.gd" -- --no_save --mute 2>&1 | grep -E "PASS|FAIL|OK|FALH|SCRIPT ERROR|Parse Error|grade|áreas|árvores|frame|fps|FPS" | tail -40
done
