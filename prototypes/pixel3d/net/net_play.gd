# PROTOTYPE - NOT FOR PRODUCTION
extends Node
## Modo ONLINE do protótipo (pixel3d_demo + pixel3d_adventure):
##   --connect=host:porta --user=Nome --pass=senha [--register] [--class=mage|warrior|archer]
## Sem --connect nada disto é criado e o jogo fica exatamente como offline.
##
## Online o servidor manda em tudo que importa: posição (predição + reconciliação do
## NetClient), vida, mana, nível, XP, poções, recargas, monstros, projéteis e dano.
## Aqui fica só a cola com o jogo: espelhar o estado do servidor no HUD, transformar
## teclas/cliques em pedidos, desenhar outros jogadores/monstros/projéteis do snapshot
## (nome + barra de vida estilo Tibia pelo overlay de textos, telegraph, teia, Luz) e
## ligar chat e amigos.

const NetGame := preload("res://prototypes/pixel3d/net/net_game.gd")
const Protocol := preload("res://prototypes/pixel3d/net/net_protocol.gd")
const Vocations := preload("res://prototypes/pixel3d/vocations.gd")
const Enemies := preload("res://prototypes/pixel3d/adventure_enemies.gd")
const AdvWorld := preload("res://prototypes/pixel3d/adventure_world.gd")
const DashMotion := preload("res://prototypes/pixel3d/net/dash_motion.gd")

## canal do servidor → aba do chat
const CHAT_TAB := {"local": "Local", "global": "Servidor", "server": "Servidor", "private": "Grupo"}
## aba do chat → canal do servidor (Grupo/PvP ainda não têm canal próprio: vão como global)
const TAB_CHANNEL := {"Local": "local", "Servidor": "global", "Grupo": "global", "PvP": "global"}

var adventure
var demo
var net: Node
var welcome := {}
var friends := {"friends": [], "incoming": [], "outgoing": []}
var failed := ""
var remotes := {}           # id → registro visual
var _builder                # adventure_enemies sem build(): só os modelos dos monstros
var _root: Node3D           # visuais remotos (dentro do SubViewport do mundo)
var _dodge_sent := false
var _light_left := 0.0
var _ring_mat: StandardMaterial3D
var _ring_mesh := TorusMesh.new()
var _args := {}
## Investida/salto do próprio jogador em andamento (DashMotion); {} = nenhum.
var _dash := {}
## Itens largados no chão (servidor manda): gid → {item, pos, floor, node, label}.
var ground := {}
const GROUND_TAKE_M := 1.6


## `owner_adventure` = pixel3d_adventure (já com world/hud/chat montados).
func start(owner_adventure, args: Dictionary) -> void:
	adventure = owner_adventure
	demo = adventure.demo
	_args = args
	name = "NetPlay"
	_builder = Enemies.new()
	_builder.adventure = adventure
	_builder.demo = demo
	_root = Node3D.new()
	_root.name = "NetRemotes"
	demo._vp.add_child(_root)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(1.0, 0.35, 0.15, 0.85)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mesh.inner_radius = 0.85
	_ring_mesh.outer_radius = 1.0
	net = NetGame.new()
	net.name = "NetGame"
	add_child(net)
	net.online_started.connect(_on_welcome)
	net.online_failed.connect(func(code: String) -> void:
		failed = code
		adventure.chat.post("Servidor", "Não foi possível entrar (%s)." % code, Color(1.0, 0.55, 0.5)))
	net.connection_lost.connect(func(_r: String) -> void: adventure.chat.post("Servidor", "Conexão perdida. Tentando voltar...", Color(1.0, 0.55, 0.5)))
	net.combat_event.connect(_on_event)
	net.chat_received.connect(_on_chat)
	net.friends_updated.connect(func(l: Dictionary) -> void: friends = l)
	net.friend_event.connect(_on_friend_event)
	var hp: Array = NetGame.parse_address(String(args.get("connect", "127.0.0.1:7777")))
	net.start(String(hp[0]), int(hp[1]), String(args.get("user", "")), String(args.get("pass", "")),
		args.has("register"), null, Callable(), String(demo._voc.id))


## Prints de rede (tools/net_dash_shot.sh): --auto_q=S usa Q S segundos depois de entrar, na
## direção --auto_q_dir=x,z (6 m); --dash_shot=res://x.png tira o print --dash_shot_after=S
## depois que OUTRO jogador começa a investida/salto (pega o meio do deslizamento).
func _auto_q() -> void:
	await get_tree().create_timer(float(_args.get("auto_q", 6.0))).timeout
	var d := String(_args.get("auto_q_dir", "1,0")).split(",")
	var dir := Vector3(float(d[0]), 0, float(d[1]) if d.size() > 1 else 0.0).normalized()
	q(demo._player.global_position + dir * 6.0)


## Print do chão (tools/net_drop_shot.sh): --auto_drop=S tira o item da cabeça S segundos depois
## de entrar e larga no chão (o outro cliente fotografa o saquinho com o nome).
func _auto_drop() -> void:
	await get_tree().create_timer(float(_args.get("auto_drop", 6.0))).timeout
	var id := String(adventure.inventory.equipped.get("head", ""))
	if id.is_empty():
		return
	unequip("head")
	await get_tree().create_timer(1.0).timeout
	drop(id)


func _dash_shot() -> void:
	if not _args.has("dash_shot") or _args.has("_dash_shot_done"):
		return
	_args["_dash_shot_done"] = true
	await get_tree().create_timer(float(_args.get("dash_shot_after", 0.1))).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(String(_args.dash_shot))
	demo.get_viewport().get_texture().get_image().save_png(path)
	print("DASH_SHOT ", path)


func is_online() -> bool:
	return net != null and net.is_online()


func my_id() -> int:
	return int(net.client.eid) if net != null else 0


func _on_welcome(w: Dictionary) -> void:
	welcome = w
	var v := String(w.get("vocation", demo._voc.id))
	if v != String(demo._voc.id):
		adventure.chat.post("Servidor", "Seu personagem é %s." % String(demo._voc.all.classes.get(v, {}).get("name", v)))
	demo._player.global_position = net.local_position()
	demo._cam_focus = demo._player.global_position
	_apply_content(w.get("content", {}))
	for gid: int in ground.keys():
		_ground_del(gid)
	for g: Variant in w.get("ground", []):
		if g is Dictionary:
			_ground_add(g)
	if _args.has("auto_q"):
		_auto_q()
	if _args.has("auto_drop"):
		_auto_drop()


# ------------------------------------------------------------------ conteúdo (servidor manda)

## Espelha o conteúdo do servidor: diário/segredos/itens de missão (quests), bolsa e
## equipamento, estágio da Nessa e tochas. O cliente só mostra.
func _apply_content(s: Variant) -> void:
	if not (s is Dictionary) or (s as Dictionary).is_empty():
		return
	adventure.quests.restore(s.get("quests", {}))
	adventure.state.stage = String(s.get("stage", adventure.state.stage))
	adventure.state.lit.assign(s.get("lit", []))
	adventure.state.cave_kills.clear()
	for k: Variant in s.get("guardians", []):
		adventure.state.cave_kills[String(k)] = true
	var inv = adventure.inventory
	inv.items.assign(s.get("bag", inv.items))
	adventure.gold = int(s.get("gold", adventure.gold))
	var eq: Variant = s.get("equipped", {})
	if eq is Dictionary:
		inv.equipped = (eq as Dictionary).duplicate()
	adventure._refresh_stats()
	demo.apply_gear_look()
	adventure._sync_secret_marks()


## Resultado de um pedido de conteúdo (ou progresso de abate/chegada): falas, diário e festa.
func _on_content(ev: Dictionary) -> void:
	var gold := Color(1.0, 0.82, 0.38)
	var me: Vector3 = demo._player.global_position
	match String(ev.get("what", "")):
		"talk":
			var npc := String(ev.get("npc", ""))
			if adventure.world.npcs.has(npc):
				adventure.npc_talk(ev.get("lines", []), npc)
			var qname := String(adventure.quests.quest(String(ev.get("quest", ""))).get("name", ""))
			match String(ev.get("event", "")):
				"accept":
					adventure.chat.post("Servidor", "Missão iniciada: %s." % qname, gold)
				"step":
					adventure.chat.post("Servidor", "Diário atualizado: %s." % qname, gold)
				"complete":
					adventure.chat.post("Servidor", "Missão concluída: %s." % qname, gold)
					demo._shockwave(me)
					_show_reward(ev.get("reward", {}), qname, "Missão concluída")
		"quest":
			var at: Array = ev.get("at", [me.x, me.z])
			var p := Vector3(float(at[0]), 0, float(at[1])) if at.size() >= 2 else me
			adventure._quest_events(ev.get("events", []), p)
		"secret":
			var id := String(ev.get("id", ""))
			var entry: Dictionary = (adventure.quests.data.secrets as Dictionary).get(id, {})
			var at3: Vector3 = adventure._secret_pos(id)
			adventure.object_say("secret_" + id, demo._vp, at3 + Vector3(0, 2.4, 0), adventure._wrap(String(entry.get("found", "")), 34), Color(0.7, 0.88, 1.0))
			demo._shockwave(at3)
			demo._burst(at3 + Vector3(0, 1.0, 0))
			_show_reward(ev.get("reward", {}), String(entry.get("name", "")), String(entry.get("announce", "")))
			adventure.chat.post("Servidor", "Você descobriu um segredo: %s." % String(entry.get("name", "")), Color(0.6, 0.85, 1.0))
		"nessa":
			match String(ev.get("result", "")):
				"accept":
					adventure.npc_talk(adventure.NESSA_ACCEPT)
					adventure.chat.post("Servidor", "Missão iniciada: As Três Brasas.", gold)
				"finish":
					adventure.npc_talk(adventure.NESSA_FINISH)
					adventure.chat.post("Servidor", "Missão concluída: As Três Brasas.", gold)
				"after":
					adventure.npc_talk(adventure.NESSA_AFTER.pick_random())
				_:
					adventure.npc_talk(adventure.NESSA_WAITING.pick_random())
			if bool(ev.get("shop", false)):
				adventure.hud.open_shop()
		"chest":
			var item_label := String(ev.get("item_name", "Colar de Brasa"))
			demo.world_labels.announce(item_label, "  ".join(ev.get("gains", [])))
			adventure.object_say("chest", adventure.world.cave, AdvWorld.CHEST - AdvWorld.ROOM + Vector3(0, 1.8, 0), item_label, gold)
			adventure.chat.post("Servidor", "Você recebeu: %s." % item_label, gold)
			demo._shockwave(AdvWorld.CHEST)
		"equip":
			adventure.chat.post("Servidor", "Você equipou: %s." % String(ev.get("item_name", "")), gold)
			adventure.hud.equip_done(String(adventure.inventory.item(String(ev.get("item", ""))).get("slot", "")))
		"unequip":
			adventure.chat.post("Servidor", "Você desequipou: %s." % String(ev.get("item_name", "")))
			adventure.hud.unequip_done(String(ev.get("slot", "")))
		"buy":
			adventure.hud.shop_done()
		"sell":
			adventure.chat.post("Servidor", "Você vendeu %s por %d moedas de ouro." % [String(ev.get("item_name", "")), int(ev.get("price", 0))])
			adventure.hud.shop_done()
		"take":
			var nm := String(adventure.inventory.item(String(ev.get("item", ""))).get("name", ""))
			adventure.chat.post("Servidor", "Você pegou: %s." % nm, gold)
		"trade":
			var names: Array[String] = []
			for id: Variant in ev.get("got", []):
				names.append(String(adventure.inventory.item(String(id)).get("name", id)))
			adventure.chat.post("Servidor", "Troca com %s concluída%s" % [String(ev.get("with", "")), (": " + ", ".join(names) + ".") if not names.is_empty() else "."], gold)


## Mesma apresentação do _apply_reward offline, com os números que o servidor aplicou.
func _show_reward(r: Variant, title: String, sub: String) -> void:
	if not (r is Dictionary):
		return
	var rw: Dictionary = r
	var gold := Color(1.0, 0.82, 0.38)
	if not String(rw.get("item", "")).is_empty():
		var it_name := String(rw.get("item_name", rw.item))
		adventure.chat.post("Servidor", "Você recebeu: %s." % it_name, gold)
		title = it_name
		sub = "  ".join(rw.get("gains", []))
	var pots: Dictionary = rw.get("potions", {})
	for k: String in pots:
		adventure.chat.post("Servidor", "Você recebeu %d poções de %s." % [int(pots[k]), "vida" if k == "hp" else "mana"], gold)
	if int(rw.get("gold", 0)) > 0:
		adventure.chat.post("Servidor", "Você recebeu %d moedas de ouro." % int(rw.gold), gold)
	var xp := int(rw.get("xp", 0))
	if xp > 0:
		adventure.floating("%d" % xp, demo._player.global_position + Vector3(0, 2.0, 0), Color(1, 1, 1))
		adventure.chat.post("Servidor", "Você ganhou %d de experiência." % xp)
	if title.is_empty():
		return
	if int(rw.get("level_to", 0)) > int(rw.get("level_from", 0)) and is_inside_tree():
		# a mensagem de nível (evento "level") vem primeiro; a do prêmio entra quando ela some
		get_tree().create_timer(4.6).timeout.connect(demo.world_labels.announce.bind(title, sub))
	else:
		demo.world_labels.announce(title, sub)


## Tecla E online: pede ao servidor (ele confere a distância na posição dele).
func interact(target: String) -> void:
	if target.is_empty() or not is_online():
		return
	if target.begins_with("torch:"):
		net.client.action("torch", {"index": int(target.get_slice(":", 1))})
		return
	if target.begins_with("ground:"):
		net.client.action("take", {"gid": int(target.get_slice(":", 1))})
		return
	net.client.action("interact", {"target": target})


## Vestir um item da bolsa (o servidor valida vocação/slot e recalcula os bônus).
func equip(item_id: String) -> void:
	if is_online():
		net.client.action("equip", {"item": item_id})


## Tirar do slot para a bolsa (o servidor confere espaço e recalcula os bônus).
func unequip(slot: String) -> void:
	if is_online():
		net.client.action("unequip", {"slot": slot})


## Troca com a Nessa: o servidor confere distância e ouro.
func buy(kind: String) -> void:
	if is_online():
		net.client.action("buy", {"kind": kind})


func sell(item_id: String) -> void:
	if is_online():
		net.client.action("sell", {"item": item_id})


## Largar no chão (todos veem por um tempo; qualquer um pega com E).
func drop(item_id: String) -> void:
	if is_online():
		net.client.action("drop", {"item": item_id})


## Pedir troca a outro jogador já oferecendo um item (o canal confiável mantém a ordem).
func trade_ask(eid: int, item_id := "") -> void:
	if not is_online():
		return
	net.client.action("trade_ask", {"target": eid})
	if not item_id.is_empty():
		net.client.action("trade_add", {"item": item_id})


func trade_add(item_id: String) -> void:
	if is_online():
		net.client.action("trade_add", {"item": item_id})


func trade_remove(item_id: String) -> void:
	if is_online():
		net.client.action("trade_remove", {"item": item_id})


func trade_ok() -> void:
	if is_online():
		net.client.action("trade_ok")


func trade_cancel() -> void:
	if is_online():
		net.client.action("trade_cancel")


## Outro jogador mais perto de `at` (no chão) dentro de `radius`; 0 = nenhum.
func player_near(at: Vector3, radius: float) -> int:
	var best := 0
	var bd := radius
	for id: int in remotes:
		var r: Dictionary = remotes[id]
		if int(r.kind) != Protocol.KIND_PLAYER:
			continue
		var p: Vector3 = (r.root as Node3D).global_position
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d <= bd:
			bd = d
			best = id
	return best


func ground_pos_of_player(eid: int) -> Vector3:
	return (remotes[eid].root as Node3D).global_position if remotes.has(eid) else Vector3.INF


# ------------------------------------------------------------------ itens no chão

## Item no chão mais perto do jogador ao alcance de pegar; 0 = nenhum.
func ground_near(p: Vector3) -> int:
	var best := 0
	var bd := GROUND_TAKE_M
	var fl := -1 if adventure.in_cave else 0
	for gid: int in ground:
		var g: Dictionary = ground[gid]
		if int(g.floor) != fl:
			continue
		var d := Vector2(p.x - (g.pos as Vector3).x, p.z - (g.pos as Vector3).z).length()
		if d <= bd:
			bd = d
			best = gid
	return best


func ground_pos(gid: int) -> Vector3:
	return ground[gid].pos if ground.has(gid) else Vector3.INF


## Saquinho no chão com a cor do item; o nome aparece só de perto (como a insígnia).
func _ground_add(g: Dictionary) -> void:
	var gid := int(g.get("gid", 0))
	if gid <= 0 or ground.has(gid):
		return
	var at: Array = g.get("at", [0.0, 0.0])
	var pos := Vector3(float(at[0]), float(g.get("y", 0.0)), float(at[1]))
	var id := String(g.get("item", ""))
	var it: Dictionary = adventure.inventory.item(id)
	var node := Node3D.new()
	node.name = "Ground%d" % gid
	_root.add_child(node)
	node.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.22, 0.4)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	var c: Array = it.get("color", [0.6, 0.5, 0.35])
	mat.albedo_color = Color(float(c[0]), float(c[1]), float(c[2])).lightened(0.35)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.6
	mi.material_override = mat
	mi.position = Vector3(0, 0.08, 0)
	mi.rotation.y = float(gid % 7) * 0.7
	node.add_child(mi)
	var lab: Label3D = adventure.world.label(node, String(it.get("name", id)), Vector3(0, 0.5, 0), adventure.hud._rarity_color(it) if it.has("slot") else Color(1, 1, 1), 28)
	lab.visible = false
	ground[gid] = {"item": id, "pos": pos, "floor": int(g.get("floor", 0)), "node": node, "label": lab}


func _ground_del(gid: int) -> void:
	if not ground.has(gid):
		return
	var node: Node3D = ground[gid].node
	if is_instance_valid(node):
		demo._burst(node.global_position + Vector3(0, 0.3, 0))
		node.queue_free()
	ground.erase(gid)


func _update_ground() -> void:
	var me: Vector3 = demo._player.global_position
	for gid: int in ground:
		var g: Dictionary = ground[gid]
		(g.label as Label3D).visible = me.distance_to(g.pos) < 6.0


# ------------------------------------------------------------------ quadro

## Física do jogador local online: manda a entrada e põe o corpo na posição prevista.
func physics(delta: float, input: Vector2) -> void:
	var dodge := false
	if demo._dodge_t >= 0.0:
		if not _dodge_sent:
			dodge = true
			_dodge_sent = true
		demo._dodge_t += delta
		if demo._dodge_t >= demo._dash_len:
			demo._end_dash()
	else:
		_dodge_sent = false
	net.send_move(input, dodge)
	var np: Vector3 = net.local_position()
	var cave := np.y < -4.0
	if cave != bool(adventure.in_cave):
		_dash = {}
		adventure.warp(np, cave)   # escada/gruta decidida pelo servidor: troca o andar visível
	if DashMotion.active(_dash):
		np = DashMotion.step(_dash, delta, np)   # investida/salto: desliza até a posição do servidor
	var v: Vector3 = (np - demo._player.global_position) / maxf(delta, 0.001)
	v.y = 0.0
	demo._player.velocity = v
	demo._player.global_position = np


## Espelha o estado do servidor (HUD/recargas/Luz) e desenha as entidades remotas.
func update(delta: float) -> void:
	if not is_online():
		return
	var me: Dictionary = net.me()
	if not me.is_empty():
		adventure.hp = float(me.hp)
		adventure.mana = float(me.mana)
		adventure.state.level = int(me.level)
		adventure.state.xp = int(me.xp)
		adventure.potions = {"hp": int(me.pot_hp), "mana": int(me.pot_mana)}
		adventure.ring_cd = float(me.cd_ring)
		adventure._potion_cd = float(me.cd_potion)
		demo._blink_cd = float(me.cd_blink)
		var lit := (int(me.effects) & (1 << Protocol.EFFECTS.find("light"))) != 0
		_light_left = maxf(0.1, _light_left - delta) if lit else 0.0
		adventure.core.set_effects({"light": _light_left})
	_sync_remotes(delta)
	_update_ground()


# ------------------------------------------------------------------ pedidos

## Ataque básico: o servidor valida alcance, visão, recarga e mana e cria o projétil/golpe.
func attack(target: Vector3, node: Node) -> void:
	if node != null and String(node.get_meta("kind", "")) == "quest_torch":
		net.client.action("torch", {"index": int(node.get_meta("torch_index", -1))})
		return
	net.fire_at(_net_id(node), target)


## Momento do golpe na animação: só o visual local (o dano vem do servidor).
func primary_fx() -> void:
	if String(demo._voc.cfg.attack) == "melee":
		demo._voc._slash_fx(float(demo._voc.cfg.melee_range), float(demo._voc.cfg.melee_arc_deg))


func q(point: Vector3) -> void:
	if not adventure.state.has_skill("blink") or demo._blink_cd > 0.0:
		return
	net.q_at(point)
	if not demo._voc.is_mage():
		demo._play_once(String(demo._voc.cfg.q.get("anim", "Dodge_Forward")), 1.6)


func r(point: Vector3) -> void:
	if not adventure.state.has_skill("ring") or adventure.ring_cd > 0.0:
		return
	net.r_at(point)
	var rid := String(demo._voc.cfg.r.id)
	if rid == "ring":
		demo._shockwave(demo._player.global_position, float(adventure.config.ring_radius))
	elif rid == "whirl":
		demo._play_once(String(demo._voc.cfg.r.get("anim", "2H_Melee_Attack_Spin")), 1.4)
	else:
		demo._play_once(String(demo._voc.cfg.attack_anim), 1.6)


func cast_light() -> void:
	var s: Dictionary = adventure.core.skill("light")
	if adventure.mana < float(s.mana):
		adventure.hud.flash_mana()
		return
	net.cast_light()
	adventure.player_say(String(s.words))


func drink(kind: String) -> void:
	net.drink(kind)


## Texto digitado no chat (aba ativa).
func say(tab: String, text: String) -> void:
	net.say(String(TAB_CHANNEL.get(tab, "local")), text)


func friend(op: String, other: String) -> void:
	net.friend(op, other)


func _net_id(node: Node) -> int:
	var n := node
	while n != null:
		if n.has_meta("net_id"):
			return int(n.get_meta("net_id"))
		n = n.get_parent()
	return 0


# ------------------------------------------------------------------ eventos do servidor

func _pos_of(id: int, fallback: Array) -> Vector3:
	if id == my_id():
		return demo._player.global_position
	if remotes.has(id):
		return (remotes[id].root as Node3D).global_position
	return Vector3(float(fallback[0]), 0, float(fallback[1])) if fallback.size() >= 2 else Vector3.ZERO


func _on_event(ev: Dictionary) -> void:
	var at: Array = ev.get("at", [])
	match String(ev.get("type", "")):
		"damage":
			var tid := int(ev.get("target", 0))
			var amount := int(ev.get("amount", 0))
			if tid == my_id():
				adventure._hurt_time = 0.0
				adventure.floating("-%d" % amount, demo._player.global_position + Vector3(0, 1.7, 0), Color(1, 0.30, 0.25))
				var src := String(ev.get("source", ""))
				adventure.chat.post("Servidor", "Você perdeu %d de vida por um ataque de %s." % [amount, src] if not src.is_empty() else "Você perdeu %d de vida." % amount, Color(1.0, 0.55, 0.5))
			else:
				adventure.floating("-%d" % amount, _pos_of(tid, at) + Vector3(0, 1.0, 0), Color(1, 0.77, 0.37))
		"kill":
			var p := _pos_of(int(ev.get("target", 0)), at)
			adventure.floating("%d" % int(ev.get("xp", 0)), p + Vector3(0, 1.6, 0), Color(1, 1, 1))
			demo._burst(p + Vector3(0, 0.7, 0))
			adventure.chat.post("Servidor", "Você derrotou %s. Ganhou %d de experiência." % [String(ev.get("name", "")), int(ev.get("xp", 0))])
			if ev.has("gold_total"):
				adventure.gain_gold(int(ev.get("gold", 0)), p, int(ev.gold_total))
			# o progresso das missões vem do servidor no evento "content" logo a seguir
		"content":
			_apply_content(ev.get("state", {}))
			_on_content(ev)
		"level":
			var old := int(ev.get("from", 1))
			var lv := int(ev.get("level", 1))
			demo._shockwave(demo._player.global_position)
			demo._burst(demo._player.global_position + Vector3(0, 1.2, 0))
			var voc: Dictionary = demo._voc.cfg
			var unlocked := ("Nova habilidade: " + String(voc.q.name)) if lv == int(adventure.config.blink_level) else (("Nova habilidade: " + String(voc.r.name)) if lv == int(adventure.config.ring_level) else "")
			demo.world_labels.announce("Você subiu do nível %d para o nível %d." % [old, lv], unlocked)
			adventure.chat.post("Servidor", "Você subiu do nível %d para o nível %d." % [old, lv], Color(1.0, 0.82, 0.38))
		"death":
			adventure.npc_talk(["Calma... você ainda respira.", "Descanse um pouco perto do fogo."])
		"blink", "dash":
			if at.size() >= 2:
				var to := Vector3(float(at[0]), 0, float(at[1]))
				demo._burst(to + Vector3(0, 0.6, 0))
				var fr: Array = ev.get("from", [])
				if fr.size() >= 2:
					demo._ghost(Vector3(float(fr[0]), 0, float(fr[1])), 0.5, 0.3)
				if String(ev.get("type", "")) == "dash":
					# investida/salto: desliza (o Eco do mago continua sendo teleporte)
					var who := int(ev.get("eid", 0))
					var t := float(ev.get("time", 0.3))
					if who == my_id():
						# parte de "from" do servidor: se o snapshot chegou antes do evento, não fica parado no destino
						var start: Vector3 = demo._player.global_position
						if fr.size() >= 2:
							start = Vector3(float(fr[0]), start.y, float(fr[1]))
						_dash = DashMotion.start(start, to, t)
					elif remotes.has(who):
						var rr: Dictionary = remotes[who]
						var rp: Vector3 = (rr.root as Node3D).position
						rr.dash = DashMotion.start(rp, Vector3(to.x, rp.y, to.z), t)
						_dash_shot()
		"whirl":
			demo._shockwave(_pos_of(int(ev.get("eid", 0)), at), float(ev.get("radius", 2.6)))
		"torch":
			var lit: Array = ev.get("lit", [])
			adventure.state.lit.assign(lit)
			var room: Vector3 = AdvWorld.ROOM
			if bool(ev.get("ok", false)):
				demo._burst(room + (AdvWorld.TORCHES[int(ev.get("index", 0))] as Vector3) + Vector3(0, 1.7, 0))
			else:
				for t: Vector3 in AdvWorld.TORCHES:   # ordem errada: todas apagam
					demo._burst(room + t + Vector3(0, 1.7, 0))
		"light":
			if int(ev.get("eid", 0)) == my_id():
				_light_left = float(ev.get("left", 0.0))
				adventure.core.set_effects({"light": _light_left})
		"refused":
			if String(ev.get("reason", "")) == "mana":
				adventure.hud.flash_mana()
			match String(ev.get("act", "")):
				"equip":
					adventure.hud.equip_refused()   # servidor recusou: o slot treme em vermelho
				"unequip":
					adventure.hud.unequip_refused()
				"buy", "sell":
					adventure.hud.shop_refused()
		"ground":
			if String(ev.get("op", "")) == "add":
				_ground_add(ev)
			else:
				_ground_del(int(ev.get("gid", 0)))
		"trade":
			adventure.hud.trade_state(ev)
			match String(ev.get("op", "")):
				"open":
					demo._burst(_pos_of(int(ev.get("with", 0)), []) + Vector3(0, 1.2, 0))
				"close":
					if String(ev.get("reason", "")) != "cancel":
						adventure.chat.post("Servidor", "A troca foi desfeita.", Color(1.0, 0.55, 0.5))


func _on_chat(m: Dictionary) -> void:
	var tab := String(CHAT_TAB.get(String(m.get("channel", "local")), "Local"))
	var from := String(m.get("from", ""))
	var text := String(m.get("text", ""))
	adventure.chat.post(tab, ("%s: %s" % [from, text]) if not from.is_empty() else text)
	if tab == "Local" and from != String(welcome.get("name", "")):
		for id: int in remotes:
			if String(remotes[id].name) == from and remotes[id].has("speech"):
				(remotes[id].speech as Label3D).text = text
				remotes[id].speech_t = 5.0


func _on_friend_event(ev: Dictionary) -> void:
	var who := String(ev.get("name", ""))
	match String(ev.get("op", "")):
		"request":
			adventure.chat.post("Servidor", "%s quer ser seu amigo." % who)
		"accepted":
			adventure.chat.post("Servidor", "%s agora é seu amigo." % who)
		"presence":
			adventure.chat.post("Servidor", ("%s entrou no jogo." if bool(ev.get("online", false)) else "%s saiu do jogo.") % who)


# ------------------------------------------------------------------ entidades remotas

func _sync_remotes(delta: float) -> void:
	var seen := {}
	for e: Dictionary in net.entities():
		var id := int(e.id)
		seen[id] = true
		var r: Dictionary = remotes.get(id, {})
		if r.is_empty():
			r = _make(e)
			remotes[id] = r
		_update_remote(r, e, delta)
	for id: int in remotes.keys():
		if not seen.has(id):
			(remotes[id].root as Node).queue_free()
			remotes.erase(id)


func _make(e: Dictionary) -> Dictionary:
	var id := int(e.id)
	var info: Dictionary = net.client.infos.get(id, {})
	var root := Node3D.new()
	root.set_meta("net_id", id)
	_root.add_child(root)
	root.position = e.pos
	var r := {"root": root, "kind": int(e.kind), "name": String(info.get("name", e.get("name", ""))), "last": e.pos}
	match int(e.kind):
		Protocol.KIND_PLAYER:
			_make_player(r, root, info)
		Protocol.KIND_MONSTER:
			_make_monster(r, root, info)
		_:
			_make_shot(r, root, int(e.sub))
	return r


func _make_player(r: Dictionary, root: Node3D, info: Dictionary) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var v = Vocations.new()
	v.setup(demo, String(info.get("vocation", "mage")))
	# build_model escreve no _anim/_p.staff do demo: guarda e devolve os do jogador local
	var keep_anim: AnimationPlayer = demo._anim
	var keep_staff = demo._p.get("staff")
	v.build_model(holder)
	r.anim = demo._anim
	r.voc = v.cfg
	demo._anim = keep_anim
	demo._p.staff = keep_staff
	r.model = holder
	r.label = adventure.world.label(root, r.name, Vector3(0, 2.15, 0), Color(1, 1, 1), 32)
	r.speech = adventure.world.label(root, "", Vector3(0, 2.6, 0), Color(1.0, 0.93, 0.35), 30)
	r.speech_t = 0.0
	var light := OmniLight3D.new()
	var lc: Array = adventure.core.skill("light").get("light_color", [1.0, 0.9, 0.68])
	light.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2]))
	light.omni_range = float(adventure.core.skill("light").get("light_range", 10.0))
	light.light_energy = float(adventure.core.skill("light").get("light_energy", 1.5))
	light.position = Vector3(0, 2.4, 0)
	light.visible = false
	root.add_child(light)
	r.light = light


func _make_monster(r: Dictionary, root: Node3D, info: Dictionary) -> void:
	var kind := String(info.get("monster", "frog"))
	var cfg: Dictionary = (adventure.config.enemy as Dictionary).get(kind, {})
	var look := String(cfg.get("model", kind))
	var rig := Node3D.new()
	rig.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	root.add_child(rig)
	var model := Node3D.new()
	rig.add_child(model)
	match look:
		"frog":
			_builder._frog(model)
		"wolf":
			var fur: Array = cfg.get("fur", [0.44, 0.43, 0.47])
			_builder._wolf(model, Color(float(fur[0]), float(fur[1]), float(fur[2])))
		_:
			_builder._spider(model)
	r.model = rig
	r.short = String(cfg.get("short", cfg.get("name", kind)))
	var lv := int(info.get("level", 1))
	if lv > 1:
		r.short = "%s Nv %d" % [r.short, lv]
	r.label = adventure.world.label(root, r.short, Vector3(0, (1.45 if look == "wolf" else 1.35) * float(cfg.get("scale", 1.0)), 0), Color(1, 0.80, 0.68), 34)
	# corpo para a mira do mouse (camada 8 = inimigos, igual aos monstros offline)
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.set_meta("kind", "enemy")
	body.set_meta("net_id", int(root.get_meta("net_id")))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.3
	shape.shape = cap
	shape.position.y = 0.65
	body.add_child(shape)
	root.add_child(body)
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = _ring_mat
	ring.scale = Vector3(1.6, 0.16, 1.6) * float(cfg.get("scale", 1.0))
	ring.position.y = 0.04
	ring.visible = false
	root.add_child(ring)
	r.ring = ring


func _make_shot(r: Dictionary, root: Node3D, sub: int) -> void:
	var what := String(Protocol.PROJECTILE_SUBKINDS[clampi(sub, 0, Protocol.PROJECTILE_SUBKINDS.size() - 1)])
	var holder := Node3D.new()
	root.add_child(holder)
	r.model = holder
	match what:
		"arrow", "pierce":
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.018
			shaft.bottom_radius = 0.018
			shaft.height = 0.7
			shaft.radial_segments = 4
			var col := Color(0.75, 0.9, 1.0) if what == "pierce" else Color(0.55, 0.38, 0.2)
			demo._mesh(shaft, demo._toon(col, col if what == "pierce" else Color.BLACK, 2.5 if what == "pierce" else 0.0), Vector3.ZERO, holder, Vector3(90, 0, 0))
			if what == "pierce":
				var l := OmniLight3D.new()
				l.light_color = Color(0.6, 0.85, 1.0)
				l.omni_range = 2.5
				l.light_energy = 1.5
				holder.add_child(l)
		"web":
			var ball := SphereMesh.new()
			ball.radius = 0.13
			ball.height = 0.26
			ball.radial_segments = 6
			ball.rings = 3
			demo._mesh(ball, demo._toon(Color(0.88, 0.95, 0.78), Color(0.6, 0.95, 0.4), 1.3), Vector3.ZERO, holder)
		_:
			var core := SphereMesh.new()
			core.radius = 0.13
			core.height = 0.26
			core.radial_segments = 6
			core.rings = 3
			demo._mesh(core, demo._toon(Color(1, 0.7, 0.3), Color(1.0, 0.55, 0.15), 6.0), Vector3.ZERO, holder)
			var l := OmniLight3D.new()
			l.light_color = Color(1, 0.5, 0.15)
			l.omni_range = 3.0
			l.light_energy = 2.0
			holder.add_child(l)


func _update_remote(r: Dictionary, e: Dictionary, delta: float) -> void:
	var root: Node3D = r.root
	var pos: Vector3 = e.pos
	var moved := Vector2(pos.x - (r.last as Vector3).x, pos.z - (r.last as Vector3).z).length() / maxf(delta, 0.001)
	r.last = pos
	var dash: Dictionary = r.get("dash", {})
	if DashMotion.active(dash):
		var to: Vector3 = dash.to
		pos = DashMotion.step(dash, delta, Vector3(to.x, pos.y, to.z))   # investida/salto de outro jogador
	root.position = pos
	var fx: Array = e.effects
	match int(r.kind):
		Protocol.KIND_PLAYER:
			(r.model as Node3D).rotation.y = lerp_angle((r.model as Node3D).rotation.y, float(e.yaw), 1.0 - exp(-delta * 14.0))
			# "Nome  vida/máx": o overlay de textos desenha o nome com a barra de vida (Tibia)
			(r.label as Label3D).text = "%s  %d/%d" % [r.name, int(e.hp), maxi(1, int(e.max_hp))]
			(r.light as OmniLight3D).visible = "light" in fx
			var anim: AnimationPlayer = r.anim
			if anim != null:
				var want := "Idle"
				if "dodge" in fx:
					want = "Dodge_Forward"
				elif "casting" in fx:
					want = String((r.voc as Dictionary).get("attack_anim", "Spellcast_Shoot"))
				elif moved > 0.4:
					want = "Running_A"
				if anim.has_animation(want) and anim.current_animation != want:
					anim.play(want)
			r.speech_t = maxf(0.0, float(r.speech_t) - delta)
			if float(r.speech_t) <= 0.0:
				(r.speech as Label3D).text = ""
		Protocol.KIND_MONSTER:
			(r.model as Node3D).rotation.y = lerp_angle((r.model as Node3D).rotation.y, float(e.yaw), 1.0 - exp(-delta * 9.0))
			(r.label as Label3D).text = "%s  %d/%d" % [r.short, int(e.hp), maxi(1, int(e.max_hp))]
			(r.ring as Node3D).visible = "windup" in fx
			# passada simples: o corpo quica um pouco enquanto anda
			var bob := absf(sin(Time.get_ticks_msec() / 1000.0 * 9.0)) * 0.06 if moved > 0.3 else 0.0
			(r.model as Node3D).position.y = bob   # o salto (hop) já vem na altura do servidor
		_:
			(r.model as Node3D).rotation.y = float(e.yaw)
