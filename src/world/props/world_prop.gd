@tool
class_name WorldProp
extends Node3D
## STUB do contrato de peças do mundo (gerado pelo artista técnico).
## Na integração prevalece a versão do agente de código do módulo de mapa.
## Peça de cenário: as variantes são filhos `Variant0..N` e só uma fica visível.

## Identificador estável da peça no kit (chave do `<kit>.json`).
@export var prop_id: StringName
## Uma de: &"wall", &"roof", &"floor", &"door", &"window", &"stairs", &"furniture",
## &"decor", &"tree", &"rock", &"fence", &"light", &"bridge", &"building".
@export var category: StringName
## Células ocupadas na grade (x, z).
@export var footprint: Vector2i = Vector2i.ONE
## Se a peça bloqueia o movimento (tem StaticBody3D na camada 1).
@export var blocks_movement: bool = false
## Variante visível (filho `Variant<n>`).
@export var variant: int = 0:
	set(v):
		variant = v
		_apply_variant()
## Tinta multiplicada nos materiais (reservado; o stub não aplica).
@export var tint: Color = Color.WHITE


func _ready() -> void:
	_apply_variant()


func _apply_variant() -> void:
	if not is_inside_tree():
		return
	var found := false
	for c in get_children():
		if c is Node3D and String(c.name).begins_with("Variant"):
			found = true
	if not found:
		return
	for c in get_children():
		if c is Node3D and String(c.name).begins_with("Variant"):
			(c as Node3D).visible = String(c.name) == "Variant%d" % variant
