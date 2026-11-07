extends SceneTree
## Core skill Luz: custo, duração, recarga, renovação, efeitos para a rede.
## godot --headless --path . -s res://src/game/tools/test_core_light.gd

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	var a = demo._adventure
	a._persist = false
	for i in 5:
		await physics_frame
	var core = a.core
	var s: Dictionary = core.skill("light")
	var r := {}
	a.mana = 100.0
	r["lanca"] = core.cast("light") and absf(a.mana - (100.0 - float(s.mana))) < 0.01 and core.remaining("light") > 0.0
	r["recarga_bloqueia"] = not core.cast("light")
	r["luz_acesa"] = core._orb.visible and core.effects().has("light")
	core.update(float(s.cooldown) + 0.1)
	a.mana = 100.0
	var before: float = core.remaining("light")
	r["renova"] = core.cast("light") and core.remaining("light") > before
	a.mana = float(s.mana) - 1.0
	core.update(float(s.cooldown) + 0.1)
	r["sem_mana"] = not core.cast("light")
	core.update(float(s.duration) + 1.0)
	r["expira"] = core.remaining("light") == 0.0 and not core._orb.visible and core.effects().is_empty()
	core.set_effects({"light": 42.0})
	r["rede_aplica"] = core._orb.visible and absf(core.remaining("light") - 42.0) < 0.01
	var ok := true
	for k: String in r:
		print("%s: %s" % [k, "OK" if r[k] else "FALHOU"])
		ok = ok and r[k]
	print("CORE_LIGHT: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
