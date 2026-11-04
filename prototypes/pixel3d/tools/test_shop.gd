# PROTOTYPE - NOT FOR PRODUCTION
extends SceneTree
## Ouro e troca com a Nessa (offline, estilo Tibia): moedas caem pelo nível da caçada e vêm das
## missões, aparecem na bolsa, a Nessa abre a troca ao conversar, compra/venda com recusa
## visual (sem ouro, longe), a troca fecha ao se afastar e tudo vai para o save. Online só pede.
## godot --headless --path . -s res://prototypes/pixel3d/tools/test_shop.gd -- --no_save --mute

const Economy := preload("res://prototypes/pixel3d/economy.gd")
const World := preload("res://prototypes/pixel3d/adventure_world.gd")

var demo: Node
var a
var fails := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	print("%s shop: %s" % ["PASS" if cond else "FAIL", what])
	if cond:
		passes += 1
	else:
		fails += 1


func _initialize() -> void:
	call_deferred("run")


class FakeOnline:
	extends RefCounted
	var asked: Array[String] = []

	func buy(kind: String) -> void:
		asked.append("buy:" + kind)

	func sell(id: String) -> void:
		asked.append("sell:" + id)

	func interact(_t: String) -> void:
		pass

	func update(_d: float) -> void:
		pass

	func ground_near(_p: Vector3) -> int:
		return 0

	func trade_set(what: String, n: int) -> void:
		asked.append("trade_set:%s=%d" % [what, n])


func run() -> void:
	Engine.set_meta("aethra_class", "mage")
	demo = (load("res://prototypes/pixel3d/pixel3d_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	demo._capture = true
	a = demo._adventure
	a._persist = false
	for i in 4:
		await process_frame
	var hud = a.hud
	var shop: Dictionary = a.shop
	check(a.gold == 0, "começa sem ouro")
	# --- moedas por abate (nível da caçada)
	var frog: Dictionary = {}
	var lvl_hi: Dictionary = {}
	for act: Dictionary in a.enemies.actors:
		if String(act.kind) == "frog" and int(act.level) == 1 and frog.is_empty():
			frog = act
		if int(act.level) >= 3 and lvl_hi.is_empty():
			lvl_hi = act
	check(not frog.is_empty(), "achou um sapo nível 1")
	a.on_enemy_killed(String(frog.id), "frog", false, Vector3.ZERO)
	var g1 := Economy.gold_drop(shop, "frog", 1)
	check(a.gold == g1, "sapo nível 1 deixa %d moedas" % g1)
	if not lvl_hi.is_empty():
		var before: int = a.gold
		a.on_enemy_killed(String(lvl_hi.id), String(lvl_hi.kind), false, Vector3.ZERO)
		check(a.gold - before == Economy.gold_drop(shop, String(lvl_hi.kind), int(lvl_hi.level)) and a.gold - before > Economy.gold_drop(shop, String(lvl_hi.kind), 1),
			"caçada nível %d paga mais (+%d)" % [int(lvl_hi.level), a.gold - before])
	var b0: int = a.gold
	a._apply_reward({"xp": 1, "gold": 20}, "")
	check(a.gold == b0 + 20, "recompensa de missão soma 20 moedas")
	var entries: Array = hud.bag_entries()
	check(not entries.is_empty() and String(entries[0].kind) == "gold" and int(entries[0].count) == a.gold, "bolsa mostra as moedas na primeira célula (%d)" % a.gold)
	# --- a Nessa abre a troca (fora do aceite da missão)
	demo._player.global_position = World.NPC + Vector3(0, 0, 1.8)
	a.interact()   # aceita As Três Brasas: só fala
	check(hud.panel != "shop", "no aceite da missão a Nessa só fala (sem troca)")
	a.interact()   # missão em andamento: fala + troca
	check(hud.panel == "shop", "depois, falar com a Nessa abre a troca")
	a.interact()
	check(hud.panel == "", "E de novo fecha a troca")
	hud.open_shop()
	# --- comprar
	var price := Economy.buy_price(shop, "hp")
	a.gold = price + 1
	var pots: int = int(a.potions.hp)
	check(hud.shop_buy("hp") and int(a.potions.hp) == pots + 1 and a.gold == 1, "comprar poção de vida: −%d moedas, +1 poção" % price)
	check(hud._accept_fx.has("buy:hp"), "compra: célula brilha dourado")
	check(not hud.shop_buy("hp") and hud._reject_fx.has("buy:hp") and int(a.potions.hp) == pots + 1, "sem ouro: recusa (célula treme em vermelho)")
	# --- vender
	a.inventory.give(["sentinel_staff"])
	var sp := Economy.sell_price(shop, "sentinel_staff", a.inventory.item("sentinel_staff"))
	check(hud.shop_sell("sentinel_staff") and a.gold == 1 + sp and not ("sentinel_staff" in a.inventory.items), "vender o Cajado da Sentinela: +%d moedas" % sp)
	var worn: String = a.inventory.equipped.weapon
	check(not hud.shop_sell(worn) and a.inventory.equipped.weapon == worn, "item vestido não aparece para venda (recusado)")
	var snap: Dictionary = a.content_snapshot()
	check(int(snap.get("gold", -1)) == a.gold, "save leva o ouro (%d)" % a.gold)
	# --- longe da Nessa: recusa e a troca fecha
	demo._player.global_position = World.NPC + Vector3(9, 0, 0)
	check(a.buy_potion("hp") == "range", "longe: compra recusada (range)")
	a.update(0.016, 0.0)
	check(hud.panel == "", "afastar fecha a troca")
	# --- save novo restaura bolsa e ouro
	a.gold = 0
	a._restore_content(snap)
	check(a.gold == 1 + sp and not ("sentinel_staff" in a.inventory.items), "carregar o save devolve ouro e bolsa sem o item vendido")
	# --- online só pede
	demo._player.global_position = World.NPC + Vector3(0, 0, 1.8)
	var fake := FakeOnline.new()
	a.online = fake
	a.gold = 100
	var p0: int = int(a.potions.mana)
	check(hud.shop_buy("mana") and fake.asked == ["buy:mana"] and int(a.potions.mana) == p0 and a.gold == 100, "online: compra só pede ao servidor (nada muda antes)")
	a.inventory.give(["iron_sword"])
	check(hud.shop_sell("iron_sword") and fake.asked.back() == "sell:iron_sword" and "iron_sword" in a.inventory.items, "online: venda só pede ao servidor")
	hud.shop_refused()
	check(hud._reject_fx.has("sell:iron_sword"), "online: recusa do servidor treme a célula")
	# --- troca entre jogadores: ouro e poções na oferta (o HUD só pede; o servidor valida)
	a.gold = 25
	a.potions = {"hp": 2, "mana": 0}
	hud.trade = {"op": "state", "name": "Bia", "mine": [], "theirs": [], "my_gold": 0, "my_pots": {"hp": 0, "mana": 0}}
	check(hud.trade_amount("gold", true) and fake.asked.back() == "trade_set:gold=10", "troca: clique no ouro oferece 10 moedas")
	hud.trade.my_gold = 20
	check(hud.trade_amount("gold", true) and fake.asked.back() == "trade_set:gold=25", "troca: mais um clique oferece o resto (25 de 25)")
	hud.trade.my_gold = 25
	hud._reject_fx.clear()
	check(not hud.trade_amount("gold", true) and hud._reject_fx.has("trade:src:gold"), "troca: sem mais ouro a fonte treme")
	check(hud.trade_amount("gold", false) and fake.asked.back() == "trade_set:gold=15", "troca: tirar devolve 10 moedas")
	check(hud.trade_amount("hp", true) and fake.asked.back() == "trade_set:hp=1", "troca: clique na poção de vida oferece 1")
	check(not hud.trade_amount("mana", true) and hud._reject_fx.has("trade:src:mana"), "troca: sem poção de mana a fonte treme")
	hud.trade = {}
	a.online = null
	# --- balanço (shop.json _balance): 25 abates (~10 min) em cada caçada, no meio da faixa de
	# nível, pagam "algumas poções" (4 a 14 poções de vida) — nem migalha, nem loja de graça
	var regions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://prototypes/pixel3d/data/world_regions.json"))
	var hp_price := Economy.buy_price(shop, "hp")
	for h: Dictionary in regions.hunts:
		var lv: Array = h.level
		var spawns: Array = h.spawns
		var per_kill := 0.0
		for spawn: Array in spawns:
			per_kill += (Economy.gold_drop(shop, String(spawn[2]), int(lv[0])) + Economy.gold_drop(shop, String(spawn[2]), int(lv[1]))) * 0.5
		per_kill /= spawns.size()
		var n_pots := 25.0 * per_kill / hp_price
		check(n_pots >= 4.0 and n_pots <= 14.0, "balanço: 10 min em %s (nv %d-%d) ≈ %.0f moedas = %.1f poções de vida" % [String(h.id), int(lv[0]), int(lv[1]), 25.0 * per_kill, n_pots])
	print("TEST_SHOP: %s (%d PASS, %d FAIL)" % ["OK" if fails == 0 else "FAIL", passes, fails])
	quit(0 if fails == 0 else 1)
