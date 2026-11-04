# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Lista de amigos sobre o AccountStore (puro). Cada operação devolve
## {ok, error, events}; `events` = Array de {to: chave, op, name, online, region}
## que o transporte entrega em tempo real a quem estiver conectado.
## Ops de evento: "request" (pedido recebido), "accepted", "declined", "removed", "presence".

const TextRules := preload("res://prototypes/pixel3d/net/text_rules.gd")

var store: RefCounted
var max_friends := 100
var max_pending := 50
var presence: Dictionary = {}   # chave → {online: bool, region: String}


func _init(account_store: RefCounted) -> void:
	store = account_store


func _acc(key: String) -> Dictionary:
	return store.accounts().get(key, {})


func _p(key: String) -> Dictionary:
	return presence.get(key, {"online": false, "region": ""})


func _ev(to: String, op: String, about: String) -> Dictionary:
	var pr := _p(about)
	return {"to": to, "op": op, "name": store.display_name(about), "online": bool(pr.online), "region": String(pr.region)}


func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "events": []}


func are_friends(a: String, b: String) -> bool:
	return (_acc(a).get("friends", {}) as Dictionary).has(b)


func request(me: String, other_name: String) -> Dictionary:
	var other := TextRules.name_key(other_name)
	if not store.exists(me) or not store.exists(other):
		return _fail("no_such_player")
	if other == me:
		return _fail("self")
	if are_friends(me, other):
		return _fail("already_friends")
	var mine: Dictionary = _acc(me)
	if (mine.incoming as Dictionary).has(other):   # pedido cruzado: vira aceite
		return accept(me, other_name)
	if (mine.outgoing as Dictionary).has(other):
		return _fail("already_requested")
	if (mine.friends as Dictionary).size() >= max_friends or (mine.outgoing as Dictionary).size() >= max_pending:
		return _fail("limit")
	var theirs: Dictionary = _acc(other)
	if (theirs.incoming as Dictionary).size() >= max_pending:
		return _fail("limit")
	(mine.outgoing as Dictionary)[other] = true
	(theirs.incoming as Dictionary)[me] = true
	store.dirty = true
	return {"ok": true, "error": "", "events": [_ev(other, "request", me)]}


func accept(me: String, other_name: String) -> Dictionary:
	var other := TextRules.name_key(other_name)
	var mine: Dictionary = _acc(me)
	if mine.is_empty() or not (mine.incoming as Dictionary).has(other) or not store.exists(other):
		return _fail("no_request")
	var theirs: Dictionary = _acc(other)
	(mine.incoming as Dictionary).erase(other)
	(theirs.outgoing as Dictionary).erase(me)
	(mine.friends as Dictionary)[other] = true
	(theirs.friends as Dictionary)[me] = true
	store.dirty = true
	return {"ok": true, "error": "", "events": [_ev(other, "accepted", me), _ev(me, "presence", other)]}


func decline(me: String, other_name: String) -> Dictionary:
	var other := TextRules.name_key(other_name)
	var mine: Dictionary = _acc(me)
	if mine.is_empty() or not (mine.incoming as Dictionary).has(other):
		return _fail("no_request")
	(mine.incoming as Dictionary).erase(other)
	if store.exists(other):
		(_acc(other).outgoing as Dictionary).erase(me)
	store.dirty = true
	return {"ok": true, "error": "", "events": [_ev(other, "declined", me)]}


func remove(me: String, other_name: String) -> Dictionary:
	var other := TextRules.name_key(other_name)
	if not are_friends(me, other):
		return _fail("not_friends")
	(_acc(me).friends as Dictionary).erase(other)
	(_acc(other).friends as Dictionary).erase(me)
	store.dirty = true
	return {"ok": true, "error": "", "events": [_ev(other, "removed", me)]}


## Atualiza presença e avisa os amigos (só se mudou).
func set_presence(key: String, online: bool, region: String) -> Array:
	var old := _p(key)
	if bool(old.online) == online and String(old.region) == region:
		return []
	presence[key] = {"online": online, "region": region if online else ""}
	var out: Array = []
	for f: String in (_acc(key).get("friends", {}) as Dictionary):
		out.append(_ev(f, "presence", key))
	return out


func list(key: String) -> Dictionary:
	var acc := _acc(key)
	var friends: Array = []
	for f: String in (acc.get("friends", {}) as Dictionary):
		var pr := _p(f)
		friends.append({"name": store.display_name(f), "online": bool(pr.online), "region": String(pr.region)})
	var incoming: Array = []
	for f: String in (acc.get("incoming", {}) as Dictionary):
		incoming.append(store.display_name(f))
	var outgoing: Array = []
	for f: String in (acc.get("outgoing", {}) as Dictionary):
		outgoing.append(store.display_name(f))
	return {"friends": friends, "incoming": incoming, "outgoing": outgoing}
