#!/usr/bin/env bash
# Teste de integração da rede (mesmo roteiro de net_session_test.ps1), para Git Bash/Linux:
# 1 servidor dedicado + 2 clientes headless em 127.0.0.1; depois reinicia o servidor e confere a persistência.
#   GODOT=/caminho/godot bash tools/net_session_test.sh [porta]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-17777}"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethra-net-test-XXXXXX")"
WORK_G="$WORK"
if command -v cygpath >/dev/null 2>&1; then WORK_G="$(cygpath -m "$WORK")"; fi
DATA="$WORK_G/data"
STATE="$WORK_G/bruno-state.json"
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

bot() { run_godot "bot-$1" -s res://prototypes/pixel3d/net/tests/net_bot.gd -- --role="$1" --port="$PORT" --state="$STATE"; }

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

echo "== fase 1: servidor + Alice + Bruno =="
S1=$(start_server server1)
A=$(bot alice)
sleep 0.3
B=$(bot bruno)
Q=$(bot quester)   # Quinn: missões 1 e 2 online, segredo, RESUME, equipamento
T=$(bot trader)    # Tara: loja da Nessa, troca, largar item, troca cancelada
P=$(bot partner)   # Teo: o outro lado das trocas e pega o item do chão
wait_pids 150 "$A" "$B" "$T" "$P"
wait_pids 480 "$Q"
kill "$S1" 2>/dev/null   # queda brusca: só vale o que já foi salvo
sleep 1
echo "== fase 2: servidor reiniciado + relogin do Bruno =="
S2=$(start_server server2)
R=$(bot relogin)
Q2=$(bot quester2)
wait_pids 60 "$R" "$Q2"
kill "$S2" 2>/dev/null
sleep 0.5

for f in server1 server2; do
	echo "--- log $f ---"
	grep -E "\[(INFO|WARN|ERROR)\]" "$WORK/$f.out.log" "$WORK/$f.err.log" 2>/dev/null | sed 's/^[^:]*://; s/^/  /'
done
echo "--- verificação ---"
cat "$WORK"/bot-alice.out.log "$WORK"/bot-bruno.out.log "$WORK"/bot-quester.out.log "$WORK"/bot-relogin.out.log "$WORK"/bot-quester2.out.log "$WORK"/bot-trader.out.log "$WORK"/bot-partner.out.log 2>/dev/null | grep -E "^(CHECK|BOT_DONE) " | tee "$WORK/summary.txt"
ERRS=$(cat "$WORK"/*.err.log 2>/dev/null | grep -cE "SCRIPT ERROR|Parse Error")
PASS=$(grep -c "^CHECK PASS" "$WORK/summary.txt")
FAIL=$(grep -c "^CHECK FAIL" "$WORK/summary.txt")
DONE=$(grep -c "^BOT_DONE" "$WORK/summary.txt")
if [ "$ERRS" -gt 0 ]; then echo "--- erros de script ---"; cat "$WORK"/*.err.log | grep -A2 -E "SCRIPT ERROR|Parse Error" | head -30; fi
if [ "$FAIL" -eq 0 ] && [ "$DONE" -eq 7 ] && [ "$PASS" -gt 0 ] && [ "$ERRS" -eq 0 ]; then
	echo "NET_SESSION_TEST: OK ($PASS PASS, $FAIL FAIL, $DONE/7 bots concluíram, $ERRS erros de script)"
	rm -rf "$WORK"; exit 0
fi
echo "NET_SESSION_TEST: FAIL ($PASS PASS, $FAIL FAIL, $DONE/7 bots concluíram, $ERRS erros de script) — logs em $WORK"
exit 1
