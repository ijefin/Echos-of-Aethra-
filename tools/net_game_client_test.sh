#!/usr/bin/env bash
# Integração com o CLIENTE REAL do jogo: 1 servidor dedicado + bot "Bia" + pixel3d_demo
# headless em modo online (--connect), tudo em 127.0.0.1.
#   GODOT=/caminho/godot bash tools/net_game_client_test.sh [porta]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-17790}"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethra-game-test-XXXXXX")"
WORK_G="$WORK"
if command -v cygpath >/dev/null 2>&1; then WORK_G="$(cygpath -m "$WORK")"; fi
echo "dados do teste: $WORK"

"$GODOT" --headless --path "$ROOT" -s res://prototypes/pixel3d/net/server_main.gd -- --port="$PORT" --data_dir="$WORK_G/data" --log_level=info >"$WORK/server.out.log" 2>"$WORK/server.err.log" &
S=$!
for _ in $(seq 1 150); do grep -q AETHRA_SERVER_READY "$WORK/server.out.log" 2>/dev/null && break; sleep 0.2; done
"$GODOT" --headless --path "$ROOT" -s res://prototypes/pixel3d/net/tests/net_bot.gd -- --role=buddy --port="$PORT" --stay=90 >"$WORK/bia.out.log" 2>"$WORK/bia.err.log" &
B=$!
sleep 0.5
"$GODOT" --headless --path "$ROOT" -s res://prototypes/pixel3d/net/tests/game_client_test.gd -- --connect=127.0.0.1:"$PORT" --user=Tester --pass=senha123 --register --class=mage --no_save --mute >"$WORK/game.out.log" 2>"$WORK/game.err.log" &
G=$!
for _ in $(seq 1 900); do kill -0 "$G" 2>/dev/null || break; sleep 0.2; done
kill "$G" 2>/dev/null
for _ in $(seq 1 100); do kill -0 "$B" 2>/dev/null || break; sleep 0.2; done
kill "$B" 2>/dev/null
kill "$S" 2>/dev/null
sleep 0.5
echo "--- log do servidor ---"
grep -E "\[(INFO|WARN|ERROR)\]" "$WORK/server.out.log" | sed 's/^/  /'
echo "--- verificação ---"
cat "$WORK/game.out.log" "$WORK/bia.out.log" | grep -E "^(CHECK|BOT_DONE) " | tee "$WORK/summary.txt"
ERRS=$(cat "$WORK"/game.err.log "$WORK"/bia.err.log "$WORK"/server.err.log | grep -cE "SCRIPT ERROR|Parse Error")
PASS=$(grep -c "^CHECK PASS" "$WORK/summary.txt")
FAIL=$(grep -c "^CHECK FAIL" "$WORK/summary.txt")
DONE=$(grep -c "^BOT_DONE" "$WORK/summary.txt")
if [ "$ERRS" -gt 0 ]; then echo "--- erros de script ---"; cat "$WORK"/*.err.log | grep -A3 -E "SCRIPT ERROR|Parse Error" | head -40; fi
if [ "$FAIL" -eq 0 ] && [ "$DONE" -eq 2 ] && [ "$PASS" -gt 0 ] && [ "$ERRS" -eq 0 ]; then
	echo "NET_GAME_CLIENT_TEST: OK ($PASS PASS, $FAIL FAIL, $DONE/2 concluíram, $ERRS erros de script)"
	rm -rf "$WORK"; exit 0
fi
echo "NET_GAME_CLIENT_TEST: FAIL ($PASS PASS, $FAIL FAIL, $DONE/2 concluíram, $ERRS erros de script) — logs em $WORK"
exit 1
