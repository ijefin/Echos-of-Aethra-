extends SceneTree
## Bolsa, ouro e trocas AUTORITATIVOS no servidor: desequipar (bolsa cheia recusa, bônus
## recalculado, persistido), moedas por abate e por missão, compra/venda com a comerciante
## (distância, ouro), itens no chão (largar/pegar/expirar, todos veem) e troca direta entre
## dois jogadores (confirmação dupla, mudança desfaz, afastar cancela, troca atômica).
##   godot --headless --path . -s res://tests/unit/net/server_economy_test.gd
## Sem física (IA mínima); fixtures = dados do protótipo (shop.json, items.json, classes.json).

const N := "res://prototypes/pixel3d/net/"
const World := preload(N + "server_world.gd")
const Collision := preload(N + "world_collision.gd")
const NetConfig := preload(N + "net_config.gd")
const Store := preload(N + "json_store.gd")
const Economy := preload("res://prototypes/pixel3d/economy.gd")
const TUNING := "res://prototypes/pixel3d/data/first_adventure.json"
const CLASSES := "res://prototypes/pixel3d/data/classes.json"

var failures := 0
var passes := 0
var w: RefCounted
var shop: Dictionary


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	var cfg := NetConfig.load_config(func(_k: String) -> String: return "")
	(cfg.monsters as Dictionary)["aggro_m"] = 0.0
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TUNING))
	var floors: Dictionary = Collision.load_floors(N + "data/collision_surface.json", 100.0)
	w = World.new(cfg, tuning, floors[0], 7, Store.load_dict(CLASSES), {}, floors)
	shop = Economy.load_data()
	test_unequip()
	test_gold_from_kills_and_quests()
	test_merchant_buy_sell()
	test_ground_items()
	test_trade_done()
	test_trade_cancel_and_guards()
	print("SERVER_ECONOMY: %s (%d ok, %d falhas)" % ["OK" if failures == 0 else "FALHOU", passes, failures])
	quit(0 if failures == 0 else 1)


func put(eid: int, at: Vector3) -> void:
	w.players[eid].ms.pos = at
	w.players[eid].floor = World.floor_of(at.y)


func evs(eid: int, type: String) -> Array:
	var out: Array = []
	for e: Dictionary in w.events:
		if int(e.to) == eid and String(e.get("type", "")) == type:
			out.append(e)
	return out


func last(eid: int, type: String) -> Dictionary:
	var l := evs(eid, type)
	return l[l.size() - 1] if not l.is_empty() else {}


# ------------------------------------------------------------------ desequipar

func test_unequip() -> void:
	var eid: int = w.add_player("e1", "E1", {}, "warrior")
	var p: Dictionary = w.players[eid]
	var weapon := String(p.inv.equipped.get("weapon", ""))
	var dmg0: int = w.combat.fire_damage(p)
	w.events.clear()
	check(w.player_action(eid, {"act": "unequip", "slot": "weapon"}) == "", "desequipar a arma: aceito")
	check(not p.inv.equipped.has("weapon") and weapon in p.inv.items, "arma volta para a bolsa (%s)" % weapon)
	check(int(w.combat.fire_damage(p)) < dmg0, "dano autoritativo recalculado sem a arma (%d → %d)" % [dmg0, int(w.combat.fire_damage(p))])
	var ev := last(eid, "content")
	check(String(ev.get("what", "")) == "unequip" and (ev.state.bag as Array).has(weapon), "evento content leva a bolsa nova ao cliente")
	check(w.player_action(eid, {"act": "unequip", "slot": "weapon"}) == "slot", "slot vazio → recusado (slot)")
	check(w.player_action(eid, {"act": "unequip", "slot": "asa"}) == "slot", "slot desconhecido → recusado")
	# bolsa cheia
	while p.inv.items.size() < p.inv.capacity():
		p.inv.items.append("iron_sword")
	var chest_id := String(p.inv.equipped.get("chest", ""))
	check(w.player_action(eid, {"act": "unequip", "slot": "chest"}) == "full" and String(p.inv.equipped.get("chest", "")) == chest_id, "bolsa cheia → recusado (full) e o peito continua vestido")
	p.inv.items.resize(1)
	check(w.player_action(eid, {"act": "unequip", "slot": "chest"}) == "", "com espaço: peito desequipado")
	var saved: Dictionary = w.remove_player(eid)
	var eid2: int = w.add_player("e1", "E1", saved, "")
	var p2: Dictionary = w.players[eid2]
	check(not p2.inv.equipped.has("weapon") and not p2.inv.equipped.has("chest") and chest_id in p2.inv.items, "persistência: bolsa e slots vazios voltam iguais do save")
	w.remove_player(eid2)


# ------------------------------------------------------------------ ouro

func test_gold_from_kills_and_quests() -> void:
	var eid: int = w.add_player("e2", "E2", {}, "archer")
	var p: Dictionary = w.players[eid]
	check(int(p.gold) == 0, "personagem novo sem ouro")
	var lvl1 := {}
	var lvl3 := {}
	for m: Dictionary in w.monsters.values():
		if String(m.kind) == "frog" and int(m.level) == 1 and lvl1.is_empty():
			lvl1 = m
		if int(m.level) >= 3 and lvl3.is_empty():
			lvl3 = m
	w.events.clear()
	w._damage_monster(lvl1, 9999, eid)
	var k := last(eid, "kill")
	var g1 := Economy.gold_drop(shop, "frog", 1)
	check(int(k.get("gold", -1)) == g1 and int(p.gold) == g1 and int(k.get("gold_total", -1)) == g1, "sapo nível 1: %d moedas (evento kill leva o total)" % g1)
	if not lvl3.is_empty():
		w._damage_monster(lvl3, 9999, eid)
		var g3 := Economy.gold_drop(shop, String(lvl3.kind), int(lvl3.level))
		check(int(last(eid, "kill").get("gold", -1)) == g3 and g3 > Economy.gold_drop(shop, String(lvl3.kind), 1), "caçada nível %d paga mais (%d moedas)" % [int(lvl3.level), g3])
	var before := int(p.gold)
	var r: Dictionary = w.content.reward(p, {"xp": 5, "gold": 20})
	check(int(r.gold) == 20 and int(p.gold) == before + 20, "recompensa de missão soma ouro (+20)")
	var saved: Dictionary = w.remove_player(eid)
	var eid2: int = w.add_player("e2", "E2", saved, "")
	check(int(w.players[eid2].gold) == before + 20, "persistência: ouro volta do save (%d)" % int(w.players[eid2].gold))
	w.remove_player(eid2)


func test_merchant_buy_sell() -> void:
	var eid: int = w.add_player("e3", "E3", {}, "mage")
	var p: Dictionary = w.players[eid]
	var price_hp := Economy.buy_price(shop, "hp")
	put(eid, World.NPC + Vector3(20, 0, 0))
	p.gold = 100
	check(w.player_action(eid, {"act": "buy", "kind": "hp"}) == "range", "comprar longe da Nessa → recusado (range)")
	put(eid, World.NPC + Vector3(0, 0, 1.6))
	p.gold = price_hp - 1
	check(w.player_action(eid, {"act": "buy", "kind": "hp"}) == "gold", "sem ouro suficiente → recusado (gold)")
	p.gold = price_hp * 2 + 1
	var pots := int(p.potions.hp)
	w.events.clear()
	check(w.player_action(eid, {"act": "buy", "kind": "hp"}) == "", "comprar poção de vida: aceito")
	check(int(p.potions.hp) == pots + 1 and int(p.gold) == price_hp + 1, "ouro −%d, poção +1 (servidor)" % price_hp)
	check(int(last(eid, "content").state.gold) == price_hp + 1, "estado do cliente leva o ouro novo")
	check(w.player_action(eid, {"act": "buy", "kind": "elixir"}) == "kind", "item que ela não vende → recusado")
	p.inv.give(["sentinel_staff"])
	var g0 := int(p.gold)
	var sp := Economy.sell_price(shop, "sentinel_staff", p.inv.item("sentinel_staff"))
	check(w.player_action(eid, {"act": "sell", "item": "sentinel_staff"}) == "" and int(p.gold) == g0 + sp and not ("sentinel_staff" in p.inv.items), "vender o Cajado da Sentinela (raro): +%d moedas e sai da bolsa" % sp)
	var worn := String(p.inv.equipped.get("weapon", ""))
	check(w.player_action(eid, {"act": "sell", "item": worn}) == "item", "item vestido não se vende (item)")
	w.events.clear()
	w.player_action(eid, {"act": "interact", "target": "nessa"})   # aceita As Três Brasas
	check(not bool(last(eid, "content").get("shop", true)), "Nessa: no aceite da missão não abre a troca")
	w.player_action(eid, {"act": "interact", "target": "nessa"})   # missão em andamento
	check(bool(last(eid, "content").get("shop", false)), "Nessa: depois abre a troca (shop no evento)")
	w.remove_player(eid)


# ------------------------------------------------------------------ chão

func test_ground_items() -> void:
	var a: int = w.add_player("e4", "Ana", {}, "archer")
	var b: int = w.add_player("e5", "Beto", {}, "warrior")
	var pa: Dictionary = w.players[a]
	var pb: Dictionary = w.players[b]
	put(a, World.NPC + Vector3(4, 0, 4))
	put(b, World.NPC + Vector3(4, 0, 7))
	pa.inv.give(["leather_hood"])
	w.events.clear()
	check(w.player_action(a, {"act": "drop", "item": "guard_sword"}) == "item", "largar item que não tem → recusado")
	check(w.player_action(a, {"act": "drop", "item": "leather_hood"}) == "" and not ("leather_hood" in pa.inv.items), "largar o Capuz de Couro: sai da bolsa")
	var add_b := last(b, "ground")
	check(String(add_b.get("op", "")) == "add" and String(add_b.get("item", "")) == "leather_hood", "o outro jogador recebe o item no chão (evento ground add)")
	var gid := int(add_b.get("gid", 0))
	check(w.trade.ground_list().size() == 1, "lista do chão (vai no welcome) tem o item")
	check(w.player_action(b, {"act": "take", "gid": gid}) == "range", "pegar a 3 m → recusado (range)")
	put(b, World.NPC + Vector3(4, 0, 5))
	w.events.clear()
	check(w.player_action(b, {"act": "take", "gid": gid}) == "" and "leather_hood" in pb.inv.items, "qualquer um perto pega: vai para a bolsa do Beto")
	check(String(last(a, "ground").get("op", "")) == "del", "item some do chão para todos (ground del)")
	check(w.player_action(a, {"act": "take", "gid": gid}) == "gone", "pegar de novo → recusado (gone)")
	# expira
	pb.inv.items.erase("leather_hood")
	pb.inv.give(["knight_helm"])
	w.player_action(b, {"act": "drop", "item": "knight_helm"})
	w.events.clear()
	w.now += float(shop.get("ground_item_s", 60.0)) + 0.1
	w.trade.step()
	check(w.trade.ground.is_empty() and String(last(a, "ground").get("op", "")) == "del", "item do chão expira (%.0f s) e some para todos" % float(shop.get("ground_item_s", 60.0)))
	w.remove_player(a)
	w.remove_player(b)


# ------------------------------------------------------------------ troca

func _pair(ka: String, kb: String) -> Array[int]:
	var a: int = w.add_player(ka, ka, {}, "archer")
	var b: int = w.add_player(kb, kb, {}, "mage")
	put(a, World.NPC + Vector3(5, 0, 3))
	put(b, World.NPC + Vector3(6.5, 0, 3))
	return [a, b]


func test_trade_done() -> void:
	var ids := _pair("Caio", "Duda")
	var a := ids[0]
	var b := ids[1]
	var pa: Dictionary = w.players[a]
	var pb: Dictionary = w.players[b]
	pa.inv.give(["sentinel_staff"])
	pb.inv.give(["yew_bow", "leather_vest"])
	w.events.clear()
	check(w.player_action(a, {"act": "trade_ask", "target": b}) == "", "pedido de troca perto: aceito")
	check(String(last(b, "trade").get("op", "")) == "open" and String(last(b, "trade").name) == "Caio", "a Duda recebe a troca aberta com o nome do Caio")
	check(w.player_action(b, {"act": "trade_ask", "target": a}) == "busy", "já em troca → recusado (busy)")
	check(w.player_action(a, {"act": "trade_add", "item": "guard_sword"}) == "item", "oferecer item que não tem → recusado")
	check(w.player_action(a, {"act": "trade_add", "item": "sentinel_staff"}) == "", "Caio oferece o Cajado da Sentinela")
	check(w.player_action(b, {"act": "trade_add", "item": "yew_bow"}) == "", "Duda oferece o Arco de Teixo")
	check((last(a, "trade").theirs as Array).has("yew_bow"), "o Caio vê a oferta da Duda")
	check(w.player_action(a, {"act": "trade_ok"}) == "" and bool(last(b, "trade").their_ok), "Caio confirma (a Duda vê)")
	w.player_action(b, {"act": "trade_add", "item": "leather_vest"})
	check(not bool(last(b, "trade").their_ok) and not bool(last(a, "trade").my_ok), "mudar a oferta desfaz as confirmações")
	w.player_action(b, {"act": "trade_remove", "item": "leather_vest"})
	w.player_action(a, {"act": "trade_ok"})
	check("sentinel_staff" in pa.inv.items, "com só um lado confirmado nada muda")
	w.events.clear()
	check(w.player_action(b, {"act": "trade_ok"}) == "", "Duda confirma: os dois confirmaram")
	check("yew_bow" in pa.inv.items and not ("sentinel_staff" in pa.inv.items), "Caio recebeu o Arco de Teixo e entregou o cajado")
	check("sentinel_staff" in pb.inv.items and not ("yew_bow" in pb.inv.items) and "leather_vest" in pb.inv.items, "Duda recebeu o cajado e ficou com o colete")
	check(String(last(a, "trade").get("op", "")) == "done" and String(last(b, "content").get("what", "")) == "trade", "evento done + bolsa nova para os dois")
	check(w.trade.trades.is_empty(), "troca encerrada no servidor")
	var saved: Dictionary = w.remove_player(a)
	var a2: int = w.add_player("Caio", "Caio", saved, "")
	check("yew_bow" in w.players[a2].inv.items, "persistência: o item trocado continua na bolsa depois de sair")
	w.remove_player(a2)
	w.remove_player(b)


func test_trade_cancel_and_guards() -> void:
	var ids := _pair("Eva", "Fabi")
	var a := ids[0]
	var b := ids[1]
	var pa: Dictionary = w.players[a]
	var pb: Dictionary = w.players[b]
	put(b, World.NPC + Vector3(15, 0, 3))
	check(w.player_action(a, {"act": "trade_ask", "target": b}) == "range", "pedido longe → recusado (range)")
	check(w.player_action(a, {"act": "trade_ask", "target": a}) == "target", "trocar consigo mesmo → recusado")
	put(b, World.NPC + Vector3(6.5, 0, 3))
	pa.inv.give(["iron_sword"])
	pb.inv.give(["ember_robe"])
	w.player_action(a, {"act": "trade_ask", "target": b})
	w.player_action(a, {"act": "trade_add", "item": "iron_sword"})
	w.player_action(b, {"act": "trade_add", "item": "ember_robe"})
	w.player_action(a, {"act": "trade_ok"})
	check(w.player_action(a, {"act": "drop", "item": "iron_sword"}) == "trade", "item na oferta não pode ser largado")
	w.events.clear()
	put(b, World.NPC + Vector3(5 + float(shop.get("trade_break_m", 6.0)) + 1.0, 0, 3))
	w.trade.step()
	check(w.trade.trades.is_empty(), "afastar além de %.0f m cancela a troca" % float(shop.get("trade_break_m", 6.0)))
	check(String(last(a, "trade").get("reason", "")) == "range" and String(last(b, "trade").get("reason", "")) == "range", "os dois recebem close (range)")
	check("iron_sword" in pa.inv.items and "ember_robe" in pb.inv.items, "troca cancelada não mexe nas bolsas")
	check(w.player_action(b, {"act": "trade_ok"}) == "no_trade", "confirmar depois de cancelada → recusado")
	# o item sumiu entre a oferta e a confirmação: o servidor confere de novo e não troca
	put(b, World.NPC + Vector3(6.5, 0, 3))
	w.player_action(a, {"act": "trade_ask", "target": b})
	w.player_action(a, {"act": "trade_add", "item": "iron_sword"})
	w.player_action(b, {"act": "trade_add", "item": "ember_robe"})
	pb.inv.items.erase("ember_robe")   # (ex.: vendeu na Nessa no meio da troca)
	w.events.clear()
	w.player_action(a, {"act": "trade_ok"})
	w.player_action(b, {"act": "trade_ok"})
	check(String(last(a, "trade").get("reason", "")) == "item" and "iron_sword" in pa.inv.items, "item sumido: troca fechada (item) sem dar nada a ninguém")
	# sair no meio fecha para o outro
	w.player_action(a, {"act": "trade_ask", "target": b})
	w.events.clear()
	w.remove_player(b)
	check(String(last(a, "trade").get("reason", "")) == "left" and w.trade.trades.is_empty(), "quem sai no meio fecha a troca do outro (left)")
	w.remove_player(a)
