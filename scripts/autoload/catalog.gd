extends Node
## Catálogo de objetos del juego (muebles, piezas, precios, tiempos).
##
## Los datos NO están en el código: se leen de `data/catalog.json`, que se
## puede editar con cualquier editor de texto. Si el archivo tiene un error,
## se muestra en la consola de Godot y el juego sigue con lo que pudo leer.

const CATALOG_PATH := "res://data/catalog.json"

## Campos que todo objeto del catálogo debe tener.
const REQUIRED_ITEM_FIELDS := ["id", "name", "category", "price"]

## Categorías por id. Ejemplo: categories["furniture"] = {"id": ..., "name": ...}
var categories: Dictionary = {}
## Objetos por id. Ejemplo: items["bed_basic"] = {"id": ..., "price": 300, ...}
var items: Dictionary = {}


func _ready() -> void:
	load_catalog()


## Lee el archivo de datos y llena `categories` e `items`.
func load_catalog() -> void:
	categories.clear()
	items.clear()

	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	if text.is_empty():
		push_error("Catálogo: no se pudo leer %s" % CATALOG_PATH)
		EventBus.catalog_loaded.emit(0)
		return

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Catálogo: error en %s, línea %d: %s"
			% [CATALOG_PATH, json.get_error_line(), json.get_error_message()])
		EventBus.catalog_loaded.emit(0)
		return

	var data: Dictionary = json.data
	for category in data.get("categories", []):
		categories[category["id"]] = category

	for item in data.get("items", []):
		if _is_valid_item(item):
			items[item["id"]] = item

	print("Catálogo: %d categorías, %d objetos" % [categories.size(), items.size()])
	EventBus.catalog_loaded.emit(items.size())


## Devuelve un objeto por su id, o un diccionario vacío si no existe.
func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


## Devuelve todos los objetos de una categoría.
func get_items_in_category(category_id: String) -> Array:
	var result: Array = []
	for item in items.values():
		if item["category"] == category_id:
			result.append(item)
	return result


## Revisa que un objeto tenga lo mínimo y avisa si algo está mal.
func _is_valid_item(item: Dictionary) -> bool:
	for field in REQUIRED_ITEM_FIELDS:
		if not item.has(field):
			push_warning("Catálogo: a un objeto le falta '%s': %s" % [field, item])
			return false
	if items.has(item["id"]):
		push_warning("Catálogo: id repetido '%s' (se ignora el segundo)" % item["id"])
		return false
	if not categories.has(item["category"]):
		push_warning("Catálogo: '%s' usa una categoría que no existe: '%s'"
			% [item["id"], item["category"]])
		return false
	return true
