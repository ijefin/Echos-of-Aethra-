#!/bin/bash
# Roda todos os testes do módulo de mundo. Uso: GODOT=/caminho/godot tests/run_world_tests.sh
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
rc=0
for t in tests/unit/world/*_test.gd tests/integration/world/*_test.gd; do
	echo "=== $t"
	out=$("$G" --headless --path . -s "res://$t" 2>&1)
	code=$?
	echo "$out" | grep -E "FAIL|passou|SCRIPT ERROR|Parse Error"
	[ $code -ne 0 ] && { echo "FALHOU: $t"; rc=1; }
done
exit $rc
