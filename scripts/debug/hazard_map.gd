class_name HazardMap
extends RefCounted
## Mapa genérico de celdas peligrosas (Pulido 4B).
##
## Una celda peligrosa tiene un TIPO:
##   wet  (charco)    → quien la pisa sin atención se CAE.
##   hot  (caliente)  → se QUEMA.
##   drop (desnivel)  → TROPIEZA.
## Los tipos, sus colores y qué accidente causa cada uno están en data/hazards.json.
##
## Es un mapa de la partida en curso (no se guarda ni se manda al servidor). Hoy el
## modo desarrollador agrega celdas tocando el suelo; mañana cualquier objeto o
## evento del juego (un derrame, una cocina encendida, un escalón) puede hacer
## `HazardMap.add(nivel, celda, "wet")` y quitarlo con `HazardMap.remove(...)`.
## La navegación (HouseNav) y el personaje lo leen; avisan por EventBus.hazards_changed.

const DATA_PATH := "res://data/hazards.json"

static var _data: Dictionary = {}
## "nivel:x,z" → tipo.
static var _cells: Dictionary = {}


## Los datos de data/hazards.json (se leen una vez).
static func data() -> Dictionary:
	if _data.is_empty():
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(DATA_PATH)) == OK and json.data is Dictionary:
			_data = json.data
		else:
			push_error("No se pudo leer %s" % DATA_PATH)
			_data = {"hazards": {}, "accidents": {}, "attention": {}}
	return _data


## Ids de los tipos de peligro (wet, hot, drop…).
static func kinds() -> Array:
	return data().get("hazards", {}).keys()


static func kind_info(kind: String) -> Dictionary:
	return data().get("hazards", {}).get(kind, {})


## El accidente que causa un tipo de peligro (fall, trip o burn).
static func accident_for(kind: String) -> String:
	return str(kind_info(kind).get("accident", ""))


static func accident_info(accident: String) -> Dictionary:
	return data().get("accidents", {}).get(accident, {})


static func accidents() -> Array:
	return data().get("accidents", {}).keys()


static func color_of(kind: String) -> Color:
	return Color(str(kind_info(kind).get("color", "#ffffff")))


# --- Atención del personaje ---

static func default_attention() -> float:
	return clampf(float(data().get("attention", {}).get("default", 1.0)), 0.0, 1.0)


## Desde este valor de atención el personaje esquiva los peligros.
static func careful_at() -> float:
	return clampf(float(data().get("attention", {}).get("careful_at", 0.5)), 0.0, 1.0)


## ¿Con esta atención esquiva los peligros?
static func is_careful(attention: float) -> bool:
	return attention >= careful_at()


## Cuánto cuesta caminar sobre un peligro para quien lo esquiva (la navegación).
static func avoid_cost() -> float:
	return maxf(1.0, float(data().get("attention", {}).get("avoid_cost", 40.0)))


## Valores rápidos de atención: [{id, name, value}].
static func presets() -> Array:
	return data().get("attention", {}).get("presets", [])


static func preset_value(id: String) -> float:
	for preset in presets():
		if preset["id"] == id:
			return clampf(float(preset["value"]), 0.0, 1.0)
	return default_attention()


# --- Las celdas ---

static func _key(level: int, cell: Vector2i) -> String:
	return "%d:%d,%d" % [level, cell.x, cell.y]


static func is_empty() -> bool:
	return _cells.is_empty()


## Agrega (o cambia) un peligro. Devuelve false si el tipo no existe.
static func add(level: int, cell: Vector2i, kind: String) -> bool:
	if kind_info(kind).is_empty():
		return false
	_cells[_key(level, cell)] = kind
	_changed()
	return true


## Quita el peligro de una celda. Devuelve true si había uno.
static func remove(level: int, cell: Vector2i) -> bool:
	var existed := _cells.erase(_key(level, cell))
	if existed:
		_changed()
	return existed


static func clear() -> void:
	if _cells.is_empty():
		return
	_cells.clear()
	_changed()


## El tipo de peligro de una celda ("" si no hay).
static func kind_at(level: int, cell: Vector2i) -> String:
	if _cells.is_empty():
		return ""
	return str(_cells.get(_key(level, cell), ""))


## Todos los peligros: [{level, cell, kind}].
static func all() -> Array:
	var result: Array = []
	for key in _cells:
		var parts := (key as String).split(":")
		var xz := parts[1].split(",")
		result.append({"level": int(parts[0]), "cell": Vector2i(int(xz[0]), int(xz[1])), "kind": _cells[key]})
	return result


static func count() -> int:
	return _cells.size()


static func _changed() -> void:
	EventBus.hazards_changed.emit()
