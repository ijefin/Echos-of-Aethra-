extends SceneTree
## Equipar pela bolsa (painel I, estilo Tibia): soltar no slot / duplo clique veste, muda dano e
## armadura offline, recusa item de outra vocação ou slot errado (feedback vermelho), arma
## vestida tinge o modelo, e online só pede ao servidor (nada muda antes da resposta).
## godot --headless --path . -s res://src/game/tools/test_equip.gd -- --no_save --mute

var demo: Node
var a
var fails := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	print("%s equip: %s" % ["PASS" if cond else "FAIL", what])
	if cond:
		passes += 1
	else:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


func _load(cls: String) -> void:
	if demo != null:
		demo.queue_free()
		await process_frame
	Engine.set_meta("aethra_class", cls)
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	for i in 4:
		await process_frame


## Fica no lugar de net_play: só anota o pedido (o servidor de verdade fica no teste de rede).
class FakeOnline:
	extends RefCounted
	var asked: Array[String] = []

	func equip(id: String) -> void:
		asked.append(id)

	func unequip(slot: String) -> void:
		asked.append("unequip:" + slot)


func _mb(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func run() -> void:
	# ---------------- Mago
	await _load("mage")
	var hud = a.hud
	a.inventory.give(["sentinel_staff", "iron_sword", "mist_mantle", "ember_robe"])
	var dmg0: int = a.basic_damage()
	var arm0: float = a.armor_ratio()
	check(a.inventory.equipped.weapon == "fire_staff", "mago começa com o Cajado de Brasa")
	check(hud.drop_on_slot("sentinel_staff", "weapon"), "soltar o Cajado da Sentinela no slot da arma veste")
	check(a.inventory.equipped.weapon == "sentinel_staff" and "fire_staff" in a.inventory.items, "cajado antigo volta para a bolsa")
	check(is_equal_approx(a.gear("spell_power"), 3.0) and a.basic_damage() > dmg0, "dano sobe %d → %d (+3 poder mágico)" % [dmg0, a.basic_damage()])
	check(hud._accept_fx.has("weapon") and hud._stat_fx > 0.0, "aceite: slot brilha dourado")
	var glow: Color = demo._crystal.get_shader_parameter("emission")
	check(glow.b > glow.r, "cristal do cajado fica azul (Sentinela) — %s" % glow)
	check(not hud.drop_on_slot("iron_sword", "weapon"), "Espada de Ferro (guerreiro) recusada para o mago")
	check(a.inventory.equipped.weapon == "sentinel_staff" and "iron_sword" in a.inventory.items, "recusa não mexe no equipamento")
	check(hud._reject_fx.has("weapon") and hud._reject_fx.has("iron_sword"), "recusa: célula e slot piscam em vermelho")
	check(not hud.drop_on_slot("mist_mantle", "head"), "manto no slot da cabeça é recusado (slot errado)")
	check(a.inventory.equipped.chest == "apprentice_robe", "peito continua com o Robe de Aprendiz")
	hud.use_entry("item", "mist_mantle")
	check(a.inventory.equipped.chest == "mist_mantle", "duplo clique veste o Manto da Névoa no peito")
	check(is_equal_approx(a.armor_ratio() - arm0, 4 * a.ARMOR_PER_POINT), "armadura sobe %d%% → %d%%" % [roundi(arm0 * 100), roundi(a.armor_ratio() * 100)])
	check(a.max_mana() > 0 and is_equal_approx(a.gear("max_resource"), 10.0), "mana máx. do manto (+20 vs +10 do robe)")
	var entries: Array = hud.bag_entries()
	var kinds := {}
	for e: Dictionary in entries:
		kinds[e.kind] = true
	check(kinds.has("potion") and kinds.has("item"), "bolsa lista poções e equipamento guardado (%d células)" % entries.size())
	# ---------------- online: só pede ao servidor
	var fake := FakeOnline.new()
	a.online = fake
	check(hud.drop_on_slot("ember_robe", "chest"), "online: soltar o Robe de Brasa manda o pedido")
	check(fake.asked.size() == 1 and fake.asked[0] == "ember_robe", "online: net_play.equip(\"ember_robe\") chamado")
	check(a.inventory.equipped.chest == "mist_mantle" and hud.pending_equip == "ember_robe", "online: nada muda antes do estado do servidor (pulsando)")
	hud.equip_refused()
	check(hud.pending_equip == "" and hud._reject_fx.has("chest"), "online: recusa do servidor pisca o slot")
	check(not hud.drop_on_slot("iron_sword", "weapon") and fake.asked.size() == 1, "online: item de outra vocação nem é pedido")
	check(hud.unequip_slot("chest") and fake.asked.back() == "unequip:chest" and a.inventory.equipped.get("chest", "") == "mist_mantle", "online: desequipar só pede ao servidor ({act: unequip, slot})")
	hud.unequip_refused()
	check(hud.pending_unequip == "" and hud._reject_fx.has("chest"), "online: recusa do desequipar pisca o slot")
	a.online = null
	# ---------------- desequipar (offline): duplo clique / arrastar até a grade
	hud._reject_fx.clear()
	var dmg_w: int = a.basic_damage()
	check(hud.unequip_slot("weapon") and not a.inventory.equipped.has("weapon") and "sentinel_staff" in a.inventory.items, "desequipar a arma: volta para a bolsa")
	check(a.basic_damage() < dmg_w, "desequipar recalcula o dano %d → %d" % [dmg_w, a.basic_damage()])
	check(hud._accept_fx.has("weapon"), "desequipar: slot brilha dourado")
	check(not hud.unequip_slot("weapon") and hud._reject_fx.has("weapon"), "slot vazio: recusa vermelha")
	var arm_u: float = a.armor_ratio()
	while a.inventory.items.size() < a.inventory.capacity():
		a.inventory.items.append("iron_sword")
	hud._reject_fx.clear()
	check(not hud.unequip_slot("chest") and a.inventory.equipped.chest == "mist_mantle" and hud._reject_fx.has("chest"), "bolsa cheia: desequipar recusado (slot treme)")
	a.inventory.items.resize(5)
	check(hud.unequip_slot("chest") and a.armor_ratio() < arm_u, "com espaço: manto sai e a armadura cai %d%% → %d%%" % [roundi(arm_u * 100), roundi(a.armor_ratio() * 100)])
	var snap: Dictionary = a.content_snapshot()
	check((snap.bag as Array).has("mist_mantle") and not (snap.equipped as Dictionary).has("chest"), "save leva a bolsa e o slot vazio")
	# arrastar do slot e soltar na grade (eventos de mouse de verdade no painel)
	a.inventory.equip("sentinel_staff")
	hud.panel = "bag"
	hud.queue_redraw()
	await process_frame
	await process_frame
	var src: Vector2 = (hud._doll_rects.weapon as Rect2).get_center()
	var dst: Vector2 = hud._grid_rect.get_center()
	hud.bag_mouse(_mb(src, true))
	var mm := InputEventMouseMotion.new()
	mm.position = dst
	hud.bag_mouse(mm)
	hud.bag_mouse(_mb(dst, false))
	check(not a.inventory.equipped.has("weapon") and "sentinel_staff" in a.inventory.items, "arrastar o cajado do slot até a grade desequipa")
	var dbl := _mb((hud._doll_rects.head as Rect2).get_center(), true)
	dbl.double_click = true
	var head_id: String = a.inventory.equipped.get("head", "")
	hud.bag_mouse(dbl)
	check(head_id != "" and not a.inventory.equipped.has("head") and head_id in a.inventory.items, "duplo clique no slot da cabeça desequipa (%s)" % head_id)
	hud.panel = ""
	a.inventory.equip("sentinel_staff")
	# ---------------- nome sobre a Insígnia da Patrulha (missão 2) só de perto
	a._debug_quest("fios_estrada:2")
	var pk: Array = a.quests.pickups()
	check(pk.size() == 1, "missão 2 no passo da insígnia")
	if pk.size() == 1:
		var at: Vector2 = pk[0].at
		demo._player.global_position = Vector3(at.x + 2.0, 0, at.y)
		a._update_content()
		var node: Node3D = a.world.pickup_nodes.values()[0]
		var lab: Label3D = node.get_meta("label") if node.has_meta("label") else null
		check(lab != null and lab.text == "Insígnia da Patrulha" and lab.visible, "perto (2 m): nome \"%s\" sobre a insígnia" % (lab.text if lab != null else ""))
		demo._player.global_position = Vector3(at.x + 12.0, 0, at.y)
		a._update_content()
		check(lab != null and not lab.visible, "longe (12 m): nome some")
	# ---------------- Guerreiro
	await _load("warrior")
	hud = a.hud
	a.inventory.give(["guard_sword", "sentinel_staff", "lair_cuirass"])
	dmg0 = a.basic_damage()
	arm0 = a.armor_ratio()
	check(hud.drop_on_slot("guard_sword", "weapon") and a.basic_damage() > dmg0, "guerreiro: Espada da Guarda sobe o dano %d → %d" % [dmg0, a.basic_damage()])
	var tint: Color = demo._voc.weapon_mat.get_shader_parameter("tint")
	check(tint.b < tint.r, "guerreiro: lâmina tingida de dourado (%s)" % tint)
	check(not hud.drop_on_slot("sentinel_staff", "weapon"), "guerreiro: cajado recusado")
	hud.use_entry("item", "lair_cuirass")
	check(a.armor_ratio() > arm0, "guerreiro: Couraça do Covil sobe a armadura %d%% → %d%%" % [roundi(arm0 * 100), roundi(a.armor_ratio() * 100)])
	# ---------------- Arqueiro
	await _load("archer")
	hud = a.hud
	a.inventory.give(["yew_bow", "guard_sword"])
	dmg0 = a.basic_damage()
	check(hud.drop_on_slot("yew_bow", "weapon") and a.basic_damage() > dmg0, "arqueiro: Arco de Teixo sobe o dano %d → %d" % [dmg0, a.basic_damage()])
	var wood: Color = demo._voc.weapon_mat.get_shader_parameter("albedo")
	check(wood.r < 0.5, "arqueiro: madeira do arco escurece (teixo) — %s" % wood)
	check(not hud.drop_on_slot("guard_sword", "weapon"), "arqueiro: espada recusada")
	print("TEST_EQUIP: %s (%d PASS, %d FAIL)" % ["OK" if fails == 0 else "FAIL", passes, fails])
	quit(0 if fails == 0 else 1)
