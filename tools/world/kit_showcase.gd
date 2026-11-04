extends SceneTree
## Vitrine dos kits de mundo: uma casinha montada com peças do Dungeon (piso, paredes
## com porta e janela, móveis) + amostra das peças do Hexagon, ao lado do Knight a 1,8 m.
## Rode JANELADO (precisa de GPU):
##   godot --path . -s res://tools/world/kit_showcase.gd -- --shot
## Com --shot grava production/qa/evidence/world-kit-*.png e sai; sem, fica aberta.

const KNIGHT := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Knight.glb"
const PROPS := "res://assets/world/props/"
const HEIGHT := 1.8
const OUT := "res://production/qa/evidence/"

## [nome do arquivo, alvo da câmera, yaw (graus), pitch (graus), tamanho ortográfico]
const SHOTS := [
	["world-kit-house", Vector3(0, 0.8, 0.5), 25.0, -42.0, 13.0],
	["world-kit-interior", Vector3(0, 0, 0), 0.0, -72.0, 10.0],
	["world-kit-village", Vector3(14, 1.0, 2), 20.0, -38.0, 26.0],
]

var _world: Node3D
var _cam: Camera3D


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_build_env()
	_build_house()
	_build_village()
	_knight(Vector3(-1.5, 0, 4.6), 0.0)
	_knight(Vector3(1.4, 0, 0.6), 200.0)
	_knight(Vector3(9.5, 0, 4.5), -30.0)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_world.add_child(_cam)
	_aim(SHOTS[0])
	if "--shot" in OS.get_cmdline_user_args():
		_shoot()


func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for s: Array in SHOTS:
		_aim(s)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := ProjectSettings.globalize_path(OUT + String(s[0]) + ".png")
		img.save_png(path)
		print("salvo ", path)
		# prévia do visual pixel: reduz 3x sem filtro e amplia de volta
		var px := img.duplicate() as Image
		var sz := px.get_size()
		px.resize(sz.x / 3, sz.y / 3, Image.INTERPOLATE_NEAREST)
		px.resize(sz.x, sz.y, Image.INTERPOLATE_NEAREST)
		px.save_png(path.replace(".png", "-pixel.png"))
	quit()


func _aim(s: Array) -> void:
	var target: Vector3 = s[1]
	var b := Basis.from_euler(Vector3(deg_to_rad(s[3]), deg_to_rad(s[2]), 0))
	_cam.transform = Transform3D(b, target + b.z * 40.0)
	_cam.size = s[4]
	_cam.far = 200.0


func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.5, 0.27)
	ground.material_override = mat
	ground.position.y = -0.02
	_world.add_child(ground)


## Instancia uma peça. `v` = variante; `yaw` em graus.
func _prop(cat: String, id: String, pos: Vector3, yaw := 0.0, v := 0) -> Node3D:
	var n := (load(PROPS + cat + "/" + id + ".tscn") as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation.y = deg_to_rad(yaw)
	_world.add_child(n)
	n.set(&"variant", v)
	return n


## Casa de 6 x 6 m (4 x 4 células): paredes nas arestas, porta e janela na frente.
func _build_house() -> void:
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			_prop("floor", "floor_wood_large", Vector3(x, 0, z))
	# frente (z = +3): porta e janela
	_prop("wall", "wall_doorway", Vector3(-1.5, 0, 3))
	_prop("window", "wall_window", Vector3(1.5, 0, 3))
	# fundo
	_prop("wall", "wall", Vector3(-1.5, 0, -3))
	_prop("wall", "wall_shelves", Vector3(1.5, 0, -3))
	# laterais
	_prop("wall", "wall", Vector3(-3, 0, -1.5), 90)
	_prop("window", "wall_window", Vector3(-3, 0, 1.5), 90, 1)
	_prop("wall", "wall", Vector3(3, 0, -1.5), 90, 1)
	_prop("window", "wall_window", Vector3(3, 0, 1.5), 90)
	for c in [Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(-3, 0, 3), Vector3(3, 0, 3)]:
		_prop("decor", "pillar", c, 0, 1)
	# móveis
	_prop("furniture", "bed", Vector3(-1.9, 0, -1.4), 0, 1)
	_prop("furniture", "table", Vector3(0.6, 0, -0.6), 0, 1)
	_prop("furniture", "chair", Vector3(-0.4, 0, -0.6), 90)
	_prop("furniture", "chair", Vector3(1.6, 0, -0.6), -90)
	_prop("furniture", "barrel", Vector3(2.2, 0, 2.2))
	_prop("furniture", "crate", Vector3(2.2, 0, 1.3))
	_prop("furniture", "chest", Vector3(-2.1, 0, 1.0), 90)
	_prop("light", "torch_wall", Vector3(-0.4, 1.4, -2.62))
	_prop("decor", "banner", Vector3(-3.0 + 0.1, 0.3, 0.0), 90, 3)
	# porta da frente: tocha, barril e escada de amostra
	_prop("stairs", "stairs", Vector3(-8.5, 0, -3.0))
	_prop("furniture", "table_long", Vector3(-6.5, 0, 3.0), 90, 2)


## Amostra das peças do Hexagon em fileiras a leste da casa.
func _build_village() -> void:
	# cercas e portão
	_prop("fence", "fence_wood", Vector3(7.5, 0, 6.5))
	_prop("fence", "fence_wood_gate", Vector3(10.5, 0, 6.5))
	_prop("fence", "fence_stone", Vector3(13.5, 0, 6.5))
	_prop("fence", "fence_stone_gate", Vector3(16.5, 0, 6.5))
	# poço, carrinho, sacos, caixas, tenda
	_prop("decor", "well", Vector3(11.5, 0, 2.5))
	_prop("decor", "cart", Vector3(8.0, 0, 1.5), 30)
	_prop("decor", "sacks", Vector3(9.0, 0, 3.0))
	_prop("decor", "street_crate", Vector3(8.0, 0, 3.4))
	_prop("decor", "street_crate", Vector3(8.4, 0, 4.2), 0, 2)
	_prop("decor", "lumber_pile", Vector3(14.5, 0, 3.5))
	_prop("decor", "tent", Vector3(17.5, 0, 2.5))
	# árvores e pedras
	_prop("tree", "tree_round", Vector3(21.5, 0, 5.0))
	_prop("tree", "tree_pine", Vector3(24.5, 0, 3.5))
	_prop("tree", "tree_grove", Vector3(27.5, 0, 0.0))
	_prop("tree", "tree_stump", Vector3(21.0, 0, 1.5))
	_prop("rock", "rock_small", Vector3(19.5, 0, 6.0))
	_prop("rock", "rock_medium", Vector3(22.5, 0, 7.5))
	_prop("rock", "rock_large", Vector3(25.5, 0, 7.0))
	# casas, muralha, ponte
	_prop("building", "house_small", Vector3(8.5, 0, -4.0))
	_prop("building", "house_tall", Vector3(15.0, 0, -4.5))
	_prop("wall", "town_wall", Vector3(-3.0, 0, -9.0))
	_prop("wall", "town_wall_gate", Vector3(3.0, 0, -9.0))
	_prop("wall", "town_wall_corner", Vector3(9.5, 0, -10.5))
	_prop("bridge", "bridge", Vector3(22.0, 0, -5.0), 90)


func _knight(pos: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = deg_to_rad(yaw)
	_world.add_child(holder)
	var body := (load(KNIGHT) as PackedScene).instantiate() as Node3D
	holder.add_child(body)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		(mi as MeshInstance3D).visible = n.begins_with("Knight_") and not n.contains("Cape")
	var top := 0.0
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.visible:
			continue
		var t := Transform3D.IDENTITY
		var p: Node = m
		while p != body and p != null:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		top = maxf(top, (t * m.get_aabb()).end.y)
	if top > 0.0:
		body.scale = Vector3.ONE * (HEIGHT / top)
	var anim := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation("Idle"):
		anim.play("Idle")
