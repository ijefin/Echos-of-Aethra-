#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION
# Prints das regiões do mundo: bash prototypes/pixel3d/tools/shot_world.sh nome x,z zoom [hora]
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/../../.."
while [ $# -ge 3 ]; do
	"$G" --path . --windowed --resolution 1280x720 res://prototypes/pixel3d/pixel3d_demo.tscn -- --no_save --mute --hour=${HOUR:-11} --at=$2 --zoom=$3 --shot=res://production/qa/evidence/pixel3d-world-$1.png --shot_delay=5 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
	echo "shot $1"
	shift 3
done
