extends Node
## Catálogo de objetos del juego (muebles, piezas, precios, tiempos).
##
## Los datos NO están en el código: se leen de `data/catalog.json`, que se
## puede editar con cualquier editor de texto. Si el archivo tiene un error,
## se muestra en la consola de Godot y el juego sigue con lo que pudo leer.

const CATALOG_PATH := "res://data/catalog.json"
const ACTIONS_PATH := "res://data/actions.json"
const TRAITS_PATH := "res://data/traits.json"
const CHARACTER_OPTIONS_PATH := "res://data/character_options.json"

## Campos que todo objeto del catálogo debe tener.
const REQUIRED_ITEM_FIELDS := ["id", "name", "category", "kind", "price"]

## Categorías por id. Ejemplo: categories["furniture"] = {"id": ..., "name": ...}
var categories: Dictionary = {}
## Objetos por id. Ejemplo: items["bed_basic"] = {"id": ..., "price": 300, ...}
var items: Dictionary = {}
## Acciones que anuncian los muebles, por id (ver data/actions.json).
var actions: Dictionary = {}
## Rasgos de personalidad, por id (ver data/traits.json).
var traits: Dictionary = {}
## Cuántos rasgos puede tener un personaje.
var max_traits := 2
## Colores y valores por defecto del editor de personaje.
var character_options: Dictionary = {}


func _ready() -> void:
	load_catalog()
	_load_character_data()


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


## Acciones que ofrece un mueble (diccionarios de actions.json).
func get_item_actions(item_id: String) -> Array:
	var result: Array = []
	for action_id in get_item(item_id).get("actions", []):
		if actions.has(action_id):
			result.append(actions[action_id])
	return result


## Lee acciones, rasgos y opciones del personaje.
func _load_character_data() -> void:
	actions.clear()
	for action in _read_json(ACTIONS_PATH).get("actions", []):
		actions[action["id"]] = action
	var trait_data := _read_json(TRAITS_PATH)
	traits.clear()
	for t in trait_data.get("traits", []):
		traits[t["id"]] = t
	max_traits = int(trait_data.get("max_per_character", 2))
	character_options = _read_json(CHARACTER_OPTIONS_PATH)

	# Avisa si un mueble pide una acción que no existe.
	for item in items.values():
		for action_id in item.get("actions", []):
			if not actions.has(action_id):
				push_warning("Catálogo: '%s' usa una acción que no existe: '%s'" % [item["id"], action_id])
	print("Personaje: %d acciones, %d rasgos" % [actions.size(), traits.size()])


func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("No se pudo leer %s (línea %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data


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
