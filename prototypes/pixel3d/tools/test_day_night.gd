# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Ciclo dia/noite: duração de cada fase (dia 20 min, noite 7 min, amanhecer/entardecer 1,5 min
## dentro do dia) e continuidade (sem saltos de luz/cor entre frames a 60 fps).
## godot --headless --path . -s res://prototypes/pixel3d/tools/test_day_night.gd
const SkyCycle := preload("res://prototypes/pixel3d/pixel3d_sky.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	var sky = SkyCycle.new()
	sky.build(world, sun, Environment.new(), RandomNumberGenerator.new(), 60.0, [])
	var ok := _cycle(sky, 20.0, 7.0)
	ok = _cycle(sky, 2.0, 1.0) and ok
	print("DAY_NIGHT: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _cycle(sky, day_min: float, night_min: float) -> bool:
	sky.set_cycle_minutes(day_min, night_min)
	sky.hour = 6.0
	sky.update(0.0)
	var dt := 1.0 / 60.0
	var spent := {"dawn": 0.0, "day": 0.0, "dusk": 0.0, "night": 0.0}
	var jump := 0.0
	var prev := _sample(sky)
	for i in int(round((day_min + night_min) * 60.0 / dt)):
		var ph: String = sky.phase()
		sky.update(dt)
		spent[ph] = float(spent[ph]) + dt
		var cur := _sample(sky)
		for k in cur.size():
			jump = maxf(jump, absf(cur[k] - prev[k]))
		prev = cur
	var edge := day_min * 60.0 * 1.5 / 20.0
	var want := {"dawn": edge, "day": day_min * 60.0 - 2.0 * edge, "dusk": edge, "night": night_min * 60.0}
	var ok := jump < 0.02 and absf(fposmod(float(sky.hour) - 6.0 + 12.0, 24.0) - 12.0) < 0.05
	for k: String in want:
		var good := absf(float(spent[k]) - float(want[k])) < 0.5
		print("  %s/%s min — %s: %.1f s (esperado %.1f) %s" % [day_min, night_min, k, spent[k], want[k], "" if good else "<<"])
		ok = ok and good
	print("  maior salto por frame = %.5f, hora final = %.2f" % [jump, sky.hour])
	return ok


func _sample(sky) -> Array[float]:
	var c: Color = sky.env.ambient_light_color
	return [float(sky.night), float(sky.sun.light_energy), float(sky.moon.light_energy), float(sky.env.ambient_light_energy), c.r, c.g, c.b]
