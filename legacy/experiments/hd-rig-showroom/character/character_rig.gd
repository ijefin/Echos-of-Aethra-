class_name CharacterRig
extends Node2D
## Personagem em rig de recorte (art bible §1/§8, revisão HD 2026-10-31).
## Esqueleto de Node2D (quadril → tronco → pescoço/cabeça, ombros → braço → antebraço →
## mão → arma, quadris → coxa → canela → pé) com peças por slot: corpo da raça, roupa
## (robe/armadura) e arma. Animação procedural suave a 60 fps: idle respirando, corrida
## com balanço e inclinação, ataque com antecipação e follow-through, esquiva com
## squash/stretch e reação a dano. Dimensões e ritmos em legacy/2d/assets/data/char_rig.json.
## As peças são placeholders vetoriais (RigShape) até as peças pintadas da IA (Fase 2).
##
## Uso:
##   var rig := CharacterRig.new()
##   add_child(rig)
##   rig.setup(JsonData.load_dict("res://legacy/2d/assets/data/char_rig.json"), "elf", "robe_fire", "staff_fire")
##   rig.set_motion(Vector2.RIGHT)   # corre para a direita
##   rig.attack()

## Emitido no frame do golpe (onde o dano/projétil deve sair).
signal action_released

const VIEWS: Array[String] = ["down", "up", "right"]
const C_LINEN := Color(0.86, 0.8, 0.68)
const C_PANTS := Color(0.36, 0.27, 0.22)
const C_BOOT := Color(0.24, 0.16, 0.12)
const C_ROBE := Color(0.72, 0.2, 0.23)
const C_ROBE_DARK := Color(0.45, 0.1, 0.16)
const C_GOLD := Color(0.85, 0.64, 0.25)
const C_STEEL := Color(0.62, 0.66, 0.74)
const C_STEEL_DARK := Color(0.32, 0.34, 0.42)
const C_LEATHER := Color(0.35, 0.22, 0.15)
const C_BRONZE := Color(0.78, 0.52, 0.25)
const C_TABARD := Color(0.2, 0.3, 0.6)
const C_WOOD := Color(0.4, 0.26, 0.16)
const C_EMBER := Color(1.0, 0.55, 0.15)
const C_EYE := Color(0.16, 0.11, 0.13)

var race_id := "human"
var outfit_id := "none"
var weapon_id := "none"
## Vista atual: "down" (frente), "up" (costas) ou "right" (lado; esquerda = espelho).
var view := "down"
var facing_left := false
var state := "idle"

var _data: Dictionary
var _sk: Dictionary
var _race: Dictionary
var _motion: Dictionary
var _bones: Dictionary = {}
var _body: Node2D
var _t := 0.0
var _phase := 0.0
var _run := 0.0
var _move_dir := Vector2.ZERO
var _action_t := 0.0
var _released := false
var _dodge_dir := Vector2.ZERO
var _pose: Dictionary = {}
var _flash := 0.0


func setup(data: Dictionary, race: String, outfit: String, weapon: String) -> void:
	_data = data
	_sk = data.skeleton
	_motion = data.motion
	race_id = race
	outfit_id = outfit
	weapon_id = weapon
	rebuild()


## Troca raça, roupa ou arma e remonta as peças (paperdoll).
func equip(race: String, outfit: String, weapon: String) -> void:
	race_id = race
	outfit_id = outfit
	weapon_id = weapon
	rebuild()


## Direção do movimento (zero = parado). Define a vista e a corrida.
func set_motion(dir: Vector2) -> void:
	_move_dir = dir
	if dir.length() > 0.1 and state != "attack" and state != "dodge":
		_face(dir)


func attack() -> void:
	if state == "dodge":
		return
	state = "attack"
	_action_t = 0.0
	_released = false


func dodge(dir: Vector2) -> void:
	if state == "dodge":
		return
	state = "dodge"
	_action_t = 0.0
	_dodge_dir = dir.normalized() if dir.length() > 0.1 else (Vector2.LEFT if facing_left else Vector2.RIGHT)
	_face(_dodge_dir)


func hurt() -> void:
	state = "hurt"
	_action_t = 0.0
	_flash = 0.12


func _face(dir: Vector2) -> void:
	var new_view := view
	if absf(dir.x) > absf(dir.y) * 0.8:
		new_view = "right"
		facing_left = dir.x < 0.0
	else:
		new_view = "down" if dir.y > 0.0 else "up"
	if new_view != view:
		view = new_view
		rebuild()


# ------------------------------------------------------------------ montagem

func _bone(bone_name: String, parent: Node2D, pos: Vector2, z := 0) -> Node2D:
	var b := Node2D.new()
	b.name = bone_name
	b.position = pos
	b.z_index = z
	b.z_as_relative = true
	parent.add_child(b)
	_bones[bone_name] = b
	return b


func _add(bone_name: String, shape: RigShape, z := 0) -> void:
	shape.z_index = z
	shape.z_as_relative = true
	(_bones[bone_name] as Node2D).add_child(shape)


func rebuild() -> void:
	if _body != null:
		_body.queue_free()
	_bones.clear()
	_race = _data.races[race_id]
	var side := view == "right"
	var w := float(_race.width)
	var hgt := float(_race.height)
	var legs := float(_race.legs)
	var hip_h := float(_sk.hip_height) * legs * hgt
	var torso_len := float(_sk.torso) * hgt
	var sw := float(_sk.shoulder_width) * w * (0.32 if side else 1.0)
	var hw := float(_sk.hip_width) * w * (0.45 if side else 1.0)
	var head_r := float(_sk.head_r) * float(_race.head)
	var far_z := -3 if side else 1
	var near_z := 3 if side else 1

	_body = Node2D.new()
	_body.name = "Body"
	add_child(_body)
	_bones["root"] = _body
	var hips := _bone("hips", _body, Vector2(0, -hip_h))
	var torso := _bone("torso", hips, Vector2.ZERO, 0)
	_bone("skirt", hips, Vector2.ZERO, 1)
	var neck := _bone("neck", torso, Vector2(2 if side else 0, -torso_len), 2)
	_bone("head", neck, Vector2(2 if side else 0, -float(_sk.neck) - head_r), 0)
	# braço direito do personagem: na frente fica à esquerda da tela; no lado é o "de perto"
	var rx := -sw / 2.0 if view == "down" else (sw / 2.0 if view == "up" else 3.0)
	var lx := -rx if not side else -3.0
	for side_name: String in ["r", "l"]:
		var x := rx if side_name == "r" else lx
		var z := (near_z if side_name == "r" else far_z) if side else 1
		var sh := _bone("shoulder_" + side_name, torso, Vector2(x, -torso_len + 7.0), z)
		var ua := _bone("upper_arm_" + side_name, sh, Vector2.ZERO)
		var fa := _bone("forearm_" + side_name, ua, Vector2(0, float(_sk.upper_arm) * hgt))
		var hand := _bone("hand_" + side_name, fa, Vector2(0, float(_sk.forearm) * hgt))
		if side_name == "r":
			_bone("weapon", hand, Vector2.ZERO, 1)
		var hx := hw / 2.0 if side_name == "l" else -hw / 2.0
		if view == "up":
			hx = -hx
		if side:
			hx = 2.0 if side_name == "r" else -2.0
		var leg_z := (near_z - 4 if side_name == "r" else far_z - 2) if side else -1
		var hip := _bone("hip_" + side_name, hips, Vector2(hx, 0), leg_z)
		var th := _bone("thigh_" + side_name, hip, Vector2.ZERO)
		var shin := _bone("shin_" + side_name, th, Vector2(0, float(_sk.thigh) * legs * hgt))
		_bone("foot_" + side_name, shin, Vector2(0, float(_sk.shin) * legs * hgt))
		if side and side_name == "l":
			for b: String in ["shoulder_l", "hip_l"]:
				(_bones[b] as Node2D).modulate = Color(0.72, 0.72, 0.8)
	_build_base(torso_len, sw, hw, head_r)
	match outfit_id:
		"robe_fire":
			_build_robe(torso_len, sw, hw, head_r)
		"armor_iron":
			_build_armor(torso_len, sw, hw, head_r)
	match weapon_id:
		"staff_fire":
			_build_staff()
		"sword_iron":
			_build_sword()
	_pose.clear()


func _limb_parts(skin: Color, sleeve: Color, pants: Color) -> void:
	var lr: Dictionary = _sk.limb_r
	var hgt := float(_race.height)
	var legs := float(_race.legs)
	var w := float(_race.width)
	for s: String in ["r", "l"]:
		_add("upper_arm_" + s, RigShape.capsule(float(_sk.upper_arm) * hgt, float(lr.upper_arm[0]) * w, float(lr.upper_arm[1]) * w, sleeve))
		_add("forearm_" + s, RigShape.capsule(float(_sk.forearm) * hgt, float(lr.forearm[0]) * w, float(lr.forearm[1]) * w, skin))
		_add("hand_" + s, RigShape.ellipse(Vector2(0, 2), float(_sk.hand_r) * w, float(_sk.hand_r) * w * 1.1, skin), 1)
		_add("thigh_" + s, RigShape.capsule(float(_sk.thigh) * legs * hgt, float(lr.thigh[0]) * w, float(lr.thigh[1]) * w, pants))
		_add("shin_" + s, RigShape.capsule(float(_sk.shin) * legs * hgt, float(lr.shin[0]) * w, float(lr.shin[1]) * w, pants))
		var foot_dx := 5.0 if view == "right" else 0.0
		_add("foot_" + s, RigShape.ellipse(Vector2(foot_dx, 3), float(_sk.foot) * 0.6 * w + (3.0 if view == "right" else 0.0), 5.0, C_BOOT), 1)


func _build_base(torso_len: float, sw: float, hw: float, head_r: float) -> void:
	var skin := Color(_race.skin[0], _race.skin[1], _race.skin[2])
	var hair := Color(_race.hair[0], _race.hair[1], _race.hair[2])
	_limb_parts(skin, C_LINEN, C_PANTS)
	var top := sw / 2.0 + 4.0
	var bot := hw / 2.0 + 6.0
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-top, -torso_len - 2), Vector2(top, -torso_len - 2),
		Vector2(bot + 2, -6), Vector2(bot, 6), Vector2(-bot, 6), Vector2(-bot - 2, -6)]), C_LINEN))
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-bot - 1, -2), Vector2(bot + 1, -2), Vector2(bot + 1, 3), Vector2(-bot - 1, 3)]), C_LEATHER), 1)
	# pescoço e cabeça
	_add("neck", RigShape.capsule(float(_sk.neck) + 2.0, 5.0, 5.0, skin.darkened(0.1), Vector2(0, -float(_sk.neck) - 1.0)), -1)
	var hair_style := String(_race.get("hair_style", "short"))
	if hair_style == "long" and view != "up":
		_add("head", RigShape.poly(PackedVector2Array([Vector2(-head_r - 2, -4), Vector2(head_r + 2, -4), Vector2(head_r + 1, head_r + 16), Vector2(-head_r - 1, head_r + 16)]), hair.darkened(0.15)), -2)
	if _race.get("ears", false):
		for s: float in ([1.0] if view == "right" else [-1.0, 1.0]):
			var ex := (-head_r * 0.2 if view == "right" else s * head_r * 0.85)
			_add("head", RigShape.poly(PackedVector2Array([Vector2(ex, -2), Vector2(ex + s * (head_r * 0.75 if view != "right" else -12.0), -14), Vector2(ex, 6)]), skin), -1)
	_add("head", RigShape.ellipse(Vector2.ZERO, head_r, head_r * 1.05, skin))
	if view == "down":
		for ex: float in [-head_r * 0.38, head_r * 0.38]:
			_add("head", RigShape.ellipse(Vector2(ex, head_r * 0.1), 2.0, 2.6, C_EYE), 1)
		_add("head", RigShape.ellipse(Vector2(0, head_r * 0.55), 3.0, 1.0, skin.darkened(0.3)), 1)
	elif view == "right":
		_add("head", RigShape.ellipse(Vector2(head_r * 0.5, head_r * 0.1), 1.8, 2.6, C_EYE), 1)
		_add("head", RigShape.ellipse(Vector2(head_r * 0.98, head_r * 0.3), 2.5, 2.0, skin), 1)
	# cabelo
	var cap: PackedVector2Array
	if view == "up":
		cap = _arc_poly(Vector2.ZERO, head_r + 1.5, head_r * 1.08 + 1.5, PI * 0.95, TAU + PI * 0.05)
		cap.append(Vector2(head_r * 0.7, head_r * 0.85))
		cap.append(Vector2(-head_r * 0.7, head_r * 0.85))
	elif view == "right":
		cap = _arc_poly(Vector2(-1, -1), head_r + 1.5, head_r + 1.5, PI * 0.55, TAU + PI * 0.05)
		cap.append(Vector2(-head_r * 0.2, head_r * 0.6))
	else:
		cap = _arc_poly(Vector2(0, -1), head_r + 1.5, head_r + 1.0, PI, TAU)
		cap.append(Vector2(head_r * 0.9, -head_r * 0.15))
		cap.append(Vector2(-head_r * 0.9, -head_r * 0.15))
	_add("head", RigShape.poly(cap, hair), 2)
	if _race.get("beard", false) and view != "up":
		var bx := head_r * 0.35 if view == "right" else 0.0
		_add("head", RigShape.poly(PackedVector2Array([Vector2(bx - head_r * 0.8, head_r * 0.25), Vector2(bx + head_r * 0.8, head_r * 0.25),
			Vector2(bx + head_r * 0.55, head_r * 1.35), Vector2(bx, head_r * 1.8), Vector2(bx - head_r * 0.55, head_r * 1.35)]), hair), 3)


func _arc_poly(c: Vector2, rx: float, ry: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Círculo completo: não repete o primeiro ponto (ponto duplicado quebra a triangulação).
	var full := absf(a1 - a0) >= TAU - 0.001
	var count := 24 if full else 17
	for i in count:
		var a := lerpf(a0, a1, float(i) / (float(count) if full else 16.0))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _build_robe(torso_len: float, sw: float, hw: float, head_r: float) -> void:
	var lr: Dictionary = _sk.limb_r
	var hgt := float(_race.height)
	var legs := float(_race.legs)
	var w := float(_race.width)
	var top := sw / 2.0 + 6.0
	var bot := hw / 2.0 + 9.0
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-top, -torso_len - 3), Vector2(top, -torso_len - 3),
		Vector2(bot, 4), Vector2(-bot, 4)]), C_ROBE), 2)
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-bot, -3), Vector2(bot, -3), Vector2(bot, 2), Vector2(-bot, 2)]), C_GOLD), 3)
	if view == "down":
		_add("torso", RigShape.poly(PackedVector2Array([Vector2(-1.5, -torso_len), Vector2(1.5, -torso_len), Vector2(1.5, -3), Vector2(-1.5, -3)]), C_GOLD), 3)
	# saia do robe até o meio da canela, presa ao quadril (balança com as pernas)
	var skirt_len := (float(_sk.thigh) + float(_sk.shin) * 0.75) * legs * hgt
	var flare := bot + 10.0 * w
	_add("skirt", RigShape.poly(PackedVector2Array([Vector2(-bot, 0), Vector2(bot, 0), Vector2(flare, skirt_len), Vector2(-flare, skirt_len)]), C_ROBE))
	_add("skirt", RigShape.poly(PackedVector2Array([Vector2(-flare + 1, skirt_len - 5), Vector2(flare - 1, skirt_len - 5), Vector2(flare, skirt_len), Vector2(-flare, skirt_len)]), C_GOLD), 1)
	for i in 5:
		var rune := RigShape.ellipse(Vector2(lerpf(-flare + 8, flare - 8, i / 4.0), skirt_len - 10), 1.6, 1.6, C_EMBER)
		rune.glow = true
		_add("skirt", rune, 2)
	# mangas largas (boca de sino) com punho dourado
	for s: String in ["r", "l"]:
		_add("upper_arm_" + s, RigShape.capsule(float(_sk.upper_arm) * hgt, float(lr.upper_arm[0]) * w + 2.0, float(lr.upper_arm[1]) * w + 3.0, C_ROBE), 1)
		_add("forearm_" + s, RigShape.capsule(float(_sk.forearm) * hgt - 4.0, float(lr.forearm[0]) * w + 3.0, float(lr.forearm[1]) * w + 7.0, C_ROBE), 1)
		_add("forearm_" + s, RigShape.poly(PackedVector2Array([Vector2(-12 * w, float(_sk.forearm) * hgt - 6), Vector2(12 * w, float(_sk.forearm) * hgt - 6),
			Vector2(12 * w, float(_sk.forearm) * hgt - 2), Vector2(-12 * w, float(_sk.forearm) * hgt - 2)]), C_GOLD), 2)
	# capuz: costas atrás da cabeça + aba por cima
	var hood_back := _arc_poly(Vector2(0, 1), head_r + 6, head_r + 7, 0.0, TAU)
	if view != "down":
		hood_back = _arc_poly(Vector2(-2 if view == "right" else 0, 0), head_r + 5, head_r + 6, 0.0, TAU)
	_add("head", RigShape.poly(hood_back, C_ROBE_DARK), -3)
	# Aba do capuz: faixa entre um arco externo e um interno (contorno simples, sem
	# cruzamentos); a ponta é um triângulo à parte.
	var a0 := PI * 0.9 if view == "up" else PI * 1.05
	var a1 := TAU + PI * 0.1 if view == "up" else TAU - PI * 0.05
	var rim := _arc_poly(Vector2.ZERO, head_r + 5, head_r * 1.05 + 5, a0, a1)
	var inner := _arc_poly(Vector2.ZERO, head_r + 0.5, head_r * 1.05 + 0.5, a0, a1)
	inner.reverse()
	rim.append_array(inner)
	_add("head", RigShape.poly(rim, C_ROBE), 4)
	if view != "up":
		var tip_x := -head_r - 6 if view == "right" else 0.0
		var base_x := -head_r * 0.5 if view == "right" else 0.0
		_add("head", RigShape.poly(PackedVector2Array([Vector2(base_x - 7, -head_r - 3), Vector2(base_x + 7, -head_r - 3),
			Vector2(tip_x, -head_r - 15)]), C_ROBE), 3)
	_add("neck", RigShape.ellipse(Vector2(0, 4), sw / 2.0 - 2.0, 5.0, C_GOLD), 3)


func _build_armor(torso_len: float, sw: float, hw: float, head_r: float) -> void:
	var lr: Dictionary = _sk.limb_r
	var hgt := float(_race.height)
	var legs := float(_race.legs)
	var w := float(_race.width)
	var top := sw / 2.0 + 6.0
	var bot := hw / 2.0 + 6.0
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-top, -torso_len - 2), Vector2(top, -torso_len - 2),
		Vector2(bot + 3, -10), Vector2(bot, 2), Vector2(-bot, 2), Vector2(-bot - 3, -10)]), C_STEEL), 2)
	if view != "right":
		_add("torso", RigShape.poly(PackedVector2Array([Vector2(-4, -torso_len + 4), Vector2(4, -torso_len + 4), Vector2(0, -12)]), C_TABARD), 3)
	_add("torso", RigShape.poly(PackedVector2Array([Vector2(-bot - 1, -3), Vector2(bot + 1, -3), Vector2(bot + 1, 3), Vector2(-bot - 1, 3)]), C_LEATHER), 3)
	_add("torso", RigShape.ellipse(Vector2(0, 0), 3.0, 3.0, C_BRONZE), 4)
	# tassets
	_add("skirt", RigShape.poly(PackedVector2Array([Vector2(-bot, 2), Vector2(bot, 2), Vector2(bot + 3, 20 * legs), Vector2(-bot - 3, 20 * legs)]), C_STEEL_DARK))
	for s: String in ["r", "l"]:
		_add("upper_arm_" + s, RigShape.ellipse(Vector2(0, 2), float(lr.upper_arm[0]) * w + 6.0, 9.0, C_STEEL), 2)
		_add("upper_arm_" + s, RigShape.ellipse(Vector2(0, -1), 1.6, 1.6, C_BRONZE), 3)
		_add("forearm_" + s, RigShape.capsule(float(_sk.forearm) * hgt * 0.7, float(lr.forearm[0]) * w + 1.5, float(lr.forearm[1]) * w + 1.5, C_STEEL, Vector2(0, float(_sk.forearm) * hgt * 0.25)), 1)
		_add("shin_" + s, RigShape.capsule(float(_sk.shin) * legs * hgt * 0.9, float(lr.shin[0]) * w + 1.5, float(lr.shin[1]) * w + 1.5, C_STEEL), 1)
		_add("thigh_" + s, RigShape.ellipse(Vector2(0, float(_sk.thigh) * legs * hgt), 7.0 * w, 6.0, C_STEEL_DARK), 2)
		_add("foot_" + s, RigShape.ellipse(Vector2(5.0 if view == "right" else 0.0, 3), float(_sk.foot) * 0.6 * w + 3.0, 5.5, C_STEEL_DARK), 2)
	# elmo com viseira e penacho
	_add("head", RigShape.ellipse(Vector2(0, -1), head_r + 3, head_r * 1.05 + 3, C_STEEL), 5)
	if view == "down":
		_add("head", RigShape.poly(PackedVector2Array([Vector2(-head_r + 2, 0), Vector2(head_r - 2, 0), Vector2(head_r - 2, 4), Vector2(-head_r + 2, 4)]), C_EYE), 6)
		_add("head", RigShape.poly(PackedVector2Array([Vector2(-1.5, -head_r), Vector2(1.5, -head_r), Vector2(1.5, 10), Vector2(-1.5, 10)]), C_STEEL_DARK), 6)
	elif view == "right":
		_add("head", RigShape.poly(PackedVector2Array([Vector2(2, 0), Vector2(head_r + 3, 0), Vector2(head_r + 3, 4), Vector2(2, 4)]), C_EYE), 6)
	_add("head", RigShape.poly(PackedVector2Array([Vector2(-3, -head_r - 2), Vector2(3, -head_r - 2), Vector2(-4 if view == "right" else 2, -head_r - 16), Vector2(-10 if view == "right" else -2, -head_r - 12)]), C_TABARD), 4)
	if _race.get("beard", false) and view != "up":
		var bx := head_r * 0.35 if view == "right" else 0.0
		var hair := Color(_race.hair[0], _race.hair[1], _race.hair[2])
		_add("head", RigShape.poly(PackedVector2Array([Vector2(bx - head_r * 0.6, head_r * 0.7), Vector2(bx + head_r * 0.6, head_r * 0.7), Vector2(bx, head_r * 1.8)]), hair), 7)


func _build_staff() -> void:
	_add("weapon", RigShape.capsule(132.0, 2.8, 2.3, C_WOOD, Vector2(0, -106)))
	var gem := RigShape.ellipse(Vector2(0, -112), 6.5, 8.0, C_EMBER)
	_add("weapon", gem, 1)
	var core := RigShape.ellipse(Vector2(-1, -114), 3.0, 3.5, Color(1.6, 1.3, 0.7))
	core.glow = true
	_add("weapon", core, 2)


func _build_sword() -> void:
	_add("weapon", RigShape.poly(PackedVector2Array([Vector2(-3.5, 8), Vector2(3.5, 8), Vector2(3, 58), Vector2(0, 66), Vector2(-3, 58)]), C_STEEL), 0)
	_add("weapon", RigShape.poly(PackedVector2Array([Vector2(-0.6, 10), Vector2(0.6, 10), Vector2(0.6, 58), Vector2(-0.6, 58)]), Color(1.4, 1.45, 1.55)), 1)
	_add("weapon", RigShape.poly(PackedVector2Array([Vector2(-11, 4), Vector2(11, 4), Vector2(9, 9), Vector2(-9, 9)]), C_BRONZE), 2)
	_add("weapon", RigShape.capsule(10.0, 2.2, 2.2, C_LEATHER, Vector2(0, -6)), 1)
	_add("weapon", RigShape.ellipse(Vector2(0, -8), 3.0, 3.0, C_BRONZE), 2)


# ------------------------------------------------------------------ animação

func _process(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	var moving := _move_dir.length() > 0.1 and state != "attack"
	_run = move_toward(_run, 1.0 if moving else 0.0, delta * 6.0)
	_phase += delta * TAU * float(_motion.run_cycle_hz) * (0.4 + 0.6 * _run)
	var target := _idle_pose()
	if _run > 0.01:
		target = _blend(target, _run_pose(), _run)
	match state:
		"attack":
			_action_t += delta / float(_motion.attack_seconds)
			target = _attack_pose(target, _action_t)
			if not _released and _action_t >= float(_motion.attack_release) / float(_motion.attack_seconds) * 1.0:
				_released = true
				action_released.emit()
			if _action_t >= 1.0:
				state = "idle"
		"dodge":
			_action_t += delta / float(_motion.dodge_seconds)
			target = _dodge_pose(target, _action_t)
			if _action_t >= 1.0:
				state = "idle"
		"hurt":
			_action_t += delta / float(_motion.hurt_seconds)
			target.torso = float(target.torso) - 12.0 * sin(clampf(_action_t, 0.0, 1.0) * PI)
			target.head = float(target.head) - 8.0 * sin(clampf(_action_t, 0.0, 1.0) * PI)
			if _action_t >= 1.0:
				state = "idle"
	# Suavização exponencial: ataque e esquiva respondem quase direto (golpe seco).
	var k := 1.0 - exp(-float(_motion.pose_smoothing) * delta * (3.0 if state in ["attack", "dodge"] else 1.0))
	if _pose.is_empty():
		_pose = target.duplicate()
	for key: String in target:
		var v: Variant = target[key]
		if v is Vector2:
			_pose[key] = (_pose.get(key, v) as Vector2).lerp(v, k)
		else:
			_pose[key] = lerpf(float(_pose.get(key, v)), float(v), k)
	_apply_pose()
	_flash = maxf(0.0, _flash - delta)
	_body.modulate = Color(2.2, 1.2, 1.2) if _flash > 0.0 else Color.WHITE


func _idle_pose() -> Dictionary:
	var b := sin(_t * TAU * float(_motion.idle_breath_hz))
	var sway := sin(_t * TAU * float(_motion.idle_breath_hz) * 0.5)
	return {"hips_y": 0.0, "torso": 0.0, "breath": 1.0 + b * float(_motion.idle_breath_scale), "head": sway * 1.5,
		"ua_r": 4.0 + b * 2.0, "fa_r": -6.0, "ua_l": -4.0 - b * 2.0, "fa_l": 6.0,
		"th_r": 0.0, "sh_r": 0.0, "th_l": 0.0, "sh_l": 0.0, "lift_r": 0.0, "lift_l": 0.0,
		"skirt": 0.0, "squash": Vector2.ONE, "weapon": 0.0}


func _run_pose() -> Dictionary:
	var p := _phase
	var s := sin(p)
	var thd := float(_motion.run_thigh_deg)
	var kd := float(_motion.run_knee_deg)
	var ad := float(_motion.run_arm_deg)
	var pose := _idle_pose()
	pose.hips_y = -float(_motion.run_bob_px) * absf(cos(p))
	if view == "right":
		pose.torso = float(_motion.run_lean_deg)
		pose.th_r = -thd * s
		pose.th_l = thd * s
		pose.sh_r = kd * maxf(0.0, sin(p + 1.3))
		pose.sh_l = kd * maxf(0.0, sin(p + PI + 1.3))
		pose.ua_r = ad * s
		pose.ua_l = -ad * s
		pose.fa_r = -20.0 - 15.0 * maxf(0.0, s)
		pose.fa_l = -20.0 - 15.0 * maxf(0.0, -s)
		pose.skirt = -6.0 * s
	else:
		pose.lift_r = maxf(0.0, s)
		pose.lift_l = maxf(0.0, -s)
		var flip := -1.0 if view == "down" else 1.0
		pose.ua_r = flip * 10.0 * s + 4.0
		pose.ua_l = flip * 10.0 * s - 4.0
		pose.fa_r = -14.0
		pose.fa_l = 14.0
		pose.head = 2.0 * s
	return pose


func _blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key: String in a:
		var va: Variant = a[key]
		if va is Vector2:
			out[key] = (va as Vector2).lerp(b[key], t)
		else:
			out[key] = lerpf(float(va), float(b[key]), t)
	return out


## Golpe: antecipação (sobe/recua), estalo (ease-out forte), follow-through e volta.
func _attack_pose(base: Dictionary, t: float) -> Dictionary:
	var pose := base.duplicate()
	var raise := 0.0
	var strike := 0.0
	var antic := 0.36
	var hit := 0.5
	if t < antic:
		raise = _ease_out(t / antic)
	elif t < hit:
		var k := _ease_out_expo((t - antic) / (hit - antic))
		raise = 1.0 - k
		strike = k
	else:
		strike = 1.0 - _ease_in_out((t - hit) / (1.0 - hit))
	if view == "right":
		pose.ua_r = lerpf(float(base.ua_r), -150.0, raise) + 95.0 * strike
		pose.fa_r = -25.0 * raise
		pose.torso = float(base.torso) - 7.0 * raise + 12.0 * strike
		pose.weapon = -20.0 * raise + 35.0 * strike
	else:
		var dir := 1.0 if view == "down" else -1.0  # braço da arma sobe pelo lado de fora
		pose.ua_r = dir * (165.0 * raise - 25.0 * strike)
		pose.fa_r = -dir * 20.0 * raise
		pose.torso = dir * (-4.0 * raise + 5.0 * strike)
		pose.weapon = dir * 20.0 * strike
	pose.hips_y = float(base.hips_y) + 4.0 * strike
	pose.squash = Vector2(1.0 + 0.06 * strike, 1.0 - 0.05 * strike + 0.03 * raise)
	return pose


## Esquiva: agacha, estica na direção (stretch) e aterrissa (squash).
func _dodge_pose(base: Dictionary, t: float) -> Dictionary:
	var pose := base.duplicate()
	var arc := sin(clampf(t, 0.0, 1.0) * PI)
	pose.hips_y = -10.0 * arc
	var tuck := arc
	if view == "right":
		pose.torso = 22.0 * tuck
		pose.th_r = -55.0 * tuck
		pose.th_l = -35.0 * tuck
		pose.sh_r = 70.0 * tuck
		pose.sh_l = 60.0 * tuck
		pose.ua_r = -40.0 * tuck
		pose.ua_l = -55.0 * tuck
	else:
		pose.lift_r = tuck
		pose.lift_l = tuck
		pose.ua_r = 30.0 * tuck * (-1.0 if view == "down" else 1.0)
		pose.ua_l = -30.0 * tuck * (-1.0 if view == "down" else 1.0)
	var land := clampf((t - 0.75) / 0.25, 0.0, 1.0)
	pose.squash = Vector2(1.0 + 0.18 * arc - 0.12 * sin(land * PI), 1.0 - 0.14 * arc + 0.1 * sin(land * PI))
	return pose


func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


func _ease_out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * clampf(x, 0.0, 1.0))


func _ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _apply_pose() -> void:
	var p := _pose
	var sq: Vector2 = p.squash
	_body.scale = Vector2(sq.x * (-1.0 if facing_left and view == "right" else 1.0), sq.y)
	(_bones.hips as Node2D).position.y = -float(_sk.hip_height) * float(_race.legs) * float(_race.height) + float(p.hips_y)
	var torso: Node2D = _bones.torso
	torso.rotation_degrees = float(p.torso)
	torso.scale = Vector2(1.0, float(p.breath))
	(_bones.head as Node2D).rotation_degrees = float(p.head)
	(_bones.skirt as Node2D).rotation_degrees = float(p.skirt)
	for s: String in ["r", "l"]:
		(_bones["upper_arm_" + s] as Node2D).rotation_degrees = float(p["ua_" + s])
		(_bones["forearm_" + s] as Node2D).rotation_degrees = float(p["fa_" + s])
		(_bones["thigh_" + s] as Node2D).rotation_degrees = float(p["th_" + s])
		(_bones["shin_" + s] as Node2D).rotation_degrees = float(p["sh_" + s])
		# vista frontal/traseira: a perna que avança "encurta" (escorço)
		var lift := float(p["lift_" + s])
		(_bones["thigh_" + s] as Node2D).scale.y = 1.0 - 0.2 * lift
		(_bones["shin_" + s] as Node2D).scale.y = 1.0 - 0.12 * lift
	# Cajado fica em pé (compensa a rotação do braço); espada acompanha o golpe.
	var weapon_rot := float(p.weapon)
	if weapon_id == "staff_fire":
		weapon_rot = -(float(p.ua_r) + float(p.fa_r)) - float(p.torso) + float(p.weapon) * 0.6
	(_bones.weapon as Node2D).rotation_degrees = weapon_rot
