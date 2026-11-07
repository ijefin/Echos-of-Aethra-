extends SceneTree
## Testes das regras puras da rede (sem sockets). Rodar:
##   godot --headless --path . -s res://tests/unit/net/net_rules_test.gd
## Saída: uma linha PASS/FAIL por verificação e "NET_RULES: OK" no fim.

const N := "res://src/game/net/"
const Protocol := preload(N + "net_protocol.gd")
const NetConfig := preload(N + "net_config.gd")
const Limiter := preload(N + "rate_limiter.gd")
const TextRules := preload(N + "text_rules.gd")
const Collision := preload(N + "world_collision.gd")
const Motion := preload(N + "player_motion.gd")
const Validator := preload(N + "move_validator.gd")
const Accounts := preload(N + "account_store.gd")
const Friends := preload(N + "friends_service.gd")
const Sessions := preload(N + "session_registry.gd")
const Store := preload(N + "json_store.gd")
const Interest := preload(N + "interest_grid.gd")
const World := preload(N + "server_world.gd")

const MOVE := {"speed": 4.2, "dodge_speed": 11.0, "dodge_time": 0.24, "dodge_cooldown": 0.8}
const TEST_DIR := "user://net-rules-test"

var failures := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


## Gerador de bytes determinístico para sal/token (testes não dependem de aleatório).
func _fake_bytes() -> Callable:
	var state := {"n": 0}
	return func(n: int) -> PackedByteArray:
		var out := PackedByteArray()
		for i in n:
			state.n = int(state.n) + 1
			out.append(int(state.n) % 256)
		return out


func _initialize() -> void:
	test_config_env()
	test_protocol_roundtrip()
	test_rate_limiter()
	test_text_rules()
	test_collision_and_motion()
	test_move_validator()
	test_accounts()
	test_sessions_reconnect()
	test_friends_presence()
	test_json_store()
	test_interest()
	test_world_authority()
	print("NET_RULES: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FAIL", passes, failures])
	quit(1 if failures else 0)


func test_config_env() -> void:
	var env := {"AETHRA_PORT": "9001", "AETHRA_DATA_DIR": "/data", "AETHRA_MAX_PLAYERS": "abc", "AETHRA_ADMIN_TOKEN": "x"}
	var cfg := NetConfig.apply_env({"port": 7777, "max_players": 16}, func(k: String) -> String: return String(env.get(k, "")))
	check(int(cfg.port) == 9001 and String(cfg.data_dir) == "/data", "config: AETHRA_PORT/AETHRA_DATA_DIR sobrescrevem o JSON")
	check(int(cfg.max_players) == 16, "config: valor inválido no ambiente é ignorado")
	check(String(cfg.admin_token) == "x", "config: token de admin vem só do ambiente")


func test_protocol_roundtrip() -> void:
	var cmds := [{"seq": 41, "dir": Vector2(1, 0), "flags": 0}, {"seq": 42, "dir": Vector2(0.6, -0.8), "flags": 1}]
	var dec := Protocol.decode_input(Protocol.encode_input(cmds))
	check(dec.size() == 2 and int(dec[1].seq) == 42 and int(dec[1].flags) == 1 and (dec[1].dir as Vector2).distance_to(Vector2(0.6, -0.8)) < 0.02, "protocolo: input ida e volta")
	var bad := Protocol.encode_input(cmds)
	bad.append(0)
	check(Protocol.decode_input(bad).is_empty(), "protocolo: input com tamanho errado é rejeitado")
	var me := {"pos": Vector3(1.5, 0, -2.25), "dodge_t": -1.0, "dodge_cd": 0.3, "dodge_dir": Vector2(0, 1), "hp": 60, "max_hp": 60,
		"mana": 33, "max_mana": 40, "level": 2, "xp": 5, "xp_req": 18, "pot_hp": 3, "pot_mana": 2, "effects": Protocol.effect_bits(["light"])}
	var ents := [{"id": 101, "kind": Protocol.KIND_MONSTER, "sub": 1, "pos": Vector3(-20.13, 0, -27.5), "yaw": 1.0, "hp": 10, "max_hp": 24, "effects": 0}]
	var snap := Protocol.decode_snapshot(Protocol.encode_snapshot(77, 41, me, ents))
	check(int(snap.tick) == 77 and int(snap.ack) == 41 and (snap.me.pos as Vector3).is_equal_approx(Vector3(1.5, 0, -2.25)), "protocolo: snapshot cabeçalho e posição própria exata")
	check((snap.entities[0].pos as Vector3).distance_to(Vector3(-20.13, 0, -27.5)) < 0.011 and int(snap.entities[0].hp) == 10, "protocolo: entidade quantizada em cm")
	check("light" in Protocol.effect_names(int(snap.me.effects)), "protocolo: efeitos genéricos (luz) sobrevivem")
	check(Protocol.packet_type(PackedByteArray([99, 1])) == -1, "protocolo: versão diferente é rejeitada")
	check(Protocol.decode_control(PackedByteArray([1, 2, 255, 255, 255, 255, 0, 0])).is_empty(), "protocolo: payload de controle lixo vira {}")


func test_rate_limiter() -> void:
	var rl := Limiter.new({"chat": {"rate": 1.0, "burst": 3.0}}, 5.0, 1.0)
	var ok := 0
	for i in 5:
		if rl.allow(7, "chat", 0.0):
			ok += 1
	check(ok == 3, "rate limit: rajada limitada a burst=3")
	check(rl.allow(7, "chat", 1.01), "rate limit: ficha volta com o tempo")
	check(rl.allow(8, "chat", 0.0), "rate limit: peers independentes")
	check(not rl.should_kick(7, 1.01), "rate limit: 2 excessos não derrubam")
	rl.penalize(7, 10.0, 1.0)
	check(rl.should_kick(7, 1.0), "rate limit: abuso acumulado derruba")
	check(not rl.should_kick(7, 20.0), "rate limit: placar de abuso decai")


func test_text_rules() -> void:
	check(TextRules.clean_name("  João  da  Silva ") == "João da Silva", "texto: nome com acento e espaços normalizados")
	check(TextRules.clean_name("ab") == "" and TextRules.clean_name("<script>") == "" and TextRules.clean_name("_x_y") == "", "texto: nomes inválidos recusados")
	var c := TextRules.clean_chat("oi" + String.chr(7) + String.chr(0x202E) + "tudo" + String.chr(10) + "bem   ?", 160)
	check(c == "oi tudo bem ?", "texto: chat sem controles/bidi")
	check(TextRules.clean_chat("a".repeat(500), 160).length() == 160, "texto: chat cortado no limite")


func test_collision_and_motion() -> void:
	var col := Collision.new({"half": 60.0, "circles": [[2.0, 0.0, 0.5]], "boxes": [[0.0, 5.0, 1.0, 1.0, 0.0]]})
	check(col.blocked(Vector2(2.2, 0), 0.35) and not col.blocked(Vector2(4, 0), 0.35), "colisão: círculo bloqueia")
	check(col.blocked(Vector2(0.5, 5.2), 0.35), "colisão: caixa bloqueia")
	check(not col.segment_clear(Vector2(0, 0), Vector2(4, 0)) and col.segment_clear(Vector2(0, 2), Vector2(4, 2)), "colisão: linha de visão")
	var s := Motion.new_state(Vector3.ZERO)
	for i in 20:
		Motion.step(s, Vector2(1, 0), 0, 0.05, col, MOVE, 0.35)
	var p: Vector3 = s.pos
	check(p.x < 2.0 - 0.5 - 0.35 + 0.02, "movimento: não atravessa o tronco")
	var free := Motion.new_state(Vector3(0, 0, -10))
	for i in 20:
		Motion.step(free, Vector2(0, -1), 0, 0.05, col, MOVE, 0.35)
	check(absf((free.pos as Vector3).z - (-10.0 - 4.2)) < 0.01, "movimento: 1 s a 4,2 m/s anda 4,2 m")
	var edge := Motion.new_state(Vector3(59.5, 0, 0))
	Motion.step(edge, Vector2(1, 0), 0, 0.05, col, MOVE, 0.35)
	check((edge.pos as Vector3).x <= 60.0 - 0.35 + 0.0001, "movimento: preso dentro do mapa")
	var a := Motion.new_state(Vector3(0, 0, -20))
	var b := Motion.new_state(Vector3(0, 0, -20))
	for i in 10:
		Motion.step(a, Vector2(0.3, 0.7), 1 if i == 2 else 0, 0.05, col, MOVE, 0.35)
		Motion.step(b, Vector2(0.3, 0.7), 1 if i == 2 else 0, 0.05, col, MOVE, 0.35)
	check((a.pos as Vector3).is_equal_approx(b.pos), "movimento: determinístico (predição = servidor)")


func test_move_validator() -> void:
	var v := Validator.new({"input_rate": 20, "move_budget_max_s": 0.25, "max_queued_inputs": 8, "move": MOVE})
	var cmds: Array = []
	for i in range(1, 61):
		cmds.append({"seq": i, "dir": Vector2(1, 0), "flags": 0})
	v.receive(cmds)   # cliente trapaceiro manda 3 s de comandos de uma vez
	var taken := v.take(0.05).size()
	check(taken == 1, "validação: 1 tick de servidor só simula 1 comando")
	check(v.queue.size() <= 8, "validação: fila limitada")
	var total := taken
	for i in 19:
		total += v.take(0.05).size()
	check(total <= 20, "validação: speedhack por excesso de comandos não acelera (≤ tempo real)")
	var dup := v.receive([{"seq": 1, "dir": Vector2.ZERO, "flags": 0}])
	check(dup == 0, "validação: seq antigo/duplicado ignorado")
	check(not v.check_step(Vector3.ZERO, Vector3(5, 0, 0)), "validação: anti-teleporte acusa 5 m em 1 comando")
	check(v.check_step(Vector3.ZERO, Vector3(0.21, 0, 0)), "validação: passo normal aceito")
	var v2 := Validator.new({"input_rate": 20, "move_budget_max_s": 0.25, "move": MOVE})
	v2.take(0.05)
	v2.take(0.05)   # 2 ticks sem pacote (jitter) acumulam orçamento
	v2.receive([{"seq": 1, "dir": Vector2(1, 0), "flags": 0}, {"seq": 2, "dir": Vector2(1, 0), "flags": 0}, {"seq": 3, "dir": Vector2(1, 0), "flags": 0}])
	check(v2.take(0.05).size() == 3, "validação: jitter é absorvido pelo orçamento")


func _accounts() -> RefCounted:
	var acc := Accounts.new({"password_iterations": 50})
	acc.random_bytes = _fake_bytes()
	return acc


func test_accounts() -> void:
	var acc := _accounts()
	var r: Dictionary = acc.register("Alice", "segredo1", 0)
	check(bool(r.ok) and String(r.key) == "alice", "contas: cadastro")
	check(not bool(acc.register("ALICE", "outra123", 0).ok), "contas: nome duplicado (sem diferenciar maiúsculas)")
	check(not bool(acc.register("Bob", "123", 0).ok), "contas: senha curta recusada")
	check(acc.verify("alice", "segredo1") == "alice" and acc.verify("Alice", "errada!!") == "", "contas: login certo/errado")
	var stored: Dictionary = acc.accounts().alice
	check(not String(stored.hash).contains("segredo1") and String(stored.salt).length() == 32, "contas: senha guardada como hash com sal")
	acc.register("Bruno", "segredo1", 0)
	check(String(acc.accounts().bruno.hash) != String(stored.hash), "contas: mesma senha, hashes diferentes (sal)")


func test_sessions_reconnect() -> void:
	var s := Sessions.new(10.0)
	s.random_bytes = _fake_bytes()
	var tok: String = s.issue("alice", 5)
	check(tok.length() == 48 and s.key_of(5) == "alice", "sessão: token emitido e ligado ao peer")
	check(s.resume(tok, 6, 1.0) == "", "sessão: token em uso não pode ser reaproveitado")
	s.detach(5, 1.0)
	check(s.resume("f".repeat(48), 6, 2.0) == "", "sessão: token falso recusado")
	check(s.resume(tok, 6, 5.0) == "alice" and s.peer_of("alice") == 6, "sessão: RESUME dentro da graça volta na mesma conta")
	s.detach(6, 20.0)
	check(s.resume(tok, 7, 31.0) == "", "sessão: RESUME depois da graça recusado")
	check(s.expire(31.0).has("alice"), "sessão: limpeza de sessões vencidas")
	var t2: String = s.issue("bruno", 8)
	var t3: String = s.issue("bruno", 9)
	s.detach(9, 0.0)
	check(s.resume(t2, 10, 1.0) == "" and s.resume(t3, 10, 1.0) == "bruno", "sessão: novo login invalida o token anterior")


func test_friends_presence() -> void:
	var acc := _accounts()
	for n: String in ["Alice", "Bruno", "Carla"]:
		acc.register(n, "segredo1", 0)
	var f := Friends.new(acc)
	var r: Dictionary = f.request("alice", "Bruno")
	check(bool(r.ok) and String(r.events[0].to) == "bruno" and String(r.events[0].op) == "request", "amigos: pedido gera evento para o destinatário")
	check(not bool(f.request("alice", "bruno").ok), "amigos: pedido repetido recusado")
	check(not bool(f.request("alice", "alice").ok) and not bool(f.request("alice", "Ninguem").ok), "amigos: a si mesmo / inexistente recusado")
	r = f.accept("bruno", "alice")
	check(bool(r.ok) and f.are_friends("alice", "bruno") and f.are_friends("bruno", "alice"), "amigos: aceitar cria amizade dos dois lados")
	var evs: Array = f.set_presence("bruno", true, "nos arredores do acampamento")
	check(evs.size() == 1 and String(evs[0].to) == "alice" and bool(evs[0].online), "presença: amigo é avisado ao entrar")
	check(f.set_presence("bruno", true, "nos arredores do acampamento").is_empty(), "presença: sem mudança, sem evento")
	evs = f.set_presence("bruno", true, "na floresta ao sul")
	check(evs.size() == 1 and String(evs[0].region) == "na floresta ao sul", "presença: troca de região notificada")
	var l: Dictionary = f.list("alice")
	check(l.friends.size() == 1 and bool(l.friends[0].online) and String(l.friends[0].name) == "Bruno", "presença: lista com online/região")
	evs = f.set_presence("bruno", false, "")
	check(evs.size() == 1 and not bool(evs[0].online), "presença: offline notificado")
	f.request("carla", "alice")
	r = f.decline("alice", "carla")
	check(bool(r.ok) and not f.are_friends("alice", "carla") and (f.list("carla").outgoing as Array).is_empty(), "amigos: recusar limpa o pedido")
	f.request("carla", "alice")
	r = f.request("alice", "carla")
	check(bool(r.ok) and f.are_friends("alice", "carla"), "amigos: pedido cruzado vira aceite")
	r = f.remove("alice", "bruno")
	check(bool(r.ok) and not f.are_friends("bruno", "alice") and String(r.events[0].op) == "removed", "amigos: remover desfaz dos dois lados")


func test_json_store() -> void:
	# Única verificação com disco (pedida: persistência). Usa diretório próprio e limpa no fim.
	var path := TEST_DIR + "/accounts.json"
	_clean_dir()
	check(Store.load_dict(path).is_empty(), "persistência: arquivo ausente = {}")
	check(Store.save(path, {"v": 1, "accounts": {"a": {"x": 1}}}) == OK, "persistência: salvar")
	check(int(Store.load_dict(path).accounts.a.x) == 1, "persistência: carregar o que foi salvo")
	Store.save(path, {"v": 2, "accounts": {}})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{corrompido")
	f.close()
	check(int(Store.load_dict(path).get("v", 0)) == 1, "persistência: arquivo corrompido cai no .bak")
	var acc := _accounts()
	acc.register("Alice", "segredo1", 0)
	acc.set_character("alice", {"pos": [1, 0, 2], "progress": {"level": 3, "xp": 4}})
	Store.save(path, acc.data)
	var back := Accounts.new({"password_iterations": 50}, Store.load_dict(path))
	check(back.verify("alice", "segredo1") == "alice" and int(back.character("alice").progress.level) == 3, "persistência: conta e personagem sobrevivem ao reinício")
	_clean_dir()


func _clean_dir() -> void:
	var abs_dir := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f: String in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
		DirAccess.remove_absolute(abs_dir)


func test_interest() -> void:
	var g := Interest.new({"interest_enter_m": 10.0, "interest_leave_m": 14.0, "max_snapshot_entities": 2})
	g.put(1, Vector3.ZERO, 0)
	g.put(2, Vector3(5, 0, 0), 1)
	g.put(3, Vector3(12, 0, 0), 1)
	g.put(4, Vector3(3, 0, 0), 2)
	var q: Dictionary = g.query(1, Vector3.ZERO)
	check(q.visible == [2, 4] and q.entered.size() == 2, "interesse: só perto, ordenado por prioridade, com teto")
	g.clear()
	g.put(1, Vector3.ZERO, 0)
	g.put(2, Vector3(12, 0, 0), 1)
	q = g.query(1, Vector3.ZERO)
	check(q.visible == [2] and q.entered.is_empty(), "interesse: histerese mantém quem já era visível")
	g.clear()
	g.put(1, Vector3.ZERO, 0)
	g.put(2, Vector3(15, 0, 0), 1)
	q = g.query(1, Vector3.ZERO)
	check(q.visible.is_empty() and q.left == [2], "interesse: sai além do raio de saída")


func _tuning() -> Dictionary:
	return {"xp_first": 10, "xp_step": 8, "max_level": 20, "player_hp": 60, "hp_per_level": 8, "basic_damage": 8,
		"regen_delay": 5.0, "regen_per_second": 4.0, "blink_level": 2, "ring_level": 3, "ring_damage": 18, "ring_radius": 3.2,
		"torch_order": [0, 2, 1], "cave_guardians": 8, "mana_base": 40, "mana_per_level": 6, "mana_regen_per_second": 2.5,
		"mana_cost": {"fire": 3, "blink": 10, "ring": 15}, "potion": {"hp_heal": 45, "mana_restore": 35, "start_hp": 3, "start_mana": 3, "cooldown": 1.0},
		"enemy": {"frog": {"name": "Sapo Bravio", "hp": 16, "damage": 6, "speed": 1.5, "xp": 3, "windup": 0.65}},
		"field_enemies": [{"kind": "frog", "x": 0, "z": -6}]}


func _world_cfg() -> Dictionary:
	var cfg := NetConfig.load_config(func(_k: String) -> String: return "")
	cfg.spawn = [0.0, 0.0, 0.0]
	cfg.spawn_spread_m = 0.0
	return cfg


func test_world_authority() -> void:
	var col := Collision.new({"half": 60.0, "circles": [[6.0, 0.0, 0.6]]})
	var w := World.new(_world_cfg(), _tuning(), col)
	var me: int = w.add_player("alice", "Alice", {})
	var frog: int = w.monsters.keys()[0]
	check(w.player_action(me, {"act": "fire", "x": 30.0, "z": 0.0, "target": 0}) == "los", "servidor: tiro sem linha de visão recusado (tronco)")
	check(w.player_action(me, {"act": "blink", "x": 0.0, "z": 3.0}) == "level", "servidor: Eco bloqueado no nível 1")
	check(w.player_action(me, {"act": "teleport"}) == "unknown", "servidor: ação desconhecida recusada")
	check(w.player_action(me, {"act": "fire", "target": frog}) == "", "servidor: tiro no sapo aceito")
	check(w.player_action(me, {"act": "fire", "target": frog}) == "cooldown", "servidor: recarga do tiro respeitada")
	w.players[me].mana = 1.0
	w.now += 1.0
	check(w.player_action(me, {"act": "fire", "target": frog}) == "mana", "servidor: sem mana não atira")
	w.players[me].mana = 40.0
	var kills := 0
	var xp_events := 0
	for i in 200:
		w.step(0.05)
		w.players[me].mana = 40.0
		w.player_action(me, {"act": "fire", "target": frog})
		for ev: Dictionary in w.events:
			if String(ev.type) == "kill":
				kills += 1
				xp_events += int(ev.xp)
		w.events.clear()
		if kills > 0:
			break
	check(kills == 1 and xp_events == 3 and int(w.players[me].state.xp) == 3, "servidor: abate e XP calculados no servidor")
	check(String(w.monsters[frog].state) == "dead", "servidor: monstro morto até o respawn")
	var saved: Dictionary = w.remove_player(me)
	var back: int = w.add_player("alice", "Alice", saved)
	check(int(w.players[back].state.xp) == 3 and (w.players[back].ms.pos as Vector3).distance_to(Vector3(float(saved.pos[0]), 0, float(saved.pos[2]))) < 0.01, "servidor: sair e voltar mantém XP e posição")
	var spam: Array = []
	for i in range(1, 201):
		spam.append({"seq": i, "dir": Vector2(-1, 0), "flags": 0})
	var start: Vector3 = w.players[back].ms.pos
	w.player_input(back, spam.slice(0, 8))
	for i in 20:
		w.player_input(back, spam.slice(8 + i * 8, 16 + i * 8))
		w.step(0.05)
	var moved := (w.players[back].ms.pos as Vector3).distance_to(start)
	check(moved <= 4.2 * 1.25 + 0.05, "servidor: comandos em massa não passam da velocidade máxima (%.2f m em 1 s)" % moved)
