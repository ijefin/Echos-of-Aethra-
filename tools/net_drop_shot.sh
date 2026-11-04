#!/usr/bin/env bash
# Prova visual do item largado no chão: 1 servidor + 2 clientes JANELADOS em 127.0.0.1.
# A Ana (--auto_drop) tira o capuz e larga no chão; o Davi fotografa o saquinho com o nome.
#   bash tools/net_drop_shot.sh [porta]
# Print: production/qa/evidence/pixel3d-net-ground-davi.png
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-17793}"
GODOT="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aethra-drop-XXXXXX")"
WORK_G="$WORK"
if command -v cygpath >/dev/null 2>&1; then WORK_G="$(cygpath -m "$WORK")"; fi
EVID="$ROOT/production/qa/evidence"
"$GODOT" --headless --path "$ROOT" -s res://prototypes/pixel3d/net/server_main.gd -- --port="$PORT" --data_dir="$WORK_G/data" >"$WORK/server.out.log" 2>&1 &
S=$!
for _ in $(seq 1 150); do grep -q AETHRA_SERVER_READY "$WORK/server.out.log" 2>/dev/null && break; sleep 0.2; done
"$GODOT" --path "$ROOT" --resolution 1280x720 res://prototypes/pixel3d/pixel3d_demo.tscn -- --connect=127.0.0.1:"$PORT" --user=Ana --pass=senha123 --register --class=archer --mute \
	--hour=11 --auto_drop=8 --shot="$EVID/pixel3d-net-ground-ana.png" --shot_delay=16 --shot_hold=6 >"$WORK/ana.log" 2>&1 &
A=$!
sleep 2
"$GODOT" --path "$ROOT" --resolution 1280x720 res://prototypes/pixel3d/pixel3d_demo.tscn -- --connect=127.0.0.1:"$PORT" --user=Davi --pass=senha123 --register --class=warrior --mute \
	--hour=11 --shot="$EVID/pixel3d-net-ground-davi.png" --shot_delay=16 --shot_hold=6 >"$WORK/davi.log" 2>&1 &
D=$!
for _ in $(seq 1 300); do (kill -0 "$A" 2>/dev/null || kill -0 "$D" 2>/dev/null) || break; sleep 0.2; done
kill "$A" "$D" 2>/dev/null
kill "$S" 2>/dev/null
grep -E "entrou|saiu" "$WORK/server.out.log"
grep -hE "SCRIPT ERROR|Parse Error" "$WORK"/*.log | head
ls -la "$EVID"/pixel3d-net-ground-*.png
