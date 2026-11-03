extends SceneTree
## Boundary and sequence tests for the playable first quest; no rendering or save IO.
const State := preload("res://prototypes/pixel3d/first_adventure_state.gd")
const CONFIG := {"xp_first": 10, "xp_step": 8, "max_level": 20, "player_hp": 60, "hp_per_level": 8, "blink_level": 2, "ring_level": 3, "torch_order": [0, 2, 1], "cave_guardians": 4, "enemy": {"frog": {"xp": 3}, "spider": {"xp": 3}}}
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	var s := State.new(CONFIG)
	check(s.level == 1 and not s.has_skill("blink") and not s.has_skill("ring"), "skills start locked")
	s.add_xp(9)
	check(s.level == 1 and s.xp == 9, "nine XP does not level")
	s.add_xp(1)
	check(s.level == 2 and s.xp == 0 and s.has_skill("blink"), "exactly ten XP unlocks blink")
	s.add_xp(20)
	check(s.level == 3 and s.xp == 2 and s.has_skill("ring"), "overflow XP preserved across levels")
	var q := State.new(CONFIG)
	check(not q.ignite(0) and not q.claim_chest(), "quest cannot be bypassed before acceptance")
	check(q.accept_quest() and not q.accept_quest(), "quest accepted once")
	for i in 4:
		check(q.record_kill("field%d" % i, "frog", false), "frog kill gives XP")
	check(q.level == 2 and q.xp == 2, "four frogs yield twelve XP")
	check(not q.record_kill("field0", "frog", false) and q.xp == 2, "same death cannot pay twice")
	q.ignite(0)
	check(not q.ignite(1) and q.lit.is_empty(), "wrong torch resets sequence")
	for index in [0, 2, 1]:
		check(q.ignite(index), "correct torch accepted")
	check(not q.claim_chest(), "guardians also protect chest")
	for i in 4:
		q.record_kill("cave%d" % i, "spider", true)
	check(q.can_open_chest() and q.claim_chest(), "solved puzzle and guardians unlock reward")
	check(not q.claim_chest() and q.stage == "claimed", "reward cannot be duplicated")
	check(q.finish_quest() and not q.finish_quest(), "NPC turn-in completes once")
	var restored := State.new(CONFIG)
	restored.restore(JSON.parse_string(JSON.stringify(q.snapshot())))
	check(restored.stage == "complete" and restored.level == q.level and restored.xp == q.xp, "progress survives serialization")
	check(restored.cave_kills.size() == 4 and restored.lit == [0, 2, 1], "puzzle and guardian state restored")
	var malformed := State.new(CONFIG)
	malformed.restore({"level": -20, "xp": -9, "stage": "unknown", "lit": [2, 7]})
	check(malformed.level == 1 and malformed.xp == 0 and malformed.stage == "available" and malformed.lit.is_empty(), "invalid save values are bounded")
	print("first_adventure: %s" % ("OK" if failures == 0 else "%d failures" % failures))
	quit(0 if failures == 0 else 1)
