extends Node3D
## Visual mínimo das entidades remotas (outros jogadores, monstros e projéteis do servidor).
## Substituível: o coordenador pode trocar por cenas/modelos do protótipo ligando os sinais
## remote_spawned/remote_despawned do NetGame. Cada visual tem meta "net_id" e "kind"
## ("enemy" para monstros) e um StaticBody3D na camada 8 para a mira do mouse.

const Protocol := preload("res://src/game/net/net_protocol.gd")
const MAGE_GLB := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"
const MONSTER_COLORS := [Color(0.35, 0.7, 0.3), Color(0.35, 0.25, 0.3), Color(0.55, 0.55, 0.6)]

## Callable(parent: Node, text: String, at: Vector3, color: Color) -> Label3D (o overlay nítido
## do protótipo: `func(p, t, a, c): return adventure.world.label(p, t, a, c)`).
var label_factory: Callable
var nodes: Dictionary = {}   # id → Node3D
var _mage: PackedScene


func sync_entities(list: Array) -> void:
	var seen := {}
	for e: Dictionary in list:
		var id := int(e.id)
		seen[id] = true
		var n: Node3D = nodes.get(id)
		if n == null:
			n = _make(e)
			nodes[id] = n
		n.position = e.pos
		n.rotation.y = float(e.yaw)
		var lbl: Variant = n.get_meta("label", null)
		if lbl is Label3D and int(e.kind) != Protocol.KIND_PROJECTILE:
			var frac := float(e.hp) / maxf(1.0, float(e.max_hp))
			(lbl as Label3D).text = String(e.name)
			(lbl as Label3D).modulate = Color(1, 0.3, 0.25).lerp(Color(0.4, 1, 0.4), frac)
		n.visible = not ("dead" in (e.effects as Array))
	for id: int in nodes.keys():
		if not seen.has(id):
			(nodes[id] as Node).queue_free()
			nodes.erase(id)


func _make(e: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.set_meta("net_id", int(e.id))
	add_child(root)
	match int(e.kind):
		Protocol.KIND_PLAYER:
			if _mage == null and ResourceLoader.exists(MAGE_GLB):
				_mage = load(MAGE_GLB)
			if _mage != null:
				var m := _mage.instantiate() as Node3D
				m.rotation.y = PI
				root.add_child(m)
			_label(root, e, 2.1, Color(1, 1, 1))
		Protocol.KIND_MONSTER:
			root.set_meta("kind", "enemy")
			var mesh := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.35
			cap.height = 0.8
			mesh.mesh = cap
			mesh.position.y = 0.4
			var mat := StandardMaterial3D.new()
			mat.albedo_color = MONSTER_COLORS[clampi(int(e.sub), 0, MONSTER_COLORS.size() - 1)]
			mesh.material_override = mat
			root.add_child(mesh)
			var body := StaticBody3D.new()
			body.collision_layer = 8
			body.collision_mask = 0
			body.set_meta("kind", "enemy")
			body.set_meta("net_id", int(e.id))
			var shape := CollisionShape3D.new()
			var cs := CapsuleShape3D.new()
			cs.radius = 0.4
			cs.height = 0.9
			shape.shape = cs
			shape.position.y = 0.45
			body.add_child(shape)
			root.add_child(body)
			_label(root, e, 1.2, Color(0.4, 1, 0.4))
		_:
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.13
			sm.height = 0.26
			ball.mesh = sm
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(1, 0.6, 0.2)
			fm.emission_enabled = true
			fm.emission = Color(1, 0.5, 0.15)
			fm.emission_energy_multiplier = 4.0
			ball.material_override = fm
			root.add_child(ball)
	return root


func _label(root: Node3D, e: Dictionary, height: float, color: Color) -> void:
	var l: Label3D
	if label_factory.is_valid():
		l = label_factory.call(root, String(e.get("name", "")), Vector3(0, height, 0), color)
	else:
		l = Label3D.new()
		l.text = String(e.get("name", ""))
		l.position = Vector3(0, height, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = color
		root.add_child(l)
	root.set_meta("label", l)
