class_name ItemDefinition
extends Resource
## Definição de um item do jogo (o "tipo", não a instância na bolsa).
## Vem de `assets/data/items.json` (+ arte em `assets/items/item_models.json`) via
## `ItemCatalog`, mas também pode ser um `.tres` criado no editor.
##
## Contrato de dados (items.json → campo):
##   name → display_name, desc → lore, slot, classes → vocations, stats, rarity,
##   kind, stack → max_stack, value, use → use_effect, tint, color, model, icon.
## Todos opcionais exceto o id (a chave do item em items.json).

## Raridade quando o item não declara uma (mesma regra da loja: "sem raridade = basic").
const DEFAULT_RARITY: StringName = &"basic"

## Chave estável do item (id em items.json). Nunca muda depois de publicado.
@export var id: StringName = &""
## Nome mostrado ao jogador.
@export var display_name: String = ""
## Descrição curta de lore (só história; nada de instrução de interface).
@export_multiline var lore: String = ""
## Slot de equipamento (`head`, `chest`, `weapon`...). Vazio = não equipável.
@export var slot: StringName = &""
## Natureza do item: &"equipment", &"consumable", &"key", &"material", &"misc".
@export var kind: StringName = &"misc"
## Vocações (ids de classe) que podem usar. Vazio = qualquer uma.
@export var vocations: PackedStringArray = PackedStringArray()
## Atributos concedidos ao vestir (chaves de `stat_names` em items.json).
@export var stats: Dictionary = {}
## &"basic", &"common", &"rare", &"epic"... (cores em items.json `rarity_colors`).
@export var rarity: StringName = DEFAULT_RARITY
## Quantos cabem numa pilha. 1 = não empilha.
@export_range(1, 9999) var max_stack: int = 1
## Valor de referência em moedas (0 = a economia decide pela raridade).
@export var value: int = 0
## Efeito ao usar (consumíveis), p.ex. {"hp": 45} ou {"buff": "STR", "amount": 4, "duration": 60}.
@export var use_effect: Dictionary = {}
## Multiplicador de cor aplicado ao modelo e ao ícone (items.json "tint").
@export var tint: Color = Color.WHITE
## Cor base usada quando não há ícone (desenho de reserva da interface).
@export var color: Color = Color(0.6, 0.6, 0.6)
## Caminho da cena/modelo 3D (`.glb`/`.gltf`/`.tscn`). Vazio = sem modelo.
@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""
## Caminho do ícone da bolsa (64 px, gerado pelo IconBaker).
@export_file("*.png") var icon_path: String = ""
## Ângulo/zoom do ícone (yaw, pitch, roll em graus; zoom; offset [x,y,z]). Vazio = padrão.
@export var icon_view: Dictionary = {}

var _model: PackedScene
var _icon: Texture2D


## True se o item pode ser vestido.
func is_equippable() -> bool:
	return slot != &""


## True se empilha (mais de 1 por célula da bolsa).
func is_stackable() -> bool:
	return max_stack > 1


## True se a vocação `vocation` pode usar o item (lista vazia = todas).
func usable_by(vocation: String) -> bool:
	return vocations.is_empty() or vocations.has(vocation)


## Cena do modelo (carregada na primeira chamada). null se não houver modelo.
func get_model() -> PackedScene:
	if _model == null and model_path != "" and ResourceLoader.exists(model_path):
		_model = load(model_path) as PackedScene
	return _model


## Ícone da bolsa (carregado na primeira chamada). null se ainda não foi gerado.
func get_icon() -> Texture2D:
	if _icon == null and icon_path != "" and ResourceLoader.exists(icon_path):
		_icon = load(icon_path) as Texture2D
	return _icon


## Injeta modelo/ícone já carregados (testes, ferramentas ou itens criados em código).
func set_assets(model: PackedScene, icon: Texture2D) -> void:
	_model = model
	_icon = icon


## Monta a definição a partir da entrada de items.json. `art` é a entrada do item em
## item_models.json já resolvida ({model, view}); campos de items.json têm prioridade.
static func from_dict(item_id: String, data: Dictionary, art: Dictionary = {}) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = StringName(item_id)
	d.display_name = String(data.get("name", item_id))
	d.lore = String(data.get("desc", ""))
	d.slot = StringName(String(data.get("slot", "")))
	d.kind = StringName(String(data.get("kind", "equipment" if d.slot != &"" else "misc")))
	d.vocations = PackedStringArray(data.get("classes", []))
	d.stats = (data.get("stats", {}) as Dictionary).duplicate()
	d.rarity = StringName(String(data.get("rarity", DEFAULT_RARITY)))
	d.max_stack = maxi(1, int(data.get("stack", 1)))
	d.value = int(data.get("value", 0))
	d.use_effect = (data.get("use", {}) as Dictionary).duplicate(true)
	d.tint = _color(data.get("tint"), Color.WHITE)
	d.color = _color(data.get("color"), Color(0.6, 0.6, 0.6))
	d.model_path = String(data.get("model", art.get("model", "")))
	d.icon_path = String(data.get("icon", ""))
	d.icon_view = (art.get("view", {}) as Dictionary).duplicate()
	if data.get("icon_view") is Dictionary:
		d.icon_view.merge(data.icon_view, true)
	return d


static func _color(v: Variant, fallback: Color) -> Color:
	if v is Array and (v as Array).size() >= 3:
		return JsonData.to_color(v)
	return fallback
