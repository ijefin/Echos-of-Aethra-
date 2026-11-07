extends SceneTree
## Conteúdo autoritativo no servidor: missões (quests.gd) avançadas por eventos do servidor,
## interação validada por distância, recompensas (XP/poções/item/bônus) concedidas uma vez,
## segredos únicos mesmo após sair e voltar, equipamento validado mudando o dano autoritativo.
##   godot --headless --path . -s res://tests/unit/net/server_content_test.gd
## Sem física (IA mínima); fixtures = dados do protótipo (quests.json, items.json, classes.json).

const N := "res://src/game/net/"
const World := preload(N + "server_world.gd")
const Collision := preload(N + "world_collision.gd")
const NetConfig := preload(N + "net_config.gd")
const Store := preload(N + "json_store.gd")
const Quests := preload("res://src/game/quests.gd")
const TUNING := "res://src/game/data/first_adventure.json"
const CLASSES := "res://src/game/data/classes.json"

var failures := 0
var passes := 0
var w: RefCounted
var qdata: Dictionary


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var cfg := NetConfig.load_config(func(_k: String) -> String: return "")
	(cfg.monsters as Dictionary)["aggro_m"] = 0.0   # monstros parados: o teste é de conteúdo
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUNING))
	var floors: Dictionary = Collision.load_floors(N + "data/collision_surface.json", 100.0)
	w = World.new(cfg, tuning, floors[0], 7, Store.load_dict(CLASSES), {}, floors)
	qdata = Quests.load_data()
	test_talk_requires_range_and_level()
	test_first_quest_completes_with_server_kills()
	test_secret_rewards_once_across_relogin()
	test_reach_step_advances_on_server_position()
	test_quest_weapon_changes_authoritative_damage()
	test_equip_is_validated_and_persisted()
	test_nessa_accept_unlocks_torches()
	print("SERVER_CONTENT: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


# ------------------------------------------------------------------ utilidades

func npc_pos(id: String) -> Vector3:
	var a: Array = qdata.npcs[id].pos
	return Vector3(float(a[0]), 0, float(a[1]))


func put(eid: int, at: Vector3) -> void:
	w.players[eid].ms.pos = at
	w.players[eid].floor = World.floor_of(at.y)


func content_events(eid: int) -> Array:
	var out: Array = []
	for e: Dictionary in w.events:
		if String(e.get("type", "")) == "content" and int(e.to) == eid:
			out.append(e)
	return out


func last_content(eid: int) -> Dictionary:
	var l := content_events(eid)
	return l[l.size() - 1] if not l.is_empty() else {}


func kill_hunt(eid: int, kind: String, hunt: String, n: int) -> int:
	var done := 0
	for m: Dictionary in w.monsters.values():
		if done >= n:
			break
		if String(m.kind) == kind and String(m.hunt) == hunt and String(m.state) != "dead":
			w._damage_monster(m, 99999, eid)
			done += 1
	return done


func revive_all() -> void:
	for m: Dictionary in w.monsters.values():
		if String(m.state) == "dead":
			m.respawn_at = 0.0
			w._monster_respawn_tick(m)


# ------------------------------------------------------------------ testes

func test_talk_requires_range_and_level() -> void:
	var eid: int = w.add_player("t1", "T1", {}, "archer")
	put(eid, npc_pos("salvia") + Vector3(30, 0, 0))
	check(w.player_action(eid, {"act": "interact", "target": "npc:salvia"}) == "range", "interagir: longe do NPC → recusado (range)")
	put(eid, npc_pos("salvia") + Vector3(1.5, 0, 0))
	w.events.clear()
	check(w.player_action(eid, {"act": "interact", "target": "npc:salvia"}) == "", "interagir: perto do NPC → aceito")
	check(String(last_content(eid).get("event", "")) == "weak", "nível 1: Sálvia ainda acha fraco (min_level 2)")
	check(w.player_action(eid, {"act": "interact", "target": "npc:ninguem"}) == "target", "interagir: NPC desconhecido → recusado")
	check(w.player_action(eid, {"act": "interact", "target": "secret:segredo_charco_juncos"}) == "range", "segredo longe → recusado")
	w.remove_player(eid)


func test_first_quest_completes_with_server_kills() -> void:
	var eid: int = w.add_player("t2", "T2", {}, "archer")
	var p: Dictionary = w.players[eid]
	p.state.level = 2
	put(eid, npc_pos("salvia") + Vector3(1.5, 0, 0))
	w.events.clear()
	check(w.player_action(eid, {"act": "interact", "target": "npc:salvia"}) == "" and String(last_content(eid).event) == "accept",
		"missão 1: aceita com a Sálvia no servidor")
	check(p.quests.active.has("coaxar"), "missão 1: ativa no estado do servidor")
	kill_hunt(eid, "frog", "floresta", 2)   # sapos de outra caçada não contam
	check(int(p.quests.active.coaxar.count) == 0, "missão 1: abates fora do Charco não contam")
	w.events.clear()
	check(kill_hunt(eid, "frog", "charco", 5) == 5, "missão 1: 5 sapos do Charco abatidos pelo servidor")
	var evs := content_events(eid)
	check(evs.size() == 5 and String((evs[4].events as Array)[0].type) == "step", "missão 1: 5 eventos de progresso, o último fecha o passo")
	check(String(p.quests.step("coaxar").get("type", "")) == "talk", "missão 1: agora é voltar à Sálvia")
	var lv: int = p.state.level
	var xp: int = p.state.xp
	var pots := int(p.potions.hp)
	w.events.clear()
	w.player_action(eid, {"act": "interact", "target": "npc:salvia"})
	var ev := last_content(eid)
	check(String(ev.get("event", "")) == "complete" and "coaxar" in p.quests.done, "missão 1: concluída no servidor")
	check(int(p.potions.hp) == pots + 3, "recompensa: +3 poções de vida (%d → %d)" % [pots, int(p.potions.hp)])
	var total_before: int = xp
	for l in range(1, lv):
		total_before += int(w.tuning.xp_first) + (l - 1) * int(w.tuning.xp_step)
	var total_after: int = int(p.state.xp)
	for l in range(1, int(p.state.level)):
		total_after += int(w.tuning.xp_first) + (l - 1) * int(w.tuning.xp_step)
	check(total_after - total_before == 25, "recompensa: +25 de XP no servidor (%d → %d)" % [total_before, total_after])
	var snap: Dictionary = w.snapshot_for(eid)
	check(int(snap.me.xp) == int(p.state.xp) and int(snap.me.level) == int(p.state.level) and int(snap.me.pot_hp) == int(p.potions.hp),
		"snapshot leva o XP/poções da recompensa (não sobrescreve mais)")
	check((ev.get("state", {}) as Dictionary).has("quests") and "coaxar" in (ev.state.quests.done as Array), "evento leva o diário atualizado para o cliente")
	w.events.clear()
	w.player_action(eid, {"act": "interact", "target": "npc:salvia"})
	check(int(p.potions.hp) == pots + 3, "recompensa da missão 1 não se repete")
	var saved: Dictionary = w.remove_player(eid)
	var eid2: int = w.add_player("t2", "T2", saved, "")
	check("coaxar" in w.players[eid2].quests.done, "persistência: missão concluída volta do save do servidor")
	w.remove_player(eid2)
	revive_all()


func test_secret_rewards_once_across_relogin() -> void:
	var eid: int = w.add_player("t3", "T3", {}, "mage")
	var p: Dictionary = w.players[eid]
	var sp: Vector2 = w.content.secret_pos["segredo_charco_juncos"]
	var mm0: int = w.combat.max_mana(p.state.level, p)
	put(eid, Vector3(sp.x + 1.0, 0, sp.y))
	w.events.clear()
	check(w.player_action(eid, {"act": "interact", "target": "secret:segredo_charco_juncos"}) == "", "segredo: revelado perto do marco")
	check(int(w.combat.max_mana(p.state.level, p)) == mm0 + 15, "segredo: +15 de mana máxima permanente no servidor")
	check(w.player_action(eid, {"act": "interact", "target": "secret:segredo_charco_juncos"}) == "claimed", "segredo: segunda vez → recusado (claimed)")
	var saved: Dictionary = w.remove_player(eid)
	var eid2: int = w.add_player("t3", "T3", saved, "")
	var p2: Dictionary = w.players[eid2]
	put(eid2, Vector3(sp.x + 1.0, 0, sp.y))
	check(w.player_action(eid2, {"act": "interact", "target": "secret:segredo_charco_juncos"}) == "claimed", "segredo: após sair e voltar continua uma vez só")
	check(int(w.combat.max_mana(p2.state.level, p2)) == mm0 + 15 and int(w.snapshot_for(eid2).me.max_mana) == mm0 + 15, "segredo: bônus permanente volta do save (e vai no snapshot)")
	w.remove_player(eid2)


func test_reach_step_advances_on_server_position() -> void:
	var eid: int = w.add_player("t4", "T4", {}, "warrior")
	var p: Dictionary = w.players[eid]
	p.quests.done.append("coaxar")
	p.quests.active["fios_estrada"] = {"step": 0, "count": 0}
	w.events.clear()
	for i in 5:
		w.step(0.05)
	check(int(p.quests.active.fios_estrada.step) == 0, "chegue a: longe, nada muda")
	put(eid, Vector3(-80, 0, 41))
	for i in 6:
		w.step(0.05)
	check(int(p.quests.active.fios_estrada.step) == 1 and not content_events(eid).is_empty(), "chegue a: servidor avança o passo pela posição dele")
	w.remove_player(eid)


func test_quest_weapon_changes_authoritative_damage() -> void:
	var eid: int = w.add_player("t5", "T5", {}, "archer")
	var p: Dictionary = w.players[eid]
	p.state.level = 3
	p.quests.done.append("coaxar")
	p.quests.active["fios_estrada"] = {"step": 3, "count": 0}
	var dmg0: int = w.combat.fire_damage(p)
	put(eid, npc_pos("rook") + Vector3(1.0, 0, 0))
	w.events.clear()
	check(w.player_action(eid, {"act": "interact", "target": "npc:rook"}) == "", "missão 2: entrega ao Rook")
	var ev := last_content(eid)
	check(String(ev.reward.item) == "yew_bow" and String(p.inv.equipped.get("weapon", "")) == "yew_bow", "recompensa: Arco de Teixo vestido no servidor")
	var dmg1: int = w.combat.fire_damage(p)
	check(dmg1 > dmg0, "arma da missão aumenta o dano autoritativo (%d → %d)" % [dmg0, dmg1])
	# o projétil criado pelo servidor leva o dano novo
	p.cd.clear()
	p.mana = 999.0
	var me: Vector3 = p.ms.pos
	w.projectiles.clear()
	check(w.player_action(eid, {"act": "fire", "x": me.x + 3.0, "z": me.z}) == "", "ataque com o arco novo aceito")
	var shot_dmg := -1
	for j: Dictionary in w.projectiles.values():
		shot_dmg = int(j.dmg)
	check(shot_dmg == dmg1, "flecha do servidor sai com o dano do arco novo (%d)" % shot_dmg)
	check(w.player_action(eid, {"act": "equip", "item": "hunting_bow"}) == "", "equipar: volta ao arco inicial")
	var dmg_base: int = w.combat.fire_damage(p)
	check(dmg_base < dmg1, "arco inicial: dano autoritativo menor (%d < %d)" % [dmg_base, dmg1])
	check((ev.reward.gains as Array).has("+%d de dano" % (dmg1 - dmg_base)), "resumo da recompensa lista o ganho de dano do arco (%s)" % str(ev.reward.gains))
	check(w.player_action(eid, {"act": "equip", "item": "yew_bow"}) == "" and int(w.combat.fire_damage(p)) == dmg1, "vestir de novo o Arco de Teixo")
	w.remove_player(eid)


func test_equip_is_validated_and_persisted() -> void:
	var eid: int = w.add_player("t6", "T6", {}, "archer")
	var p: Dictionary = w.players[eid]
	check(w.player_action(eid, {"act": "equip", "item": "guard_sword"}) == "equip", "equipar: item fora da bolsa → recusado")
	p.inv.give(["guard_sword", "crypt_greaves"])
	p.quests.owned.append("crypt_greaves")   # como se viesse de recompensa (refeito no login)
	check(w.player_action(eid, {"act": "equip", "item": "guard_sword"}) == "equip", "equipar: espada de guerreiro na arqueira → recusado (vocação)")
	var a0: float = p.armor
	var hp0: int = p.state.max_hp()
	check(w.player_action(eid, {"act": "equip", "item": "crypt_greaves"}) == "", "equipar: grevas da cripta aceitas")
	check(float(p.armor) > a0 + 0.07 and int(p.state.max_hp()) == hp0 + 10, "grevas: armadura (+8%%) e vida (+10) no servidor (%.2f → %.2f)" % [a0, float(p.armor)])
	p.hp = float(p.state.max_hp())
	var before := float(p.hp)
	p.invuln_until = 0.0
	p.ms.dodge_t = -1.0
	w.damage_player(eid, 40, "teste")
	var took := before - float(p.hp)
	check(is_equal_approx(took, float(maxi(1, roundi(40.0 * (1.0 - float(p.armor)))))), "dano recebido usa a armadura do equipamento (%d)" % int(took))
	var saved: Dictionary = w.remove_player(eid)
	saved.erase("hp")
	var eid2: int = w.add_player("t6", "T6", saved, "")
	check(String(w.players[eid2].inv.equipped.get("feet", "")) == "crypt_greaves" and float(w.players[eid2].armor) > a0 + 0.07, "persistência: grevas voltam vestidas (e com a armadura) do save do servidor")
	w.remove_player(eid2)


func test_nessa_accept_unlocks_torches() -> void:
	var eid: int = w.add_player("t7", "T7", {}, "mage")
	var p: Dictionary = w.players[eid]
	put(eid, World.NPC + Vector3(0, 0, 1.5))
	w.events.clear()
	check(w.player_action(eid, {"act": "interact", "target": "nessa"}) == "" and String(last_content(eid).result) == "accept", "Nessa: missão das brasas aceita no servidor")
	check(String(p.state.stage) == "active", "Nessa: estágio ativo (tochas liberadas)")
	check(w.player_action(eid, {"act": "interact", "target": "chest"}) == "floor", "baú: só na gruta")
	w.remove_player(eid)
