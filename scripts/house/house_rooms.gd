class_name HouseRooms
## Cuartos que el juego entiende (Pulido 1).
##
## Un cuarto es un área de piso cerrada por paredes (las puertas cuentan como
## pared: separan cuartos). Según los muebles que tiene, el juego le pone un
## tipo (dormitorio, cocina, baño, sala, estudio... o multiuso). Los tipos y
## qué mueble cuenta para cada uno están en data/rooms.json (editable).
##
## La Tienda usa esto para RECOMENDAR (primero lo del tipo más probable, después
## lo del segundo). Nunca prohíbe nada: una cama en la cocina se puede.

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
	for entry in room.get("ranking", []).slice(0, 2):
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
	var room := {"cells": cells, "ranking": ranking}
	if ranking.is_empty():
		var empty: Dictionary = data().get("empty", {"id": "empty", "name": "Cuarto vacío"})
		room["type"] = empty["id"]
		room["name"] = empty["name"]
	elif ranking.size() >= 2 and ranking[1][1] >= ranking[0][1] * float(data().get("mixed_ratio", 0.6)):
		var mixed: Dictionary = data().get("mixed", {"id": "mixed", "name": "Multiuso"})
		room["type"] = mixed["id"]
		room["name"] = mixed["name"]
	else:
		room["type"] = ranking[0][0]
		room["name"] = _type(ranking[0][0]).get("name", "")
	return room


static func _type(id: String) -> Dictionary:
	for type in data().get("types", []):
		if type["id"] == id:
			return type
	return {}
