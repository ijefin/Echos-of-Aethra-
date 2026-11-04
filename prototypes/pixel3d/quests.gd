# PROTOTYPE - NOT FOR PRODUCTION
extends RefCounted
## Missões guiadas por dados (data/quests.json), segredos únicos e itens de missão.
## Regras puras: sem cena, sem arquivo (o adventure injeta os dados e aplica recompensas).
## Passos: kill {kind, hunt?, count} · reach {at, radius} · collect {item, count,
## from {kind, hunt?} | at} · talk {npc}. Todo o progresso cabe em snapshot()/restore().

const PATH := "res://prototypes/pixel3d/data/quests.json"
const PICKUP_RADIUS := 2.0

var data: Dictionary
## id da missão → {"step": int, "count": int}
var active: Dictionary = {}
var done: Array[String] = []
## Itens de missão na bolsa: id → quantidade.
var items: Dictionary = {}
var secrets: Array[String] = []
## Bônus permanentes (relíquias): max_hp, max_resource.
var perm: Dictionary = {"max_hp": 0, "max_resource": 0}
## Equipamento recebido como recompensa (para refazer a bolsa ao carregar).
var owned: Array[String] = []


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH))


func _init(quest_data: Dictionary) -> void:
	data = quest_data


func quest(id: String) -> Dictionary:
	for q: Dictionary in data.quests:
		if String(q.id) == id:
			return q
	return {}


func npc(id: String) -> Dictionary:
	return data.npcs.get(id, {})


func item_name(id: String) -> String:
	return String(data.items.get(id, {}).get("name", id))


## locked (falta missão anterior) · weak (nível baixo) · available · active · done
func status(id: String, level: int) -> String:
	if id in done:
		return "done"
	if active.has(id):
		return "active"
	var q := quest(id)
	for r: Variant in q.get("requires", []):
		if not (String(r) in done):
			return "locked"
	return "weak" if level < int(q.get("min_level", 1)) else "available"


func step(id: String) -> Dictionary:
	var q := quest(id)
	if not active.has(id):
		return {}
	var i := int(active[id].step)
	return q.steps[i] if i < (q.steps as Array).size() else {}


## Missões ativas na ordem do arquivo.
func active_ids() -> Array[String]:
	var out: Array[String] = []
	for q: Dictionary in data.quests:
		if active.has(String(q.id)):
			out.append(String(q.id))
	return out


func _advance(id: String) -> void:
	active[id] = {"step": int(active[id].step) + 1, "count": 0}
	var s := step(id)
	# coleta de algo que o jogador já tem (ex.: item que caiu antes) conta na hora
	if String(s.get("type", "")) == "collect" and int(items.get(String(s.item), 0)) >= int(s.count):
		_advance(id)


## Conversa com um NPC. Devolve {event, quest, lines, reward}:
## step (entregou um passo intermediário) · complete · accept · waiting · weak · idle.
func talk(npc_id: String, level: int) -> Dictionary:
	# 1) algum passo "fale com este NPC" em andamento (inclusive missão de outro NPC)
	for id: String in active_ids():
		var s := step(id)
		if String(s.get("type", "")) == "talk" and String(s.npc) == npc_id:
			var q := quest(id)
			if int(active[id].step) >= (q.steps as Array).size() - 1:
				return _complete(id)
			_advance(id)
			return {"event": "step", "quest": id, "lines": s.get("lines", q.get("waiting", [[""]])[0])}
	var n := npc(npc_id)
	var weak := false
	for q: Dictionary in data.quests:
		if String(q.giver) != npc_id:
			continue
		var id := String(q.id)
		match status(id, level):
			"active":
				return {"event": "waiting", "quest": id, "lines": (q.waiting as Array).pick_random()}
			"available":
				active[id] = {"step": -1, "count": 0}
				_advance(id)
				return {"event": "accept", "quest": id, "lines": q.accept}
			"weak":
				weak = true
				break
			"locked":
				break
	if weak:
		return {"event": "weak", "quest": "", "lines": (n.weak as Array).pick_random()}
	return {"event": "idle", "quest": "", "lines": (n.idle as Array).pick_random()}


func _complete(id: String) -> Dictionary:
	var q := quest(id)
	active.erase(id)
	done.append(id)
	for s: Dictionary in q.steps:  # itens de missão são entregues
		if String(s.type) == "collect":
			items.erase(String(s.item))
	return {"event": "complete", "quest": id, "lines": q.complete, "reward": q.get("reward", {})}


## Um monstro morreu. Devolve eventos: [{quest, type: "progress"|"step", drop?: item}].
func on_kill(kind: String, hunt: String) -> Array:
	var events: Array = []
	for id: String in active_ids():
		var s := step(id)
		if String(s.get("type", "")) == "kill":
			if String(s.kind) == kind and (String(s.get("hunt", "")) == "" or String(s.hunt) == hunt):
				active[id].count = int(active[id].count) + 1
				if int(active[id].count) < int(s.count):
					events.append({"quest": id, "type": "progress"})
					continue
				_advance(id)
				events.append({"quest": id, "type": "step"})
				s = step(id)  # o mesmo abate pode soltar o item do passo seguinte
		match String(s.get("type", "")):
			"collect":
				var from: Dictionary = s.get("from", {})
				if not from.is_empty() and String(from.kind) == kind and (String(from.get("hunt", "")) == "" or String(from.hunt) == hunt):
					var it := String(s.item)
					items[it] = int(items.get(it, 0)) + 1
					var ev := {"quest": id, "type": "progress", "drop": it}
					if int(items[it]) >= int(s.count):
						_advance(id)
						ev.type = "step"
					events.append(ev)
	return events


## O jogador está em `p` (xz). Passos "reach" cumpridos viram eventos.
func on_reach(p: Vector2) -> Array:
	var events: Array = []
	for id: String in active_ids():
		var s := step(id)
		if String(s.get("type", "")) == "reach" and p.distance_to(_v2(s.at)) <= float(s.radius):
			_advance(id)
			events.append({"quest": id, "type": "step"})
	return events


## Objetos de missão no mundo que podem ser pegos agora: [{quest, item, at: Vector2}].
func pickups() -> Array:
	var out: Array = []
	for id: String in active_ids():
		var s := step(id)
		if String(s.get("type", "")) == "collect" and s.has("at"):
			out.append({"quest": id, "item": String(s.item), "at": _v2(s.at)})
	return out


## Pega o objeto de missão perto de `p`. Devolve o evento ou {}.
func pickup(p: Vector2) -> Dictionary:
	for pk: Dictionary in pickups():
		if p.distance_to(pk.at) <= PICKUP_RADIUS:
			var it := String(pk.item)
			items[it] = int(items.get(it, 0)) + 1
			var s := step(String(pk.quest))
			if int(items[it]) >= int(s.count):
				_advance(String(pk.quest))
			return {"quest": pk.quest, "type": "step", "drop": it}
	return {}


## Segredo: a recompensa só sai uma vez. Devolve a entrada do segredo ou {}.
func claim_secret(id: String) -> Dictionary:
	if id in secrets or not (data.secrets as Dictionary).has(id):
		return {}
	secrets.append(id)
	return data.secrets[id]


## Objetivo curto (história) do passo atual, para o canto da tela.
func step_text(id: String) -> String:
	return String(step(id).get("text", ""))


## Progresso para o diário (J): "Sapos do charco abatidos: 3 de 5".
func progress_text(id: String) -> String:
	var s := step(id)
	if not s.has("log"):
		return ""
	var have := int(active[id].count) if String(s.type) == "kill" else int(items.get(String(s.item), 0))
	return "%s: %d de %d" % [String(s.log), mini(have, int(s.count)), int(s.count)]


## NPCs com algo a dizer: "!" (missão nova disponível) ou "?" (entrega pendente).
func marker(npc_id: String, level: int) -> String:
	for id: String in active_ids():
		var s := step(id)
		if String(s.get("type", "")) == "talk" and String(s.npc) == npc_id:
			return "?"
	for q: Dictionary in data.quests:
		if String(q.giver) == npc_id and status(String(q.id), level) == "available":
			return "!"
	return ""


static func _v2(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func snapshot() -> Dictionary:
	return {"active": active.duplicate(true), "done": done.duplicate(), "items": items.duplicate(), "secrets": secrets.duplicate(), "perm": perm.duplicate(), "owned": owned.duplicate()}


## Valida o que veio do save: ids desconhecidos e passos fora do intervalo são descartados.
func restore(saved: Dictionary) -> void:
	active.clear()
	done.clear()
	items.clear()
	secrets.clear()
	owned.clear()
	perm = {"max_hp": 0, "max_resource": 0}
	for id: Variant in saved.get("done", []):
		if not quest(String(id)).is_empty() and not (String(id) in done):
			done.append(String(id))
	var act: Variant = saved.get("active", {})
	if act is Dictionary:
		for id: String in act:
			var q := quest(id)
			var e: Variant = act[id]
			if q.is_empty() or id in done or not (e is Dictionary):
				continue
			var st := clampi(int(e.get("step", 0)), 0, (q.steps as Array).size() - 1)
			active[id] = {"step": st, "count": maxi(0, int(e.get("count", 0)))}
	var it: Variant = saved.get("items", {})
	if it is Dictionary:
		for k: String in it:
			if (data.items as Dictionary).has(k):
				items[k] = maxi(0, int(it[k]))
	for s: Variant in saved.get("secrets", []):
		if (data.secrets as Dictionary).has(String(s)) and not (String(s) in secrets):
			secrets.append(String(s))
	var pm: Variant = saved.get("perm", {})
	if pm is Dictionary:
		for k: String in ["max_hp", "max_resource"]:
			perm[k] = maxi(0, int(pm.get(k, 0)))
	for o: Variant in saved.get("owned", []):
		owned.append(String(o))
