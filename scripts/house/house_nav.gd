class_name HouseNav
extends RefCounted
## Caminos dentro de una casa: por dónde puede caminar un personaje.
##
## Usa una red de puntos (AStar3D de Godot): un punto en el centro de cada
## celda donde se puede pararse, unidos con sus vecinos si no hay una pared
## en medio (una pared con puerta sí deja pasar). Las escaleras unen la
## planta baja con el piso de arriba.
##
## Cuando la casa cambia, la red se marca "sucia" y se vuelve a armar sola la
## próxima vez que alguien pide un camino (navegación que se regenera).

var _house: HouseData
var _astar := AStar3D.new()
var _dirty := true


func _init(house: HouseData) -> void:
	_house = house
	_house.piece_changed.connect(_on_piece_changed)
	_house.reloaded.connect(mark_dirty)


## La casa cambió: el camino se vuelve a armar cuando se pida.
func mark_dirty() -> void:
	_dirty = true


func _on_piece_changed(_level: int, _layer: String, _key: String) -> void:
	_dirty = true


## Número único de cada celda de cada nivel (el lote mide menos de 100).
static func point_id(level: int, cell: Vector2i) -> int:
	return HouseGrid.level_index(level) * 10000 + cell.y * 100 + cell.x


static func id_to_level(id: int) -> int:
	return (id % 100000) / 10000 + HouseGrid.MIN_LEVEL


static func id_to_cell(id: int) -> Vector2i:
	return Vector2i(id % 100, (id / 100) % 100)


## Los escalones usan otro rango de ids (las celdas llegan hasta 9595).
const STEP_ID_BASE := 100000


## Altura del suelo de una celda (sobre cimientos o sobre el pasto).
func ground_y(level: int, cell: Vector2i) -> float:
	if level == 0 and not _house.has_piece(0, "foundation", HouseGrid.cell_key(cell)):
		return 0.0
	return HouseGrid.level_y(level)


## ¿Se puede estar parado en esta celda? (Las escaleras se tratan aparte.)
func is_walkable(level: int, cell: Vector2i) -> bool:
	if not HouseGrid.is_cell_in_lot(cell):
		return false
	if level > 0 and not _house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
		return false
	if level == 0 and HouseRules.is_blocked(cell):
		return false  # Un árbol, una roca o el laguito (Pulido 2C).
	if level < 0 and not _house.has_piece(level, "floors", HouseGrid.cell_key(cell)):
		return false  # En un sótano solo se camina sobre piso.
	return _house.object_at(level, cell) == ""


## ¿Se puede cruzar el borde entre dos celdas vecinas? (sin pared, o con puerta)
func is_edge_open(level: int, edge: String) -> bool:
	var wall: Variant = _house.get_piece(level, "walls", edge)
	if wall == null:
		return true
	return Catalog.get_item(wall.get("opening", "")).get("kind", "") == "door"


## Camino desde una celda hasta otra. Devuelve las posiciones (coordenadas de
## la casa) o una lista vacía si no se puede llegar.
func find_path(from_level: int, from_cell: Vector2i, to_level: int, to_cell: Vector2i) -> PackedVector3Array:
	_rebuild_if_needed()
	var from_id := point_id(from_level, from_cell)
	var to_id := point_id(to_level, to_cell)
	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return PackedVector3Array()
	if _astar.is_point_disabled(from_id) or _astar.is_point_disabled(to_id):
		return PackedVector3Array()
	return _astar.get_point_path(from_id, to_id)


## Celda caminable más cercana a una posición (para "rescatar" al personaje
## si le construyeron algo encima). Devuelve [nivel, celda] o [] si no hay.
func nearest_walkable(position: Vector3) -> Array:
	_rebuild_if_needed()
	var id := _astar.get_closest_point(position)
	if id < 0:
		return []
	if id % 10000 >= 5000:
		return []  # Es un escalón: no sirve para quedarse parado.
	return [id_to_level(id), id_to_cell(id)]


## Celdas desde donde se puede usar un objeto: vecinas, caminables y sin
## pared en medio.
func object_spots(level: int, key: String) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var cells := _house.object_cells(level, key)
	for cell in cells:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next in cells or next in spots:
				continue
			if is_walkable(level, next) and is_edge_open(level, _shared_edge(cell, next)):
				spots.append(next)
	return spots


func _rebuild_if_needed() -> void:
	if _dirty:
		rebuild()


## Pulido 2C: con una parcela de 96 x 96, la red solo cubre la zona útil: la
## casa y su alrededor (con margen) y la franja hasta la calle. Así armarla
## es barato en un teléfono (≈2000 celdas en vez de 9216).
const AREA_MARGIN := 8


func nav_area() -> Rect2i:
	var home := HouseGrid.home_origin()
	var area := Rect2i(home, Vector2i(HouseGrid.HOME_ZONE, HouseGrid.HOME_ZONE)).grow(AREA_MARGIN)
	for level in HouseGrid.level_range():
		for layer in ["foundation", "floors"]:
			for key in _house.get_layer(level, layer):
				area = area.expand(HouseGrid.key_to_cell(key)).expand(HouseGrid.key_to_cell(key) + Vector2i.ONE)
	area = area.grow(2)
	# Hasta la calle (el frente de la parcela).
	area = area.expand(Vector2i(area.position.x, HouseGrid.LOT_SIZE.y)).expand(Vector2i(area.end.x, HouseGrid.LOT_SIZE.y))
	return area.intersection(Rect2i(Vector2i.ZERO, HouseGrid.LOT_SIZE))


## Arma la red de puntos completa.
func rebuild() -> void:
	_dirty = false
	_astar.clear()
	var area := nav_area()
	for level in HouseGrid.level_range():
		for x in range(area.position.x, area.end.x):
			for z in range(area.position.y, area.end.y):
				var cell := Vector2i(x, z)
				if is_walkable(level, cell):
					var pos := HouseGrid.cell_center(cell) + Vector3(0, ground_y(level, cell), 0)
					_astar.add_point(point_id(level, cell), pos)

	for level in HouseGrid.level_range():
		for x in range(area.position.x, area.end.x):
			for z in range(area.position.y, area.end.y):
				var cell := Vector2i(x, z)
				_connect_if_open(level, cell, cell + Vector2i(1, 0))
				_connect_if_open(level, cell, cell + Vector2i(0, 1))
		# Diagonales: solo si se puede ir por los dos lados (no corta esquinas).
		for x in range(area.position.x, area.end.x):
			for z in range(area.position.y, area.end.y):
				for step in [Vector2i(1, 1), Vector2i(1, -1)]:
					_connect_diagonal(level, Vector2i(x, z), step)

	# Escaleras de todos los pisos (cada una une su piso con el de arriba).
	for level in range(HouseGrid.MIN_LEVEL, HouseGrid.MAX_LEVELS - 1):
		for key in _house.get_layer(level, "objects"):
			_add_stairs(level, key)


func _connect_if_open(level: int, a: Vector2i, b: Vector2i) -> void:
	var id_a := point_id(level, a)
	var id_b := point_id(level, b)
	if _astar.has_point(id_a) and _astar.has_point(id_b) and is_edge_open(level, _shared_edge(a, b)):
		_astar.connect_points(id_a, id_b)


func _connect_diagonal(level: int, a: Vector2i, step: Vector2i) -> void:
	var b := a + step
	var side_x := a + Vector2i(step.x, 0)
	var side_z := a + Vector2i(0, step.y)
	var ids := [point_id(level, a), point_id(level, b), point_id(level, side_x), point_id(level, side_z)]
	for id in ids:
		if not _astar.has_point(id):
			return
	if _astar.are_points_connected(ids[0], ids[2]) and _astar.are_points_connected(ids[2], ids[1]) \
			and _astar.are_points_connected(ids[0], ids[3]) and _astar.are_points_connected(ids[3], ids[1]):
		_astar.connect_points(ids[0], ids[1])


## Una escalera: entrada abajo → escalones → salida arriba.
func _add_stairs(level: int, key: String) -> void:
	var value: Dictionary = _house.get_piece(level, "objects", key)
	if Catalog.get_item(value["item"]).get("kind", "") != "stairs" or HouseData.is_under_construction(value):
		return
	# Hacia dónde sube la escalera según su giro (ver HousePieces._build_stairs).
	var up: Vector2i = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][int(value.get("rot", 0)) % 4]
	var steps := _house.object_cells(level, key)
	steps.sort_custom(func(a, b): return a.x * up.x + a.y * up.y < b.x * up.x + b.y * up.y)

	var entry: Vector2i = steps[0] - up
	var exit: Vector2i = steps[-1] + up
	var entry_id := point_id(level, entry)
	var exit_id := point_id(level + 1, exit)
	if not _astar.has_point(entry_id) or not _astar.has_point(exit_id):
		return
	if not is_edge_open(level, _shared_edge(entry, steps[0])):
		return

	var previous := entry_id
	for i in steps.size():
		var id := STEP_ID_BASE + point_id(level, steps[i])  # Ids aparte para los escalones.
		var height := HouseGrid.level_y(level) + (i + 0.5) / steps.size() * HouseGrid.WALL_HEIGHT
		_astar.add_point(id, HouseGrid.cell_center(steps[i]) + Vector3(0, height, 0))
		_astar.connect_points(previous, id)
		previous = id
	_astar.connect_points(previous, exit_id)


## Borde que comparten dos celdas vecinas.
static func _shared_edge(a: Vector2i, b: Vector2i) -> String:
	if a.x == b.x:
		return HouseGrid.edge_key(Vector2i(a.x, maxi(a.y, b.y)), true)
	return HouseGrid.edge_key(Vector2i(maxi(a.x, b.x), a.y), false)
