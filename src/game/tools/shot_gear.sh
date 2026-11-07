#!/usr/bin/env bash
# Prints do equipamento no modelo (3 vocações): vestido (inicial), sem arma/cabeça/peito e com o
# peitoral tingido. bash src/game/tools/shot_gear.sh
G="${GODOT:-C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/../../.."
shot() {
	"$G" --path . --windowed --resolution 1280x720 res://src/game/pixel3d_demo.tscn -- --no_save --mute --hour=11 --zoom=40 --class=$1 $3 --shot=res://production/qa/evidence/pixel3d-gear-$1-$2.png --shot_delay=5 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
	echo "shot $1-$2"
}
for c in mage warrior archer; do
	shot $c full ""
	shot $c bare "--unequip=weapon,head,chest"
done
shot mage tinted "--give=mist_mantle,pyromancer_hood --equip=mist_mantle,pyromancer_hood"
shot warrior tinted "--give=lair_cuirass --equip=lair_cuirass"
shot archer tinted "--give=wolfhide_jerkin --equip=wolfhide_jerkin"
