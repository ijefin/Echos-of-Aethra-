# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Alcance do mundo: grade de navegação (0,6 m) feita com as colisões que bloqueiam o
## jogador (camada 1 + margens d'água), BFS a partir do ponto de chegada até cada ponto
## importante (acampamentos, bocas de caverna, regiões, hunts, segredos, marcos).
## Também conta áreas livres de 9×10 m (sem árvore/pedra) na floresta inicial.
## godot --headless --path . -s res://prototypes/pixel3d/tools/test_world_reach.gd -- --no_save --mute

const WorldLayout := preload("res://prototypes/pixel3d/world/world_layout.gd")
const CELL := 0.6
const SNAP := 2.0  # alvo dentro de rocha/objeto: vale a célula livre mais próxima até 2 m


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var t0 := Time.get_ticks_msec()
	var demo: Node = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	if demo._adventure != null:
		demo._adventure._persist = false
	for i in 4:
		await physics_frame
	var build_ms := Time.get_ticks_msec() - t0
	var half: float = demo.HALF
	var n := int(ceil(half * 2.0 / CELL))
	var space: PhysicsDirectSpaceState3D = demo._player.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.28
	shape.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1 | 4
	q.exclude = [demo._player.get_rid()]
	var blocked := PackedByteArray()
	blocked.resize(n * n)
	var t1 := Time.get_ticks_msec()
	for iz in n:
		for ix in n:
			var x := -half + (ix + 0.5) * CELL
			var z := -half + (iz + 0.5) * CELL
			q.transform = Transform3D(Basis(), Vector3(x, 0.8, z))
			blocked[iz * n + ix] = 1 if space.intersect_shape(q, 1).size() > 0 else 0
	var grid_ms := Time.get_ticks_msec() - t1
	# BFS a partir da chegada
	var start_p: Vector3 = demo._player.global_position
	var start := _free_near(blocked, n, half, Vector2(start_p.x, start_p.z))
	var seen := PackedByteArray()
	seen.resize(n * n)
	var queue := PackedInt32Array()
	var reached := 0
	if start >= 0:
		queue.append(start)
		seen[start] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		reached += 1
		var cx := c % n
		var cz := c / n
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + d.x
			var nz := cz + d.y
			if nx < 0 or nz < 0 or nx >= n or nz >= n:
				continue
			var k := nz * n + nx
			if seen[k] == 0 and blocked[k] == 0:
				seen[k] = 1
				queue.append(k)
	var ok := start >= 0
	print("grade %dx%d (%.1f m) montada em %d ms; cena em %d ms; alcançáveis %d células" % [n, n, CELL, grid_ms, build_ms, reached])
	for target: Array in WorldLayout.reach_targets():
		var name: String = target[0]
		var p: Vector2 = target[1]
		var c := _free_near(blocked, n, half, p)
		var pass_ok := c >= 0 and seen[c] == 1
		print("%s %s (%.0f, %.0f)" % ["PASS" if pass_ok else "FAIL", name, p.x, p.y])
		ok = ok and pass_ok
	# áreas abertas 9×10 m na floresta inicial (sem árvore, pedra ou água)
	var wx := int(ceil(9.0 / CELL))
	var wz := int(ceil(10.0 / CELL))
	var sat := PackedInt32Array()
	sat.resize((n + 1) * (n + 1))
	for iz in n:
		for ix in n:
			sat[(iz + 1) * (n + 1) + ix + 1] = blocked[iz * n + ix] + sat[iz * (n + 1) + ix + 1] + sat[(iz + 1) * (n + 1) + ix] - sat[iz * (n + 1) + ix]
	var open := 0
	var lo := int((half - 60.0) / CELL)
	var hi := n - lo
	var iz2 := lo
	while iz2 + wz <= hi:
		var ix2 := lo
		var found_row := false
		while ix2 + wx <= hi:
			var s := sat[(iz2 + wz) * (n + 1) + ix2 + wx] - sat[iz2 * (n + 1) + ix2 + wx] - sat[(iz2 + wz) * (n + 1) + ix2] + sat[iz2 * (n + 1) + ix2]
			if s == 0:
				open += 1
				ix2 += wx
				found_row = true
			else:
				ix2 += 1
		iz2 += wz if found_row else 1
	print("áreas livres 9x10 m na floresta inicial (sem sobrepor): %d" % open)
	print("árvores: %d" % demo._tree_spots.size())
	ok = ok and open >= 6
	print("WORLD_REACH: ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)


func _free_near(blocked: PackedByteArray, n: int, half: float, p: Vector2) -> int:
	var cx := int((p.x + half) / CELL)
	var cz := int((p.y + half) / CELL)
	var r := int(ceil(SNAP / CELL))
	var best := -1
	var best_d := INF
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= n or z >= n or blocked[z * n + x] == 1:
				continue
			var d := float(dx * dx + dz * dz)
			if d < best_d:
				best_d = d
				best = z * n + x
	return best
