class_name HouseData
extends RefCounted
## Los datos de UNA casa (sin nada 3D): qué pieza hay en cada lugar.
##
## Cada nivel (piso) tiene "capas", y cada capa es un diccionario
## clave → valor:
##   foundation: "x,z" → {item}               (solo nivel 0)
##   floors:     "x,z" → {item, color?}
##   walls:      "h:x,z" / "v:x,z" → {item, color_a?, color_b?, opening?, join_end?}
##               color_a = cara que mira a la 1.ª celda de HouseGrid.edge_cells
##               (norte u oeste), color_b = la otra (Pulido 1: cada cara se
##               pinta aparte). join_end = la ventana se une con la de la
##               pared que sigue en línea (la unión es de esa juntura).
##   objects:    "o7" → {item, cell: [x, z], rot, diag?, color?}   (muebles,
##               escaleras, pilares; diag = 45° más, ver HouseGrid)
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
## Versión del formato de la casa. 3 = Pulido 1 (pintura por cara de pared y
## unión de ventanas en la juntura). Las casas sin número son de antes.
const FORMAT := 4
## Casas con formato menor a este vienen de antes del Pulido 1 (pintura y ventanas).
const LEGACY_FORMAT := 3

## Pulido 2C: celdas con un obstáculo sin limpiar ("x,z" → id). Lo pone Parcel;
## es de todas las casas (como la parcela) y no se guarda con la casa.
static var blocked_cells: Dictionary = {}

## levels[nivel][capa][clave] = valor
var levels: Array = []
## Contador para dar nombres únicos a objetos y techos ("o1", "o2"...).
var next_id := 1
## Fase 5: versión del hogar en el servidor a la que corresponde esta casa
## (no se guarda: la pone la escena principal al cargar o al ponerse al día).
var rev := 0
## Si al cargar se movió la casa (parcela de otro tamaño), cuánto se movió.
## Quien guarda posiciones aparte (el personaje) debe moverse igual.
var migrated_offset := Vector2i.ZERO
## Pulido 2: cuántos pisos tiene la casa porque el jugador los agregó con
## "Agregar piso" (mínimo 1). Nunca hay un piso "de regalo": ver floors_total.
var floor_count := 1
## Cuántas piezas rotas se sacaron al cargar (ver repair).
var repaired_count := 0


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
	floor_count = 1


## Piso más alto con algo construido (cualquier capa: techos y muebles
## también cuentan). 0 si la casa está vacía.
func used_top_level() -> int:
	for level in range(levels.size() - 1, -1, -1):
		for layer in LAYERS:
			if not levels[level][layer].is_empty():
				return level
	return 0


## Cuántos pisos hay: los que agregó el jugador o los que tienen algo
## construido (lo que sea más alto). Así ninguna pieza queda en un piso al
## que no se puede ir, y no aparece un piso vacío "de regalo".
func floors_total() -> int:
	return clampi(maxi(floor_count, used_top_level() + 1), 1, HouseGrid.MAX_LEVELS)


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


## ¿Esta pieza todavía se está construyendo? (obras con temporizador)
static func is_under_construction(value: Variant) -> bool:
	return value != null and int(value.get("ready_at", 0)) > Economy.now()


## Piezas en obra: lista de [nivel, capa, clave, hora en que terminan].
func pending_construction() -> Array:
	var result: Array = []
	var now := Economy.now()
	for level in HouseGrid.MAX_LEVELS:
		for layer in Economy.TIMED_LAYERS:
			for key in levels[level][layer]:
				var ready_at := int(levels[level][layer][key].get("ready_at", 0))
				if ready_at > now:
					result.append([level, layer, key, ready_at])
	return result


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
	return value_cells(value)


## Celdas que ocupa un objeto (diccionario de la capa "objects").
static func value_cells(value: Dictionary) -> Array[Vector2i]:
	var item := Catalog.get_item(value.get("item", ""))
	return HouseGrid.object_cells_full(item_footprint(item), object_anchor(value), int(value.get("rot", 0)),
		bool(value.get("diag", false)))


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
		"format": FORMAT,
		"floor_count": floor_count,
	}


## Llena la casa a partir de un diccionario leído del archivo.
func from_dict(data: Dictionary) -> void:
	# El servidor no guarda "floor_count": si falta, se conserva lo que había.
	var kept_floors := floor_count
	clear()
	var saved_levels: Array = data.get("levels", [])
	for i in mini(saved_levels.size(), levels.size()):
		for layer in LAYERS:
			levels[i][layer] = (saved_levels[i] as Dictionary).get(layer, {}).duplicate(true)
	next_id = int(data.get("next_id", 1))
	if int(data.get("format", 1)) < LEGACY_FORMAT:
		upgrade_legacy(levels)

	# Migración: las casas guardadas antes tenían un lote de 12x12. Si la
	# parcela cambió de tamaño, la casa se centra en la nueva.
	var saved_lot: Array = data.get("lot_size", [12, 12])
	migrated_offset = (HouseGrid.LOT_SIZE - Vector2i(int(saved_lot[0]), int(saved_lot[1]))) / 2
	if migrated_offset != Vector2i.ZERO:
		_shift(migrated_offset)
	floor_count = clampi(int(data.get("floor_count", kept_floors)), 1, HouseGrid.MAX_LEVELS)
	repaired_count = repair()
	reloaded.emit()


## Saca las piezas rotas que una edición vieja pudo dejar (por ejemplo un
## techo sin medidas o fuera de la parcela, que no se podía tocar ni borrar).
## Devuelve cuántas sacó. El servidor hace lo mismo al leer la casa
## (neighborhood_rules.lua, normalize_house).
func repair() -> int:
	var removed := 0
	for level in levels:
		for key in level["roofs"].keys():
			if not _roof_is_sane(level["roofs"][key]):
				level["roofs"].erase(key)
				removed += 1
	return removed


static func _roof_is_sane(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY or not value.has("rect") or typeof(value["rect"]) != TYPE_ARRAY:
		return false
	var r: Array = value["rect"]
	if r.size() != 4:
		return false
	for n in r:
		if typeof(n) != TYPE_FLOAT and typeof(n) != TYPE_INT:
			return false
	var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	return rect.size.x >= 1 and rect.size.y >= 1 and Rect2i(Vector2i.ZERO, HouseGrid.LOT_SIZE).encloses(rect)


## Casas de antes del Pulido 1 (sin "format"): la misma cuenta que
## normalize_house en el servidor (neighborhood_rules.lua, upgrade_legacy).
##   - Pintura: el color de una pared pasa a sus DOS caras.
##   - Ventanas: antes se unían solas si eran iguales y ninguna estaba
##     "separada". Ahora la unión se guarda en la juntura (join_end en la
##     pared que termina ahí): se marca donde antes se veían unidas.
static func upgrade_legacy(house_levels: Array) -> void:
	for level in house_levels:
		var walls: Dictionary = level.get("walls", {})
		var joins: Array = []
		for key in walls:
			if _legacy_joined(walls, key):
				joins.append(key)
		for key in walls:
			var wall: Dictionary = walls[key]
			if wall.has("color"):
				wall["color_a"] = wall.get("color_a", wall["color"])
				wall["color_b"] = wall.get("color_b", wall["color"])
				wall.erase("color")
			wall.erase("separate")
		for key in joins:
			walls[key]["join_end"] = true


## ¿Esta pared (con ventana) se veía unida con la que sigue en línea?
static func _legacy_joined(walls: Dictionary, key: String) -> bool:
	var wall: Dictionary = walls[key]
	var opening: String = wall.get("opening", "")
	if opening == "" or Catalog.get_item(opening).get("kind", "") != "window" or wall.get("separate", false):
		return false
	var next := HouseGrid.next_in_line(key)
	if not walls.has(next):
		return false
	var other: Dictionary = walls[next]
	if other.get("opening", "") != opening or other.get("separate", false):
		return false
	# En esa esquina tienen que juntarse solo esas dos.
	var count := 0
	for edge in HouseGrid.vertex_edges(HouseGrid.edge_vertices(key)[1]):
		if walls.has(edge):
			count += 1
	return count == 2


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
