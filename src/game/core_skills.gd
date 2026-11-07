extends RefCounted
## Core skills: habilidades básicas de TODAS as classes (independem do mago/guerreiro/arqueiro).
## Dados em data/core_skills.json. Para criar outra: chave nova em "skills" + um ramo em _apply/_expire.
## Estado por skill: {"left": duração restante, "cd": recarga restante}. `effects()` é o que a rede sincroniza.

const DATA := "res://src/game/data/core_skills.json"

var adventure
var demo
var config: Dictionary = {}
var state: Dictionary = {}
var _light: OmniLight3D
var _orb: Node3D
var _orb_mat: ShaderMaterial
var _t := 0.0


func build(owner_adventure) -> void:
	adventure = owner_adventure
	demo = adventure.demo
	config = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for id: String in config.order:
		state[id] = {"left": 0.0, "cd": 0.0}
	_build_light()


func skill(id: String) -> Dictionary:
	return config.skills[id]


## Lança a core skill. Mesma regra para qualquer classe: mana + recarga. Relançar renova a duração.
func cast(id: String) -> bool:
	if not state.has(id) or adventure.hud.any_open():
		return false
	var s: Dictionary = skill(id)
	var st: Dictionary = state[id]
	if float(st.cd) > 0.0:
		return false
	if adventure.mana < float(s.mana):
		adventure.hud.flash_mana()
		return false
	adventure.mana -= float(s.mana)
	st.cd = float(s.cooldown)
	st.left = float(s.duration)
	adventure.player_say(String(s.words))
	_apply(id, true)
	return true


func remaining(id: String) -> float:
	return float(state[id].left) if state.has(id) else 0.0


func cooldown_ratio(id: String) -> float:
	return clampf(float(state[id].cd) / maxf(0.01, float(skill(id).cooldown)), 0.0, 1.0)


## Estado compacto para a rede (efeitos ativos e quanto falta).
func effects() -> Dictionary:
	var out := {}
	for id: String in state:
		if float(state[id].left) > 0.0:
			out[id] = snappedf(float(state[id].left), 0.1)
	return out


## Aplica efeitos vindos da rede (jogador remoto) ou de um save.
func set_effects(fx: Dictionary) -> void:
	for id: String in state:
		var left := float(fx.get(id, 0.0))
		var was := float(state[id].left) > 0.0
		state[id].left = left
		if (left > 0.0) != was:
			_apply(id, left > 0.0)


func update(delta: float) -> void:
	_t += delta
	for id: String in state:
		var st: Dictionary = state[id]
		st.cd = maxf(0.0, float(st.cd) - delta)
		if float(st.left) > 0.0:
			st.left = maxf(0.0, float(st.left) - delta)
			if float(st.left) <= 0.0:
				_apply(id, false)
	_update_light()


# ------------------------------------------------------------------ Luz (utevo vis lux)

func _build_light() -> void:
	var s: Dictionary = skill("light")
	var c: Array = s.light_color
	_orb = Node3D.new()
	demo._player.add_child(_orb)
	_orb.position = Vector3(0, 2.15, 0)
	_light = OmniLight3D.new()
	_light.light_color = Color(float(c[0]), float(c[1]), float(c[2]))
	_light.omni_range = float(s.light_range)
	_light.omni_attenuation = 0.9
	_light.light_specular = 0.0
	_light.shadow_enabled = false
	_orb.add_child(_light)
	var core := SphereMesh.new()
	core.radius = 0.09
	core.height = 0.18
	core.radial_segments = 6
	core.rings = 3
	_orb_mat = demo._toon(Color(1, 0.95, 0.75), Color(1, 0.9, 0.6), 4.0)
	demo._mesh(core, _orb_mat, Vector3.ZERO, _orb)
	_orb.hide()


func _apply(id: String, on: bool) -> void:
	match id:
		"light":
			_orb.visible = on
			if on:
				demo._burst(demo._player.global_position + Vector3(0, 1.6, 0))


func _update_light() -> void:
	var left := remaining("light")
	if left <= 0.0:
		return
	var s: Dictionary = skill("light")
	# a esfera orbita sobre a cabeça; perto do fim pisca cada vez mais rápido
	_orb.position = Vector3(cos(_t * 1.6) * 0.35, 2.15 + sin(_t * 3.1) * 0.06, sin(_t * 1.6) * 0.35)
	var fade := 1.0
	var warn := float(s.warn_last)
	if left < warn:
		var rate := lerpf(9.0, 3.0, left / warn)
		fade = 0.55 + 0.45 * (0.5 + 0.5 * cos(_t * rate))
	var grow := clampf((float(s.duration) - left) / 0.6, 0.0, 1.0)  # acende em 0,6 s
	_light.light_energy = float(s.light_energy) * fade * grow
	_light.omni_range = float(s.light_range) * (0.85 + 0.15 * fade)
	_orb_mat.set_shader_parameter("emission_energy", 4.0 * fade)


## Quanto a luz realça a leitura dos personagens à noite (somado ao readability do céu).
func readability_boost() -> float:
	return float(skill("light").readability) if remaining("light") > 0.0 else 0.0
