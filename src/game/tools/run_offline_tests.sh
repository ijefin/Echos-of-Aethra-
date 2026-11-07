#!/usr/bin/env bash
# Roda os testes offline do protótipo e mostra só o resumo de cada um.
# bash src/game/tools/run_offline_tests.sh [teste ...]
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/../../.."
TESTS="${*:-shop equip gear_look quests world_reach vocations mage_combat floors day_night core_light enemy_ai}"
BAD=0
for t in $TESTS; do
	OUT="$("$G" --headless --path . -s res://src/game/tools/test_$t.gd -- --no_save --mute 2>&1)"
	CODE=$?
	P=$(echo "$OUT" | grep -cE "^PASS|CHECK PASS|: OK")
	F=$(echo "$OUT" | grep -cE "^FAIL|CHECK FAIL|FALHOU|: FAIL")
	E=$(echo "$OUT" | grep -cE "SCRIPT ERROR|Parse Error")
	echo "test_$t: exit $CODE, $P PASS, $F FAIL, $E erros"
	if [ "$CODE" -ne 0 ] || [ "$F" -gt 0 ] || [ "$E" -gt 0 ]; then
		BAD=1
		echo "$OUT" | grep -E "FAIL|FALHOU|SCRIPT ERROR|Parse Error" | head -10
	fi
done
exit $BAD
