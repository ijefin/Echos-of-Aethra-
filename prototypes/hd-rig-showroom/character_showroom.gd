class_name CharacterShowroom
extends Node2D
## Provador de personagens (Fase 1 da revisão HD): Humano, Elfo e Anão lado a lado,
## controlados juntos, para validar o rig de peças, a animação procedural e a troca de
## equipamento antes de levar ao jogo. Renderiza em resolução nativa com MSAA.
##
## Rodar: godot --path . res://src/tools/character_showroom.tscn
## Teclas: WASD/setas correr · Espaço esquivar · J ou clique atacar · H dano
##         1/2/3 roupa · Q/E arma · F10 sair
## Linha de comando (depois de `--`): --demo (alterna estados sozinho)

const RIG_PATH := "res://assets/data/char_rig.json"
const RACE_ORDER: Array[String] = ["human", "elf", "dwarf"]
const OUTFIT_ORDER: Array[String] = ["none", "robe_fire", "armor_iron"]
const WEAPON_ORDER: Array[String] = ["staff_fire", "sword_iron", "none"]
const REF_HEIGHT := 720.0
const SPACING := 230.0

var _data: Dictionary
var _rigs: Array[CharacterRig] = []
var _stage: Node2D
var _label: Label
var _outfit_i := 1
var _weapon_i := 0
var _demo := false
var _demo_t := 0.0
var _demo_step := -1


func _ready() -> void:
	get_viewport().msaa_2d = Viewport.MSAA_4X
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_data = JsonData.load_dict(RIG_PATH)
	_demo = "--demo" in OS.get_cmdline_user_args()
	_stage = Node2D.new()
	add_child(_stage)
	for i in RACE_ORDER.size():
		var rig := CharacterRig.new()
		rig.position = Vector2((i - 1) * SPACING, 0)
		_stage.add_child(rig)
		rig.setup(_data, RACE_ORDER[i], OUTFIT_ORDER[_outfit_i], WEAPON_ORDER[_weapon_i])
		_rigs.append(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	_label = Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	font.font_weight = 600
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.04))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(20, 14)
	ui.add_child(_label)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var size := get_viewport_rect().size
	var s := size.y / REF_HEIGHT * 1.45
	_stage.scale = Vector2(s, s)
	_stage.position = Vector2(size.x / 2.0, size.y * 0.8)
	queue_redraw()


func _draw() -> void:
	# Fundo: céu de floresta ao entardecer → chão, com feixe de luz e sombras de contato.
	var size := get_viewport_rect().size
	var horizon := size.y * 0.62
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([Color(0.13, 0.2, 0.17), Color(0.2, 0.26, 0.2), Color(0.32, 0.42, 0.27), Color(0.27, 0.38, 0.24)]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(size.x, horizon), size, Vector2(0, size.y)]),
		PackedColorArray([Color(0.3, 0.45, 0.24), Color(0.33, 0.47, 0.25), Color(0.2, 0.32, 0.18), Color(0.18, 0.3, 0.16)]))
	draw_polygon(PackedVector2Array([Vector2(size.x * 0.18, 0), Vector2(size.x * 0.34, 0), Vector2(size.x * 0.62, size.y), Vector2(size.x * 0.38, size.y)]),
		PackedColorArray([Color(1, 0.92, 0.65, 0.12), Color(1, 0.92, 0.65, 0.12), Color(1, 0.92, 0.65, 0.0), Color(1, 0.92, 0.65, 0.0)]))
	for rig in _rigs:
		var p := _stage.to_global(rig.position)
		var r := 34.0 * _stage.scale.x
		draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, r, Color(0.05, 0.08, 0.06, 0.45))
		draw_set_transform(Vector2.ZERO)


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		dir = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if _demo:
		dir = _run_demo(delta)
	for rig in _rigs:
		rig.set_motion(dir)
	var r := _rigs[0]
	_label.text = "Provador — rig de peças HD (placeholder vetorial)\nRoupa: %s  ·  Arma: %s  ·  Vista: %s%s  ·  Estado: %s\n1/2/3 roupa · Q/E arma · WASD correr · Espaço esquivar · J/clique atacar · H dano" % [
		_data.outfits[r.outfit_id].name, _data.weapons[r.weapon_id].name, r.view,
		" (esquerda)" if r.facing_left and r.view == "right" else "", r.state]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_all("attack")
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3:
			_outfit_i = event.physical_keycode - KEY_1
			_reequip()
		KEY_Q:
			_weapon_i = (_weapon_i + WEAPON_ORDER.size() - 1) % WEAPON_ORDER.size()
			_reequip()
		KEY_E:
			_weapon_i = (_weapon_i + 1) % WEAPON_ORDER.size()
			_reequip()
		KEY_J:
			_all("attack")
		KEY_SPACE:
			for rig in _rigs:
				rig.dodge(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down"))
		KEY_H:
			_all("hurt")
		KEY_F10:
			get_tree().quit()


func _all(action: String) -> void:
	for rig in _rigs:
		rig.call(action)


func _reequip() -> void:
	for i in _rigs.size():
		_rigs[i].equip(RACE_ORDER[i], OUTFIT_ORDER[_outfit_i], WEAPON_ORDER[_weapon_i])


## Demo automática: percorre vistas, corrida, ataque, esquiva e trocas de equipamento.
func _run_demo(delta: float) -> Vector2:
	_demo_t += delta
	var steps := [
		[0.0, Vector2.ZERO, ""], [1.2, Vector2.ZERO, "attack"], [2.4, Vector2.RIGHT, ""], [3.6, Vector2.RIGHT, "attack"],
		[4.6, Vector2.DOWN, ""], [5.6, Vector2.ZERO, "outfit2"], [6.4, Vector2.ZERO, "attack"], [7.4, Vector2.UP, ""],
		[8.4, Vector2.LEFT, "dodge"], [9.4, Vector2.ZERO, "outfit0"], [10.4, Vector2.RIGHT, "weapon"], [11.6, Vector2.ZERO, "attack"],
	]
	var current: Vector2 = Vector2.ZERO
	for i in steps.size():
		if _demo_t >= float(steps[i][0]):
			current = steps[i][1]
			if i > _demo_step:
				_demo_step = i
				match String(steps[i][2]):
					"attack":
						_all("attack")
					"dodge":
						for rig in _rigs:
							rig.dodge(steps[i][1])
					"outfit2":
						_outfit_i = 2
						_weapon_i = 1
						_reequip()
					"outfit0":
						_outfit_i = 0
						_weapon_i = 2
						_reequip()
					"weapon":
						_outfit_i = 1
						_weapon_i = 0
						_reequip()
	if _demo_t > 13.0:
		_demo_t = 0.0
		_demo_step = -1
	return current
