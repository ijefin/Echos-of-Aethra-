# PROTOTYPE - NOT FOR PRODUCTION
extends Node
## First playable slice: local quest, progression, combat, underground puzzle and return.
const State := preload("res://prototypes/pixel3d/first_adventure_state.gd")
const World := preload("res://prototypes/pixel3d/adventure_world.gd")
const Enemies := preload("res://prototypes/pixel3d/adventure_enemies.gd")
const Hud := preload("res://prototypes/pixel3d/adventure_hud.gd")
const CoreSkills := preload("res://prototypes/pixel3d/core_skills.gd")
const WorldLayout := preload("res://prototypes/pixel3d/world/world_layout.gd")
const Chat := preload("res://prototypes/pixel3d/adventure_chat.gd")
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const BUBBLE_TIME := 10.0
const ItemInventory := preload("res://src/core/inventory.gd")
const Quests := preload("res://prototypes/pixel3d/quests.gd")
const NetPlay := preload("res://prototypes/pixel3d/net/net_play.gd")
## Atributos do equipamento que mexem no jogo (diferença para o equipamento inicial).
const POWER_STATS := ["attack_power", "spell_power"]
## Cada ponto de armadura do equipamento reduz 2 % do dano recebido (teto ARMOR_CAP).
const ARMOR_PER_POINT := 0.02
const ARMOR_CAP := 0.8
const SECRET_RADIUS := 2.3
const SAVE := "user://pixel3d-first-adventure-v1.json"
var save_path := SAVE
var demo: Node
var config: Dictionary
var state
var world
var enemies
var hud
## Save antigo/novo sem vocação: o jogo abre a escolha de vocação.
var needs_vocation := false
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
## Modo online (--connect=host:porta): net/net_play.gd; null = jogo offline de sempre.
var online = null
## Evita descer/subir de novo logo depois de trocar de andar.
var _stair_cd := 0.0
var chat
var _bubbles := {}
var _was_night := false
var _talk: Array[String] = []
var _talk_time := 0.0
## Quem está falando agora ("nessa" ou id de quests.json → npcs).
var _talk_npc := "nessa"
## Missões, segredos e itens de missão (quests.gd).
var quests
## Soma dos atributos do equipamento inicial da vocação (linha de base dos bônus).
var _baseline: Dictionary = {}
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
	["Uma ermitã vive no Charco das Brumas, ao sul. Dizem que ela ouve a névoa."],
]

func build(owner_demo: Node, args: Dictionary) -> void:
	demo = owner_demo
	config = JSON.parse_string(FileAccess.get_file_as_string("res://prototypes/pixel3d/data/first_adventure.json"))
	state = State.new(config)
	_persist = not demo._capture and not args.has("no_save") and not args.has("connect")  # online: o servidor guarda
	if _persist and FileAccess.file_exists(save_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary:
			state.restore(data)
			needs_vocation = not (data as Dictionary).has("vocation") and not Engine.has_meta("aethra_class")
	elif _persist and not Engine.has_meta("aethra_class"):
		needs_vocation = true
	var voc: Dictionary = demo._voc.cfg
	state.vocation = demo._voc.id
	state.hp_mult = float(voc.hp_mult)
	inventory = ItemInventory.new(ItemInventory.load_db(), String(voc.item_class))
	inventory.give(voc.start_items)
	for id: String in voc.start_items:
		inventory.equip(id)
	_baseline = inventory.bonus()
	if state.has_reward():
		_equip_reward()
	potions = {"hp": int(config.potion.start_hp), "mana": int(config.potion.start_mana)}
	quests = Quests.new(Quests.load_data())
	quests.restore(state.content)
	_restore_content(state.content)
	if args.has("give"):  # prints/testes: --give=id,id (itens extras na bolsa, de qualquer vocação)
		inventory.give(Array(String(args.give).split(",")))
	if args.has("equip"):  # prints: --equip=id,id veste da bolsa (com --give)
		for id: String in String(args.equip).split(","):
			inventory.equip(id)
	if args.has("quest"):
		_debug_quest(String(args.quest))
	if args.has("level"):  # prints/testes
		state.level = clampi(int(args.level), 1, int(config.max_level))
	_refresh_stats()
	hp = state.max_hp()
	mana = max_mana()
	world = World.new()
	world.build(demo)
	world.build_npcs(quests.data)
	_sync_secret_marks()
	if args.has("talk"):  # print: conversa com um NPC das missões logo ao abrir
		_talk_content.call_deferred(String(args.talk))
	if args.has("secret"):  # print: revela um segredo logo ao abrir
		claim_secret.call_deferred(String(args.secret))
	enemies = Enemies.new()
	if args.has("connect"):
		enemies.adventure = self   # online: os monstros vêm do servidor (nenhum local)
		enemies.demo = demo
	else:
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
	if args.has("connect"):
		online = NetPlay.new()
		add_child(online)
		online.start(self, args)
	demo.apply_gear_look.call_deferred()

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
	var extra := int(round(gear("max_resource"))) + int(quests.perm.max_resource) if quests != null else 0
	return int(round((int(config.mana_base) + (state.level - 1) * int(config.mana_per_level)) * float(demo._voc.cfg.mana_mult))) + extra


## Bônus de um atributo do equipamento vestido acima do equipamento inicial.
func gear(stat: String) -> float:
	return float(inventory.bonus().get(stat, 0.0)) - float(_baseline.get(stat, 0.0))


## Redução de dano: armadura da vocação + armadura extra do equipamento.
func armor_ratio() -> float:
	return clampf(float(demo._voc.cfg.armor) + gear("armor") * ARMOR_PER_POINT, 0.0, ARMOR_CAP)


## Recalcula o que vem do equipamento e das relíquias (vida máxima extra).
func _refresh_stats() -> void:
	state.bonus_hp = int(round(gear("max_hp"))) + int(quests.perm.max_hp)
	hp = minf(hp, state.max_hp())
	mana = minf(mana, max_mana())


## Bolsa e poções do save (equipamento ganho em missões/segredos volta vestido).
func _restore_content(content: Dictionary) -> void:
	inventory.give(quests.owned)
	var eq: Variant = content.get("equipped", {})
	if eq is Dictionary:
		for slot: String in eq:
			var id := String(eq[slot])
			if id in inventory.items:
				inventory.equip(id)
	var saved: Variant = content.get("potions", {})
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		potions = {"hp": maxi(0, int(saved.get("hp", 0))), "mana": maxi(0, int(saved.get("mana", 0)))}


## --quest=id[:passo|offer] (prints/testes): missões anteriores concluídas, esta no passo dado.
func _debug_quest(spec: String) -> void:
	var parts := spec.split(":")
	for q: Dictionary in quests.data.quests:
		if String(q.id) == parts[0]:
			if parts.size() < 2 or parts[1] != "offer":  # offer: só as anteriores concluídas
				quests.active[parts[0]] = {"step": int(parts[1]) if parts.size() > 1 else 0, "count": 0}
			break
		quests.done.append(String(q.id))
	state.stage = "complete"


func cost(skill: String) -> int:
	return int(demo._voc.cfg.costs.get(skill, config.mana_cost.get(skill, 0)))


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
	if online != null:
		online.drink(kind)
		return
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


## NPC fala frase por frase sobre a cabeça (tempo de leitura por frase).
func npc_talk(lines: Array, who := "nessa") -> void:
	_speech().text = ""
	_talk_npc = who
	_talk.clear()
	for l: Variant in lines:
		_talk.append(String(l))
	_talk_time = 0.0
	_next_line()


func _speech() -> Label3D:
	return world.npc_speech if _talk_npc == "nessa" else world.npcs[_talk_npc].speech


func _npc_pos(who: String) -> Vector3:
	return World.NPC if who == "nessa" else world.npcs[who].pos


func _next_line() -> void:
	var speech := _speech()
	if _talk.is_empty():
		speech.text = ""
		return
	var line: String = _talk.pop_front()
	speech.text = _wrap(line, 34)
	speech.modulate.a = 1.0
	chat.post("Local", ("Nessa" if _talk_npc == "nessa" else String(world.npcs[_talk_npc].display)) + ": " + line)
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
	state.content = content_snapshot()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state.snapshot()))


## Tudo do conteúdo jogável que vai no save (dentro de state.content).
func content_snapshot() -> Dictionary:
	var out: Dictionary = quests.snapshot()
	out["potions"] = potions.duplicate()
	out["equipped"] = inventory.equipped.duplicate()
	return out

func say(text: String, seconds := 5.0) -> void:
	notice_text = text
	notice_time = seconds

func floating(text: String, at: Vector3, color: Color) -> void:
	var label: Label3D = world.label(demo._vp, text, at, color, 38)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", at.y + 0.9, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)

## Vestir um item da bolsa (painel I). Offline veste na hora e recalcula os bônus; online só
## pede ao servidor (o estado volta no evento "content"). "" = feito/pedido; senão o motivo.
func equip_item(id: String) -> String:
	if id not in inventory.items:
		return "Item não está no inventário"
	var err: String = inventory.can_use(id)
	if err != "":
		return err
	if online != null:
		online.equip(id)
		return ""
	inventory.equip(id)
	_refresh_stats()
	demo.apply_gear_look()
	chat.post("Servidor", "Você equipou: %s." % String(inventory.item(id).get("name", id)), Color(1.0, 0.82, 0.38))
	_save()
	return ""


func _equip_reward() -> void:
	var id := String(config.reward_item)
	if inventory.equipped.get("neck", "") != id:
		inventory.give([id])
		inventory.equip(id)

func basic_damage() -> int:
	# O equipamento inicial é a linha de base; arma/colar/etc. melhores somam o poder extra.
	var bonus := 0.0
	for stat: String in POWER_STATS:
		bonus += gear(stat)
	return int(round((int(config.basic_damage) + state.level - 1 + int(round(bonus))) * float(demo._voc.cfg.damage_mult)))

func on_enemy_killed(id: String, kind: String, cave: bool, at: Vector3) -> void:
	var actor: Dictionary = enemies.find(id) if enemies != null else {}
	var cfg: Dictionary = actor.get("cfg", config.enemy[kind])
	var xp_gain := int(cfg.xp)
	var old_level: int = state.level
	if not state.record_kill(id, kind, cave, xp_gain):
		return
	# Como no Tibia: número branco de XP subindo de onde o monstro morreu.
	floating("%d" % xp_gain, at + Vector3(0, 1.6, 0), Color(1, 1, 1))
	chat.post("Servidor", "Você derrotou %s. Ganhou %d de experiência." % [String(cfg.name), xp_gain])
	_quest_events(quests.on_kill(kind, String(actor.get("hunt", ""))), at)
	_level_feedback(old_level)
	_save()


## XP de recompensa (missões/segredos), com a mesma festa de subida de nível.
func gain_xp(amount: int) -> void:
	var old_level: int = state.level
	state.add_xp(amount)
	floating("%d" % amount, demo._player.global_position + Vector3(0, 2.0, 0), Color(1, 1, 1))
	chat.post("Servidor", "Você ganhou %d de experiência." % amount)
	_level_feedback(old_level)


func _level_feedback(old_level: int) -> void:
	if state.level > old_level:
		hp = state.max_hp()
		mana = max_mana()
		demo._shockwave(demo._player.global_position)
		demo._burst(demo._player.global_position + Vector3(0, 1.2, 0))
		var voc: Dictionary = demo._voc.cfg
		var unlocked := ("Nova habilidade: " + String(voc.q.name)) if state.level == int(config.blink_level) else (("Nova habilidade: " + String(voc.r.name)) if state.level == int(config.ring_level) else "")
		demo.world_labels.announce("Você subiu do nível %d para o nível %d." % [old_level, state.level], unlocked)
		chat.post("Servidor", "Você subiu do nível %d para o nível %d." % [old_level, state.level], Color(1.0, 0.82, 0.38))

func take_damage(amount: int, source := "") -> void:
	if _invulnerable > 0 or demo._blink_t >= 0 or demo._dodge_t >= 0:
		return
	amount = maxi(1, int(round(amount * (1.0 - armor_ratio()))))  # vocação + equipamento
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
	demo._player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED  # superfície e gruta: sempre com chão
	demo._player.global_position = to
	demo._player.velocity = Vector3.ZERO
	demo._cam_focus = to + Vector3(0, 0.6, 0)
	demo._update_camera(1.0)
	_invulnerable = 1.0

## Escolha de vocação (painel F2 / primeira vez): grava e recarrega a cena com o novo corpo.
func choose_vocation(id: String) -> void:
	state.vocation = id
	Engine.set_meta("aethra_class", id)
	_save()
	demo.get_tree().reload_current_scene()


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

func hit(collider: Object, amount := -1) -> bool:
	if enemies.hit(collider, basic_damage() if amount < 0 else amount):
		return true
	if collider != null and String(collider.get_meta("kind", "")) == "quest_torch":
		ignite(int(collider.get_meta("torch_index")))
		return true
	return false

func cast_ring() -> void:
	if online != null:
		online.r(demo._mouse_ground())
		return
	if not demo._voc.is_mage():
		demo._voc.cast_r()
		return
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

## Tecla 3: core skill Luz (online o servidor liga o efeito, visto por todos).
func cast_light() -> void:
	if online != null:
		if not hud.any_open():
			online.cast_light()
		return
	core.cast("light")


## Ação possível agora ("E — ...") e onde ela aparece (sobre o objeto/pessoa).
var prompt_at := Vector3.INF


func prompt() -> String:
	var p: Vector3 = demo._player.global_position
	prompt_at = Vector3.INF
	if not in_cave:
		if p.distance_to(World.NPC) < 2.8:
			prompt_at = World.NPC + Vector3(0, 3.5, 0)
			return "E — conversar"
		for id: String in world.npcs:
			var pos: Vector3 = world.npcs[id].pos
			if p.distance_to(pos) < 2.8:
				prompt_at = pos + Vector3(0, 3.5, 0)
				return "E — conversar"
		for pk: Dictionary in quests.pickups():
			var at: Vector2 = pk.at
			if Vector2(p.x, p.z).distance_to(at) < Quests.PICKUP_RADIUS:
				prompt_at = Vector3(at.x, 1.0, at.y)
				return "E — pegar"
		var sid := _secret_near(p)
		if not sid.is_empty():
			prompt_at = _secret_pos(sid) + Vector3(0, 1.9, 0)
			return "E — examinar"
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
	return WorldLayout.region_name(p)


## Segredo (marco de pedras) ainda não revelado ao alcance do jogador.
func _secret_near(p: Vector3) -> String:
	if demo._props == null:
		return ""
	for s: Dictionary in demo._props.secrets:
		var c: Vector2 = s.position
		if not (String(s.id) in quests.secrets) and Vector2(p.x, p.z).distance_to(c) < SECRET_RADIUS:
			return String(s.id)
	return ""


func _secret_pos(id: String) -> Vector3:
	for s: Dictionary in demo._props.secrets:
		if String(s.id) == id:
			return Vector3((s.position as Vector2).x, 0, (s.position as Vector2).y)
	return Vector3.ZERO


## Marcos já revelados brilham (save carregado ou recém-descobertos).
func _sync_secret_marks() -> void:
	if demo._props == null:
		return
	for s: Dictionary in demo._props.secrets:
		if String(s.id) in quests.secrets:
			world.secret_glow(s.node)


## Revela um segredo: recompensa única, efeito no marco, mensagem central e no Servidor.
func claim_secret(id: String) -> bool:
	var entry: Dictionary = quests.claim_secret(id)
	if entry.is_empty():
		return false
	var at := _secret_pos(id)
	object_say("secret_" + id, demo._vp, at + Vector3(0, 2.4, 0), _wrap(String(entry.found), 34), Color(0.7, 0.88, 1.0))
	demo._shockwave(at)
	demo._burst(at + Vector3(0, 1.0, 0))
	_sync_secret_marks()
	_apply_reward(entry.get("reward", {}), String(entry.name), String(entry.get("announce", "")))
	chat.post("Servidor", "Você descobriu um segredo: %s." % String(entry.name), Color(0.6, 0.85, 1.0))
	_save()
	return true


## XP, poções, equipamento da vocação (vestido na hora) e bônus permanentes.
func _apply_reward(reward: Dictionary, title: String, sub := "") -> void:
	var lines: Array[String] = []
	var items: Dictionary = reward.get("items", {})
	var item_id := String(items.get(String(demo._voc.id), ""))
	if not item_id.is_empty() and not inventory.item(item_id).is_empty():
		var before_dmg := basic_damage()
		var before_armor := armor_ratio()
		var before_hp: int = state.max_hp()
		var before_mana := max_mana()
		inventory.give([item_id])
		quests.owned.append(item_id)
		inventory.equip(item_id)
		_refresh_stats()
		demo.apply_gear_look()
		var it_name := String(inventory.item(item_id).name)
		chat.post("Servidor", "Você recebeu: %s." % it_name, Color(1.0, 0.82, 0.38))
		var gains: Array[String] = []
		if basic_damage() > before_dmg:
			gains.append("+%d de dano" % (basic_damage() - before_dmg))
		if armor_ratio() > before_armor + 0.001:
			gains.append("+%d%% de armadura" % roundi((armor_ratio() - before_armor) * 100.0))
		if state.max_hp() > before_hp:
			gains.append("+%d de vida" % (state.max_hp() - before_hp))
		if max_mana() > before_mana:
			gains.append("+%d de mana" % (max_mana() - before_mana))
		title = it_name
		sub = "  ".join(gains)
	var perm: Dictionary = reward.get("perm", {})
	for k: String in perm:
		quests.perm[k] = int(quests.perm.get(k, 0)) + int(perm[k])
	if not perm.is_empty():
		_refresh_stats()
		hp = state.max_hp()
		mana = max_mana()
	var pots: Dictionary = reward.get("potions", {})
	for k: String in pots:
		potions[k] = int(potions.get(k, 0)) + int(pots[k])
		chat.post("Servidor", "Você recebeu %d poções de %s." % [int(pots[k]), "vida" if k == "hp" else "mana"], Color(1.0, 0.82, 0.38))
	var old_level: int = state.level
	if int(reward.get("xp", 0)) > 0:
		gain_xp(int(reward.xp))
	if not title.is_empty():
		if state.level > old_level and is_inside_tree():
			# a mensagem de nível vem primeiro; a do prêmio entra quando ela some
			get_tree().create_timer(4.6).timeout.connect(demo.world_labels.announce.bind(title, sub))
		else:
			demo.world_labels.announce(title, sub)


## Eventos das missões (abate, coleta, chegada): itens de missão e diário atualizado.
func _quest_events(events: Array, at: Vector3) -> void:
	for ev: Dictionary in events:
		if ev.has("drop"):
			var it_name: String = quests.item_name(String(ev.drop))
			chat.post("Servidor", "Você encontrou: %s." % it_name, Color(1.0, 0.82, 0.38))
			floating(it_name, at + Vector3(0, 2.1, 0), Color(1.0, 0.82, 0.38))
		if String(ev.type) == "step":
			chat.post("Servidor", "Diário atualizado: %s." % String(quests.quest(String(ev.quest)).name), Color(1.0, 0.82, 0.38))


func _talk_content(id: String) -> void:
	var r: Dictionary = quests.talk(id, state.level)
	npc_talk(r.lines, id)
	var q: Dictionary = quests.quest(String(r.quest))
	match String(r.event):
		"accept":
			chat.post("Servidor", "Missão iniciada: %s." % String(q.name), Color(1.0, 0.82, 0.38))
		"step":
			chat.post("Servidor", "Diário atualizado: %s." % String(q.name), Color(1.0, 0.82, 0.38))
		"complete":
			chat.post("Servidor", "Missão concluída: %s." % String(q.name), Color(1.0, 0.82, 0.38))
			demo._shockwave(demo._player.global_position)
			_apply_reward(r.get("reward", {}), String(q.name), "Missão concluída")
	_save()


## Online: o que a tecla E pediria agora (mesma ordem do interact offline). O servidor
## confere a distância e responde com o resultado (net_play._on_content).
func interact_target() -> String:
	var p: Vector3 = demo._player.global_position
	if not in_cave:
		for id: String in world.npcs:
			if p.distance_to(world.npcs[id].pos) < 2.8:
				return "npc:" + id
		for pk: Dictionary in quests.pickups():
			if Vector2(p.x, p.z).distance_to(pk.at) <= Quests.PICKUP_RADIUS:
				return "pickup"
		var sid := _secret_near(p)
		if not sid.is_empty():
			return "secret:" + sid
		return "nessa" if p.distance_to(World.NPC) < 2.8 else ""
	if p.distance_to(World.CHEST) < 2.2:
		return "chest"
	for i in World.TORCHES.size():
		if p.distance_to(World.ROOM + World.TORCHES[i]) < 2.1:
			return "torch:%d" % i
	return ""


func interact() -> void:
	if online != null:
		online.interact(interact_target())
		return
	var p: Vector3 = demo._player.global_position
	if not in_cave:
		for id: String in world.npcs:
			if p.distance_to(world.npcs[id].pos) < 2.8:
				_talk_content(id)
				return
		var picked: Dictionary = quests.pickup(Vector2(p.x, p.z))
		if not picked.is_empty():
			demo._burst(p + Vector3(0, 0.6, 0))
			_quest_events([picked], p)
			_save()
			return
		var sid := _secret_near(p)
		if not sid.is_empty():
			claim_secret(sid)
			return
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

## Título do painel de objetivo no canto (missão que o objetivo descreve).
func objective_title() -> String:
	if state.stage in ["available", "active", "claimed"]:
		return "NESSA · AS TRÊS BRASAS"
	var ids: Array[String] = quests.active_ids()
	if not ids.is_empty():
		return String(quests.quest(ids[0]).name).to_upper()
	return "AETHRA"


## Objetivo de uma missão do conteúdo: frase de história + distância quando é um lugar.
func quest_objective(id: String) -> String:
	var s: Dictionary = quests.step(id)
	var text := _wrap(String(s.get("text", "")), 40)
	var target := Vector3.INF
	match String(s.get("type", "")):
		"talk":
			target = _npc_pos(String(s.npc))
		"reach":
			target = Vector3(float(s.at[0]), 0, float(s.at[1]))
		"collect":
			if s.has("at"):
				target = Vector3(float(s.at[0]), 0, float(s.at[1]))
	if target != Vector3.INF and not in_cave:
		var d: float = demo._player.global_position.distance_to(target)
		if d > 6.0:
			text += "\n%d m" % ceili(d)
	return text


## Próximo NPC com missão nova: frase de onde ele está.
func _next_giver() -> String:
	for q: Dictionary in quests.data.quests:
		var st: String = quests.status(String(q.id), state.level)
		if st == "available" or st == "weak":
			var n: Dictionary = quests.npc(String(q.giver))
			var pos := _npc_pos(String(q.giver))
			return _wrap("%s espera %s." % [String(n.name), WorldLayout.region_name(Vector2(pos.x, pos.z))], 40)
	return ""


func objective() -> String:
	if state.stage == "available":
		return "Converse com Nessa no acampamento."
	if state.stage == "complete":
		var ids: Array[String] = quests.active_ids()
		if not ids.is_empty():
			return quest_objective(ids[0])
		var next := _next_giver()
		return next if not next.is_empty() else "Concluída."
	if state.has_reward():
		if not in_cave:
			return "Leve o colar de volta à Nessa."
		return "Leve o colar de volta à Nessa."
	if in_cave:
		return "Guardiões: %d/%d\nTochas acesas: %d/3" % [state.cave_kills.size(), int(config.cave_guardians), state.lit.size()]
	var distance: float = demo._player.global_position.distance_to(World.ENTRANCE)
	return "Encontre a Gruta das Raízes, a oeste.\n%d m" % ceili(distance)

## Passos "reach", objetos de missão visíveis só quando servem, marcadores dos NPCs.
func _update_content() -> void:
	var p: Vector3 = demo._player.global_position
	if not in_cave and online == null:  # online: o servidor confere os passos "chegue a"
		var events: Array = quests.on_reach(Vector2(p.x, p.z))
		if not events.is_empty():
			_quest_events(events, p)
			_save()
	var wanted := {}
	for pk: Dictionary in quests.pickups():
		var key := String(pk.quest) + ":" + String(pk.item)
		wanted[key] = true
		world.pickup_node(key, pk.at, quests.item_name(String(pk.item))).visible = not in_cave
	for key: String in world.pickup_nodes:
		if not wanted.has(key):
			(world.pickup_nodes[key] as Node3D).visible = false
	world.pickup_names(p)
	var markers := {}
	for id: String in world.npcs:
		markers[id] = quests.marker(id, state.level)
	world.sync_npcs(p, markers)


func update(delta: float, t: float) -> void:
	notice_time = maxf(0, notice_time - delta)
	ring_cd = maxf(0, ring_cd - delta)
	core.update(delta)
	_potion_cd = maxf(0, _potion_cd - delta)
	_update_bubbles(delta)
	_stair_cd = maxf(0.0, _stair_cd - delta)
	if _stair_cd <= 0.0 and online == null:  # online: o servidor só conhece a superfície
		_check_stairs()
	var action := prompt() if not hud.any_open() else ""
	if action == "E — conversar" and not _speech().text.is_empty():
		action = ""  # não cobre a fala de quem está falando
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
		elif demo._player.global_position.distance_to(_npc_pos(_talk_npc)) > 12.0:
			_talk.clear()
			_talk_time = 0.0
			_speech().text = ""
	_update_content()
	_invulnerable = maxf(0, _invulnerable - delta)
	_hurt_time += delta
	if online != null:
		online.update(delta)   # vida/mana/nível/XP/poções/recargas e monstros vêm do servidor
	else:
		mana = minf(max_mana(), mana + float(config.mana_regen_per_second) * delta)
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
