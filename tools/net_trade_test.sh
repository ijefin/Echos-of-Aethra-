#!/usr/bin/env bash
# Sessão só da economia online (~1 min): 1 servidor + 2 bots (Tara e Teo) em 127.0.0.1.
# Loja da Nessa (venda/compra validadas no servidor), troca concluída, item largado no chão
# pego pelo outro e troca cancelada ao se afastar. O mesmo roteiro roda em net_session_test.sh.
#   GODOT=/caminho/godot bash tools/net_trade_test.sh [porta]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-17787}"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethra-net-trade-XXXXXX")"
WORK_G="$WORK"
if command -v cygpath >/dev/null 2>&1; then WORK_G="$(cygpath -m "$WORK")"; fi
DATA="$WORK_G/data"
echo "dados do teste: $WORK"

run_godot() { # nome args...
	local name="$1"; shift
	"$GODOT" --headless --path "$ROOT" "$@" >"$WORK/$name.out.log" 2>"$WORK/$name.err.log" &
	echo $!
}

start_server() { # nome
	local pid
	pid=$(run_godot "$1" -s res://prototypes/pixel3d/net/server_main.gd -- --port="$PORT" --data_dir="$DATA" --log_level=info)
	for _ in $(seq 1 150); do
		grep -q AETHRA_SERVER_READY "$WORK/$1.out.log" 2>/dev/null && { echo "$pid"; return 0; }
		sleep 0.2
	done
	echo "servidor $1 não ficou pronto" >&2
	echo "$pid"
	return 1
}

bot() { run_godot "bot-$1" -s res://prototypes/pixel3d/net/tests/net_bot.gd -- --role="$1" --port="$PORT"; }

wait_pids() { # timeout pids...
	local limit="$1"; shift
	local t=0
	while [ $t -lt $((limit * 5)) ]; do
		local alive=0
		for p in "$@"; do kill -0 "$p" 2>/dev/null && alive=1; done
		[ $alive -eq 0 ] && return 0
		sleep 0.2; t=$((t + 1))
	done
	echo "TIMEOUT"; for p in "$@"; do kill "$p" 2>/dev/null; done
}

S1=$(start_server server)
T=$(bot trader)
P=$(bot partner)
wait_pids 200 "$T" "$P"
kill "$S1" 2>/dev/null
sleep 0.5
cat "$WORK"/bot-trader.out.log "$WORK"/bot-partner.out.log 2>/dev/null | grep -E "^(CHECK|BOT_DONE) " | tee "$WORK/summary.txt"
ERRS=$(cat "$WORK"/*.err.log 2>/dev/null | grep -cE "SCRIPT ERROR|Parse Error")
PASS=$(grep -c "^CHECK PASS" "$WORK/summary.txt")
FAIL=$(grep -c "^CHECK FAIL" "$WORK/summary.txt")
DONE=$(grep -c "^BOT_DONE" "$WORK/summary.txt")
if [ "$ERRS" -gt 0 ]; then echo "--- erros de script ---"; cat "$WORK"/*.err.log | grep -A2 -E "SCRIPT ERROR|Parse Error" | head -30; fi
if [ "$FAIL" -eq 0 ] && [ "$DONE" -eq 2 ] && [ "$PASS" -gt 0 ] && [ "$ERRS" -eq 0 ]; then
	echo "NET_TRADE_TEST: OK ($PASS PASS, $FAIL FAIL, $DONE/2 bots)"
	rm -rf "$WORK"; exit 0
fi
echo "NET_TRADE_TEST: FAIL ($PASS PASS, $FAIL FAIL, $DONE/2 bots, $ERRS erros de script) — logs em $WORK"
exit 1
