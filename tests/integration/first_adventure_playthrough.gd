extends SceneTree
## Graphical playthrough through real projectiles, collisions and interaction handlers.
## Run with -- --no_save. All screenshots and progress are isolated from player saves.
var demo: Node
var adventure
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print("%s %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1

func wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func shot(name: String) -> void:
	await wait_seconds(0.4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://production/qa/evidence/" + name + ".png")

func stand_near(target: Vector3, distance := 3.0) -> void:
	var space: PhysicsDirectSpaceState3D = demo._player.get_world_3d().direct_space_state
	for i in 16:
		var angle := i * TAU / 16.0
		var at := target + Vector3(cos(angle), 0, sin(angle)) * distance
		var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.9, 0), target + Vector3(0, 0.9, 0), 1)
		if space.intersect_ray(query).is_empty():
			demo._player.global_position = at
			demo._player.velocity = Vector3.ZERO
			await physics_frame
			return
	demo._player.global_position = target + Vector3(0, 0, distance)
	await physics_frame

func kill_enemy(a: Dictionary) -> void:
	await stand_near((a.body as Node3D).position)
	for attempt in 8:
		if a.dead:
			break
		demo._attack_at((a.body as Node3D).position)
		await wait_seconds(0.65)
	check(a.dead, "projectiles defeat " + String(a.id))

func fire_torch(index: int) -> void:
	var p: Vector3 = adventure.world.ROOM + adventure.world.TORCHES[index]
	await stand_near(p, 2.6)
	demo._attack_at(p)
	await wait_seconds(0.65)

func run() -> void:
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	adventure = demo._adventure
	adventure._persist = false
	demo._px = 1.0 / 20.0
	demo._fit()
	await wait_seconds(0.3)
	check(adventure.state.level == 1, "new game starts at level one")
	demo._start_blink()
	check(demo._blink_t < 0, "blink input locked before level two")
	adventure.interact()
	check(adventure.state.stage == "active", "NPC accepts quest through interaction")
	for i in 6:
		await kill_enemy(adventure.enemies.actors[i])
	check(adventure.state.level == 2 and adventure.state.xp == 8, "six enemies grant eighteen XP")
	await shot("pixel3d-adventure-combat")
	adventure.warp(adventure.world.ENTRANCE, false)
	adventure.interact()
	check(adventure.in_cave and is_equal_approx(demo._player.position.y, -5.0), "entrance leads to upper ledge")
	adventure.interact()
	await wait_seconds(0.9)
	check(absf(demo._player.position.y + 8.0) < 0.12, "gravity lands player in lower chamber")
	await shot("pixel3d-adventure-cave")
	# At melee distance, a telegraphed enemy attack must reduce player health.
	var first: Dictionary = adventure.enemies.actors[6]
	demo._player.global_position = (first.body as Node3D).position + Vector3(0, 0, 0.95)
	adventure._invulnerable = 0.0
	var before: float = adventure.hp
	await wait_seconds(2.0)
	check(adventure.hp < before, "enemy telegraph resolves into real damage")
	demo._start_dodge()
	before = adventure.hp
	adventure._invulnerable = 0
	adventure.take_damage(999)
	check(adventure.hp == before, "dodge protects against damage during its active state")
	await wait_seconds(0.3)
	for i in range(6, adventure.enemies.actors.size()):
		await kill_enemy(adventure.enemies.actors[i])
	check(adventure.state.level == 3 and adventure.state.xp == 2, "cave kills unlock the second skill")
	await fire_torch(0)
	await fire_torch(1)
	check(adventure.state.lit.is_empty(), "wrong projectile torch order resets puzzle")
	for index in [0, 2, 1]:
		await fire_torch(index)
	check(adventure.state.can_open_chest(), "real fire projectiles solve the torch puzzle")
	demo._player.global_position = adventure.world.CHEST + Vector3(0, 0, 1.5)
	adventure.interact()
	check(adventure.state.stage == "claimed" and adventure.inventory.equipped.get("neck") == "ember_amulet", "chest equips real item reward")
	check(adventure.basic_damage() == 13, "pendant applies its spell-power bonus")
	adventure.hud.bag_open = true
	await shot("pixel3d-adventure-reward")
	adventure.hud.bag_open = false
	demo._player.global_position = adventure.world.ASCEND
	demo._blink_cd = 0
	demo._start_blink()
	await wait_seconds(0.5)
	check(absf(demo._player.position.y + 5.0) < 0.15, "Eco returns to upper ledge")
	await shot("pixel3d-adventure-return-ledge")
	adventure.interact()
	check(not adventure.in_cave and demo._player.position.distance_to(adventure.world.NPC) < 2.8, "upper ledge interaction returns directly to quest NPC")
	adventure.interact()
	check(adventure.state.stage == "complete", "NPC completes recovered-item quest")
	await shot("pixel3d-adventure-complete")
	for a: Dictionary in adventure.enemies.actors:
		if not a.cave and not a.dead:
			await stand_near((a.body as Node3D).position, 2.5)
			adventure.cast_ring()
			check(a.dead and adventure.ring_cd > 0, "unlocked ring skill damages nearby enemies")
			var cooldown: float = adventure.ring_cd
			adventure.cast_ring()
			check(adventure.ring_cd == cooldown, "ring cooldown prevents immediate reuse")
			break
	var progress: Dictionary = adventure.state.snapshot()
	adventure._invulnerable = 0
	adventure.take_damage(999)
	check(adventure.hp == adventure.state.max_hp() and adventure.state.snapshot() == progress, "defeat restores health without losing XP or reward")
	adventure.save_path = "res://production/qa/evidence/first-adventure-save-fixture.json"
	adventure._persist = true
	adventure._save()
	adventure._persist = false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(adventure.save_path))
	var restored := preload("res://src/game/first_adventure_state.gd").new(adventure.config)
	restored.restore(data)
	check(restored.snapshot() == adventure.state.snapshot(), "save file restores XP, unlocks, quest and reward in an isolated slot")
	print("PLAYTHROUGH %s" % ("OK" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
