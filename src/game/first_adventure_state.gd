extends RefCounted
## Pure progression and quest rules, injected tuning, no scene tree or file access.

var config: Dictionary
var level := 1
var xp := 0
var stage := "available"
var lit: Array[int] = []
var cave_kills: Dictionary = {}
var _paid_deaths: Dictionary = {}
## Vocação escolhida (mage / warrior / archer) e multiplicador de vida dela (classes.json).
var vocation := "mage"
var hp_mult := 1.0
## Vida máxima extra (equipamento + relíquias permanentes), posta pelo adventure.
var bonus_hp := 0
## Conteúdo jogável (quests.gd: missões, segredos, itens de missão, equipamento ganho,
## poções). Opaco aqui; saves antigos sem a chave restauram como {}.
var content: Dictionary = {}

func _init(tuning: Dictionary) -> void:
	config = tuning

## XP remaining within the current level, with increasing requirements after level 1.
func xp_required() -> int:
	return int(config.xp_first) + (level - 1) * int(config.xp_step)

func max_hp() -> int:
	return int(round((int(config.player_hp) + (level - 1) * int(config.hp_per_level)) * hp_mult)) + bonus_hp

func has_skill(id: String) -> bool:
	return level >= int(config.get(id + "_level", 1))

## Consume whole level thresholds while preserving overflow.
func add_xp(amount: int) -> void:
	xp += maxi(0, amount)
	while xp >= xp_required() and level < int(config.max_level):
		xp -= xp_required()
		level += 1
	if level == int(config.max_level):
		xp = mini(xp, xp_required() - 1)

## Called once per enemy death. Respawning field enemies must clear their death token.
## `xp_gain` < 0 usa o XP base do tipo (monstros de caçada passam o XP escalado pelo nível).
func record_kill(id: String, kind: String, in_cave: bool, xp_gain := -1) -> bool:
	if _paid_deaths.has(id) or not (config.enemy as Dictionary).has(kind):
		return false
	_paid_deaths[id] = true
	if in_cave and id.begins_with("cave"):  # só os guardiões da gruta contam para o baú
		cave_kills[id] = true
	add_xp(int(config.enemy[kind].xp) if xp_gain < 0 else xp_gain)
	return true

func respawn_enemy(id: String) -> void:
	if not cave_kills.has(id):
		_paid_deaths.erase(id)

func accept_quest() -> bool:
	if stage != "available":
		return false
	stage = "active"
	return true

## Repeated hits on already-lit torches are harmless; an incorrect new torch resets.
func ignite(index: int) -> bool:
	if stage != "active" or index < 0 or index >= (config.torch_order as Array).size():
		return false
	if index in lit:
		return true
	if int(config.torch_order[lit.size()]) != index:
		lit.clear()
		return false
	lit.append(index)
	return true

func can_open_chest() -> bool:
	return stage == "active" and lit.size() == (config.torch_order as Array).size() and cave_kills.size() >= int(config.cave_guardians)

func claim_chest() -> bool:
	if not can_open_chest():
		return false
	stage = "claimed"
	return true

func finish_quest() -> bool:
	if stage != "claimed":
		return false
	stage = "complete"
	return true

func has_reward() -> bool:
	return stage in ["claimed", "complete"]

func snapshot() -> Dictionary:
	return {"version": 1, "vocation": vocation, "level": level, "xp": xp, "stage": stage, "lit": lit.duplicate(), "cave_kills": cave_kills.duplicate(), "content": content.duplicate(true)}

## Validate local save values and reconstruct consistent terminal quest states.
func restore(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, int(config.max_level))
	vocation = String(data.get("vocation", vocation))
	var saved_content: Variant = data.get("content", {})
	content = (saved_content as Dictionary).duplicate(true) if saved_content is Dictionary else {}
	xp = clampi(int(data.get("xp", 0)), 0, xp_required() - 1)
	var saved_stage := String(data.get("stage", "available"))
	stage = saved_stage if saved_stage in ["available", "active", "claimed", "complete"] else "available"
	lit.clear()
	var saved_lit: Variant = data.get("lit", [])
	if saved_lit is Array:
		for index: Variant in saved_lit:
			if lit.size() >= (config.torch_order as Array).size() or int(index) != int(config.torch_order[lit.size()]):
				break
			lit.append(int(index))
	cave_kills.clear()
	var saved_kills: Variant = data.get("cave_kills", {})
	if saved_kills is Dictionary:
		for i in int(config.cave_guardians):
			var id := "cave%d" % i
			if saved_kills.has(id):
				cave_kills[id] = true
	if has_reward():
		lit.assign(config.torch_order)
		for i in int(config.cave_guardians):
			cave_kills["cave%d" % i] = true
	_paid_deaths = cave_kills.duplicate()
