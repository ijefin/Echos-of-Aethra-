# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Regras de combate do servidor (puras): recarga, mana, nível, alcance, linha de visão, dano.
## `ch` é o registro do jogador em ServerWorld ({state, mana, cd: {skill → t_pronto}, ...}).

var tuning: Dictionary   # data/first_adventure.json
var combat: Dictionary   # net_config.json → combat
var col: RefCounted


func _init(adventure_tuning: Dictionary, combat_cfg: Dictionary, collision: RefCounted) -> void:
	tuning = adventure_tuning
	combat = combat_cfg
	col = collision


func mana_cost(skill: String) -> int:
	if skill == "light":
		return int(combat.get("light_mana", 20))
	return int((tuning.get("mana_cost", {}) as Dictionary).get(skill, 0))


func cooldown(skill: String) -> float:
	match skill:
		"fire": return float(combat.get("fire_cooldown", 0.42))
		"blink": return float(combat.get("blink_cooldown", tuning.get("blink_cooldown", 3.0)))
		"ring": return float(combat.get("ring_cooldown", tuning.get("ring_cooldown", 6.0)))
		"potion": return float(combat.get("potion_cooldown", 1.0))
		"light": return float(combat.get("light_cooldown", 2.0))
	return 1.0


func required_level(skill: String) -> int:
	return int(tuning.get(skill + "_level", 1))


func max_mana(level: int) -> int:
	return int(tuning.get("mana_base", 40)) + (level - 1) * int(tuning.get("mana_per_level", 6))


## "" = pode usar; senão o código do motivo (o cliente mostra só feedback visual).
func can_use(ch: Dictionary, skill: String, now: float) -> String:
	if int(ch.hp) <= 0:
		return "dead"
	if int(ch.state.level) < required_level(skill):
		return "level"
	if now < float((ch.cd as Dictionary).get(skill, 0.0)):
		return "cooldown"
	if float(ch.mana) < float(mana_cost(skill)):
		return "mana"
	return ""


## Debita mana e arma a recarga (chamar só depois de can_use == "").
func commit(ch: Dictionary, skill: String, now: float) -> void:
	ch.mana = float(ch.mana) - float(mana_cost(skill))
	(ch.cd as Dictionary)[skill] = now + cooldown(skill)


## Alvo dentro do alcance (com tolerância de latência) e com linha de visão.
func target_ok(from: Vector3, to: Vector3, max_range: float) -> String:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if a.distance_to(b) > max_range + float(combat.get("range_tolerance", 1.5)):
		return "range"
	if not col.segment_clear(a, b, 0.05):
		return "los"
	return ""


func fire_range() -> float:
	return float(combat.get("fire_range", 10.4))


## Dano do ataque básico: igual ao protótipo (base + nível − 1 + poder mágico do colar).
func fire_damage(ch: Dictionary) -> int:
	return int(tuning.get("basic_damage", 8)) + int(ch.state.level) - 1 + int(ch.get("spell_power", 0))


func ring_damage(ch: Dictionary) -> int:
	return int(tuning.get("ring_damage", 18)) + int(ch.state.level) - 1


## Destino do Eco: dentro do alcance, livre e com visão. Devolve o ponto final ou null.
func blink_target(from: Vector3, to: Vector3, radius: float) -> Variant:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var max_r := float(combat.get("blink_range", 7.0))
	if a.distance_to(b) > max_r:
		b = a + (b - a).normalized() * max_r
	if col.blocked(b, radius) or not col.segment_clear(a, b, 0.05):
		return null
	return Vector3(b.x, col.ground_y(b.x, b.y), b.y)
