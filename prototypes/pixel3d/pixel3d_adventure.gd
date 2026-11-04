# PROTOTYPE - NOT FOR PRODUCTION
extends Node
## First playable slice: local quest, progression, combat, underground puzzle and return.
const State := preload("res://prototypes/pixel3d/first_adventure_state.gd")
const World := preload("res://prototypes/pixel3d/adventure_world.gd")
const Enemies := preload("res://prototypes/pixel3d/adventure_enemies.gd")
const Hud := preload("res://prototypes/pixel3d/adventure_hud.gd")
const CoreSkills := preload("res://prototypes/pixel3d/core_skills.gd")
const Chat := preload("res://prototypes/pixel3d/adventure_chat.gd")
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const BUBBLE_TIME := 10.0
const ItemInventory := preload("res://src/core/inventory.gd")
const SAVE := "user://pixel3d-first-adventure-v1.json"
var save_path := SAVE
var demo: Node
var config: Dictionary
var state
var world
var enemies
var hud
## Core skills (todas as classes): luz etc.
var core
var inventory
var hp := 60.0
var mana := 40.0
## Poções na bolsa (contagem).
var potions := {"hp": 0, "mana": 0}
var _potion_cd := 0.0
var in_cave := false
var ring_cd := 0.0
var notice_text := ""
var notice_time := 0.0
var _hurt_time := 99.0
var _invulnerable := 0.0
var _persist := false
## Evita descer/subir de novo logo depois de trocar de andar.
var _stair_cd := 0.0
var chat
var _bubbles := {}
var _was_night := false
var _talk: Array[String] = []
var _talk_time := 0.0
const NESSA_ACCEPT := [
	"Você também chegou com a tempestade, não foi?",
	"Naquela noite a Gruta das Raízes, a oeste, engoliu meu colar de brasa.",
	"Sem ele, as lamparinas do acampamento morrem antes do amanhecer.",
	"Os antigos guiavam os caminhos com fogo... dizem que as tochas de lá ainda se lembram da ordem.",
]
const NESSA_WAITING := [
	["Os bichos da trilha andam agitados desde a tempestade. Vá com cuidado."],
	["Aquela gruta respira. Às vezes ouço água correndo lá dentro, onde nunca choveu."],
	["Minha avó dizia que o fogo certo abre o que a pedra esconde."],
]
const NESSA_FINISH := [
	"...esse calor. É ele!",
	"Você trouxe a luz de volta ao acampamento.",
	"Fique com o colar. A brasa escolheu você, não eu.",
]
const NESSA_AFTER := [
	["As lamparinas não tremem mais. Esta noite dormimos tranquilos."],
	["Há outras sombras na floresta... mas hoje, obrigada."],
]

func build(owner_demo: Node, args: Dictionary) -> void:
	demo = owner_demo
	config = JSON.parse_string(FileAccess.get_file_as_string("res://prototypes/pixel3d/data/first_adventure.json"))
	state = State.new(config)
	_persist = not demo._capture and not args.has("no_save")
	if _persist and FileAccess.file_exists(save_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary:
			state.restore(data)
	inventory = ItemInventory.new(ItemInventory.load_db(), "fire_mage")
	inventory.give(["fire_staff", "apprentice_robe", "mage_hat"])
	for id in ["fire_staff", "apprentice_robe", "mage_hat"]:
		inventory.equip(id)
	if state.has_reward():
		_equip_reward()
	hp = state.max_hp()
	mana = max_mana()
	potions = {"hp": int(config.potion.start_hp), "mana": int(config.potion.start_mana)}
	world = World.new()
	world.build(demo)
	enemies = Enemies.new()
	enemies.build(self)
	hud = Hud.new()
	hud.build(self)
	core = CoreSkills.new()
	core.build(self)
	chat = Chat.new()
	chat.build(self, hud.get_parent())
	chat.post("Servidor", "Bem-vindo a Aethra.")
	if not args.has("at"):
		warp(World.NPC + Vector3(0, 0, 2.3), false)

## Estilo Tibia: pisou na boca da caverna desce; pisou na escada sobe; sem tecla.
func _check_stairs() -> void:
	var p: Vector3 = demo._player.global_position
	var flat := Vector2(p.x, p.z)
	for s: Dictionary in World.STAIRS:
		var down: Vector3 = s.down
		var up: Vector3 = s.up
		if not in_cave and flat.distance_to(Vector2(down.x, down.z)) < 1.0:
			warp(s.arrive, true)
			return
		if in_cave and flat.distance_to(Vector2(up.x, up.z)) < 1.0:
			warp(s.exit, false)
			return
	if in_cave and state.has_reward() and flat.distance_to(Vector2(World.PORTAL.x, World.PORTAL.z)) < 1.1:
		warp(World.NPC + Vector3(0, 0, 2.1), false)
		demo._burst(World.NPC + Vector3(0, 0.6, 2.1))


func max_mana() -> int:
	return int(config.mana_base) + (state.level - 1) * int(config.mana_per_level)


func cost(skill: String) -> int:
	return int(config.mana_cost.get(skill, 0))


## Gasta mana da habilidade; sem mana suficiente, avisa (barra pisca) e recusa.
func spend(skill: String) -> bool:
	var c := cost(skill)
	if mana < c:
		hud.flash_mana()
		return false
	mana -= c
	return true


func potion_cd_ratio() -> float:
	return clampf(_potion_cd / maxf(0.01, float(config.potion.cooldown)), 0.0, 1.0)


## Teclas 1 (vida) e 2 (mana).
func drink(kind: String) -> void:
	if _potion_cd > 0.0 or int(potions.get(kind, 0)) <= 0:
		return
	if kind == "hp":
		if hp >= state.max_hp():
			return
		hp = minf(state.max_hp(), hp + float(config.potion.hp_heal))
		floating("+%d" % int(config.potion.hp_heal), demo._player.global_position + Vector3(0, 1.8, 0), Color(0.4, 1, 0.4))
	else:
		if mana >= max_mana():
			return
		mana = minf(max_mana(), mana + float(config.potion.mana_restore))
		floating("+%d" % int(config.potion.mana_restore), demo._player.global_position + Vector3(0, 1.8, 0), Color(0.5, 0.7, 1))
	potions[kind] = int(potions[kind]) - 1
	chat.post("Servidor", "Você usou uma poção de %s. Restam %d." % ["vida" if kind == "hp" else "mana", int(potions[kind])])
	_potion_cd = float(config.potion.cooldown)


## Nessa fala frase por frase sobre a cabeça (tempo de leitura por frase).
func npc_talk(lines: Array) -> void:
	_talk.clear()
	for l: Variant in lines:
		_talk.append(String(l))
	_talk_time = 0.0
	_next_line()


func _next_line() -> void:
	if _talk.is_empty():
		world.npc_speech.text = ""
		return
	var line: String = _talk.pop_front()
	world.npc_speech.text = _wrap(line, 34)
	world.npc_speech.modulate.a = 1.0
	chat.post("Local", "Nessa: " + line)
	_talk_time = BUBBLE_TIME if _talk.is_empty() else 1.6 + line.length() * 0.055


static func _wrap(text: String, width: int) -> String:
	var out := ""
	var row := ""
	for word in text.split(" "):
		if row.length() + word.length() + 1 > width and not row.is_empty():
			out += row + "\n"
			row = word
		else:
			row = word if row.is_empty() else row + " " + word
	return out + row


func _save() -> void:
	if not _persist:
		return
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state.snapshot()))

func say(text: String, seconds := 5.0) -> void:
	notice_text = text
	notice_time = seconds

func floating(text: String, at: Vector3, color: Color) -> void:
	var label: Label3D = world.label(demo._vp, text, at, color, 38)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at.y + 0.9, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)

func _equip_reward() -> void:
	var id := String(config.reward_item)
	if inventory.equipped.get("neck", "") != id:
		inventory.give([id])
		inventory.equip(id)

func basic_damage() -> int:
	# Starter weapon is the visual baseline; the quest pendant adds its actual stat bonus.
	var necklace := String(inventory.equipped.get("neck", ""))
	var bonus := int(inventory.item(necklace).get("stats", {}).get("spell_power", 0))
	return int(config.basic_damage) + state.level - 1 + bonus

func on_enemy_killed(id: String, kind: String, cave: bool, at: Vector3) -> void:
	var old_level: int = state.level
	if not state.record_kill(id, kind, cave):
		return
	# Como no Tibia: número branco de XP subindo de onde o monstro morreu.
	floating("%d" % int(config.enemy[kind].xp), at + Vector3(0, 1.6, 0), Color(1, 1, 1))
	chat.post("Servidor", "Você derrotou %s. Ganhou %d de experiência." % [String(config.enemy[kind].name), int(config.enemy[kind].xp)])
	if state.level > old_level:
		hp = state.max_hp()
		mana = max_mana()
		demo._shockwave(demo._player.global_position)
		demo._burst(demo._player.global_position + Vector3(0, 1.2, 0))
		var unlocked := "Nova habilidade: Eco de Aethra" if state.level == 2 else ("Nova habilidade: Anel de Brasa" if state.level == 3 else "")
		demo.world_labels.announce("Você subiu do nível %d para o nível %d." % [old_level, state.level], unlocked)
		chat.post("Servidor", "Você subiu do nível %d para o nível %d." % [old_level, state.level], Color(1.0, 0.82, 0.38))
	_save()

func take_damage(amount: int, source := "") -> void:
	if _invulnerable > 0 or demo._blink_t >= 0 or demo._dodge_t >= 0:
		return
	hp = maxf(0, hp - amount)
	_hurt_time = 0.0
	chat.post("Servidor", "Você perdeu %d de vida por um ataque de %s." % [amount, source] if not source.is_empty() else "Você perdeu %d de vida." % amount, Color(1.0, 0.55, 0.5))
	_invulnerable = 0.75
	floating("-%d" % amount, demo._player.global_position + Vector3(0, 1.7, 0), Color(1, 0.30, 0.25))
	if hp <= 0:
		hp = state.max_hp()
		warp(World.NPC + Vector3(0, 0, 2.3), false)
		npc_talk(["Calma... você ainda respira.", "Descanse um pouco perto do fogo."])

## Scene travel always clears transient combat and returns to a known safe position.
func warp(to: Vector3, cave: bool) -> void:
	in_cave = cave
	world.cave.visible = cave
	world.surface.visible = not cave
	demo._world_root.visible = not cave  # como no Tibia: só o andar atual aparece
	demo.world_labels.fade_in()
	_stair_cd = 1.0
	for projectile: Dictionary in demo._projectiles:
		(projectile.node as Node).queue_free()
	demo._projectiles.clear()
	demo._blink_t = -1.0
	demo._attack_t = -1.0
	demo._dodge_t = -1.0
	demo._set_dissolve(0.0)
	demo._player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED if cave else CharacterBody3D.MOTION_MODE_FLOATING
	demo._player.global_position = to
	demo._player.velocity = Vector3.ZERO
	demo._cam_focus = to + Vector3(0, 0.6, 0)
	demo._update_camera(1.0)
	_invulnerable = 1.0

func ground_height() -> float:
	return World.ROOM.y if in_cave else 0.0

## The marked return circle allows a controlled vertical blink to the upper ledge.
func ledge_blink_target() -> Vector3:
	return Vector3.INF  # sem patamar: andares são trocados pelas escadas

func ignite(index: int) -> void:
	if not in_cave:
		return
	var was_lit: bool = index in state.lit
	var correct: bool = state.ignite(index)
	if not correct:
		for i in World.TORCHES.size():  # erro de ordem: todas apagam com um sopro de fumaça
			demo._burst(World.ROOM + World.TORCHES[i] + Vector3(0, 1.7, 0))
	elif not was_lit:
		demo._burst(World.ROOM + World.TORCHES[index] + Vector3(0, 1.7, 0))
	_save()

func hit(collider: Object) -> bool:
	if enemies.hit(collider, basic_damage()):
		return true
	if collider != null and String(collider.get_meta("kind", "")) == "quest_torch":
		ignite(int(collider.get_meta("torch_index")))
		return true
	return false

func cast_ring() -> void:
	if not state.has_skill("ring") or ring_cd > 0:
		return
	if not spend("ring"):
		return
	ring_cd = float(config.ring_cooldown)
	var p: Vector3 = demo._player.global_position
	demo._shockwave(p, float(config.ring_radius))
	for i in 6:
		var angle := i * TAU / 6.0
		demo._burst(p + Vector3(cos(angle), 0.3, sin(angle)) * 2.3)
	enemies.ring_damage(p, float(config.ring_radius), int(config.ring_damage) + state.level)

## Ação possível agora ("E — ...") e onde ela aparece (sobre o objeto/pessoa).
var prompt_at := Vector3.INF


func prompt() -> String:
	var p: Vector3 = demo._player.global_position
	prompt_at = Vector3.INF
	if not in_cave:
		if p.distance_to(World.NPC) < 2.8:
			prompt_at = World.NPC + Vector3(0, 3.5, 0)
			return "E — conversar"
	else:
		if p.distance_to(World.CHEST) < 2.2 and state.can_open_chest():
			prompt_at = World.CHEST + Vector3(0, 1.6, 0)
			return "E — abrir"
		for i in World.TORCHES.size():
			if p.distance_to(World.ROOM + World.TORCHES[i]) < 2.1 and not (i in state.lit):
				prompt_at = World.ROOM + World.TORCHES[i] + Vector3(0, 2.2, 0)
				return "E — acender"
	return ""


## Mensagem sobre um objeto/pessoa por 10 s; a mesma chave troca o texto (sem spam).
## Também vai para o chat Local.
func object_say(key: String, parent: Node, at: Vector3, text: String, color := Color(1.0, 0.93, 0.35), log := true) -> void:
	var entry: Dictionary = _bubbles.get(key, {})
	var l: Label3D = entry.get("label")
	if l == null or not is_instance_valid(l):
		l = world.label(parent, text, at, color, 34)
	else:
		l.text = text
		l.modulate = color
	_bubbles[key] = {"label": l, "time": BUBBLE_TIME}
	if log:
		chat.post("Local", text.replace("\n", " "), color)


## O que o jogador digita no canal Local aparece sobre a cabeça dele.
func player_say(text: String) -> void:
	object_say("player", demo._player, Vector3(0, 2.5, 0), _wrap(text, 34), Color(1.0, 0.93, 0.35), false)


func _update_bubbles(delta: float) -> void:
	for key: String in _bubbles.keys():
		var b: Dictionary = _bubbles[key]
		var l: Label3D = b.label
		b.time = float(b.time) - delta
		if not is_instance_valid(l):
			_bubbles.erase(key)
		elif float(b.time) <= 0.0:
			l.queue_free()
			_bubbles.erase(key)
		elif float(b.time) < 1.0:
			l.modulate.a = float(b.time)


## Nome da região onde algo acontece (para os eventos do servidor).
func region_name(at: Vector3) -> String:
	var p := Vector2(at.x, at.z)
	if Vector2(World.ENTRANCE.x, World.ENTRANCE.z).distance_to(p) < 12.0:
		return "perto da Gruta das Raízes"
	if Dressing.water_dist(p) < 6.0:
		return "às margens do rio"
	if Vector2(World.NPC.x, World.NPC.z).distance_to(p) < 14.0:
		return "nos arredores do acampamento"
	return "na floresta " + ("ao norte" if at.z < -10.0 else ("ao sul" if at.z > 10.0 else ("a leste" if at.x > 0.0 else "a oeste")))


func interact() -> void:
	var p: Vector3 = demo._player.global_position
	if not in_cave:
		if p.distance_to(World.NPC) < 2.8:
			if state.accept_quest():
				npc_talk(NESSA_ACCEPT)
				chat.post("Servidor", "Missão iniciada: As Três Brasas.", Color(1.0, 0.82, 0.38))
			elif state.finish_quest():
				npc_talk(NESSA_FINISH)
				chat.post("Servidor", "Missão concluída: As Três Brasas.", Color(1.0, 0.82, 0.38))
			elif state.stage == "complete":
				npc_talk(NESSA_AFTER.pick_random())
			else:
				npc_talk(NESSA_WAITING.pick_random())
			_save()
		return
	if p.distance_to(World.CHEST) < 2.2:
		if state.claim_chest():
			_equip_reward()
			demo.world_labels.announce("Colar de Brasa", "+3 poder mágico")
			object_say("chest", world.cave, World.CHEST - World.ROOM + Vector3(0, 1.8, 0), "Colar de Brasa", Color(1.0, 0.82, 0.38))
			chat.post("Servidor", "Você recebeu: Colar de Brasa.", Color(1.0, 0.82, 0.38))
			demo._shockwave(World.CHEST)
			_save()
		return
	for i in World.TORCHES.size():
		if p.distance_to(World.ROOM + World.TORCHES[i]) < 2.1:
			ignite(i)
			return

func objective() -> String:
	if state.stage == "available":
		return "Converse com Nessa no acampamento."
	if state.stage == "complete":
		return "Concluída."
	if state.has_reward():
		if not in_cave:
			return "Leve o colar de volta à Nessa."
		return "Leve o colar de volta à Nessa."
	if in_cave:
		return "Guardiões: %d/%d\nTochas acesas: %d/3" % [state.cave_kills.size(), int(config.cave_guardians), state.lit.size()]
	var distance: float = demo._player.global_position.distance_to(World.ENTRANCE)
	return "Encontre a Gruta das Raízes, a oeste.\n%d m" % ceili(distance)

func update(delta: float, t: float) -> void:
	notice_time = maxf(0, notice_time - delta)
	ring_cd = maxf(0, ring_cd - delta)
	core.update(delta)
	_potion_cd = maxf(0, _potion_cd - delta)
	_update_bubbles(delta)
	_stair_cd = maxf(0.0, _stair_cd - delta)
	if _stair_cd <= 0.0:
		_check_stairs()
	var action := prompt() if not hud.any_open() else ""
	if action == "E — conversar" and not world.npc_speech.text.is_empty():
		action = ""  # não cobre a fala da Nessa
	demo.world_labels.prompt_text = action
	demo.world_labels.prompt_at = prompt_at
	var night: bool = demo._sky.night > 0.5
	if night != _was_night:
		_was_night = night
		chat.post("Servidor", "A noite cai sobre a floresta." if night else "Amanhece em Aethra.")
	if _talk_time > 0.0:
		_talk_time -= delta
		if _talk_time <= 0.0:
			_next_line()
		elif demo._player.global_position.distance_to(World.NPC) > 12.0:
			_talk.clear()
			_talk_time = 0.0
			world.npc_speech.text = ""
	mana = minf(max_mana(), mana + float(config.mana_regen_per_second) * delta)
	_invulnerable = maxf(0, _invulnerable - delta)
	_hurt_time += delta
	if _hurt_time > float(config.regen_delay):
		hp = minf(state.max_hp(), hp + float(config.regen_per_second) * delta)
	enemies.update(delta, t)
	world.sync(state.lit, state.has_reward(), state.stage, t, demo._player.global_position)
	demo._dress.ambient.visible = not in_cave
	if in_cave:
		demo._sun.hide()
		demo._sky.moon.hide()
		demo._env.ambient_light_color = Color(0.34, 0.32, 0.46)
		demo._env.ambient_light_energy = 0.8
		demo._env.background_color = Color(0.02, 0.018, 0.03)
	else:
		demo._env.background_color = Color(0.08, 0.06, 0.1)
	hud.update()
