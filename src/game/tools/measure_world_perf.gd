extends SceneTree
## Mede tempo de frame (sem vsync) em pontos de cada região, com e sem os pedaços
## (world_chunks) escondendo o que está fora da tela. Precisa de janela (render real):
## godot --path . --windowed --resolution 1280x720 -s res://src/game/tools/measure_world_perf.gd -- --no_save --mute

const SPOTS := [["Floresta (chegada)", Vector3(0, 0, 0)], ["Serra / Vale do Vigia", Vector3(-20, 0, -82)],
	["Bosque Antigo", Vector3(80, 0, 10)], ["Charco das Brumas", Vector3(10, 0, 80)], ["Ruínas / Posto Velho", Vector3(-80, 0, 18)]]
const WARM := 40
const FRAMES := 180


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0 := Time.get_ticks_msec()
	var demo: Node = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	if demo._adventure != null:
		demo._adventure._persist = false
	print("PERF cena montada em %d ms; pedaços=%d; árvores=%d; rochas da serra=%d" % [Time.get_ticks_msec() - t0, demo._chunks.count(), demo._tree_spots.size(), demo._props.mountain_rocks])
	for culling: bool in [true, false]:
		demo.chunk_culling = culling
		for spot: Array in SPOTS:
			var at: Vector3 = spot[1]
			demo._player.global_position = at
			demo._cam_focus = at
			for i in WARM:
				await process_frame
			var start := Time.get_ticks_usec()
			var worst := 0.0
			var last := start
			for i in FRAMES:
				await process_frame
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
			var avg := (Time.get_ticks_usec() - start) / 1000.0 / FRAMES
			print("PERF %-24s pedaços=%s  média %.2f ms (%.0f fps)  pior %.1f ms  objetos=%d  draws=%d  visíveis=%d" % [spot[0], "on " if culling else "off", avg, 1000.0 / avg, worst,
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), demo._chunks.visible_count])
	quit()
