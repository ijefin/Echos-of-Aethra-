@tool
class_name SpawnPoint
extends WorldMarker
## Ponto de surgimento de jogador ou de inimigos.

enum Faction { PLAYER, ENEMY }

@export var side: Faction = Faction.PLAYER
## Tipo de inimigo (id do catálogo de inimigos) — só para `side == ENEMY`.
@export var enemy_kind: StringName = &""
@export var level: int = 1
## Segundos até reaparecer depois de morto.
@export var respawn_s: float = 30.0
## Quantos inimigos deste ponto podem existir ao mesmo tempo.
@export var max_alive: int = 1


func get_kind() -> StringName:
	return &"spawn"


func get_extra() -> Dictionary:
	return {"side": &"player" if side == Faction.PLAYER else &"enemy", "enemy_kind": enemy_kind,
		"level": level, "respawn_s": respawn_s, "max_alive": max_alive}


func get_debug_color() -> Color:
	return Color(0.3, 0.8, 1.0) if side == Faction.PLAYER else Color(1.0, 0.3, 0.3)
