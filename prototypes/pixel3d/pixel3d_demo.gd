# PROTOTYPE - NOT FOR PRODUCTION
# Pergunta: um mundo 3D renderizado em baixa resolução (luz em degraus + contorno +
# câmera presa ao pixel) fica bonito como pixel art, resolve o andar em qualquer direção
# e aguenta efeitos de fogo fortes (labaredas na silhueta + chamas de partícula)?
# Rodar: godot --path . res://prototypes/pixel3d/pixel3d_demo.tscn [-- --auto --pyro --shot=res://x.png]
extends Node

const SH := "res://prototypes/pixel3d/shaders/"
const BASE_H := 360            # altura interna (pixels de arte)
const PX_MIN := 1.0 / 44.0     # zoom mais perto
const PX_MAX := 1.0 / 20.0     # zoom mais longe (20% mais perto que 1/16, pedido do usuário)
var _pitch := -50.0
const SPEED := 4.2
const ACCEL_T := 0.10
const FRICTION_T := 0.08
const DODGE_T := 0.24
const DODGE_SPEED := 11.0
const ATTACK_T := 0.42
const GRAVITY := 22.0
const MAX_FALL := 18.0
## Altura de voo da bola de fogo acima do pé do mago (meio do peito).
const SHOT_HEIGHT := 0.85
const SHOT_SPEED := 13.0
const BLINK_RANGE := 7.0
const BLINK_OUT := 0.12        # some (dissolve 0→1)
const BLINK_IN := 0.2          # reaparece no destino
const BLINK_CD := 0.55
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const Life := preload("res://prototypes/pixel3d/pixel3d_life.gd")
const SkyCycle := preload("res://prototypes/pixel3d/pixel3d_sky.gd")
const Fauna := preload("res://prototypes/pixel3d/pixel3d_fauna.gd")
const Forest := preload("res://prototypes/pixel3d/pixel3d_forest.gd")
const Wildlife := preload("res://prototypes/pixel3d/pixel3d_wildlife.gd")
const Camps := preload("res://prototypes/pixel3d/pixel3d_camps.gd")
const Adventure := preload("res://prototypes/pixel3d/pixel3d_adventure.gd")
const AmbienceAudio := preload("res://prototypes/pixel3d/pixel3d_ambience_audio.gd")
const WorldLabels := preload("res://prototypes/pixel3d/world_labels_overlay.gd")
const Vocations := preload("res://prototypes/pixel3d/vocations.gd")
const HALF := 100.0            # meio lado do mapa (u)
const MAX_TREES := 1500
const WorldLayout := preload("res://prototypes/pixel3d/world/world_layout.gd")
const WorldChunks := preload("res://prototypes/pixel3d/world/world_chunks.gd")
const WorldProps := preload("res://prototypes/pixel3d/world/world_props.gd")
const HELP := "WASD andar · clique/segurar: fogo · Espaço: esquiva · E: interagir · Q: Eco · R: Anel · I: bolsa"
## Paletas de copa por bioma (verde, outono, florada, violeta, dourada).
const CANOPY := {
	"green": [Color(0.13, 0.32, 0.2), Color(0.2, 0.42, 0.2), Color(0.28, 0.5, 0.22)],
	"autumn": [Color(0.78, 0.4, 0.15), Color(0.68, 0.26, 0.13), Color(0.8, 0.58, 0.18)],
	"blossom": [Color(0.78, 0.46, 0.6), Color(0.84, 0.56, 0.68), Color(0.68, 0.36, 0.52)],
	"violet": [Color(0.48, 0.31, 0.66), Color(0.63, 0.44, 0.82), Color(0.36, 0.27, 0.56)],
	"golden": [Color(0.8, 0.62, 0.22), Color(0.72, 0.52, 0.16), Color(0.84, 0.68, 0.3)],
}
const FLOWER_COLORS := [Color(0.97, 0.95, 0.9), Color(1.0, 0.85, 0.3), Color(0.95, 0.5, 0.65), Color(0.55, 0.62, 1.0), Color(0.75, 0.5, 0.95), Color(1.0, 0.45, 0.3)]

var _vp: SubViewport
var _view: TextureRect
var _cam: Camera3D
var _cam_focus := Vector3.ZERO
## 1 pixel de arte = _px unidades de mundo (roda do mouse muda o zoom).
var _px := 1.0 / 26.0
var _scale := 3
var _noise: NoiseTexture2D
var _grass_mat: ShaderMaterial
var _player: CharacterBody3D
var _model: Node3D
var _p := {}
## [material, cor normal, cor do Piromante]
var _clothes: Array = []
var _rune_mat: ShaderMaterial
var _flame_draw: ShaderMaterial
var _pyro := false
var _pyro_nodes: Array[Node] = []
var _crystal: ShaderMaterial
## Malha do cajado do mago (tingida pelo cajado vestido) e força do brilho do cristal.
var _staff_mesh: MeshInstance3D
var _crystal_mult := 1.0
var _crystal_light: OmniLight3D
const WEAPON_LIGHTS := [
	{"label": "sem luz", "energy": 0.0, "range": 0.5, "emission": 0.0},
	{"label": "sutil", "energy": 0.65, "range": 3.2, "emission": 1.8},
	{"label": "acesa", "energy": 1.7, "range": 4.4, "emission": 3.5},
	{"label": "intensa", "energy": 2.5, "range": 5.2, "emission": 5.0},
]
var _weapon_glow := 2
var _aura_light: OmniLight3D
var _phase := 0.0
var _t := 0.0
var _attack_t := -1.0
var _fired := false
var _dodge_t := -1.0
var _dodge_dir := Vector3.FORWARD
var _aim := Vector3.FORWARD
var _attack_target := Vector3.FORWARD * 5.0
## Corpo mirado no clique (inimigo/tocha); a mira segue a posição dele até o disparo.
var _attack_node: Node3D = null
var _hover_node: Node3D = null
var _auto := false
var _projectiles: Array = []
var _help: Label
var _anim: AnimationPlayer
var _anim_cur := ""
var _capture := false
var _capture_walk := false
var _dress
var _life
var _sky
var _fauna
var _forest := Forest.new()
var _wildlife
var _camps
var _adventure
## Raiz de todo o cenário da superfície (escondida no andar -1).
var _world_root: Node3D
var _audio
## Textos do mundo em resolução nativa (estilo Tibia).
var world_labels
var _sun: DirectionalLight3D
var _env: Environment
## [posição, tamanho, bioma] de cada árvore (fadas e colmeias usam).
var _tree_spots: Array = []
## Arbustos na borda dos bosques (planejados com as árvores; desenhados pela fauna).
var edge_bushes: Array = []
var _chunks
var _props
## Desligar = todos os pedaços visíveis (só para medir o ganho em tools/measure_world_perf.gd).
var chunk_culling := true
var _scorch_tex: GradientTexture2D
var _ember_tex: GradientTexture2D
var _biome := FastNoiseLite.new()
var _toon_cache := {}
var _char_mats: Array[ShaderMaterial] = []
var _ghost_shader: Shader
var _ghost_t := 0.0
var _spark_mat: StandardMaterial3D
var _blink_t := -1.0
var _blink_cd := 0.0
var _blink_to := Vector3.ZERO
var _blink_dir := Vector3.FORWARD
var _blinked := false
var _dissolve := 0.0
## Vocação jogada (mage / warrior / archer) e sua lógica (vocations.gd).
var _class := "mage"
var _voc
var _speed := SPEED
## Investida/salto: parâmetros do "dash" atual (a esquiva comum usa os valores DODGE_*).
var _dash_speed := DODGE_SPEED
var _dash_len := DODGE_T
var _dash_anim := "Dodge_Forward"
var _dash_kind := ""
var _once_t := 0.0


func _ready() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_auto = args.has("auto")
	_weapon_glow = clampi(int(args.get("weapon_glow", 2)), 0, WEAPON_LIGHTS.size() - 1)
	_capture = args.has("shot")  # print: ignora a roda do mouse de quem estiver por perto
	_capture_walk = _capture and args.has("walk")
	if args.has("pitch"):
		_pitch = float(args.pitch)
	if args.has("zoom"):
		_px = 1.0 / float(args.zoom)
	_noise = NoiseTexture2D.new()
	var fnl := FastNoiseLite.new()
	fnl.frequency = 0.03
	fnl.seed = 7
	_noise.noise = fnl
	_noise.seamless = true
	_noise.width = 256
	_noise.height = 256
	# ruído de nuvens (global: lido pela luz de todos os shaders toon e pelo dissolve)
	var cloud := NoiseTexture2D.new()
	var cn := FastNoiseLite.new()
	cn.frequency = 0.012
	cn.seed = 3
	cloud.noise = cn
	cloud.seamless = true
	cloud.width = 256
	cloud.height = 256
	# (a cena é recarregada ao trocar de vocação: os globais já existem na 2ª vez)
	if not Engine.has_meta("aethra_globals"):
		RenderingServer.global_shader_parameter_add(&"cloud_noise", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, cloud)
		RenderingServer.global_shader_parameter_add(&"player_world", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	else:
		RenderingServer.global_shader_parameter_set(&"cloud_noise", cloud)
	_ghost_shader = load(SH + "ghost.gdshader")
	_class = _pick_class(args)
	_voc = Vocations.new()
	_voc.setup(self, _class)
	_speed = float(_voc.cfg.speed)
	_build_view()
	_build_world()
	_build_player()
	_build_flames()
	Engine.set_meta("aethra_globals", true)  # globais de shader já criados (sobrevive ao reload)
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override is ShaderMaterial:
			_char_mats.append((mi as MeshInstance3D).material_override)
	_set_pyro(_voc.is_mage() and (args.has("pyro") or _auto))  # Piromante é do Mago
	if args.has("hour"):
		_sky.hour = float(args.hour)
		_sky.update(0.0)
	if args.has("at"):
		var xz := String(args.at).split(",")
		_player.global_position = Vector3(float(xz[0]), 0, float(xz[1]))
		_cam_focus = _player.global_position
	if not args.has("scenery"):
		_adventure = Adventure.new()
		add_child(_adventure)
		_adventure.build(self, args)
	if not args.has("mute"):
		_audio = AmbienceAudio.new()
		_audio.build(self)
	get_viewport().size_changed.connect(_fit)
	_fit()
	if _adventure != null and _adventure.needs_vocation and not _capture:
		_adventure.hud.panel = "vocation"  # primeira vez: escolher a vocação
	if args.has("panel") and _adventure != null:  # print de painel (ex.: --panel=vocation)
		_adventure.hud.panel = String(args.panel)
	if args.has("light") and _adventure != null:  # print/teste: começa com a core skill Luz ativa
		_adventure.mana = 999.0
		_adventure.core.cast("light")
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("shot_delay", 4.0))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(String(args.shot)))
		if args.has("shot_hold"):  # multiplayer: continua conectado para o print do outro cliente
			await get_tree().create_timer(float(args.shot_hold)).timeout
		get_tree().quit()


# ------------------------------------------------------------------ vista em pixel

func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_child(_vp)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	world_labels = WorldLabels.new()
	add_child(world_labels)
	world_labels.setup(self)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.cull_mask &= ~WorldLabels.HIDDEN_LAYER  # rótulos 3D são redesenhados nítidos no overlay
	_cam.rotation_degrees = Vector3(_pitch, 0, 0)
	_cam.far = 120.0
	_vp.add_child(_cam)
	# contorno: quadrado em tela cheia preso à câmera
	var post := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	post.mesh = quad
	post.extra_cull_margin = 16384.0
	var pm := ShaderMaterial.new()
	pm.shader = load(SH + "outline_post.gdshader")
	pm.render_priority = -128
	post.material_override = pm
	_cam.add_child(post)
	_help = Label.new()
	_help.text = HELP
	_help.position = Vector2(12, 8)
	_help.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_help.add_theme_constant_override("outline_size", 4)
	add_child(_help)


func _fit() -> void:
	var win := get_viewport().get_visible_rect().size
	_scale = maxi(1, int(win.y / BASE_H))
	var size := Vector2i(ceili(win.x / _scale) + 2, ceili(win.y / _scale) + 2)
	_vp.size = size
	_view.size = Vector2(size) * _scale
	_cam.size = size.y * _px


## Câmera presa à grade de pixels (sem tremer) + resto compensado deslocando a imagem.
func _update_camera(delta: float) -> void:
	_cam_focus = _cam_focus.lerp(_player.global_position + Vector3(0, 0.6, 0), 1.0 - exp(-delta * 8.0))
	var b := _cam.global_transform.basis
	var right := b.x
	var up := b.y
	var fwd := -b.z
	var pos := _cam_focus - fwd * 40.0
	var a := pos.dot(right)
	var u := pos.dot(up)
	var c := pos.dot(fwd)
	var a2 := roundf(a / _px) * _px
	var u2 := roundf(u / _px) * _px
	_cam.global_position = right * a2 + up * u2 + fwd * c
	_view.position = Vector2(-1.0 - (a - a2) / _px, -1.0 + (u - u2) / _px) * _scale


# ------------------------------------------------------------------ mundo

func _toon(color: Color, emission := Color.BLACK, energy := 0.0, sway := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + "toon.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("sway", sway)
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func path_dist(p: Vector2) -> float:
	var a := absf(p.x - sin(p.y * 0.18) * 3.0)
	var b := absf(p.y - (sin(p.x * 0.15) * 2.0 + 4.0))
	return minf(minf(minf(a, b), Camps.path_distance(p)), WorldLayout.trail_dist(p))


func _build_world() -> void:
	var root := Node3D.new()
	_vp.add_child(root)
	_world_root = root
	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.92, 0.78)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.64)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.4  # só emissivos (magia, luzes) passam; folhagem clara não
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# pedaços de 20 m: só o que está perto da câmera fica visível (world/world_chunks.gd)
	_chunks = WorldChunks.new()
	_chunks.setup(root)
	# chão em ladrilhos (um por pedaço), grade de 0,5 m: a bacia da água afunda suave
	var ground := PlaneMesh.new()
	ground.size = Vector2(WorldChunks.SIZE, WorldChunks.SIZE)
	ground.subdivide_width = int(WorldChunks.SIZE * 2.0) - 1
	ground.subdivide_depth = int(WorldChunks.SIZE * 2.0) - 1
	var gm := ShaderMaterial.new()
	gm.shader = load(SH + "ground.gdshader")
	gm.set_shader_parameter("noise_tex", _noise)
	Camps.configure_terrain(gm)
	WorldLayout.configure_terrain(gm)
	var tiles := int(WorldChunks.EXTENT * 2.0 / WorldChunks.SIZE)
	for ix in tiles:
		for iz in tiles:
			var c := Vector3(-WorldChunks.EXTENT + (ix + 0.5) * WorldChunks.SIZE, 0, -WorldChunks.EXTENT + (iz + 0.5) * WorldChunks.SIZE)
			var tile := _mesh(ground, gm, c, _chunks.node_at3(c))
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(WorldChunks.EXTENT * 2.0, 1, WorldChunks.EXTENT * 2.0)
	fs.shape = fbox
	fs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fs)
	root.add_child(floor_body)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# árvores em bosques agrupados, com clareiras e trilhas livres (world/world_layout.gd)
	_biome.frequency = 0.022
	_biome.seed = 5
	_props = WorldProps.new()
	_props.demo = self
	_props.chunks = _chunks
	var plan: Dictionary = WorldLayout.plan_trees(HALF, MAX_TREES, rng, path_dist)
	for t: Array in plan.trees:
		var tp: Vector2 = t[0]
		_tree(_chunks.node_at(tp), Vector3(tp.x, 0, tp.y), rng, float(t[1]), String(t[2]))
	edge_bushes = plan.bushes
	_props.build(self, _chunks)
	for i in 220:
		var p := Vector2(rng.randf_range(-HALF + 2, HALF - 2), rng.randf_range(-HALF + 2, HALF - 2))
		if path_dist(p) < 1.8 or Camps.clearing_distance(p) < 0.0 or WorldLayout.clearing_dist(p) < 1.0 or p.length() < 2.5 or Dressing.water_dist(p) < 0.8 or Dressing.plaza_dist(p) < 1.0 or WorldLayout.open_dist(p) > -1.0:
			continue
		_rock(_chunks.node_at(p), Vector3(p.x, 0, p.y), rng)
	# pedras de margem: beiram o lago e o rio
	var placed := 0
	while placed < 26:
		var p := Vector2(rng.randf_range(-30, 30), rng.randf_range(-24, 20))
		var wd := Dressing.water_dist(p)
		if wd > 0.1 and wd < 0.9 and absf(p.x - Dressing.BRIDGE_X) > 2.5:
			_rock(_chunks.node_at(p), Vector3(p.x, 0, p.y), rng)
			placed += 1

	# grama (um MultiMesh por pedaço: a GPU descarta o que está fora da tela)
	_grass_mat = ShaderMaterial.new()
	_grass_mat.shader = load(SH + "grass.gdshader")
	_grass_mat.set_shader_parameter("noise_tex", _noise)
	Camps.configure_terrain(_grass_mat)
	WorldLayout.configure_terrain(_grass_mat)
	var tuft := _tuft_mesh()
	var groups := {}
	for i in int(52000.0 * HALF * HALF / 3600.0):
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		if path_dist(p) < 1.5 + rng.randf() * 0.4 or Dressing.water_dist(p) < 0.35 or Dressing.plaza_dist(p) < 0.2 or WorldLayout.open_dist(p) > 0.6:
			continue
		var k: Vector2i = _chunks.key(p)
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.25)), Vector3(p.x, 0, p.y)))
	for k: Vector2i in groups:
		var xforms: Array = groups[k]
		var first: Transform3D = xforms[0]
		var mmi: MultiMeshInstance3D = _props._multimesh(_chunks.node_at(Vector2(first.origin.x, first.origin.z)), tuft, _grass_mat, xforms)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flowers(root, rng)
	_dress = Dressing.new()
	_dress.build(root, self, _noise)
	_camps = Camps.new()
	_camps.build(root, self)
	_life = Life.new()
	_life.build(root, self)
	_sky = SkyCycle.new()
	_sky.build(root, _sun, _env, rng, HALF, _tree_spots)
	for c: Color in CANOPY.violet:
		_sky.night_glow.append([_toon_shared(c, 0.04), Color(0.55, 0.35, 1.0), 1.5])
	_fauna = Fauna.new()
	_fauna.build(root, self, _tree_spots, HALF)
	_wildlife = Wildlife.new()
	_wildlife.build(root, self, HALF)


## Só os pedaços do mundo na tela (+ margem) ficam visíveis; a margem sul é maior porque
## árvores e rochas altas logo abaixo da tela ainda aparecem por cima (câmera a -50°).
func _update_chunks() -> void:
	if not chunk_culling:
		_chunks.update(_cam_focus, 1000.0, 1000.0, 1000.0)
		return
	var s := _cam.size
	var aspect := float(_vp.size.x) / maxf(1.0, float(_vp.size.y))
	var depth := s * 0.5 / sin(deg_to_rad(-_pitch))
	_chunks.update(_cam_focus, s * aspect * 0.5 + 5.0, depth + 9.0, depth + 5.0)


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var b := Basis(Vector3.UP, i * TAU / 3.0 + 0.4)
		var h := 0.26 + i * 0.06
		var off := b * Vector3(0.03, 0, 0)
		for v: Vector3 in [Vector3(-0.045, 0, 0), Vector3(0.045, 0, 0), Vector3(0.01, h, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(b * v + off)
	return st.commit()


## Material toon compartilhado por cor (árvores, pedras): poucas cópias = menos trocas de estado.
func _toon_shared(color: Color, sway := 0.0) -> ShaderMaterial:
	var key := "%s|%s" % [color.to_html(), sway]
	if not _toon_cache.has(key):
		var m := _toon(color, Color.BLACK, 0.0, sway)
		m.set_shader_parameter("see_through", sway > 0.0)  # copas vazam perto do jogador
		_toon_cache[key] = m
	return _toon_cache[key]


## Bioma pela posição: manchas de outono, florada e violeta no meio do verde.
func _biome_at(p: Vector2, rng: RandomNumberGenerator) -> String:
	var v := _biome.get_noise_2d(p.x, p.y)
	if rng.randf() < 0.015:
		return "golden" if rng.randf() < 0.5 else "blossom"
	if v < -0.32:
		return "autumn"
	if v > 0.42:
		return "violet"
	if v > 0.22:
		return "blossom"
	return "green"


func _tree(root: Node3D, pos: Vector3, rng: RandomNumberGenerator, size_k := 1.0, region := "floresta") -> void:
	var body := StaticBody3D.new()
	body.position = pos
	root.add_child(body)
	var size := rng.randf_range(0.8, 1.2) * size_k
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.32 * size
	cyl.height = 2.0
	col.shape = cyl
	col.position.y = 1.0
	body.add_child(col)
	var biome := _biome_at(Vector2(pos.x, pos.z), rng)
	var species := ""
	match region:
		"ruinas":
			if rng.randf() < 0.55:
				biome = "autumn"
		"bosque":
			var pick := rng.randf()
			biome = "violet" if pick < 0.22 else ("golden" if pick < 0.32 else "green")
			species = "pine" if rng.randf() < 0.1 else "broad"
		"serra":
			biome = "green"
			species = "pine" if rng.randf() < 0.8 else ""
		"charco":
			if rng.randf() < 0.65:
				biome = "dead"
	body.set_meta("kind", "tree")
	body.set_meta("size", size)
	if biome == "dead":
		body.set_meta("leaf", Color(0.45, 0.42, 0.3))
		_tree_spots.append([pos, size, biome])
		_props.dead_tree(body, size, rng)
		return
	var palette: Array = CANOPY[biome]
	body.set_meta("leaf", palette[0])
	_tree_spots.append([pos, size, biome])
	_forest.populate(self, body, palette, size, rng, biome, species)


## Tapete de flores em manchas (cor por mancha), fora de trilha/água/praça.
func _flowers(root: Node3D, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# cabeça: quadrado deitado no topo (lido de cima); haste: tira vertical fina
	var top := 0.2
	var hs := 0.07
	for v: Array in [[Vector3(-hs, top, -hs), Vector2(0, 0)], [Vector3(hs, top, -hs), Vector2(1, 0)], [Vector3(hs, top, hs), Vector2(1, 1)],
			[Vector3(-hs, top, -hs), Vector2(0, 0)], [Vector3(hs, top, hs), Vector2(1, 1)], [Vector3(-hs, top, hs), Vector2(0, 1)],
			[Vector3(-0.01, 0, 0), Vector2(0, 0)], [Vector3(0.01, 0, 0), Vector2(0, 0)], [Vector3(0.01, top, 0), Vector2(0, 0)],
			[Vector3(-0.01, 0, 0), Vector2(0, 0)], [Vector3(0.01, top, 0), Vector2(0, 0)], [Vector3(-0.01, top, 0), Vector2(0, 0)]]:
		st.set_normal(Vector3.UP)
		st.set_uv(v[1])
		st.add_vertex(v[0])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = st.commit()
	var patch := FastNoiseLite.new()
	patch.frequency = 0.09
	patch.seed = 9
	var items: Array = []
	for i in int(30000.0 * HALF * HALF / 3600.0):
		var p := Vector2(rng.randf_range(-HALF, HALF), rng.randf_range(-HALF, HALF))
		if patch.get_noise_2d(p.x, p.y) < 0.28:
			continue
		if p.y < -58.0 or p.y > 62.0 or path_dist(p) < 1.8 or Dressing.water_dist(p) < 0.5 or Dressing.plaza_dist(p) < 0.5:
			continue
		var c: Color = FLOWER_COLORS[int(absf(patch.get_noise_2d(p.x * 0.3 + 100.0, p.y * 0.3)) * 40.0) % FLOWER_COLORS.size()]
		items.append([Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, 0, p.y)), c])
	var fm := ShaderMaterial.new()
	fm.shader = load(SH + "flower.gdshader")
	var groups := {}
	for it: Array in items:
		var xf: Transform3D = it[0]
		var k: Vector2i = _chunks.key(Vector2(xf.origin.x, xf.origin.z))
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(it)
	for k: Vector2i in groups:
		var arr: Array = groups[k]
		var chunk_mm := MultiMesh.new()
		chunk_mm.transform_format = MultiMesh.TRANSFORM_3D
		chunk_mm.use_colors = true
		chunk_mm.mesh = mm.mesh
		chunk_mm.instance_count = arr.size()
		for i in arr.size():
			chunk_mm.set_instance_transform(i, arr[i][0])
			chunk_mm.set_instance_color(i, arr[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = chunk_mm
		mmi.material_override = fm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var first: Transform3D = arr[0][0]
		_chunks.node_at(Vector2(first.origin.x, first.origin.z)).add_child(mmi)


func _rock(root: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	root.add_child(body)
	var r := rng.randf_range(0.3, 0.7)
	body.set_meta("kind", "rock")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	col.shape = sph
	body.add_child(col)
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.4
	s.radial_segments = 6
	s.rings = 3
	_mesh(s, _toon_shared(Color(0.45, 0.45, 0.5)), Vector3(0, r * 0.35, 0), body, Vector3(0, rng.randf() * 360, 0), Vector3(1.0, 0.8, 1.2))


# ------------------------------------------------------------------ mago (KayKit, CC0)

const MAGE_GLB := "res://assets/third_party/kaykit_adventurers/addons/kaykit_character_pack_adventures/Characters/gltf/Mage.glb"
const MODEL_HEIGHT := 1.8
const PYRO_TINT := Color(0.6, 0.2, 0.24)
## Peças que recebem as runas de brasa no modo Piromante.
const RUNE_PARTS := ["Mage_Body", "Mage_Cape", "Mage_Hat"]
const CLOTH_PARTS := ["Mage_Body", "Mage_Cape", "Mage_Hat", "Mage_ArmLeft", "Mage_ArmRight", "Mage_LegLeft", "Mage_LegRight"]
const LOOPED := ["Idle", "Running_A", "Walking_A", "2H_Melee_Idle"]


func _build_player() -> void:
	_player = CharacterBody3D.new()
	# Modo de chão: detecta piso, desce de pedras e não sobe paredes íngremes.
	_player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_player.floor_max_angle = deg_to_rad(46.0)
	_player.floor_snap_length = 0.35
	_player.floor_stop_on_slope = true
	_player.collision_mask = 1 | Dressing.WATER_LAYER
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.4
	col.shape = cap
	col.position.y = 0.7
	_player.add_child(col)
	_vp.add_child(_player)
	_build_contact_shadow()
	_model = Node3D.new()
	_player.add_child(_model)
	if not _voc.is_mage():
		_voc.build_model(_model)
		_play("Idle", 1.0)
		_model.rotation.y = PI
		return
	var mage := (load(MAGE_GLB) as PackedScene).instantiate() as Node3D
	_model.add_child(mage)
	mage.rotation.y = PI  # o glTF olha para +Z; o resto do código assume -Z
	# chapéu menor: de cima o chapéu cabeçudo do pacote cobria o corpo inteiro
	var hat := mage.find_child("Mage_Hat", true, false) as Node3D
	if hat != null:
		hat.scale = Vector3.ONE * 0.62
	for extra: String in ["1H_Wand", "Spellbook", "Spellbook_open"]:
		var n := mage.find_child(extra, true, false) as Node3D
		if n != null:
			n.visible = false
	# escala pela altura real (corpo + cabeça + chapéu)
	var top := 0.0
	for mi in mage.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.visible and m.is_visible_in_tree():
			top = maxf(top, (m.global_transform * m.get_aabb()).end.y)
	if top > 0.0:
		mage.scale = Vector3.ONE * (MODEL_HEIGHT / top)
	# materiais toon com a paleta do pacote
	for mi in mage.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.get_active_material(0) as BaseMaterial3D
		var mat := _toon(Color.WHITE)
		if src != null and src.albedo_texture != null:
			mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			mat.set_shader_parameter("use_tex", true)
		m.material_override = mat
		if String(m.name) in CLOTH_PARTS:
			_clothes.append([mat, Color.WHITE, PYRO_TINT, String(m.name) in RUNE_PARTS])
	_anim = mage.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a: String in LOOPED:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("Idle", 1.0)
	_model.rotation.y = PI  # começa olhando para a câmera
	# ponta do cajado: cristal aceso + luz (origem da chama e da bola de fogo)
	var staff := mage.find_child("2H_Staff", true, false) as MeshInstance3D
	_staff_mesh = staff
	var tip := Node3D.new()
	staff.add_child(tip)
	tip.position = Vector3(0, staff.mesh.get_aabb().end.y * 0.94, 0)
	var crystal := SphereMesh.new()
	crystal.radius = 0.09
	crystal.height = 0.22
	crystal.radial_segments = 4
	crystal.rings = 2
	_crystal = _toon(Color(1.0, 0.5, 0.15), Color(1.0, 0.45, 0.1), 3.0)
	_mesh(crystal, _crystal, Vector3.ZERO, tip)
	_crystal_light = OmniLight3D.new()
	_crystal_light.light_color = Color(1.0, 0.55, 0.2)
	_crystal_light.omni_range = 4.4
	_crystal_light.omni_attenuation = 1.5
	_crystal_light.light_specular = 0.0
	_crystal_light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	_crystal_light.light_energy = 1.1
	tip.add_child(_crystal_light)
	_p.staff = tip


## Arma vestida no modelo: cristal, luz e tom do cajado do mago; espada ou arco das outras
## vocações (vocations.gd). Chamado ao abrir, ao equipar e quando o servidor manda o estado.
func apply_gear_look() -> void:
	if _adventure == null or _adventure.inventory == null:
		return
	var it: Dictionary = _adventure.inventory.item(String(_adventure.inventory.equipped.get("weapon", "")))
	if not _voc.is_mage():
		_voc.apply_weapon(it)
		return
	if _crystal == null:
		return
	var g: Array = it.get("glow", [1.0, 0.5, 0.15])
	var glow := Color(float(g[0]), float(g[1]), float(g[2]))
	_crystal.set_shader_parameter("albedo", glow)
	_crystal.set_shader_parameter("emission", glow)
	_crystal_light.light_color = glow.lerp(Color.WHITE, 0.1)
	_crystal_mult = clampf(float(it.get("glow_energy", 1.0)), 0.4, 2.0)
	if _staff_mesh != null and _staff_mesh.material_override is ShaderMaterial:
		var t: Array = it.get("tint", [1, 1, 1])
		(_staff_mesh.material_override as ShaderMaterial).set_shader_parameter("tint", Color(float(t[0]), float(t[1]), float(t[2])))


func _build_contact_shadow() -> void:
	# Tight grounding shadow complements the long sun/moon shadows. Project
	# onto surfaces instead of drawing a floating transparent quad over grass.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.07, 0.06, 0.11, 0.66))
	gradient.add_point(0.38, Color(0.07, 0.06, 0.11, 0.50))
	gradient.add_point(0.72, Color(0.07, 0.06, 0.11, 0.20))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.07, 0.06, 0.11, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var shadow := Decal.new()
	shadow.name = "ContactShadow"
	shadow.texture_albedo = texture
	shadow.size = Vector3(0.86, 0.22, 0.64)
	shadow.position = Vector3(0, 0.025, 0)
	shadow.normal_fade = 0.8
	_player.add_child(shadow)


func _play(anim_name: String, speed: float, restart := false) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if anim_name != _anim_cur or restart:
		_anim.play(anim_name, 0.12)
		if restart:
			_anim.seek(0.0, true)
		_anim_cur = anim_name
	_anim.speed_scale = speed


# ------------------------------------------------------------------ Piromante

func _build_flames() -> void:
	_rune_mat = ShaderMaterial.new()
	_rune_mat.shader = load(SH + "rune_flow.gdshader")
	_rune_mat.set_shader_parameter("noise_tex", _noise)
	# escala do modelo KayKit (unidades do esqueleto, ~2,7 de altura)
	_rune_mat.set_shader_parameter("channels", 5.0)
	_rune_mat.set_shader_parameter("ring_spacing", 1.1)
	_rune_mat.set_shader_parameter("flow_density", 1.2)
	_rune_mat.set_shader_parameter("channel_width", 0.18)
	_flame_draw = ShaderMaterial.new()
	_flame_draw.shader = load(SH + "flame_particle.gdshader")
	_flame_draw.set_shader_parameter("noise_tex", _noise)
	_flame_draw.set_shader_parameter("intensity", 2.2)

	# chama viva só na ponta do cajado (presa ao cristal)
	var flames := _particles(14, 0.6, _flame_quad(0.22, 0.34), _flame_draw)
	var pm: ParticleProcessMaterial = flames.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.7
	pm.scale_max = 1.1
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.25, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([Color(1.0, 0.42, 0.08, 1.0), Color(0.95, 0.18, 0.04, 0.85), Color(0.5, 0.04, 0.02, 0.0)])
	flames.get_parent().remove_child(flames)
	(_p.staff as Node3D).add_child(flames)
	flames.position = Vector3(0, 0.08, 0)
	flames.local_coords = true
	_pyro_nodes.append(flames)

	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	em.vertex_color_use_as_albedo = true
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat = em
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.05, 0.05)
	var embers := _particles(10, 1.6, ember_quad, em)
	var epm: ParticleProcessMaterial = embers.process_material
	epm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	epm.emission_sphere_radius = 0.4
	epm.direction = Vector3.UP
	epm.spread = 40.0
	epm.initial_velocity_min = 0.5
	epm.initial_velocity_max = 1.4
	epm.gravity = Vector3(0, 0.6, 0)
	epm.turbulence_enabled = true
	epm.turbulence_noise_strength = 2.0
	epm.color_ramp = _ramp([Color(3.0, 1.6, 0.5, 1.0), Color(2.0, 0.6, 0.15, 1.0), Color(0.8, 0.1, 0.05, 0.0)])
	embers.position = Vector3(0, 0.7, 0)
	_pyro_nodes.append(embers)

	_aura_light = OmniLight3D.new()
	_aura_light.light_color = Color(1.0, 0.32, 0.1)
	_aura_light.omni_range = 2.8
	_aura_light.position = Vector3(0, 0.9, 0)
	_player.add_child(_aura_light)
	_pyro_nodes.append(_aura_light)


func _particles(amount: int, life: float, quad: Mesh, mat: Material) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = amount
	g.lifetime = life
	g.local_coords = false
	g.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	g.process_material = ParticleProcessMaterial.new()
	(quad as PrimitiveMesh).material = mat
	g.draw_pass_1 = quad
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player.add_child(g)
	return g


func _flame_quad(w: float, h: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	return q


func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, colors[0])
	g.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		g.add_point(float(i) / (colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true  # cores acima de 1 acendem o bloom
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _set_pyro(on: bool) -> void:
	_pyro = on
	for c: Array in _clothes:
		var m: ShaderMaterial = c[0]
		m.next_pass = _rune_mat if on and bool(c[3]) else null
		m.set_shader_parameter("tint", c[2] if on else c[1])
	for n in _pyro_nodes:
		if n is GPUParticles3D:
			(n as GPUParticles3D).emitting = on
		else:
			(n as Node3D).visible = on


# ------------------------------------------------------------------ jogo

func _unhandled_input(event: InputEvent) -> void:
	if _capture:
		return
	if _adventure != null and _adventure.hud.friends_key(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_O:
				if _net_mode():
					_adventure.hud.toggle("friends")
			KEY_E:
				if _adventure != null:
					_adventure.interact()
			KEY_I:
				if _adventure != null:
					_adventure.hud.toggle("bag")
			KEY_H, KEY_F1:
				if _adventure != null:
					_adventure.hud.toggle("help")
			KEY_J:
				if _adventure != null:
					_adventure.hud.toggle("quest")
			KEY_C:
				if _adventure != null:
					_adventure.hud.toggle("char")
			KEY_ESCAPE:
				if _adventure != null:
					_adventure.hud.panel = ""
			KEY_ENTER, KEY_KP_ENTER:
				if _adventure != null:
					_adventure.chat.open_input()
			KEY_1:
				if _adventure != null and not _adventure.hud.vocation_key(0):
					_adventure.drink("hp")
			KEY_2:
				if _adventure != null and not _adventure.hud.vocation_key(1):
					_adventure.drink("mana")
			KEY_3:
				if _adventure != null and not _adventure.hud.vocation_key(2):
					_adventure.cast_light()
			KEY_R:
				if _adventure != null:
					_adventure.cast_ring()
			KEY_F:
				if _voc.is_mage():
					_set_pyro(not _pyro)
			KEY_F2:
				if _adventure != null:
					_adventure.hud.toggle("vocation")
			KEY_SPACE:
				_start_dodge()
			KEY_Q:
				_skill_q()
			KEY_N:
				_sky.skip(3.0)
			KEY_L:
				_weapon_glow = (_weapon_glow + 1) % WEAPON_LIGHTS.size()
			KEY_F10:
				get_tree().quit()
	if _adventure != null and _adventure.hud.bag_mouse(event):
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if _adventure == null or not _adventure.hud.vocation_click(event.position):
					_start_attack()
			MOUSE_BUTTON_RIGHT:
				_skill_q()
			MOUSE_BUTTON_WHEEL_UP when not _capture:
				_px = clampf(_px / 1.15, PX_MIN, PX_MAX)
				_fit()
			MOUSE_BUTTON_WHEEL_DOWN when not _capture:
				_px = clampf(_px * 1.15, PX_MIN, PX_MAX)
				_fit()


func _mouse_ground() -> Vector3:
	var m := (get_viewport().get_mouse_position() - _view.position) / float(_scale)
	var o := _cam.project_ray_origin(m)
	var d := _cam.project_ray_normal(m)
	if _adventure != null:
		var query := PhysicsRayQueryParameters3D.create(o, o + d * 120.0, 1 | 8)
		query.exclude = [_player.get_rid()]
		var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and String(hit.collider.get_meta("kind", "")) in ["enemy", "quest_torch"]:
			_hover_node = hit.collider as Node3D
			return (hit.collider as Node3D).global_position
	if absf(d.y) < 0.0001:
		return _player.global_position
	var ground: float = _adventure.ground_height() if _adventure != null else 0.0
	return o + d * ((ground - o.y) / d.y)


func _start_attack() -> void:
	_hover_node = null
	var tgt := _mouse_ground() if not _auto else _player.global_position + Vector3(1, 0, -0.4)
	_attack_at(tgt, _hover_node)


func _attack_at(tgt: Vector3, node: Node3D = null) -> void:
	if _adventure != null and _adventure.hud.any_open():
		return
	if _attack_t >= 0.0 or _dodge_t >= 0.0 or _blink_t >= 0.0:
		return
	if _net_mode():
		_adventure.online.attack(tgt, node)   # online: o servidor valida mana/recarga/alcance
	elif _adventure != null and not _adventure.spend("fire"):
		return
	_attack_target = tgt
	_attack_node = node
	var d := tgt - _player.global_position
	d.y = 0
	if d.length() > 0.01:
		_aim = d.normalized()
	_attack_t = 0.0
	_fired = false
	_anim_cur = ""


func _start_dodge() -> void:
	if _dodge_t >= 0.0:
		return
	var v := Vector3(_player.velocity.x, 0, _player.velocity.z)
	_dodge_dir = v.normalized() if v.length() > 0.5 else -_model.global_transform.basis.z
	_dodge_t = 0.0
	_attack_t = -1.0
	_anim_cur = ""


func _physics_process(delta: float) -> void:
	_t += delta
	var input := Vector2.ZERO
	if _auto:
		input = Vector2(cos(_t * 0.7), sin(_t * 0.7)).orthogonal()
		if fmod(_t, 1.6) < delta:
			_start_attack()
	elif not _capture and not (_adventure != null and _adventure.chat.typing):  # print ou chat: teclado não mexe no boneco
		input = Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	input = input.limit_length(1.0)
	if not _capture and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_start_attack()
	if _capture_walk:
		input = Vector2.RIGHT
	if _auto and fmod(_t + 0.8, 2.6) < delta:
		_skill_q()
	if _net_mode():
		# online: o servidor move (predição/reconciliação em net/net_play.gd)
		_adventure.online.physics(delta, input)
	else:
		_blink_cd = maxf(0.0, _blink_cd - delta)
		var target := Vector3(input.x, 0, input.y) * _speed
		if _blink_t >= 0.0:
			_update_blink(delta)
		elif _dodge_t >= 0.0:
			_dodge_t += delta
			var k := _dodge_t / _dash_len
			var vy := _player.velocity.y
			_player.velocity = _dodge_dir * _dash_speed * (1.0 - k * (0.55 if _dash_kind.is_empty() else 0.2))
			_player.velocity.y = vy
			_ghost_t += delta
			if _ghost_t >= 0.045:
				_ghost_t = 0.0
				_ghost(_player.global_position, 0.55, 0.26)
			if _voc.dash_tick(_dash_kind) or _dodge_t >= _dash_len:
				_end_dash()
		else:
			var slow: float = (0.35 if _attack_t >= 0.0 else 1.0) * (_adventure.enemies.player_speed_factor() if _adventure != null else 1.0)
			var rate := _speed / (ACCEL_T if input != Vector2.ZERO else FRICTION_T)
			var horizontal := Vector3(_player.velocity.x, 0, _player.velocity.z).move_toward(target * slow, rate * delta)
			_player.velocity.x = horizontal.x
			_player.velocity.z = horizontal.z
		# Gravidade sempre (superfície e gruta): quem sobe numa pedra volta ao chão.
		if _blink_t >= 0.0:
			_player.velocity.y = 0.0
		elif _player.is_on_floor():
			_player.velocity.y = -0.5  # mantém contato sem acumular queda
		else:
			_player.velocity.y = maxf(_player.velocity.y - GRAVITY * delta, -MAX_FALL)
		_player.move_and_slide()
	# rede de segurança: nunca abaixo do piso do andar atual
	var floor_y: float = _adventure.ground_height() if _adventure != null else 0.0
	if _player.global_position.y < floor_y - 0.5:
		_player.global_position.y = floor_y
		_player.velocity.y = 0.0
	_animate(delta, input)
	_update_projectiles(delta)
	_update_camera(delta)
	_grass_mat.set_shader_parameter("player_pos", _player.global_position)
	RenderingServer.global_shader_parameter_set(&"player_world", _player.global_position)
	var pulse := 1.0 + 0.045 * sin(_t * 4.0) + 0.02 * sin(_t * 11.0)
	_rune_mat.set_shader_parameter("pulse", pulse * (1.0 - _dissolve))
	_sky.update(delta, _player.global_position)
	if _audio != null:
		_audio.update(delta, _sky.night, _adventure != null and _adventure.in_cave, _player.global_position)
	_dress.flicker(_t, _sky.night, _player.global_position)
	_life.update(delta, _t, _player.global_position)
	_fauna.update(delta, _t, _player.global_position, HALF, _sky.day)
	_wildlife.update(delta, _t, _player.global_position, _sky.day)
	_camps.update(_t, _sky.night, _player.global_position)
	_update_chunks()
	_help.text = HELP + "\n" + _sky.label() + " (N +3h) · L: luz da arma — " + String(WEAPON_LIGHTS[_weapon_glow].label)
	_help.visible = _adventure == null  # com a aventura, as teclas ficam na tela de atalhos (H)
	_dress.ambient.global_position = Vector3(_cam_focus.x, 0, _cam_focus.z)
	# Runes glow, but the staff is the source of the surrounding warm light.
	_aura_light.light_energy = 0.0
	var profile: Dictionary = WEAPON_LIGHTS[_weapon_glow]
	var strength := pulse * (1.2 if _pyro else 1.0) * (1.0 - _dissolve)
	if _crystal != null:
		_crystal.set_shader_parameter("emission_energy", float(profile.emission) * strength * _crystal_mult)
		_crystal_light.light_energy = float(profile.energy) * strength * _crystal_mult
		_crystal_light.omni_range = float(profile.range)
	for mat in _char_mats:
		mat.set_shader_parameter("readability", minf(1.0, _sky.night * 0.45 + (_adventure.core.readability_boost() * _sky.night if _adventure != null else 0.0)))
	if _adventure != null:
		_adventure.update(delta, _t)


func _animate(delta: float, _input: Vector2) -> void:
	var hv := Vector3(_player.velocity.x, 0, _player.velocity.z)
	var speed := hv.length()
	var moving := speed > 0.3
	# para onde olhar: mira durante o ataque, senão a direção do movimento
	var face := _aim if _attack_t >= 0.0 else (hv.normalized() if moving else -_model.global_transform.basis.z)
	if _dodge_t >= 0.0:
		face = _dodge_dir
	var yaw := atan2(-face.x, -face.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-delta * 16.0))
	if _attack_t >= 0.0:
		_attack_t += delta
		var a := _attack_t / float(_voc.cfg.attack_t)
		if a >= float(_voc.cfg.attack_hit) and not _fired:
			_fired = true
			if _net_mode():
				_adventure.online.primary_fx()   # online: dano e projétil vêm do servidor
			else:
				_voc.primary()
		if a >= 1.0:
			_attack_t = -1.0
	# animação do pacote por estado
	if _blink_t >= 0.0:
		_play("Spellcast_Raise", 1.6)
	elif _dodge_t >= 0.0:
		_play(_dash_anim, _anim_len(_dash_anim) / (_dash_len * 1.6))
	elif _attack_t >= 0.0:
		var atk := String(_voc.cfg.attack_anim)
		_play(atk, _anim_len(atk) / (float(_voc.cfg.attack_t) * 1.4))
	elif _once_t > 0.0:
		_once_t -= delta
	elif moving:
		_play("Running_A", clampf(speed / _speed, 0.5, 1.3))
	else:
		_play("Idle", 1.0)


## Jogo ligado ao servidor (--connect)? Offline devolve sempre false.
func _net_mode() -> bool:
	return _adventure != null and _adventure.online != null


func _anim_len(anim_name: String) -> float:
	return _anim.get_animation(anim_name).length if _anim != null and _anim.has_animation(anim_name) else 1.0


func _fireball() -> void:
	var n := Node3D.new()
	_vp.add_child(n)
	var tip := (_p.staff as Node3D).global_position
	var chest := _player.global_position + Vector3(0, SHOT_HEIGHT, 0)
	var spawn := Vector3(tip.x, chest.y, tip.z) + _aim * 0.3
	# mira no centro do volume do alvo, na posição ATUAL (ele andou durante o gesto)
	var aim_point := _attack_target
	if is_instance_valid(_attack_node) and _attack_node.is_inside_tree():
		aim_point = _target_center(_attack_node)
	else:
		aim_point.y = chest.y  # chão: voa na altura do peito, sem mergulhar no piso
	n.global_position = spawn
	var core := SphereMesh.new()
	core.radius = 0.13
	core.height = 0.26
	core.radial_segments = 6
	core.rings = 3
	_mesh(core, _toon(Color(1, 0.7, 0.3), Color(1.0, 0.55, 0.15), 6.0), Vector3.ZERO, n)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.5, 0.15)
	l.omni_range = 3.0
	l.light_energy = 2.0
	n.add_child(l)
	var trail := GPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-20, -4, -20), Vector3(40, 8, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08
	pm.gravity = Vector3(0, 1.0, 0)
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([Color(1.0, 0.65, 0.2, 1.0), Color(1.0, 0.25, 0.05, 0.8), Color(0.5, 0.05, 0.02, 0.0)])
	trail.process_material = pm
	var q := _flame_quad(0.3, 0.4)
	q.material = _flame_draw
	trail.draw_pass_1 = q
	n.add_child(trail)
	var shot := aim_point - chest
	if Vector2(shot.x, shot.z).length() < 0.05:
		shot = _aim
	shot = shot.normalized()
	# o trecho peito → ponta do cajado também é testado: alvo colado no mago é atingido
	_projectiles.append({"node": n, "vel": shot * SHOT_SPEED, "life": 0.8, "from": chest})


## Centro do volume de colisão de um corpo (cápsula do monstro, tocha...).
func _target_center(body: Node3D) -> Vector3:
	for c in body.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return body.global_position + Vector3(0, 0.6, 0)


func _update_projectiles(delta: float) -> void:
	var space := _player.get_world_3d().direct_space_state
	for i in range(_projectiles.size() - 1, -1, -1):
		var pr: Dictionary = _projectiles[i]
		var n: Node3D = pr.node
		pr.life = float(pr.life) - delta
		var vel: Vector3 = pr.vel
		if float(pr.life) <= 0.0:
			# fim do alcance: perde força e cai no chão
			vel.y -= 24.0 * delta
			vel.x *= 1.0 - 2.2 * delta
			vel.z *= 1.0 - 2.2 * delta
			pr.vel = vel
		var from := n.global_position
		if pr.has("from"):
			from = pr.from  # 1º passo: do peito do mago até onde a bola nasceu
			pr.erase("from")
		var to := n.global_position + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var skip: Array[RID] = [_player.get_rid()]
		if pr.has("hit"):
			for r: RID in pr.hit:
				skip.append(r)
		q.exclude = skip
		q.collision_mask = 1 | 8  # cenário e inimigos; margens d'água ficam de fora
		var hit := space.intersect_ray(q)
		# flecha perfurante: atravessa inimigos (cada um só uma vez) e segue até o cenário
		if not hit.is_empty() and bool(pr.get("pierce", false)) and String(hit.collider.get_meta("kind", "")) == "enemy":
			if _adventure != null:
				_adventure.hit(hit.collider, int(pr.dmg))
			_burst(hit.position)
			(pr.hit as Array).append((hit.collider as CollisionObject3D).get_rid())
			n.global_position = hit.position + vel.normalized() * 0.05
			continue
		var impact_pos := Vector3.INF
		var collider: Object = null
		if not hit.is_empty():
			impact_pos = hit.position
			collider = hit.collider
		elif to.y <= (_adventure.ground_height() if _adventure != null else 0.0) + 0.04:
			impact_pos = Vector3(to.x, _adventure.ground_height() if _adventure != null else 0.0, to.z)
		if impact_pos != Vector3.INF:
			_impact(impact_pos, collider, pr)
			n.queue_free()
			_projectiles.remove_at(i)
			continue
		n.global_position = to


## Impacto da bola de fogo: faíscas sempre; árvore balança e solta folhas; chão fica
## chamuscado (marca que esfria e some); na água vira respingo.
func _impact(pos: Vector3, collider: Object, pr: Dictionary = {}) -> void:
	if _adventure != null and _adventure.hit(collider, int(pr.get("dmg", -1))):
		_burst(pos)
		return
	if String(pr.get("kind", "")) == "arrow":
		_ghost_spark(pos)  # flecha: só um estalo, sem chamuscado
		return
	var kind := String(collider.get_meta("kind", "")) if collider != null else ""
	var on_water := Dressing.water_dist(Vector2(pos.x, pos.z)) < 0.0 and pos.y < 0.3
	if on_water:
		_life.splash(Vector3(pos.x, Dressing.WATER_Y, pos.z))
		return
	_burst(pos + Vector3(0, 0.15, 0))
	match kind:
		"tree":
			var tree := collider as Node3D
			var size := float(tree.get_meta("size", 1.0))
			var tw := tree.create_tween()
			tw.tween_property(tree, "rotation:z", 0.07, 0.05)
			tw.tween_property(tree, "rotation:z", -0.045, 0.12)
			tw.tween_property(tree, "rotation:z", 0.02, 0.12)
			tw.tween_property(tree, "rotation:z", 0.0, 0.15)
			_leaf_burst(tree.global_position + Vector3(0, 3.2 * size, 0), tree.get_meta("leaf", Color(0.3, 0.5, 0.2)))
		"rock":
			pass
		_:
			_scorch(Vector3(pos.x, _adventure.ground_height() if _adventure != null else 0.0, pos.z))


func _leaf_burst(pos: Vector3, color: Color) -> void:
	var g := GPUParticles3D.new()
	g.amount = 18
	g.lifetime = 2.2
	g.one_shot = true
	g.explosiveness = 0.85
	g.local_coords = false
	g.visibility_aabb = AABB(Vector3(-4, -5, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3.UP
	pm.spread = 90.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0.3, -1.4, 0.2)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.color = color
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	g.draw_pass_1 = q
	_vp.add_child(g)
	g.global_position = pos
	g.emitting = true
	get_tree().create_timer(2.6).timeout.connect(g.queue_free)


## Marca de queimado no chão (Decal acompanha o relevo): brasa no meio esfria em ~1,5 s,
## a mancha some em ~6 s.
func _scorch(pos: Vector3) -> void:
	if _scorch_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.06, 0.03, 0.02, 0.9))
		g.add_point(0.55, Color(0.12, 0.06, 0.03, 0.55))
		g.set_color(g.get_point_count() - 1, Color(0.1, 0.05, 0.03, 0.0))
		_scorch_tex = GradientTexture2D.new()
		_scorch_tex.gradient = g
		_scorch_tex.fill = GradientTexture2D.FILL_RADIAL
		_scorch_tex.fill_from = Vector2(0.5, 0.5)
		_scorch_tex.fill_to = Vector2(1.0, 0.5)
		_scorch_tex.width = 32
		_scorch_tex.height = 32
		var ge := Gradient.new()
		ge.set_color(0, Color(1.0, 0.45, 0.1, 1.0))
		ge.add_point(0.3, Color(0.6, 0.12, 0.02, 1.0))
		ge.set_color(ge.get_point_count() - 1, Color(0, 0, 0, 1.0))
		_ember_tex = GradientTexture2D.new()
		_ember_tex.gradient = ge
		_ember_tex.fill = GradientTexture2D.FILL_RADIAL
		_ember_tex.fill_from = Vector2(0.5, 0.5)
		_ember_tex.fill_to = Vector2(0.85, 0.5)
		_ember_tex.width = 32
		_ember_tex.height = 32
	var d := Decal.new()
	d.size = Vector3(1.3, 1.0, 1.3)
	d.texture_albedo = _scorch_tex
	d.texture_emission = _ember_tex
	d.emission_energy = 3.0
	_vp.add_child(d)
	d.global_position = pos
	var tw := d.create_tween()
	tw.tween_property(d, "emission_energy", 0.0, 1.5)
	tw.tween_property(d, "modulate:a", 0.0, 4.5)
	tw.tween_callback(d.queue_free)


# ------------------------------------------------------------------ teleporte (blink)

func _start_blink() -> void:
	if _adventure != null and not _adventure.state.has_skill("blink"):
		return  # o HUD mostra o cadeado
	if _blink_t >= 0.0 or _blink_cd > 0.0:
		return
	if _adventure != null and _adventure.mana < _adventure.cost("blink"):
		_adventure.spend("blink")  # recusa: pisca a mana e avisa
		return
	if _adventure != null:
		var upper: Vector3 = _adventure.ledge_blink_target()
		if upper != Vector3.INF:
			_begin_blink(upper)
			return
	var from := _player.global_position
	var tgt := _mouse_ground() if not _auto else from + Vector3(cos(_t) * 5.0, 0, sin(_t) * 5.0)
	var d := Vector3(tgt.x - from.x, 0, tgt.z - from.z)
	if d.length() < 0.6:
		return
	var dir := d.normalized()
	var dist := minf(d.length(), BLINK_RANGE)
	# não atravessa árvore/pedra/água: para antes do primeiro obstáculo
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.6, 0), from + dir * dist + Vector3(0, 0.6, 0))
	q.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit.position
		dist = maxf(0.0, Vector2(hp.x - from.x, hp.z - from.z).length() - 0.45)
	while dist > 0.5 and not (_adventure != null and _adventure.in_cave) and Dressing.water_dist(Vector2(from.x + dir.x * dist, from.z + dir.z * dist)) < 0.4:
		dist -= 0.25
	if dist < 0.6:
		return
	_begin_blink(from + dir * dist)


func _begin_blink(destination: Vector3) -> void:
	if _adventure != null:
		_adventure.mana -= _adventure.cost("blink")
	var from := _player.global_position
	_blink_to = destination
	_blink_dir = (destination - from).normalized()
	_aim = Vector3(_blink_dir.x, 0, _blink_dir.z).normalized()
	_blink_t = 0.0
	_blinked = false
	_blink_cd = float(_adventure.config.blink_cooldown) if _adventure != null else BLINK_CD
	_attack_t = -1.0
	_dodge_t = -1.0
	_burst(from + Vector3(0, 0.7, 0))
	_shockwave(from)
	for i in 5:
		var k := (i + 1) / 6.0
		_ghost(from.lerp(_blink_to, k), 0.2 + 0.5 * k, 0.35)


func _update_blink(delta: float) -> void:
	_blink_t += delta
	_player.velocity = Vector3.ZERO
	if _blink_t < BLINK_OUT:
		_set_dissolve(_blink_t / BLINK_OUT)
		return
	if not _blinked:
		_blinked = true
		_player.global_position = _blink_to
		_burst(_blink_to + Vector3(0, 0.7, 0))
		_shockwave(_blink_to)
	var k := (_blink_t - BLINK_OUT) / BLINK_IN
	_set_dissolve(1.0 - k)
	if k >= 1.0:
		_set_dissolve(0.0)
		_blink_t = -1.0


func _set_dissolve(v: float) -> void:
	_dissolve = clampf(v, 0.0, 1.0)
	for m in _char_mats:
		m.set_shader_parameter("dissolve", _dissolve)


func _ghost_material(alpha: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _ghost_shader
	m.set_shader_parameter("alpha", alpha)
	m.set_shader_parameter("color", Color(1.0, 0.42, 0.1) if _pyro else Color(0.35, 0.75, 1.0))
	return m


## Cópia do personagem na pose atual, cor sólida que some em `life` segundos.
func _ghost(pos: Vector3, alpha: float, life: float) -> void:
	var g := _model.duplicate() as Node3D
	for n in g.find_children("*", "", true, false):
		if n is GPUParticles3D or n is Light3D or n is AnimationPlayer:
			n.queue_free()
	var m := _ghost_material(alpha)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(g)
	g.global_transform = Transform3D(_model.global_transform.basis, pos)
	var tw := g.create_tween()
	tw.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), alpha, 0.0, life)
	tw.tween_callback(g.queue_free)


## Explosão de faíscas única (origem e destino do teleporte).
func _burst(pos: Vector3) -> void:
	var g := GPUParticles3D.new()
	g.amount = 40
	g.lifetime = 0.55
	g.one_shot = true
	g.explosiveness = 1.0
	g.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	var hot := Color(3.0, 1.3, 0.4) if _pyro else Color(0.8, 2.0, 3.0)
	pm.color_ramp = _ramp([hot, hot * Color(0.7, 0.45, 0.4), Color(0.4, 0.1, 0.1, 0.0)])
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	q.material = _spark_mat
	g.draw_pass_1 = q
	_vp.add_child(g)
	g.global_position = pos
	g.emitting = true
	get_tree().create_timer(1.2).timeout.connect(g.queue_free)


## Anel que se expande no chão e some.
func _shockwave(pos: Vector3, radius := 1.76) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.55
	t.rings = 28
	t.ring_segments = 4
	ring.mesh = t
	var m := _ghost_material(1.0)
	m.set_shader_parameter("energy", 3.0)
	m.set_shader_parameter("rim_cut", 2.0)
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.06, 0)
	ring.scale = Vector3(0.4, 0.15, 0.4)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius / 0.55, 0.15, radius / 0.55), 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(a: float) -> void: m.set_shader_parameter("alpha", a), 1.0, 0.0, 0.38)
	tw.chain().tween_callback(ring.queue_free)


# ------------------------------------------------------------------ vocações (vocations.gd)

## Vocação: --class=… > escolha feita nesta sessão > save > Mago.
func _pick_class(args: Dictionary) -> String:
	if args.has("class"):
		return String(args["class"])
	if Engine.has_meta("aethra_class"):
		return String(Engine.get_meta("aethra_class"))
	var path := "user://pixel3d-first-adventure-v1.json"
	if not args.has("no_save") and not args.has("shot") and FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and (data as Dictionary).has("vocation"):
			return String(data.vocation)
	return "mage"


## Q: Mago = Eco (teleporte); Guerreiro/Arqueiro = habilidade da vocação.
func _skill_q() -> void:
	if _net_mode():
		_adventure.online.q(_mouse_ground())
		return
	if _voc.is_mage():
		_start_blink()
	else:
		_voc.cast_q()


## Investida/salto reaproveitam a esquiva (mesmo estado, invulnerável enquanto dura).
func _begin_dash(dir: Vector3, speed: float, length: float, anim: String, kind: String) -> void:
	_dodge_dir = Vector3(dir.x, 0, dir.z).normalized()
	_dash_speed = speed
	_dash_len = length
	_dash_anim = anim
	_dash_kind = kind
	_dodge_t = 0.0
	_attack_t = -1.0
	_anim_cur = ""


func _end_dash() -> void:
	_dodge_t = -1.0
	_dash_speed = DODGE_SPEED
	_dash_len = DODGE_T
	_dash_anim = "Dodge_Forward"
	_dash_kind = ""


## Toca uma animação "de uma vez" (golpe giratório etc.) sem ser cortada pelo Idle/Run.
func _play_once(anim_name: String, speed: float) -> void:
	_play(anim_name, speed, true)
	_once_t = _anim_len(anim_name) / maxf(speed, 0.01)


## Faísca pequena e curta (golpe de espada, flecha no cenário).
func _ghost_spark(pos: Vector3) -> void:
	var g := GPUParticles3D.new()
	g.amount = 8
	g.lifetime = 0.25
	g.one_shot = true
	g.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = _ramp([Color(1, 1, 0.9, 1), Color(1, 0.85, 0.5, 0.0)])
	g.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	g.draw_pass_1 = q
	_vp.add_child(g)
	g.global_position = pos
	g.emitting = true
	get_tree().create_timer(0.6).timeout.connect(g.queue_free)
