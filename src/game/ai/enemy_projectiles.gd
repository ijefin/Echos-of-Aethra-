extends RefCounted
## Projéteis dos monstros (teia/veneno da aranha). Voam em linha reta na altura do peito,
## são desviáveis (miram onde o alvo estava no disparo), param no cenário (camada 1)
## e, ao acertar, aplicam dano + lentidão curta via `on_hit`.
## A lógica não depende de visual: `visual_parent` nulo = modo servidor.

const HEIGHT := 0.75

## (target_id: String, damage: int, slow_factor: float, slow_s: float, source: String) -> void
var on_hit: Callable
var space: PhysicsDirectSpaceState3D
var visual_parent: Node3D
var mat_ball: Material
var mat_splat: Material
var mask := 1
var list: Array[Dictionary] = []
var fired := 0
var blocked := 0
var hits := 0

var _ray := PhysicsRayQueryParameters3D.new()
var _ball := SphereMesh.new()
var _disc := CylinderMesh.new()


func _init() -> void:
	_ball.radius = 0.13
	_ball.height = 0.26
	_ball.radial_segments = 6
	_ball.rings = 3
	_disc.top_radius = 0.42
	_disc.bottom_radius = 0.42
	_disc.height = 0.02
	_disc.radial_segments = 8


## Dispara de `from` (pé do atirador) em direção a `aim` (pé do alvo).
func fire(from: Vector3, aim: Vector3, cfg: Dictionary, source: String, owner_rid: RID) -> void:
	var start := from + Vector3(0, HEIGHT, 0)
	var dir := Vector3(aim.x - from.x, 0, aim.z - from.z)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var speed := float(cfg.get("projectile_speed", 8.5))
	var p := {
		"pos": start + dir * 0.4, "from": start, "vel": dir * speed,
		"life": float(cfg.get("projectile_range", 9.0)) / speed,
		"floor_y": from.y, "damage": int(cfg.get("projectile_damage", 5)),
		"radius": float(cfg.get("projectile_radius", 0.35)),
		"slow": float(cfg.get("slow_factor", 0.55)), "slow_s": float(cfg.get("slow_s", 1.5)),
		"source": source, "owner": owner_rid, "node": null,
	}
	if visual_parent != null:
		var n := Node3D.new()
		visual_parent.add_child(n)
		n.global_position = p.pos
		for i in 3:  # bola + dois respingos atrás (rastro de teia)
			var m := MeshInstance3D.new()
			m.mesh = _ball
			m.material_override = mat_ball
			m.position = -dir * (0.2 * i)
			m.scale = Vector3.ONE * (1.0 - i * 0.3)
			n.add_child(m)
		n.look_at(n.global_position + dir, Vector3.UP)
		p.node = n
	list.append(p)
	fired += 1


func clear() -> void:
	for p: Dictionary in list:
		if p.node != null:
			(p.node as Node).queue_free()
	list.clear()


## Avança todos. `targets` = [{id, pos, node?}]; corpos dos alvos não contam como parede.
func update(delta: float, targets: Array) -> void:
	if list.is_empty():
		return
	var exclude: Array[RID] = []
	for t: Dictionary in targets:
		if t.get("node") is CollisionObject3D:
			exclude.append((t.node as CollisionObject3D).get_rid())
	for i in range(list.size() - 1, -1, -1):
		var p: Dictionary = list[i]
		p.life = float(p.life) - delta
		var vel: Vector3 = p.vel
		if float(p.life) <= 0.0:
			vel.y -= 14.0 * delta  # fim do alcance: a teia cai
			p.vel = vel
		var a: Vector3 = p.from if p.has("from") else p.pos
		p.erase("from")
		var b: Vector3 = p.pos + vel * delta
		var seg := b - a
		var seg_len := seg.length()
		# 1) alvo mais cedo ao longo do segmento
		var hit_k := INF
		var hit_target: Dictionary = {}
		for t: Dictionary in targets:
			var c: Vector3 = (t.pos as Vector3) + Vector3(0, HEIGHT, 0)
			var k := clampf((c - a).dot(seg) / maxf(seg_len * seg_len, 0.0001), 0.0, 1.0)
			var closest := a + seg * k
			var off := c - closest
			if Vector2(off.x, off.z).length() < float(p.radius) + 0.28 and absf(off.y) < 0.8 and k < hit_k:
				hit_k = k
				hit_target = t
		# 2) cenário
		var wall_k := INF
		var wall_pos := Vector3.ZERO
		if space != null and seg_len > 0.0001:
			_ray.from = a
			_ray.to = b
			_ray.collision_mask = mask
			var ex: Array[RID] = exclude.duplicate()
			if p.owner is RID and (p.owner as RID).is_valid():
				ex.append(p.owner)
			_ray.exclude = ex
			var hit := space.intersect_ray(_ray)
			if not hit.is_empty():
				wall_pos = hit.position
				wall_k = (wall_pos - a).length() / seg_len
		if not hit_target.is_empty() and hit_k <= wall_k:
			hits += 1
			if on_hit.is_valid():
				on_hit.call(String(hit_target.id), int(p.damage), float(p.slow), float(p.slow_s), String(p.source))
			_splat(p, a + seg * hit_k, true)
			list.remove_at(i)
			continue
		if wall_k != INF:
			blocked += 1
			_splat(p, wall_pos, false)
			list.remove_at(i)
			continue
		if b.y <= float(p.floor_y) + 0.03:
			_splat(p, Vector3(b.x, float(p.floor_y), b.z), false)
			list.remove_at(i)
			continue
		p.pos = b
		if p.node != null:
			(p.node as Node3D).global_position = b


## Respingo de teia: disco que abre e some (no chão ou na parede/alvo).
func _splat(p: Dictionary, at: Vector3, on_target: bool) -> void:
	if p.node != null:
		(p.node as Node).queue_free()
	if visual_parent == null:
		return
	var m := MeshInstance3D.new()
	m.mesh = _disc
	m.material_override = mat_splat
	visual_parent.add_child(m)
	m.global_position = Vector3(at.x, float(p.floor_y) + (0.05 if on_target else 0.03), at.z)
	m.scale = Vector3(0.3, 1, 0.3)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(1, 1, 1), 0.12)
	tw.tween_interval(0.6)
	tw.tween_property(m, "scale", Vector3(0.05, 1, 0.05), 0.4)
	tw.tween_callback(m.queue_free)
