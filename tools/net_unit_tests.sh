#!/usr/bin/env bash
# Roda todos os testes unitários da rede (tests/unit/net/*_test.gd) e mostra a linha final de cada um.
#   GODOT=/caminho/godot bash tools/net_unit_tests.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
FAILED=0
for f in "$ROOT"/tests/unit/net/*_test.gd; do
	name="$(basename "$f")"
	out="$("$GODOT" --headless --path "$ROOT" -s "res://tests/unit/net/$name" 2>&1)"
	code=$?
	echo "$out" | grep -E "^FAIL|SCRIPT ERROR|Parse Error" | head -10
	echo "$out" | grep -E "^[A-Z_]+: (OK|FALHOU)" | tail -1
	if [ $code -ne 0 ]; then FAILED=$((FAILED + 1)); echo "  ($name saiu com $code)"; fi
done
if [ $FAILED -eq 0 ]; then echo "NET_UNIT_TESTS: OK"; exit 0; fi
echo "NET_UNIT_TESTS: FAIL ($FAILED arquivos)"
exit 1
