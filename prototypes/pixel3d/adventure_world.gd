# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Geometry and interactable targets for Nessa's first underground quest.
const Cave := preload("res://prototypes/pixel3d/adventure_cave.gd")
const NPC := Vector3(-14, 0, -25)
const ENTRANCE := Vector3(-38, 0, -28)
## Andar -1 (estilo Tibia): a gruta fica EMBAIXO da boca dela, nas mesmas coordenadas
## do mapa. ROOM é a origem do layout local de adventure_cave.gd.
const ROOM := Vector3(-38, -8, -39)
## Escadas entre andares: pisou na boca (down) desce e chega em arrive; pisou na escada
## de pedra (up) sobe e sai em exit, na frente da boca. Sem tecla.
const STAIRS := [
	{"down": Vector3(-38, 0, -31.3), "arrive": Vector3(-38, -8, -32.0), "up": Vector3(-38, -8, -28.6), "exit": Vector3(-38, 0, -28.4)},
	{"down": Vector3(36, 0, 30.7), "arrive": Vector3(36, -8, 30.2), "up": Vector3(36, -8, 33.0), "exit": Vector3(36, 0, 33.4)},
]
## Círculo de retorno ao lado do baú (aparece depois do colar): pisou, volta à Nessa.
const PORTAL := Vector3(-29.5, -8, -54.5)
const CHEST := Vector3(-33, -8, -56.2)
## Tochas nas Ruínas: índice 0 = I, 2 = II, 1 = III (ordem em first_adventure.json).
const TORCHES := [Vector3(0, 0, -9), Vector3(12, 0, -6), Vector3(6, 0, -1.5)]
## Dois bandos de guardiões: Salão das Aranhas e Ruínas das Tochas.
const CAVE_SPAWNS := [Vector3(-8, 0, 3), Vector3(-4, 0, 5), Vector3(-7, 0, -1), Vector3(-2, 0, 0),
	Vector3(3, 0, -9), Vector3(9, 0, -10), Vector3(9, 0, -4), Vector3(4, 0, -5)]
## Bandos do túnel até a segunda caverna (renascem; não contam como guardiões).
const TUNNEL_SPAWNS := [[Vector3(28, 0, -1), "spider"], [Vector3(30, 0, 2), "frog"], [Vector3(47, 0, 13), "spider"],
	[Vector3(50, 0, 15), "spider"], [Vector3(46, 0, 16), "frog"], [Vector3(62, 0, 38), "spider"], [Vector3(65, 0, 40), "spider"]]
var demo: Node
var surface: Node3D
var cave: Node3D
var torch_nodes: Array[Dictionary] = []
var chest_lid: Node3D
var npc_marker: Label3D
var npc_name: Label3D
## Fala da Nessa sobre a cabeça (estilo Tibia).
var npc_speech: Label3D
var portal_node: Node3D
## NPCs do conteúdo (quests.json): id → {node, name, speech, marker, pos, display}.
var npcs: Dictionary = {}
## Objetos de missão no chão (um por passo "collect" com `at`): chave → Node3D.
var pickup_nodes: Dictionary = {}
const CHAR_DIR := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/"
var _box := BoxMesh.new()
var _cave_materials: Dictionary = {}

func _stone_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _cave_materials.has(key):
		var material: ShaderMaterial = demo._toon(color)
		material.set_shader_parameter("local_light_softness", 1.0)
		_cave_materials[key] = material
	return _cave_materials[key]

func label(parent: Node, text: String, at: Vector3, color := Color(1.0, 0.88, 0.53), font_size := 32) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 7
	l.no_depth_test = true
	l.modulate = color
	l.position = at
	parent.add_child(l)
	demo.world_labels.adopt(l)
	return l

func cube(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid := false, kind := "rock") -> Node3D:
	var target: Node3D = parent
	if solid:
		var body := StaticBody3D.new()
		body.set_meta("kind", kind)
		parent.add_child(body)
		body.position = at
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		target = body
		demo._mesh(_box, _stone_material(color), Vector3.ZERO, target, Vector3.ZERO, size)
	else:
		demo._mesh(_box, _stone_material(color), at, parent, Vector3.ZERO, size)
	return target

func rune(parent: Node3D, at: Vector3, color: Color, radius := 0.75) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.82
	ring.outer_radius = radius
	ring.rings = 20
	ring.ring_segments = 5
	demo._mesh(ring, demo._toon(color, color, 1.5), at + Vector3(0, 0.035, 0), parent, Vector3.ZERO, Vector3(1, 0.16, 1))

func _npc() -> void:
	var npc := Node3D.new()
	surface.add_child(npc)
	npc.position = NPC
	var path := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Rogue.glb"
	var model := (load(path) as PackedScene).instantiate() as Node3D
	npc.add_child(model)
	model.rotation.y = 0.0
	model.scale = Vector3.ONE * 0.72
	for name in ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]:
		(model.find_child(name, true, false) as Node3D).hide()
	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var source := mi.get_active_material(0) as BaseMaterial3D
		var material: ShaderMaterial = demo._toon(Color.WHITE)
		if source != null and source.albedo_texture != null:
			material.set_shader_parameter("albedo_tex", source.albedo_texture)
			material.set_shader_parameter("use_tex", true)
		if "Cape" in mi.name or "Body" in mi.name:
			material.set_shader_parameter("tint", Color(0.60, 0.85, 0.87))
		mi.material_override = material
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")
	var hand := model.find_child("handslot_l", true, false) as Node3D
	var lantern := BoxMesh.new()
	lantern.size = Vector3(0.19, 0.24, 0.19)
	demo._mesh(lantern, demo._toon(Color(1, 0.8, 0.4), Color(1, 0.65, 0.2), 3), Vector3(0, -0.12, 0), hand)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.73, 0.4)
	light.light_energy = 0.7
	light.omni_range = 2.8
	hand.add_child(light)
	npc_name = label(npc, "Nessa", Vector3(0, 2.1, 0), Color(0.85, 0.93, 1))
	npc_speech = label(npc, "", Vector3(0, 2.75, 0), Color(1.0, 0.93, 0.35), 34)
	npc_marker = label(npc, "!", Vector3(0, 2.7, 0), Color(1, 0.8, 0.24), 64)
	rune(surface, NPC, Color(0.28, 0.58, 0.76), 0.65)
	rune(surface, ENTRANCE, Color(0.32, 0.58, 0.83))
	for p: Vector3 in [Vector3(-21, 0, -28), Vector3(-29, 0, -29), Vector3(-36, 0, -28)]:
		rune(surface, p, Color(0.32, 0.51, 0.55), 0.28)

func _torch(index: int) -> void:
	var node := StaticBody3D.new()
	node.set_meta("kind", "quest_torch")
	node.set_meta("torch_index", index)
	cave.add_child(node)
	node.position = TORCHES[index]
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.37
	shape.height = 1.9
	collision.shape = shape
	collision.position.y = 0.95
	node.add_child(collision)
	var base := CylinderMesh.new()
	base.top_radius = 0.32
	base.bottom_radius = 0.42
	base.height = 0.3
	base.radial_segments = 7
	demo._mesh(base, demo._toon_shared(Color(0.36, 0.33, 0.32)), Vector3(0, 0.15, 0), node)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.09
	pole.bottom_radius = 0.13
	pole.height = 1.15
	pole.radial_segments = 6
	demo._mesh(pole, demo._toon_shared(Color(0.33, 0.22, 0.15)), Vector3(0, 0.8, 0), node)
	var bowl := CylinderMesh.new()
	bowl.top_radius = 0.23
	bowl.bottom_radius = 0.12
	bowl.height = 0.18
	bowl.radial_segments = 7
	demo._mesh(bowl, demo._toon_shared(Color(0.18, 0.19, 0.21)), Vector3(0, 1.43, 0), node)
	var flame := SphereMesh.new()
	flame.radius = 0.15
	flame.height = 0.52
	flame.radial_segments = 6
	flame.rings = 3
	var fire: MeshInstance3D = demo._mesh(flame, demo._toon(Color(1, 0.65, 0.18), Color(1, 0.47, 0.08), 4.0), Vector3(0, 1.7, 0), node)
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sparks := GPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 0.55
	sparks.preprocess = 0.6
	sparks.local_coords = true
	sparks.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.07
	process.direction = Vector3.UP
	process.spread = 9
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.45
	process.gravity = Vector3(0, 1.0, 0)
	process.scale_min = 0.55
	process.scale_max = 0.95
	process.color_ramp = demo._ramp([Color(1, 0.6, 0.15), Color(1, 0.23, 0.025, 0.0)])
	sparks.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.40)
	quad.material = demo._flame_draw
	sparks.draw_pass_1 = quad
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.add_child(sparks)
	var light := OmniLight3D.new()
	light.position.y = 1.65
	light.light_color = Color(1, 0.65, 0.28)
	light.omni_range = 6.5
	light.light_energy = 2.2
	light.shadow_enabled = false
	node.add_child(light)
	# Ordem gravada na pedra da base: 1, 2 ou 3 marcas (índice 0 = 1ª, 2 = 2ª, 1 = 3ª).
	var marks: int = [1, 3, 2][index]
	var notch := BoxMesh.new()
	notch.size = Vector3(0.07, 0.04, 0.16)
	for m in marks:
		demo._mesh(notch, demo._toon_shared(Color(0.72, 0.68, 0.6)), Vector3((m - (marks - 1) * 0.5) * 0.14, 0.31, 0.24), node)
	# Brasa fraca no bojo apagado: insinua que fogo acende a tocha.
	var ember := SphereMesh.new()
	ember.radius = 0.05
	ember.height = 0.06
	var glint: MeshInstance3D = demo._mesh(ember, demo._toon(Color(0.6, 0.2, 0.05), Color(1.0, 0.35, 0.05), 1.6), Vector3(0, 1.5, 0), node)
	torch_nodes.append({"node": node, "fire": fire, "light": light, "ember": glint})

func _room() -> void:
	cave = Node3D.new()
	demo._vp.add_child(cave)
	cave.position = ROOM
	# Preenchimento fraco e neutro: a gruta é escura; braseiros e tochas dão o contraste.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-58, -28, 0)
	fill.light_color = Color(0.78, 0.74, 0.8)
	fill.light_energy = 0.32
	fill.shadow_enabled = false
	cave.add_child(fill)
	var layout := Cave.new()
	layout.build(demo, cave, _stone_material)
	for s: Dictionary in STAIRS:
		_stairs((s.up as Vector3) - ROOM)
	# círculo de retorno ao lado do baú (só depois do colar)
	portal_node = Node3D.new()
	cave.add_child(portal_node)
	portal_node.position = PORTAL - ROOM
	rune(portal_node, Vector3.ZERO, Color(0.40, 0.65, 0.98), 0.9)
	var portal_light := OmniLight3D.new()
	portal_light.light_color = Color(0.45, 0.7, 1.0)
	portal_light.light_energy = 0.9
	portal_light.omni_range = 3.2
	portal_light.position = Vector3(0, 0.8, 0)
	portal_node.add_child(portal_light)
	portal_node.hide()
	for i in 3:
		_torch(i)
	# Baú do altar: tampa animada separada e alvo real de clique.
	var chest_local := CHEST - ROOM
	var chest := cube(cave, chest_local + Vector3(0, 0.4, 0), Vector3(1.45, 0.8, 0.85), Color(0.44, 0.26, 0.13), true, "quest_chest")
	chest_lid = Node3D.new()
	chest.add_child(chest_lid)
	chest_lid.position = Vector3(0, 0.45, -0.42)
	cube(chest_lid, Vector3(0, 0, 0.42), Vector3(1.52, 0.22, 0.92), Color(0.55, 0.35, 0.17))
	for x: float in [-0.48, 0.48]:
		cube(chest, Vector3(x, 0, 0.44), Vector3(0.10, 0.8, 0.04), Color(0.69, 0.54, 0.22))
	cube(chest, Vector3(0, 0.35, 0.47), Vector3(0.22, 0.26, 0.06), Color(0.83, 0.64, 0.20))
	cave.hide()

## Escada de pedra subindo para a luz do dia (saída do andar -1).
func _stairs(at: Vector3) -> void:
	var stone := Color(0.46, 0.43, 0.4)
	for k in 4:
		var step := BoxMesh.new()
		step.size = Vector3(2.4 - k * 0.15, 0.22 + k * 0.22, 0.6)
		demo._mesh(step, _stone_material(stone.lightened(0.04 * k)), at + Vector3(0, step.size.y * 0.5, -0.9 + k * 0.6), cave)
	var day := OmniLight3D.new()  # claridade que desce pela boca da caverna
	day.light_color = Color(0.92, 0.95, 1.0)
	day.light_energy = 1.3
	day.omni_range = 4.5
	day.position = at + Vector3(0, 2.6, 0.4)
	cave.add_child(day)


func build(owner_demo: Node) -> void:
	demo = owner_demo
	surface = Node3D.new()
	demo._vp.add_child(surface)
	_npc()
	_room()


## NPCs das missões (mesmo estilo da Nessa: modelo KayKit, toon com textura, tinta,
## nome perto, fala sobre a cabeça, "!"/"?" quando há missão).
func build_npcs(quest_data: Dictionary) -> void:
	for id: String in quest_data.npcs:
		var spec: Dictionary = quest_data.npcs[id]
		var pos := Vector3(float(spec.pos[0]), 0, float(spec.pos[1]))
		var npc := Node3D.new()
		npc.name = "npc_" + id
		surface.add_child(npc)
		npc.position = pos
		var model := (load(CHAR_DIR + String(spec.model) + ".glb") as PackedScene).instantiate() as Node3D
		npc.add_child(model)
		model.rotation.y = deg_to_rad(float(spec.get("yaw", 0)))
		model.scale = Vector3.ONE * 0.72
		var hide: Array = spec.get("hide", [])
		var tint: Array = spec.get("tint", [1, 1, 1])
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mi := child as MeshInstance3D
			if String(mi.name) in hide:
				mi.hide()
				continue
			var source := mi.get_active_material(0) as BaseMaterial3D
			var material: ShaderMaterial = demo._toon(Color.WHITE)
			if source != null and source.albedo_texture != null:
				material.set_shader_parameter("albedo_tex", source.albedo_texture)
				material.set_shader_parameter("use_tex", true)
			if "Cape" in mi.name or "Body" in mi.name:
				material.set_shader_parameter("tint", Color(float(tint[0]), float(tint[1]), float(tint[2])))
			mi.material_override = material
		var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation("Idle"):
			anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("Idle")
		if bool(spec.get("lantern", false)):
			var hand := model.find_child("handslot_l", true, false) as Node3D
			if hand != null:
				var lantern := BoxMesh.new()
				lantern.size = Vector3(0.19, 0.24, 0.19)
				demo._mesh(lantern, demo._toon(Color(0.7, 1, 0.6), Color(0.5, 1, 0.45), 3), Vector3(0, -0.12, 0), hand)
				var light := OmniLight3D.new()
				light.light_color = Color(0.6, 1, 0.55)
				light.light_energy = 0.7
				light.omni_range = 2.8
				hand.add_child(light)
		rune(surface, pos, Color(0.28, 0.58, 0.76), 0.65)
		npcs[id] = {"node": npc, "pos": pos, "display": String(spec.name),
			"name": label(npc, String(spec.name), Vector3(0, 2.1, 0), Color(0.85, 0.93, 1)),
			"speech": label(npc, "", Vector3(0, 2.75, 0), Color(1.0, 0.93, 0.35), 34),
			"marker": label(npc, "", Vector3(0, 2.7, 0), Color(1, 0.8, 0.24), 64)}


## Distância (m) em que o nome de um objeto de missão no chão aparece (padrão Tibia).
const PICKUP_NAME_RADIUS := 6.0

## Objeto de missão no chão: insígnia de metal com um brilho fraco que pulsa. O nome fica
## sobre ele (meta "label") e só aparece com o jogador perto (pickup_names).
func pickup_node(key: String, at: Vector2, title := "") -> Node3D:
	if pickup_nodes.has(key):
		return pickup_nodes[key]
	var node := Node3D.new()
	surface.add_child(node)
	node.position = Vector3(at.x, 0, at.y)
	cube(node, Vector3(0, 0.06, 0), Vector3(0.42, 0.08, 0.5), Color(0.55, 0.5, 0.42))
	cube(node, Vector3(0, 0.12, 0), Vector3(0.24, 0.05, 0.3), Color(0.85, 0.7, 0.3))
	rune(node, Vector3.ZERO, Color(0.95, 0.8, 0.4), 0.5)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.85, 0.5)
	light.light_energy = 0.6
	light.omni_range = 2.2
	light.position.y = 0.5
	node.add_child(light)
	if not title.is_empty():
		var l := label(node, title, Vector3(0, 0.95, 0), Color(1.0, 0.88, 0.53), 26)
		l.visible = false
		node.set_meta("label", l)
	pickup_nodes[key] = node
	return node


## Nome dos objetos de missão visíveis só quando o jogador está a PICKUP_NAME_RADIUS.
func pickup_names(player: Vector3) -> void:
	for key: String in pickup_nodes:
		var node: Node3D = pickup_nodes[key]
		if node.has_meta("label"):
			(node.get_meta("label") as Label3D).visible = node.visible and Vector2(player.x, player.z).distance_to(Vector2(node.global_position.x, node.global_position.z)) < PICKUP_NAME_RADIUS


## Marco de segredo já revelado: anel de runa e luz azulada (fica para sempre).
func secret_glow(parent: Node3D) -> void:
	if parent.has_node("glow"):
		return
	var g := Node3D.new()
	g.name = "glow"
	parent.add_child(g)
	rune(g, Vector3.ZERO, Color(0.45, 0.75, 1.0), 1.1)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.75, 1.0)
	light.light_energy = 1.1
	light.omni_range = 3.5
	light.position.y = 1.2
	g.add_child(light)


## Nome perto, marcador quando calado (texto vindo das missões).
func sync_npcs(player: Vector3, markers: Dictionary) -> void:
	for id: String in npcs:
		var n: Dictionary = npcs[id]
		(n.name as Label3D).visible = player.distance_to(n.pos) < 9.0
		var speech: Label3D = n.speech
		(n.marker as Label3D).text = String(markers.get(id, "")) if speech.text.is_empty() else ""

func sync(lit: Array[int], reward: bool, stage: String, t: float, player := Vector3.ZERO) -> void:
	# nome só quando o jogador está na área; a "!" some enquanto ela fala
	npc_name.visible = player.distance_to(NPC) < 9.0
	npc_marker.visible = npc_speech.text.is_empty()
	portal_node.visible = reward
	for i in torch_nodes.size():
		(torch_nodes[i].fire as MeshInstance3D).visible = i in lit
		(torch_nodes[i].light as OmniLight3D).visible = i in lit
		(torch_nodes[i].ember as Node3D).visible = not (i in lit) and fmod(t * 0.7 + i * 0.37, 1.0) < 0.6
		(torch_nodes[i].fire as Node3D).scale.y = 1.0 + sin(t * 7 + i) * 0.09
	chest_lid.rotation_degrees.x = -75.0 if reward else 0.0
	npc_marker.text = "?" if stage == "claimed" else ("!" if stage == "available" else "")
