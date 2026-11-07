extends RefCounted
## Passo de movimento determinístico do jogador: o MESMO código roda no servidor
## (autoridade) e no cliente (predição + reconciliação). Sem nós, sem física do Godot.
##
## Estado: {pos: Vector3, dodge_t: float (-1 = sem esquiva), dodge_cd: float, dodge_dir: Vector2,
##          yaw: float}


static func new_state(pos: Vector3) -> Dictionary:
	return {"pos": pos, "dodge_t": -1.0, "dodge_cd": 0.0, "dodge_dir": Vector2(0, 1), "yaw": 0.0}


## Aplica um comando (dir normalizada ≤ 1, flags) por `dt` segundos. Muta e devolve `s`.
static func step(s: Dictionary, dir: Vector2, flags: int, dt: float, col: RefCounted, mv: Dictionary, radius: float) -> Dictionary:
	var d := dir.limit_length(1.0)
	s.dodge_cd = maxf(0.0, float(s.dodge_cd) - dt)
	if (flags & 1) and float(s.dodge_t) < 0.0 and float(s.dodge_cd) <= 0.0:
		s.dodge_t = 0.0
		s.dodge_cd = float(mv.dodge_cooldown)
		var yaw := float(s.yaw)
		s.dodge_dir = d.normalized() if d.length() > 0.2 else Vector2(-sin(yaw), -cos(yaw))
	var vel: Vector2
	if float(s.dodge_t) >= 0.0:
		var k := float(s.dodge_t) / float(mv.dodge_time)
		vel = (s.dodge_dir as Vector2) * float(mv.dodge_speed) * (1.0 - k * 0.55)
		s.dodge_t = float(s.dodge_t) + dt
		if float(s.dodge_t) >= float(mv.dodge_time):
			s.dodge_t = -1.0
	else:
		vel = d * float(mv.speed)
	var p3: Vector3 = s.pos
	var p := Vector2(p3.x, p3.z)
	var delta := vel * dt
	var sub := maxi(1, ceili(delta.length() / 0.2))   # sem atravessar troncos finos
	for _i in sub:
		p = col.resolve(p + delta / float(sub), radius)
	if vel.length() > 0.05:
		s.yaw = atan2(-vel.x, -vel.y)
	s.pos = Vector3(p.x, col.ground_y(p.x, p.y), p.y)
	return s


static func copy(s: Dictionary) -> Dictionary:
	return s.duplicate()
