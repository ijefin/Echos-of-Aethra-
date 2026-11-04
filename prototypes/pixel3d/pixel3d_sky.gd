# PROTOTYPE - NOT FOR PRODUCTION
# Ciclo dia/noite + raios de sol. O sol nasce quente (laranja), fica creme ao meio-dia e
# se põe rosado; à noite a lua azulada assume, o ambiente vai para azul-roxo e as luzes
# quentes (lampiões, fadas, árvores mágicas) ganham destaque. Raios de sol: quads baratos
# alinhados ao sol, mais fortes de manhã e no fim da tarde.
extends RefCounted

## Ciclo (2026-11-03): DIA = 20 min reais (06:00→18:00), NOITE = 7 min reais (18:00→06:00) → 27 min.
## Amanhecer = 1,5 min no começo do dia (06:00→06:54); entardecer = 1,5 min no fim (17:06→18:00).
## Os dois contam DENTRO dos 20 min de dia. Teste: tools/test_day_night.gd.
const DAY_MINUTES := 20.0
const NIGHT_MINUTES := 7.0
const DAWN_MINUTES := 1.5
const DUSK_MINUTES := 1.5
const SUNRISE := 6.0
const SUNSET := 18.0
## Piso de luz ambiente à noite: terreno, obstáculos e ameaças próximas continuam legíveis.
const NIGHT_AMBIENT := 0.9
const SHAFTS := 0  # luz das copas removida a pedido do usuário (2026-11-03)
const Dressing := preload("res://prototypes/pixel3d/pixel3d_dressing.gd")
const AMB_DAY := Color(0.42, 0.36, 0.64)
const AMB_DUSK := Color(0.62, 0.4, 0.56)
const AMB_NIGHT := Color(0.28, 0.33, 0.56)
const SUN_NOON := Color(1.0, 0.92, 0.78)
const SUN_LOW := Color(1.0, 0.56, 0.3)

var hour := 8.5
var day_seconds := DAY_MINUTES * 60.0
var night_seconds := NIGHT_MINUTES * 60.0
var night := 0.0          # 0 = dia, 1 = noite (lido por lampiões, fadas, vagalumes)
var day := 1.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var shaft_mat: ShaderMaterial
var _shafts: Array[Dictionary] = []
var _layout_timer := 0.0
## Materiais que acendem à noite: [ShaderMaterial, cor, energia máxima].
var night_glow: Array = []


func build(root: Node3D, sun_light: DirectionalLight3D, environment: Environment, rng: RandomNumberGenerator, _half: float, trees: Array) -> void:
	sun = sun_light
	env = environment
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.64, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 40.0
	# Both shadow maps follow the celestial orbit; the moon is not a fixed fill.
	sun.shadow_opacity = 0.82
	moon.shadow_opacity = 0.62
	root.add_child(moon)
	if not Engine.has_meta("aethra_globals"):  # marcado pelo demo depois do 1º build
		RenderingServer.global_shader_parameter_add(&"sun_dir", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.DOWN)
	shaft_mat = ShaderMaterial.new()
	shaft_mat.shader = load("res://prototypes/pixel3d/shaders/sun_shaft.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var candidates := trees.duplicate()
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return _path_distance(a[0]) < _path_distance(b[0]))
	for tree: Array in candidates:
		if _shafts.size() >= SHAFTS:
			break
		var anchor: Vector3 = tree[0]
		var crowded := false
		for beam: Dictionary in _shafts:
			if anchor.distance_to(beam.anchor) < 5.5:
				crowded = true
				break
		if crowded:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var m := shaft_mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("seed", rng.randf() * 10.0)
		m.set_shader_parameter("width", rng.randf_range(0.45, 0.85))
		mi.material_override = m
		mi.extra_cull_margin = 12.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = anchor
		root.add_child(mi)
		var light := SpotLight3D.new()
		light.spot_angle = 18.0
		light.spot_angle_attenuation = 1.5
		light.spot_attenuation = 0.65
		light.light_specular = 0.0
		light.light_size = 0.12
		root.add_child(light)
		_shafts.append({"anchor": anchor, "size": float(tree[1]), "mat": m, "mesh": mi, "light": light, "valid": false})
	shaft_mat = null
	update(0.0)


static func _path_distance(p: Vector3) -> float:
	return minf(absf(p.x - sin(p.z * 0.18) * 3.0), absf(p.z - sin(p.x * 0.15) * 2.0 - 4.0))


func _place_shafts() -> void:
	var direction := -sun.global_transform.basis.z.normalized()
	# Hide at low sun angles instead of stretching horizontal bars.
	var elevation := smoothstep(0.32, 0.62, -direction.y)
	for beam: Dictionary in _shafts:
		var size: float = beam.size
		# Begin below the leaf shell, where light has passed the canopy opening.
		var source: Vector3 = beam.anchor + Vector3(direction.x, 0, direction.z).normalized() * size * 1.1
		source.y = size * 1.85
		var length_u := source.y / maxf(-direction.y, 0.25)
		var target := source + direction * length_u
		beam.target = target
		# Favor patches on the path/forest edge rather than buried inside bushes.
		beam.valid = elevation > 0.0 and Dressing.water_dist(Vector2(target.x, target.z)) > 0.8 and _path_distance(target) < 2.6
		(beam.mesh as MeshInstance3D).visible = beam.valid
		var mat: ShaderMaterial = beam.mat
		mat.set_shader_parameter("source", source)
		mat.set_shader_parameter("target", target)
		var light: SpotLight3D = beam.light
		light.position = source
		light.look_at(target, Vector3.UP)
		light.spot_range = length_u + 1.8
		light.light_color = sun.light_color
		beam.elevation = elevation


## Adianta o relógio (tecla N).
func skip(hours: float) -> void:
	hour = fposmod(hour + hours, 24.0)
	_layout_timer = 0.0


## Para testes: muda as durações (amanhecer/entardecer mantêm a proporção 1,5/20 do dia).
func set_cycle_minutes(day_min: float, night_min: float) -> void:
	day_seconds = maxf(day_min, 0.01) * 60.0
	night_seconds = maxf(night_min, 0.01) * 60.0


func _is_day(h: float) -> bool:
	return h >= SUNRISE and h < SUNSET


## Duração em horas de jogo do amanhecer/entardecer (1,5 min reais → 0,9 h com dia de 20 min).
func _edge_hours() -> float:
	return 12.0 * DAWN_MINUTES / DAY_MINUTES


## "dawn" / "day" / "dusk" / "night".
func phase() -> String:
	if not _is_day(hour):
		return "night"
	if hour < SUNRISE + _edge_hours():
		return "dawn"
	if hour >= SUNSET - _edge_hours():
		return "dusk"
	return "day"


## 0 = dia pleno, 1 = noite; transição suave no amanhecer e no entardecer.
func _night_at(h: float) -> float:
	if not _is_day(h):
		return 1.0
	var edge := _edge_hours()
	if h < SUNRISE + edge:
		return 1.0 - smoothstep(0.0, 1.0, (h - SUNRISE) / edge)
	if h > SUNSET - edge:
		return smoothstep(0.0, 1.0, (h - (SUNSET - edge)) / edge)
	return 0.0


## Avança o relógio: dia e noite andam em velocidades diferentes, com troca exata na borda.
func _advance(delta: float) -> void:
	var left := delta
	var guard := 0
	while left > 0.0 and guard < 4:
		guard += 1
		var daytime := _is_day(hour)
		var rate := 12.0 / (day_seconds if daytime else night_seconds)
		var boundary := SUNSET if daytime else (SUNRISE if hour < SUNRISE else SUNRISE + 24.0)
		var to_boundary := (boundary - hour) / rate
		if left < to_boundary:
			hour += left * rate
			left = 0.0
		else:
			hour = fmod(boundary, 24.0)
			left -= to_boundary
	hour = fposmod(hour, 24.0)


## Shared solar/lunar arc: a high light casts short shadows, a low light long ones.
static func orbit_rotation(progress: float, azimuth_offset := 0.0) -> Vector3:
	var altitude := maxf(0.0, sin(progress * PI))
	return Vector3(-lerpf(10.0, 66.0, altitude), lerpf(-135.0, 70.0, progress) + azimuth_offset, 0.0)


func update(delta: float, viewer := Vector3.ZERO) -> void:
	_advance(delta)
	var e := sin((hour - 6.0) / 12.0 * PI)          # elevação do sol: > 0 de dia
	night = _night_at(hour)
	day = 1.0 - night
	var low := 1.0 - smoothstep(0.12, 0.55, e)       # sol perto do horizonte = luz quente
	var t := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	sun.visible = day > 0.005
	sun.rotation_degrees = orbit_rotation(t)
	sun.light_energy = 1.05 * pow(day, 0.6)  # o sol segura a luz até perto do fim do entardecer
	sun.light_color = SUN_NOON.lerp(SUN_LOW, low * day)
	# lua: atravessa o céu durante a noite; espera no horizonte no entardecer e se põe no amanhecer
	# (arco entre 18% e 82%: nunca rasante — sombras longas demais escondiam o chão)
	var moon_t := 0.18
	if not _is_day(hour):
		moon_t = lerpf(0.18, 0.82, clampf(fposmod(hour - SUNSET, 24.0) / 12.0, 0.0, 1.0))
	elif hour < 12.0:
		moon_t = 0.82
	moon.rotation_degrees = orbit_rotation(moon_t, 180.0)
	moon.light_energy = 0.46 * night * (0.85 + 0.15 * sin(moon_t * PI))
	moon.visible = moon.light_energy > 0.005
	var amb := AMB_DAY.lerp(AMB_DUSK, low * day)
	env.ambient_light_color = amb.lerp(AMB_NIGHT, night)
	env.ambient_light_energy = lerpf(0.5, NIGHT_AMBIENT, night)
	env.glow_intensity = lerpf(0.9, 1.3, night)
	env.adjustment_saturation = lerpf(1.15, 1.02, night)
	RenderingServer.global_shader_parameter_set(&"sun_dir", -sun.global_transform.basis.z)
	_layout_timer -= delta
	if _layout_timer <= 0.0 or delta == 0.0:
		_layout_timer = 0.12
		_place_shafts()
	var nearby := _shafts.filter(func(beam: Dictionary) -> bool: return beam.valid)
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.target as Vector3).distance_squared_to(viewer) < (b.target as Vector3).distance_squared_to(viewer))
	for beam: Dictionary in _shafts:
		var strength := day * float(beam.get("elevation", 0.0))
		var light: SpotLight3D = beam.light
		var rank := nearby.find(beam)
		light.visible = beam.valid and strength > 0.01 and rank >= 0 and rank < 3 and (beam.target as Vector3).distance_squared_to(viewer) < 324.0
		(beam.mesh as MeshInstance3D).visible = light.visible
		(beam.mat as ShaderMaterial).set_shader_parameter("intensity", strength * 0.34)
		light.light_energy = 6.0 * strength
		light.shadow_enabled = false
	for g: Array in night_glow:
		(g[0] as ShaderMaterial).set_shader_parameter("emission", g[1])
		(g[0] as ShaderMaterial).set_shader_parameter("emission_energy", float(g[2]) * night)


func label() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]
