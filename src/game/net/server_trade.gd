extends RefCounted
## Itens no chão e troca direta entre jogadores — AUTORITATIVO (servidor).
##
## Chão: {"act": "drop", "item": id} tira da bolsa e deixa o item na posição do servidor por
## `ground_item_s` (shop.json); todos recebem o evento "ground" (add/del) e o welcome traz a
## lista. Qualquer um perto (`ground_take_m` + folga, mesmo andar) pega com {"act": "take", "gid"}.
##
## Troca: {"act": "trade_ask", "target": eid} abre a troca para os dois (perto, vivos, livres).
## Cada um põe/tira itens da bolsa ("trade_add"/"trade_remove", "item") e define quanto ouro e
## quantas poções entram ("trade_set", what = gold|hp|mana, n = total oferecido); qualquer mudança
## desfaz as confirmações. Com os dois "trade_ok", o servidor confere tudo de novo (itens ainda
## na bolsa, espaço) e troca de uma vez. Afastar além de `trade_break_m`, mudar de andar,
## morrer, sair ou "trade_cancel" fecham a troca para os dois.
## Eventos "trade" (só para os dois): op = open | state | done | close (reason).

var world: RefCounted
var shop: Dictionary
## gid → {gid, item, pos: Vector3, floor, until, by}
var ground: Dictionary = {}
## eid → {with: eid, offer: Array[String], gold: int, pots: {hp, mana}, ok: bool}
var trades: Dictionary = {}


func _init(server_world: RefCounted, shop_data: Dictionary) -> void:
	world = server_world
	shop = shop_data


func _f(key: String, fallback: float) -> float:
	return float(shop.get(key, fallback))


func _tol() -> float:
	return float(world.content.tolerance)


func _bag(p: Dictionary) -> Array:
	return (p.inv as RefCounted).items


func _cap(p: Dictionary) -> int:
	return int((p.inv as RefCounted).capacity())


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Evento para cada jogador conectado (itens no chão: poucos jogadores, todos sabem).
func _broadcast(ev: Dictionary) -> void:
	for eid: int in world.players:
		var e := ev.duplicate()
		e["to"] = eid
		world.events.append(e)


## Estado novo da bolsa para o próprio jogador (mesmo evento "content" do resto).
func _bag_event(p: Dictionary, ev: Dictionary) -> void:
	world._content_event(p, world.content._ok(p, ev).ev)


# ------------------------------------------------------------------ chão

func _ground_info(g: Dictionary) -> Dictionary:
	var at: Vector3 = g.pos
	return {"gid": int(g.gid), "item": String(g.item), "at": [snappedf(at.x, 0.01), snappedf(at.z, 0.01)],
		"y": snappedf(at.y, 0.01), "floor": int(g.floor), "left": snappedf(maxf(0.0, float(g.until) - float(world.now)), 0.1)}


## Itens no chão agora (vai no welcome para quem chega).
func ground_list() -> Array:
	var out: Array = []
	for g: Dictionary in ground.values():
		out.append(_ground_info(g))
	return out


func _offered(p: Dictionary, id: String) -> bool:
	var tr: Dictionary = trades.get(int(p.eid), {})
	return not tr.is_empty() and id in (tr.offer as Array)


## Onde o item cai: um passo à frente do corpo (na direção da câmera, para não sumir sob o
## boneco), empurrado para fora de árvores/rochas pela colisão do andar.
func _drop_spot(p: Dictionary) -> Vector3:
	var me: Vector3 = p.ms.pos
	var spot := Vector2(me.x, me.z + 0.7)
	var col: RefCounted = world._col(p)
	if col != null and col.has_method("resolve"):
		spot = col.resolve(spot, 0.25)
	return Vector3(spot.x, me.y, spot.y)


## Largar um item da bolsa no chão. Recusas: dead, item, trade (está na troca).
func drop(p: Dictionary, id: String) -> String:
	if float(p.get("hp", 1.0)) <= 0.0:
		return "dead"
	if not (id in _bag(p)):
		return "item"
	if _offered(p, id) and _bag(p).count(id) <= (trades[int(p.eid)].offer as Array).count(id):
		return "trade"
	_bag(p).erase(id)
	var gid: int = world._id()
	ground[gid] = {"gid": gid, "item": id, "pos": _drop_spot(p), "floor": int(p.get("floor", 0)),
		"until": float(world.now) + _f("ground_item_s", 60.0), "by": int(p.eid)}
	var info := _ground_info(ground[gid])
	info["type"] = "ground"
	info["op"] = "add"
	_broadcast(info)
	_bag_event(p, {"what": "drop", "item": id, "gid": gid})
	return ""


## Pegar um item do chão. Recusas: dead, gone, floor, range, full.
func take(p: Dictionary, gid: int) -> String:
	if float(p.get("hp", 1.0)) <= 0.0:
		return "dead"
	if not ground.has(gid):
		return "gone"
	var g: Dictionary = ground[gid]
	if int(g.floor) != int(p.get("floor", 0)):
		return "floor"
	if _flat(p.ms.pos, g.pos) > _f("ground_take_m", 1.6) + _tol():
		return "range"
	if _bag(p).size() >= _cap(p):
		return "full"
	ground.erase(gid)
	_bag(p).append(String(g.item))
	_broadcast({"type": "ground", "op": "del", "gid": gid, "by": int(p.eid)})
	_bag_event(p, {"what": "take", "item": String(g.item), "gid": gid})
	return ""


# ------------------------------------------------------------------ troca

func _send_state(eid: int, op: String) -> void:
	var tr: Dictionary = trades.get(eid, {})
	if tr.is_empty():
		return
	var other := int(tr.with)
	var ot: Dictionary = trades.get(other, {})
	var oname := String((world.players.get(other, {}) as Dictionary).get("name", ""))
	world.events.append({"to": eid, "type": "trade", "op": op, "with": other, "name": oname,
		"mine": (tr.offer as Array).duplicate(), "theirs": (ot.get("offer", []) as Array).duplicate(),
		"my_gold": int(tr.gold), "their_gold": int(ot.get("gold", 0)),
		"my_pots": (tr.pots as Dictionary).duplicate(), "their_pots": (ot.get("pots", {}) as Dictionary).duplicate(),
		"my_ok": bool(tr.ok), "their_ok": bool(ot.get("ok", false))})


## Pedir troca a outro jogador. Recusas: target, dead, busy, floor, range.
func ask(p: Dictionary, target: int) -> String:
	var me := int(p.eid)
	if target == me or not world.players.has(target):
		return "target"
	var q: Dictionary = world.players[target]
	if float(p.hp) <= 0.0 or float(q.hp) <= 0.0:
		return "dead"
	if trades.has(me) or trades.has(target):
		return "busy"
	if int(p.get("floor", 0)) != int(q.get("floor", 0)):
		return "floor"
	if _flat(p.ms.pos, q.ms.pos) > _f("trade_radius_m", 3.0) + _tol():
		return "range"
	var empty_a: Array[String] = []
	var empty_b: Array[String] = []
	trades[me] = {"with": target, "offer": empty_a, "gold": 0, "pots": {"hp": 0, "mana": 0}, "ok": false}
	trades[target] = {"with": me, "offer": empty_b, "gold": 0, "pots": {"hp": 0, "mana": 0}, "ok": false}
	_send_state(me, "open")
	_send_state(target, "open")
	return ""


## Pôr (add) ou tirar um item da sua oferta. Recusas: no_trade, item, max.
func offer(p: Dictionary, id: String, add: bool) -> String:
	var me := int(p.eid)
	if not trades.has(me):
		return "no_trade"
	var tr: Dictionary = trades[me]
	var off: Array = tr.offer
	if add:
		if _bag(p).count(id) <= off.count(id):
			return "item"
		if off.size() >= int(_f("trade_max_items", 6)):
			return "max"
		off.append(id)
	else:
		if not (id in off):
			return "item"
		off.erase(id)
	tr.ok = false
	trades[int(tr.with)].ok = false
	_send_state(me, "state")
	_send_state(int(tr.with), "state")
	return ""


## Quanto ouro ou poções ("gold" | "hp" | "mana") entram na sua oferta (total, não soma).
## Recusas: no_trade, what, gold (mais do que tem), potion (mais do que tem).
func set_amount(p: Dictionary, what: String, n: int) -> String:
	var me := int(p.eid)
	if not trades.has(me):
		return "no_trade"
	var tr: Dictionary = trades[me]
	n = maxi(0, n)
	if what == "gold":
		if n > int(p.get("gold", 0)):
			return "gold"
		tr.gold = n
	elif what in ["hp", "mana"]:
		if n > int((p.get("potions", {}) as Dictionary).get(what, 0)):
			return "potion"
		tr.pots[what] = n
	else:
		return "what"
	tr.ok = false
	trades[int(tr.with)].ok = false
	_send_state(me, "state")
	_send_state(int(tr.with), "state")
	return ""


## Confirmar. Com os dois confirmados, troca (ou fecha se algo não fecha mais).
func confirm(p: Dictionary) -> String:
	var me := int(p.eid)
	if not trades.has(me):
		return "no_trade"
	trades[me].ok = true
	var other := int(trades[me].with)
	if bool(trades[other].ok):
		_swap(me, other)
	else:
		_send_state(me, "state")
		_send_state(other, "state")
	return ""


func cancel(p: Dictionary) -> String:
	if not trades.has(int(p.eid)):
		return "no_trade"
	close(int(p.eid), "cancel")
	return ""


## Fecha a troca dos dois lados com o motivo (cancel, range, floor, dead, left, item, full).
func close(eid: int, reason: String) -> void:
	var tr: Dictionary = trades.get(eid, {})
	if tr.is_empty():
		return
	var other := int(tr.with)
	trades.erase(eid)
	trades.erase(other)
	for who: int in [eid, other]:
		if world.players.has(who):
			world.events.append({"to": who, "type": "trade", "op": "close", "reason": reason})


## Tem todos os itens da oferta (contando repetidos)?
static func _has_all(bag: Array, off: Array) -> bool:
	for id: Variant in off:
		if bag.count(id) < off.count(id):
			return false
	return true


func _swap(a: int, b: int) -> void:
	var pa: Dictionary = world.players[a]
	var pb: Dictionary = world.players[b]
	var oa: Array = (trades[a].offer as Array).duplicate()
	var ob: Array = (trades[b].offer as Array).duplicate()
	if not _has_all(_bag(pa), oa) or not _has_all(_bag(pb), ob):
		close(a, "item")
		return
	var ga := int(trades[a].gold)
	var gb := int(trades[b].gold)
	var ka: Dictionary = (trades[a].pots as Dictionary).duplicate()
	var kb: Dictionary = (trades[b].pots as Dictionary).duplicate()
	if int(pa.get("gold", 0)) < ga or int(pb.get("gold", 0)) < gb:
		close(a, "gold")   # gastou o ouro na loja depois de oferecer
		return
	for k: String in ["hp", "mana"]:
		if int(pa.potions.get(k, 0)) < int(ka.get(k, 0)) or int(pb.potions.get(k, 0)) < int(kb.get(k, 0)):
			close(a, "potion")   # bebeu a poção depois de oferecer
			return
	if _bag(pa).size() - oa.size() + ob.size() > _cap(pa) or _bag(pb).size() - ob.size() + oa.size() > _cap(pb):
		close(a, "full")
		return
	# tudo conferido: aplica os dois lados no mesmo passo
	for id: Variant in oa:
		_bag(pa).erase(id)
	for id: Variant in ob:
		_bag(pb).erase(id)
	for id: Variant in ob:
		_bag(pa).append(String(id))
	for id: Variant in oa:
		_bag(pb).append(String(id))
	pa.gold = int(pa.get("gold", 0)) - ga + gb
	pb.gold = int(pb.get("gold", 0)) - gb + ga
	for k: String in ["hp", "mana"]:
		pa.potions[k] = int(pa.potions.get(k, 0)) - int(ka.get(k, 0)) + int(kb.get(k, 0))
		pb.potions[k] = int(pb.potions.get(k, 0)) - int(kb.get(k, 0)) + int(ka.get(k, 0))
	trades.erase(a)
	trades.erase(b)
	_bag_event(pa, {"what": "trade", "gave": oa, "got": ob, "gold_gave": ga, "gold_got": gb, "pots_gave": ka, "pots_got": kb, "with": String(pb.name)})
	_bag_event(pb, {"what": "trade", "gave": ob, "got": oa, "gold_gave": gb, "gold_got": ga, "pots_gave": kb, "pots_got": ka, "with": String(pa.name)})
	world.events.append({"to": a, "type": "trade", "op": "done", "gave": oa, "got": ob, "gold_got": gb, "pots_got": kb})
	world.events.append({"to": b, "type": "trade", "op": "done", "gave": ob, "got": oa, "gold_got": ga, "pots_got": ka})


# ------------------------------------------------------------------ passo

## Itens do chão expiram; trocas fecham se alguém se afasta, muda de andar ou morre.
func step() -> void:
	for gid: int in ground.keys():
		if float(world.now) >= float(ground[gid].until):
			ground.erase(gid)
			_broadcast({"type": "ground", "op": "del", "gid": gid, "by": 0})
	for eid: int in trades.keys():
		if not trades.has(eid):
			continue
		var other := int(trades[eid].with)
		if not world.players.has(eid) or not world.players.has(other):
			close(eid, "left")
			continue
		var pa: Dictionary = world.players[eid]
		var pb: Dictionary = world.players[other]
		if float(pa.hp) <= 0.0 or float(pb.hp) <= 0.0:
			close(eid, "dead")
		elif int(pa.get("floor", 0)) != int(pb.get("floor", 0)):
			close(eid, "floor")
		elif _flat(pa.ms.pos, pb.ms.pos) > _f("trade_break_m", 6.0):
			close(eid, "range")


func on_leave(eid: int) -> void:
	close(eid, "left")
