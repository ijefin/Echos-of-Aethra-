# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Equipamento no modelo (3 vocações): arma some com o slot vazio e volta ao vestir; elmo/chapéu
## e capa/capuz também; o corpo toma o "tint" do peitoral (bare_tint sem peitoral). O mesmo
## Vocations.apply_gear desenha os outros jogadores online (net_play._make_player / evento "gear").
## godot --headless --path . -s res://prototypes/pixel3d/tools/test_gear_look.gd -- --no_save --mute

const Vocations := preload("res://prototypes/pixel3d/vocations.gd")
## Peitoral com tinta própria por vocação (items.json "tint").
const TINTED_CHEST := {"mage": "mist_mantle", "warrior": "lair_cuirass", "archer": "wolfhide_jerkin"}

var demo: Node
var a
var fails := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	print("%s gear: %s" % ["PASS" if cond else "FAIL", what])
	if cond:
		passes += 1
	else:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


func _load(cls: String) -> void:
	if demo != null:
		demo.queue_free()
		await process_frame
	Engine.set_meta("aethra_class", cls)
	demo = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	for i in 4:
		await process_frame


func _body_tint(v) -> Color:
	var mats: Array = v.gear_mats.get("body", [])
	return (mats[0] as ShaderMaterial).get_shader_parameter("tint") if not mats.is_empty() else Color(-1, -1, -1)


func _col(arr: Array) -> Color:
	return Color(float(arr[0]), float(arr[1]), float(arr[2]))


func run() -> void:
	for cls: String in ["mage", "warrior", "archer"]:
		await _vocation(cls)
	demo.queue_free()
	await process_frame
	print("GEAR_LOOK: %d PASS, %d FAIL" % [passes, fails])
	quit(0 if fails == 0 else 1)


func _vocation(cls: String) -> void:
	await _load(cls)
	var v = demo._voc
	var eq: Dictionary = a.inventory.equipped
	var weapon := String(eq.get("weapon", ""))
	var head := String(eq.get("head", ""))
	var chest := String(eq.get("chest", ""))
	check(not weapon.is_empty() and v.gear_visible("weapon"), "%s: começa com a arma (%s) no modelo" % [cls, weapon])
	check(not head.is_empty() and v.gear_visible("head"), "%s: começa com %s na cabeça" % [cls, head])
	check(not chest.is_empty() and v.gear_visible("chest"), "%s: começa com a capa do peitoral (%s)" % [cls, chest])
	# arma: some com o slot vazio e volta ao vestir
	check(a.unequip_item("weapon") == "" and not a.inventory.equipped.has("weapon"), "%s: desequipou a arma" % cls)
	check(not v.gear_visible("weapon"), "%s: arma some do modelo com o slot vazio" % cls)
	check(a.equip_item(weapon) == "" and v.gear_visible("weapon"), "%s: arma volta ao equipar" % cls)
	# cabeça
	a.unequip_item("head")
	check(not v.gear_visible("head"), "%s: sem item na cabeça o elmo/chapéu/capuz some" % cls)
	a.equip_item(head)
	check(v.gear_visible("head"), "%s: cabeça volta ao equipar %s" % [cls, head])
	# peito: capa some e o corpo fica com a tinta nua
	var bare := _col(v.cfg.gear.bare_tint)
	a.unequip_item("chest")
	check(not v.gear_visible("chest") and _body_tint(v).is_equal_approx(bare), "%s: sem peitoral a capa some e o corpo fica %s" % [cls, _body_tint(v)])
	var tinted := String(TINTED_CHEST[cls])
	a.inventory.give([tinted])
	check(a.equip_item(tinted) == "" and v.gear_visible("chest"), "%s: veste %s (capa volta)" % [cls, tinted])
	var want := _col(a.inventory.item(tinted).tint)
	check(_body_tint(v).is_equal_approx(want), "%s: corpo toma o tint de %s (%s)" % [cls, tinted, _body_tint(v)])
	# outro jogador (mesmo caminho do online): modelo montado por Vocations e apply_gear do snapshot
	var other = Vocations.new()
	other.setup(demo, cls)
	var holder := Node3D.new()
	demo._vp.add_child(holder)
	var keep_anim: AnimationPlayer = demo._anim
	var keep_staff = demo._p.get("staff")
	other.build_model(holder)
	demo._anim = keep_anim
	demo._p.staff = keep_staff
	other.apply_gear({}, a.inventory.item)
	check(not other.gear_visible("weapon") and not other.gear_visible("head") and not other.gear_visible("chest"),
		"%s (outro jogador): sem equipamento não mostra arma, cabeça nem capa" % cls)
	other.apply_gear({"weapon": weapon, "head": head, "chest": chest}, a.inventory.item)
	check(other.gear_visible("weapon") and other.gear_visible("head") and other.gear_visible("chest"),
		"%s (outro jogador): evento gear com arma/cabeça/peito redesenha tudo" % cls)
	holder.queue_free()
