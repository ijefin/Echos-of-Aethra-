extends SceneTree
## Colisão exportada do mundo (net/data/collision_surface.json) usada pelo servidor:
##   godot --headless --path . -s res://tests/unit/net/collision_export_test.gd
## - o jogador do servidor (PlayerMotion) não atravessa árvore, rocha nem serra;
## - água bloqueia o andar mas não o tiro;
## - todos os pontos principais (WorldLayout.reach_targets) continuam alcançáveis a pé
##   a partir da chegada, e os pontos dentro da serra continuam bloqueados.
## O JSON é um artefato versionado (fixture); regenerar com net/tools/export_collision.gd.

const N := "res://prototypes/pixel3d/net/"
const Collision := preload(N + "world_collision.gd")
const Motion := preload(N + "player_motion.gd")
const NetConfig := preload(N + "net_config.gd")
const WorldLayout := preload("res://prototypes/pixel3d/world/world_layout.gd")
const PATH := N + "data/collision_surface.json"
const CELL := 0.5
const SNAP := 2.0

var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var cfg := NetConfig.load_config()
	var floors: Dictionary = Collision.load_floors(PATH, float(cfg.world_half))
	var col: RefCounted = floors[0]
	var radius := float(cfg.player_radius)
	check(col.half == 100.0, "colisão: mapa ±100 (%.0f)" % col.half)
	check(col.circles.size() > 1000 and col.boxes.size() > 50, "colisão: superfície exportada (%d círculos, %d caixas, %d polígonos)" % [col.circles.size(), col.boxes.size(), col.polys.size()])
	check(floors.has(-1) and (floors[-1] as RefCounted).count() > 50 and is_equal_approx((floors[-1] as RefCounted).floor_y, -8.0),
		"colisão: gruta como andar -1 (%d obstáculos)" % ((floors[-1] as RefCounted).count() if floors.has(-1) else 0))
	_test_no_tunneling(col, cfg, radius)
	_test_water(col)
	_test_reach(col, radius, Vector2(cfg.spawn[0], cfg.spawn[2]))
	print("COLLISION_EXPORT: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


## Corre direto contra 3 obstáculos sólidos (tronco, maior rocha, caixa) e confere que
## o centro nunca entra no raio do obstáculo.
func _test_no_tunneling(col: RefCounted, cfg: Dictionary, radius: float) -> void:
	var picks: Array = []   # [nome, centro, raio efetivo]
	var tree := -1
	var rock := -1
	for i in col.circles.size():
		var c: Array = col.circles[i]
		if int(col._masks[0][i]) != 1 or absf(float(c[0])) > 90 or absf(float(c[1])) > 55:
			continue
		var r := float(c[2])
		if tree < 0 and r < 0.6:
			tree = i
		if r > 1.0 and r < 3.0 and (rock < 0 or r > float(col.circles[rock][2])):
			rock = i
	if tree >= 0:
		picks.append(["tronco", Vector2(col.circles[tree][0], col.circles[tree][1]), float(col.circles[tree][2])])
	if rock >= 0:
		picks.append(["rocha", Vector2(col.circles[rock][0], col.circles[rock][1]), float(col.circles[rock][2])])
	check(picks.size() == 2, "colisão: achou tronco e rocha para o teste")
	for pk: Array in picks:
		var center: Vector2 = pk[1]
		var ok := true
		for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
			var dir := Vector2(cos(ang), sin(ang))
			var start: Vector2 = col.resolve(center - dir * (float(pk[2]) + 3.0), radius)
			var s := Motion.new_state(Vector3(start.x, 0, start.y))
			for _i in 60:   # 3 s a 20 Hz empurrando contra o obstáculo
				Motion.step(s, (center - Vector2(s.pos.x, s.pos.z)).normalized(), 0, 0.05, col, cfg.move, radius)
				if Vector2(s.pos.x, s.pos.z).distance_to(center) < float(pk[2]) + radius - 0.02:
					ok = false
		check(ok, "colisão: jogador do servidor não atravessa %s (r %.2f em %.1f, %.1f)" % [pk[0], pk[2], center.x, center.y])
	# esquiva (11 m/s) contra o tronco: sem túnel mesmo no passo rápido
	if tree >= 0:
		var c2 := Vector2(col.circles[tree][0], col.circles[tree][1])
		var start2: Vector2 = col.resolve(c2 + Vector2(-2.5, 0), radius)
		var s2 := Motion.new_state(Vector3(start2.x, 0, start2.y))
		var through := false
		for _i in 10:
			Motion.step(s2, (c2 - start2).normalized(), 1, 0.05, col, cfg.move, radius)
			if s2.pos.x > c2.x + 0.2 and absf(s2.pos.z - c2.y) < 0.2:
				through = true
		check(not through, "colisão: esquiva não atravessa tronco")
	# serra: do vale para o contraforte, 20 s andando para dentro da rocha
	var s3 := Motion.new_state(Vector3(-30, 0, -80))
	for _i in 400:
		Motion.step(s3, Vector2(0, 1), 0, 0.05, col, cfg.move, radius)
	check(s3.pos.z < -70.0, "colisão: serra segura quem sai do vale para o sul (z final %.1f)" % s3.pos.z)


func _test_water(col: RefCounted) -> void:
	var wi := -1
	for i in col.boxes.size():
		if int(col._masks[1][i]) == 4:
			wi = i
			break
	if wi < 0:
		for i in col.circles.size():
			if int(col._masks[0][i]) == 4:
				wi = -2 - i
				break
	check(wi != -1, "colisão: água exportada com máscara 4")
	if wi == -1:
		return
	var c: Vector2 = Vector2(col.boxes[wi][0], col.boxes[wi][1]) if wi >= 0 else Vector2(col.circles[-2 - wi][0], col.circles[-2 - wi][1])
	check(col.blocked(c, 0.28), "colisão: água bloqueia o andar")
	var a := c + Vector2(-0.3, -0.3)
	var b := c + Vector2(0.3, 0.3)
	var solid_near: bool = not col.segment_clear(a, b, 0.0, Collision.SOLID)
	check(solid_near or col.segment_clear(a, b, 0.0), "colisão: água não bloqueia tiro")
	check(not col.segment_clear(a, b, 0.0, Collision.SOLID | Collision.WATER), "colisão: máscara de água bloqueia quando pedida")


## BFS numa grade de 0,5 m com o mesmo raio do servidor.
func _test_reach(col: RefCounted, radius: float, spawn: Vector2) -> void:
	var t0 := Time.get_ticks_msec()
	var half: float = col.half
	var n := int(ceil(half * 2.0 / CELL))
	var blocked := PackedByteArray()
	blocked.resize(n * n)
	for iz in n:
		for ix in n:
			blocked[iz * n + ix] = 1 if col.blocked(Vector2(-half + (ix + 0.5) * CELL, -half + (iz + 0.5) * CELL), radius) else 0
	var start := _free_near(blocked, n, half, spawn)
	check(start >= 0, "alcance: chegada livre (%.1f, %.1f)" % [spawn.x, spawn.y])
	var seen := PackedByteArray()
	seen.resize(n * n)
	var queue := PackedInt32Array()
	if start >= 0:
		queue.append(start)
		seen[start] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
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
	print("alcance: grade %dx%d em %d ms, %d células alcançáveis" % [n, n, Time.get_ticks_msec() - t0, queue.size()])
	for target: Array in WorldLayout.reach_targets():
		var p: Vector2 = target[1]
		var c := _free_near(blocked, n, half, p)
		check(c >= 0 and seen[c] == 1, "alcance: %s (%.0f, %.0f)" % [target[0], p.x, p.y])
	for target: Array in WorldLayout.blocked_targets():
		var p: Vector2 = target[1]
		var c := _free_near(blocked, n, half, p)
		check(c < 0 or seen[c] == 0, "alcance: %s bloqueado (%.0f, %.0f)" % [target[0], p.x, p.y])


func _free_near(blocked: PackedByteArray, n: int, half: float, p: Vector2) -> int:
	var best := -1
	var best_d := SNAP + 0.001
	var cx := int((p.x + half) / CELL)
	var cz := int((p.y + half) / CELL)
	var rr := int(ceil(SNAP / CELL))
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= n or z >= n or blocked[z * n + x] == 1:
				continue
			var d := Vector2(dx, dz).length() * CELL
			if d < best_d:
				best_d = d
				best = z * n + x
	return best
