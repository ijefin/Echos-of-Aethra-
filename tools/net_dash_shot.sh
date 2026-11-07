#!/usr/bin/env bash
# Prova visual da investida deslizando online: 1 servidor + 2 clientes JANELADOS em 127.0.0.1.
# Davi (guerreiro, nível 3 para ter a Investida) dá Q sozinho; o cliente da Ana tira o print
# logo depois que a investida dele começa (meio do deslizamento).
#   bash tools/net_dash_shot.sh [porta] [atraso_do_print_s]
# Print: production/qa/evidence/pixel3d-net-dash-ana.png
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-17792}"
AFTER="${2:-0.12}"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethra-dash-XXXXXX")"
WORK_G="$WORK"
if command -v cygpath >/dev/null 2>&1; then WORK_G="$(cygpath -m "$WORK")"; fi
EVID="$ROOT/production/qa/evidence"
rm -f "$EVID/pixel3d-net-dash-ana.png" "$EVID/pixel3d-net-dash-davi.png"

# 1) cria as contas (servidor sai sozinho e grava)
"$GODOT" --headless --path "$ROOT" -s res://src/game/net/server_main.gd -- --port="$PORT" --data_dir="$WORK_G/data" --quit_after=14 >"$WORK/server0.log" 2>&1 &
S=$!
for _ in $(seq 1 150); do grep -q AETHRA_SERVER_READY "$WORK/server0.log" 2>/dev/null && break; sleep 0.2; done
for who in "Ana archer" "Davi warrior"; do
	set -- $who
	"$GODOT" --headless --path "$ROOT" --quit-after 400 res://src/game/pixel3d_demo.tscn -- --connect=127.0.0.1:"$PORT" --user="$1" --pass=senha123 --register --class="$2" --mute --no_save >"$WORK/reg-$1.log" 2>&1 &
done
wait "$S"
# 2) Davi no nível 3 (Investida liberada no nível 2)
python -I - "$WORK/data/accounts.json" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
accs = d.get("accounts", d)
n = 0
for k, a in accs.items():
	if isinstance(a, dict) and str(a.get("name", k)).lower() == "davi" and isinstance(a.get("character"), dict):
		a["character"]["progress"]["level"] = 3
		n += 1
assert n == 1, "Davi não encontrado em accounts.json"
json.dump(d, open(p, "w", encoding="utf-8"))
print("Davi nível 3")
EOF
[ $? -eq 0 ] || { echo "falhou ao preparar contas — $WORK"; exit 1; }
# 3) servidor + 2 clientes janelados
"$GODOT" --headless --path "$ROOT" -s res://src/game/net/server_main.gd -- --port="$PORT" --data_dir="$WORK_G/data" >"$WORK/server.log" 2>&1 &
S=$!
for _ in $(seq 1 150); do grep -q AETHRA_SERVER_READY "$WORK/server.log" 2>/dev/null && break; sleep 0.2; done
"$GODOT" --path "$ROOT" --resolution 1280x720 res://src/game/pixel3d_demo.tscn -- --connect=127.0.0.1:"$PORT" --user=Ana --pass=senha123 --class=archer --mute \
	--hour=11 --dash_shot="$EVID/pixel3d-net-dash-ana.png" --dash_shot_after="$AFTER" --shot="$WORK_G/ana-end.png" --shot_delay=24 >"$WORK/ana.log" 2>&1 &
A=$!
sleep 2
"$GODOT" --path "$ROOT" --resolution 1280x720 res://src/game/pixel3d_demo.tscn -- --connect=127.0.0.1:"$PORT" --user=Davi --pass=senha123 --class=warrior --mute \
	--hour=11 --auto_q=12 --auto_q_dir=1,0.3 --shot="$WORK_G/davi-end.png" --shot_delay=22 >"$WORK/davi.log" 2>&1 &
D=$!
for _ in $(seq 1 300); do (kill -0 "$A" 2>/dev/null || kill -0 "$D" 2>/dev/null) || break; sleep 0.2; done
kill "$A" "$D" 2>/dev/null
kill "$S" 2>/dev/null
grep -E "entrou|saiu|dash|Investida" "$WORK/server.log" | head
grep -h "DASH_SHOT" "$WORK"/ana.log
grep -hE "SCRIPT ERROR|Parse Error" "$WORK"/*.log | head
ls -la "$EVID"/pixel3d-net-dash-*.png 2>/dev/null || { echo "sem print — logs em $WORK"; exit 1; }
