class_name HouseRooms
## Cuartos que el juego entiende (Pulido 1).
##
## Un cuarto es un área de piso cerrada por paredes (las puertas cuentan como
## pared: separan cuartos). Según los muebles que tiene, el juego le pone un
## tipo (dormitorio, cocina, baño, sala, estudio...). Los tipos y qué mueble
## cuenta para cada uno están en data/rooms.json (editable).
##
## Pulido 3B: el JUGADOR puede ponerle su propio tipo a cada cuarto (y elegir
## cuál es el dormitorio PRINCIPAL). Lo asignado manda sobre lo deducido por
## los muebles, que sigue sirviendo de recomendación cuando no hay nada asignado.
##
## La Tienda usa esto para RECOMENDAR (primero lo del tipo asignado o más
## probable, después lo del segundo). Nunca prohíbe nada: una cama en la cocina
## se puede.

const ROOMS_PATH := "res://data/rooms.json"
## Un área más grande que esto no es un cuarto (es el jardín, por ejemplo).
const MAX_ROOM_CELLS := 400

static var _data: Dictionary = {}


## Los datos de data/rooms.json (se leen una vez).
static func data() -> Dictionary:
	if _data.is_empty():
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(ROOMS_PATH)) == OK and json.data is Dictionary:
			_data = json.data
		else:
			push_error("No se pudo leer %s" % ROOMS_PATH)
			_data = {"types": []}
	return _data


## Los cuartos de un piso: [{cells: {"x,z": true}, type, name, ranking}].
## ranking = [[id del tipo, puntos], ...] de mayor a menor.
static func detect(house: HouseData, level: int) -> Array:
	var rooms: Array = []
	var seen := {}
	for key in house.get_layer(level, "floors"):
		if seen.has(key):
			continue
		var region := _flood(house, level, HouseGrid.key_to_cell(key), seen)
		if region["closed"]:
			rooms.append(_classify(house, level, region["cells"]))
	rooms.sort_custom(func(a, b) -> bool: return str(a["anchor"]) < str(b["anchor"]))
	return rooms


## El cuarto donde está una celda ({} si no está en un cuarto cerrado).
static func room_at(house: HouseData, level: int, cell: Vector2i) -> Dictionary:
	if not house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
		return {}
	var region := _flood(house, level, cell, {})
	if not region["closed"]:
		return {}
	return _classify(house, level, region["cells"])


## Muebles recomendados para un cuarto, en orden: los del tipo más probable
## (los que más puntos dan primero), después los del segundo tipo.
static func recommended_items(room: Dictionary) -> Array:
	var result: Array = []
	var ranked: Array = room.get("ranking", []).duplicate()
	# Lo asignado por el jugador va primero.
	if room.get("assigned", false):
		ranked.push_front([room["type"], 0.0])
	for entry in ranked.slice(0, 2 if not room.get("assigned", false) else 3):
		var type := _type(entry[0])
		var items: Dictionary = type.get("items", {})
		var ids := items.keys()
		ids.sort_custom(func(a, b): return float(items[a]) > float(items[b]))
		for id in ids:
			if not id in result:
				result.append(id)
	return result


## Recorre las celdas con piso unidas sin pared en medio. Si llega a un borde
## sin pared que da a una celda SIN piso, el área está abierta (no es cuarto).
static func _flood(house: HouseData, level: int, start: Vector2i, seen: Dictionary) -> Dictionary:
	var cells := {}
	var closed := true
	var queue: Array[Vector2i] = [start]
	cells[HouseGrid.cell_key(start)] = true
	seen[HouseGrid.cell_key(start)] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if house.has_piece(level, "walls", HouseGrid.shared_edge(cell, next)):
				continue  # Pared (con o sin puerta): el cuarto termina aquí.
			var key := HouseGrid.cell_key(next)
			if cells.has(key):
				continue
			if not house.has_piece(level, "floors", key):
				closed = false  # Se sale del piso sin pared: está abierto.
				continue
			cells[key] = true
			seen[key] = true
			queue.append(next)
		if cells.size() > MAX_ROOM_CELLS:
			closed = false
			break
	return {"cells": cells, "closed": closed}


## Le pone tipo a un cuarto según sus muebles.
static func _classify(house: HouseData, level: int, cells: Dictionary) -> Dictionary:
	var scores := {}
	for key in house.get_layer(level, "objects"):
		var value: Dictionary = house.get_piece(level, "objects", key)
		var anchor := HouseGrid.cell_key(HouseData.object_anchor(value))
		var inside := cells.has(anchor)
		if not inside:
			for cell in HouseData.value_cells(value):
				if cells.has(HouseGrid.cell_key(cell)):
					inside = true
					break
		if not inside:
			continue
		for type in data().get("types", []):
			var points := float(type.get("items", {}).get(value.get("item", ""), 0))
			if points > 0:
				scores[type["id"]] = scores.get(type["id"], 0.0) + points
	var ranking: Array = []
	for id in scores:
		ranking.append([id, scores[id]])
	ranking.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and str(a[0]) < str(b[0])))
	var room := {"cells": cells, "ranking": ranking, "level": level, "anchor": _anchor(cells)}
	var assigned := assigned_type(house, level, cells)
	if assigned != "":
		room["type"] = assigned
		room["name"] = _type(assigned).get("name", "")
		room["assigned"] = true
		room["main"] = assigned == BEDROOM and is_main_bedroom_cell(house, level, cells)
		return room
	if ranking.is_empty():
		var empty: Dictionary = data().get("empty", {"id": "empty", "name": "Cuarto vacío"})
		room["type"] = empty["id"]
		room["name"] = empty["name"]
	elif ranking.size() >= 2 and ranking[1][1] >= ranking[0][1] * float(data().get("mixed_ratio", 0.6)):
		var mixed: Dictionary = data().get("mixed", {"id": "mixed", "name": "Sin tipo"})
		room["type"] = mixed["id"]
		room["name"] = mixed["name"]
	else:
		room["type"] = ranking[0][0]
		room["name"] = _type(ranking[0][0]).get("name", "")
	return room


## Una clave estable para ordenar cuartos: su celda más "arriba a la izquierda".
static func _anchor(cells: Dictionary) -> String:
	var best := Vector2i(100000, 100000)
	for key in cells:
		var c := HouseGrid.key_to_cell(key)
		if c.y < best.y or (c.y == best.y and c.x < best.x):
			best = c
	return "%05d,%05d" % [best.y, best.x]


# --- Tipo elegido por el jugador (Pulido 3B) ---

const BEDROOM := "bedroom"


static func room_key(level: int, cell_key: String) -> String:
	return "%d:%s" % [level, cell_key]


## El tipo que el jugador le puso a un cuarto ("" si no le puso ninguno). Si
## por unir cuartos hay dos distintos, gana el de la celda más "arriba a la
## izquierda" (siempre el mismo).
static func assigned_type(house: HouseData, level: int, cells: Dictionary) -> String:
	if house.room_types.is_empty():
		return ""
	var keys := cells.keys()
	keys.sort()
	for key in keys:
		var type := str(house.room_types.get(room_key(level, key), ""))
		if type != "" and not _type(type).is_empty():
			return type
	return ""


static func is_main_bedroom_cell(house: HouseData, level: int, cells: Dictionary) -> bool:
	if house.main_bedroom_cell == "":
		return false
	for key in cells:
		if room_key(level, key) == house.main_bedroom_cell:
			return true
	return false


## Los tipos que el jugador puede elegir: [{id, name}] en el orden de data/rooms.json.
static func choosable_types() -> Array:
	var result: Array = []
	for type in data().get("types", []):
		if type["id"] != "restaurant":
			result.append({"id": type["id"], "name": type["name"]})
	return result


## Le pone tipo a un cuarto. `main` solo cuenta para dormitorios: el principal es
## uno solo (si ya había otro, deja de serlo). type_id "" = sacarle el tipo
## elegido (vuelve a valer lo que se deduce por los muebles).
static func set_room_type(house: HouseData, room: Dictionary, type_id: String, main := false) -> void:
	var level: int = room["level"]
	var cells: Dictionary = room["cells"]
	var was_main := is_main_bedroom_cell(house, level, cells)
	for key in cells:
		house.room_types.erase(room_key(level, key))
	if type_id != "" and not _type(type_id).is_empty():
		for key in cells:
			house.room_types[room_key(level, key)] = type_id
	var first := cells.keys()
	first.sort()
	if type_id == BEDROOM and main and not first.is_empty():
		house.main_bedroom_cell = room_key(level, first[0])
	elif was_main:
		house.main_bedroom_cell = ""


## El dormitorio principal del personaje ({} si la casa no tiene dormitorio). Es
## el que el jugador marcó; si no marcó ninguno, el primer dormitorio que haya
## (de abajo hacia arriba). Devuelve el cuarto (con "level" y "cells").
static func main_bedroom(house: HouseData) -> Dictionary:
	var first_bedroom := {}
	for level in HouseGrid.level_range():
		for room in detect(house, level):
			if room["type"] != BEDROOM:
				continue
			if room.get("main", false):
				return room
			if first_bedroom.is_empty():
				first_bedroom = room
	return first_bedroom


## El nombre de un tipo ("bedroom" → "Dormitorio").
static func type_name(id: String) -> String:
	return str(_type(id).get("name", ""))


static func _type(id: String) -> Dictionary:
	for type in data().get("types", []):
		if type["id"] == id:
			return type
	return {}
