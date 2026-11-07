extends SceneTree
## Conteúdo jogável: as 4 missões de ponta a ponta (aceitar, kill/reach/collect/talk,
## concluir, recompensa), save/restore no meio, segredos únicos, equipamento que muda
## dano/armadura/vida/mana, nível das caçadas escalando monstros, save antigo.
## godot --headless --path . -s res://src/game/tools/test_quests.gd -- --no_save --mute

var demo: Node
var a
var r := {}


func _initialize() -> void:
	call_deferred("run")


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _load(cls: String, lazy_now := true) -> void:
	if demo != null:
		demo.queue_free()
		await process_frame
	Engine.set_meta("aethra_class", cls)
	demo = (load("res://src/game/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	a.state.stage = "complete"  # missão da Nessa já feita
	if lazy_now:
		a.enemies.spawn_lazy(true)  # Garra-Velha nasce quando o jogador chega ao vale
	await _frames(4)


func _go(p: Vector3) -> void:
	a.warp(p, false)


func _talk(npc: String) -> void:
	_go(a.world.npcs[npc].pos + Vector3(0, 0, 1.5))
	a._talk_time = 0.0
	a.interact()


## Mata (pelo combate de verdade: enemies.hit) n monstros do tipo/caçada.
func _kill(kind: String, hunt: String, n: int) -> int:
	var killed := 0
	for e: Dictionary in a.enemies.actors:
		if killed >= n:
			break
		if String(e.kind) == kind and String(e.get("hunt", "")) == hunt and not e.dead:
			a._invulnerable = 99.0
			a.enemies.hit(e.body, 99999)
			killed += 1
	return killed


func _active_step(id: String) -> int:
	return int(a.quests.active[id].step) if a.quests.active.has(id) else -1


## Simula sair e voltar ao jogo: grava, monta uma cena nova e restaura do JSON.
func _reload() -> void:
	a.state.content = a.content_snapshot()
	var json := JSON.stringify(a.state.snapshot())
	var cls: String = demo._voc.id
	await _load(cls)
	a.state.restore(JSON.parse_string(json))
	a.quests.restore(a.state.content)
	a._restore_content(a.state.content)
	a._refresh_stats()
	a._sync_secret_marks()


func run() -> void:
	await _load("mage", false)
	var q = a.quests
	var before: bool = a.enemies.find("field%d" % (a.config.field_enemies.size() - 1)).is_empty()
	_go(Vector3(10, 0, -82))
	await _frames(2)
	r["elite_nasce_ao_chegar_no_vale"] = before and not a.enemies.find("field%d" % (a.config.field_enemies.size() - 1)).is_empty()
	# ---- nível das caçadas escala vida/dano/XP
	var frog_base := int(a.config.enemy.frog.hp)
	var charco_frog: Dictionary = {}
	var elite: Dictionary = {}
	for e: Dictionary in a.enemies.actors:
		if String(e.get("hunt", "")) == "charco" and int(e.level) == 3:
			charco_frog = e
		if String(e.kind) == "wolf_elite":
			elite = e
	r["nivel_escala_vida_xp"] = int(charco_frog.cfg.hp) > frog_base and int(charco_frog.cfg.xp) > int(a.config.enemy.frog.xp) and int(charco_frog.cfg.damage) > int(a.config.enemy.frog.damage)
	r["elite_existe_e_forte"] = not elite.is_empty() and int(elite.cfg.hp) >= int(a.config.enemy.wolf.hp) * 4 and float(elite.cfg.charge_width) > float(a.config.enemy.wolf.charge_width) and float(elite.cfg.leap_radius) > 2.0
	print("  sapo nív 3: vida %d (base %d), xp %d · Garra-Velha: vida %d, investida %d, salto %d" % [int(charco_frog.cfg.hp), frog_base, int(charco_frog.cfg.xp), int(elite.cfg.hp), int(elite.cfg.charge_damage), int(elite.cfg.leap_damage)])

	# ---- Q1 Coaxar nas Brumas (Sálvia): nível baixo recusa com história; depois aceita
	a.state.level = 1
	_talk("salvia")
	r["q1_nivel_baixo_nao_aceita"] = not q.active.has("coaxar")
	a.state.level = 2
	_talk("salvia")
	r["q1_aceita"] = _active_step("coaxar") == 0 and a.objective_title() == "COAXAR NAS BRUMAS"
	var xp0: int = a.state.xp + a.state.level * 1000
	_kill("frog", "charco", 3)
	r["q1_progresso"] = int(q.active.coaxar.count) == 3 and q.progress_text("coaxar").ends_with("3 de 5")
	# sapo de outra caçada não conta
	_kill("frog", "floresta", 1)
	r["q1_outra_cacada_nao_conta"] = int(q.active.coaxar.count) == 3
	# ---- save/restore no meio da caçada
	await _reload()
	q = a.quests
	r["save_meio_preserva"] = int(q.active.coaxar.count) == 3 and _active_step("coaxar") == 0
	_kill("frog", "charco", 2)
	r["q1_kill_concluido"] = _active_step("coaxar") == 1
	var hp_pots := int(a.potions.hp)
	var lvl_xp: int = a.state.level * 1000 + a.state.xp
	_talk("salvia")
	r["q1_concluida_recompensa"] = "coaxar" in q.done and int(a.potions.hp) == hp_pots + 3 and a.state.level * 1000 + a.state.xp > lvl_xp
	print("  objetivo depois de Q1: ", a.objective().replace("\n", " | "))
	r["q1_aponta_rook"] = a.objective().begins_with("Sargento Rook")

	# ---- Q2 Fios na Estrada Velha (Rook): reach → kill → collect no mundo → talk
	a.state.level = 3
	_talk("rook")
	r["q2_aceita"] = _active_step("fios_estrada") == 0
	_go(Vector3(-80, 0, 40))
	await _frames(3)
	r["q2_reach"] = _active_step("fios_estrada") == 1
	_kill("spider", "estrada_velha", 4)
	r["q2_kill"] = _active_step("fios_estrada") == 2
	r["q2_insignia_aparece"] = q.pickups().size() == 1
	_go(Vector3(-82.5, 0, 47.0))
	await _frames(2)
	a.interact()
	r["q2_collect_mundo"] = _active_step("fios_estrada") == 3 and int(q.items.get("patrol_badge", 0)) == 1
	var dmg0: int = a.basic_damage()
	_talk("rook")
	r["q2_arma_aumenta_dano"] = "fios_estrada" in q.done and a.inventory.equipped.weapon == "sentinel_staff" and a.gear("spell_power") == 3.0 and a.basic_damage() >= dmg0 + 3 and not q.items.has("patrol_badge")
	print("  dano do mago: %d → %d (Cajado de Sentinela)" % [dmg0, a.basic_damage()])

	# ---- Q3 Presas do Covil (Rook → Bran): collect de lobo + kill, entrega a outro NPC
	a.state.level = 4
	_talk("rook")
	r["q3_aceita"] = _active_step("presas_covil") == 0
	r["q3_bran_marca_nada_ainda"] = q.marker("bran", a.state.level) == ""
	_kill("wolf", "covil_bosque", 2)
	r["q3_presas_caem"] = int(q.items.get("wolf_fang", 0)) == 2 and _active_step("presas_covil") == 1
	_kill("spider", "covil_bosque", 3)
	r["q3_entrega_em_bran"] = _active_step("presas_covil") == 2 and q.marker("bran", a.state.level) == "?"
	var armor0: float = a.armor_ratio()
	var mana0: int = a.max_mana()
	a._invulnerable = 0.0
	a.hp = 200.0
	a.take_damage(20, "teste")
	var hurt0: float = 200.0 - a.hp
	_talk("bran")
	a._invulnerable = 0.0
	a.hp = 200.0
	a.take_damage(20, "teste")
	var hurt1: float = 200.0 - a.hp
	r["q3_armadura_reduz_dano"] = "presas_covil" in q.done and a.armor_ratio() > armor0 and hurt1 < hurt0 and a.gear("max_resource") == 10.0 and a.max_mana() >= mana0 + 10
	print("  armadura %.0f%% → %.0f%%, golpe de 20: %d → %d, mana máx %d → %d" % [armor0 * 100, a.armor_ratio() * 100, hurt0, hurt1, mana0, a.max_mana()])

	# ---- Q4 O Vigia do Vale (Bran): elite; o mesmo abate solta o colmilho
	a.state.level = 6
	a._talk_time = 0.0
	_talk("bran")
	r["q4_aceita"] = _active_step("vigia_vale") == 0
	_kill("wolf_elite", "vale_vigia", 1)
	r["q4_elite_colmilho"] = _active_step("vigia_vale") == 2 and int(q.items.get("elder_fang", 0)) == 1
	var hp_max0: int = a.state.max_hp()
	var dmg1: int = a.basic_damage()
	_talk("bran")
	r["q4_colar_vida_dano"] = "vigia_vale" in q.done and a.inventory.equipped.neck == "elder_fang_charm" and a.gear("max_hp") == 20.0 and a.state.max_hp() >= hp_max0 + 20 and a.basic_damage() > dmg1

	# ---- segredos: recompensa única, salva, não repete
	var hp_max1: int = a.state.max_hp()
	var s_pos: Vector3 = a._secret_pos("segredo_serra_fenda")
	_go(s_pos + Vector3(1.2, 0, 0))
	await _frames(2)
	r["segredo_prompt"] = a.prompt() == "E — examinar"
	a.interact()
	r["segredo_vida_permanente"] = a.state.max_hp() == hp_max1 + 15 and "segredo_serra_fenda" in q.secrets
	r["segredo_nao_repete_na_hora"] = not a.claim_secret("segredo_serra_fenda") and a.state.max_hp() == hp_max1 + 15 and a.prompt() != "E — examinar"
	var mpots := int(a.potions.mana)
	r["segredo_pocoes"] = a.claim_secret("segredo_bosque_raizes") and int(a.potions.mana) == mpots + 3
	var mana1: int = a.max_mana()
	r["segredo_mana_permanente"] = a.claim_secret("segredo_charco_juncos") and a.max_mana() == mana1 + 15
	r["segredo_grevas"] = a.claim_secret("segredo_ruinas_cripta") and a.inventory.equipped.get("feet", "") == "crypt_greaves"
	var final_hp: int = a.state.max_hp()
	var final_mana: int = a.max_mana()
	var final_dmg: int = a.basic_damage()
	var final_armor: float = a.armor_ratio()
	await _reload()
	q = a.quests
	r["save_tudo_volta"] = q.done.size() == 4 and q.secrets.size() == 4 and a.state.max_hp() == final_hp and a.max_mana() == final_mana and a.basic_damage() == final_dmg and is_equal_approx(a.armor_ratio(), final_armor)
	r["segredo_nao_repete_depois_do_save"] = not a.claim_secret("segredo_ruinas_cripta") and a.inventory.items.count("crypt_greaves") == 0
	r["segredo_marco_brilha"] = (a.demo._props.secrets[0].node as Node3D).has_node("glow")
	r["tudo_concluido_sem_texto"] = a.objective() == "Concluída."

	# ---- save antigo (sem "content") continua abrindo
	a.state.restore({"version": 1, "level": 3, "xp": 2, "stage": "complete"})
	a.quests.restore(a.state.content)
	r["save_antigo"] = a.quests.done.is_empty() and a.quests.secrets.is_empty() and a.state.level == 3

	# ---- recompensas por vocação mexem no dano das três
	for cls: String in ["warrior", "archer"]:
		await _load(cls)
		var d0: int = a.basic_damage()
		a._apply_reward(a.quests.quest("fios_estrada").reward, "teste")
		var w: String = a.inventory.equipped.weapon
		r["arma_" + cls] = a.basic_damage() > d0 and w == String(a.quests.quest("fios_estrada").reward.items[cls])
		var ar0: float = a.armor_ratio()
		a._apply_reward(a.quests.quest("presas_covil").reward, "teste")
		r["armadura_" + cls] = a.armor_ratio() > ar0
		print("  %s: dano %d → %d, armadura %.0f%% → %.0f%%" % [cls, d0, a.basic_damage(), ar0 * 100, a.armor_ratio() * 100])

	var ok := true
	for k: String in r:
		print("  %s: %s" % [k, "OK" if r[k] else "FALHOU"])
		ok = ok and bool(r[k])
	print("QUESTS: ", "OK" if ok else "FALHOU", " (%d casos)" % r.size())
	quit(0 if ok else 1)
