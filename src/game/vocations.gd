extends RefCounted
## Vocações (Mago, Guerreiro, Arqueiro): dados em data/classes.json.
## O Mago continua usando o código original de pixel3d_demo.gd (bola de fogo, Eco, Anel);
## aqui ficam o modelo, o ataque básico e as habilidades Q/R do Guerreiro e do Arqueiro.
## Q usa o slot interno "blink" e R o "ring" (mesmos níveis de desbloqueio e recargas no HUD).

const DATA := "res://src/game/data/classes.json"
const CHAR_DIR := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/"
const ENEMY_LAYER := 8

var demo
var id := "mage"
var cfg: Dictionary = {}
var all: Dictionary = {}
## Recarga restante de R para as classes não-mago (o Mago usa adventure.ring_cd).
var _arrow_mat: ShaderMaterial
var _string_mat: ShaderMaterial
var _charge_hit: Array = []
## Material da arma no modelo (espada do Guerreiro / madeira do arco do Arqueiro): o item vestido tinge.
var weapon_mat: ShaderMaterial
var weapon_base := Color.WHITE
## Peças que dependem do equipamento (classes.json "gear"): slot → nós que só aparecem com o
## slot ocupado; materiais tingidos pelo "tint" do item da cabeça/peito; "body" = corpo tingido
## pelo peitoral (bare_tint sem peitoral).
var gear_nodes := {}
var gear_mats := {}
## Arqueiro: [MeshInstance3D da cabeça, malha/skin com capuz, malha/skin sem capuz].
var _head_swap: Array = []
static var _bare_heads := {}


static func load_all() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA))


func setup(owner_demo, class_id: String) -> void:
	demo = owner_demo
	all = load_all()
	id = class_id if all.classes.has(class_id) else "mage"
	cfg = all.classes[id]


## Visual da arma vestida (items.json: "tint" multiplica, "glow"/"glow_energy" brilham;
## no arco a cor do item vira a madeira).
func apply_weapon(it: Dictionary) -> void:
	if weapon_mat == null:
		return
	var glow: Array = it.get("glow", [0, 0, 0])
	var energy := float(it.get("glow_energy", 0.0))
	if id == "archer":
		var c: Array = it.get("color", [weapon_base.r, weapon_base.g, weapon_base.b])
		weapon_mat.set_shader_parameter("albedo", Color(float(c[0]), float(c[1]), float(c[2])))
		if _string_mat != null:
			_string_mat.set_shader_parameter("emission", Color(float(glow[0]), float(glow[1]), float(glow[2])))
			_string_mat.set_shader_parameter("emission_energy", energy * 2.0)
	else:
		var t: Array = it.get("tint", [1, 1, 1])
		weapon_mat.set_shader_parameter("tint", Color(float(t[0]), float(t[1]), float(t[2])))
	weapon_mat.set_shader_parameter("emission", Color(float(glow[0]), float(glow[1]), float(glow[2])))
	weapon_mat.set_shader_parameter("emission_energy", energy)


## Liga as peças do modelo `body` (já com material_override toon) aos slots de cfg.gear.
## Chamado por build_model e pelo mago local de pixel3d_demo.gd.
func bind_gear(body: Node3D) -> void:
	var g: Dictionary = cfg.get("gear", {})
	for slot: String in ["weapon", "shield", "head", "chest", "body"]:
		for n: Variant in g.get(slot, []):
			var mi := body.find_child(String(n), true, false) as MeshInstance3D
			if mi == null:
				continue
			if slot != "body":
				(gear_nodes.get_or_add(slot, []) as Array).append(mi)
			if mi.material_override is ShaderMaterial:
				(gear_mats.get_or_add(slot, []) as Array).append(mi.material_override)
				if slot == "weapon" and weapon_mat == null:
					weapon_mat = mi.material_override
	var hs: Dictionary = g.get("head_swap", {})
	if not hs.is_empty():
		var head := body.find_child(String(hs.mesh), true, false) as MeshInstance3D
		var bare: Array = _bare_head(String(hs.bare_model), String(hs.bare_mesh))
		if head != null and not bare.is_empty():
			_head_swap = [head, head.mesh, head.skin, bare[0], bare[1]]


## Malha + skin da cabeça sem capuz de outro modelo do pacote (mesmo esqueleto), em cache.
static func _bare_head(model: String, mesh_name: String) -> Array:
	var key := model + "/" + mesh_name
	if not _bare_heads.has(key):
		var sc := (load(CHAR_DIR + model + ".glb") as PackedScene).instantiate() as Node3D
		var mi := sc.find_child(mesh_name, true, false) as MeshInstance3D
		_bare_heads[key] = [mi.mesh, mi.skin] if mi != null else []
		sc.free()
	return _bare_heads[key]


## Visual do equipamento no modelo: arma/escudo/elmo/capa somem com o slot vazio e voltam ao
## vestir; elmo/chapéu e capa tomam o "tint" do item; o corpo toma o tint do peitoral (ou
## bare_tint sem peitoral). `lookup(id)` devolve o item de items.json.
func apply_gear(eq: Dictionary, lookup: Callable) -> void:
	for slot: String in ["weapon", "shield", "head", "chest"]:
		var id := String(eq.get(slot, ""))
		var on := not id.is_empty()
		var it: Dictionary = lookup.call(id) if on else {}
		for n: Node3D in gear_nodes.get(slot, []):
			n.visible = on
		var t: Array = it.get("tint", [1, 1, 1])
		var tc := Color(float(t[0]), float(t[1]), float(t[2]))
		if slot == "head" or slot == "chest":
			for m: ShaderMaterial in gear_mats.get(slot, []):
				m.set_shader_parameter("tint", tc)
		if slot == "chest":
			var b: Array = t if on else cfg.get("gear", {}).get("bare_tint", [1, 1, 1])
			for m: ShaderMaterial in gear_mats.get("body", []):
				m.set_shader_parameter("tint", Color(float(b[0]), float(b[1]), float(b[2])))
		if slot == "head" and not _head_swap.is_empty():
			var head: MeshInstance3D = _head_swap[0]
			head.mesh = _head_swap[1] if on else _head_swap[3]
			head.skin = _head_swap[2] if on else _head_swap[4]
			(head.material_override as ShaderMaterial).set_shader_parameter("tint", tc if on else Color.WHITE)
		if slot == "weapon" and on:
			apply_weapon(it)


## Slots com peça visível no modelo agora (testes e prints).
func gear_visible(slot: String) -> bool:
	if slot == "head" and not _head_swap.is_empty():
		return (_head_swap[0] as MeshInstance3D).mesh == _head_swap[1]
	var nodes: Array = gear_nodes.get(slot, [])
	return not nodes.is_empty() and (nodes[0] as Node3D).visible


func is_mage() -> bool:
	return id == "mage"


# ------------------------------------------------------------------ modelo

## Monta o personagem KayKit da vocação dentro de `holder` (mesmo tratamento do mago:
## altura fixa, materiais toon com a textura do pacote) e define _anim e _p.staff.
func build_model(holder: Node3D) -> void:
	var body := (load(CHAR_DIR + String(cfg.model) + ".glb") as PackedScene).instantiate() as Node3D
	holder.add_child(body)
	body.rotation.y = PI  # o glTF olha para +Z; o jogo assume -Z
	var keep: Array = cfg.get("keep_meshes", [])
	var parts := String(cfg.model).split("_")[0]  # "Knight", "Rogue"
	var scales: Dictionary = cfg.get("scale_meshes", {})
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		# corpo sempre; acessórios só os listados em keep_meshes
		(mi as MeshInstance3D).visible = n.begins_with(parts + "_") and not n.contains("Cape") or n in keep
		if scales.has(n):
			(mi as Node3D).scale = Vector3.ONE * float(scales[n])
	var top := 0.0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.visible:
			top = maxf(top, (m.global_transform * m.get_aabb()).end.y)
	if top > 0.0:
		body.scale = Vector3.ONE * (demo.MODEL_HEIGHT / top)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.get_active_material(0) as BaseMaterial3D
		var mat: ShaderMaterial = demo._toon(Color.WHITE)
		if src != null and src.albedo_texture != null:
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("use_tex", true)
		m.material_override = mat
	bind_gear(body)
	demo._anim = body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a: String in ["Idle", "Running_A", "Walking_A", "Blocking"]:
		if demo._anim.has_animation(a):
			demo._anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	# ponto de origem dos golpes/flechas: a mão da arma
	var hand := body.find_child("handslot_r", true, false) as Node3D
	var tip := Node3D.new()
	hand.add_child(tip)
	tip.position = Vector3(0, 0.3, 0)
	demo._p.staff = tip
	if id == "archer":
		_build_bow(body.find_child("handslot_l", true, false) as Node3D)
		var quiver := Node3D.new()
		(body.find_child("chest", true, false) as Node3D).add_child(quiver)
		_arrow_bundle(quiver)


## Arco procedural (o pacote só tem bestas): lâminas curvas de madeira + corda.
func _build_bow(hand: Node3D) -> void:
	var wood: ShaderMaterial = demo._toon(Color(0.72, 0.48, 0.24))  # claro: contrasta com o capuz verde
	weapon_mat = wood
	weapon_base = Color(0.72, 0.48, 0.24)
	_string_mat = demo._toon(Color(0.9, 0.88, 0.8))
	var bow := Node3D.new()
	hand.add_child(bow)
	(gear_nodes.get_or_add("weapon", []) as Array).append(bow)
	bow.rotation_degrees = Vector3(0, 90, 0)
	var segs := 7
	var half_h := 0.78
	var pts: Array[Vector3] = []
	for i in segs + 1:
		var k := float(i) / segs * 2.0 - 1.0  # -1..1
		pts.append(Vector3(0.0, k * half_h, -0.22 * (1.0 - k * k)))
	for i in segs:
		var a := pts[i]
		var b := pts[i + 1]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.06 if absf(i - segs * 0.5) < 1.5 else 0.045
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 5
		var m: MeshInstance3D = demo._mesh(cyl, wood, (a + b) * 0.5, bow)
		m.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var string := CylinderMesh.new()
	string.top_radius = 0.012
	string.bottom_radius = 0.012
	string.height = half_h * 2.0
	string.radial_segments = 3
	demo._mesh(string, _string_mat, Vector3.ZERO, bow)


func _arrow_bundle(parent: Node3D) -> void:
	var leather: ShaderMaterial = demo._toon(Color(0.36, 0.22, 0.12))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.07
	cyl.height = 0.5
	cyl.radial_segments = 6
	var q: MeshInstance3D = demo._mesh(cyl, leather, Vector3(0.12, 0.05, 0.22), parent, Vector3(25, 0, -20))
	for i in 3:
		var f := BoxMesh.new()
		f.size = Vector3(0.05, 0.1, 0.01)
		demo._mesh(f, demo._toon(Color(0.85, 0.82, 0.75)), Vector3(-0.03 + i * 0.03, 0.3, 0), q)


# ------------------------------------------------------------------ ataque básico

## Chamado no instante do golpe/disparo (attack_hit da animação).
func primary() -> void:
	match String(cfg.attack):
		"fireball":
			demo._fireball()
		"melee":
			_melee(float(cfg.melee_range), float(cfg.melee_arc_deg), demo._adventure.basic_damage() if demo._adventure != null else 10)
		"arrow":
			_arrow(1.0, false, float(cfg.arrow_life))


## Golpe em arco à frente: atinge TODOS os inimigos no setor (alcance + ângulo), sem atravessar parede.
func _melee(reach: float, arc_deg: float, damage: int) -> int:
	var origin: Vector3 = demo._player.global_position + Vector3(0, 0.8, 0)
	var hits := 0
	for body in _enemies_near(origin, reach + 0.5):
		var to: Vector3 = (body as Node3D).global_position - demo._player.global_position
		to.y = 0
		if to.length() > reach + 0.45:  # 0,45 ≈ raio da cápsula do monstro
			continue
		if to.length() > 0.2 and rad_to_deg(Vector3(demo._aim.x, 0, demo._aim.z).angle_to(to.normalized())) > arc_deg * 0.5:
			continue
		if not _clear_line(origin, (body as Node3D).global_position + Vector3(0, 0.6, 0), body):
			continue
		if demo._adventure != null and demo._adventure.hit(body, damage):
			hits += 1
			demo._burst((body as Node3D).global_position + Vector3(0, 0.7, 0))
	_slash_fx(reach, arc_deg)
	return hits


func _enemies_near(center: Vector3, radius: float) -> Array:
	var space: PhysicsDirectSpaceState3D = demo._player.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	q.shape = s
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = ENEMY_LAYER
	var out: Array = []
	for h in space.intersect_shape(q, 32):
		if String(h.collider.get_meta("kind", "")) == "enemy" and not out.has(h.collider):
			out.append(h.collider)
	return out


func _clear_line(from: Vector3, to: Vector3, target: Object) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [demo._player.get_rid()]
	var hit: Dictionary = demo._player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == target


## Rastro do golpe: leque claro e curto no chão à frente.
func _slash_fx(reach: float, arc_deg: float) -> void:
	var p: Vector3 = demo._player.global_position
	var yaw := atan2(demo._aim.x, demo._aim.z)
	for i in 5:
		var a := yaw + deg_to_rad(lerpf(-arc_deg * 0.4, arc_deg * 0.4, i / 4.0))
		var at := p + Vector3(sin(a), 0, cos(a)) * reach * 0.8 + Vector3(0, 0.8, 0)
		demo._ghost_spark(at)


# ------------------------------------------------------------------ flecha

## Flecha: rápida, reta, na altura do peito, mira o centro do alvo (mesma regra da bola de fogo).
func _arrow(damage_mult: float, pierce: bool, life: float) -> void:
	var n := Node3D.new()
	demo._vp.add_child(n)
	var chest: Vector3 = demo._player.global_position + Vector3(0, demo.SHOT_HEIGHT, 0)
	var aim_point: Vector3 = demo._attack_target
	if is_instance_valid(demo._attack_node) and demo._attack_node.is_inside_tree():
		aim_point = demo._target_center(demo._attack_node)
	else:
		aim_point.y = chest.y
	var dir := aim_point - chest
	if Vector2(dir.x, dir.z).length() < 0.05:
		dir = demo._aim
	dir = dir.normalized()
	n.global_position = chest + dir * 0.35
	n.look_at(n.global_position + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.018
	shaft.bottom_radius = 0.018
	shaft.height = 0.7
	shaft.radial_segments = 4
	var color := Color(0.75, 0.9, 1.0) if pierce else Color(0.55, 0.38, 0.2)
	demo._mesh(shaft, demo._toon(color, color if pierce else Color.BLACK, 2.5 if pierce else 0.0), Vector3.ZERO, n, Vector3(90, 0, 0))
	var head := CylinderMesh.new()
	head.top_radius = 0.0
	head.bottom_radius = 0.045
	head.height = 0.12
	head.radial_segments = 4
	demo._mesh(head, demo._toon(Color(0.8, 0.82, 0.85)), Vector3(0, 0, -0.38), n, Vector3(-90, 0, 0))
	if pierce:
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 0.85, 1.0)
		l.omni_range = 2.5
		l.light_energy = 1.5
		n.add_child(l)
	var base: int = demo._adventure.basic_damage() if demo._adventure != null else 10
	demo._projectiles.append({"node": n, "vel": dir * float(cfg.arrow_speed), "life": life, "from": chest,
		"kind": "arrow", "dmg": int(round(base * damage_mult)), "pierce": pierce, "hit": []})


# ------------------------------------------------------------------ Q / R

func cooldown_q() -> float:
	return float(cfg.q.cooldown)


func cooldown_r() -> float:
	return float(cfg.r.cooldown)


## Q do Guerreiro (Investida) e do Arqueiro (Salto Evasivo). Retorna se lançou.
func cast_q() -> bool:
	var adv = demo._adventure
	if adv != null and not adv.state.has_skill("blink"):
		return false
	if demo._blink_cd > 0.0 or demo._dodge_t >= 0.0 or demo._attack_t >= 0.0:
		return false
	if adv != null and not adv.spend("blink"):
		return false
	var q: Dictionary = cfg.q
	var tgt: Vector3 = demo._mouse_ground()
	var d := Vector3(tgt.x - demo._player.global_position.x, 0, tgt.z - demo._player.global_position.z)
	var dir: Vector3 = d.normalized() if d.length() > 0.3 else -demo._model.global_transform.basis.z
	demo._blink_cd = float(q.cooldown)
	match String(q.id):
		"charge":
			_charge_hit.clear()
			demo._begin_dash(dir, float(q.distance) / float(q.time), float(q.time), String(q.anim), "charge")
			demo._aim = dir
		"leap":
			# salta PARA TRÁS em relação à mira: abre distância do que está perto
			demo._begin_dash(-dir, float(q.distance) / float(q.time), float(q.time), String(q.anim), "leap")
			demo._aim = dir
	return true


## Chamado a cada quadro durante a Investida: o primeiro inimigo à frente leva o golpe e ela para.
func dash_tick(kind: String) -> bool:
	if kind != "charge":
		return false
	var p: Vector3 = demo._player.global_position
	for body in _enemies_near(p + Vector3(0, 0.7, 0), 1.3):
		if body in _charge_hit:
			continue
		_charge_hit.append(body)
		var dmg := int(round(float(demo._adventure.basic_damage() if demo._adventure != null else 10) * float(cfg.q.damage_mult)))
		if demo._adventure != null and demo._adventure.hit(body, dmg):
			demo._burst((body as Node3D).global_position + Vector3(0, 0.8, 0))
			demo._shockwave(p, 1.2)
			return true  # para no impacto
	return false


## R do Guerreiro (Redemoinho) e do Arqueiro (Flecha Perfurante).
func cast_r() -> bool:
	var adv = demo._adventure
	if adv == null or not adv.state.has_skill("ring") or adv.ring_cd > 0.0:
		return false
	if demo._dodge_t >= 0.0 or demo._attack_t >= 0.0:
		return false
	if not adv.spend("ring"):
		return false
	var r: Dictionary = cfg.r
	adv.ring_cd = float(r.cooldown)
	match String(r.id):
		"whirl":
			var dmg := int(round(float(adv.basic_damage()) * float(r.damage_mult)))
			var hits := _melee(float(r.radius), 360.0, dmg)
			demo._shockwave(demo._player.global_position, float(r.radius))
			demo._play_once(String(r.anim), 1.4)
			return hits >= 0
		"pierce":
			demo._hover_node = null
			var tgt: Vector3 = demo._mouse_ground()
			demo._attack_target = tgt
			demo._attack_node = demo._hover_node
			var d := Vector3(tgt.x - demo._player.global_position.x, 0, tgt.z - demo._player.global_position.z)
			if d.length() > 0.1:
				demo._aim = d.normalized()
			_arrow(float(r.damage_mult), true, float(r.arrow_life))
			demo._play_once(String(cfg.attack_anim), 1.6)
	return true
