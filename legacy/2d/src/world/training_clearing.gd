class_name TrainingClearing
extends Node2D
## Clareira de Treino: monta o mundo a partir de legacy/2d/assets/data/clearing_layout.json
## (gerado por legacy/2d/tools/art/gen_art.gd) e legacy/2d/assets/data/world_ambience.json, e recebe os
## jogadores pela sessão de rede (NetSession).
##
## Camadas, de baixo para cima:
##   chão (-10) → sombras das copas com luz manchada (-8) → sombras de contato (-6/-5)
##   → mundo com y-sort (árvores, vegetação, fauna, jogadores, inimigos) → partículas (5)
##   → feixes de luz (6) → CanvasLayer: primeiro plano → vinheta.
## Roda dentro do SubViewport de pixel art do GameMain; o HUD fica fora, em resolução nativa.
##
## Uso (GameMain):
##   clearing.local_player_ready.connect(...)
##   clearing.start_solo("Jeff", "fire_mage")      # ou start_host / start_join
##   clearing.game_input(event, mouse_world)       # input repassado pela raiz

## O avatar do jogador local entrou no mundo (HUD se conecta ao kit).
signal local_player_ready(kit: ClassKit)

const LAYOUT_PATH := "res://legacy/2d/assets/data/clearing_layout.json"
const AMBIENCE_PATH := "res://legacy/2d/assets/data/world_ambience.json"
const ART := "res://legacy/2d/assets/art/"
const SHADERS := "res://legacy/2d/src/shaders/"
## Texturas por tipo de prop; o índice "v" do layout escolhe a variante.
const PROP_ART := {
	"fern": ["env/fern_0.png", "env/fern_1.png"],
	"bush": ["env/bush_0.png", "env/bush_1.png", "env/bush_2.png"],
	"grass_tall": ["env/grass_tall_0.png", "env/grass_tall_1.png", "env/grass_tall_2.png"],
	"mushroom": ["env/mushroom_0.png", "env/mushroom_1.png"],
	"flowers": ["env/flowers_0.png", "env/flowers_1.png", "env/flowers_2.png", "env/flowers_3.png"],
	"rock": ["env/rock_0.png", "env/rock_1.png", "env/rock_2.png"],
	"log": ["env/log.png"],
	"stump": ["env/stump.png"],
}
## Sombra de contato por tipo: [escala x, escala y, alfa]. Ausente = sem sombra.
const CONTACT_SHADOW := {
	"bush": [1.2, 1.0, 0.7], "fern": [1.0, 0.8, 0.45], "rock": [1.0, 0.9, 0.75],
	"log": [2.0, 0.9, 0.7], "stump": [1.0, 0.9, 0.75], "mushroom": [0.35, 0.3, 0.5],
}
## Quanto a base do sprite fica abaixo do pivô (props desenhados como massa, não em pé).
const BASE_INSET := {"rock": 3, "log": 3, "stump": 2, "bush": 2}
const MOVE_KEYS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
	"dodge": [KEY_SPACE, KEY_SHIFT],
}
## Primeiro plano preso aos cantos da tela: [textura, canto, deslocamento, espelhado].
const FOREGROUND := [
	["env/fg_canopy_0.png", Vector2(0, 0), Vector2(-40, -48), false],
	["env/fg_canopy_1.png", Vector2(1, 0), Vector2(-200, -52), true],
	["env/fg_fern.png", Vector2(0, 1), Vector2(-12, -74), false],
	["env/fg_fern.png", Vector2(1, 1), Vector2(-138, -70), true],
]
const CAMERA_OFFSET := Vector2(0, -20)
const SHAKE_PX := 6.0
const SHAKE_DECAY := 1.6

var combat: CombatWorld
var net: NetSession
## Faz o mago/guerreiro local jogar sozinho (argumento `-- --demo`).
var demo := false

var _layout: Dictionary
var _amb: Dictionary
var _world: Node2D
var _shadows: Node2D
var _focus: Node2D
var _camera: Camera2D
var _ambient: Node2D
var _fg_layer: CanvasLayer
var _fg_items: Array[Dictionary] = []
var _grass_mat: ShaderMaterial
var _trees: Array[Dictionary] = []
var _fireflies: Array[Dictionary] = []
var _tex_cache := {}
var _cam_prev := Vector2.ZERO
var _cam_lag := Vector2.ZERO
var _fade_alpha := 0.45
var _local_avatar: PlayerAvatar
var _local_kit: ClassKit
var _trauma := 0.0
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_layout = JsonData.load_dict(LAYOUT_PATH)
	_amb = JsonData.load_dict(AMBIENCE_PATH)
	if _layout.is_empty() or _amb.is_empty():
		push_error("TrainingClearing: dados ausentes — rode legacy/2d/tools/art/gen_art.gd")
		return
	_register_input()
	_fade_alpha = float(_amb.light.get("canopy_fade_alpha", _fade_alpha))
	_build_environment()
	_build_ground()
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)
	_build_focus()
	_build_trees()
	_build_props()
	_build_critters()
	_build_god_rays()
	_build_particles()
	_build_fireflies()
	_build_foreground()
	_build_session()
	_cam_prev = _camera.get_screen_center_position()


# ------------------------------------------------------------------ sessão e jogadores

func start_solo(player_name: String, cls: String) -> void:
	net.start_solo(player_name, cls)


func start_host(port: int, player_name: String, cls: String) -> String:
	return net.host(port, player_name, cls)


func start_join(address: String, port: int, player_name: String, cls: String) -> String:
	return net.join(address, port, player_name, cls)


## Cria o avatar e o kit de um jogador (chamado em todos os peers pela NetSession).
func spawn_player(peer: int, player_name: String, cls: String, pos: Vector2) -> void:
	var def: Dictionary = combat.classes[cls]
	var avatar := PlayerAvatar.new()
	avatar.name = "P%d" % peer
	avatar.peer_id = peer
	avatar.display_name = player_name
	avatar.position = pos
	avatar.set_multiplayer_authority(peer)
	avatar.ready_peers = func() -> Array: return net.players_info.keys()
	_world.add_child(avatar)
	var stats := AttributeSet.build(def, 1, combat.derived)
	avatar.setup(_amb.player, def, stats, _tex(String(def.get("sheet", "chars/spr_mage_fire_sheet.png"))),
		_tex("fx/light_radial.png"), _tex("fx/mote.png"), _tex("fx/soft_shadow.png"),
		float(combat.net_cfg.get("avatar_send_hz", 30)), combat.rules.get("movement", {}))
	var kit := ClassKit.new()
	kit.name = "Kit"
	avatar.add_child(kit)
	avatar.kit = kit
	kit.setup(avatar, combat, cls, peer)
	combat.register_player(peer, avatar, kit)
	if peer == multiplayer.get_unique_id():
		_local_avatar = avatar
		_local_kit = kit
		kit.demo = demo
		local_player_ready.emit(kit)


func despawn_player(peer: int) -> void:
	var avatar := combat.avatar_of(peer)
	combat.unregister_player(peer)
	if avatar != null:
		# Sai da árvore já: um respawn (troca de classe) reusa o mesmo nome de nó.
		avatar.get_parent().remove_child(avatar)
		avatar.queue_free()


## Input repassado pela raiz (o mundo roda num SubViewport). `mouse_world` já está em
## coordenadas do mundo.
func game_input(event: InputEvent, mouse_world: Vector2) -> void:
	if _local_kit != null and _local_kit.handle_input(event, mouse_world):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E:
				combat.request_command.rpc_id(1, "slimes")
			KEY_R:
				combat.request_command.rpc_id(1, "reset")
			KEY_P:
				combat.request_command.rpc_id(1, "pvp")
			KEY_C:
				var info: Dictionary = net.players_info.get(multiplayer.get_unique_id(), {})
				if not info.is_empty():
					net.request_class.rpc_id(1, net.next_class(String(info["class"])))


## Atualiza a pré-visualização de mira (alcance + área no chão) do jogador local.
func update_aim(mouse_world: Vector2) -> void:
	if _local_avatar != null and is_instance_valid(_local_avatar):
		_local_avatar.aim_direction = (mouse_world - _local_avatar.global_position).normalized()
	if _local_kit == null or _local_kit.aiming == "":
		combat.vfx.aim = {}
		return
	var ab := _local_kit.ability(_local_kit.aiming)
	var radius := 0.0
	if ab.has("aoe"):
		radius = float(ab.aoe.radius)
	combat.vfx.aim = {
		"origin": _local_avatar.global_position, "range": _local_kit.effective_range(ab),
		"point": _local_kit.aim_point(ab, mouse_world), "radius": radius,
		"cone": float(ab.get("arc_deg", 0.0)) if String(ab.type) == "melee_cone" else 0.0,
	}
	if String(ab.type) == "melee_cone":
		combat.vfx.aim.radius = float(ab.range)


func _build_session() -> void:
	combat = CombatWorld.new()
	combat.name = "Combat"
	add_child(combat)
	var textures := {"light": _tex("fx/light_radial.png"), "shadow": _tex("fx/soft_shadow.png")}
	var enemy_defs: Dictionary = JsonData.load_dict(CombatWorld.ENEMIES_PATH).get("enemies", {})
	for id: String in enemy_defs:
		textures[id] = _tex(String(enemy_defs[id].texture))
	combat.setup(_world, textures)
	combat.local_shake.connect(func(amount: float) -> void: _trauma = minf(1.0, _trauma + amount))
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	var playable: Array = JsonData.load_dict(CombatWorld.CLASSES_PATH).get("playable", ["fire_mage"])
	net.setup(self, combat.net_cfg, playable)


# ------------------------------------------------------------------ quadro a quadro

func _process(delta: float) -> void:
	if _focus == null:
		return
	if _local_avatar != null and is_instance_valid(_local_avatar):
		_focus.global_position = _local_avatar.global_position
	var p := _focus.global_position
	_grass_mat.set_shader_parameter("player_pos", p)
	_update_canopy_fade(p, delta)
	var cam := _camera.get_screen_center_position()
	_ambient.global_position = cam
	_update_fireflies(delta)
	_update_foreground(cam, delta)
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	var amount := SHAKE_PX * _trauma * _trauma * combat_shake_scale()
	_camera.offset = Vector2(_shake_rng.randf_range(-1, 1), _shake_rng.randf_range(-1, 1)).round() * amount if amount > 0.01 else Vector2.ZERO


## Multiplicador do tremor de tela (0 = desligado; tecla K na raiz).
var shake_scale := 1.0


func combat_shake_scale() -> float:
	return shake_scale


func _build_focus() -> void:
	# Foco da câmera e da fauna: segue o jogador local; antes disso fica no ponto inicial.
	_focus = Node2D.new()
	_focus.name = "Focus"
	var start: Array = _layout.player_start
	_focus.position = Vector2(start[0], start[1])
	add_child(_focus)
	_camera = Camera2D.new()
	_camera.position = CAMERA_OFFSET
	_focus.add_child(_camera)
	_camera.make_current()


# ------------------------------------------------------------------ montagem do mundo

func _tex(rel: String) -> Texture2D:
	if not _tex_cache.has(rel):
		_tex_cache[rel] = load(ART + rel) as Texture2D
	return _tex_cache[rel]


func _shader_mat(file: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADERS + file) as Shader
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	return mat


func _register_input() -> void:
	for action: String in MOVE_KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in MOVE_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _build_environment() -> void:
	var light: Dictionary = _amb.light
	var modulate_node := CanvasModulate.new()
	modulate_node.color = JsonData.to_color(light.canvas_tint)
	add_child(modulate_node)

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = float(light.glow_intensity)
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = float(light.saturation)
	env.adjustment_contrast = float(light.contrast)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var post := CanvasLayer.new()
	post.layer = 2
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = _shader_mat("canvas_post_vignette.gdshader", {"strength": float(light.vignette)})
	post.add_child(vignette)
	add_child(post)


func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.texture = _tex("env/ground.png")
	ground.centered = false
	ground.z_index = -10
	add_child(ground)
	_shadows = Node2D.new()
	_shadows.z_index = -8
	add_child(_shadows)


func _build_trees() -> void:
	var wind: Dictionary = _amb.wind
	var light: Dictionary = _amb.light
	var shadow_mat := _shader_mat("canvas_env_canopy_shadow.gdshader", {
		"strength": float(light.canopy_shadow_strength), "drift": float(light.canopy_shadow_drift)})
	var mats: Array[ShaderMaterial] = []
	for meta: Dictionary in _layout.tree_variants:
		mats.append(_shader_mat("canvas_env_wind_sway.gdshader", {
			"sway_px": float(wind.tree_sway_px), "sway_speed": float(wind.tree_sway_speed),
			"canopy_v": float(meta.canopy_v)}))
	for t: Dictionary in _layout.trees:
		var v := int(t.v)
		var meta: Dictionary = _layout.tree_variants[v]
		var pos := Vector2(t.x, t.y)
		var spr := Sprite2D.new()
		spr.texture = _tex(meta.texture)
		spr.centered = false
		spr.offset = -Vector2(meta.pivot[0], meta.pivot[1])
		spr.position = pos
		spr.material = mats[v]
		_world.add_child(spr)

		var canopy_shadow := Sprite2D.new()
		canopy_shadow.texture = _tex("fx/canopy_shadow.png")
		canopy_shadow.position = pos + Vector2(16, -2)
		canopy_shadow.scale = Vector2(meta.shadow, float(meta.shadow) * 0.85)
		canopy_shadow.material = shadow_mat
		_shadows.add_child(canopy_shadow)
		_add_contact_shadow(pos, Vector2(1.3, 1.0), 0.85, _shadows)
		_add_collider(pos, float(t.r))
		_trees.append({"sprite": spr, "pos": pos, "canopy": Vector2(meta.canopy[0], meta.canopy[1])})


func _build_props() -> void:
	var wind: Dictionary = _amb.wind
	_grass_mat = _shader_mat("canvas_env_grass_bend.gdshader", {
		"sway_px": float(wind.grass_sway_px), "bend_px": float(wind.grass_bend_px),
		"bend_radius": float(wind.grass_bend_radius)})
	var bush_mat := _shader_mat("canvas_env_wind_sway.gdshader", {
		"sway_px": float(wind.bush_sway_px), "sway_speed": 1.4, "canopy_v": 1.0, "rustle": 0.6})
	for p: Dictionary in _layout.props:
		var kind: String = p.kind
		var files: Array = PROP_ART.get(kind, [])
		if files.is_empty():
			continue
		var tex := _tex(files[int(p.v) % files.size()])
		var pos := Vector2(p.x, p.y)
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + int(BASE_INSET.get(kind, 0)))
		spr.position = pos
		if kind == "grass_tall":
			spr.material = _grass_mat
		elif kind in ["bush", "fern", "flowers"]:
			spr.material = bush_mat
		_world.add_child(spr)
		if CONTACT_SHADOW.has(kind):
			var s: Array = CONTACT_SHADOW[kind]
			_add_contact_shadow(pos, Vector2(s[0], s[1]) * tex.get_width() / 32.0, float(s[2]), _shadows)
		if p.has("r"):
			_add_collider(pos, float(p.r))


func _add_contact_shadow(pos: Vector2, scl: Vector2, alpha: float, parent: Node) -> void:
	var s := Sprite2D.new()
	s.texture = _tex("fx/soft_shadow.png")
	s.position = pos + Vector2(2, 0)
	s.scale = scl
	s.modulate = Color(1, 1, 1, alpha)
	s.z_index = 2
	parent.add_child(s)


func _add_collider(pos: Vector2, radius: float) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _build_critters() -> void:
	var cfg: Dictionary = _amb.critters
	var size: Array = _layout.world
	var bounds := Rect2(24, 40, float(size[0]) - 48.0, float(size[1]) - 60.0)
	var shadow := _tex("fx/soft_shadow.png")
	var i := 0
	for c: Dictionary in _layout.critters:
		i += 1
		var pos := Vector2(c.x, c.y)
		match String(c.kind):
			"butterfly":
				var b := Butterfly.new()
				_world.add_child(b)
				b.setup(_tex("critters/butterfly.png"), shadow, int(c.v), pos, _focus, float(cfg.butterfly_flee_px), i * 1.37)
			"rabbit":
				var r := Rabbit.new()
				_world.add_child(r)
				r.setup(_tex("critters/rabbit.png"), shadow, pos, _focus, cfg, bounds, i * 97)
			"squirrel":
				var s := Squirrel.new()
				_world.add_child(s)
				var tree: Array = c.tree
				s.setup(_tex("critters/squirrel.png"), shadow, pos, Vector2(tree[0], tree[1]), _focus, cfg, i * 53)


func _build_god_rays() -> void:
	var light: Dictionary = _amb.light
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var center := Vector2(800, 560)
	for k in int(light.god_rays):
		var ray := Sprite2D.new()
		ray.texture = _tex("fx/pixel.png")
		ray.position = center + Vector2(rng.randf_range(-300, 300), rng.randf_range(-220, 180))
		ray.scale = Vector2(rng.randf_range(24, 46), rng.randf_range(220, 320))
		ray.rotation = deg_to_rad(-32.0)
		ray.z_index = 6
		ray.material = _shader_mat("canvas_fx_god_ray.gdshader", {
			"intensity": float(light.god_ray_intensity) * rng.randf_range(0.7, 1.2), "phase": rng.randf() * TAU})
		add_child(ray)


func _build_particles() -> void:
	var counts: Dictionary = _amb.particles
	_ambient = Node2D.new()
	_ambient.z_index = 5
	add_child(_ambient)

	var leaves := CPUParticles2D.new()
	leaves.texture = _tex("fx/leaf.png")
	leaves.amount = int(counts.leaves)
	leaves.lifetime = 9.0
	leaves.preprocess = 9.0
	leaves.local_coords = false
	leaves.position = Vector2(0, -260)
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(520, 20)
	leaves.direction = Vector2(0.25, 1.0)
	leaves.spread = 20.0
	leaves.gravity = Vector2(4, 9)
	leaves.initial_velocity_min = 6.0
	leaves.initial_velocity_max = 16.0
	leaves.angular_velocity_min = -140.0
	leaves.angular_velocity_max = 140.0
	leaves.angle_min = -180.0
	leaves.angle_max = 180.0
	var leaf_colors := Gradient.new()
	leaf_colors.set_color(0, Color("8cc85a"))
	leaf_colors.set_color(1, Color("e0a040"))
	leaf_colors.add_point(0.5, Color("d8d060"))
	leaves.color_initial_ramp = leaf_colors
	_ambient.add_child(leaves)

	var pollen := CPUParticles2D.new()
	pollen.texture = _tex("fx/mote.png")
	pollen.amount = int(counts.pollen)
	pollen.lifetime = 6.0
	pollen.preprocess = 6.0
	pollen.local_coords = false
	pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pollen.emission_rect_extents = Vector2(480, 260)
	pollen.direction = Vector2(0.3, -1.0)
	pollen.spread = 180.0
	pollen.gravity = Vector2(1, -3)
	pollen.initial_velocity_min = 2.0
	pollen.initial_velocity_max = 6.0
	pollen.scale_amount_min = 0.5
	pollen.scale_amount_max = 1.0
	pollen.color = Color(1.5, 1.4, 1.0, 0.7)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.5, Color(1, 1, 1, 1))
	pollen.color_ramp = fade
	_ambient.add_child(pollen)


func _build_fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var count := int(_amb.particles.fireflies)
	for k in count:
		var t: Dictionary = _trees[rng.randi_range(0, _trees.size() - 1)]
		var home: Vector2 = t.pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 10))
		var fly := Sprite2D.new()
		fly.texture = _tex("fx/mote.png")
		fly.material = add_mat
		fly.modulate = Color(2.2, 2.6, 1.2)
		fly.z_index = 5
		var glow := PointLight2D.new()
		glow.texture = _tex("fx/light_radial.png")
		glow.texture_scale = 0.5
		glow.color = Color(0.8, 1.0, 0.5)
		glow.energy = 0.5
		fly.add_child(glow)
		add_child(fly)
		_fireflies.append({"node": fly, "light": glow, "home": home, "seed": rng.randf() * 10.0})


func _build_foreground() -> void:
	_fg_layer = CanvasLayer.new()
	_fg_layer.layer = 1
	add_child(_fg_layer)
	var k := 0
	for it: Array in FOREGROUND:
		var spr := Sprite2D.new()
		spr.texture = _tex(it[0])
		spr.centered = false
		spr.flip_h = it[3]
		_fg_layer.add_child(spr)
		_fg_items.append({"sprite": spr, "corner": it[1], "offset": it[2], "phase": k * 1.7})
		k += 1


# ------------------------------------------------------------------ atualização

func _update_canopy_fade(p: Vector2, delta: float) -> void:
	for t: Dictionary in _trees:
		var spr: Sprite2D = t.sprite
		var pos: Vector2 = t.pos
		var canopy: Vector2 = t.canopy
		var behind := p.y < pos.y - 2.0 and p.y > pos.y - canopy.y and absf(p.x - pos.x) < canopy.x * 0.42
		var target := _fade_alpha if behind else 1.0
		if not is_equal_approx(spr.modulate.a, target):
			spr.modulate.a = move_toward(spr.modulate.a, target, delta * 3.0)


func _update_fireflies(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f: Dictionary in _fireflies:
		var s: float = f.seed
		var node: Sprite2D = f.node
		var home: Vector2 = f.home
		node.position = home + Vector2(sin(t * 0.5 + s) * 30.0, cos(t * 0.37 + s * 2.0) * 18.0 - 14.0 + sin(t * 1.3 + s) * 4.0)
		var blink := clampf(sin(t * 1.6 + s * 3.0) * 1.5 + 0.5, 0.0, 1.0)
		node.modulate.a = blink
		var light: PointLight2D = f.light
		light.energy = 0.5 * blink


func _update_foreground(cam: Vector2, delta: float) -> void:
	# Parallax: o primeiro plano "atrasa" na direção oposta ao movimento da câmera.
	var view := get_viewport().get_visible_rect().size
	var vel := (cam - _cam_prev) / maxf(delta, 0.0001)
	_cam_prev = cam
	_cam_lag = _cam_lag.lerp((-vel * 0.05).limit_length(8.0), clampf(delta * 4.0, 0.0, 1.0))
	var t := Time.get_ticks_msec() / 1000.0
	for it: Dictionary in _fg_items:
		var spr: Sprite2D = it.sprite
		var corner: Vector2 = it.corner
		var offset: Vector2 = it.offset
		var ph: float = it.phase
		var base := corner * view + offset
		spr.position = (base + _cam_lag + Vector2(sin(t * 0.8 + ph) * 2.0, sin(t * 0.6 + ph) * 1.5)).round()
