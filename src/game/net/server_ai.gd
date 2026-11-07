extends RefCounted
## IA real dos monstros no servidor dedicado: a mesma `ai/enemy_director.gd` do jogo,
## rodando num World3D headless montado com a colisão exportada
## (net/data/collision_surface.json → StaticBody3D: camada 1 cenário, camada 4 água)
## e um CharacterBody3D por monstro (camada 8, igual ao cliente).
##
## ServerWorld continua dono das regras (vida, XP, recompensa); este adaptador só liga:
##   targets_provider = jogadores do ServerWorld ({id: str(eid), pos, safe})
##   damage_sink      = ServerWorld.damage_player (autoritativo; esquiva/invulnerável = falhou)
##   slow_sink        = ServerWorld.slow_player (efeito "slow" replicado)
##   on_reset         = monstro voltou para casa → vida cheia

const Director := preload("res://src/game/ai/enemy_director.gd")
const Brain := preload("res://src/game/ai/enemy_brain.gd")

const OBSTACLE_HEIGHT := 3.0
const SAFE_RADIUS := 4.0   # igual ao cliente: perto da Nessa ninguém é atacado

var director := Director.new()
var root: Node3D
var world: RefCounted          # ServerWorld
var actors: Dictionary = {}    # eid do monstro → actor
var npc := Vector3(-14, 0, -25)


## `parent` precisa estar na árvore (tem World3D). `floors` = WorldCollision.load_floors().
func _init(parent: Node3D, floors: Dictionary) -> void:
	root = Node3D.new()
	root.name = "ServerAIWorld"
	parent.add_child(root)
	for f: int in floors:
		_build_obstacles(floors[f], f)
	director.targets_provider = _targets
	director.damage_sink = _damage
	director.slow_sink = _slow
	director.on_reset = _on_reset


func _build_obstacles(col: RefCounted, floor_id: int) -> void:
	var fy: float = col.floor_y
	var solid := StaticBody3D.new()
	solid.name = "Solid%d" % floor_id
	solid.collision_layer = 1
	solid.collision_mask = 0
	var water := StaticBody3D.new()
	water.name = "Water%d" % floor_id
	water.collision_layer = 4
	water.collision_mask = 0
	root.add_child(solid)
	root.add_child(water)
	# chão do andar
	var ground := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	var half: float = col.half
	gb.size = Vector3(half * 2.0 + 20.0, 1.0, half * 2.0 + 20.0)
	ground.shape = gb
	ground.position = Vector3(0, fy - 0.5, 0)
	solid.add_child(ground)
	var masks: Array = col._masks
	for i in col.circles.size():
		var c: Array = col.circles[i]
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = float(c[2])
		cyl.height = OBSTACLE_HEIGHT
		cs.shape = cyl
		cs.position = Vector3(float(c[0]), fy + OBSTACLE_HEIGHT * 0.5, float(c[1]))
		(water if int(masks[0][i]) == 4 else solid).add_child(cs)
	for i in col.boxes.size():
		var b: Array = col.boxes[i]
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(b[2]) * 2.0, OBSTACLE_HEIGHT, float(b[3]) * 2.0)
		cs.shape = box
		# yaw 2D (ângulo do eixo x local no plano XZ) = −rotação em torno de Y
		cs.transform = Transform3D(Basis(Vector3.UP, -float(b[4])), Vector3(float(b[0]), fy + OBSTACLE_HEIGHT * 0.5, float(b[1])))
		(water if int(masks[1][i]) == 4 else solid).add_child(cs)
	for i in col.polys.size():
		var pts: PackedVector2Array = col.polys[i]
		var cs := CollisionShape3D.new()
		var cv := ConvexPolygonShape3D.new()
		var p3 := PackedVector3Array()
		for p: Vector2 in pts:
			p3.append(Vector3(p.x, fy, p.y))
			p3.append(Vector3(p.x, fy + OBSTACLE_HEIGHT, p.y))
		cv.points = p3
		cs.shape = cv
		(water if int(masks[2][i]) == 4 else solid).add_child(cs)


## Registra o monstro `m` (registro do ServerWorld) com o tipo `cfg` (= enemy.<tipo>).
func add_monster(m: Dictionary, cfg: Dictionary) -> void:
	var body := CharacterBody3D.new()
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	body.floor_max_angle = deg_to_rad(46.0)
	body.floor_snap_length = 0.35
	body.collision_layer = 8
	body.collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.3
	cs.shape = cap
	cs.position.y = 0.65
	body.add_child(cs)
	root.add_child(body)
	body.global_position = m.home
	var actor := {"id": String(m.key), "eid": int(m.eid), "kind": String(m.kind), "body": body, "home": m.home,
		"cfg": cfg, "dead": false, "cooldown": 1.0}
	director.add_agent(actor)
	actors[int(m.eid)] = actor


func step(dt: float) -> void:
	director.space = root.get_world_3d().direct_space_state
	director.update(dt)


## Estado do monstro para o snapshot.
func sync_monster(m: Dictionary) -> void:
	var a: Dictionary = actors.get(int(m.eid), {})
	if a.is_empty() or a.dead:
		return
	var body: CharacterBody3D = a.body
	var b: Brain = a.brain
	var p := body.global_position
	m.pos = Vector3(p.x, p.y + b.hop, p.z)
	m.yaw = body.rotation.y
	m.ai_state = b.state
	m.winding = b.state == Brain.WINDUP
	m.attack = b.attack


func on_damaged(m: Dictionary, by: int) -> void:
	var a: Dictionary = actors.get(int(m.eid), {})
	if not a.is_empty() and not a.dead:
		director.alert(a, str(by) if by > 0 else "")


func on_killed(m: Dictionary) -> void:
	var a: Dictionary = actors.get(int(m.eid), {})
	if a.is_empty():
		return
	a.dead = true
	(a.body as CharacterBody3D).collision_layer = 0
	director.reset_agent(a)


func on_respawn(m: Dictionary) -> void:
	var a: Dictionary = actors.get(int(m.eid), {})
	if a.is_empty():
		return
	var body: CharacterBody3D = a.body
	body.global_position = a.home
	body.velocity = Vector3.ZERO
	body.collision_layer = 8
	a.dead = false
	a.cooldown = 1.0
	director.reset_agent(a)


## Projéteis dos monstros em voo (teia da aranha) para o snapshot.
func shots() -> Array[Dictionary]:
	return director.projectiles.list


# ------------------------------------------------------------------ ganchos

func _targets() -> Array:
	var out: Array = []
	for p: Dictionary in world.players.values():
		var pos: Vector3 = p.ms.pos
		var safe := float(p.hp) <= 0.0 or Vector2(pos.x - npc.x, pos.z - npc.z).length() < SAFE_RADIUS
		out.append({"id": str(int(p.eid)), "pos": pos, "safe": safe})
	return out


func _damage(id: String, amount: int, source: String) -> bool:
	return bool(world.damage_player(int(id), amount, source))


func _slow(id: String, factor: float, seconds: float) -> void:
	world.slow_player(int(id), factor, seconds)


func _on_reset(a: Dictionary) -> void:
	var m: Dictionary = world.monsters.get(int(a.eid), {})
	if not m.is_empty():
		m.hp = int(m.max_hp)
