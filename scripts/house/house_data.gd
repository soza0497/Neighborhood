class_name HouseData
extends RefCounted
## Los datos de UNA casa (sin nada 3D): qué pieza hay en cada lugar.
##
## Cada nivel (piso) tiene "capas", y cada capa es un diccionario
## clave → valor:
##   foundation: "x,z" → {item}               (solo nivel 0)
##   floors:     "x,z" → {item, color?}
##   walls:      "h:x,z" / "v:x,z" → {item, color?, opening?}
##   objects:    "o7" → {item, cell: [x, z], rot, color?}   (muebles, escaleras)
##   roofs:      "o8" → {item, rect: [x, z, ancho, fondo], color?}
##
## TODO cambio pasa por apply(), con una lista de "escrituras":
##   {level, layer, key, value}   (value = null significa "quitar")
## apply() devuelve las escrituras inversas: así funciona deshacer, y en la
## Fase 5 esas mismas escrituras se podrán mandar a la pareja.
##
## Nota: es RefCounted (no un autoload) porque más adelante habrá varias
## casas (la de la pareja, las del barrio).

## Una pieza cambió. La vista 3D escucha esto para actualizar solo esa pieza.
signal piece_changed(level: int, layer: String, key: String)
## Se reemplazó toda la casa (por ejemplo, al cargar).
signal reloaded

const LAYERS := ["foundation", "floors", "walls", "objects", "roofs"]

## levels[nivel][capa][clave] = valor
var levels: Array = []
## Contador para dar nombres únicos a objetos y techos ("o1", "o2"...).
var next_id := 1
## Si al cargar se movió la casa (parcela de otro tamaño), cuánto se movió.
## Quien guarda posiciones aparte (el personaje) debe moverse igual.
var migrated_offset := Vector2i.ZERO


func _init() -> void:
	clear()


## Deja la casa vacía.
func clear() -> void:
	levels = []
	for i in HouseGrid.MAX_LEVELS:
		var level := {}
		for layer in LAYERS:
			level[layer] = {}
		levels.append(level)
	next_id = 1


## Devuelve la pieza (un diccionario) o null si no hay nada.
func get_piece(level: int, layer: String, key: String) -> Variant:
	if level < 0 or level >= levels.size():
		return null
	return levels[level][layer].get(key)


func has_piece(level: int, layer: String, key: String) -> bool:
	return get_piece(level, layer, key) != null


## Todas las piezas de una capa: clave → valor. No modificar lo que devuelve.
func get_layer(level: int, layer: String) -> Dictionary:
	if level < 0 or level >= levels.size():
		return {}
	return levels[level][layer]


## Nombre nuevo para un objeto o techo.
func new_id() -> String:
	next_id += 1
	return "o%d" % (next_id - 1)


## Crea una escritura (ayudante para no escribir el diccionario a mano).
static func write(level: int, layer: String, key: String, value: Variant) -> Dictionary:
	return {"level": level, "layer": layer, "key": key, "value": value}


## Aplica una lista de escrituras y devuelve la lista que las deshace.
func apply(writes: Array) -> Array:
	var inverse: Array = []
	for w in writes:
		var level: int = w["level"]
		var layer: String = w["layer"]
		var key: String = w["key"]
		var previous: Variant = get_piece(level, layer, key)
		inverse.push_front(write(level, layer, key, previous))
		if w["value"] == null:
			levels[level][layer].erase(key)
		else:
			# Se guarda una copia para que nadie cambie los datos "por la espalda".
			levels[level][layer][key] = (w["value"] as Dictionary).duplicate(true)
		piece_changed.emit(level, layer, key)
	return inverse


## Busca el objeto que ocupa una celda. Devuelve su clave o "" si no hay.
func object_at(level: int, cell: Vector2i) -> String:
	for key in get_layer(level, "objects"):
		if cell in object_cells(level, key):
			return key
	return ""


## Celdas que ocupa un objeto ya colocado.
func object_cells(level: int, key: String) -> Array[Vector2i]:
	var value: Variant = get_piece(level, "objects", key)
	if value == null:
		return []
	var item := Catalog.get_item(value["item"])
	return HouseGrid.object_cells(item_footprint(item), object_anchor(value), int(value.get("rot", 0)))


## Celda de anclaje de un objeto (los números del JSON llegan como decimales).
static func object_anchor(value: Dictionary) -> Vector2i:
	var cell: Array = value["cell"]
	return Vector2i(int(cell[0]), int(cell[1]))


## Tamaño en celdas de un objeto del catálogo.
static func item_footprint(item: Dictionary) -> Vector2i:
	var footprint: Array = item.get("footprint", [1, 1])
	return Vector2i(int(footprint[0]), int(footprint[1]))


## Rectángulo de un techo: posición (x, z) y tamaño (ancho, fondo).
static func roof_rect(value: Dictionary) -> Rect2i:
	var r: Array = value["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## Copia independiente (para simular cambios sin tocar la casa real).
func duplicate_data() -> HouseData:
	var copy := HouseData.new()
	copy.from_dict(to_dict())
	return copy


## Convierte la casa en un diccionario simple para guardarlo en JSON.
func to_dict() -> Dictionary:
	return {
		"levels": levels.duplicate(true),
		"next_id": next_id,
		"lot_size": [HouseGrid.LOT_SIZE.x, HouseGrid.LOT_SIZE.y],
	}


## Llena la casa a partir de un diccionario leído del archivo.
func from_dict(data: Dictionary) -> void:
	clear()
	var saved_levels: Array = data.get("levels", [])
	for i in mini(saved_levels.size(), levels.size()):
		for layer in LAYERS:
			levels[i][layer] = (saved_levels[i] as Dictionary).get(layer, {}).duplicate(true)
	next_id = int(data.get("next_id", 1))

	# Migración: las casas guardadas antes tenían un lote de 12x12. Si la
	# parcela cambió de tamaño, la casa se centra en la nueva.
	var saved_lot: Array = data.get("lot_size", [12, 12])
	migrated_offset = (HouseGrid.LOT_SIZE - Vector2i(int(saved_lot[0]), int(saved_lot[1]))) / 2
	if migrated_offset != Vector2i.ZERO:
		_shift(migrated_offset)
	reloaded.emit()


## Mueve toda la casa `offset` celdas (para las migraciones).
func _shift(offset: Vector2i) -> void:
	for level in levels:
		for layer in LAYERS:
			var moved := {}
			for key in level[layer]:
				var value: Dictionary = level[layer][key]
				match layer:
					"foundation", "floors":
						moved[HouseGrid.cell_key(HouseGrid.key_to_cell(key) + offset)] = value
					"walls":
						moved[HouseGrid.edge_key(HouseGrid.edge_vertex(key) + offset, HouseGrid.is_edge_horizontal(key))] = value
					"objects":
						var cell := object_anchor(value) + offset
						value["cell"] = [cell.x, cell.y]
						moved[key] = value
					"roofs":
						var rect := roof_rect(value)
						value["rect"] = [rect.position.x + offset.x, rect.position.y + offset.y, rect.size.x, rect.size.y]
						moved[key] = value
			level[layer] = moved
